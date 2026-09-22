package com.personallifeos.personal_life_os

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * FR-31 & FR-151 — jembatan isi widget layar utama.
 *
 * Dart menyusun isi (judul, total, tiga baris, tombol aksi); kelas ini hanya
 * menyimpannya untuk dibaca [WidgetHariIni] lalu meminta widget digambar ulang.
 */
class KanalWidget(private val konteks: Context) {

    companion object {
        const val NAMA_SIMPANAN = "lifeos_widget"
    }

    fun pasang(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, "lifeos/widget").setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method != "perbarui") {
                hasil.notImplemented()
                return@setMethodCallHandler
            }
            val baris = panggilan.argument<List<String>>("baris") ?: emptyList()
            val idBaris = panggilan.argument<List<String>>("idBaris") ?: emptyList()
            val simpanan = konteks
                .getSharedPreferences(NAMA_SIMPANAN, Context.MODE_PRIVATE)
                .edit()
            simpanan.putString("judul", panggilan.argument<String>("judul") ?: "Personal Life OS")
            simpanan.putString("total", panggilan.argument<String>("total") ?: "")
            simpanan.putString("catatan", panggilan.argument<String>("catatan") ?: "")
            simpanan.putString("aksiId", panggilan.argument<String>("aksiId") ?: "")
            for (i in 0 until WidgetHariIni.JUMLAH_BARIS) {
                simpanan.putString("baris$i", baris.getOrNull(i) ?: "")
                simpanan.putString("id$i", idBaris.getOrNull(i) ?: "")
            }
            simpanan.apply()
            WidgetHariIni.perbaruiSemua(konteks)
            hasil.success(true)
        }
    }
}
