package com.micabo.app.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * **Le profil de l'élève**, celui du parcours d'accueil : sa langue, son pays, sa marche
 * d'études, ses matières, ses notes. C'est lui qui dit au serveur pour qui écrire.
 */
data class Profile(
    val onboarded: Boolean = false,
    val name: String = "",
    val language: String = "",
    val country: String = "",
    val tier: String = "",
    val subjects: Set<String> = emptySet(),
    val worries: Set<String> = emptySet(),
    /** La moyenne d'aujourd'hui et l'objectif, de 0 à 100 (`learner.ts`). */
    val currentScore: Int? = null,
    val targetScore: Int? = null,
    /** Ce que l'élève vient chercher (`ios.goal.*`). */
    val goals: Set<String> = emptySet(),
    /** Les minutes par jour qu'il est prêt à donner. */
    val dailyMinutes: Int = 0,
    /** system, light ou dark : l'apparence, propre à ce téléphone. */
    val theme: String = "system",
)

/** Ce que la ligne `profiles` transporte : le reste (la langue, l'apparence, les notes) reste ici. */
private fun Profile.synced(): List<Any> = listOf(onboarded, name, country, tier, goals, subjects, dailyMinutes)

class Prefs(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)

    private val _profile = MutableStateFlow(read())
    val profile: StateFlow<Profile> = _profile.asStateFlow()

    private fun read(): Profile = Profile(
        onboarded = prefs.getBoolean("onboarded", false),
        name = prefs.getString("name", "").orEmpty(),
        language = prefs.getString("language", "").orEmpty(),
        country = prefs.getString("country", "").orEmpty(),
        tier = prefs.getString("tier", "").orEmpty(),
        subjects = prefs.getStringSet("subjects", emptySet()).orEmpty().toSet(),
        worries = prefs.getStringSet("worries", emptySet()).orEmpty().toSet(),
        currentScore = prefs.getInt("currentScore", -1).takeIf { it >= 0 },
        targetScore = prefs.getInt("targetScore", -1).takeIf { it >= 0 },
        goals = prefs.getStringSet("goals", emptySet()).orEmpty().toSet(),
        dailyMinutes = prefs.getInt("dailyMinutes", 0),
        theme = prefs.getString("theme", "system").orEmpty().ifEmpty { "system" },
    )

    /**
     * Change le profil. Un changement de ce que `profiles` transporte (le nom, le pays, la
     * marche, les buts, le temps par jour, l'accueil fini) est daté : la synchronisation garde
     * la plus récente des deux versions, celle d'ici ou celle du compte.
     */
    fun update(change: (Profile) -> Profile) = write(change(_profile.value), stamp = true)

    /** Le profil descendu du compte : il ne se date pas, il n'a rien à remonter. */
    fun updateFromCloud(change: (Profile) -> Profile) = write(change(_profile.value), stamp = false)

    private fun write(next: Profile, stamp: Boolean) {
        if (stamp && next.synced() != _profile.value.synced()) profileUpdatedAt = System.currentTimeMillis()
        prefs.edit {
            putBoolean("onboarded", next.onboarded)
            putString("name", next.name)
            putString("language", next.language)
            putString("country", next.country)
            putString("tier", next.tier)
            putStringSet("subjects", next.subjects)
            putStringSet("worries", next.worries)
            putInt("currentScore", next.currentScore ?: -1)
            putInt("targetScore", next.targetScore ?: -1)
            putStringSet("goals", next.goals)
            putInt("dailyMinutes", next.dailyMinutes)
            putString("theme", next.theme)
        }
        _profile.value = next
    }

    /**
     * Efface le profil et les réglages, **pas le compte invité** : c'est lui qui porte
     * l'abonnement et la leçon offerte. Un compte neuf perdait Pro.
     *
     * **Ni l'état de la synchronisation** (`sync.*`) ni le transfert de l'invité (`claim.*`) :
     * les pierres tombales que « Tout effacer » vient de poser doivent encore monter, et le
     * repère comme le dernier utilisateur restent ceux du serveur. Les effacer faisait tout
     * redescendre au passage suivant, sous le même invité.
     */
    fun reset() {
        val kept = prefs.all.filterKeys { key ->
            key in setOf("auth.access", "auth.refresh", "auth.user", "auth.expiresAt") || key.startsWith("sync.") || key.startsWith("claim.")
        }
        prefs.edit {
            clear()
            kept.forEach { (key, value) ->
                when (value) {
                    is String -> putString(key, value)
                    is Long -> putLong(key, value)
                    is Int -> putInt(key, value)
                    is Boolean -> putBoolean(key, value)
                    is Float -> putFloat(key, value)
                    is Set<*> -> putStringSet(key, value.filterIsInstance<String>().toSet())
                    else -> Unit
                }
            }
        }
        _profile.value = read()
    }

    /**
     * **Le profil vient d'être effacé** (« Tout effacer ») et l'accueil n'est pas refait : le
     * profil du serveur ne redescend pas, sinon son `onboarding_completed_at` refermait l'accueil
     * en plein milieu. Retiré quand l'accueil est fini ici, ou à la connexion d'un compte.
     */
    var profileErased: Boolean
        get() = prefs.getBoolean("sync.profileErased", false)
        set(value) = prefs.edit { putBoolean("sync.profileErased", value) }

    /** La permission des notifications a déjà été demandée (Android 13 et plus). */
    var notificationsAsked: Boolean
        get() = prefs.getBoolean("notifications.asked", false)
        set(value) = prefs.edit { putBoolean("notifications.asked", value) }

    /** Le lot de nouvelles questions offert, une fois (`PracticeAllowance`). */
    var practiceFreeUsed: Boolean
        get() = prefs.getBoolean("practice.freeUsed", false)
        set(value) = prefs.edit { putBoolean("practice.freeUsed", value) }

    /** L'examen blanc offert, une fois (`ExamAllowance`). */
    var mockFreeUsed: Boolean
        get() = prefs.getBoolean("mock.freeUsed", false)
        set(value) = prefs.edit { putBoolean("mock.freeUsed", value) }

    /** La question offerte à Mika, et le compte du jour (`MikaQuota`). */
    var mikaFreeUsed: Boolean
        get() = prefs.getBoolean("mika.freeUsed", false)
        set(value) = prefs.edit { putBoolean("mika.freeUsed", value) }
    var mikaDay: String
        get() = prefs.getString("mika.day", "").orEmpty()
        set(value) = prefs.edit { putString("mika.day", value) }
    var mikaDayCount: Int
        get() = prefs.getInt("mika.dayCount", 0)
        set(value) = prefs.edit { putInt("mika.dayCount", value) }

    // La session invitée de Supabase.
    var accessToken: String
        get() = prefs.getString("auth.access", "").orEmpty()
        set(value) = prefs.edit { putString("auth.access", value) }
    var refreshToken: String
        get() = prefs.getString("auth.refresh", "").orEmpty()
        set(value) = prefs.edit { putString("auth.refresh", value) }
    var expiresAt: Long
        get() = prefs.getLong("auth.expiresAt", 0)
        set(value) = prefs.edit { putLong("auth.expiresAt", value) }
    var userId: String
        get() = prefs.getString("auth.user", "").orEmpty()
        set(value) = prefs.edit { putString("auth.user", value) }

    // Le vrai compte, quand l'élève s'est connecté (Google, lien par courriel).
    var accountAccess: String
        get() = prefs.getString("account.access", "").orEmpty()
        set(value) = prefs.edit { putString("account.access", value) }
    var accountRefresh: String
        get() = prefs.getString("account.refresh", "").orEmpty()
        set(value) = prefs.edit { putString("account.refresh", value) }
    var accountExpiresAt: Long
        get() = prefs.getLong("account.expiresAt", 0)
        set(value) = prefs.edit { putLong("account.expiresAt", value) }
    var accountUser: String
        get() = prefs.getString("account.user", "").orEmpty()
        set(value) = prefs.edit { putString("account.user", value) }
    var accountEmail: String
        get() = prefs.getString("account.email", "").orEmpty()
        set(value) = prefs.edit { putString("account.email", value) }
    var accountName: String
        get() = prefs.getString("account.name", "").orEmpty()
        set(value) = prefs.edit { putString("account.name", value) }
    /** Le vérificateur PKCE en attente : le lien du courriel peut s'ouvrir des jours après. */
    var pkceVerifier: String
        get() = prefs.getString("account.pkce", "").orEmpty()
        set(value) = prefs.edit { putString("account.pkce", value) }
    /**
     * Celui de la page Google ou Apple, à part : un seul vérificateur pour les deux chemins
     * faisait échouer le lien du courriel dès qu'on essayait Google entre-temps, et l'inverse.
     */
    var pkceOAuthVerifier: String
        get() = prefs.getString("account.pkce.oauth", "").orEmpty()
        set(value) = prefs.edit { putString("account.pkce.oauth", value) }

    /** Les suppressions qui attendent la synchronisation : `course:<id>`, `card:<id>`, `exam:<id>`. */
    val tombstones: Set<String> get() = prefs.getStringSet("sync.tombstones", emptySet()).orEmpty().toSet()

    fun addTombstones(ids: Collection<String>) {
        if (ids.isEmpty()) return
        prefs.edit { putStringSet("sync.tombstones", tombstones + ids) }
    }

    fun removeTombstones(ids: Collection<String>) {
        prefs.edit { putStringSet("sync.tombstones", tombstones - ids.toSet()) }
    }

    /**
     * Les cartes notées qui attendent de monter (`review_logs`), une ligne JSON chacune : le
     * classement de la semaine et les statistiques de l'iPhone les comptent. Cinq cents au plus.
     */
    val pendingReviews: Set<String> get() = prefs.getStringSet("sync.reviews", emptySet()).orEmpty().toSet()

    fun queueReview(row: String) {
        val current = pendingReviews
        if (current.size >= 500) return
        prefs.edit { putStringSet("sync.reviews", current + row) }
    }

    fun removeReviews(rows: Collection<String>) {
        prefs.edit { putStringSet("sync.reviews", pendingReviews - rows.toSet()) }
    }

    /** Les notes en attente dont la carte a changé d'identifiant (`LessonRepository.rekey`). */
    fun remapReviews(cardIds: Map<String, String>) {
        if (cardIds.isEmpty()) return
        val current = pendingReviews
        val next = current.map { line ->
            val row = runCatching { MicaboJson.parseToJsonElement(line) }.getOrNull() as? kotlinx.serialization.json.JsonObject
            val card = row?.str("card_id")?.lowercase().orEmpty()
            val replaced = cardIds[card]
            if (row == null || replaced == null) line else kotlinx.serialization.json.JsonObject(row + ("card_id" to kotlinx.serialization.json.JsonPrimitive(replaced))).toString()
        }.toSet()
        if (next != current) prefs.edit { putStringSet("sync.reviews", next) }
    }

    /**
     * **Ce qui attendait de monter pour un compte**, mis de côté quand il s'en va (déconnexion,
     * session perdue, « Tout effacer ») : poussées sous l'invité, ses suppressions ne
     * touchaient aucune ligne et ses notes étaient refusées, puis tout était jeté. Elles
     * reviennent dans la file à sa prochaine connexion (`unpark`).
     */
    fun park(user: String) {
        if (user.isEmpty()) return
        val tombstones = this.tombstones
        val reviews = pendingReviews
        if (tombstones.isEmpty() && reviews.isEmpty()) return
        val tombKey = "sync.parked.tombstones.$user"
        val reviewKey = "sync.parked.reviews.$user"
        val parkedTombstones = prefs.getStringSet(tombKey, emptySet()).orEmpty().toSet()
        val parkedReviews = prefs.getStringSet(reviewKey, emptySet()).orEmpty().toSet()
        prefs.edit {
            putStringSet(tombKey, parkedTombstones + tombstones)
            putStringSet(reviewKey, (parkedReviews + reviews).take(500).toSet())
            putStringSet("sync.tombstones", emptySet())
            putStringSet("sync.reviews", emptySet())
        }
    }

    /** Ce qui avait été mis de côté pour ce compte revient dans la file. */
    fun unpark(user: String) {
        if (user.isEmpty()) return
        val tombKey = "sync.parked.tombstones.$user"
        val reviewKey = "sync.parked.reviews.$user"
        val parkedTombstones = prefs.getStringSet(tombKey, null)
        val parkedReviews = prefs.getStringSet(reviewKey, null)
        if (parkedTombstones == null && parkedReviews == null) return
        val tombstones = this.tombstones + parkedTombstones.orEmpty()
        val reviews = (pendingReviews + parkedReviews.orEmpty()).take(500).toSet()
        prefs.edit {
            putStringSet("sync.tombstones", tombstones)
            putStringSet("sync.reviews", reviews)
            remove(tombKey)
            remove(reviewKey)
        }
    }

    /** La dernière synchronisation réussie, en millisecondes ; 0 pour tout reprendre. */
    var syncWatermark: Long
        get() = prefs.getLong("sync.watermark", 0)
        set(value) = prefs.edit { putLong("sync.watermark", value) }

    /** Le compte (ou l'invité) pour lequel le repère a été pris : un autre repart de zéro. */
    var syncUser: String
        get() = prefs.getString("sync.user", "").orEmpty()
        set(value) = prefs.edit { putString("sync.user", value) }

    /**
     * Ce qu'était le dernier utilisateur synchronisé : `account`, `guest`, ou vide (avant cette
     * date). Un compte qui laisse place à l'invité (déconnexion) ne fait pas remonter ses leçons
     * sous l'invité ; un invité qui en remplace un autre (une sauvegarde restaurée, un invité
     * recréé), si.
     */
    var syncUserKind: String
        get() = prefs.getString("sync.userKind", "").orEmpty()
        set(value) = prefs.edit { putString("sync.userKind", value) }

    /**
     * **Le transfert de l'invité vers le compte** (`create_guest_claim`, puis `claim_guest`) : le
     * jeton, valable vingt-quatre heures, pris avec la session de l'invité juste avant la
     * connexion, l'heure où il a été pris, et l'invité qu'il transfère. Gardé tant que le
     * transfert n'a pas abouti : il se réessaie au passage suivant.
     */
    var guestClaimToken: String
        get() = prefs.getString("claim.token", "").orEmpty()
        set(value) = prefs.edit { putString("claim.token", value) }
    var guestClaimAt: Long
        get() = prefs.getLong("claim.at", 0)
        set(value) = prefs.edit { putLong("claim.at", value) }
    var guestClaimFrom: String
        get() = prefs.getString("claim.from", "").orEmpty()
        set(value) = prefs.edit { putString("claim.from", value) }

    fun clearGuestClaim() {
        prefs.edit {
            remove("claim.token")
            remove("claim.at")
            remove("claim.from")
        }
    }

    /**
     * **Le compte dont la session a été perdue** (GoTrue a refusé son jeton) et l'heure : la
     * synchronisation attend qu'il se reconnecte plutôt que de pousser ses leçons sous l'invité.
     * Effacé par « Tout effacer » (le préfixe `account.` n'est pas gardé), et par une connexion.
     */
    var lostAccount: String
        get() = prefs.getString("account.lost", "").orEmpty()
        set(value) = prefs.edit { putString("account.lost", value) }
    var lostAccountAt: Long
        get() = prefs.getLong("account.lostAt", 0)
        set(value) = prefs.edit { putLong("account.lostAt", value) }

    /** Le dernier changement du profil fait ici, en millisecondes ; 0 avant cette date. */
    var profileUpdatedAt: Long
        get() = prefs.getLong("profile.updatedAt", 0)
        set(value) = prefs.edit { putLong("profile.updatedAt", value) }

    /**
     * **La leçon du parcours d'accueil reste à écrire** (`LessonCreation.onboarding`). Posé à la
     * fin du parcours, retiré à la première leçon : celle-là part avec `onboarding: true`, et le
     * serveur l'accorde même depuis un PDF ou des photos, une fois (`begin_lesson`).
     */
    var onboardingLessonPending: Boolean
        get() = prefs.getBoolean("onboarding.lessonPending", false)
        set(value) = prefs.edit { putBoolean("onboarding.lessonPending", value) }

    /** L'empreinte du profil tel qu'il est monté la dernière fois (`CloudSync.pushProfile`). */
    var profileSignature: String
        get() = prefs.getString("sync.profile", "").orEmpty()
        set(value) = prefs.edit { putString("sync.profile", value) }

    fun clearAccount() {
        prefs.edit {
            listOf("account.access", "account.refresh", "account.expiresAt", "account.user", "account.email", "account.name").forEach(::remove)
        }
    }

    fun clearSession() {
        prefs.edit {
            remove("auth.access")
            remove("auth.refresh")
            remove("auth.expiresAt")
            remove("auth.user")
        }
    }

    companion object {
        /** La langue de l'interface, lue avant que l'app ne démarre (pour `attachBaseContext`). */
        fun storedLanguage(context: Context): String =
            context.getSharedPreferences("micabo", Context.MODE_PRIVATE).getString("language", "").orEmpty()
    }
}
