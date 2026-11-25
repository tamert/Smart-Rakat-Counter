package com.tamer.rekat

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.text.SpannableString
import android.text.style.RelativeSizeSpan
import android.view.WindowManager
import android.widget.Button
import java.io.BufferedWriter
import java.io.File
import java.io.Writer
import java.text.SimpleDateFormat
import java.util.Date

// Kayıt modu (sadece debug build): tüm sensörleri ~50 Hz CSV'ye yazar. Satır: t_ns,sensor,v0,v1,...
// Dosyalar: files/kayit_*.csv  (adb exec-out run-as com.tamer.rekat cat files/<ad>)
class MainActivity : Activity(), SensorEventListener {
    private lateinit var sm: SensorManager
    private lateinit var btn: Button
    private val handler = Handler(HandlerThread("sensors").apply { start() }.looper)
    @Volatile private var out: BufferedWriter? = null
    // ponytail: activity + wake lock; ekran kapanınca veri kesilirse foreground service'e geç
    private lateinit var wake: PowerManager.WakeLock
    // Mağaza (release) sürümü dosya yazmaz, sadece gravity dinler, izin istemez.
    private val kayit by lazy { applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 }

    // Canlı sayım (rekat.py ile aynı eşikler). Sadece sensör thread'inde değişir.
    private var winStart = 0L; private var n = 0
    private var sx = 0f; private var sy = 0f; private var sz = 0f
    private var run = '.'; private var runStart = 0L
    private var rekat = 0; private var secdeGoruldu = true

    private fun durus(x: Float, y: Float, z: Float) = when {
        z < -3 && x > 4 && x < 8 -> 'K'
        x > 8.5 -> 'R'
        z > 2 && x > 5 -> 'S'
        z > 5 && x < 4.5 -> 'O'
        else -> '.'
    }

    // 0.5 sn'lik pencere ortalamasıyla duruş; secdeden sonra 5 sn kıyam = yeni rekat
    private fun say(e: SensorEvent, w: BufferedWriter) {
        if (n == 0) winStart = e.timestamp
        sx += e.values[0]; sy += e.values[1]; sz += e.values[2]; n++
        if (e.timestamp - winStart < 500_000_000L) return
        val d = durus(sx / n, sy / n, sz / n)
        sx = 0f; sy = 0f; sz = 0f; n = 0
        if (d != run) { run = d; runStart = winStart }
        val sure = e.timestamp - runStart
        if (d == 'S' && sure >= 1_000_000_000L) secdeGoruldu = true
        if (d == 'K' && sure >= 5_000_000_000L && secdeGoruldu) {
            secdeGoruldu = false
            rekat++
            w.write("# rekat $rekat ${e.timestamp}\n")
            getSystemService(Vibrator::class.java)
                .vibrate(VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE))
            val r = rekat
            runOnUiThread { btn.text = buyuk("$r", resources.getQuantityString(R.plurals.rakat, r)) }
        }
    }

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        sm = getSystemService(SensorManager::class.java)
        wake = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "rekat:kayit")
        if (kayit && checkSelfPermission(android.Manifest.permission.BODY_SENSORS) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(arrayOf(android.Manifest.permission.BODY_SENSORS), 1)
        btn = Button(this).apply {
            textSize = 18f
            text = getString(R.string.start)
            setBackgroundColor(0xFF1B8A3A.toInt())
            setOnClickListener { if (out == null) start() }
            // secdede bileğe yanlışlıkla dokunma durdurmasın diye uzun basış
            setOnLongClickListener { if (out != null) stop(); true }
        }
        setContentView(btn)
    }

    private fun start() {
        val name = "kayit_" + SimpleDateFormat("yyyyMMdd_HHmmss").format(Date()) + ".csv"
        val w = if (kayit) File(filesDir, name).bufferedWriter() else BufferedWriter(bosYazici)
        val sensors = if (kayit) sm.getSensorList(Sensor.TYPE_ALL)
            .filter { !it.isWakeUpSensor && it.reportingMode != Sensor.REPORTING_MODE_ONE_SHOT }
        else listOfNotNull(sm.getDefaultSensor(Sensor.TYPE_GRAVITY))
        sensors.forEach { w.write("# ${it.stringType} | ${it.name} | ${it.vendor}\n") }
        n = 0; run = '.'; rekat = 0; secdeGoruldu = true
        out = w
        wake.acquire(60 * 60 * 1000L)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        sensors.forEach { sm.registerListener(this, it, 20_000, handler) }
        // kayıtta dikkat çekmesin: siyah zemin, soluk gri yazı
        btn.setBackgroundColor(0xFF000000.toInt())
        btn.setTextColor(0xFF3A3A3A.toInt())
        btn.text = buyuk("0", resources.getQuantityString(R.plurals.rakat, 0))
    }

    // Writer.nullWriter() API 33+, minSdk 30
    private val bosYazici = object : Writer() {
        override fun write(c: CharArray, o: Int, l: Int) {}
        override fun flush() {}
        override fun close() {}
    }

    private fun buyuk(sayi: String, alt: String) = SpannableString("$sayi\n$alt")
        .apply { setSpan(RelativeSizeSpan(3.5f), 0, sayi.length, 0) }

    private fun stop() {
        sm.unregisterListener(this)
        handler.post { out?.close(); out = null }
        if (wake.isHeld) wake.release()
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        btn.setBackgroundColor(0xFFC62828.toInt())
        btn.setTextColor(0xFFFFFFFF.toInt())
        btn.text = buyuk("$rekat", resources.getQuantityString(R.plurals.rakat, rekat) + "\n" + getString(R.string.done))
    }

    override fun onSensorChanged(e: SensorEvent) {
        val w = out ?: return
        w.write("${e.timestamp},${e.sensor.stringType}")
        for (v in e.values) { w.write(","); w.write(v.toString()) }
        w.write("\n")
        if (e.sensor.type == Sensor.TYPE_GRAVITY) say(e, w)
    }

    override fun onAccuracyChanged(s: Sensor, a: Int) {}

    override fun onDestroy() { if (out != null) stop(); super.onDestroy() }
}
