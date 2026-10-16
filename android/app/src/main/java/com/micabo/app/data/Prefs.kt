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
        }
        _profile.value = next
    }

    fun reset() {
        prefs.edit { clear() }
        _profile.value = read()
    }

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
