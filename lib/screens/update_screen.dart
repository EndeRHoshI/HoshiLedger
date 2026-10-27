import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_update.dart';
import '../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with WidgetsBindingObserver {
  final _service = UpdateService();
  AppUpdate? _update;
  File? _package;
  String _installedVersion = '';
  String? _error;
  String? _message;
  bool _checking = false;
  bool _initialized = false;
  bool _downloading = false;
  bool _installing = false;
  bool _waitingPermission = false;
  int _received = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final installed = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installedVersion = installed.version;
        _initialized = true;
      });
      await _check();
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取应用版本，请重试');
    } finally {
      if (mounted) setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.cancelDownload();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _waitingPermission &&
        !_installing) {
      _resumePermission();
    }
  }

  Future<void> _resumePermission() async {
    _waitingPermission = false;
    try {
      final allowed = await _service.canInstall();
      if (!mounted) return;
      if (allowed) {
        await _install();
      } else {
        setState(() => _message = '尚未允许安装应用');
      }
    } on PlatformException catch (error) {
      if (mounted) _showError(error.message ?? '无法检查安装授权');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final update = await _service.check();
      if (mounted) setState(() => _update = update);
    } on UpdateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    final update = _update;
    if (_downloading || update == null) return;
    setState(() {
      _downloading = true;
      _message = null;
      _received = 0;
    });
    try {
      final file = await _service.download(update, (received, total) {
        if (mounted) setState(() => _received = received);
      });
      if (mounted) setState(() => _package = file);
    } on UpdateCancelled {
      if (mounted) setState(() => _message = '下载已取消');
    } on UpdateException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('下载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _install() async {
    final file = _package;
    final update = _update;
    if (_installing || file == null || update == null) return;
    setState(() => _installing = true);
    try {
      final allowed = await _service.canInstall();
      if (!mounted) return;
      if (!allowed) {
        _waitingPermission = true;
        setState(() => _message = '等待安装授权');
        await _service.openInstallPermission();
        return;
      }
      await _service.install(file, update);
      if (mounted) setState(() => _message = '已打开系统安装器');
    } on PlatformException catch (error) {
      _waitingPermission = false;
      if (mounted) _showError(error.message ?? '无法打开系统安装器');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    return Scaffold(
      appBar: AppBar(title: const Text('应用更新')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hoshi记账', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('当前版本 $_installedVersion'),
          const SizedBox(height: 24),
          if (_checking || !_initialized)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.refresh),
              label: const Text('重新检查'),
            ),
          ] else if (update == null) ...[
            const Text('已是最新版本'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.refresh),
              label: const Text('检查更新'),
            ),
          ] else ...[
            Text(
              '新版本 ${update.version}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${(update.size / 1024 / 1024).toStringAsFixed(1)} MB'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SelectableText(update.notes.isEmpty ? '暂无更新说明' : update.notes),
          ],
        ],
      ),
      bottomNavigationBar: update == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_message != null) ...[
                      Text(_message!),
                      const SizedBox(height: 12),
                    ],
                    if (_downloading) ...[
                      LinearProgressIndicator(value: _received / update.size),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(_received / 1024 / 1024).toStringAsFixed(1)} / ${(update.size / 1024 / 1024).toStringAsFixed(1)} MB',
                            ),
                          ),
                          IconButton(
                            tooltip: '取消下载',
                            onPressed: _service.cancelDownload,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: _installing
                            ? null
                            : (_package == null ? _download : _install),
                        icon: _installing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _package == null
                                    ? Icons.download
                                    : Icons.system_update_alt,
                              ),
                        label: Text(_package == null ? '下载更新' : '安装更新'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
