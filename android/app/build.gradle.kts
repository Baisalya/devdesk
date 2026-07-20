import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun signingValue(property: String, environment: String): String? {
    return (signingProperties[property] as String?)
        ?.takeIf { it.isNotBlank() }
        ?: System.getenv(environment)?.takeIf { it.isNotBlank() }
}

val releaseStoreFile = signingValue("storeFile", "DEVDESK_ANDROID_STORE_FILE")
val releaseStorePassword =
    signingValue("storePassword", "DEVDESK_ANDROID_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "DEVDESK_ANDROID_KEY_ALIAS")
val releaseKeyPassword =
    signingValue("keyPassword", "DEVDESK_ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val releaseTaskRequested = gradle.startParameter.taskNames.any { task ->
    task.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "DevDesk release signing is not configured. Supply key.properties " +
            "outside source control or the DEVDESK_ANDROID_* environment variables. " +
            "Debug signing is intentionally forbidden for release artifacts.",
    )
}

android {
    namespace = "com.baishalya.devdesk"
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
        applicationId = "com.baishalya.devdesk"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        debug {
            // Cleartext is enabled only by src/debug/AndroidManifest.xml for
            // local API-development workflows.
        }
        release {
            isDebuggable = false
            isMinifyEnabled = false
            // Flutter's Android defaults may enable resource shrinking for
            // release builds. Keep it paired with the code-shrinking choice;
            // AGP rejects shrinkResources=true when minification is disabled,
            // even while configuring an unrelated debug build.
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
