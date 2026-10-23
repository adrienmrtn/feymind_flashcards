package com.micabo.app.data

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.io.File
import java.text.NumberFormat
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** **Un examen à venir** (`Exam`) : son nom, son jour, les leçons qu'il couvre. */
@Serializable
data class Exam(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    /** Le jour, à minuit local, en millisecondes. */
    val date: Long,
    val lessonIds: List<String> = emptyList(),
    /** La dernière modification, pour la synchronisation. */
    val updatedAt: Long = 0,
    /**
     * **Ce que l'iPhone et le site règlent et qu'Android ne demande pas** : le type d'épreuve
     * (`kind`), l'intensité du plan, la note visée, le point de départ. Gardés tels qu'ils sont
     * descendus et renvoyés tels quels : un examen modifié ici ne retombe pas sur les défauts
     * du serveur. Nuls pour un examen né ici, qui prend alors ceux de la base.
     */
    val kind: String? = null,
    val intensity: String? = null,
    val targetScore: Int? = null,
    val startingPoint: String? = null,
)

/** Le score d'une leçon dans une copie. */
@Serializable
data class LessonScore(val title: String, val correct: Int, val total: Int) {
    val fraction: Double get() = if (total == 0) 0.0 else correct.toDouble() / total
}

/** **Le résultat d'un examen blanc** (`ExamPaperResult`), gardé dans l'historique. */
@Serializable
data class MockResult(
    val id: String,
    val examId: String? = null,
    val title: String,
    val date: Long,
    val correct: Int,
    val total: Int,
    val seconds: Int,
    val minutes: Int,
    val lessons: List<LessonScore> = emptyList(),
) {
    val fraction: Double get() = if (total == 0) 0.0 else correct.toDouble() / total
}

/** Une question de la copie, avec la leçon et le thème d'où elle vient. */
data class PaperItem(val question: Question, val lesson: Int, val theme: Int)

/** **Une copie d'examen blanc** (`ExamPaper`) : rien n'est gardé, sauf son résultat. */
data class Paper(
    val id: String,
    val examId: String?,
    val title: String,
    val minutes: Int,
    val lessons: List<Pair<String, String>>,
    val items: List<PaperItem>,
) {
    fun result(answers: Map<Int, Boolean>, seconds: Int): MockResult {
        val perLesson = lessons.map { (_, title) -> intArrayOf(0, 0) to title }
        var correct = 0
        items.forEachIndexed { index, item ->
            val right = answers[index] == true
            if (right) correct += 1
            perLesson.getOrNull(item.lesson)?.first?.let {
                it[1] += 1
                if (right) it[0] += 1
            }
        }
        return MockResult(
            id = id,
            examId = examId,
            title = title,
            date = System.currentTimeMillis(),
            correct = correct,
            total = items.size,
            seconds = seconds,
            minutes = minutes,
            lessons = perLesson.filter { it.first[1] > 0 }.map { LessonScore(it.second, it.first[0], it.first[1]) },
        )
    }

    companion object {
        /** Une question et demie par minute, entre six et trente (`examQuestionCount`). */
        fun questionCount(minutes: Int): Int = min(30, max(6, (minutes / 1.5).roundToInt()))
    }
}

@Serializable
private data class ExamStore(val exams: List<Exam> = emptyList(), val results: List<MockResult> = emptyList())

/** **Les examens et les examens blancs**, gardés dans `files/exams.json`. */
class ExamRepository(context: Context, private val prefs: Prefs? = null) {
    private val file = File(context.filesDir, "exams.json")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()

    private val _exams = MutableStateFlow<List<Exam>>(emptyList())
    val exams: StateFlow<List<Exam>> = _exams.asStateFlow()
    private val _results = MutableStateFlow<List<MockResult>>(emptyList())
    val results: StateFlow<List<MockResult>> = _results.asStateFlow()

    /** Le fichier est lu : avant, une écriture l'aurait remplacé par une liste vide. */
    private val loaded = CompletableDeferred<Unit>()

    init {
        scope.launch {
            try {
                val stored = runCatching { MicaboJson.decodeFromString(ExamStore.serializer(), file.readText()) }.getOrNull()
                if (stored != null) {
                    // Ce qui a changé pendant la lecture passe devant ce qui était gardé.
                    // Un examen d'avant la synchronisation reçoit une date : sans elle, il ne monterait jamais.
                    val dated = stored.exams.map { if (it.updatedAt > 0) it else it.copy(updatedAt = 1) }
                    _exams.update { current -> (dated.filter { old -> current.none { it.id == old.id } } + current).sortedBy { it.date } }
                    _results.update { current -> (current + stored.results.filter { old -> current.none { it.id == old.id } }).take(30) }
                }
            } finally {
                loaded.complete(Unit)
            }
        }
    }

