plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.naipingzai.flutter_file_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.naipingzai.flutter_file_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 只支持 Android 15 (API 35) 及以上，旧系统不再支持
        minSdk = 35
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // C++ FFI 静态库打包为 libfileops.so
        // 仅 arm64-v8a（对应依赖仓库 FFmpeg 产物；减少 APK 体积）
        ndk {
            // 仅 arm64-v8a：先清空默认 ABI，再加入 arm64，避免编出无对应 FFmpeg 库的 ABI
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += "-DANDROID_STL=c++_static"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
