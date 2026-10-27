import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val versionParts = flutter.versionName.split('.').map { it.toInt() }
require(versionParts.size == 3) { "Use major.minor.patch+revision in pubspec.yaml" }
val (major, minor, patch) = versionParts
val revision = flutter.versionCode
require(major in 0..20 && minor in 0..99 && patch in 0..999 && revision in 0..999) {
    "Version limits: major <= 20, minor <= 99, patch/revision <= 999"
}
val androidVersionCode = major * 100_000_000 + minor * 1_000_000 + patch * 1_000 + revision
require(androidVersionCode > 0) { "Android versionCode must be positive" }

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) {
    signingFile.inputStream().use { signingProperties.load(it) }
}
val ciBuild = System.getenv("CI").equals("true", ignoreCase = true)
require(!ciBuild || signingFile.exists()) { "CI release signing requires android/key.properties" }

android {
    namespace = "com.hoshi.ledger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hoshi.ledger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = androidVersionCode
        versionName = "${flutter.versionName}.$revision"
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                storeFile = file(requireNotNull(signingProperties.getProperty("storeFile")))
                storePassword = requireNotNull(signingProperties.getProperty("storePassword"))
                keyAlias = requireNotNull(signingProperties.getProperty("keyAlias"))
                keyPassword = requireNotNull(signingProperties.getProperty("keyPassword"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (signingFile.exists()) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