    private fun persist() {
        scope.launch {
            loaded.await()
            lock.withLock {
                runCatching {
                    val temp = File(file.parentFile, "exams.json.tmp")
                    temp.writeText(MicaboJson.encodeToString(ExamStore.serializer(), ExamStore(_exams.value, _results.value)))
                    temp.renameTo(file)
                }.onFailure { Log.w("Exams", "Examens non enregistrés", it) }
            }
        }
    }

    fun exam(id: String?): Exam? = _exams.value.firstOrNull { it.id == id }

    fun save(exam: Exam) {
        val stamped = exam.copy(updatedAt = System.currentTimeMillis())
        _exams.value = (_exams.value.filter { it.id != exam.id } + stamped).sortedBy { it.date }
        persist()
    }

    fun delete(id: String) {
        _exams.value = _exams.value.filter { it.id != id }
        prefs?.addTombstones(listOf("exam:$id"))
        persist()
    }

    /** Un examen venu du serveur, gardé avec sa date. */
    fun applyFromCloud(exam: Exam) {
        _exams.value = (_exams.value.filter { it.id != exam.id } + exam).sortedBy { it.date }
        persist()
    }

    fun removeFromCloud(id: String) {
        _exams.value = _exams.value.filter { it.id != id }
        persist()
    }

    /** Attend la lecture du fichier : la synchronisation ne compare qu'une liste complète. */
    suspend fun ready() = loaded.await()

    /**
     * **L'examen change d'identifiant** : le serveur le refuse (RLS) parce que l'identifiant
     * appartient à un autre utilisateur, l'invité d'avant par exemple. Rend l'examen neuf.
     */
    fun rekey(id: String): Exam? {
        val current = exam(id) ?: return null
        val fresh = current.copy(id = newId(), updatedAt = System.currentTimeMillis())
        _exams.value = (_exams.value.filter { it.id != id } + fresh).sortedBy { it.date }
        persist()
        return fresh
    }

    /** Une leçon qui a changé d'identifiant (`LessonRepository.rekey`) : les examens la suivent. */
    fun replaceLesson(oldId: String, replacement: String) {
        if (_exams.value.none { oldId in it.lessonIds }) return
        _exams.value = _exams.value.map { exam ->
            if (oldId in exam.lessonIds) exam.copy(lessonIds = exam.lessonIds.map { if (it == oldId) replacement else it }, updatedAt = System.currentTimeMillis()) else exam
        }
        persist()
    }

    /** Une leçon supprimée sort des examens qui la couvraient. */
    fun forgetLesson(lessonId: String) {
        if (_exams.value.none { lessonId in it.lessonIds }) return
        _exams.value = _exams.value.map { if (lessonId in it.lessonIds) it.copy(lessonIds = it.lessonIds - lessonId, updatedAt = System.currentTimeMillis()) else it }
        persist()
    }

    fun record(result: MockResult) {
        _results.value = (listOf(result) + _results.value.filter { it.id != result.id }).take(30)
        persist()
    }

    /**
     * Vide les examens. Pour « Tout effacer » (`tombstones`), chacun part aussi au serveur : sans
     * pierre tombale, la synchronisation suivante les faisait redescendre.
     */
    fun reset(tombstones: Boolean = false) {
        if (tombstones) prefs?.addTombstones(_exams.value.map { "exam:${it.id}" })
        _exams.value = emptyList()
        _results.value = emptyList()
        persist()
    }

    /**
     * **La sortie d'un compte** (déconnexion, suppression) : les examens et les examens blancs
     * quittent ce téléphone, sans pierre tombale (ils restent sur le compte). Ceux qui ont changé
     * depuis la dernière synchronisation réussie (`since`), ou tous (`everything`), sont mis de
     * côté pour ce compte (`parkFor`) et reviennent à sa prochaine connexion (`unpark`).
     */
    suspend fun leaveAccount(parkFor: String?, since: Long, everything: Boolean = false) {
        loaded.await()
        val all = _exams.value
        val kept = if (parkFor.isNullOrEmpty()) emptyList() else all.filter { everything || it.updatedAt > since }
        _exams.value = emptyList()
        _results.value = emptyList()
        withContext(Dispatchers.IO) { lock.withLock {
            if (kept.isNotEmpty()) {
                runCatching {
                    val target = parkedFile(parkFor.orEmpty())
                    target.parentFile?.mkdirs()
                    val previous = runCatching { MicaboJson.decodeFromString(ExamStore.serializer(), target.readText()).exams }.getOrNull().orEmpty()
                    val merged = previous.filter { old -> kept.none { it.id == old.id } } + kept
                    target.writeText(MicaboJson.encodeToString(ExamStore.serializer(), ExamStore(merged)))
                }.onFailure { Log.w("Exams", "Examens non mis de côté", it) }
            }
            runCatching {
                val temp = File(file.parentFile, "exams.json.tmp")
                temp.writeText(MicaboJson.encodeToString(ExamStore.serializer(), ExamStore()))
                temp.renameTo(file)
            }.onFailure { Log.w("Exams", "Examens non effacés", it) }
        } }
    }

