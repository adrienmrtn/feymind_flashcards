package com.micabo.app.i18n

import android.content.res.Resources
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext

/**
 * **Une phrase des catalogues, ses variables passées par leur nom** (`L10n.t(key, vars:)` sur
 * l'iPhone) : `tr(R.string.ios_onb12_react_name, "name" to "Lina")`. L'ordre des `%n$s` vient de
 * la phrase anglaise (`StringVars`, engendré avec les chaînes) : le code n'a pas à le connaître.
 */
@Composable
@ReadOnlyComposable
fun tr(@StringRes id: Int, vararg vars: Pair<String, Any?>): String {
    LocalConfiguration.current
    return LocalContext.current.resources.tr(id, *vars)
}

/** Un pluriel des catalogues : le nombre, puis les autres variables par leur nom. */
@Composable
@ReadOnlyComposable
fun trPlural(@PluralsRes id: Int, count: Int, vararg vars: Pair<String, Any?>): String {
    LocalConfiguration.current
    return LocalContext.current.resources.trPlural(id, count, *vars)
}

/**
 * **Une phrase par sa clé du catalogue de l'iPhone** (`L10n.t("ios.onb15.q.name", vars:)`). La
 * clé est retrouvée dans `CatalogKeys`, engendré avec les chaînes ; une clé ICU au pluriel passe
 * par son `count`.
 */
@Composable
@ReadOnlyComposable
fun t(key: String, vararg vars: Pair<String, Any?>): String {
    LocalConfiguration.current
    return LocalContext.current.resources.t(key, *vars)
}

fun Resources.t(key: String, vararg vars: Pair<String, Any?>): String {
    CatalogKeys.strings[key]?.let { return tr(it, *vars) }
    CatalogKeys.plurals[key]?.let { id ->
        val values = vars.toMap()
        val name = StringVars.plurals[id]?.firstOrNull() ?: "count"
        val count = values[name]?.toString()?.toIntOrNull() ?: 0
        return trPlural(id, count, *vars)
    }
    return key
}

/** Vrai quand la clé existe dans les ressources de l'app (les tests de couverture). */
fun hasCatalogKey(key: String): Boolean = CatalogKeys.strings.containsKey(key) || CatalogKeys.plurals.containsKey(key)

fun Resources.tr(@StringRes id: Int, vararg vars: Pair<String, Any?>): String {
    val order = StringVars.strings[id] ?: return getString(id)
    val values = vars.toMap()
    val args = order.map { name -> values[name]?.toString().orEmpty() }
    return getString(id, *args.toTypedArray())
}

fun Resources.trPlural(@PluralsRes id: Int, count: Int, vararg vars: Pair<String, Any?>): String {
    val order = StringVars.plurals[id].orEmpty()
    val values = vars.toMap()
    val args = listOf<Any>(count) + order.drop(1).map { name -> values[name]?.toString().orEmpty() }
    return getQuantityString(id, count, *args.toTypedArray())
}
