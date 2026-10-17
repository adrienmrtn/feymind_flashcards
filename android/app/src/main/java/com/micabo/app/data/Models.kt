package com.micabo.app.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull

/** Le JSON de toute l'app : tolérant à ce qu'il ne connaît pas, comme l'app iPhone. */
val MicaboJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    explicitNulls = false
    encodeDefaults = true
    isLenient = true
}

/**
 * **Une leçon**, telle que le plan de `generate-lesson` la décrit, ses thèmes remplis au fil de
 * l'eau, et la progression de l'élève. Gardée en JSON dans `files/lessons/<id>.json`.
 */
@Serializable
data class Lesson(
    val id: String,
    val title: String,
    val subject: String = "",
    val icon: String = "livre-ouvert",
    val createdAt: Long = 0,
    val openedAt: Long = 0,
    val language: String = "en",
    val source: String = "topic",
    val topic: String = "",
    val contextText: String = "",
    val intro: Intro = Intro(),
    val takeaways: List<String> = emptyList(),
    val groups: List<Group> = emptyList(),
    val shortened: Boolean = false,
    val singleQuiz: Boolean = false,
    val themes: List<Theme> = emptyList(),
    val tone: Int = 0,
    val progress: Progress = Progress(),
    /** Le jour de l'examen qui porte sur la leçon, en millisecondes ; 0 sans examen. */
    val examDate: Long = 0,
    /** La conversation avec Mika sur cette leçon, gardée sur le téléphone. */
    val chat: List<ChatMessage> = emptyList(),
    /** La dernière modification, en millisecondes : la synchronisation garde la plus récente. */
    val updatedAt: Long = 0,
    /** Qui voit la leçon (`CourseVisibility`) : `friends` ou `private` ; nul tant qu'on ne l'a pas lu ni choisi. */
    val visibility: String? = null,
) {
    /**
     * La leçon avec un identifiant stable pour chaque thème et chaque carte : ce sont les
     * lignes `chapters` et `flashcards` de la synchronisation, qu'un iPhone relit.
     */
    fun stamped(): Lesson {
        if (themes.all { theme -> theme.id.isNotEmpty() && theme.flashcards.all { it.id.isNotEmpty() } }) return this
        return copy(themes = themes.map { theme ->
            theme.copy(
                id = theme.id.ifEmpty { newId() },
                flashcards = theme.flashcards.map { card -> if (card.id.isEmpty()) card.copy(id = newId()) else card },
            )
        })
    }

    /** L'examen, s'il est encore à venir (aujourd'hui compris). */
    fun upcomingExam(now: Long = System.currentTimeMillis()): Long? =
        examDate.takeIf { it > 0 && it >= startOfDay(now) }

    val readyThemes: Int get() = themes.count { it.status == ThemeStatus.READY }
    val isWriting: Boolean get() = themes.any { it.status == ThemeStatus.PENDING }

    /** Toutes les questions de la leçon, thème par thème. */
    fun questions(themeIndexes: List<Int>? = null): List<Pair<Int, Question>> =
        themes.withIndex()
            .filter { themeIndexes == null || it.index in themeIndexes }
            .flatMap { (index, theme) -> theme.questions.map { index to it } }

    val flashcards: List<Flashcard> get() = themes.flatMap { it.flashcards }
}

@Serializable
data class Intro(val lines: List<String> = emptyList(), val minutes: Int = 0)

@Serializable
data class Group(val name: String = "", val themes: List<Int> = emptyList())

object ThemeStatus {
    const val PENDING = "pending"
    const val READY = "ready"
    const val FAILED = "failed"
}

@Serializable
data class Theme(
    val title: String,
    /** L'identifiant du thème, celui de sa ligne `chapters`. */
    val id: String = "",
    val icon: String = "livre-ouvert",
    val points: List<String> = emptyList(),
    val status: String = ThemeStatus.PENDING,
    val notes: ThemeNotes? = null,
    val questions: List<Question> = emptyList(),
    val flashcards: List<Flashcard> = emptyList(),
    val error: String = "",
)

/** Les notes d'un thème. Les blocs restent en JSON brut : un type inconnu ne fait rien perdre. */
@Serializable
data class ThemeNotes(
    val oneLiner: String = "",
    val blocks: List<JsonObject> = emptyList(),
    val takeaways: List<String> = emptyList(),
)

@Serializable
data class Question(
    val kind: String = "choice",
    val prompt: String = "",
    val choices: List<String> = emptyList(),
    val answer: Int = 0,
    val why: String = "",
    val difficulty: Int = 2,
    val matches: List<String> = emptyList(),
) {
    val isValid: Boolean
        get() = prompt.isNotBlank() && when (kind) {
            "order" -> choices.size >= 3
            "match" -> choices.size >= 2 && matches.size == choices.size
            else -> choices.size >= 2 && answer in choices.indices
        }

    val answerText: String
        get() = when (kind) {
            "order" -> choices.joinToString(" → ")
            "match" -> choices.zip(matches).joinToString(" · ") { "${it.first} : ${it.second}" }
            else -> choices.getOrNull(answer).orEmpty()
        }
}

