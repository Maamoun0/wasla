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
        // Google Maps key from the MAPS_API_KEY environment variable or
        // android/local.properties (not in git). Empty: the map shows an
        // error tile instead of crashing.
        val localProps = Properties()
        val localPropsFile = rootProject.file("local.properties")
        if (localPropsFile.exists()) localPropsFile.inputStream().use { localProps.load(it) }
        manifestPlaceholders["mapsApiKey"] =
            System.getenv("MAPS_API_KEY") ?: localProps.getProperty("MAPS_API_KEY", "")
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
