package com.micabo.app.ui.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.i18n.AppLocale
import com.micabo.app.i18n.t
import com.micabo.app.onboarding.Countries
import com.micabo.app.onboarding.ExamChoice
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.OnboardingStep
import com.micabo.app.onboarding.SchoolSystem
import com.micabo.app.onboarding.SubjectCatalog
import com.micabo.app.onboarding.SubjectDisplay
import com.micabo.app.onboarding.SubjectGroup
import com.micabo.app.onboarding.SubjectKind
import com.micabo.app.onboarding.WorldCountries
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboGhostButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.ChapterOpener
import com.micabo.app.ui.v3.GroupHeader
import com.micabo.app.ui.v3.LocalStill
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.MikaRow
import com.micabo.app.ui.v3.OnbScreen
import com.micabo.app.ui.v3.V3Chip
import com.micabo.app.ui.v3.V3Metric
import com.micabo.app.ui.v3.V3OptionRow
import com.micabo.app.ui.v3.V3Title
import com.micabo.app.ui.v3.subjectTone
import com.micabo.app.ui.v3.v3Card
import com.micabo.app.ui.v3.wash
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** **Une question** (`OnbQuestion`) : le titre en haut, Mika qui réagit, les réponses. */
@Composable
fun Question(
    title: String,
    say: String?,
    mood: MikaMood = MikaMood.IDLE,
    footer: (@Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit)? = null,
    answers: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    OnbScreen(
        header = {
            V3Title(title, Modifier.padding(top = 16.dp))
            if (say != null) MikaRow(say, mood, Modifier.padding(top = 12.dp))
        },
        body = {
            Column(Modifier.fillMaxWidth().padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = answers)
        },
        footer = footer,
    )
}

/** Le pied d'un choix unique : toucher une ligne la choisit seulement, « Continuer » avance. */
@Composable
fun ChoiceFooter(model: OnboardingModel, enabled: Boolean) {
    MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = enabled, modifier = Modifier.testTag("cta"))
}

// MARK: - Les stories

private enum class Story(val titleKey: String) {
    INTRO("ios.onb16.story.intro"),
    LESSON("ios.onb14.story1"),
    QUIZ("ios.onb10.story2"),
    SCAN("ios.onb16.scan.title"),
    PLAN("ios.onb10.story4"),
}

