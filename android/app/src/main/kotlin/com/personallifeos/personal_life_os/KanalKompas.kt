package com.personallifeos.personal_life_os

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// FR-98 — arah hadap perangkat (kompas) untuk layar Kiblat.
///
/// Memakai sensor ROTATION_VECTOR (hasil gabungan accelerometer, gyroscope dan
/// magnetometer) lalu menambah koreksi deklinasi magnetik lewat
/// [SensorManager.getOrientation] → azimuth derajat dari Utara.
///
/// Bila perangkat TIDAK punya sensor kompas, kanal ini mengirim `null` dan
/// Dart memakai mode arah mata angin — tidak ada angka palsu.
class KanalKompas : SensorEventListener, EventChannel.StreamHandler {
    companion object {
        const val namaSaluran: String = "plo/kompas"
        private const val namaSaluranArah: String = "plo/kompas/arah"

        fun pasang(flutterEngine: FlutterEngine, konteks: Context) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, namaSaluran)
                .setMethodCallHandler { panggilan, hasil ->
                    when (panggilan.method) {
                        "sensorAda" -> hasil.success(punyaSensor(konteks))
                        else -> hasil.notImplemented()
                    }
                }
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, namaSaluranArah)
                .setStreamHandler(KanalKompas(konteks))
        }

        private fun punyaSensor(konteks: Context): Boolean {
            val sm = konteks.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                ?: return false
            return sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null
        }
    }

    private val konteks: Context
    private var peristiwa: EventChannel.EventSink? = null
    private var sensor: Sensor? = null
    private val matriksRotasi = FloatArray(9)
    private val sudutOrientasi = FloatArray(3)

    constructor(konteks: Context) {
        this.konteks = konteks
    }

    override fun onListen(argumen: Any?, sink: EventChannel.EventSink?) {
        peristiwa = sink
        val sm = konteks.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val s = sm?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (sm == null || s == null) {
            // Tidak ada sensor: kirim null supaya Dart memakai arah mata angin.
            sink?.success(null)
            return
        }
        sensor = s
        sm.registerListener(this, s, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(argumen: Any?) {
        val sm = konteks.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        if (sm != null) sm.unregisterListener(this)
        peristiwa = null
        sensor = null
    }

    /// Arah hadap terakhir yang BENAR-BENAR dibaca sensor (null = belum ada).
    /// Dipakai supaya perubahan akurasi tidak pernah mengirim arah palsu.
    private var derajatTerakhir: Float? = null
    private var galatTerakhir: Double? = null

    override fun onSensorChanged(peristiwa: SensorEvent?) {
        val e = peristiwa ?: return
        SensorManager.getRotationMatrixFromVector(matriksRotasi, e.values)
        SensorManager.getOrientation(matriksRotasi, sudutOrientasi)
        var derajat = Math.toDegrees(sudutOrientasi[0].toDouble()).toFloat()
        if (derajat < 0) derajat += 360f
        derajatTerakhir = derajat
        kirim()
    }

    override fun onAccuracyChanged(sensor: Sensor?, akurasi: Int) {
        // Sensor tidak melaporkan galat derajat langsung; kita petakan tingkat
        // akurasi Android ke perkiraan galat supaya layar bisa menyarankan
        // kalibrasi. Bila arah belum pernah terbaca, TIDAK ada yang dikirim
        // (arah 0° tidak boleh muncul sebagai "Utara" palsu).
        galatTerakhir = when (akurasi) {
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> null
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 12.0
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 25.0
            else -> 40.0
        }
        kirim()
    }

    private fun kirim() {
        val derajat = derajatTerakhir ?: return
        peristiwa?.success(
            mapOf("derajat" to derajat.toDouble(), "akurasi" to galatTerakhir)
        )
    }
}
