import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dibaca dari android/key.properties (TIDAK pernah ikut di-commit:
// sudah ada di .gitignore). Isinya:
//   storePassword=... keyPassword=... keyAlias=upload
//   storeFile=/opt/aaron-tools/lifeos/keystore/lifeos-release.jks
// Bila berkas itu tidak ada (mis. build di mesin lain), build masih berjalan
// dengan kunci debug supaya tidak menghambat pengembangan — dan itu DITULIS
// jelas di keluaran build, bukan diam-diam.
val berkasKunci = rootProject.file("key.properties")
val propertiKunci = Properties().apply {
    if (berkasKunci.exists()) berkasKunci.inputStream().use { load(it) }
}
val adaKunciRilis = propertiKunci.getProperty("storeFile")?.isNotBlank() == true &&
    propertiKunci.getProperty("storePassword")?.isNotBlank() == true &&
    propertiKunci.getProperty("keyAlias")?.isNotBlank() == true

if (!adaKunciRilis) {
    // Jujur di keluaran build: jangan sampai ada yang mengira APK-nya sudah
    // bertanda tangan kunci rilis padahal belum.
    println(
        "PERINGATAN: android/key.properties tidak ada / tidak lengkap — build " +
            "rilis memakai KUNCI DEBUG. Jangan kirim ke Play Store. Salin " +
            "android/key.properties.example menjadi android/key.properties."
    )
}

android {
    namespace = "com.personallifeos.personal_life_os"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // F3: flutter_local_notifications 22.x butuh desugaring untuk notifikasi terjadwal.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Keystore rilis (Play App Signing / sideload jangka panjang). Kunci debug
    // bawaan template adalah kunci PUBLIK yang sama di seluruh dunia: siapa pun
    // bisa membuat APK bertanda tangan identik, sehingga update berbahaya bisa
    // dipasang menimpa aplikasi ini tanpa peringatan sistem.
    if (adaKunciRilis) {
        signingConfigs {
            create("release") {
                storeFile = file(propertiKunci.getProperty("storeFile"))
                storePassword = propertiKunci.getProperty("storePassword")
                keyAlias = propertiKunci.getProperty("keyAlias")
                keyPassword = propertiKunci.getProperty("keyPassword")
                    ?: propertiKunci.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.personallifeos.personal_life_os"
        // F3: notifikasi terjadwal (flutter_local_notifications) butuh multidex.
        multiDexEnabled = true
        // Versi SDK DIPATOK (bukan `flutter.minSdkVersion`) supaya build dapat
        // direproduksi: nilai ini yang terbukti dipakai APK rilis (minSdk 24 =
        // Android 7, targetSdk 36 = Android 16). Semua pustaka CPU tetap
        // dipertahankan (perintah pemilik).
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (adaKunciRilis) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // P1-4: rilis sebelumnya tanpa minify/shrink sama sekali sehingga APK
            // membengkak dan mudah dibaca. Aturan keep ada di proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FR-45: FileProvider untuk membagikan berkas laporan.
    implementation("androidx.core:core-ktx:1.13.1")
    // FR-38/FR-50 — OCR di perangkat (model terbundel, tanpa Play Services
    // dan tetap jalan tanpa internet). Konsekuensi jujur: ukuran APK naik.
    implementation("com.google.mlkit:text-recognition:16.0.1")
}
