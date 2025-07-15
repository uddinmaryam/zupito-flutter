plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zupito"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.zupito"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    lint {
        checkReleaseBuilds = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // REQUIRED: These lines are essential for Android themes and UI components
    implementation("androidx.appcompat:appcompat:1.6.1") // Corrected syntax for Kotlin DSL
    implementation("com.google.android.material:material:1.12.0") // Corrected syntax for Kotlin DSL

    // Your existing dependencies
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