    /** Les examens mis de côté pour ce compte reviennent, sauf si une version plus récente est ici. */
    suspend fun unpark(user: String) {
        if (user.isEmpty()) return
        val target = parkedFile(user)
        if (!target.exists()) return
        loaded.await()
        val parked = withContext(Dispatchers.IO) {
            runCatching { MicaboJson.decodeFromString(ExamStore.serializer(), target.readText()).exams }.getOrNull().orEmpty()
        }
        val current = _exams.value
        val back = parked.filter { exam -> current.none { it.id == exam.id && it.updatedAt >= exam.updatedAt } }
        if (back.isNotEmpty()) _exams.value = (current.filter { local -> back.none { it.id == local.id } } + back).sortedBy { it.date }
        // Écrits tout de suite, avant que la copie mise de côté ne parte.
        withContext(Dispatchers.IO) {
            lock.withLock {
                val written = back.isEmpty() || runCatching {
                    val temp = File(file.parentFile, "exams.json.tmp")
                    temp.writeText(MicaboJson.encodeToString(ExamStore.serializer(), ExamStore(_exams.value, _results.value)))
                    temp.renameTo(file)
                }.getOrDefault(false)
                if (written) target.delete()
            }
        }
    }

    /** Le compte a été supprimé : ses examens mis de côté n'ont plus où aller. */
    fun dropParked(user: String) {
        if (user.isEmpty()) return
        parkedFile(user).delete()
    }

    private fun parkedFile(user: String) = File(File(file.parentFile, "parked-exams"), "${user.lowercase()}.json")

    /** Les examens d'aujourd'hui et après, le plus proche d'abord. */
    fun upcoming(now: Long = System.currentTimeMillis()): List<Exam> =
        _exams.value.filter { it.date >= startOfDay(now) }.sortedBy { it.date }
}

/** Les jours qui restent avant un jour donné. */
fun daysUntil(date: Long, now: Long = System.currentTimeMillis()): Int =
    ((startOfDay(date) - startOfDay(now) + 3_600_000L) / 86_400_000L).toInt()

/** **La note d'une copie, au barème du pays** (`ExamGrade`). */
object ExamGrade {
    fun label(fraction: Double, country: String): String {
        val value = min(1.0, max(0.0, fraction))
        val number = NumberFormat.getNumberInstance().apply { maximumFractionDigits = 1; minimumFractionDigits = 0 }
        fun pick(steps: List<Pair<Double, String>>, fallback: String) = steps.firstOrNull { value >= it.first }?.second ?: fallback
        return when (country) {
            "fr", "be", "ma", "dz", "tn", "sn", "ci", "pt", "gr" -> "${number.format(Math.round(value * 40) / 2.0)}/20"
            "it", "es" -> "${number.format(Math.round(value * 20) / 2.0)}/10"
            "lu" -> "${(value * 60).roundToInt()}/60"
            "ca", "tr" -> "${(value * 100).roundToInt()} %"
            "ch" -> number.format(Math.round((value * 5 + 1) * 2) / 2.0)
            "nl" -> number.format(Math.round((value * 9 + 1) * 10) / 10.0)
            "ro" -> number.format(Math.round(max(1.0, value * 10) * 10) / 10.0)
            "de" -> pick(listOf(0.95 to "1,0", 0.90 to "1,3", 0.85 to "1,7", 0.80 to "2,0", 0.75 to "2,3", 0.70 to "2,7", 0.65 to "3,0", 0.60 to "3,3", 0.55 to "3,7", 0.50 to "4,0", 0.30 to "5,0"), "6,0")
            "cz" -> pick(listOf(0.9 to "1", 0.75 to "2", 0.6 to "3", 0.5 to "4"), "5")
            "hu" -> pick(listOf(0.9 to "5", 0.7 to "4", 0.5 to "3", 0.35 to "2"), "1")
            "pl" -> pick(listOf(0.98 to "6", 0.9 to "5", 0.7 to "4", 0.5 to "3", 0.3 to "2"), "1")
            "se" -> pick(listOf(0.9 to "A", 0.8 to "B", 0.7 to "C", 0.6 to "D", 0.5 to "E"), "F")
            "uk" -> pick(listOf(0.9 to "A*", 0.8 to "A", 0.7 to "B", 0.6 to "C", 0.5 to "D", 0.4 to "E"), "U")
            else -> pick(listOf(0.97 to "A+", 0.93 to "A", 0.90 to "A-", 0.87 to "B+", 0.83 to "B", 0.80 to "B-", 0.77 to "C+", 0.73 to "C", 0.70 to "C-", 0.60 to "D"), "F")
        }
    }

    fun passes(fraction: Double): Boolean = fraction >= 0.5
}