@Serializable
data class Flashcard(
    val kind: String = "basic",
    val front: String = "",
    val back: String = "",
    /** L'identifiant de la carte, celui de sa ligne `flashcards`. */
    val id: String = "",
)

/** Un identifiant neuf, au format que Postgres et l'iPhone attendent. */
fun newId(): String = java.util.UUID.randomUUID().toString().lowercase()

/** Un message de la conversation avec Mika ; sa réponse peut proposer une carte. */
@Serializable
data class ChatMessage(
    /** user ou assistant. */
    val role: String,
    val text: String,
    val card: Flashcard? = null,
    /** Le thème où ranger la carte proposée, s'il est connu. */
    val cardTheme: Int? = null,
    val cardAdded: Boolean = false,
)

/** Où en est l'élève : les cercles faits, les scores des quiz. */
@Serializable
data class Progress(
    val done: Set<String> = emptySet(),
    val quizScores: Map<String, List<Int>> = emptyMap(),
    val seconds: Long = 0,
    val finishedAt: Long = 0,
    /** Les thèmes où l'élève s'est trompé : l'entraînement y revient d'abord. */
    val missed: Set<Int> = emptySet(),
    /** La mémoire des flashcards, par clé `thème:rang` (SM-2, `Srs`). */
    val cards: Map<String, CardReview> = emptyMap(),
) {
    val averageQuizPercent: Int?
        get() {
            val scores = quizScores.values.filter { it.size == 2 && it[1] > 0 }
            if (scores.isEmpty()) return null
            val right = scores.sumOf { it[0] }
            val total = scores.sumOf { it[1] }
            return Math.round(right * 100.0 / total).toInt()
        }
}

/** Les notes d'un thème à plat, pour le serveur : l'entraînement, Mika, l'examen blanc. */
fun Theme.flatNotes(): String {
    val lines = mutableListOf<String>()
    notes?.oneLiner?.takeIf { it.isNotBlank() }?.let(lines::add)
    notes?.blocks.orEmpty().forEach { raw ->
        when (val block = NoteBlock.parse(raw)) {
            is NoteBlock.Subtitle -> lines.add(block.text)
            is NoteBlock.Paragraph -> lines.add(block.text)
            is NoteBlock.Bullets -> lines.addAll(block.items.map { "- $it" })
            is NoteBlock.Definition -> lines.add("${block.term} : ${block.text}")
            is NoteBlock.Dates -> lines.addAll(block.items.map { "${it.first} : ${it.second}" })
            is NoteBlock.Formula -> lines.add(block.latex + (block.caption?.let { " ($it)" } ?: ""))
            is NoteBlock.Example -> lines.add(block.text)
            is NoteBlock.Steps -> lines.addAll(block.items.mapIndexed { index, step -> "${index + 1}. $step" })
            is NoteBlock.Table -> lines.addAll(listOf(block.columns.joinToString(" | ")) + block.rows.map { it.joinToString(" | ") })
            is NoteBlock.Quote -> lines.add(block.text)
            is NoteBlock.Callout -> lines.add(block.text)
            null -> Unit
        }
    }
    notes?.takeaways.orEmpty().forEach { lines.add("- $it") }
    return lines.joinToString("\n")
}

/** Le début du jour local d'un instant. */
fun startOfDay(time: Long): Long = java.util.Calendar.getInstance().apply {
    timeInMillis = time
    set(java.util.Calendar.HOUR_OF_DAY, 0)
    set(java.util.Calendar.MINUTE, 0)
    set(java.util.Calendar.SECOND, 0)
    set(java.util.Calendar.MILLISECOND, 0)
}.timeInMillis

// MARK: - Les blocs de notes

/** Un bloc de notes, lu depuis son JSON. `null` pour un bloc illisible et sans `text`. */
sealed interface NoteBlock {
    data class Subtitle(val text: String) : NoteBlock
    data class Paragraph(val text: String) : NoteBlock
    data class Bullets(val items: List<String>) : NoteBlock
    data class Definition(val term: String, val text: String) : NoteBlock
    data class Dates(val items: List<Pair<String, String>>) : NoteBlock
    data class Formula(val latex: String, val caption: String?) : NoteBlock
    data class Example(val text: String) : NoteBlock
    data class Steps(val items: List<String>) : NoteBlock
    data class Table(val columns: List<String>, val rows: List<List<String>>) : NoteBlock
    data class Quote(val text: String, val author: String?) : NoteBlock
    /** Un encadré : pourquoi, piège, astuce, à retenir. */
    data class Callout(val kind: String, val title: String?, val text: String) : NoteBlock

    val isBoxed: Boolean
        get() = this is Definition || this is Formula || this is Example || this is Steps ||
            this is Table || this is Quote || this is Callout

