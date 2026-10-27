import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_update.dart';

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

class _DigestCollector implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class UpdateService {
  static const _channel = MethodChannel('com.hoshi.ledger/updates');
  static final _manifestUrl = Uri.parse(
    'https://github.com/${AppUpdate.repository}/releases/latest/download/latest.json',
  );

  HttpClient? _downloadClient;
  bool _cancelled = false;

  Future<AppUpdate?> check() async {
    if (!Platform.isAndroid) throw const UpdateException('应用内更新仅支持 Android');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    final deadline = Timer(
      const Duration(seconds: 45),
      () => client.close(force: true),
    );
    try {
      final request = await client
          .getUrl(_manifestUrl)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == HttpStatus.notFound) {
        throw const UpdateException('暂未发布可用的更新信息');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const UpdateException('更新服务暂时不可用，请稍后重试');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 128 * 1024) throw const UpdateException('更新信息过大');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final update = AppUpdate.fromJson(decoded);
      final installed = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(installed.buildNumber);
      if (installedCode == null) throw const UpdateException('无法读取当前版本');
      return update.versionCode > installedCode ? update : null;
    } on UpdateException {
      rethrow;
    } on FormatException {
      throw const UpdateException('更新信息格式不正确');
    } catch (_) {
      throw const UpdateException('检查更新失败，请检查网络后重试');
    } finally {
      deadline.cancel();
      client.close(force: true);
    }
  }

  Future<File> download(
    AppUpdate update,
    void Function(int received, int total) onProgress,
  ) async {
    if (_downloadClient != null) throw const UpdateException('正在下载更新');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _downloadClient = client;
    _cancelled = false;
    File? partial;
    IOSink? output;
    final deadline = Timer(
      const Duration(minutes: 10),
      () => client.close(force: true),
    );
    try {
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/updates',
      );
      await directory.create(recursive: true);
      final target = File(
        '${directory.path}/HoshiLedger-v${update.version}.apk',
      );
      if (await target.exists()) {
        if (await target.length() == update.size &&
            (await sha256.bind(target.openRead()).first).toString() ==
                update.sha256) {
          if (_cancelled) throw const UpdateCancelled();
          onProgress(update.size, update.size);
          return target;
        }
        await target.delete();
      }
      if (_cancelled) throw const UpdateCancelled();
      partial = File('${target.path}.part');
      final request = await client
          .getUrl(update.apkUrl)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok ||
          (response.contentLength >= 0 &&
              response.contentLength != update.size)) {
        throw const UpdateException('安装包暂不可用或大小不匹配');
      }
      output = partial.openWrite();
      final digest = _DigestCollector();
      final hashing = sha256.startChunkedConversion(digest);
      int received = 0;
      var lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (_cancelled) throw const UpdateCancelled();
        received += chunk.length;
        if (received > update.size) throw const UpdateException('安装包大小不匹配');
        hashing.add(chunk);
        output.add(chunk);
        final now = DateTime.now();
        if (now.difference(lastProgress).inMilliseconds >= 100) {
          onProgress(received, update.size);
          lastProgress = now;
        }
      }
      hashing.close();
      await output.flush();
      await output.close();
      output = null;
      if (_cancelled) throw const UpdateCancelled();
      if (received != update.size || digest.value.toString() != update.sha256) {
        throw const UpdateException('安装包校验失败，请重新下载');
      }
      await partial.rename(target.path);
      partial = null;
      onProgress(received, update.size);
      return target;
    } on UpdateCancelled {
      rethrow;
    } on UpdateException {
      rethrow;
    } catch (_) {
      if (_cancelled) throw const UpdateCancelled();
      throw const UpdateException('下载失败，请检查网络或存储空间后重试');
    } finally {
      deadline.cancel();
      client.close(force: true);
      _downloadClient = null;
      try {
        await output?.close();
      } catch (_) {
        // 保留原始下载错误，避免清理阶段覆盖它。
      }
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {
        // 不完整文件不会被用于安装，下一次下载会覆盖它。
      }
    }
  }

  void cancelDownload() {
    _cancelled = true;
    _downloadClient?.close(force: true);
  }

  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  Future<void> openInstallPermission() =>
      _channel.invokeMethod<void>('openInstallPermission');

  Future<void> install(File file, AppUpdate update) =>
      _channel.invokeMethod<void>('installApk', {
        'path': file.path,
        'sha256': update.sha256,
        'versionCode': update.versionCode,
      });
}
