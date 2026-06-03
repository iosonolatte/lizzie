plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.kotlinMultiplatform)
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    sourceSets {
        androidMain.dependencies {
            implementation(project(":shared"))
            implementation(libs.androidx.activity.compose)
            implementation(libs.androidx.lifecycle.viewmodel)
            implementation(libs.kotlinx.coroutines.core)
        }
    }
}

android {
    namespace = "com.lizzie.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.lizzie.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // Bundle KataGo native binary and resources into APK assets
    // Built using: cd katago-mobile && bash scripts/build-android.sh
    // Expected output: katago-mobile/out/android/arm64-v8a/katago
    sourceSets {
        getByName("main") {
            assets.srcDirs(
                "src/androidMain/assets",
                "../katago-mobile/out/android",
            )
        }
    }
}