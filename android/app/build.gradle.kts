import java.util.Properties
import org.yaml.snakeyaml.LoaderOptions
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.constructor.SafeConstructor

buildscript {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        mavenCentral()
    }
    dependencies {
        classpath("org.yaml:snakeyaml:2.3")
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter normalizes a build number of zero to one; read the version source directly.
val pubspec = Yaml(SafeConstructor(LoaderOptions())).load<Map<String, Any>>(
    rootProject.file("../pubspec.yaml").readText()
)
val sourceVersion = requireNotNull(pubspec["version"] as? String)
val parsedVersion = requireNotNull(
    Regex("(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\+(0|[1-9]\\d*)").matchEntire(sourceVersion)
) { "Use major.minor.patch+revision in pubspec.yaml" }
val (major, minor, patch, revision) = parsedVersion.groupValues.drop(1).map { it.toInt() }
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
        versionName = "$major.$minor.$patch.$revision"
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
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
            signingConfig = signingConfigs.getByName(if (signingFile.exists()) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
