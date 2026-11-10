package com.micabo.app.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.text.SimpleDateFormat
import java.util.Locale

/** Ce que la porte de Mika répond avant une question (`MikaQuota.Gate`). */
enum class MikaGate { ALLOWED, PAYWALL, DAILY_CAP }

/**
 * **Mika, sur une leçon** (`MikaChat`, `LessonMikaView`) : la conversation est gardée dans la
 * leçon ; chaque question part avec les huit derniers tours et les notes de la leçon à plat.
 * Une question offerte, puis Pro, avec un plafond par jour. Le serveur tient la même porte.
 */
class MikaChat(
    private val functions: SupabaseFunctions,
    private val lessons: LessonRepository,
    private val prefs: Prefs,
    /** Une réponse de Mika rapporte `mikaAnswer` ; un exercice expliqué, `exerciseSolved`. */
    private val xp: Xp? = null,
) {
    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(System.currentTimeMillis())

    private val askedToday: Int get() = if (prefs.mikaDay == today()) prefs.mikaDayCount else 0

    fun gate(isPro: Boolean): MikaGate = when {
        isPro -> if (askedToday < PRO_PER_DAY) MikaGate.ALLOWED else MikaGate.DAILY_CAP
        prefs.mikaFreeUsed -> MikaGate.PAYWALL
        else -> MikaGate.ALLOWED
    }

    private fun counted(isPro: Boolean) {
        if (!isPro) prefs.mikaFreeUsed = true
        val day = today()
        prefs.mikaDayCount = if (prefs.mikaDay == day) prefs.mikaDayCount + 1 else 1
        prefs.mikaDay = day
    }

    /** Ajoute la question à la conversation : la réponse se demande ensuite, par `answer`. */
    fun ask(id: String, text: String) {
        val clean = text.trim().take(MESSAGE_CHARACTERS)
        if (clean.isEmpty()) return
        lessons.modify(id) { it.copy(chat = it.chat + ChatMessage(role = "user", text = clean)) }
    }

    /** Demande la réponse au dernier message de l'élève, et la range dans la conversation. */
    suspend fun answer(id: String, isPro: Boolean) {
        val lesson = lessons.lesson(id) ?: return
        val turns = lesson.chat.takeLast(TURNS)
        if (turns.lastOrNull()?.role != "user") return
        val attachment = lesson.themes.joinToString("\n\n") { "${it.title}\n${it.flatNotes()}" }
            .ifBlank { lesson.contextText }
        val reply = ask(turns, lesson.language, lesson.title, attachment)
        val text = reply.str("reply")
        val card = (reply["card"] as? JsonObject)?.let { raw ->
            val front = raw.str("front")
            val back = raw.str("back")
            if (front.isBlank() || back.isBlank()) null else Flashcard(kind = raw.str("kind").ifBlank { "basic" }.takeIf { it == "cloze" } ?: "basic", front = front, back = back) to raw.int("chapter")
        }
        counted(isPro)
        lessons.modify(id) {
            it.copy(chat = it.chat + ChatMessage(role = "assistant", text = text, card = card?.first, cardTheme = card?.second))
        }
        xp?.award(XpReason.MIKA_ANSWER)
    }

    /**
     * **Mika sur un exercice scanné** (« Mika · Exercice ») : la même fonction `mika-chat`, la
     * même porte et le même compte du jour, mais la conversation vit dans `ExerciseSession`, hors
     * de toute leçon. Le texte lu par l'OCR part comme document joint. Rend la réponse.
     */
    suspend fun answerExercise(session: ExerciseSession, isPro: Boolean): String {
        val turns = session.messages.takeLast(TURNS)
        check(turns.lastOrNull()?.role == "user")
        val language = com.micabo.app.i18n.AppLocale.resolved(prefs.profile.value.language).content
        val reply = ask(turns, language, session.title, session.text)
        val text = reply.str("reply")
        counted(isPro)
        session.messages.add(ChatMessage(role = "assistant", text = text))
        // La première explication est l'exercice résolu ; les suivantes, des réponses de Mika.
        xp?.award(if (session.solved) XpReason.MIKA_ANSWER else XpReason.EXERCISE_SOLVED)
        session.solved = true
        return text
    }

    /** L'appel lui-même : les derniers tours, la langue, le niveau et le document joint. */
    private suspend fun ask(turns: List<ChatMessage>, language: String, title: String, attachment: String): JsonObject {
        val profile = prefs.profile.value
        val payload = buildJsonObject {
            putJsonArray("messages") {
                turns.forEach { turn ->
                    add(buildJsonObject {
                        // Le serveur ne connaît que « user » et « mika » (`readTurns`) : un tour
                        // « assistant » était jeté, et Mika oubliait ce qu'elle venait de dire.
                        put("role", if (turn.role == "user") "user" else "mika")
                        put("text", turn.text.take(MESSAGE_CHARACTERS))
                    })
                }
            }
            put("language", language)
            put("level", lessons.levelOf(profile.tier))
            putJsonObject("attachment") {
                put("title", title)
                put("text", attachment.take(ATTACHMENT_CHARACTERS))
            }
        }
        val envelope = functions.call("mika-chat", payload, timeoutMs = 90_000)
        val reply = envelope["answer"] as? JsonObject ?: throw ApiException(502, "invalid", "")
        if (reply.str("reply").isBlank()) throw ApiException(502, "invalid", "")
        return reply
    }

    /** Range la carte proposée par Mika dans la leçon : elle entre dans les flashcards. */
    fun addCard(id: String, messageIndex: Int) {
        lessons.modify(id) { lesson ->
            val message = lesson.chat.getOrNull(messageIndex) ?: return@modify lesson
            val card = message.card ?: return@modify lesson
            if (message.cardAdded || lesson.themes.isEmpty()) return@modify lesson
            val theme = message.cardTheme?.takeIf { it in lesson.themes.indices } ?: lesson.themes.lastIndex
            lesson.copy(
                themes = lesson.themes.mapIndexed { index, value -> if (index == theme) value.copy(flashcards = value.flashcards + card) else value },
                chat = lesson.chat.mapIndexed { index, value -> if (index == messageIndex) value.copy(cardAdded = true) else value },
            )
        }
    }

    fun reset(id: String) = lessons.modify(id) { it.copy(chat = emptyList()) }

    /** L'exercice scanné en cours : il survit à l'écran (le paywall, une rotation), pas à l'app. */
    val exercise = ExerciseSession()

    companion object {
        const val TURNS = 8
        const val MESSAGE_CHARACTERS = 1_500
        const val ATTACHMENT_CHARACTERS = 16_000
        const val PRO_PER_DAY = 30
    }
}

/**
 * **Un exercice scanné et sa conversation** : le texte lu sur la photo, sous un titre, et les
 * échanges avec Mika. Rien ne va dans une leçon : la conversation d'une leçon ne s'écrase pas.
 */
class ExerciseSession {
    var title by mutableStateOf("")
        private set
    var text by mutableStateOf("")
        private set
    val messages = mutableStateListOf<ChatMessage>()
    /** La première explication a été donnée (et son XP comptée). */
    var solved = false

    val isEmpty: Boolean get() = text.isBlank()

    /** Un nouvel exercice : l'ancien et sa conversation s'effacent. */
    fun start(title: String, text: String) {
        this.title = title
        this.text = text
        messages.clear()
        solved = false
    }

    fun ask(text: String) {
        val clean = text.trim().take(MikaChat.MESSAGE_CHARACTERS)
        if (clean.isNotEmpty()) messages.add(ChatMessage(role = "user", text = clean))
    }

    fun clear() = start("", "")
}
