package com.personallifeos.personal_life_os

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * FR-31 & FR-151 — widget "Tagihan 7 hari" di layar utama.
 *
 * Menampilkan tagihan yang dikirim aplikasi, dan setiap ketukan membawa
 * pengguna (atau langsung menjalankan aksi) ke halaman yang benar:
 * * baris tagihan  → buka daftar tagihan;
 * * tombol centang  → tandai tagihan itu lunas (aksi dijalankan saat aplikasi
 *   terbuka, jadi datanya tetap satu sumber dengan aplikasi);
 * * tombol "Catat pengeluaran" → buka form pengeluaran.
 */
class WidgetHariIni : AppWidgetProvider() {

    companion object {
        const val JUMLAH_BARIS = 3

        fun perbaruiSemua(konteks: Context) {
            val pengelola = AppWidgetManager.getInstance(konteks)
            val komponen = ComponentName(konteks, WidgetHariIni::class.java)
            val ids = pengelola.getAppWidgetIds(komponen)
            for (id in ids) {
                pengelola.updateAppWidget(id, tampilan(konteks))
            }
        }

        private fun niatAksi(konteks: Context, kode: Int, aksi: Map<String, String>): PendingIntent {
            val niat = Intent(konteks, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                for ((kunci, nilai) in aksi) putExtra(kunci, nilai)
            }
            return PendingIntent.getActivity(
                konteks, kode, niat,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun tampilan(konteks: Context): RemoteViews {
            val views = RemoteViews(konteks.packageName, R.layout.widget_hari_ini)
            val p = konteks.getSharedPreferences(KanalWidget.NAMA_SIMPANAN, Context.MODE_PRIVATE)
            val aksiId = p.getString("aksiId", "") ?: ""

            views.setTextViewText(R.id.widget_judul, p.getString("judul", "Personal Life OS") ?: "")
            views.setTextViewText(R.id.widget_total, p.getString("total", "") ?: "")
            views.setTextViewText(R.id.widget_catatan, p.getString("catatan", "") ?: "")

            val barisId = intArrayOf(R.id.widget_baris1, R.id.widget_baris2, R.id.widget_baris3)
            val centangId = intArrayOf(R.id.widget_centang1, R.id.widget_centang2, R.id.widget_centang3)
            for (i in 0 until JUMLAH_BARIS) {
                val teks = p.getString("baris$i", "") ?: ""
                val idTagihan = p.getString("id$i", "") ?: ""
                views.setTextViewText(barisId[i], teks)
                views.setViewVisibility(barisId[i], if (teks.isEmpty()) View.GONE else View.VISIBLE)
                if (teks.isEmpty()) {
                    views.setViewVisibility(centangId[i], View.GONE)
                } else {
                    views.setViewVisibility(centangId[i], View.VISIBLE)
                    // Menekan baris = membuka daftar tagihan.
                    views.setOnClickPendingIntent(
                        barisId[i],
                        niatAksi(konteks, 100 + i, mapOf("rute" to "/tagihan"))
                    )
                    if (idTagihan.isEmpty()) {
                        views.setViewVisibility(centangId[i], View.GONE)
                    } else {
                        views.setOnClickPendingIntent(
                            centangId[i],
                            niatAksi(
                                konteks, 200 + i,
                                mapOf("aksi" to "lunas", "id" to idTagihan)
                            )
                        )
                    }
                }
            }

            if (aksiId.isEmpty()) {
                views.setViewVisibility(R.id.widget_tombol_lunas, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_tombol_lunas, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.widget_tombol_lunas,
                    niatAksi(konteks, 300, mapOf("aksi" to "lunas", "id" to aksiId))
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_tombol_catat,
                niatAksi(konteks, 301, mapOf("aksi" to "tambah-pengeluaran"))
            )
            return views
        }
    }

    override fun onUpdate(
        konteks: Context,
        pengelola: AppWidgetManager,
        ids: IntArray
    ) {
        for (id in ids) {
            pengelola.updateAppWidget(id, tampilan(konteks))
        }
    }
}
