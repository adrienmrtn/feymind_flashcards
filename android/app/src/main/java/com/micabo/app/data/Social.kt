package com.micabo.app.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.put
import java.io.IOException
import java.net.URLEncoder
import java.text.Normalizer
import java.time.Instant

/** Où l'on en est avec quelqu'un : c'est lui, et lui seul, qui décide du bouton en face d'un nom. */
enum class Relation { UNKNOWN, REQUESTED, AWAITING_ME, FRIENDS, ME }

/** Quelqu'un, tel que l'annuaire le montre : un nom d'utilisateur et une école. */
data class Person(val id: String, val username: String, val institution: String = "") {
    val handle: String get() = Username.display(username)
}

/** Un cours qu'un ami partage (`SharedCourseRecord`) : ce qu'il faut pour le lire et le reprendre. */
data class SharedCourse(
    val id: String,
    val userId: String,
    val title: String,
    val subject: String,
    val summary: String,
    val rawText: String,
    val contextText: String,
    val visibility: String,
)

/** Une ligne du classement de la semaine : cartes passées depuis lundi. */
data class RankingRow(val userId: String, val username: String, val passes: Int, val isMe: Boolean)

/** Une carte d'un cours partagé : le contenu, pas ce que l'auteur savait. */
data class SharedCard(val front: String, val back: String)

/** Ce qui a empêché une action, pour la phrase de l'écran. */
sealed interface SocialProblem {
    data object Network : SocialProblem
    data object RequestExists : SocialProblem
    data class UsernameTaken(val name: String) : SocialProblem
    data class UsernameInvalid(val problem: Username.Problem) : SocialProblem
    data object Other : SocialProblem
}

/**
 * **Le nom d'utilisateur** (`Username`) : un identifiant, pas un pseudonyme. Minuscules, sans
 * accent ni espace, pour qu'il se dicte sans ambiguïté. La base a la même règle
 * (`profiles_username_shape`) ; celle-ci refuse tout de suite, sans aller-retour.
 */
object Username {
    const val MIN = 3
    const val MAX = 20

    enum class Problem { EMPTY, TOO_SHORT, TOO_LONG }

    /** « Adrien Martinot » devient « adrien-martinot », « Zoé_92 » devient « zoe_92 ». */
    fun normalize(raw: String): String {
        val folded = Normalizer.normalize(raw.replace('ı', 'i').replace('ß', 's'), Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "")
            .lowercase()
        val result = StringBuilder()
        var pendingSeparator = false
        for (character in folded) {
            if ((character in 'a'..'z') || (character in '0'..'9') || character == '_') {
                if (pendingSeparator && result.isNotEmpty()) result.append('-')
                pendingSeparator = false
                result.append(character)
            } else {
                pendingSeparator = true
            }
        }
        // La base exige une lettre ou un chiffre en tête (`^[a-z0-9]`).
        while (result.isNotEmpty() && !result[0].isLetterOrDigit()) result.deleteCharAt(0)
        return result.take(MAX).toString()
    }

    /** Le nom prêt à être écrit, ou ce qui l'en empêche. */
    fun validate(raw: String): Result<String> {
        val normalized = normalize(raw)
        val problem = when {
            normalized.isEmpty() -> if (raw.isBlank()) Problem.EMPTY else Problem.TOO_SHORT
            normalized.length < MIN -> Problem.TOO_SHORT
            normalized.length > MAX -> Problem.TOO_LONG
            else -> null
        }
        return if (problem == null) Result.success(normalized) else Result.failure(InvalidUsername(problem))
    }

    fun display(username: String): String = if (username.startsWith("@")) username else "@$username"

    class InvalidUsername(val problem: Problem) : Exception(problem.name)
}

/**
 * **Les amis et ce qu'ils partagent** (`SocialService` sur iPhone) : l'annuaire, les demandes,
 * les amitiés, les cours des amis. Rien n'est gardé sur le téléphone : les cours des autres
 * changent sans qu'on le sache, et une copie mentirait. C'est la base qui décide de ce qu'on
 * voit ; l'app ne fait que demander.
 */
