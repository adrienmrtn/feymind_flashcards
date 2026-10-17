package com.micabo.app.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.micabo.app.MainActivity
import com.micabo.app.R
import com.micabo.app.i18n.AppLocale
import java.text.DateFormat
import java.util.Date

/**
 * **Le rappel avant la fin de l'essai**, promis par le parcours d'accueil : une notification la
 * veille du dernier jour, pour pouvoir annuler à temps. Posé au moment de l'achat d'une offre
 * avec essai ; une alarme inexacte suffit, à quelques heures près.
 */
object TrialReminder {
    private const val CHANNEL = "trial"
    private const val EXTRA_END = "end"

    fun schedule(context: Context, trialDays: Int, now: Long = System.currentTimeMillis()) {
        if (trialDays < 2) return
        val end = now + trialDays * Srs.DAY
        val at = end - Srs.DAY
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.set(AlarmManager.RTC_WAKEUP, at, pending(context, end))
    }

    private fun pending(context: Context, end: Long): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, TrialReminderReceiver::class.java).putExtra(EXTRA_END, end),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun show(context: Context, end: Long) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val localized = AppLocale.wrap(context, Prefs.storedLanguage(context))
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, localized.getString(R.string.ios_trialReminder_cardTitle), NotificationManager.IMPORTANCE_DEFAULT))
        }
        val date = DateFormat.getDateInstance(DateFormat.LONG).format(Date(end))
        val open = PendingIntent.getActivity(
            context,
            1,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val body = localized.getString(R.string.ios_trialReminder_cardBody, date)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentTitle(localized.getString(R.string.ios_trialReminder_cardTitle))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(7, notification) }
    }

    internal fun endOf(intent: Intent): Long = intent.getLongExtra(EXTRA_END, System.currentTimeMillis() + Srs.DAY)
}

/** L'alarme du rappel : elle montre la notification. */
class TrialReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TrialReminder.show(context, TrialReminder.endOf(intent))
    }
}
