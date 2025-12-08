plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.futureyou.futureyouos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Use Java 17 to match AGP 8.x requirements
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Align Kotlin bytecode with Java 17
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID matching Firebase registration
        applicationId = "com.futureyou.futureyouos"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 2
        versionName = "2.0.0"
        multiDexEnabled = true
    }

    /**
     * Release signing config for Play Store (AAB)
     *
     * Uses the upload-keystore.jks committed in android/app and
     * environment variables provided by GitHub Actions (or local defaults).
     */
    signingConfigs {
        create("release") {
            val keyAliasEnv = System.getenv("KEY_ALIAS")
            val storePasswordEnv = System.getenv("STORE_PASSWORD")
            val keyPasswordEnv = System.getenv("KEY_PASSWORD")

            keyAlias = keyAliasEnv ?: "upload"
            storeFile = file("upload-keystore.jks")
            storePassword = storePasswordEnv ?: "pass123"
            keyPassword = keyPasswordEnv ?: "pass123"
        }
    }

    buildTypes {
        getByName("debug") {
            // Keep default debug behaviour
            isDebuggable = true
        }
        getByName("release") {
            // Play Store release: signed, non-debuggable
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for Java 8/11+ APIs on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Enable multidex for apps with many method references
    implementation("androidx.multidex:multidex:2.0.1")
}
