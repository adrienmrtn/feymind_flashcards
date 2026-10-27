package com.micabo.app.data

import android.util.Log
import com.micabo.app.i18n.AppLocale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.io.IOException
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId

/** Où en est la synchronisation, pour le profil. */
data class SyncState(val running: Boolean = false, val lastSuccess: Long = 0, val failed: Boolean = false)

/**
 * **La synchronisation des leçons** (`CloudSync` sur iPhone), sous le compte de l'élève, ou
 * sous son compte invité tant qu'il ne s'est pas connecté.
 *
 * Les mêmes tables et les mêmes encodages que l'iPhone : une leçon est une ligne `courses`
 * (son chemin dans `path`, sa progression dans `progress`), ses thèmes des lignes `chapters`
 * (`notes`, `quiz`), ses cartes des lignes `flashcards` avec leur mémoire SM-2. Une leçon
 * écrite sur Android s'ouvre donc sur l'iPhone, et l'inverse.
 *
 * **L'invité synchronise aussi**, depuis le 23 octobre 2026. Jusque-là, rien ne partait sans
 * compte connecté - et presque personne ne se connecte sur Android : 116 invités en quatorze
 * jours, 32 leçons générées, zéro en base, un seul appareil connecté. Or le compte invité est
 * un vrai `auth.users` : le cloisonnement marche avec son jeton, et `begin_lesson` compte déjà
 * sa leçon offerte sous cet identifiant. Un élève qui réinstalle ou change de téléphone ne
 * perd plus rien. Quand il ouvre un vrai compte, le repère repart de zéro et tout ce qui est
 * ici remonte sous le compte (voir `sync`).
 *
 * Un passage tire d'abord ce qui a changé depuis la dernière fois (cinq minutes de marge pour
 * les horloges), puis pousse ce qui a changé ici ; la plus récente des deux versions gagne.
 * Une erreur laisse le repère où il était : tout repart au passage suivant - et elle est
 * **dite** (`onFailure`), parce qu'une synchro qui échoue dans un `Log.w` est une synchro dont
 * personne n'apprend l'échec.
 */
