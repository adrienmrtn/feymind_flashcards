package com.micabo.app.data

/**
 * **Le compte des relecteurs** des stores (`AppStoreReview` sur iPhone).
 *
 * Google Play a refusé l'app : les informations de connexion données ne permettaient pas
 * d'entrer. Android n'avait que Google, Apple et le lien par courriel, et un relecteur ne
 * relève pas de boîte. Taper l'adresse des notes de relecture et appuyer sur « Recevoir un
 * lien » ouvre donc la session du compte de démonstration tout de suite, par mot de passe,
 * sans courriel. L'écran ne change pas.
 *
 * Toute adresse en `@apple.com` passe, comme sur l'iPhone (personne chez Apple ne relève
 * une boîte pour essayer une app), et `review@micabo.app` est l'adresse donnée à Google.
 */
object StoreReview {
    const val EMAIL = "review@apple.com"
    const val PASSWORD = "Micabo-Review-2026-Kx9m"
    private const val GOOGLE_EMAIL = "review@micabo.app"
    private const val APPLE_DOMAIN = "apple.com"

    fun matches(raw: String?): Boolean {
        val address = raw?.trim()?.lowercase().orEmpty()
        val at = address.lastIndexOf('@')
        if (at <= 0) return false
        return address == GOOGLE_EMAIL || address.substring(at + 1) == APPLE_DOMAIN
    }
}
