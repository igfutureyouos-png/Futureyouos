plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.futureyou.futureyouos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.futureyou.futureyouos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        
        // 🔥 MUST be HIGHER than your last version
        versionCode = 3
        versionName = "3.0.0"

        multiDexEnabled = true

        // 🔥 REQUIRED — fixes your Play Store error
        ndk {
            abiFilters "armeabi-v7a", "arm64-v8a"
        }
    }

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
            isDebuggable = true
        }

        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Optional but recommended for correct ABI packaging
    splits {
        abi {
            enable true
            reset()
            include "armeabi-v7a", "arm64-v8a"
            universalApk false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
