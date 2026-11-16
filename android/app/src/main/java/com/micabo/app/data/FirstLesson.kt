package com.micabo.app.data

import android.content.Context
import androidx.core.content.edit
import com.micabo.app.MicaboApplication

/**
 * **La première leçon choisie au parcours d'accueil** (`FirstLessonIntent`) : un sujet tapé, ou
 * un cours à importer. Rien ne s'écrit avant le paywall : l'accueil de l'app la propose, et
 * l'élève la lance. Le sujet reste sur le téléphone ; il ne part jamais dans les statistiques.
 */
object FirstLesson {
    private const val TOPIC = "firstLesson.topic"
    private const val IMPORT = "firstLesson.import"

    sealed interface Intent {
        data class Topic(val topic: String) : Intent
        data object Import : Intent
    }

    fun save(app: MicaboApplication, topic: String?, import: Boolean) = save(app as Context, topic, import)

    fun save(context: Context, topic: String?, import: Boolean) {
        context.getSharedPreferences("micabo", Context.MODE_PRIVATE).edit {
            if (topic.isNullOrBlank()) remove(TOPIC) else putString(TOPIC, topic.trim())
            putBoolean(IMPORT, import && topic.isNullOrBlank())
        }
    }

    fun pending(context: Context): Intent? {
        val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)
        prefs.getString(TOPIC, null)?.takeIf { it.isNotBlank() }?.let { return Intent.Topic(it) }
        return if (prefs.getBoolean(IMPORT, false)) Intent.Import else null
    }

    /** La leçon proposée est lancée, ou écartée : l'accueil ne la repropose plus. */
    fun clear(context: Context) {
        context.getSharedPreferences("micabo", Context.MODE_PRIVATE).edit {
            remove(TOPIC)
            remove(IMPORT)
        }
    }
}