    companion object {
        fun parse(raw: JsonObject): NoteBlock? {
            val type = raw.str("type")
            val text = raw.str("text")
            return when (type) {
                "subtitle" -> text.takeIf { it.isNotBlank() }?.let { Subtitle(it) }
                "paragraph" -> text.takeIf { it.isNotBlank() }?.let { Paragraph(it) }
                "list" -> raw.strings("items").takeIf { it.isNotEmpty() }?.let { Bullets(it) }
                "definition" -> {
                    val term = raw.str("term")
                    if (term.isNotBlank() && text.isNotBlank()) Definition(term, text) else fallback(text)
                }
                "dates" -> {
                    val items = (raw["items"] as? JsonArray).orEmpty().mapNotNull { item ->
                        val entry = item as? JsonObject ?: return@mapNotNull null
                        val date = entry.str("date")
                        val label = entry.str("text")
                        if (date.isNotBlank() && label.isNotBlank()) date to label else null
                    }
                    if (items.isNotEmpty()) Dates(items) else fallback(text)
                }
                "formula" -> {
                    val latex = raw.str("latex")
                    if (latex.isNotBlank()) Formula(latex, raw.str("caption").ifBlank { null }) else fallback(text)
                }
                "example" -> text.takeIf { it.isNotBlank() }?.let { Example(it) }
                "steps" -> raw.strings("items").takeIf { it.size >= 2 }?.let { Steps(it) } ?: fallback(text)
                "table" -> {
                    val columns = raw.strings("columns")
                    val rows = (raw["rows"] as? JsonArray).orEmpty().mapNotNull { row ->
                        (row as? JsonArray)?.map { cell -> (cell as? JsonPrimitive)?.contentOrNull.orEmpty() }
                    }.filter { it.size == columns.size }
                    if (columns.size >= 2 && rows.isNotEmpty()) Table(columns, rows) else fallback(text)
                }
                "quote" -> text.takeIf { it.isNotBlank() }?.let { Quote(it, raw.str("author").ifBlank { null }) }
                "callout" -> text.takeIf { it.isNotBlank() }?.let {
                    Callout(raw.str("kind").takeIf { it in setOf("why", "mistake", "tip", "remember") } ?: "tip", raw.str("title").ifBlank { null }, it)
                }
                else -> fallback(text)
            }
        }

        private fun fallback(text: String): NoteBlock? = text.takeIf { it.isNotBlank() }?.let { Paragraph(it) }
    }
}

fun JsonObject.str(key: String): String = when (val value = this[key]) {
    is JsonPrimitive -> value.contentOrNull.orEmpty()
    else -> ""
}

fun JsonObject.int(key: String): Int? = (this[key] as? JsonPrimitive)?.intOrNull

fun JsonObject.strings(key: String): List<String> =
    (this[key] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.takeIf(String::isNotBlank) }

fun JsonElement?.asObject(): JsonObject? = this as? JsonObject

// MARK: - Le chemin

/** Un cercle du chemin : l'intro, un thème, un quiz de palier, le quiz final. */
sealed interface PathCircle {
    val id: String

    data object IntroCircle : PathCircle { override val id = "intro" }
    data class NotesCircle(val theme: Int) : PathCircle { override val id = "notes:$theme" }
    data class QuizCircle(val group: Int, val themes: List<Int>, val name: String) : PathCircle { override val id = "quiz:$group" }
    data class FinalCircle(val themes: List<Int>) : PathCircle { override val id = "final" }
}

/** Les paliers : ceux du plan, sinon le même découpage que l'app iPhone (`PathLayout.groups`). */
fun Lesson.pathGroups(): List<Group> {
    val count = themes.size
    if (count == 0) return emptyList()
    val fromPlan = groups.filter { it.themes.isNotEmpty() && it.themes.all { index -> index in 0 until count } }
    // Les paliers du plan valent s'ils couvrent chaque thème une fois et une seule : deux paliers
    // qui partagent un thème doubleraient son cercle.
    val planned = fromPlan.flatMap { it.themes }
    if (fromPlan.isNotEmpty() && planned.size == count && planned.toSet().size == count) return fromPlan
    if (singleQuiz) return listOf(Group("", (0 until count).toList()))
    val size = if (count > 8) 3 else 2
    val sizes = MutableList(count / size) { size }
    val rest = count % size
    if (size == 2 && rest == 1) {
        if (sizes.isEmpty()) sizes.add(1) else sizes[sizes.lastIndex] += 1
    } else if (size == 3 && rest == 1) {
        if (sizes.isEmpty()) sizes.add(1) else { sizes.removeAt(sizes.lastIndex); sizes.add(2); sizes.add(2) }
    } else if (size == 3 && rest == 2) {
        sizes.add(2)
    }
    var start = 0
    return sizes.map { n -> Group("", (start until start + n).toList()).also { start += n } }
}

fun Lesson.pathCircles(): List<PathCircle> {
    val out = mutableListOf<PathCircle>(PathCircle.IntroCircle)
    val groups = pathGroups()
    groups.forEachIndexed { index, group ->
        group.themes.forEach { out.add(PathCircle.NotesCircle(it)) }
        if (index < groups.lastIndex) out.add(PathCircle.QuizCircle(index, group.themes, group.name))
    }
    if (themes.isNotEmpty()) out.add(PathCircle.FinalCircle(themes.indices.toList()))
    return out
}

fun Lesson.currentCircle(): PathCircle? = pathCircles().firstOrNull { it.id !in progress.done }
