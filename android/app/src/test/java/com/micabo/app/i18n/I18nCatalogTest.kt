package com.micabo.app.i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **Les 32 langues sont complètes** : chaque phrase de l'app existe dans chaque langue (une
 * phrase identique à l'anglais, comme « Quiz » ou « YouTube », y est écrite explicitement par
 * `generate_strings.py` quand la langue la dit ainsi). Une phrase absente retomberait en
 * anglais à l'écran : ce test le refuse. Et chaque clé appelée par son nom dans le code existe.
 */
class I18nCatalogTest {
    private val res = File("src/main/res")

    /** Les dossiers des 32 langues de l'iPhone (`UiLocale`). */
    private val folders = listOf(
        "values", "values-fr", "values-de", "values-es", "values-b+es+419", "values-it", "values-pt", "values-pt-rBR",
        "values-nl", "values-pl", "values-ro", "values-sv", "values-da", "values-fi", "values-et", "values-cs",
        "values-sk", "values-hu", "values-hr", "values-sl", "values-sr", "values-bg", "values-el", "values-ru",
        "values-tr", "values-ar", "values-nb", "values-iw", "values-ja", "values-lt", "values-lv", "values-ko",
    )

    private fun strings(folder: String): Map<String, String> {
        val file = File(res, "$folder/strings.xml")
        if (!file.exists()) return emptyMap()
        return Regex("""<string name="([^"]+)"[^>]*>(.*?)</string>""", RegexOption.DOT_MATCHES_ALL)
            .findAll(file.readText()).associate { it.groupValues[1] to it.groupValues[2] }
    }

    private fun plurals(folder: String): Set<String> {
        val file = File(res, "$folder/plurals.xml")
        if (!file.exists()) return emptySet()
        return Regex("""<plurals name="([^"]+)"""").findAll(file.readText()).map { it.groupValues[1] }.toSet()
    }

    @Test
    fun thereAreThirtyTwoLanguages() {
        assertEquals(32, folders.size)
        for (folder in folders) assertTrue("$folder manque", File(res, "$folder/strings.xml").exists())
    }

    @Test
    fun everyStringExistsInEveryLanguage() {
        val base = strings("values").keys - "app_name"
        val missing = folders.drop(1).associateWith { folder -> base - strings(folder).keys }.filterValues { it.isNotEmpty() }
        assertTrue(
            "Phrases sans traduction (elles s'afficheraient en anglais) :\n" +
                missing.entries.joinToString("\n") { (folder, names) -> "$folder (${names.size}) : ${names.sorted().take(30)}" },
            missing.isEmpty(),
        )
    }

    @Test
    fun everyPluralExistsInEveryLanguage() {
        val base = plurals("values")
        val missing = folders.drop(1).associateWith { folder -> base - plurals(folder) }.filterValues { it.isNotEmpty() }
        assertTrue("Pluriels sans traduction : $missing", missing.isEmpty())
    }

    @Test
    fun noStringIsLeftAsItsKey() {
        val leftovers = folders.flatMap { folder -> strings(folder).filterValues { it.startsWith("ios.") || it.startsWith("lesson.") || it.startsWith("app.") }.keys.map { "$folder:$it" } }
        assertTrue("Clés affichées telles quelles : $leftovers", leftovers.isEmpty())
    }

    @Test
    fun noFrenchLeftInOtherLanguages() {
        // Une phrase française recopiée dans une autre langue que le français : les mots
        // les plus courants du français, entourés d'espaces, ne doivent pas y apparaître.
        val french = Regex("""\b(avec|pour|leçon|aujourd'hui|séance|révise|matières|tes cours)\b""")
        val offenders = folders.filter { it != "values-fr" && it != "values" }.flatMap { folder ->
            strings(folder).filter { (_, text) -> french.findAll(text).count() >= 2 }.keys.map { "$folder:$it" }
        }
        assertTrue("Du français dans une autre langue : ${offenders.take(40)}", offenders.isEmpty())
    }

    @Test
    fun everyKeyCalledByNameExists() {
        val code = File("src/main/java").walkTopDown().filter { it.extension == "kt" }.joinToString("\n") { it.readText() }
        val keys = Regex("""\bt\("((?:ios|lesson|common|app|country)\.[A-Za-z0-9_.\-]+)"""").findAll(code).map { it.groupValues[1] }.toSet()
        val missing = keys.filterNot(::hasCatalogKey)
        assertTrue("Clés introuvables : $missing", missing.isEmpty())
    }

    @Test
    fun noInventedSocialProof() {
        // Aucun nombre d'utilisateurs, aucune note ni aucun avis inventés ne s'affichent.
        val code = File("src/main/java").walkTopDown().filter { it.extension == "kt" && it.name != "CatalogKeys.kt" && it.name != "StringVars.kt" }.joinToString("\n") { it.readText() }
        for (banned in listOf("ios_onb_social", "ios.onb.social", "ios_proof_", "ReviewAvatar", "500 000", "500,000", "500.000")) {
            assertTrue("« $banned » est encore utilisé", !code.contains(banned))
        }
    }
}
