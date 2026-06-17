plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sr.player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.sr.player"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ نسخ APK إلى جذر مشروع Flutter (حيث يتوقعه أمر `flutter build`)
gradle.projectsEvaluated {
    tasks.matching { it.name == "assembleRelease" }.all {
        doLast {
            val src = file("${buildDir}/outputs/apk/release/app-release.apk")
            // الخروج من android/ إلى جذر المشروع
            val rootFlutterDir = file("${rootProject.projectDir}/..")
            val dest = file("${rootFlutterDir}/build/app/outputs/flutter-apk/app-release.apk")
            if (src.exists()) {
                dest.parentFile.mkdirs()
                src.copyTo(dest, overwrite = true)
                println("✅ تم نسخ APK إلى: ${dest.absolutePath}")
            } else {
                println("⚠️ لم يتم العثور على APK المصدر: ${src.absolutePath}")
            }
        }
    }
}