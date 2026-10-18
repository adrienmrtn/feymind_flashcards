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
import androidx.core.content.edit
import com.micabo.app.MainActivity
import com.micabo.app.R
import com.micabo.app.i18n.AppLocale
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.util.Calendar
import java.util.TimeZone

/**
 * **Le rappel du jour** (`DailyReminder` sur iPhone) : une notification par jour, à 18 h, dont
 * le texte suit ce que l'élève a déjà fait. Sans leçon, elle l'invite à importer un cours ;
 * avec des leçons, elle nomme celle sur laquelle s'entraîner (celle qui a le plus de cartes
 * dues d'abord, puis chacune à son tour les jours suivants).
 *
 * **Personne en période d'essai ne la reçoit** : les rappels commencent le jour où l'essai
 * finit, qu'il devienne un abonnement ou non. Quatorze jours sont posés d'avance, et reposés
 * au lancement et à chaque passage en arrière-plan : le texte suit les leçons, et le rappel du
 * jour saute quand l'élève a déjà travaillé. Sans l'autorisation des notifications, rien.
 */
object DailyReminder {
    const val DAYS = 14
    /** L'heure du rappel : celle que l'iPhone propose quand le parcours ne l'a pas demandée. */
    const val DEFAULT_HOUR = 18
    private const val CHANNEL = "daily"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_BODY = "body"
    private const val PLAN_KEY = "daily.plan"
    /** Les codes des alarmes, loin de ceux du rappel d'essai. */
    private const val REQUEST_BASE = 100

    @Serializable
    data class Planned(val at: Long, val title: String, val body: String)

    /**
     * **Le plan, sans rien toucher.** `courseTitles` du plus pressant au moins pressant (vide
     * sans leçon) ; `trialEndsAt` la fin de l'essai en cours, `null` hors essai.
     */
    fun plan(
        courseTitles: List<String>,
        trialEndsAt: Long?,
        studiedToday: Boolean,
        hour: Int,
        now: Long,
        text: (Int, String?) -> String,
    ): List<Planned> {
        val planned = mutableListOf<Planned>()
        val day = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        for (offset in 0 until DAYS) {
            val fire = (day.clone() as Calendar).apply { set(Calendar.HOUR_OF_DAY, hour) }.timeInMillis
            val dayStart = day.timeInMillis
            day.add(Calendar.DAY_OF_YEAR, 1)
            if (fire <= now) continue
            if (offset == 0 && studiedToday) continue
            if (trialEndsAt != null && fire < trialEndsAt) continue
            // Le texte tourne avec le jour du calendrier : reposé le lendemain, le plan ne
            // recommence pas par la même phrase.
            val ordinal = ((dayStart + TimeZone.getDefault().getOffset(dayStart)) / Srs.DAY).toInt()
            val variant = ordinal % 2
            val (title, body) = if (courseTitles.isEmpty()) {
                if (variant == 0) text(R.string.ios_reminder_import1_title, null) to text(R.string.ios_reminder_import1_body, null)
                else text(R.string.ios_reminder_import2_title, null) to text(R.string.ios_reminder_import2_body, null)
            } else {
                val course = courseTitles[planned.size % courseTitles.size]
                text(R.string.ios_reminder_practice_title, course) to
                    text(if (variant == 0) R.string.ios_reminder_practice_body1 else R.string.ios_reminder_practice_body2, null)
            }
            planned.add(Planned(fire, title, body))
        }
        return planned
    }

    /** **Repose les rappels** d'après les leçons, l'essai et le travail du jour. */
    fun reschedule(context: Context, lessons: Collection<Lesson>, trialEndsAt: Long?, studiedToday: Boolean, now: Long = System.currentTimeMillis()) {
        cancelAll(context)
        if (!allowed(context)) {
            store(context, emptyList())
            return
        }
        val courses = lessons
            .filter { it.title.isNotBlank() }
            .sortedWith(compareByDescending<Lesson> { it.dueCards(now) }.thenByDescending { maxOf(it.openedAt, it.createdAt) })
            .map { it.title }
        val localized = AppLocale.wrap(context, Prefs.storedLanguage(context))
        val planned = plan(courses, trialEndsAt, studiedToday, DEFAULT_HOUR, now) { id, course ->
            if (course != null) localized.getString(id, course) else localized.getString(id)
        }
        store(context, planned)
        arm(context, planned, now)
    }

    /** Après un redémarrage : les rappels encore à venir reviennent tels qu'ils étaient posés. */
    fun rearm(context: Context) {
        if (!allowed(context)) return
        val stored = context.getSharedPreferences("micabo", Context.MODE_PRIVATE).getString(PLAN_KEY, null) ?: return
        val planned = runCatching { MicaboJson.decodeFromString(ListSerializer(Planned.serializer()), stored) }.getOrNull() ?: return
        arm(context, planned, System.currentTimeMillis())
    }

    private fun arm(context: Context, planned: List<Planned>, now: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        planned.withIndex().filter { it.value.at > now }.forEach { (index, reminder) ->
            // Une alarme inexacte suffit : à quelques minutes près, le rappel reste le bon.
            alarms.set(AlarmManager.RTC_WAKEUP, reminder.at, pending(context, index, reminder))
        }
    }

    private fun cancelAll(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        repeat(DAYS) { index -> alarms.cancel(pending(context, index, null)) }
    }

    private fun pending(context: Context, index: Int, reminder: Planned?): PendingIntent {
        val intent = Intent(context, DailyReminderReceiver::class.java)
        if (reminder != null) intent.putExtra(EXTRA_TITLE, reminder.title).putExtra(EXTRA_BODY, reminder.body)
        return PendingIntent.getBroadcast(context, REQUEST_BASE + index, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun store(context: Context, planned: List<Planned>) {
        context.getSharedPreferences("micabo", Context.MODE_PRIVATE).edit {
            putString(PLAN_KEY, MicaboJson.encodeToString(ListSerializer(Planned.serializer()), planned))
        }
    }

    private fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    internal fun show(context: Context, intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        if (!allowed(context)) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            val name = AppLocale.wrap(context, Prefs.storedLanguage(context)).getString(R.string.x_reminder_channel)
            manager.createNotificationChannel(NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(
            context,
            2,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(8, notification) }
    }
}

/** L'alarme du rappel du jour : elle montre la notification. */
class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DailyReminder.show(context, intent)
    }
}
