import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
rootProject.file("local.properties").inputStream().use { localProperties.load(it) }

android {
    namespace = "ir.didebansepehr.dideban_sepehr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = localProperties.getProperty("dideban.ndkVersion") ?: flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ir.didebansepehr.dideban_sepehr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Tink references these annotations without declaring them at runtime.
    // Supply their definitions so R8 can validate the release classpath.
    implementation("com.google.errorprone:error_prone_annotations:2.30.0")
    implementation("com.google.code.findbugs:jsr305:3.0.2")
}
