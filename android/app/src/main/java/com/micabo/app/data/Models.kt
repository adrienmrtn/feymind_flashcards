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
    /**
     * **Un cours d'avant les leçons**, ou un paquet de cartes : une ligne `courses` sans `path`,
     * écrite sur l'iPhone ou le site. Il se lit et ses cartes se révisent ici, mais seule leur
     * mémoire remonte : réécrire sa ligne lui donnerait un chemin inventé par Android, et
     * l'iPhone comme le site le prendraient pour une leçon.
     */
    val legacy: Boolean = false,
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

    /**
     * Compte pour la leçon offerte, comme `begin_lesson` : un paquet fait à la main, un cours
     * d'exemple ou repris de la bibliothèque ne la consomment pas. Sans ça, un paquet venu de
     * l'iPhone fermait ici la porte d'une leçon que le serveur aurait accordée.
     */
    val usesFreeLesson: Boolean get() = source !in setOf("sample", "library", "deck")
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

/**
 * Une carte. Son `kind` est gardé **tel que le serveur l'a écrit** (`basic`, `cloze`, `choice`,
 * `occlusion`) : Android ne sait pas tout afficher, mais il ne réécrit jamais un QCM de
 * l'iPhone en recto verso. La synchronisation le faisait, et la carte revenait cassée partout.
 */
@Serializable
data class Flashcard(
    val kind: String = "basic",
    val front: String = "",
    val back: String = "",
    /** L'identifiant de la carte, celui de sa ligne `flashcards`. */
    val id: String = "",
    /** Les propositions d'un QCM (`choices`), écrit sur l'iPhone ou le site ; vides ailleurs. */
    val choices: List<String> = emptyList(),
    /** Le rang de la bonne proposition (`correct_choice_index`). */
    val correctChoice: Int = 0,
) {
    /** Un QCM affichable (`Flashcard.format` sur iPhone) : deux propositions au moins, la bonne parmi elles. */
    val isChoice: Boolean get() = kind == "choice" && choices.size >= 2 && correctChoice in choices.indices

    /**
     * Le verso à montrer. Un QCM se révise ici en recto verso : la bonne proposition, puis son
     * explication s'il y en a une. Seul l'affichage change, la carte reste un QCM.
     */
    val answer: String
        get() {
            if (!isChoice) return back
            val right = choices[correctChoice]
            return if (back.isBlank() || back.trim() == right.trim()) right else "$right\n\n$back"
        }
}

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

    /** Le nombre de mots que le bloc donne à lire : ce qui remplit, ou non, un écran. */
    val wordCount: Int
        get() {
            val pieces = when (this) {
                is Subtitle -> listOf(text)
                is Paragraph -> listOf(text)
                is Example -> listOf(text)
                is Bullets -> items
                is Steps -> items
                is Definition -> listOf(term, text)
                is Dates -> items.flatMap { listOf(it.first, it.second) }
                is Formula -> listOf(caption.orEmpty())
                is Table -> columns + rows.flatten()
                is Quote -> listOf(text, author.orEmpty())
                is Callout -> listOf(title.orEmpty(), text)
            }
            return pieces.sumOf { piece -> piece.split(WHITESPACE).count { it.isNotEmpty() } }
        }

    companion object {
        private val WHITESPACE = Regex("\\s+")
        /** Un numéro d'étape dans le fil d'une phrase : « 1. », « 2) », en tête ou après un blanc. */
        private val INLINE_STEP = Regex("(?:^|(?<=[\\s:;]))(\\d{1,2})[.)]\\s+")

        /**
         * Un bloc et sa réparation (`NoteBlock.repaired` sur iPhone) : des étapes écrites d'une
         * traite dans un paragraphe (« 1. … 2. … 3. … ») deviennent un paragraphe d'introduction
         * et des étapes. Le serveur le fait depuis ; les leçons écrites avant sont réparées ici.
         */
        fun parseAll(raw: JsonObject): List<NoteBlock> {
            val block = parse(raw) ?: return emptyList()
            val split = (block as? Paragraph)?.let { inlineSteps(it.text) } ?: return listOf(block)
            return listOfNotNull(split.first.takeIf { it.isNotEmpty() }?.let { Paragraph(it) }, Steps(split.second))
        }

        /**
         * Trois numéros au moins, qui se suivent depuis 1 : une date (« en 1945. ») ou un « 2 »
         * isolé ne font pas une méthode. Jumeau de `inlineSteps` (iPhone et serveur).
         */
        fun inlineSteps(text: String): Pair<String, List<String>>? {
            val sequence = mutableListOf<MatchResult>()
            for (match in INLINE_STEP.findAll(text)) {
                if (match.groupValues[1].toIntOrNull() == sequence.size + 1) sequence.add(match)
            }
            if (sequence.size < 3) return null
            val items = sequence.mapIndexed { index, match ->
                val start = match.range.last + 1
                val end = if (index + 1 < sequence.size) sequence[index + 1].range.first else text.length
                // « 1. poser l'opération ; 2. calculer » : le point-virgule séparait, il ne finit pas l'étape.
                text.substring(start, end).trim().removeSuffix(";").removeSuffix(",").trim()
            }
            if (items.any { it.length < 2 }) return null
            return text.substring(0, sequence[0].range.first).trim() to items
        }

        /**
         * La formule ramenée à ce que le rendu compose (`SheetText.normalizedFormula`) : une
         * flèche étiquetée devient `\\rightarrow`, et son étiquette rejoint la légende.
         */
        private fun normalizedFormula(latex: String, caption: String?): Pair<String, String?> {
            val labels = mutableListOf<String>()
            val source = com.micabo.app.ui.text.FormulaRenderer.LABELLED_ARROW.replace(latex) { match ->
                match.groupValues[2].trim().takeIf { it.isNotEmpty() }?.let(labels::add)
                if (match.groupValues[1] == "right") "\\rightarrow" else "\\leftarrow"
            }.trim()
            val parts = (listOfNotNull(caption?.trim()) + labels).filter { it.isNotEmpty() }
            return source to parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
        }

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
                    if (latex.isNotBlank()) {
                        val (normalized, caption) = normalizedFormula(latex, raw.str("caption").ifBlank { null })
                        Formula(normalized.ifBlank { latex }, caption)
                    } else {
                        fallback(text)
                    }
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
