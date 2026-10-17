package com.micabo.app.ui.text

import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import com.micabo.app.ui.theme.Micabo

/**
 * **Le texte d'une leçon** : les `**mots-clés**` en gras, dans le violet des mots-clés, et les
 * formules `$…$` transposées (`FormulaRenderer`) dans une italique à empattements.
 */
fun richText(
    source: String,
    keyword: Color?,
    keywordWeight: FontWeight = FontWeight.ExtraBold,
): AnnotatedString = buildAnnotatedString {
    val marks = Regex("\\*\\*").findAll(source).count()
    val parts = if (marks >= 2) source.split("**") else listOf(source.replace("**", ""))
    // Un nombre impair de marques laisse la dernière ouverte : elle reste littérale.
    parts.forEachIndexed { index, part ->
        val bold = index % 2 == 1 && !(marks % 2 == 1 && index == parts.lastIndex)
        if (bold) {
            withStyle(SpanStyle(fontWeight = keywordWeight, color = keyword ?: Color.Unspecified)) { appendMath(part) }
        } else {
            appendMath(part)
        }
    }
}

private fun AnnotatedString.Builder.appendMath(text: String) {
    for (segment in FormulaRenderer.segments(text)) {
        if (segment.isMath) {
            withStyle(SpanStyle(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic)) { append(segment.text) }
        } else {
            append(segment.text)
        }
    }
}

/** Le texte sans balisage : pour un titre, une ligne de liste, une notification. */
fun plainText(source: String): String = FormulaRenderer.stripped(source.replace("**", ""))

@Composable
fun RichText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    color: Color = Micabo.colors.ink,
    tintsKeywords: Boolean = true,
    textAlign: TextAlign? = null,
    maxLines: Int = Int.MAX_VALUE,
    keywordColor: Color? = null,
) {
    val keyword = if (tintsKeywords) keywordColor ?: Micabo.colors.keyword else null
    val annotated = remember(text, keyword) { richText(text, keyword) }
    Text(
        text = annotated,
        style = style,
        color = color,
        modifier = modifier,
        textAlign = textAlign,
        maxLines = maxLines,
        inlineContent = emptyMap<String, InlineTextContent>(),
    )
}
