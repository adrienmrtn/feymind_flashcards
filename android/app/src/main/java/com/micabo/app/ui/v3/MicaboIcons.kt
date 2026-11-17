package com.micabo.app.ui.v3

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Alarm
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Biotech
import androidx.compose.material.icons.rounded.Calculate
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Event
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.HistoryEdu
import androidx.compose.material.icons.rounded.HourglassBottom
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material.icons.rounded.PictureAsPdf
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.Quiz
import androidx.compose.material.icons.rounded.RocketLaunch
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.micabo.app.onboarding.SubjectGroup
import com.micabo.app.onboarding.SubjectKind
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.tone

/**
 * **Les icônes plates de l'app** (`MicaboIcon`) : sur l'iPhone, des symboles du système ; ici,
 * les icônes arrondies de Material, une par idée.
 */
object MicaboIcons {
    val book = Icons.Rounded.AutoStories
    val calculator = Icons.Rounded.Calculate
    val atom = Icons.Rounded.Science
    val flask = Icons.Rounded.Biotech
    val scroll = Icons.Rounded.HistoryEdu
    val globe = Icons.Rounded.Public
    val brain = Icons.Rounded.Psychology
    val palette = Icons.Rounded.Palette
    val quill = Icons.Rounded.Edit
    val diploma = Icons.Rounded.School
    val rocket = Icons.Rounded.RocketLaunch
    val computer = Icons.Rounded.Computer
    val trophy = Icons.Rounded.EmojiEvents
    val language = Icons.Rounded.Translate
    val star = Icons.Rounded.Star
    val hourglass = Icons.Rounded.HourglassBottom
    val flame = Icons.Rounded.LocalFireDepartment
    val notes = Icons.Rounded.Description
    val quiz = Icons.Rounded.Quiz
    val cards = Icons.Rounded.Style
    val photo = Icons.Rounded.PhotoCamera
    val pdf = Icons.Rounded.PictureAsPdf
    val audio = Icons.Rounded.Mic
    val text = Icons.Rounded.TextFields
    val alarm = Icons.Rounded.Alarm
    val flag = Icons.Rounded.Flag
    val unlock = Icons.Rounded.LockOpen
    val bell = Icons.Rounded.Notifications
    val card = Icons.Rounded.CreditCard
    val sparkles = Icons.Rounded.AutoAwesome
    val exam = Icons.Rounded.Event
    val puzzle = Icons.Rounded.Extension
    val mika = Icons.Rounded.ChatBubble
    val lightbulb = Icons.Rounded.Lightbulb

    fun subject(kind: SubjectKind?): ImageVector = when (kind) {
        SubjectKind.CALCULATOR -> calculator
        SubjectKind.ATOM -> atom
        SubjectKind.FLASK -> flask
        SubjectKind.SCROLL -> scroll
        SubjectKind.GLOBE -> globe
        SubjectKind.BRAIN -> brain
        SubjectKind.PALETTE -> palette
        SubjectKind.QUILL -> quill
        SubjectKind.DIPLOMA -> diploma
        SubjectKind.ROCKET -> computer
        SubjectKind.BOOK, null -> book
    }

    /** L'icône d'une matière dans la grille des matières (`OnbSubjectGroup.icon`). */
    fun forSubject(subject: String, country: String): ImageVector {
        if (SubjectGroup.isSport(subject)) return trophy
        SubjectKind.of(subject)?.let { return subject(it) }
        return when (SubjectGroup.of(subject, country)) {
            SubjectGroup.LANGUAGES -> language
            SubjectGroup.OTHER -> star
            SubjectGroup.MAIN -> book
        }
    }

    /** L'icône d'une marche d'études (`EducationTier.icon`). */
    fun tier(tier: String?): ImageVector = when (tier) {
        "lowerSecondary" -> book
        "upperSecondary" -> diploma
        "preUniversity" -> calculator
        "undergraduate" -> diploma
        "graduate" -> atom
        "health" -> flask
        "competitive" -> flag
        else -> star
    }
}

/** La teinte d'une matière : l'encre de son ton (`LessonTone.forSubject(icon).ink`). */
@Composable
fun subjectTone(subject: String): Color = Micabo.colors.tone(SubjectKind.tone(SubjectKind.of(subject))).vivid
