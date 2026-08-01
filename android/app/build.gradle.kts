import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key, resolved from `android/local.properties` (gitignored,
// machine-local — never committed). Falls back to an empty placeholder so a
// missing key fails at Maps runtime, not at build time. The SHA-1 restriction
// for the *real* key is a MANUAL step in Google Cloud Console — see
// `dart_define.example.json` for details.
//
// NOTE: `java.util.Properties()` (fully qualified) does NOT resolve here —
// the Android/Kotlin Gradle plugins add a `java` extension property to
// `Project` that shadows the `java` top-level package alias inside this
// script's implicit scope, so `java.util` fails to resolve. An explicit
// `import java.util.Properties` sidesteps that shadowing.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

android {
    namespace = "com.ferrematica.express"
    compileSdk = flutter.compileSdkVersion
    // Highest version required across plugins (app_links,
    // flutter_plugin_android_lifecycle, google_maps_flutter_android,
    // isar_community_flutter_libs, path_provider_android,
    // shared_preferences_android, url_launcher_android); NDK is backward
    // compatible so this satisfies all of them.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ferrematica.express"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 21 required by google_maps_flutter; minSdk 23 required by
        // isar_community_flutter_libs (the higher constraint wins).
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
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
