import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ahmedmaamoun.wasla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ahmedmaamoun.wasla"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google Maps key: `--dart-define=MAPS_API_KEY=…` (the app hides the
        // maps without it), else the MAPS_API_KEY environment variable or
        // android/local.properties (not in git).
        val localProps = Properties()
        val localPropsFile = rootProject.file("local.properties")
        if (localPropsFile.exists()) localPropsFile.inputStream().use { localProps.load(it) }
        manifestPlaceholders["mapsApiKey"] = dartDefine("MAPS_API_KEY")
            ?: System.getenv("MAPS_API_KEY") ?: localProps.getProperty("MAPS_API_KEY", "")
    }

    // staging: the build for device testing against the staging project. Its
    // own id and name, so it installs next to any other build.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Wasla")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "وصلة تجريبي")
        }
    }

    // Upload key from android/key.properties (not in git), or from the file
    // named by WASLA_KEY_PROPERTIES: storeFile, storePassword, keyAlias,
    // keyPassword. Without it a release build is signed with the debug key,
    // which runs on a device but the Play Store rejects.
    val keyPropsFile = System.getenv("WASLA_KEY_PROPERTIES")?.let { file(it) }
        ?: rootProject.file("key.properties")
    val keyProps = Properties()
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { keyProps.load(it) }

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Obfuscate code and shrink resources for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            signingConfig = if (keyPropsFile.exists()) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn("wasla: no key.properties, release build signed with the debug key (not for the Play Store)")
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}

// Staging has no Firebase app of its own (google-services.json only knows the
// prod id), so it builds without it; the app then runs with push disabled.
tasks.configureEach {
    if (name.contains("GoogleServices") && name.contains("Staging")) enabled = false
}

/// A `--dart-define` value: Flutter hands them to Gradle base64-encoded in
/// the `dart-defines` property.
fun dartDefine(key: String): String? =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.map { String(Base64.getDecoder().decode(it)) }
        ?.firstOrNull { it.startsWith("$key=") }
        ?.substringAfter("=")
        ?.takeIf { it.isNotEmpty() }