class Social(private val auth: SupabaseAuth) {
    private val background = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _username = MutableStateFlow<String?>(null)
    val username: StateFlow<String?> = _username.asStateFlow()
    private val _friends = MutableStateFlow<List<Person>>(emptyList())
    val friends: StateFlow<List<Person>> = _friends.asStateFlow()
    private val _incoming = MutableStateFlow<List<Person>>(emptyList())
    val incoming: StateFlow<List<Person>> = _incoming.asStateFlow()
    private val _outgoing = MutableStateFlow<List<Person>>(emptyList())
    val outgoing: StateFlow<List<Person>> = _outgoing.asStateFlow()
    /** Soi et ses amis, cartes passées depuis lundi ; vide sans cercle. */
    private val _ranking = MutableStateFlow<List<RankingRow>>(emptyList())
    val ranking: StateFlow<List<RankingRow>> = _ranking.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()
    private val _problem = MutableStateFlow<SocialProblem?>(null)
    val problem: StateFlow<SocialProblem?> = _problem.asStateFlow()

    private val me: String? get() = auth.account.value?.userId?.lowercase()

    fun clearProblem() {
        _problem.value = null
    }

    /** Après une déconnexion : plus rien à montrer. */
    fun reset() {
        _username.value = null
        _friends.value = emptyList()
        _incoming.value = emptyList()
        _outgoing.value = emptyList()
        _ranking.value = emptyList()
        _problem.value = null
    }

    // MARK: - Chargement

    /** Relit le nom d'utilisateur et les amitiés ; l'annuaire met des noms sur les identifiants. */
    suspend fun refresh() {
        val me = me ?: return reset()
        _loading.value = true
        try {
            val mine = rows("directory?select=id,username,institution_name&id=eq.$me&limit=1")
            _username.value = mine.firstOrNull()?.str("username")?.takeIf { it.isNotEmpty() }
            val links = rows("friendships?select=requester_id,addressee_id,status")
            val others = links.map { other(it, me) }
            val people = directory(others)
            _friends.value = links.filter { it.str("status") == ACCEPTED }.mapNotNull { people[other(it, me)] }
            _incoming.value = links.filter { it.str("status") != ACCEPTED && it.str("addressee_id").lowercase() == me }
                .mapNotNull { people[it.str("requester_id").lowercase()] }
            _outgoing.value = links.filter { it.str("status") != ACCEPTED && it.str("requester_id").lowercase() == me }
                .mapNotNull { people[it.str("addressee_id").lowercase()] }
            _ranking.value = loadRanking(me)
            _problem.value = null
        } catch (error: Exception) {
            _problem.value = describe(error)
        } finally {
            _loading.value = false
        }
    }

    /** Le classement vient du serveur (`week_review_ranking`) : les notes des autres ne se lisent pas. */
    private suspend fun loadRanking(me: String): List<RankingRow> = runCatching {
        val result = call("POST", "rpc/week_review_ranking", "{}")
        check(result)
        MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { item ->
            val row = item as? JsonObject ?: return@mapNotNull null
            val id = row.str("user_id").lowercase()
            if (id.isEmpty()) return@mapNotNull null
            RankingRow(id, row.str("username"), row.str("passes").toIntOrNull() ?: 0, id == me)
        }
    }.getOrDefault(emptyList())

    fun relation(id: String): Relation {
        val key = id.lowercase()
        return when {
            key == me -> Relation.ME
            _friends.value.any { it.id == key } -> Relation.FRIENDS
            _incoming.value.any { it.id == key } -> Relation.AWAITING_ME
            _outgoing.value.any { it.id == key } -> Relation.REQUESTED
            else -> Relation.UNKNOWN
        }
    }

    // MARK: - Nom d'utilisateur

