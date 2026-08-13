import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zaboon.zaboon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zaboon.zaboon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ═══ إعداد توقيع الإصدار من key.properties (مستثنى من git) ═══
    signingConfigs {
        create("release") {
            val props = Properties().apply {
                val f = rootProject.file("key.properties")
                if (f.exists()) FileInputStream(f).use { load(it) }
            }
            storeFile = file("zaboon-release.jks")
            storePassword = props.getProperty("storePassword") ?: "missing"
            keyAlias = props.getProperty("keyAlias") ?: "missing"
            keyPassword = props.getProperty("keyPassword") ?: "missing"
        }
    }

    buildTypes {
        release {
            // ═══ توقيع release بمفتاح خاص (zaboon-release.jks) — مو debug ═══
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
