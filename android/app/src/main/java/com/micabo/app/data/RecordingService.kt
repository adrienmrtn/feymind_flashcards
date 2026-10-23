package com.micabo.app.data

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.micabo.app.MainActivity
import com.micabo.app.R
import com.micabo.app.i18n.AppLocale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File

/** Où en est le micro : rien, en cours (depuis `startedAt`), ou en échec. */
data class RecordingState(val recording: Boolean = false, val startedAt: Long = 0, val failed: Boolean = false)

/**
 * **L'enregistrement d'un cours, en service de premier plan** (type `microphone`).
 *
 * Le micro vivait dans la feuille (`AudioSheet`) : écran verrouillé, Android coupait l'accès au
 * micro d'une app en arrière-plan, et un cours d'une heure et demie s'arrêtait au bout de
 * quelques minutes, sans un mot. Un service de premier plan garde le micro, avec une
 * notification qui dit que l'enregistrement tourne et un bouton pour l'arrêter.
 *
 * Il se démarre seulement depuis la feuille, app visible (Android 14 refuse un service
 * `microphone` démarré en arrière-plan), après l'autorisation du micro. L'enregistrement fini -
 * par le bouton de la feuille, celui de la notification, ou la limite de quatre-vingt-dix
 * minutes - rejoint la barre de l'accueil (`onRecorded`), même si la feuille a été refermée.
 */
class RecordingService : Service() {
    private var recorder: ClassRecorder? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> finish(deliver = true)
            ACTION_CANCEL -> finish(deliver = false)
            else -> begin()
        }
        return START_NOT_STICKY
    }

    private fun begin() {
        if (recorder != null) return
        val startedAt = System.currentTimeMillis()
        // Au premier plan d'abord (Android laisse cinq secondes), puis le micro.
        val foreground = runCatching {
            val type = if (Build.VERSION.SDK_INT >= 30) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(startedAt), type)
        }
        if (foreground.isFailure) {
            Log.w(TAG, "Service du micro refusé", foreground.exceptionOrNull())
            _state.value = RecordingState(failed = true)
            stopSelf()
            return
        }
        val created = ClassRecorder(this)
        if (!created.start(onLimit = { Handler(Looper.getMainLooper()).post { finish(deliver = true) } })) {
            _state.value = RecordingState(failed = true)
            stopForegroundNow()
            stopSelf()
            return
        }
        recorder = created
        _state.value = RecordingState(recording = true, startedAt = startedAt)
    }

    /** Arrête ; l'enregistrement part à la barre (`deliver`), ou est jeté. */
    private fun finish(deliver: Boolean) {
        val current = recorder
        recorder = null
        val file = current?.stop()
        if (current != null) {
            if (file != null && deliver) {
                _state.value = RecordingState()
                runCatching { onRecorded(file) }.onFailure { Log.w(TAG, "Enregistrement non remis", it) }
            } else {
                file?.delete()
                _state.value = RecordingState(failed = deliver)
            }
        }
        stopForegroundNow()
        stopSelf()
    }

    private fun stopForegroundNow() {
        runCatching { ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE) }
    }

    override fun onDestroy() {
        // Le système arrête le service : ce qui a été enregistré n'est pas perdu.
        if (recorder != null) finish(deliver = true)
        super.onDestroy()
    }

    /** La notification de l'enregistrement : le temps qui passe, et « Arrêter ». */
    private fun notification(startedAt: Long): android.app.Notification {
        val localized = AppLocale.wrap(this, Prefs.storedLanguage(this))
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && manager != null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, localized.getString(R.string.x_record_channel), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val open = PendingIntent.getActivity(
            this,
            3,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            4,
            Intent(this, RecordingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentTitle(localized.getString(R.string.x_record_ongoing))
            .setContentText(localized.getString(R.string.x_record_ongoingBody))
            .setWhen(startedAt)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(open)
            .addAction(0, localized.getString(R.string.lesson_import_recordStop), stop)
            .build()
    }

    companion object {
        private const val TAG = "Recording"
        private const val CHANNEL = "recording"
        private const val NOTIFICATION_ID = 21
        private const val ACTION_START = "com.micabo.app.record.START"
        private const val ACTION_STOP = "com.micabo.app.record.STOP"
        private const val ACTION_CANCEL = "com.micabo.app.record.CANCEL"

        private val _state = MutableStateFlow(RecordingState())
        val state: StateFlow<RecordingState> = _state.asStateFlow()

        /** Ce qu'on fait de l'enregistrement fini : la barre de l'accueil (`MicaboApplication`). */
        @Volatile
        var onRecorded: (File) -> Unit = {}

        /**
         * Démarre l'enregistrement, app visible et micro autorisé. Rend faux si Android refuse
         * (autorisation absente, service interdit en arrière-plan).
         */
        fun start(context: Context): Boolean {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
            _state.value = RecordingState()
            return runCatching {
                ContextCompat.startForegroundService(context, Intent(context, RecordingService::class.java).setAction(ACTION_START))
            }.onFailure { Log.w(TAG, "Service du micro non démarré", it) }.isSuccess
        }

        /** Arrête et remet l'enregistrement à la barre. */
        fun stop(context: Context) {
            if (!_state.value.recording) return
            runCatching { context.startService(Intent(context, RecordingService::class.java).setAction(ACTION_STOP)) }
                .onFailure { Log.w(TAG, "Arrêt du micro refusé", it) }
        }

        /** L'échec affiché par la feuille, oublié quand on réessaie ou qu'on la referme. */
        fun clearFailure() {
            if (_state.value.failed) _state.value = RecordingState()
        }
    }
}