    /**
     * Écrit le nom d'utilisateur, seul : la synchronisation de l'iPhone envoie le profil entier,
     * et un nom qui voyagerait avec serait écrasé par un appareil en retard.
     */
    suspend fun setUsername(raw: String): Boolean {
        val me = me ?: return false
        val candidate = Username.validate(raw).getOrElse {
            _problem.value = SocialProblem.UsernameInvalid((it as Username.InvalidUsername).problem)
            return false
        }
        if (candidate == _username.value) {
            _problem.value = null
            return true
        }
        _loading.value = true
        return try {
            val result = call("PATCH", "profiles?id=eq.$me", buildJsonObject { put("username", candidate) }.toString())
            if (isDuplicate(result)) {
                _problem.value = SocialProblem.UsernameTaken(Username.display(candidate))
                false
            } else {
                check(result)
                _username.value = candidate
                _problem.value = null
                true
            }
        } catch (error: Exception) {
            _problem.value = describe(error)
            false
        } finally {
            _loading.value = false
        }
    }

    // MARK: - Trouver quelqu'un

    /** Cherche dans l'annuaire, qui ne porte que le nom et l'école. */
    suspend fun search(query: String): List<Person> {
        val needle = Username.normalize(query)
        if (me == null || needle.length < 2) return emptyList()
        return try {
            rows("directory?select=id,username,institution_name&username=ilike.${encode("*$needle*")}&order=username.asc&limit=25").mapNotNull(::person)
        } catch (error: Exception) {
            _problem.value = describe(error)
            emptyList()
        }
    }

    // MARK: - Demander, accepter, retirer

    /** Une demande ; si la personne en a déjà envoyé une, on l'accepte plutôt que d'en créer une seconde. */
    suspend fun request(person: Person) {
        val me = me ?: return
        if (person.id == me) return
        if (_incoming.value.any { it.id == person.id }) return accept(person)
        perform {
            call("POST", "friendships", buildJsonArray {
                add(buildJsonObject {
                    put("requester_id", me)
                    put("addressee_id", person.id)
                    put("status", PENDING)
                })
            }.toString(), mapOf("Prefer" to "return=minimal"))
        }
    }

    /** Accepter n'appartient qu'au destinataire ; la base le vérifie. */
    suspend fun accept(person: Person) {
        val me = me ?: return
        perform {
            call("PATCH", "friendships?requester_id=eq.${person.id}&addressee_id=eq.$me", buildJsonObject {
                put("status", ACCEPTED)
                put("responded_at", Instant.now().toString())
            }.toString(), mapOf("Prefer" to "return=minimal"))
        }
    }

    /** Refuser, annuler sa demande, se retirer d'une amitié : la même ligne s'efface. */
    suspend fun remove(person: Person) {
        val me = me ?: return
        val pair = "(and(requester_id.eq.$me,addressee_id.eq.${person.id}),and(requester_id.eq.${person.id},addressee_id.eq.$me))"
        perform { call("DELETE", "friendships?or=${encode(pair)}", null, mapOf("Prefer" to "return=minimal")) }
    }

    // MARK: - Ce que les amis partagent

    /** Les cours d'une personne, tels qu'elle nous les laisse voir : la base trie. */
    suspend fun courses(of: Person): List<SharedCourse> {
        if (me == null || of.id == me) return emptyList()
        return try {
            rows("courses?select=id,user_id,title,subject,summary,raw_text,context_text,visibility" +
                "&user_id=eq.${of.id}&visibility=neq.private&deleted_at=is.null&order=updated_at.desc&limit=60").map { row ->
                SharedCourse(
                    id = row.str("id").lowercase(),
                    userId = row.str("user_id").lowercase(),
                    title = row.str("title"),
                    subject = row.str("subject"),
                    summary = row.str("summary"),
                    rawText = row.str("raw_text"),
                    contextText = row.str("context_text"),
                    visibility = row.str("visibility"),
                )
            }
        } catch (error: Exception) {
            _problem.value = describe(error)
            emptyList()
        }
    }

