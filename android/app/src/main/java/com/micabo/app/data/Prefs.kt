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

    fun update(change: (Profile) -> Profile) {
        val next = change(_profile.value)
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
     */
    fun reset() {
        val session = listOf("auth.access", "auth.refresh", "auth.user").associateWith { prefs.getString(it, "").orEmpty() }
        val expiresAt = this.expiresAt
        prefs.edit {
            clear()
            session.forEach { (key, value) -> putString(key, value) }
            putLong("auth.expiresAt", expiresAt)
        }
        _profile.value = read()
    }

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

    /** La dernière synchronisation réussie, en millisecondes ; 0 pour tout reprendre. */
    var syncWatermark: Long
        get() = prefs.getLong("sync.watermark", 0)
        set(value) = prefs.edit { putLong("sync.watermark", value) }

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