/**
 * **Les stories** (lot 16) : « Tous tes cours, simplifiés. », puis les sources, le quiz, le
 * scanner, le plan. La langue de l'app se change en haut ; « J'ai déjà un compte » en bas.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun StoriesStep(model: OnboardingModel, host: OnboardingHost, page: Int? = null) {
    val colors = Micabo.colors
    val pager = rememberPagerState(initialPage = page ?: 0) { Story.entries.size }
    val scope = rememberCoroutineScope()
    val exam = SchoolSystem.flagshipExam(model.regionCode) ?: t("ios.onb5.exam.testName")
    LaunchedEffect(pager.currentPage) { host.track("onboarding_story_viewed", mapOf("index" to pager.currentPage + 1)) }
    Column(Modifier.fillMaxSize().background(colors.canvas), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.widthIn(max = com.micabo.app.ui.v3.V3Metric.readable).fillMaxWidth().heightIn(min = 44.dp).padding(horizontal = 20.dp), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            LanguageChip(host)
        }
        HorizontalPager(state = pager, modifier = Modifier.weight(1f).widthIn(max = com.micabo.app.ui.v3.V3Metric.readable).fillMaxWidth().testTag("stories")) { index ->
            StoryPage(Story.entries[index], exam)
        }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.Center) {
            Story.entries.forEachIndexed { index, _ ->
                Box(Modifier.padding(horizontal = 3.5.dp).size(7.dp).clip(CircleShape).background(if (index == pager.currentPage) colors.ink else colors.inkTertiary))
            }
        }
        Column(
            Modifier.widthIn(max = com.micabo.app.ui.v3.V3Metric.readable).fillMaxWidth().navigationBarsPadding().padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 16.dp).testTag("footer"),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            val last = pager.currentPage == Story.entries.lastIndex
            MicaboButton(t(if (last) "ios.onb10.story.start" else "common.continue"), onClick = {
                if (last) model.advance() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
            }, modifier = Modifier.testTag("cta"))
            MicaboSecondaryButton(t("common.alreadyAccount"), onClick = host::signIn)
        }
    }
}

@Composable
private fun LanguageChip(host: OnboardingHost) {
    val colors = Micabo.colors
    var open by remember { mutableStateOf(false) }
    val current = AppLocale.ofLocale(currentLocale)
    Box {
        Row(
            Modifier
                .heightIn(min = 36.dp)
                .clip(CircleShape)
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, CircleShape)
                .clickable { open = true }
                .padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            Text(current.label, style = text(15.sp, FontWeight.SemiBold), color = colors.inkSecondary)
            Icon(Icons.Rounded.ExpandMore, contentDescription = t("ios.appLanguage"), tint = colors.inkSecondary, modifier = Modifier.size(18.dp))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            AppLocale.entries.forEach { locale ->
                DropdownMenuItem(text = { Text(locale.label) }, onClick = {
                    open = false
                    if (locale != current) host.pickLanguage(locale.code)
                })
            }
        }
    }
}

@Composable
private fun StoryPage(story: Story, exam: String) {
    val colors = Micabo.colors
    val keyword = when (story) {
        Story.INTRO, Story.LESSON -> colors.accentBright
        Story.QUIZ -> colors.green
        Story.SCAN -> colors.pink
        Story.PLAN -> colors.yellow
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        V3Title(t(story.titleKey), Modifier.padding(top = 14.dp), size = 40, keyword = keyword, align = TextAlign.Center)
        val shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp)
        Column(
            Modifier
                .padding(top = 26.dp)
                .fillMaxWidth()
                .weight(1f)
                .clip(shape)
                .background(Brush.verticalGradient(listOf(colors.surface, colors.canvas)))
                .border(2.dp, colors.stroke, shape)
                .padding(start = 18.dp, end = 18.dp, top = 26.dp),
        ) {
            // L'illustration garde ses proportions quand le texte du téléphone est très agrandi,
            // et se mesure à sa hauteur naturelle : sur un petit écran, la carte la coupe en bas
            // (elle se fond dans le fond) au lieu d'écraser ses lignes.
            Column(
                Modifier.fillMaxWidth().wrapContentHeight(Alignment.Top, unbounded = true),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                com.micabo.app.ui.v3.CappedFontScale {
                    when (story) {
                        Story.INTRO -> StoryIntro()
                        Story.LESSON -> StoryLesson()
                        Story.QUIZ -> StoryQuiz()
                        Story.SCAN -> StoryScan()
                        Story.PLAN -> StoryPlan(exam)
                    }
                }
            }
        }
    }
}

@Composable
private fun StoryTile(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Micabo.colors.surfaceMuted)) { content() }
}

@Composable
private fun StoryIntro() {
    val colors = Micabo.colors
    Mika(MikaMood.WAVE, 96.dp, Modifier.fillMaxWidth())
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        listOf("Mathématiques", "Histoire", "SVT", "Anglais").forEach { subject ->
            StoryTile {
                Row(Modifier.padding(horizontal = 12.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    val tone = subjectTone(subject)
                    com.micabo.app.ui.v3.IconTile(MicaboIcons.subject(SubjectKind.of(subject)), tone, size = 38.dp, iconSize = 22.dp, radius = 11.dp)
                    Text(SubjectDisplay.subject(subject, appLanguageCode), style = Type.option, color = colors.ink, modifier = Modifier.weight(1f))
                    Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(22.dp))
                }
            }
        }
    }
}

@Composable
private fun StoryLesson() {
    val colors = Micabo.colors
    SourceStrip(highlighted = OnbSource.PHOTO, tile = 40)
    NotebookPhoto(Modifier.fillMaxWidth().height(132.dp))
    Icon(Icons.Rounded.ArrowDownward, null, tint = colors.accentBright, modifier = Modifier.fillMaxWidth().size(20.dp))
    StoryTile {
        Column(Modifier.padding(16.dp)) {
            Text(t("ios.onb12.notebook.title"), style = display(22.sp), color = colors.ink)
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tag(t("lesson.nav.notes"), colors.accentBright)
                Tag(t("lesson.nav.quiz"), colors.green)
                Tag(t("lesson.nav.flashcards"), colors.lilac)
            }
        }
    }
}

@Composable
fun Tag(text: String, tone: Color) {
    Text(
        text,
        style = text(13.sp, FontWeight.Bold),
        color = tone,
        maxLines = 1,
        modifier = Modifier.clip(CircleShape).background(wash(tone)).padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
private fun StoryQuiz() {
    val colors = Micabo.colors
    Text(t("ios.onb.mika.design.question"), style = display(22.sp), color = colors.ink)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("1961" to false, "1989" to true, "1991" to false).forEach { (year, right) ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (right) wash(colors.green) else colors.surfaceMuted)
                    .border(1.5.dp, if (right) colors.green else colors.stroke, RoundedCornerShape(14.dp))
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(year, style = Type.option, color = colors.ink, modifier = Modifier.weight(1f))
                if (right) Icon(Icons.Rounded.CheckCircle, null, tint = colors.green)
            }
        }
    }
}

@Composable
private fun StoryScan() {
    val colors = Micabo.colors
    LeftToRight {
        Box(Modifier.fillMaxWidth().padding(vertical = 6.dp), contentAlignment = Alignment.Center) {
            Viewfinder(colors.pink, Modifier.fillMaxWidth().height(96.dp))
            com.micabo.app.ui.v3.FitText("2x² − 8x + 6 = 0", display(26.sp), colors.ink)
        }
    }
    StoryTile {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("1" to t("ios.onb10.story.step1"), "2" to t("ios.onb10.story.step2")).forEach { (number, label) ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(number, style = text(13.sp, FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.size(26.dp).clip(CircleShape).background(colors.accent).padding(top = 4.dp))
                    Text(label, style = text(17.sp), color = colors.ink)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(26.dp))
                Text(t("ios.onb10.story.result"), style = text(17.sp, FontWeight.SemiBold), color = colors.green)
            }
        }
    }
}

@Composable
private fun StoryPlan(exam: String) {
    val colors = Micabo.colors
    val locale = currentLocale
    StoryTile {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) {
                Text(t("ios.cal.nextExam"), style = text(13.sp), color = colors.inkSecondary)
                Text(exam, style = display(22.sp), color = colors.ink)
            }
            Text(Words.duration(12, locale), style = text(15.sp, FontWeight.Bold), color = colors.yellowInk, modifier = Modifier.clip(CircleShape).background(colors.yellowWash).padding(horizontal = 12.dp, vertical = 6.dp))
        }
    }
    StoryTile { WeekStrip(start = LocalDate.of(2026, 11, 9), selected = 4, done = 4, event = 6, modifier = Modifier.padding(vertical = 14.dp, horizontal = 6.dp)) }
    Row(
        Modifier.clip(CircleShape).background(colors.surfaceMuted).padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Rounded.Timer, null, tint = colors.accentBright, modifier = Modifier.size(18.dp))
        Text(t("ios.onb10.story.focus", "time" to t("ios.quiz.time.short", "n" to 25)), style = text(15.sp, FontWeight.SemiBold), color = colors.ink)
    }
}

// MARK: - Faisons connaissance

@Composable
fun WelcomeStep(model: OnboardingModel) =
    ChapterOpener(t("ios.onb15.open.welcome.title"), t("ios.onb16.welcome.say"), MikaMood.WAVE, t("ios.onb16.welcome.cta"), instant = !model.isMovingForward) { model.advance() }

@Composable
fun NameStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val name = model.displayName.trim()
    val focus = remember { FocusRequester() }
    val still = LocalStill.current || LocalInspectionMode.current
    LaunchedEffect(Unit) { if (!still) runCatching { focus.requestFocus() } }
    Question(
        title = t("ios.onb15.q.name"),
        say = if (name.isEmpty()) t("ios.onb12.say.name") else t("ios.onb12.react.name", "name" to name),
        mood = if (name.isEmpty()) MikaMood.WAVE else MikaMood.HAPPY,
    ) {
        Box(Modifier.fillMaxWidth().v3Card(selected = name.isNotEmpty()).padding(vertical = 18.dp, horizontal = 16.dp), contentAlignment = Alignment.Center) {
            if (model.displayName.isEmpty()) {
                Text(t("ios.onb.name.placeholder"), style = display(40.sp), color = colors.inkTertiary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
            BasicTextField(
                value = model.displayName,
                onValueChange = { model.displayName = it.take(40) },
                textStyle = display(40.sp).copy(color = colors.ink, textAlign = TextAlign.Center),
                cursorBrush = SolidColor(colors.accent),
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { if (name.isNotEmpty()) model.advance() }),
                modifier = Modifier.fillMaxWidth().focusRequester(focus).testTag("nameField"),
            )
        }
        MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = name.isNotEmpty(), modifier = Modifier.padding(top = 10.dp).testTag("cta"))
    }
}

@Composable
fun countryLabel(model: OnboardingModel): String =
    if (model.country == "other") model.customCountry?.let { WorldCountries.country(it, currentLocale)?.name } ?: countryName("other") else countryName(model.country)

@Composable
fun CountryStep(model: OnboardingModel) {
    val colors = Micabo.colors
    var query by remember { mutableStateOf("") }
    val name = model.displayName.trim()
    val locale = currentLocale
    val focus = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    Question(
        title = t("ios.onb12.q.country"),
        say = if (name.isEmpty()) t("ios.onb12.say.countryAny") else t("ios.onb12.say.country", "name" to name),
        mood = if (name.isEmpty()) MikaMood.LOOK else MikaMood.HAPPY,
        footer = {
            // Le pays présélectionné, gardé sans y toucher, compte comme choisi (il se retrouve à la reprise).
            MicaboButton(t("common.continue"), onClick = {
                if (model.country != "other") model.selectCountry(model.country)
                model.advance()
            }, enabled = model.hasAnsweredCountry, modifier = Modifier.testTag("cta"))
        },
    ) {
        Row(
            Modifier.fillMaxWidth().clip(CircleShape).background(colors.surfaceMuted).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(Icons.Rounded.Search, null, tint = colors.inkTertiary)
            Box(Modifier.weight(1f)) {
                if (query.isEmpty()) Text(t("ios.countryPlaceholder"), style = text(17.sp), color = colors.inkTertiary)
                BasicTextField(
                    value = query,
                    onValueChange = { query = it },
                    textStyle = text(17.sp).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (query.isNotEmpty()) Icon(Icons.Rounded.Close, t("ios.clearSearch"), tint = colors.inkTertiary, modifier = Modifier.clickable { query = "" })
        }
        if (query.isNotBlank()) {
            val matches = WorldCountries.matches(query, locale)
            if (matches.isEmpty()) {
                Text(t("ios.countryNone"), style = text(17.sp), color = colors.inkSecondary, modifier = Modifier.padding(top = 6.dp))
            }
            matches.forEach { country ->
                // Un résultat choisi : la recherche se vide, le clavier se range, la liste le montre coché.
                V3OptionRow(country.name, selected = false, emoji = country.flag, onClick = {
                    model.selectWorld(country.code)
                    query = ""
                    focus.clearFocus()
                    keyboard?.hide()
                })
            }
        } else {
            val custom = model.customCountry
            if (model.country == "other" && custom != null) {
                V3OptionRow(WorldCountries.country(custom, locale)?.name ?: custom, selected = true, emoji = Countries.flag(custom), onClick = {})
            }
            val guessed = Countries.detected(listOf(locale.toLanguageTag()))
            val listed = listOfNotNull(guessed) + Countries.listed.filter { it != guessed }
            listed.forEach { code ->
                V3OptionRow(countryName(code), selected = model.country == code, emoji = Countries.flag(code), onClick = { model.selectCountry(code) })
            }
        }
    }
}

@Composable
fun SchoolTypeStep(model: OnboardingModel) {
    Question(t("ios.onb12.q.schoolType"), t("ios.onb12.react.country", "country" to countryLabel(model)), MikaMood.HAPPY, footer = {
        ChoiceFooter(model, enabled = model.tracks.any { it.id == model.schoolTrack?.id })
    }) {
        model.tracks.forEach { track ->
            V3OptionRow(track.title, selected = model.schoolTrack?.id == track.id, icon = MicaboIcons.tier(track.tier), onClick = { model.chooseTrack(track) })
        }
    }
}

@Composable
fun SchoolYearStep(model: OnboardingModel) {
    val track = model.schoolTrack
    val title = when (track?.tier) {
        "lowerSecondary", "upperSecondary", null -> t("ios.onb12.q.year")
        else -> t("ios.onb12.q.yearHigher")
    }
    Question(title, if (track == null) t("ios.onb12.say.level") else t("ios.onb12.react.track", "track" to track.title), if (track == null) MikaMood.IDLE else MikaMood.HAPPY, footer = {
        ChoiceFooter(model, enabled = track?.years.orEmpty().any { it.id == model.schoolYear?.id })
    }) {
        track?.years.orEmpty().forEach { year ->
            V3OptionRow(year.title, selected = model.schoolYear?.id == year.id, onClick = { model.chooseYear(year) })
        }
    }
}

@Composable
fun LevelStep(model: OnboardingModel) {
    Question(t("ios.onb12.q.level"), t("ios.onb12.react.countryAny", "country" to countryLabel(model)), MikaMood.HAPPY, footer = {
        ChoiceFooter(model, enabled = Countries.genericStages.any { it.id == model.stage?.id })
    }) {
        Countries.genericStages.forEach { stage ->
            val title = when (stage.id) {
                "generic.middle" -> t("ios.level.generic.middle")
                "generic.high" -> t("ios.level.generic.high")
                "generic.college" -> t("ios.level.generic.college")
                "generic.university" -> t("ios.level.generic.university")
                else -> t("ios.level.other")
            }
            V3OptionRow(title, selected = model.stage?.id == stage.id, icon = MicaboIcons.tier(stage.tier), onClick = { model.chooseStage(stage.copy(title = title)) })
        }
    }
}

@Composable
fun examTitle(choice: ExamChoice, row: Boolean = false): String = when (choice) {
    is ExamChoice.Named -> choice.exam.title
    ExamChoice.Test -> if (row) t("ios.onb5.exam.test") else t("ios.onb5.exam.testName")
    ExamChoice.Finals -> if (row) t("ios.onb5.exam.finals") else t("ios.onb5.exam.finalsName")
    ExamChoice.None -> if (row) t("ios.onb10.exam.none") else t("ios.onb5.exam.none")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val locale = currentLocale
    val choice = model.examChoice
    val date = model.examDate
    var picking by remember { mutableStateOf(false) }
    val reaction = when {
        choice == null -> null
        choice == ExamChoice.None -> t("ios.onb10.react.exam.none")
        choice == ExamChoice.Test -> t("ios.onb10.react.exam.test")
        date != null -> {
            val days = model.examDaysLeft() ?: 0
            val vars = arrayOf("exam" to examTitle(choice), "time" to Words.duration(days, locale))
            if (days < 30) t("ios.onb10.react.exam.soon", *vars) else t("ios.onb10.react.exam.far", *vars)
        }
        else -> null
    }
    val say = reaction ?: model.classLabel?.let { t("ios.onb12.react.year", "class" to it) } ?: t("ios.onb12.say.exam")
    val mood = when {
        reaction == null -> MikaMood.THINK
        choice == ExamChoice.None -> MikaMood.WINK
        else -> MikaMood.SURPRISE
    }
    Question(t("ios.onb12.q.exam"), say, mood, footer = {
        MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = choice != null, modifier = Modifier.testTag("cta"))
    }) {
        model.examChoices.forEach { option ->
            V3OptionRow(examTitle(option, row = true), selected = choice == option, icon = MicaboIcons.exam, onClick = { model.chooseExam(option) })
        }
        if (choice != null && choice.hasDate && date != null) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = V3Metric.optionHeight).v3Card(radius = V3Metric.radiusInner).clickable { picking = true }.padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(MicaboIcons.exam, null, tint = colors.accentBright, modifier = Modifier.size(26.dp))
                Column(Modifier.weight(1f)) {
                    Text(t("ios.onb5.exam.dateLabel"), style = text(13.sp), color = colors.inkSecondary)
                    Text(Words.date(date, locale), style = text(17.sp, FontWeight.SemiBold), color = colors.ink)
                }
                val days = model.examDaysLeft() ?: 0
                if (days > 0) Text(Words.duration(days, locale), style = text(15.sp, FontWeight.Bold), color = colors.yellowInk, modifier = Modifier.clip(CircleShape).background(colors.yellowWash).padding(horizontal = 10.dp, vertical = 5.dp))
                Icon(Icons.Rounded.Edit, null, tint = colors.accentBright, modifier = Modifier.size(18.dp))
            }
        }
    }
    if (picking && date != null) {
        val state = rememberDatePickerState(initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { millis -> model.examDate = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate() }
                    picking = false
                }) { Text(t("ios.done")) }
            },
        ) { DatePicker(state = state) }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SubjectsStep(model: OnboardingModel) {
    val mine = model.classSubjects
    var showCatalog by remember { mutableStateOf(false) }
    val others = SubjectCatalog.all.filter { it !in mine }
    val showsOthers = mine.isEmpty() || showCatalog || !mine.containsAll(model.subjects)
    val say = when {
        model.subjects.isNotEmpty() -> t("ios.onb10.react.subjects")
        mine.isNotEmpty() && model.classLabel != null -> t("ios.onb12.say.subjectsOf", "class" to model.classLabel!!)
        else -> t("ios.onb12.say.subjects")
    }
    Question(t("ios.onb12.q.subjects"), say, if (model.subjects.isNotEmpty()) MikaMood.WRITE else MikaMood.IDLE, footer = {
        MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = model.subjects.isNotEmpty(), modifier = Modifier.testTag("cta"))
    }) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (mine.isNotEmpty()) {
                val groups = SubjectGroup.grouped(mine, model.country)
                groups.forEach { (group, subjects) ->
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (groups.size > 1) GroupHeader(t(group.titleKey))
                        SubjectChips(model, subjects)
                    }
                }
            }
            if (showsOthers) {
                if (mine.isNotEmpty()) GroupHeader(t("ios.onb10.subjects.more"))
                SubjectChips(model, others)
            } else {
                com.micabo.app.ui.v3.V3AddChip(t("ios.onb10.subjects.more")) { showCatalog = true }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SubjectChips(model: OnboardingModel, subjects: List<String>) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        subjects.forEach { subject ->
            V3Chip(
                SubjectDisplay.subject(subject, appLanguageCode),
                onClick = { model.toggleSubject(subject) },
                icon = MicaboIcons.forSubject(subject, model.country),
                iconTone = subjectTone(subject),
                selected = subject in model.subjects,
            )
        }
    }
}

@Composable
fun HardestSubjectStep(model: OnboardingModel) {
    Question(t("ios.onb16.q.hardest"), t("ios.onb16.say.hardest"), MikaMood.WINK, footer = {
        ChoiceFooter(model, enabled = model.hardestSubject != null)
    }) {
        model.subjects.sorted().forEach { subject ->
            V3OptionRow(
                SubjectDisplay.subject(subject, appLanguageCode),
                selected = model.hardestSubject == subject,
                icon = MicaboIcons.subject(SubjectKind.of(subject)),
                iconTone = subjectTone(subject),
                onClick = { model.chooseHardest(subject) },
            )
        }
    }
}

/** **Les ouvertures de chapitre où Mika parle** : sa phrase, son humeur ; le récit nomme l'exemple de son pays. */
@Composable
fun ChapterOpenerStep(step: OnboardingStep, model: OnboardingModel) {
    val (title, say, mood) = when (step) {
        OnboardingStep.studyIntro -> Triple("ios.onb15.open.study.title", t("ios.onb16.open.study.say"), MikaMood.LOOK)
        OnboardingStep.helpIntro -> Triple("ios.onb15.open.help.title", t("ios.onb16.open.help.say"), MikaMood.HAPPY)
        OnboardingStep.goalIntro -> Triple("ios.onb15.open.goal.title", t("ios.onb16.open.goal.say"), MikaMood.PROUD)
        OnboardingStep.organizeIntro -> Triple("ios.onb15.open.organize.title", t("ios.onb15.open.organize.say"), MikaMood.WRITE)
        else -> Triple("ios.onb15.open.story.title", t("ios.onb16.story.intro.say", "topic" to t(model.story.lessonKey)), MikaMood.WINK)
    }
    val cta = if (step == OnboardingStep.helpIntro || step == OnboardingStep.storyIntro) t("ios.onb12.recap.cta") else t("common.continue")
    ChapterOpener(t(title), say, mood, cta, instant = !model.isMovingForward) { model.advance() }
}