    /** Combien de cartes chaque cours emporte, en une requête. */
    suspend fun cardCounts(courses: List<String>): Map<String, Int> {
        if (me == null || courses.isEmpty()) return emptyMap()
        return runCatching {
            rows("flashcards?select=course_id&course_id=in.(${courses.distinct().joinToString(",")})&deleted_at=is.null&limit=${courses.size * 80}")
                .groupingBy { it.str("course_id").lowercase() }.eachCount()
        }.getOrDefault(emptyMap())
    }

    suspend fun cards(course: String): List<SharedCard> = runCatching {
        rows("flashcards?select=front,back,choices,correct_choice_index&course_id=eq.$course&deleted_at=is.null&order=position.asc&limit=400").mapNotNull { row ->
            val choices = (row["choices"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            val back = row.str("back").ifBlank { choices.getOrNull((row["correct_choice_index"] as? JsonPrimitive)?.intOrNull ?: 0).orEmpty() }
            val front = row.str("front")
            if (front.isBlank() || back.isBlank()) null else SharedCard(front, back)
        }
    }.getOrDefault(emptyList())

    /** Une vue, dédupliquée par jour côté serveur ; une reprise, une seule fois par personne. */
    suspend fun recordView(course: String) {
        runCatching { call("POST", "rpc/record_course_view", buildJsonObject { put("p_course_id", course) }.toString()) }
    }

    /** Hors de l'écran : l'élève part aussitôt vers l'accueil, la reprise compte quand même. */
    fun recordAdopt(course: String) {
        background.launch { runCatching { call("POST", "rpc/record_course_adopt", buildJsonObject { put("p_course_id", course) }.toString()) } }
    }

    // MARK: - Rouages

    /** Une écriture, puis une relecture : pas d'état local en parallèle de celui du serveur. */
    private suspend fun perform(work: suspend () -> HttpResult) {
        _loading.value = true
        val raised = try {
            val result = work()
            if (isDuplicate(result)) SocialProblem.RequestExists else {
                check(result)
                null
            }
        } catch (error: Exception) {
            describe(error)
        }
        _loading.value = false
        refresh()
        // La relecture efface le message sur son chemin heureux : il revient après elle.
        if (raised != null) _problem.value = raised
    }

    private suspend fun directory(ids: List<String>): Map<String, Person> {
        val unique = ids.filter { it.isNotEmpty() }.distinct()
        if (unique.isEmpty()) return emptyMap()
        return rows("directory?select=id,username,institution_name&id=in.(${unique.joinToString(",")})&limit=${unique.size}")
            .mapNotNull(::person).associateBy { it.id }
    }

    private fun person(row: JsonObject): Person? {
        val id = row.str("id").lowercase()
        val username = row.str("username")
        if (id.isEmpty() || username.isEmpty()) return null
        return Person(id, username, row.str("institution_name"))
    }

    private fun other(link: JsonObject, me: String): String {
        val requester = link.str("requester_id").lowercase()
        return if (requester == me) link.str("addressee_id").lowercase() else requester
    }

    private suspend fun rows(path: String): List<JsonObject> {
        val result = call("GET", path, null)
        check(result)
        return MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { it as? JsonObject }
    }

    private suspend fun call(method: String, path: String, body: String?, headers: Map<String, String> = emptyMap()): HttpResult {
        val token = auth.accessToken()
        return withContext(Dispatchers.IO) {
            try {
                http(method, "${SupabaseConfig.URL}/rest/v1/$path", body, token, 20_000, headers)
            } catch (error: IOException) {
                throw NetworkException(error)
            }
        }
    }

    private fun check(result: HttpResult) {
        if (result.status !in 200..299) throw ApiException(result.status, "social", result.body.take(200))
    }

    /** La contrainte d'unicité : un nom déjà pris, une demande qui existe déjà. */
    private fun isDuplicate(result: HttpResult): Boolean = result.status == 409 || result.body.contains("23505")

    private fun describe(error: Throwable): SocialProblem = if (error is NetworkException) SocialProblem.Network else SocialProblem.Other

    private companion object {
        const val PENDING = "pending"
        const val ACCEPTED = "accepted"

        fun encode(value: String): String = URLEncoder.encode(value, "UTF-8").replace("+", "%20")
    }
}