class CloudSync(
    private val auth: SupabaseAuth,
    private val lessons: LessonRepository,
    private val exams: ExamRepository,
    private val prefs: Prefs,
    /** La série : les jours étudiés sur l'iPhone ou le site l'allument ici aussi (`review_logs`). */
    private val streak: Streak? = null,
    /** Appelé avec un mot court quand un passage échoue : la statistique `sync_failed`. */
    private val onFailure: (String) -> Unit = {},
    /** Appelé quand un passage aboutit, avec le nombre de leçons poussées : `sync_finished`. */
    private val onSuccess: (Int) -> Unit = {},
) {
    private val mutex = Mutex()
    private val _state = MutableStateFlow(SyncState(lastSuccess = prefs.syncWatermark))
    val state: StateFlow<SyncState> = _state.asStateFlow()

    /**
     * Un passage complet ; rend vrai s'il a abouti sans aucun refus. Sans compte ni invité, il ne
     * fait rien.
     *
     * **Un refus n'arrête plus tout.** Une leçon que le serveur rejette (le plus souvent la RLS,
     * 42501 : ses identifiants appartiennent à l'invité d'avant) faisait échouer le passage
     * entier : le repère restait à zéro et plus rien ne montait, ni les leçons suivantes, ni le
     * profil, ni les notes, ni les examens. Chaque leçon monte maintenant à part ; celle qui est
     * refusée reste à pousser (`Lesson.dirty`), les autres passent, et le refus est dit
     * (`onFailure`, `SyncState.failed`).
     */
    suspend fun sync(): Boolean = mutex.withLock {
        // Le compte, sinon l'invité : le même choix que pour les fonctions et les événements.
        val user = auth.userId.lowercase()
        if (user.isEmpty()) return@withLock false
        // Une session de compte perdue : on attend sa reconnexion plutôt que de pousser ses
        // leçons sous l'invité. Au-delà de deux semaines, l'élève a refait sa vie en invité.
        if (prefs.lostAccount.isNotEmpty() && auth.account.value == null) {
            if (System.currentTimeMillis() - prefs.lostAccountAt < LOST_ACCOUNT_WAIT) return@withLock false
            auth.clearLostAccount()
        }
        _state.value = _state.value.copy(running = true, failed = false)
        var pushedLessons = 0
        var refused = 0
        val ok = withContext(Dispatchers.IO) {
            runCatching {
                lessons.ready()
                exams.ready()
                val isAccount = auth.account.value != null
                val previous = prefs.syncUser
                // Un autre compte que la dernière fois - l'invité qui vient de se connecter,
                // un camarade sur le même téléphone : le repère ne vaut plus rien. Tout ce qui
                // est ici monte sous lui, tout ce qu'il a redescend.
                val switched = previous != user
                val oldWatermark = prefs.syncWatermark
                // Un compte qui laisse place à l'invité (déconnexion) : ses leçons sont déjà sous
                // le compte, elles ne remontent pas sous l'invité (elles y seraient recopiées en
                // double) ; seules celles qui changeront ici monteront.
                val accountToGuest = switched && previous.isNotEmpty() && prefs.syncUserKind == "account" && !isAccount
                if (switched) {
                    prefs.syncWatermark = 0
                    prefs.profileSignature = ""
                }
                // Le repère est pris avant les requêtes : ce qui change pendant le passage repartira.
                val started = System.currentTimeMillis()
                val since = prefs.syncWatermark
                val token = auth.accessToken()
                // La session du compte a pu se perdre en route (`accessToken` retombe alors sur
                // l'invité) : pousser sous `user` avec le jeton d'un autre serait refusé partout.
                if (auth.userId.lowercase() != user) throw IOException("user changed")
                // Ce qui avait été mis de côté pour ce compte revient dans la file : les
                // suppressions et les notes, puis les leçons et les examens qui n'avaient pas pu
                // monter avant son départ (`leaveAccount`). La descente qui suit départage.
                prefs.unpark(user)
                lessons.unpark(user)
                exams.unpark(user)
                if (isAccount && switched) claimGuest(token, user, previous)
                if (switched && !accountToGuest) lessons.markDirty(lessons.lessons.value.keys)
                pull(token, user, since, switched, isAccount)
                val pushed = push(token, user, if (accountToGuest) oldWatermark else since)
                pushedLessons = pushed.first
                refused = pushed.second
                runCatching { pushProfile(token, user) }.onFailure {
                    if (it is NetworkException) throw it
                    refused += 1
                    Log.w(TAG, "Profil non monté", it)
                }
                // Le repère avance même après un refus : ce qui a été refusé reste dans sa file
                // (leçons à pousser, pierres tombales, notes) et repartira de toute façon.
                prefs.syncWatermark = started
                prefs.syncUser = user
                prefs.syncUserKind = if (isAccount) "account" else "guest"
                started
            }.onFailure {
                Log.w(TAG, "Synchronisation interrompue", it)
                onFailure(describe(it))
            }.getOrNull()
        }
        if (ok != null && refused > 0) onFailure("refused")
        _state.value = if (ok != null) SyncState(running = false, lastSuccess = ok, failed = refused > 0) else _state.value.copy(running = false, failed = true)
        if (ok != null) onSuccess(pushedLessons)
        ok != null && refused == 0
    }

    /** L'échec en un mot, sans texte d'élève : la famille, puis le statut HTTP s'il y en a. */
    private fun describe(error: Throwable): String = when (error) {
        is NetworkException -> "network"
        is IOException -> error.message?.let { message ->
            // « POST chapters 400: … » : on garde le verbe, la table et le statut.
            Regex("""^(GET|POST|PATCH) ([\w/]+) (\d{3})""").find(message)?.let {
                "${it.groupValues[1].lowercase()}_${it.groupValues[2].replace('/', '_')}_${it.groupValues[3]}"
            }
        } ?: "io"
        else -> error.javaClass.simpleName.lowercase().take(40)
    }

    /**
     * **La déconnexion et la suppression du compte, de bout en bout** (`CloudSync.leaveAccount`
     * sur l'iPhone). Jusqu'au 23 octobre 2026, se déconnecter laissait les leçons ici : elles
     * restaient affichées, et un passage suivant pouvait les remonter sous l'invité, puis sous
     * le compte d'après (un camarade sur le même téléphone). Désormais :
     *
     * 1. une dernière montée (déconnexion seulement) : une révision de la minute d'avant ne doit
     *    pas être le prix du départ ;
     * 2. la session du compte se ferme, ou le compte est supprimé (`close`) ; une suppression
     *    qui échoue lève son erreur, et **rien** n'a changé ici ;
     * 3. déconnexion : ce que la dernière montée n'a pas pu pousser (hors ligne, un refus) est
     *    mis de côté sous l'identifiant du compte - suppressions, notes, leçons à pousser,
     *    examens changés - et revient à sa prochaine connexion (`sync`, `unpark`), avec ce que
     *    le serveur avait déjà. Suppression : rien à garder ;
     * 4. le téléphone se vide de ce qui appartient à l'élève (leçons, examens, examens blancs,
     *    série), sans pierre tombale ; le repère, la file et le dernier utilisateur s'oublient
     *    (`forget`) ;
     * 5. un invité neuf prend la place de l'ancien, qui a cédé ses lignes au compte : il n'a
     *    rien à transférer, et ne remonte rien de l'ancien compte.
     *
     * Aucun passage ne part entre la fermeture de la session et le téléphone vidé : tout se
     * fait sous le verrou de la synchronisation. Le profil (l'accueil fini, la langue, le pays)
     * reste, comme sur l'iPhone : l'élève reste accueilli sur ce téléphone.
     *
     * Rend vrai quand la dernière montée a tout poussé (toujours vrai pour une suppression).
     */
    suspend fun leaveAccount(deleting: Boolean, close: suspend () -> Unit): Boolean {
        val account = auth.account.value?.userId?.lowercase().orEmpty()
        val clean = if (deleting) true else runCatching { sync() }.getOrDefault(false)
        return mutex.withLock {
            // Une suppression ratée lève ici : rien n'est encore effacé.
            close()
            withContext(Dispatchers.IO) {
                lessons.ready()
                exams.ready()
                if (deleting || account.isEmpty()) {
                    lessons.leaveAccount(parkFor = null)
                    exams.leaveAccount(parkFor = null, since = 0L)
                    if (account.isNotEmpty()) {
                        prefs.dropParked(account)
                        lessons.dropParked(account)
                        exams.dropParked(account)
                    }
                } else {
                    // Le premier passage sous ce compte n'a jamais abouti (connecté puis parti
                    // hors ligne) : rien d'ici n'est encore confirmé chez lui, tout est mis de côté.
                    val confirmed = prefs.syncUser == account
                    prefs.park(account)
                    lessons.leaveAccount(parkFor = account, everything = !confirmed)
                    exams.leaveAccount(parkFor = account, since = if (confirmed) prefs.syncWatermark else 0L, everything = !confirmed)
                }
                streak?.reset()
                // L'examen blanc offert se compte par compte au serveur, comme sur l'iPhone.
                prefs.mockFreeUsed = false
                forget()
                auth.startFreshGuest()
            }
            clean
        }
    }

    /**
     * Efface le repère, la file et le dernier utilisateur (`CloudSync.forget` sur l'iPhone) : le
     * compte suivant n'hérite ni du repère du précédent, ni de ce qui attendait de monter pour lui
     * (déjà mis de côté par `leaveAccount` quand il le fallait).
     */
    private fun forget() {
        prefs.syncWatermark = 0
        prefs.syncUser = ""
        prefs.syncUserKind = ""
        prefs.removeTombstones(prefs.tombstones)
        prefs.removeReviews(prefs.pendingReviews)
        prefs.profileSignature = ""
        _state.value = SyncState()
    }

    /**
     * Met de côté ce qui attendait de monter pour ce compte : sa session vient d'être perdue, ou
     * l'élève efface tout. Seulement si la file est bien la sienne (le dernier synchronisé).
     */
    fun park(user: String) {
        val id = user.lowercase()
        if (prefs.syncUser == id || prefs.syncUser.isEmpty()) prefs.park(id)
    }

    /** Après « Tout effacer » : l'état affiché repart ; la file et le repère restent. */
    fun erased() {
        _state.value = SyncState(lastSuccess = prefs.syncWatermark)
    }

    // MARK: - Le transfert de l'invité

    /**
     * **Le jeton de transfert, pris avec la session de l'invité** (`create_guest_claim`), juste
     * avant la connexion d'un compte. Sans lui, les leçons de l'invité montaient sous le compte
     * avec des identifiants qui appartenaient encore à l'invité au serveur : refus RLS, et plus
     * rien ne se synchronisait. Sans réseau ou sans la fonction, rien : le transfert se tentera
     * encore au premier passage sous le compte, tant que la session invitée est là.
     */
    suspend fun prepareGuestClaim() {
        if (auth.account.value != null) return
        val guest = auth.guestId.lowercase()
        if (guest.isEmpty()) return
        runCatching { withContext(Dispatchers.IO) { createClaim(guest) } }.onFailure { Log.w(TAG, "Jeton de transfert non pris", it) }
    }

    /** Le jeton, s'il n'y en a pas déjà un frais pour cet invité. Rend vrai s'il y en a un. */
    private suspend fun createClaim(guest: String): Boolean {
        val now = System.currentTimeMillis()
        if (prefs.guestClaimToken.isNotEmpty() && prefs.guestClaimFrom == guest && now - prefs.guestClaimAt < CLAIM_VALIDITY) return true
        val guestToken = auth.guestSessionToken() ?: return false
        val result = request("POST", "rpc/create_guest_claim", "{}", guestToken)
        if (result.status !in 200..299) {
            Log.w(TAG, "create_guest_claim ${result.status}: ${result.body.take(160)}")
            return false
        }
        val token = claimTokenOf(result.body) ?: return false
        prefs.guestClaimToken = token
        prefs.guestClaimAt = now
        prefs.guestClaimFrom = guest
        return true
    }

    /**
     * **Les lignes de l'invité passent au compte** (`claim_guest`), avant toute montée : cours,
     * thèmes, cartes, examens, historique changent de propriétaire au serveur, et les leçons
     * d'ici remontent ensuite sous le compte sans refus. Le jeton est pris maintenant avec la
     * session invitée s'il ne l'a pas été avant la connexion.
     *
     * Une panne (réseau, 5xx) arrête le passage : pousser maintenant ferait recopier les leçons
     * sous de nouveaux identifiants (`rekey`), puis le transfert les doublerait. Un jeton refusé
     * (périmé, déjà servi) est oublié ; les refus restants se règlent alors un par un (`rekey`).
     */
    private suspend fun claimGuest(token: String, user: String, previous: String) {
        if (previous.isNotEmpty() && previous == auth.guestId.lowercase() && previous != user) createClaim(previous)
        val claim = prefs.guestClaimToken
        if (claim.isEmpty()) return
        if (System.currentTimeMillis() - prefs.guestClaimAt >= CLAIM_VALIDITY || prefs.guestClaimFrom == user) {
            prefs.clearGuestClaim()
            return
        }
        val result = request("POST", "rpc/claim_guest", buildJsonObject { put("p_token", claim) }.toString(), token)
        when {
            result.status in 200..299 -> {
                Log.i(TAG, "Invité transféré : ${result.body.take(200)}")
                prefs.clearGuestClaim()
            }
            result.status >= 500 || result.status == 429 -> throw PostgrestError("POST", "rpc/claim_guest", result.status, result.body)
            else -> {
                Log.w(TAG, "claim_guest ${result.status}: ${result.body.take(160)}")
                prefs.clearGuestClaim()
            }
        }
    }

    /** Le jeton rendu par `create_guest_claim` : un uuid nu (`"…"`), ou rangé dans un objet. */
    private fun claimTokenOf(body: String): String? {
        val element = runCatching { MicaboJson.parseToJsonElement(body) }.getOrNull() ?: return null
        val single = if (element is JsonArray) element.firstOrNull() else element
        val raw: String? = if (single is JsonObject) {
            single.str("token").ifEmpty { single.str("create_guest_claim") }.ifEmpty {
                (single.values.firstOrNull() as? JsonPrimitive)?.contentOrNull.orEmpty()
            }
        } else {
            (single as? JsonPrimitive)?.contentOrNull
        }
        return raw?.trim()?.lowercase()?.takeIf { UUID_PATTERN.matches(it) }
    }

    // MARK: - Le profil

    /**
     * **Le profil monte avec les leçons**, comme sur l'iPhone (`ProfileRecord`).
     *
     * Android n'écrivait jamais `profiles` : 95 comptes Android en quatorze jours, et pas un
     * `onboarding_completed_at`, pas un pays, pas un niveau en base. Seules les colonnes
     * qu'Android connaît partent, et seulement quand elles ont changé depuis la dernière
     * montée : un upsert de ces colonnes-là laisse le reste de la ligne - le nom d'utilisateur,
     * la langue des fiches choisie sur l'iPhone - tel quel.
     */
    private fun pushProfile(token: String, user: String) {
        val profile = prefs.profile.value
        // Juste après « Tout effacer » : un profil vide ne remonte pas écraser les buts et les
        // matières du serveur ; il remontera une fois l'accueil refait.
        if (prefs.profileErased) {
            if (!profile.onboarded) return
            prefs.profileErased = false
        }
        val signature = signature(profile)
        if (signature == prefs.profileSignature) return
        val row = buildJsonObject {
            put("id", user)
            profile.name.trim().takeIf { it.isNotEmpty() }?.let { put("display_name", it.take(80)) }
            // Le registre, pas la marche : `study_level` est le `StudyLevel` de l'iPhone et du
            // site (« lycee », « licence »). Une marche (« upperSecondary ») n'y était lue par personne.
            profile.tier.takeIf { it.isNotEmpty() }?.let { put("study_level", Tiers.level(it)) }
            profile.country.takeIf { it.isNotEmpty() }?.let { put("country_code", it) }
            putJsonArray("learning_goals") { profile.goals.forEach { add(JsonPrimitive(it)) } }
            putJsonArray("subjects") { profile.subjects.forEach { add(JsonPrimitive(it)) } }
            // La base refuse hors de 1 à 240 minutes : un temps jamais choisi (0) faisait échouer
            // la montée du profil, et avec elle tout le passage, à chaque fois.
            profile.dailyMinutes.takeIf { it in 1..240 }?.let { put("daily_minutes", it) }
            // La langue dans laquelle on écrit, celle de l'app : un iPhone du même compte resté
            // sur une ancienne version, qui relit ce champ, écrit alors dans la même langue.
            put("sheet_language", AppLocale.resolved(profile.language).content)
            if (profile.onboarded) put("onboarding_completed_at", iso(System.currentTimeMillis()))
            put("updated_at", iso(System.currentTimeMillis()))
        }
        upsert(token, "profiles", listOf(row))
        prefs.profileSignature = signature
    }

    /** L'empreinte de ce que le profil transporte (`ProfileRecord.signature`). */
    private fun signature(profile: Profile): String = listOf(
        profile.onboarded.toString(), profile.name, profile.tier, profile.country,
        profile.goals.sorted().joinToString(","), profile.subjects.sorted().joinToString(","),
        profile.dailyMinutes.toString(), AppLocale.resolved(profile.language).content,
    ).joinToString("|")

    /**
     * **Le profil descend aussi** (`ProfileRecord.applyToLocalPreferences`). Il montait sans
     * jamais redescendre : un élève inscrit sur l'iPhone ou le site qui se connectait ici
     * refaisait tout l'accueil, et son pays, sa marche, ses buts restaient ceux du téléphone.
     *
     * Un champ vide ici prend celui du compte ; un champ rempli ne le prend que si le compte a
     * changé après (`updated_at` contre `Prefs.profileUpdatedAt`), et jamais par-dessus un
     * changement d'ici pas encore monté : un pays changé dans le profil ne revient pas à
     * l'ancien au passage suivant. Juste après la connexion à un compte (`switched`), le compte
     * gagne, comme sur l'iPhone (`recognizeExistingAccount`) : c'est lui que l'élève retrouve.
     * Une ligne jamais remplie - celle que l'inscription pose, la France et quinze minutes par
     * défaut - n'apprend rien et ne change rien. L'accueil fini ailleurs
     * (`onboarding_completed_at`) vaut accueil fini ici.
     *
     * La langue des fiches (`sheet_language`) ne descend pas : Micabo écrit dans la langue de
     * l'app, celle que l'élève lit ici. Elle changeait la langue de toute l'app (un téléphone en
     * turc passait en français parce que le compte disait « fr »).
     */
    private fun pullProfile(token: String, user: String, switched: Boolean, isAccount: Boolean) {
        // « Tout effacer » : l'accueil se refait, le profil du serveur ne le referme pas en plein
        // milieu (son `onboarding_completed_at` valait accueil fini). Seul un compte qui se
        // connecte pendant l'accueil est reconnu, comme avant.
        if (prefs.profileErased && !prefs.profile.value.onboarded && !(switched && isAccount)) return
        val row = selectAll(token, "profiles", "id=eq.$user").firstOrNull() ?: return
        if (row.str("onboarding_completed_at").isEmpty()) return
        val remoteUpdated = row.str("updated_at").takeIf { it.isNotEmpty() }?.let(::time) ?: 0
        val unpushed = prefs.profileSignature.isNotEmpty() && signature(prefs.profile.value) != prefs.profileSignature
        val newer = switched || (!unpushed && remoteUpdated > prefs.profileUpdatedAt)
        val name = row.str("display_name").trim().takeIf { it.isNotEmpty() }
        val tier = Tiers.fromLevel(row.str("study_level")).takeIf { it.isNotEmpty() }
        val country = row.str("country_code").lowercase().takeIf { COUNTRY.matches(it) || it == "other" }
        val goals = row.strings("learning_goals").toSet().takeIf { it.isNotEmpty() }
        val subjects = row.strings("subjects").toSet().takeIf { it.isNotEmpty() }
        val daily = row.int("daily_minutes")?.takeIf { it in 1..240 }
        fun <T> pick(local: T, empty: Boolean, remote: T?): T = if (remote != null && (empty || newer)) remote else local
        prefs.updateFromCloud { profile ->
            profile.copy(
                onboarded = true,
                name = pick(profile.name, profile.name.isBlank(), name),
                country = pick(profile.country, profile.country.isBlank(), country),
                tier = pick(profile.tier, profile.tier.isBlank(), tier),
                goals = pick(profile.goals, profile.goals.isEmpty(), goals),
                subjects = pick(profile.subjects, profile.subjects.isEmpty(), subjects),
                dailyMinutes = pick(profile.dailyMinutes, profile.dailyMinutes <= 0, daily),
            )
        }
        if (prefs.profileErased) prefs.profileErased = false
        // Le compte a gagné : ce qui vient de descendre n'a pas à remonter. Plus vieux que le
        // téléphone, il a seulement rempli les vides, et la montée qui suit publie le reste.
        if (newer) prefs.profileSignature = signature(prefs.profile.value)
    }

    // MARK: - Tirer

    /**
     * Tire ce qui a changé ; rend les leçons recopiées en entier, avec leur date.
     *
     * **Qui gagne, pour une leçon** : on ne compare plus l'horloge du téléphone à celle du
     * serveur (un téléphone en avance gardait sa version, un en retard perdait la sienne, et
     * chaque leçon poussée redescendait au passage suivant, le serveur posant lui-même son
     * `updated_at`). Une ligne qui n'a pas bougé depuis la dernière fois qu'on l'a vue
     * (`Lesson.serverUpdatedAt`) est sautée ; une leçon sans changement ici à pousser
     * (`Lesson.dirty` faux) prend la version du serveur ; seules deux modifications des deux
     * côtés se départagent à la date. Et la version descendue n'entre que si la leçon d'ici n'a
     * pas changé pendant le téléchargement (`applyFromCloud`).
     */
    private fun pull(token: String, user: String, since: Long, switched: Boolean, isAccount: Boolean): Map<String, Long> {
        val from = iso(maxOf(0, since - OVERLAP))
        val applied = HashMap<String, Long>()
        val courses = selectAll(token, "courses", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        val tombstones = prefs.tombstones
        for (row in courses) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "course:$id" in tombstones) continue
            val local = lessons.lesson(id)
            val remoteUpdated = time(row.str("updated_at"))
            val deletedAt = row.str("deleted_at").takeIf { it.isNotEmpty() }?.let(::time)
            if (deletedAt != null) {
                // Supprimée ailleurs : elle part, sauf si elle a été changée ici après.
                if (local != null && (!local.dirty || deletedAt >= local.updatedAt)) lessons.removeFromCloud(id)
                continue
            }
            // Un cours sans chemin (une ancienne fiche, un paquet de cartes) s'affiche aussi : il
            // était sauté, et ses cartes n'existaient pas sur Android.
            val path = row["path"] as? JsonObject
            if (local != null) {
                // Rien de neuf au serveur depuis qu'on a vu la ligne (montée ou descendue).
                if (local.serverUpdatedAt > 0 && remoteUpdated <= local.serverUpdatedAt) continue
                // Une leçon d'avant ces repères : l'ancienne règle, la plus récente gagne.
                if (local.serverUpdatedAt == 0L && local.updatedAt >= remoteUpdated) continue
                // Changée des deux côtés : la plus récente gagne.
                if (local.dirty && local.updatedAt >= remoteUpdated) continue
            }
            val chapters = selectAll(token, "chapters", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val cards = selectAll(token, "flashcards", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val lesson = (if (path != null) lessonFrom(row, path, chapters, cards, local) else legacyLessonFrom(row, chapters, cards, local)) ?: continue
            val fresh = lesson.copy(updatedAt = remoteUpdated, serverUpdatedAt = remoteUpdated, dirty = false)
            if (lessons.applyFromCloud(fresh, expectedUpdatedAt = local?.updatedAt)) applied[id] = remoteUpdated
        }

        pullCards(token, user, from, applied.keys)

        val remoteExams = selectAll(token, "exams", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        for (row in remoteExams) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "exam:$id" in tombstones) continue
            val local = exams.exam(id)
            val remoteUpdated = time(row.str("updated_at"))
            val deletedAt = row.str("deleted_at").takeIf { it.isNotEmpty() }?.let(::time)
            if (deletedAt != null) {
                if (local != null && deletedAt >= local.updatedAt) exams.removeFromCloud(id)
                continue
            }
            if (local != null && local.updatedAt >= remoteUpdated) continue
            val day = runCatching { LocalDate.parse(row.str("exam_date").take(10)) }.getOrNull() ?: continue
            // Une colonne absente (une ligne d'avant qu'elle existe) garde ce qu'on avait ici.
            exams.applyFromCloud(
                Exam(
                    id = id,
                    name = row.str("name"),
                    date = day.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                    lessonIds = (row["course_ids"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.lowercase() },
                    updatedAt = remoteUpdated,
                    kind = row.str("kind").ifEmpty { local?.kind.orEmpty() }.ifEmpty { null },
                    intensity = row.str("intensity").ifEmpty { local?.intensity.orEmpty() }.ifEmpty { null },
                    targetScore = row.int("target_score") ?: local?.targetScore,
                    startingPoint = row.str("starting_point").ifEmpty { local?.startingPoint.orEmpty() }.ifEmpty { null },
                ),
            )
        }

        // Ni la série ni le profil ne font échouer le passage : les leçons sont déjà là.
        runCatching { pullReviewDays(token, user, from) }.onFailure { Log.w(TAG, "Série non relue", it) }
        runCatching { pullProfile(token, user, switched, isAccount) }.onFailure { Log.w(TAG, "Profil non relu", it) }
        return applied
    }

    /**
     * **Les cartes descendent seules**, comme sur l'iPhone. Noter une carte sur l'iPhone ou le
     * site ne touche que sa ligne `flashcards`, pas `courses.updated_at` : relire les cartes
     * seulement sous les cours changés laissait ici, pour toujours, la mémoire d'avant.
     *
     * Carte par carte, la plus récente gagne : le `updated_at` du serveur contre la dernière
     * note posée ici (`CardReview.updatedAt`). Une carte inconnue rejoint son thème (ou le
     * dernier) ; une carte supprimée ou suspendue ailleurs s'en va. Les leçons recopiées en
     * entier à l'instant ont déjà leurs cartes.
     */
    private fun pullCards(token: String, user: String, from: String, fresh: Set<String>) {
        val rows = selectAll(token, "flashcards", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        if (rows.isEmpty()) return
        val tombstones = prefs.tombstones
        rows.groupBy { it.str("course_id").lowercase() }.forEach { (courseId, group) ->
            if (courseId.isEmpty() || courseId in fresh || lessons.lesson(courseId) == null) return@forEach
            lessons.mergeFromCloud(courseId) { lesson -> mergeCards(lesson, group, tombstones) }
        }
    }

    /** Les cartes descendues, fondues dans la leçon. Sans effet de bord : la fusion peut être rejouée. */
    private fun mergeCards(lesson: Lesson, rows: List<JsonObject>, tombstones: Set<String>): Lesson {
        val chapterIndex = lesson.themes.withIndex().filter { it.value.id.isNotEmpty() }.associate { it.value.id.lowercase() to it.index }
        val cards = lesson.themes.mapIndexed { theme, value ->
            value.flashcards.mapIndexed { index, card -> card to lesson.progress.cards["$theme:$index"] }.toMutableList()
        }
        if (cards.isEmpty()) return lesson
        var changed = false
        for (row in rows) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "card:$id" in tombstones) continue
            val remoteUpdated = time(row.str("updated_at"))
            val gone = row.str("deleted_at").isNotEmpty() || row.bool("is_suspended") == true
            var theme = -1
            var index = -1
            for ((position, list) in cards.withIndex()) {
                val found = list.indexOfFirst { it.first.id.lowercase() == id }
                if (found >= 0) {
                    theme = position
                    index = found
                    break
                }
            }
            if (index < 0) {
                if (gone) continue
                val entry = cardFrom(row) ?: continue
                val target = row.str("chapter_id").lowercase().takeIf { it.isNotEmpty() }?.let { chapterIndex[it] } ?: cards.lastIndex
                cards[target].add(entry)
                changed = true
                continue
            }
            val local = cards[theme][index]
            if (remoteUpdated <= (local.second?.updatedAt ?: 0)) continue
            if (gone) {
                cards[theme].removeAt(index)
                changed = true
                continue
            }
            // Une carte qu'Android ne sait pas montrer reste telle qu'elle était ici.
            val entry = cardFrom(row) ?: continue
            // La même carte, la même mémoire : rien à réécrire, seule la date diffère.
            if (entry.first == local.first && entry.second?.copy(updatedAt = 0) == local.second?.copy(updatedAt = 0)) continue
            cards[theme][index] = entry
            changed = true
        }
        return if (changed) lesson.withCards(cards) else lesson
    }

    /**
     * **Les jours étudiés ailleurs allument la série d'ici** (`review_logs`). L'historique monte
     * depuis Android ; il ne redescendait jamais, et la série d'un élève qui révise sur les deux
     * appareils se cassait les jours passés sur l'iPhone. Seule la date est lue : Android ne
     * garde pas l'historique lui-même, il n'en a pas l'usage.
     */
    private fun pullReviewDays(token: String, user: String, from: String) {
        val streak = streak ?: return
        val rows = selectAll(
            token,
            "review_logs",
            "user_id=eq.$user&reviewed_at=gt.${encode(from)}&order=reviewed_at.desc",
            select = "reviewed_at",
            maxRows = 10_000,
        )
        val days = rows.mapNotNull { row -> time(row.str("reviewed_at")).takeIf { it > 0 }?.let(streak::stampOf) }.toSet()
        streak.merge(days)
    }

    /**
     * Une ligne `flashcards` devenue carte, avec sa mémoire ; `null` pour une carte suspendue,
     * ou qu'Android ne sait pas montrer (une occlusion, qui a besoin de son schéma). Le `kind`
     * reste celui du serveur : un QCM reste un QCM (voir `Flashcard`).
     */
    private fun cardFrom(row: JsonObject): Pair<Flashcard, CardReview?>? {
        if (row.bool("is_suspended") == true) return null
        val kind = row.str("kind").ifEmpty { "basic" }
        if (kind == "occlusion") return null
        val card = Flashcard(
            kind = kind,
            front = row.str("front"),
            back = row.str("back"),
            id = row.str("id").lowercase(),
            choices = (row["choices"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
            correctChoice = row.int("correct_choice_index") ?: 0,
        )
        if (card.front.isBlank() || card.answer.isBlank()) return null
        val state = row.str("state").ifEmpty { CardState.NEW }
        val review = if (state == CardState.NEW) null else CardReview(
            state = state,
            interval = row.double("interval_days") ?: 0.0,
            ease = row.double("ease_factor") ?: Srs.STARTING_EASE,
            reps = row.int("repetitions") ?: 0,
            lapses = row.int("lapses") ?: 0,
            step = row.int("step_index") ?: 0,
            due = row.str("due_date").takeIf { it.isNotEmpty() }?.let(::time) ?: 0,
            updatedAt = row.str("updated_at").takeIf { it.isNotEmpty() }?.let(::time) ?: 0,
        )
        return card to review
    }

    /** Une ligne `courses` et ses thèmes et cartes, devenus une leçon. */
    private fun lessonFrom(row: JsonObject, path: JsonObject, chapterRows: List<JsonObject>, cardRows: List<JsonObject>, local: Lesson?): Lesson? {
        val points = (path["points"] as? JsonArray).orEmpty().map { item -> (item as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull } }
        val chapterIndex = HashMap<String, Int>()
        val themes = chapterRows.sortedBy { it.int("position") ?: 0 }.mapIndexed { index, chapter ->
            val id = chapter.str("id").lowercase()
            chapterIndex[id] = index
            val notes = (chapter["notes"] as? JsonObject)?.let { runCatching { MicaboJson.decodeFromJsonElement<ThemeNotes>(it) }.getOrNull() }
            val questions = ((chapter["quiz"] as? JsonObject)?.get("questions") as? JsonArray).orEmpty().mapNotNull { item ->
                runCatching { MicaboJson.decodeFromJsonElement<Question>(item) }.getOrNull()
            }
            val status = chapter.str("status").takeIf { it in setOf(ThemeStatus.PENDING, ThemeStatus.READY, ThemeStatus.FAILED) }
                ?: if (notes != null) ThemeStatus.READY else ThemeStatus.PENDING
            Theme(
                title = chapter.str("title"),
                id = id,
                icon = chapter.str("icon").ifEmpty { "livre-ouvert" },
                points = points.getOrElse(index) { emptyList() },
                status = status,
                notes = notes,
                questions = questions,
            )
        }
        if (themes.isEmpty()) return null

        // Les cartes, rangées dans leur thème ; une carte sans thème va au dernier.
        val byTheme = MutableList(themes.size) { mutableListOf<Pair<Flashcard, CardReview?>>() }
        for (card in cardRows) {
            val entry = cardFrom(card) ?: continue
            val theme = card.str("chapter_id").lowercase().let { chapterIndex[it] } ?: themes.lastIndex
            byTheme[theme].add(entry)
        }

        val progressJson = row["progress"] as? JsonObject
        val done = (progressJson?.get("done") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }.toSet()
        val scores = (progressJson?.get("quizScores") as? JsonObject).orEmpty().mapNotNull { (key, value) ->
            val pair = (value as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.intOrNull }
            if (pair != null && pair.size == 2) key to pair else null
        }.toMap()
        val seconds = (progressJson?.get("seconds") as? JsonObject).orEmpty().values.sumOf { (it as? JsonPrimitive)?.doubleOrNull ?: 0.0 }.toLong()
        val missed = (progressJson?.get("missed") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            .mapNotNull { chapterIndex[it.substringBefore(':').lowercase()] }.toSet()
        val finishedAt = progressJson?.str("finishedAt")?.takeIf { it.isNotEmpty() }?.let(::time) ?: 0

        val intro = path["intro"] as? JsonObject
        val groups = (path["groups"] as? JsonArray).orEmpty().mapNotNull { item ->
            val group = item as? JsonObject ?: return@mapNotNull null
            Group(group.str("name"), (group["themes"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.intOrNull })
        }
        return Lesson(
            id = row.str("id").lowercase(),
            title = row.str("title"),
            subject = row.str("subject"),
            icon = row.str("icon").ifEmpty { path.str("icon").ifEmpty { "livre-ouvert" } },
            createdAt = row.str("created_at").takeIf { it.isNotEmpty() }?.let(::time) ?: System.currentTimeMillis(),
            openedAt = row.str("last_opened_at").takeIf { it.isNotEmpty() }?.let(::time) ?: local?.openedAt ?: 0,
            language = row.str("language").ifEmpty { local?.language ?: "en" },
            source = sourceFromCourse(row.str("source")),
            topic = local?.topic.orEmpty(),
            contextText = row.str("context_text"),
            intro = Intro(
                lines = (intro?.get("lines") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
                minutes = intro?.int("minutes") ?: 0,
            ),
            takeaways = (path["takeaways"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
            groups = groups,
            shortened = path.bool("shortened") == true,
            singleQuiz = path.bool("singleQuiz") == true,
            themes = themes,
            tone = TONES.indexOf(row.str("tone")).takeIf { it >= 0 } ?: 2,
            progress = Progress(done = done, quizScores = scores, seconds = seconds, finishedAt = finishedAt, missed = missed),
            examDate = local?.examDate ?: 0,
            chat = local?.chat.orEmpty(),
            visibility = row.str("visibility").ifEmpty { null },
        ).withCards(byTheme)
    }

    /**
     * **Un cours sans chemin, devenu leçon** (`Lesson.legacy`) : une ancienne fiche, ou un paquet
     * de cartes fait sur l'iPhone ou le site. Ses parties (`chapters`) font les thèmes, leurs
     * notes ou leur fiche se lisent ; sans partie, la fiche du cours fait un thème unique. Pas
     * de génération : tout est prêt, et les quiz sans question se passent d'un appui. Ce qui a
     * été fait ici sur le chemin reste ici ; ses cartes, elles, se révisent et remontent.
     */
    private fun legacyLessonFrom(row: JsonObject, chapterRows: List<JsonObject>, cardRows: List<JsonObject>, local: Lesson?): Lesson {
        val title = row.str("title")
        val chapterIndex = HashMap<String, Int>()
        val chapters = chapterRows.sortedBy { it.int("position") ?: 0 }
        val themes = if (chapters.isEmpty()) {
            listOf(
                Theme(
                    title = title,
                    status = ThemeStatus.READY,
                    notes = notesFromSheet(row["sheet"]) ?: ThemeNotes(oneLiner = row.str("summary")),
                ),
            )
        } else {
            chapters.mapIndexed { index, chapter ->
                val id = chapter.str("id").lowercase()
                chapterIndex[id] = index
                val notes = (chapter["notes"] as? JsonObject)?.let { runCatching { MicaboJson.decodeFromJsonElement<ThemeNotes>(it) }.getOrNull() }
                    ?: notesFromSheet(chapter["sheet"])
                    ?: ThemeNotes()
                val questions = ((chapter["quiz"] as? JsonObject)?.get("questions") as? JsonArray).orEmpty().mapNotNull { item ->
                    runCatching { MicaboJson.decodeFromJsonElement<Question>(item) }.getOrNull()?.takeIf { it.isValid }
                }
                Theme(
                    title = chapter.str("title").ifBlank { title },
                    id = id,
                    icon = chapter.str("icon").ifEmpty { "livre-ouvert" },
                    status = ThemeStatus.READY,
                    notes = notes,
                    questions = questions,
                )
            }
        }
        val byTheme = MutableList(themes.size) { mutableListOf<Pair<Flashcard, CardReview?>>() }
        for (card in cardRows) {
            val entry = cardFrom(card) ?: continue
            val theme = card.str("chapter_id").lowercase().takeIf { it.isNotEmpty() }?.let { chapterIndex[it] } ?: themes.lastIndex
            byTheme[theme].add(entry)
        }
        val id = row.str("id").lowercase()
        return Lesson(
            id = id,
            title = title,
            subject = row.str("subject"),
            icon = local?.icon ?: "livre-ouvert",
            createdAt = row.str("created_at").takeIf { it.isNotEmpty() }?.let(::time) ?: System.currentTimeMillis(),
            openedAt = row.str("last_opened_at").takeIf { it.isNotEmpty() }?.let(::time) ?: local?.openedAt ?: 0,
            language = row.str("language").ifEmpty { local?.language ?: "en" },
            // La provenance brute : un paquet (`deck`), un exemple, la bibliothèque ne consomment
            // pas la leçon offerte (`Lesson.usesFreeLesson`). Elle ne remonte jamais d'ici.
            source = if (row.bool("is_from_library") == true) "library" else row.str("source").ifEmpty { "text" },
            topic = local?.topic.orEmpty(),
            contextText = row.str("context_text"),
            intro = Intro(lines = listOfNotNull(row.str("summary").trim().takeIf { it.isNotEmpty() })),
            singleQuiz = true,
            themes = themes,
            tone = local?.tone ?: TONES.indexOf(row.str("tone")).takeIf { it >= 0 } ?: Math.floorMod(id.hashCode(), TONES.size),
            progress = local?.progress ?: Progress(),
            examDate = local?.examDate ?: 0,
            chat = local?.chat.orEmpty(),
            visibility = row.str("visibility").ifEmpty { null },
            legacy = true,
        ).withCards(byTheme)
    }

    /**
     * La fiche d'un ancien cours (`CourseSheet`), lue comme des notes. Ses quatre blocs passent
     * presque tels quels : le titre de partie devient un sous-titre, une liste numérotée des
     * étapes ; un bloc d'avant la refonte retombe sur son texte (`NoteBlock.parse`).
     */
    private fun notesFromSheet(sheet: JsonElement?): ThemeNotes? {
        val blocks = ((sheet as? JsonObject)?.get("blocks") as? JsonArray).orEmpty().mapNotNull { item ->
            val block = item as? JsonObject ?: return@mapNotNull null
            when (block.str("type")) {
                "heading" -> buildJsonObject {
                    put("type", "subtitle")
                    put("text", block.str("text"))
                }
                "list" -> if (block.bool("ordered") == true && block.strings("items").size >= 2) JsonObject(block + ("type" to JsonPrimitive("steps"))) else block
                else -> block
            }
        }
        return if (blocks.isEmpty()) null else ThemeNotes(blocks = blocks)
    }

    // MARK: - Pousser

    /**
     * Pousse ce qui a changé ; rend le nombre de leçons montées et le nombre de refus.
     *
     * Ce qui monte : les leçons à pousser (`Lesson.dirty`), et celles d'avant ce drapeau que
     * seule leur date repère (`pushSince`). Une leçon qui vient de descendre est propre : elle ne
     * remonte pas telle qu'Android la décrit, ce qu'il ne tient pas de sa progression s'y perdrait.
     *
     * Chaque leçon, chaque pierre tombale, chaque lot de notes et chaque examen passe ou échoue
     * seul : un refus ne bloque plus le reste. Seule une coupure du réseau arrête le passage.
     */
    private fun push(token: String, user: String, pushSince: Long): Pair<Int, Int> {
        var refused = 0

        // Les suppressions d'abord : un cours supprimé ne doit pas revenir.
        val tombstones = prefs.tombstones
        if (tombstones.isNotEmpty()) {
            val now = iso(System.currentTimeMillis())
            val done = mutableListOf<String>()
            for (entry in tombstones) {
                val table = when (entry.substringBefore(':')) {
                    "course" -> "courses"
                    "card" -> "flashcards"
                    "exam" -> "exams"
                    else -> null
                }
                val id = entry.substringAfter(':')
                if (table == null || id.isEmpty()) {
                    done.add(entry)
                    continue
                }
                val result = request("PATCH", "$table?id=eq.$id&user_id=eq.$user", buildJsonObject {
                    put("deleted_at", now)
                    put("updated_at", now)
                }.toString(), token, mapOf("Prefer" to "return=minimal"))
                when {
                    result.status in 200..299 -> done.add(entry)
                    // Un refus du serveur ne passera pas mieux plus tard (un identifiant invalide) :
                    // la pierre tombale est abandonnée. Une panne la garde pour le passage suivant.
                    result.status in 400..499 && result.status != 429 -> {
                        Log.w(TAG, "PATCH $table ${result.status}: ${result.body.take(160)}")
                        done.add(entry)
                    }
                    else -> refused += 1
                }
            }
            prefs.removeTombstones(done)
        }

        // Les leçons d'avant le drapeau, repérées par leur date, deviennent « à pousser » : un
        // refus ne les perd plus quand le repère avance.
        lessons.markDirty(lessons.lessons.value.values.filter { !it.dirty && it.serverUpdatedAt == 0L && it.updatedAt > pushSince }.map { it.id })
        val changed = lessons.lessons.value.values.filter { it.dirty }
        var pushed = 0
        for (lesson in changed) {
            try {
                pushLesson(token, user, lesson)
                pushed += 1
            } catch (error: PostgrestError) {
                if (error.rlsDenied && !lesson.legacy) {
                    // Les identifiants appartiennent à un autre utilisateur au serveur (l'invité
                    // d'avant, sans transfert possible) : la leçon prend des identifiants neufs,
                    // garde son contenu et la mémoire de ses cartes, et remonte une fois.
                    val retried = rekeyAndPush(token, user, lesson)
                    if (retried) pushed += 1 else refused += 1
                } else if (error.rlsDenied) {
                    // Un ancien cours d'un autre : seules ses cartes montaient, et elles ne
                    // peuvent pas changer de cours. Rien à réessayer.
                    Log.w(TAG, "Ancien cours refusé : ${error.message}")
                    lessons.markPushed(lesson.id, lesson.updatedAt, null)
                    refused += 1
                } else {
                    Log.w(TAG, "Leçon refusée", error)
                    refused += 1
                }
            }
        }

        refused += pushReviews(token, user)
        refused += pushExams(token, user, pushSince)
        return pushed to refused
    }

    /**
     * Une leçon : son cours et ses thèmes (sauf un ancien cours), puis ses cartes. Le cours rend
     * son `updated_at` (posé par le serveur) : c'est lui qui dira, au passage suivant, si la
     * ligne a changé ailleurs.
     */
    private fun pushLesson(token: String, user: String, lesson: Lesson) {
        val stamped = lesson.stamped()
        var serverUpdated: Long? = null
        // Un ancien cours ou un paquet : seules ses cartes remontent (`Lesson.legacy`).
        if (!stamped.legacy) {
            val rows = upsert(token, "courses", listOf(courseRow(stamped, user)), returning = "id,updated_at")
            serverUpdated = rows.firstOrNull()?.str("updated_at")?.takeIf { it.isNotEmpty() }?.let(::time)?.takeIf { it > 0 }
            upsert(token, "chapters", stamped.themes.mapIndexed { index, theme -> chapterRow(stamped, theme, index, user) })
        }
        upsert(token, "flashcards", cardRows(stamped, user))
        lessons.markPushed(lesson.id, lesson.updatedAt, serverUpdated)
    }

    /** La leçon refusée, sous des identifiants neufs ; les examens et les notes en attente suivent. */
    private fun rekeyAndPush(token: String, user: String, lesson: Lesson): Boolean {
        val (fresh, cardIds) = lessons.rekey(lesson.id) ?: return false
        Log.w(TAG, "Leçon ${lesson.id} refusée (RLS) : nouveaux identifiants ${fresh.id}")
        exams.replaceLesson(lesson.id, fresh.id)
        prefs.remapReviews(cardIds)
        return try {
            pushLesson(token, user, fresh)
            true
        } catch (error: PostgrestError) {
            Log.w(TAG, "Leçon refusée même sous de nouveaux identifiants", error)
            false
        }
    }

    /**
     * **Les cartes notées**, après les cartes elles-mêmes (`card_id` y renvoie), par lots de deux
     * cents. Un lot refusé (une carte supprimée entre-temps, une ligne invalide) n'est plus jeté
     * en entier : il repart ligne par ligne, et seules les lignes refusées sont laissées. Rend le
     * nombre de lots qui n'ont pas pu partir (panne du serveur) : ils restent dans la file.
     */
    private fun pushReviews(token: String, user: String): Int {
        var refused = 0
        val reviews = prefs.pendingReviews.toList()
        for (chunk in reviews.chunked(200)) {
            val parsed = chunk.map { line ->
                line to (runCatching { MicaboJson.parseToJsonElement(line) }.getOrNull() as? JsonObject)?.let { JsonObject(it + ("user_id" to JsonPrimitive(user))) }
            }
            // Une ligne illisible ne passera jamais : elle part de la file.
            val unreadable = parsed.filter { it.second == null }.map { it.first }
            val rows = parsed.mapNotNull { (line, row) -> row?.let { line to it } }
            if (unreadable.isNotEmpty()) prefs.removeReviews(unreadable)
            if (rows.isEmpty()) continue
            val result = postReviews(token, rows.map { it.second })
            when {
                result.status in 200..299 -> prefs.removeReviews(rows.map { it.first })
                result.status in 400..499 && result.status != 429 -> {
                    // Ligne par ligne : seules les lignes refusées sont laissées.
                    val sent = mutableListOf<String>()
                    for ((line, row) in rows) {
                        val single = postReviews(token, listOf(row))
                        when {
                            single.status in 200..299 -> sent.add(line)
                            single.status in 400..499 && single.status != 429 -> {
                                Log.w(TAG, "Note refusée ${single.status}: ${single.body.take(160)}")
                                sent.add(line)
                            }
                            else -> refused += 1
                        }
                    }
                    prefs.removeReviews(sent)
                }
                else -> refused += 1
            }
        }
        return refused
    }

    private fun postReviews(token: String, rows: List<JsonObject>): HttpResult = request(
        "POST",
        "review_logs",
        JsonArray(rows).toString(),
        token,
        mapOf("Prefer" to "resolution=ignore-duplicates,return=minimal"),
    )

    /**
     * **Les examens** changés depuis le repère. Un lot refusé repart examen par examen ; un
     * examen refusé par la RLS (son identifiant appartient à un autre utilisateur) prend un
     * identifiant neuf et repart une fois. Une panne du serveur arrête le passage : les examens
     * ne sont repérés que par leur date, et le repère ne doit pas les dépasser.
     */
    private fun pushExams(token: String, user: String, pushSince: Long): Int {
        val changedExams = exams.exams.value.filter { it.updatedAt > pushSince }
        if (changedExams.isEmpty()) return 0
        try {
            upsert(token, "exams", changedExams.map { examRow(it, user) })
            return 0
        } catch (error: PostgrestError) {
            if (error.serverSide) throw error
        }
        var refused = 0
        for (exam in changedExams) {
            try {
                upsert(token, "exams", listOf(examRow(exam, user)))
            } catch (error: PostgrestError) {
                if (error.serverSide) throw error
                val fresh = if (error.rlsDenied) exams.rekey(exam.id) else null
                val retried = fresh != null && runCatching { upsert(token, "exams", listOf(examRow(fresh, user))) }.isSuccess
                if (!retried) {
                    Log.w(TAG, "Examen refusé", error)
                    refused += 1
                }
            }
        }
        return refused
    }

    private fun examRow(exam: Exam, user: String): JsonObject = buildJsonObject {
        put("id", exam.id.lowercase())
        put("user_id", user)
        put("name", exam.name)
        put("exam_date", Instant.ofEpochMilli(exam.date).atZone(ZoneId.systemDefault()).toLocalDate().toString())
        putJsonArray("course_ids") { exam.lessonIds.forEach { add(JsonPrimitive(it.lowercase())) } }
        // Rendus tels qu'ils sont descendus ; absents, la base garde les siens.
        exam.kind?.let { put("kind", it) }
        exam.intensity?.let { put("intensity", it) }
        exam.targetScore?.let { put("target_score", it) }
        exam.startingPoint?.let { put("starting_point", it) }
        put("updated_at", iso(exam.updatedAt))
    }

    /**
     * La ligne `courses`. Seules les colonnes que l'app tient partent : la visibilité, le
     * dossier ou l'emoji choisis sur l'iPhone restent tels quels (`merge-duplicates`).
     */
    private fun courseRow(lesson: Lesson, user: String): JsonObject = buildJsonObject {
        put("id", lesson.id.lowercase())
        put("user_id", user)
        put("title", lesson.title)
        put("subject", lesson.subject.ifBlank { null })
        put("source", sourceForCourse(lesson.source))
        put("language", lesson.language.takeIf { LANGUAGE.matches(it) } ?: "en")
        // Le texte d'origine n'est gardé ici que pour un sujet tapé : vide, il ne part pas. Il
        // partait vide et effaçait au serveur le document d'une leçon faite sur l'iPhone ou le
        // site (`raw_text`), à chaque montée. Absent, la base garde le sien (`merge-duplicates`).
        lesson.topic.takeIf { it.isNotBlank() }?.let { put("raw_text", it) }
        put("context_text", lesson.contextText)
        put("created_at", iso(lesson.createdAt.takeIf { it > 0 } ?: lesson.updatedAt))
        put("updated_at", iso(lesson.updatedAt))
        if (lesson.openedAt > 0) put("last_opened_at", iso(lesson.openedAt))
        // Une visibilité jamais lue ni choisie ici ne part pas : celle de l'iPhone reste.
        lesson.visibility?.let { put("visibility", it) }
        put("tone", TONES[((lesson.tone % 5) + 5) % 5])
        put("icon", lesson.icon)
        putJsonObject("path") {
            put("version", 1)
            put("icon", lesson.icon)
            putJsonObject("intro") {
                putJsonArray("lines") { lesson.intro.lines.forEach { add(JsonPrimitive(it)) } }
                put("minutes", lesson.intro.minutes)
            }
            putJsonArray("takeaways") { lesson.takeaways.forEach { add(JsonPrimitive(it)) } }
            putJsonArray("groups") {
                lesson.groups.forEach { group ->
                    add(buildJsonObject {
                        put("name", group.name)
                        putJsonArray("themes") { group.themes.forEach { add(JsonPrimitive(it)) } }
                    })
                }
            }
            put("shortened", lesson.shortened)
            put("singleQuiz", lesson.singleQuiz)
            put(
                "status",
                when {
                    lesson.isWriting -> "generating"
                    lesson.themes.isNotEmpty() && lesson.themes.all { it.status == ThemeStatus.FAILED } -> "failed"
                    else -> "ready"
                },
            )
            putJsonArray("points") { lesson.themes.forEach { theme -> add(buildJsonArray { theme.points.forEach { add(JsonPrimitive(it)) } }) } }
        }
        putJsonObject("progress") {
            val progress = lesson.progress
            putJsonArray("done") { progress.done.forEach { add(JsonPrimitive(it)) } }
            put("inCircle", 0.0)
            putJsonObject("quizScores") {
                progress.quizScores.filterValues { it.size == 2 }.forEach { (key, value) ->
                    put(key, buildJsonArray { value.forEach { add(JsonPrimitive(it)) } })
                }
            }
            // L'iPhone note les fautes par question ; ici par thème : la première question du thème en tient lieu.
            putJsonArray("missed") { progress.missed.mapNotNull { lesson.themes.getOrNull(it)?.id }.forEach { add(JsonPrimitive("$it:0")) } }
            putJsonObject("seconds") { put("notes", progress.seconds.toDouble()) }
            if (progress.finishedAt > 0) put("finishedAt", Instant.ofEpochSecond(progress.finishedAt / 1000).toString())
        }
    }

    private fun chapterRow(lesson: Lesson, theme: Theme, index: Int, user: String): JsonObject = buildJsonObject {
        put("id", theme.id.lowercase())
        put("user_id", user)
        put("course_id", lesson.id.lowercase())
        put("position", index)
        put("title", theme.title)
        put("icon", theme.icon)
        put("status", theme.status)
        put("updated_at", iso(lesson.updatedAt))
        val notes = theme.notes
        if (notes != null) {
            putJsonObject("notes") {
                put("oneLiner", notes.oneLiner)
                put("blocks", JsonArray(notes.blocks))
                putJsonArray("takeaways") { notes.takeaways.forEach { add(JsonPrimitive(it)) } }
            }
        } else {
            put("notes", JsonNull)
        }
        putJsonObject("quiz") {
            putJsonArray("questions") {
                theme.questions.forEachIndexed { number, question ->
                    add(buildJsonObject {
                        put("id", "${theme.id.lowercase()}:$number")
                        put("kind", question.kind)
                        put("prompt", question.prompt)
                        putJsonArray("choices") { question.choices.forEach { add(JsonPrimitive(it)) } }
                        put("answer", question.answer)
                        put("why", question.why)
                        putJsonArray("matches") { question.matches.forEach { add(JsonPrimitive(it)) } }
                        put("difficulty", question.difficulty.coerceIn(1, 3))
                    })
                }
            }
        }
    }

    /**
     * Les lignes `flashcards`. Le `kind` part tel qu'il est gardé, QCM compris, avec ses
     * propositions : c'est l'iPhone ou le site qui décident comment montrer une carte, pas ce
     * qu'Android sait en afficher. Les colonnes qu'Android ne tient pas (l'indice, le schéma,
     * le groupe) ne partent pas, et restent telles quelles au serveur (`merge-duplicates`).
     *
     * Pour un ancien cours, ni le chapitre ni le rang ne partent : ses thèmes ne sont pas
     * forcément des lignes `chapters`, et l'ordre de ses cartes appartient à l'iPhone.
     */
    private fun cardRows(lesson: Lesson, user: String): List<JsonObject> {
        var position = 0
        val now = iso(System.currentTimeMillis())
        return lesson.themes.flatMapIndexed { themeIndex, theme ->
            theme.flashcards.mapIndexed { cardIndex, card ->
                val review = lesson.progress.cards["$themeIndex:$cardIndex"] ?: CardReview()
                buildJsonObject {
                    put("id", card.id.lowercase())
                    put("user_id", user)
                    put("course_id", lesson.id.lowercase())
                    if (!lesson.legacy) {
                        put("chapter_id", theme.id.lowercase())
                        put("position", position++)
                    }
                    put("front", card.front)
                    put("back", card.back)
                    put("kind", card.kind.takeIf { it in CARD_KINDS } ?: "basic")
                    if (card.kind == "choice" && card.choices.isNotEmpty()) {
                        putJsonArray("choices") { card.choices.forEach { add(JsonPrimitive(it)) } }
                        put("correct_choice_index", card.correctChoice)
                    }
                    put("state", review.state)
                    put("due_date", if (review.due > 0) iso(review.due) else now)
                    put("interval_days", review.interval)
                    put("ease_factor", review.ease)
                    put("repetitions", review.reps)
                    put("lapses", review.lapses)
                    put("step_index", review.step)
                    // La note la plus récente date la carte, même si la leçon a bougé avant elle.
                    put("updated_at", iso(maxOf(lesson.updatedAt, review.updatedAt)))
                }
            }
        }
    }

    // MARK: - PostgREST

    /** Toutes les lignes d'un filtre, page après page ; `maxRows` borne un historique sans fin. */
    private fun selectAll(token: String, table: String, filter: String, select: String = "*", maxRows: Int = Int.MAX_VALUE): List<JsonObject> {
        val out = mutableListOf<JsonObject>()
        var offset = 0
        while (true) {
            val result = request("GET", "$table?select=$select&$filter&limit=$PAGE&offset=$offset", null, token)
            if (result.status !in 200..299) throw IOException("GET $table ${result.status}: ${result.body.take(160)}")
            val page = MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { it as? JsonObject }
            out.addAll(page)
            if (page.size < PAGE || out.size >= maxRows) return out
            offset += PAGE
        }
    }

    /**
     * Un upsert par lots de mêmes clés : PostgREST refuse un tableau aux clés mêlées (PGRST102).
     * Avec `returning` (des colonnes), rend les lignes écrites telles que le serveur les a gardées.
     */
    private fun upsert(token: String, table: String, rows: List<JsonObject>, returning: String? = null): List<JsonObject> {
        if (rows.isEmpty()) return emptyList()
        val out = mutableListOf<JsonObject>()
        rows.groupBy { it.keys.sorted() }.values.forEach { group ->
            group.chunked(200).forEach { chunk ->
                val result = request(
                    "POST",
                    if (returning != null) "$table?select=$returning" else table,
                    JsonArray(chunk).toString(),
                    token,
                    mapOf("Prefer" to if (returning != null) "resolution=merge-duplicates,return=representation" else "resolution=merge-duplicates,return=minimal"),
                )
                if (result.status !in 200..299) throw PostgrestError("POST", table, result.status, result.body)
                if (returning != null) {
                    runCatching { MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { it as? JsonObject } }.getOrNull()?.let(out::addAll)
                }
            }
        }
        return out
    }

    private fun request(method: String, path: String, body: String?, token: String, headers: Map<String, String> = emptyMap()): HttpResult =
        try {
            http(method, "${SupabaseConfig.URL}/rest/v1/$path", body, token, 30_000, headers)
        } catch (error: IOException) {
            throw NetworkException(error)
        }

    private companion object {
        const val TAG = "CloudSync"
        const val PAGE = 1000
        /** Cinq minutes de marge : deux horloges ne disent jamais tout à fait la même heure. */
        const val OVERLAP = 5 * 60_000L
        /** Les teintes des leçons, dans l'ordre de l'iPhone (`LessonTone`). */
        val TONES = listOf("yellow", "mint", "blue", "pink", "lilac")
        val LANGUAGE = Regex("^[a-z]{2}(-[A-Za-z0-9]{2,3})?$")
        val COUNTRY = Regex("^[a-z]{2}$")
        /** Le jeton de transfert de l'invité vaut vingt-quatre heures (`create_guest_claim`). */
        const val CLAIM_VALIDITY = 24 * 3_600_000L
        /** Combien de temps la synchronisation attend la reconnexion d'un compte perdu. */
        const val LOST_ACCOUNT_WAIT = 14 * 86_400_000L
        val UUID_PATTERN = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        /** Les formes de carte de l'iPhone et du site (`CardKind`) : une autre repart en recto verso. */
        val CARD_KINDS = setOf("basic", "cloze", "choice", "occlusion")

        fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")

        /** L'heure ISO avec les millisecondes, en UTC. */
        fun iso(time: Long): String = Instant.ofEpochMilli(time).toString()

        /** Une date du serveur (`2026-10-17T16:38:14.123456+00:00`), ou une date seule. */
        fun time(value: String): Long = runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }
            .recoverCatching { Instant.parse(value).toEpochMilli() }
            .recoverCatching { LocalDate.parse(value.take(10)).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() }
            .getOrDefault(0)

        /** Les sources des leçons, ramenées à celles que l'iPhone connaît (`LessonSourceKind.courseSource`). */
        fun sourceForCourse(source: String): String = when (source) {
            "pdf", "photo", "docx", "youtube" -> source
            else -> "text"
        }

        fun sourceFromCourse(source: String): String = when (source) {
            "pdf", "photo", "docx", "youtube" -> source
            else -> "text"
        }
    }
}

/**
 * **Un refus de PostgREST**, avec son statut et son corps. C'est une `IOException` : le passage
 * le décrit comme avant (« POST courses 403 »). `rlsDenied` reconnaît le refus de la RLS
 * (403, ou le code Postgres 42501) : la ligne appartient à un autre utilisateur.
 */
internal class PostgrestError(val method: String, val table: String, val status: Int, val body: String) :
    IOException("$method $table $status: ${body.take(160)}") {
    val rlsDenied: Boolean get() = status == 403 || body.contains("42501")
    /** Une panne du serveur, pas un refus de la ligne : à réessayer plus tard. */
    val serverSide: Boolean get() = status >= 500 || status == 429
}

private fun JsonObject.bool(key: String): Boolean? = (this[key] as? JsonPrimitive)?.contentOrNull?.toBooleanStrictOrNull()

private fun JsonObject.double(key: String): Double? = (this[key] as? JsonPrimitive)?.doubleOrNull
