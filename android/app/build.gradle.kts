import java.io.File
import java.io.FileInputStream
import java.util.Properties


plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}



// 1️⃣ 从 local.properties 中读取 Flutter 写入的版本号
val localProperties = Properties().apply {
    val localPropsFile = rootProject.file("local.properties")
    if (localPropsFile.exists()) {
        load(FileInputStream(localPropsFile))
    }
}

// 如果没取到，就给个默认值防止构建失败
val flutterVersionCode: Int =
    (localProperties.getProperty("flutter.versionCode") ?: "1").toInt()

val flutterVersionName: String =
    localProperties.getProperty("flutter.versionName") ?: "1.0.0"

android {
    namespace = "com.tlmile.autoclick"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            // 这里从 local.properties 中读取参数
            storeFile = localProperties.getProperty("storeFile")
                ?.let { File(rootProject.projectDir, "app/$it") }

            storePassword = localProperties.getProperty("storePassword")
            keyAlias = localProperties.getProperty("keyAlias")
            keyPassword = localProperties.getProperty("keyPassword")
        }
    }



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tlmile.autoclick"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // 先把资源压缩明确关掉，避免当前这个错误
            isMinifyEnabled = true
            isShrinkResources = true   // 🔥 关键修复点

            // 使用我们在 signingConfigs 里定义的 release 签名
            signingConfig = signingConfigs.getByName("release")

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        // 如果需要自定义 debug，可以这样写；不需要可以省略
        getByName("debug") {
            // debug 一般不开混淆和资源压缩
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

//    // 👇 只修改andorid原生 的 自定义 APK 文件名
//    applicationVariants.all {
//        val variantName = name              // debug / release
//        val vName = versionName             // 来自 pubspec.yaml 的 versionName
//        val vCode = versionCode             // 来自 pubspec.yaml 的 versionCode
//        val appName = "autoclick"           // 你想要的 APK 前缀名
//
//        outputs.all {
//            // outputs 的具体实现类，里面才有 outputFileName
//            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
//            outputImpl.outputFileName =
//                "${appName}-v${vName}(${vCode})-${variantName}.apk"
//        }
//    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("com.squareup.okhttp3:okhttp:4.9.0") // 添加 OkHttp 依赖
    implementation("org.json:json:20210307") // 添加 org.json 依赖（用于处理 JSON）
}

flutter {
    source = "../.."
}


// === 重命名 flutter-apk 产物：Release 版本 ===
tasks.register("copyAndRenameFlutterApkRelease") {
    doLast {
        val outputDir = file("$buildDir/outputs/flutter-apk")
        if (!outputDir.exists()) {
            println("flutter-apk dir not found, skip rename (release)")
            return@doLast
        }

        val appName = "autoclick"
        val vName = flutterVersionName
        val vCode = flutterVersionCode

        outputDir.listFiles()?.forEach { file ->
            if (file.isFile && file.extension == "apk" && "release" in file.name) {

                val newName = "${appName}-v${vName}(${vCode})-release.apk"
                val newFile = File(outputDir, newName)

                // 注意：copy 而不是 rename
                file.copyTo(newFile, overwrite = true)

                println("Copied and renamed flutter-apk → $newName")
            }
        }
    }
}


// === 重命名 flutter-apk 产物：Debug 版本（可选） ===
tasks.register("renameFlutterApkDebug") {
    doLast {
        val outputDir = file("$buildDir/outputs/flutter-apk")
        if (!outputDir.exists()) {
            println("flutter-apk dir not found, skip rename (debug)")
            return@doLast
        }

        val appName = "autoclick"
        val vName = flutterVersionName
        val vCode = flutterVersionCode

        outputDir.listFiles()?.forEach { file ->
            if (file.isFile && file.extension == "apk" && "debug" in file.name) {
                val newName = "${appName}-v${vName}(${vCode})-debug.apk"
                val newFile = File(outputDir, newName)
                if (file.renameTo(newFile)) {
                    println("Renamed debug flutter-apk → $newName")
                } else {
                    println("Failed to rename debug flutter-apk: ${file.name}")
                }
            }
        }
    }
}

// ✅ 用 whenTaskAdded 动态关联 assemble 任务，避免 “Task not found” 错误
tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("copyAndRenameFlutterApkRelease")
}




