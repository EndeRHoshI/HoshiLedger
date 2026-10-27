package com.hoshi.ledger

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val updateExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hoshi.ledger/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstall())
                    "openInstallPermission" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")))
                            }
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("permission_unavailable", "无法打开安装授权设置", null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val checksum = call.argument<String>("sha256")
                        val versionCode = call.argument<Number>("versionCode")?.toLong()
                        if (path == null || checksum == null || versionCode == null) {
                            result.error("invalid_package", "安装包信息不完整", null)
                            return@setMethodCallHandler
                        }
                        updateExecutor.execute {
                            try {
                                val apk = validatePackage(path, checksum, versionCode)
                                runOnUiThread {
                                    try {
                                        check(canInstall()) { "请先允许安装应用" }
                                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                                        startActivity(Intent(Intent.ACTION_VIEW)
                                            .setDataAndType(uri, "application/vnd.android.package-archive")
                                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                                        result.success(null)
                                    } catch (error: Exception) {
                                        result.error("install_failed", error.message ?: "无法打开安装器", null)
                                    }
                                }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("invalid_package", error.message ?: "安装包校验失败", null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canInstall(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
        packageManager.canRequestPackageInstalls()

    @Suppress("DEPRECATION")
    private fun validatePackage(path: String, checksum: String, expectedVersion: Long): File {
        val apk = File(path).canonicalFile
        val updateDirectory = File(cacheDir, "updates").canonicalPath + File.separator
        require(apk.path.startsWith(updateDirectory) && apk.isFile && apk.extension == "apk") {
            "安装包路径不正确"
        }
        require(apk.length() in 1..(200L * 1024 * 1024)) { "安装包大小不正确" }
        val digest = MessageDigest.getInstance("SHA-256")
        apk.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        require(hex(digest.digest()) == checksum) { "安装包校验失败，请重新下载" }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val installed = packageManager.getPackageInfo(packageName, flags)
        val archive = requireNotNull(packageManager.getPackageArchiveInfo(apk.path, flags)) { "无法读取安装包" }
        require(archive.packageName == packageName) { "安装包不是 Hoshi 记账" }
        fun code(info: PackageInfo) = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            info.longVersionCode else info.versionCode.toLong()
        require(code(archive) == expectedVersion && code(archive) > code(installed)) { "安装包版本不正确" }
        fun signers(info: PackageInfo): Set<String> {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                info.signingInfo?.apkContentsSigners else info.signatures
            return signatures.orEmpty().map {
                hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray()))
            }.toSet()
        }
        val currentSigners = signers(installed)
        require(currentSigners.isNotEmpty() && currentSigners == signers(archive)) {
            "安装包签名与当前应用不同，已停止安装"
        }
        return apk
    }

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }

    override fun onDestroy() {
        updateExecutor.shutdown()
        super.onDestroy()
    }
}
