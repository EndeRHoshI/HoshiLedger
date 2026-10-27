class AppUpdate {
  static const repository = 'EndeRHoshI/HoshiLedger';
  static const packageName = 'com.hoshi.ledger';
  static const maxApkSize = 200 * 1024 * 1024;

  final String version;
  final int versionCode;
  final Uri apkUrl;
  final String sha256;
  final int size;
  final String notes;

  const AppUpdate({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.size,
    required this.notes,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    final name = json['version'];
    if (json['schemaVersion'] != 1 ||
        json['packageName'] != packageName ||
        name is! String ||
        !RegExp(
          r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
        ).hasMatch(name)) {
      throw const FormatException('更新信息格式不正确');
    }
    final parts = name.split('.').map(int.parse).toList();
    if (parts[0] > 20 || parts[1] > 99 || parts[2] > 999 || parts[3] > 999) {
      throw const FormatException('更新版本号超出范围');
    }
    final code =
        parts[0] * 100000000 + parts[1] * 1000000 + parts[2] * 1000 + parts[3];
    final expectedUrl =
        'https://github.com/$repository/releases/download/v$name/HoshiLedger-v$name.apk';
    final digest = json['sha256'];
    final size = json['size'];
    final notes = json['notes'];
    if (code <= 0 ||
        json['versionCode'] != code ||
        json['apkUrl'] != expectedUrl ||
        digest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        size is! int ||
        size <= 0 ||
        size > maxApkSize ||
        notes is! String) {
      throw const FormatException('更新信息校验失败');
    }
    return AppUpdate(
      version: name,
      versionCode: code,
      apkUrl: Uri.parse(expectedUrl),
      sha256: digest,
      size: size,
      notes: notes,
    );
  }
}
