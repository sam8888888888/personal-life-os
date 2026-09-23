# Aturan ProGuard/R8 untuk Personal Life OS.
#
# Hasil audit 23 Sep 2026 (P1-4): rilis sebelumnya TIDAK memakai minify sama
# sekali — APK membengkak dan kode mudah dibaca. Sekarang minify + shrinkResources
# menyala, dengan aturan "keep" yang cukup untuk pustaka yang dipanggil lewat
# nama kelas (refleksi) atau lewat manifes/manifest-merger.

# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── ML Kit OCR (model terbundel, tanpa Play Services) ────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text** { *; }
-keep class com.google.android.gms.internal.mlkit_common** { *; }
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# ── Notifikasi terjadwal (receiver dipanggil sistem lewat nama kelas) ───────
-keep class com.dexterous.** { *; }

# ── Pekerja latar (Workmanager memanggil kelas pekerja lewat nama) ──────────
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
-keep class * extends androidx.work.CoroutineWorker

# ── Kanal aplikasi sendiri yang dirujuk manifes/niat ────────────────────────
-keep class com.personallifeos.personal_life_os.MainActivity { *; }
-keep class com.personallifeos.personal_life_os.WidgetHariIni { *; }
-keep class * implements android.appwidget.AppWidgetProvider
-keep class * extends androidx.core.content.FileProvider

# ── JSON (payload notifikasi & konfigurasi plugin) ──────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class org.json.** { *; }

# ── Anggota yang sengaja ditandai @Keep ─────────────────────────────────────
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-keep @androidx.annotation.Keep class * { *; }

# ── Sisa peringatan yang tidak memengaruhi aplikasi ─────────────────────────
-dontwarn org.sqlite.**
-dontwarn javax.annotation.**
