package com.micabo.app.ui.onboarding

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.StorePlan
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.text.NumberFormat
import java.util.Date

/** Un écran du parcours : son contenu qui défile, et le bouton du bas. */
@Composable
private fun StepScaffold(
    cta: String,
    onNext: () -> Unit,
    enabled: Boolean = true,
    centered: Boolean = false,
    /** Sous le bouton : un lien discret, comme « J'ai déjà un compte » sur l'accroche. */
    secondary: String? = null,
    onSecondary: () -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = if (centered) Alignment.CenterHorizontally else Alignment.Start,
            verticalArrangement = if (centered) Arrangement.Center else Arrangement.Top,
        ) {
            if (centered) Spacer(Modifier.height(24.dp))
            content()
            Spacer(Modifier.height(24.dp))
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            MicaboButton(cta, onClick = onNext, enabled = enabled)
            if (secondary != null) {
                TextButton(onClick = onSecondary, modifier = Modifier.padding(top = 6.dp)) {
                    Text(secondary, style = nunito(15.sp, FontWeight.ExtraBold), color = Micabo.colors.inkSecondary)
                }
            }
        }
    }
}

/** Mika qui parle : une bulle à côté de lui, comme sur iPhone. */
@Composable
private fun MikaSays(text: String, mood: MikaMood = MikaMood.IDLE, size: Dp = 64.dp) {
    val colors = Micabo.colors
    val shape = RoundedCornerShape(topStart = 4.dp, topEnd = 18.dp, bottomEnd = 18.dp, bottomStart = 18.dp)
    Row(verticalAlignment = Alignment.Top) {
        Mika(mood, size)
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier
                .padding(top = 6.dp)
                .clip(shape)
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, shape)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            RichText(text, style = nunito(19.sp, FontWeight.ExtraBold, lineHeight = 25.sp), color = colors.ink, keywordColor = colors.accent)
        }
    }
}

/** **L'accroche** : le logo, « Apprends 2× plus vite », Mika qui salue. */
@Composable
fun Hook(onNext: () -> Unit, onSignIn: (() -> Unit)? = null) {
    val colors = Micabo.colors
    val pop = remember { Animatable(0.6f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 180f)) }
    // **Qui a déjà un compte se connecte d'emblée**, comme sur l'iPhone et le site : le profil
    // descend avec ses leçons, et un accueil fini ailleurs ne se refait pas ici.
    StepScaffold(
        stringResource(R.string.ios_hook_next),
        onNext,
        centered = true,
        secondary = if (onSignIn != null) stringResource(R.string.common_alreadyAccount) else null,
        onSecondary = { onSignIn?.invoke() },
    ) {
        Spacer(Modifier.height(40.dp))
        Image(
            painterResource(R.mipmap.ic_launcher_foreground_art),
            contentDescription = null,
            modifier = Modifier.size(96.dp).graphicsLayer { scaleX = pop.value; scaleY = pop.value }.clip(RoundedCornerShape(26.dp)),
        )
        Spacer(Modifier.height(28.dp))
        RichText(
            stringResource(R.string.ios_hook_title),
            style = nunito(40.sp, FontWeight.Black, lineHeight = 44.sp),
            textAlign = TextAlign.Center,
            keywordColor = colors.accent,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(R.string.ios_hook_sub),
            style = nunito(18.sp, FontWeight.SemiBold, lineHeight = 25.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(32.dp))
        Mika(MikaMood.WAVE, 170.dp)
    }
}

/** **Le prénom** : Mika s'en sert ensuite. */
@Composable
fun NameStep(name: String, onName: (String) -> Unit, onNext: () -> Unit) {
    val colors = Micabo.colors
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val canContinue = name.isNotBlank()
    StepScaffold(stringResource(R.string.common_continue), onNext, enabled = canContinue) {
        Spacer(Modifier.height(12.dp))
        MikaSays(stringResource(R.string.ios_onb_name))
        Spacer(Modifier.height(28.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(colors.surface)
                .border(2.dp, if (canContinue) colors.accent else colors.stroke, RoundedCornerShape(18.dp))
                .padding(horizontal = 18.dp, vertical = 16.dp),
        ) {
            if (name.isEmpty()) Text(stringResource(R.string.ios_onb_name_placeholder), style = nunito(22.sp, FontWeight.Bold), color = colors.inkTertiary)
            BasicTextField(
                value = name,
                onValueChange = onName,
                singleLine = true,
                textStyle = nunito(22.sp, FontWeight.Bold).copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { if (canContinue) onNext() }),
                modifier = Modifier.fillMaxWidth().focusRequester(focus),
            )
        }
    }
}

/** **Bienvenue**, avec le prénom. */
@Composable
fun Welcome(name: String, onNext: () -> Unit) {
    val colors = Micabo.colors
    StepScaffold(stringResource(R.string.common_continue), onNext, centered = true) {
        Spacer(Modifier.height(40.dp))
        Mika(MikaMood.HAPPY, 190.dp)
        Spacer(Modifier.height(24.dp))
        Text(
            stringResource(R.string.ios_onb_welcome_title, name),
            style = nunito(34.sp, FontWeight.Black, lineHeight = 38.sp),
            color = colors.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(R.string.ios_onb_welcome_sub),
            style = nunito(18.sp, FontWeight.SemiBold, lineHeight = 25.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun worryEcho(worry: String): String = stringResource(
    when (worry) {
        "examStress" -> R.string.ios_onb_worry_examStress_echo
        "hardLessons" -> R.string.ios_onb_worry_hardLessons_echo
        "homework" -> R.string.ios_onb_worry_homework_echo
        "forgetting" -> R.string.ios_onb_worry_forgetting_echo
        "noStart" -> R.string.ios_onb_worry_noStart_echo
        else -> R.string.ios_onb_worry_motivation_echo
    },
)

/**
 * **« On s'en occupe »** : ce qui freine, puis la preuve — ce qui reste d'une leçon après une
 * semaine, relue (36 %) ou testée (80 %), Karpicke & Roediger.
 */
@Composable
fun Proof(worry: String?, onNext: () -> Unit) {
    val colors = Micabo.colors
    val grow = remember { Animatable(0f) }
    LaunchedEffect(Unit) { grow.animateTo(1f, tween(1100, delayMillis = 250, easing = FastOutSlowInEasing)) }
    StepScaffold(stringResource(R.string.common_continue), onNext) {
        Spacer(Modifier.height(12.dp))
        RichText(
            if (worry != null) stringResource(R.string.ios_proof_gotYou_named, worryEcho(worry)) else stringResource(R.string.ios_proof_gotYou),
            style = nunito(30.sp, FontWeight.Black, lineHeight = 34.sp),
            keywordColor = colors.accent,
        )
        Spacer(Modifier.height(10.dp))
        RichText(stringResource(R.string.ios_proof_retention_title), style = nunito(22.sp, FontWeight.ExtraBold, lineHeight = 27.sp), keywordColor = colors.wrong)
        Spacer(Modifier.height(22.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
                .padding(20.dp),
        ) {
            Text(stringResource(R.string.ios_proof_retention_caption), style = nunito(15.sp, FontWeight.Bold, lineHeight = 20.sp), color = colors.inkSecondary)
            Spacer(Modifier.height(18.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.Bottom) {
                Bar(stringResource(R.string.ios_proof_retention_reread), 36, colors.wrong, grow.value, Modifier.weight(1f))
                Bar(stringResource(R.string.ios_proof_retention_testing), 80, colors.correct, grow.value, Modifier.weight(1f))
            }
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.ios_journey_source), style = nunito(12.sp, FontWeight.SemiBold), color = colors.inkTertiary)
        }
    }
}

@Composable
private fun Bar(label: String, percent: Int, color: Color, grow: Float, modifier: Modifier) {
    val colors = Micabo.colors
    // La hauteur des barres est en dp, pas en fraction d'une ligne fixe : avec un grand texte
    // système, les étiquettes passaient sous le bas de la carte.
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text("${(percent * grow).toInt()} %", style = nunito(24.sp, FontWeight.Black), color = color)
        Spacer(Modifier.height(6.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height((124f * percent / 100f * grow + 4f).dp)
                .clip(RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp))
                .background(color),
        )
        Spacer(Modifier.height(8.dp))
        Text(label, style = nunito(14.sp, FontWeight.Bold, lineHeight = 18.sp), color = colors.ink, textAlign = TextAlign.Center, minLines = 2, maxLines = 2)
    }
}

/** **Le temps par jour** : cinq, dix, quinze ou trente minutes. */
@Composable
fun DailyTime(minutes: Int, onPick: (Int) -> Unit, onNext: () -> Unit) {
    val colors = Micabo.colors
    val options = listOf(5, 10, 15, 30)
    StepScaffold(stringResource(R.string.common_continue), onNext, enabled = minutes > 0) {
        Spacer(Modifier.height(12.dp))
        MikaSays(stringResource(R.string.ios_quiz_time))
        Spacer(Modifier.height(22.dp))
        options.forEach { option ->
            val on = option == minutes
            val border by animateColorAsState(if (on) colors.accent else colors.stroke, label = "border")
            Pressable(onClick = { onPick(option) }, modifier = Modifier.padding(bottom = 10.dp).fillMaxWidth()) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(if (on) colors.accentWash else colors.surface)
                        .border(2.dp, border, RoundedCornerShape(18.dp))
                        .padding(horizontal = 18.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon3D(if (option >= 30) "fusee" else if (option >= 15) "flamme" else if (option >= 10) "sablier" else "reveil", 34.dp)
                    Spacer(Modifier.width(12.dp))
                    Text(stringResource(R.string.ios_quiz_time_minutes, option.toString()), style = nunito(18.sp, FontWeight.ExtraBold), color = if (on) colors.accent else colors.ink, modifier = Modifier.weight(1f))
                    Text(
                        stringResource(
                            when (option) {
                                5 -> R.string.ios_quiz_time_caption_5
                                10 -> R.string.ios_quiz_time_caption_10
                                15 -> R.string.ios_quiz_time_caption_15
                                else -> R.string.ios_quiz_time_caption_30
                            },
                        ),
                        style = nunito(14.sp, FontWeight.Bold),
                        color = colors.inkSecondary,
                    )
                }
            }
        }
    }
}

/** **Mika prépare le plan** : quatre étapes qui se cochent, puis on continue tout seul. */
@Composable
fun Building(onDone: () -> Unit) {
    val colors = Micabo.colors
    var done by remember { mutableIntStateOf(0) }
    val steps = listOf(R.string.ios_build_step1, R.string.ios_build_step2, R.string.ios_build_step3, R.string.ios_build_step4)
    LaunchedEffect(Unit) {
        while (done < steps.size) {
            delay(900)
            done += 1
        }
        delay(700)
        onDone()
    }
    val transition = rememberInfiniteTransition(label = "build")
    val pulse by transition.animateFloat(0.94f, 1.06f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "pulse")
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        Box(contentAlignment = Alignment.Center) {
            Box(Modifier.size((200 * pulse).dp).clip(CircleShape).background(colors.accentWash))
            Mika(MikaMood.THINK, 150.dp)
        }
        Spacer(Modifier.height(22.dp))
        Text(
            stringResource(if (done >= steps.size) R.string.ios_build_done else R.string.ios_build_title),
            style = nunito(28.sp, FontWeight.Black),
            color = colors.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        ProgressBar(done / steps.size.toFloat(), Modifier.fillMaxWidth(0.8f))
        Spacer(Modifier.height(22.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            steps.forEachIndexed { index, label ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier.size(26.dp).clip(CircleShape).background(if (index < done) colors.correct else colors.surfaceSunken),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (index < done) Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(16.dp))
                        else if (index == done) CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(stringResource(label), style = nunito(16.sp, if (index == done) FontWeight.ExtraBold else FontWeight.SemiBold), color = if (index <= done) colors.ink else colors.inkTertiary)
                }
            }
        }
        Spacer(Modifier.weight(1.3f))
    }
}

/** **Tous tes supports** : PDF, photos, notes, YouTube, audio, cours. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MikaSources(onNext: () -> Unit) {
    val colors = Micabo.colors
    val sources = listOf(
        "pdf" to R.string.ios_onb_mika_source_pdf,
        "fiche" to R.string.ios_onb_mika_source_photo,
        "fusee" to R.string.ios_onb_mika_source_youtube,
        "texte" to R.string.ios_onb_mika_source_notes,
        "livre-ouvert" to R.string.ios_onb_mika_source_course,
    )
    StepScaffold(stringResource(R.string.common_continue), onNext) {
        Spacer(Modifier.height(12.dp))
        MikaSays(stringResource(R.string.ios_onb_mika_sources), MikaMood.HAPPY)
        Spacer(Modifier.height(28.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            sources.forEachIndexed { index, (icon, label) ->
                val appear = remember { Animatable(0f) }
                LaunchedEffect(Unit) {
                    delay(index * 90L)
                    appear.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = 260f))
                }
                Column(
                    Modifier
                        .graphicsLayer { scaleX = appear.value; scaleY = appear.value; alpha = appear.value }
                        .width(100.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                        .padding(vertical = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon3D(icon, 48.dp)
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(label), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.ink)
                }
            }
        }
    }
}

/** **… et en fait un chemin simple** : un petit chemin de cercles, comme dans une leçon. */
@Composable
fun MikaPaths(onNext: () -> Unit) {
    val colors = Micabo.colors
    val nodes = listOf(
        Triple("etoile", R.string.lesson_circle_intro, true),
        Triple("livre-ouvert", R.string.ios_onb_sample_step1, true),
        Triple("fusee", R.string.ios_onb_sample_step2, false),
        Triple("quiz", R.string.lesson_circle_checkpoint, false),
    )
    StepScaffold(stringResource(R.string.common_continue), onNext) {
        Spacer(Modifier.height(12.dp))
        MikaSays(stringResource(R.string.ios_onb_mika_paths), MikaMood.HAPPY)
        Spacer(Modifier.height(24.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(26.dp))
                .background(colors.tonePale[2])
                .padding(20.dp),
        ) {
            Text(stringResource(R.string.ios_onb_sample_title), style = nunito(22.sp, FontWeight.Black), color = colors.toneInk[2])
            Text(stringResource(R.string.ios_onb_sample_group), style = nunito(14.sp, FontWeight.Bold), color = colors.toneInk[2])
            Spacer(Modifier.height(16.dp))
            nodes.forEachIndexed { index, (icon, label, done) ->
                Row(
                    Modifier.padding(start = if (index % 2 == 0) 0.dp else 60.dp, bottom = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                            .background(if (done) colors.toneVivid[2] else colors.surface)
                            .border(3.dp, colors.toneVivid[2].copy(alpha = if (done) 1f else 0.4f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon3D(icon, 40.dp)
                    }
                    Spacer(Modifier.width(12.dp))
                    Text(stringResource(label), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink)
                }
            }
        }
    }
}

/** **Ton tuteur, dans ta poche** : une question, la réponse de Mika, toutes les matières. */
@Composable
fun MikaTutor(onNext: () -> Unit) {
    val colors = Micabo.colors
    var shown by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        delay(500); shown = 1
        delay(900); shown = 2
    }
    StepScaffold(stringResource(R.string.common_continue), onNext) {
        Spacer(Modifier.height(12.dp))
        MikaSays(stringResource(R.string.ios_onb_mika_tutor), MikaMood.WAVE)
        Spacer(Modifier.height(24.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(26.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(26.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (shown >= 1) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    Text(
                        stringResource(R.string.ios_onb_tutor_ask),
                        style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
                        color = colors.onInk,
                        modifier = Modifier.widthIn(max = 260.dp).clip(RoundedCornerShape(18.dp)).background(colors.accent).padding(12.dp),
                    )
                }
            }
            if (shown >= 2) {
                Row(verticalAlignment = Alignment.Top) {
                    Mika(MikaMood.HAPPY, 36.dp)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        stringResource(R.string.ios_onb_tutor_answer),
                        style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
                        color = colors.ink,
                        modifier = Modifier.widthIn(max = 260.dp).clip(RoundedCornerShape(18.dp)).background(colors.surfaceMuted).padding(12.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Pill("reveil", stringResource(R.string.ios_onb_tutor_anytime))
            Pill("globe", stringResource(R.string.ios_onb_tutor_subjects))
        }
    }
}

@Composable
private fun Pill(icon: String, text: String) {
    val colors = Micabo.colors
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(colors.accentWash).padding(start = 8.dp, end = 14.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon3D(icon, 24.dp)
        Spacer(Modifier.width(6.dp))
        Text(text, style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent)
    }
}

/** **Ils sont déjà nombreux** : le nombre d'élèves, et leurs avis qui défilent. */
@Composable
fun SocialProof(onNext: () -> Unit) {
    val colors = Micabo.colors
    val reviews = listOf(
        Triple(R.string.ios_onb_review1_title, R.string.ios_onb_review1_body, R.string.ios_onb_review1_author),
        Triple(R.string.ios_onb_review2_title, R.string.ios_onb_review2_body, R.string.ios_onb_review2_author),
        Triple(R.string.ios_onb_review3_title, R.string.ios_onb_review3_body, R.string.ios_onb_review3_author),
        Triple(R.string.ios_onb_review4_title, R.string.ios_onb_review4_body, R.string.ios_onb_review4_author),
        Triple(R.string.ios_onb_review5_title, R.string.ios_onb_review5_body, R.string.ios_onb_review5_author),
    )
    var current by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(3200)
            current = (current + 1) % reviews.size
        }
    }
    val students = remember { NumberFormat.getIntegerInstance().format(45_000) }
    StepScaffold(stringResource(R.string.common_continue), onNext, centered = true) {
        Spacer(Modifier.height(20.dp))
        Text(stringResource(R.string.ios_onb_social_title), style = nunito(22.sp, FontWeight.ExtraBold), color = colors.inkSecondary, textAlign = TextAlign.Center)
        Text(stringResource(R.string.ios_onb_social_count, students), style = nunito(40.sp, FontWeight.Black, lineHeight = 44.sp), color = colors.accent, textAlign = TextAlign.Center)
        // Sur iPhone, « n° 1 » et les cinq étoiles encadrent le classement de l'App Store. Google
        // Play n'en a pas encore : les afficher ici serait une note de boutique inventée.
        Spacer(Modifier.height(26.dp))
        AnimatedContent(targetState = current, transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(300)) }, label = "review") { index ->
            val (title, body, author) = reviews[index]
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
                    .padding(20.dp),
            ) {
                Row { repeat(5) { Icon(Icons.Filled.Star, null, tint = colors.caution, modifier = Modifier.size(16.dp)) } }
                Spacer(Modifier.height(8.dp))
                Text(stringResource(title), style = nunito(18.sp, FontWeight.ExtraBold), color = colors.ink)
                Spacer(Modifier.height(6.dp))
                Text(stringResource(body), style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp), color = colors.inkSecondary)
                Spacer(Modifier.height(10.dp))
                Text(stringResource(author), style = nunito(13.sp, FontWeight.Bold), color = colors.inkTertiary)
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            reviews.indices.forEach { index ->
                Box(Modifier.size(if (index == current) 9.dp else 7.dp).clip(CircleShape).background(if (index == current) colors.accent else colors.stroke))
            }
        }
    }
}

/** **L'essai gratuit** : rien à payer aujourd'hui, et le prix qui suit. */
@Composable
fun TrialOffer(onNext: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    var yearly by remember { mutableStateOf<StorePlan?>(null) }
    LaunchedEffect(Unit) { yearly = app.billing.plans().firstOrNull { it.yearly } }
    StepScaffold(stringResource(R.string.ios_trial_reminder_cta), onNext, centered = true) {
        Spacer(Modifier.height(20.dp))
        Box(contentAlignment = Alignment.Center) {
            Box(Modifier.size(190.dp).clip(CircleShape).background(colors.cautionSoft))
            Icon3D("couronne", 120.dp)
        }
        Spacer(Modifier.height(22.dp))
        RichText(
            stringResource(R.string.ios_trial_title),
            style = nunito(32.sp, FontWeight.Black, lineHeight = 36.sp),
            textAlign = TextAlign.Center,
            keywordColor = colors.accent,
        )
        Spacer(Modifier.height(18.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Check, null, tint = colors.correct, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.ios_trial_noPayment), style = nunito(17.sp, FontWeight.ExtraBold), color = colors.ink)
        }
        yearly?.let { plan ->
            val monthly = plan.monthly
            if (monthly != null && plan.trialDays > 0) {
                Spacer(Modifier.height(10.dp))
                Text(
                    stringResource(R.string.ios_trial_price, plan.price, monthly),
                    style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/**
 * **Le rappel** : aujourd'hui tout s'ouvre, la veille de la fin une notification prévient, le
 * dernier jour l'abonnement commence. La permission des notifications se demande ici.
 */
@Composable
fun TrialReminderStep(days: Int, onNext: () -> Unit) {
    val colors = Micabo.colors
    val end = remember(days) { System.currentTimeMillis() + days * 86_400_000L }
    val date = remember(end) { DateFormat.getDateInstance(DateFormat.LONG).format(Date(end)) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { onNext() }
    StepScaffold(
        stringResource(R.string.ios_trial_reminder_cta),
        onNext = {
            if (Build.VERSION.SDK_INT >= 33) permission.launch(Manifest.permission.POST_NOTIFICATIONS) else onNext()
        },
    ) {
        Spacer(Modifier.height(16.dp))
        Box(
            Modifier.size(84.dp).clip(CircleShape).background(colors.accentWash).align(Alignment.CenterHorizontally),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Notifications, null, tint = colors.accent, modifier = Modifier.size(42.dp))
        }
        Spacer(Modifier.height(18.dp))
        RichText(
            stringResource(R.string.ios_trial_reminder_title),
            style = nunito(28.sp, FontWeight.Black, lineHeight = 32.sp),
            textAlign = TextAlign.Center,
            keywordColor = colors.accent,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.ios_trial_reminder_sub, (days - 1).toString()),
            style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(24.dp))
        Timeline("couronne", stringResource(R.string.ios_trialToday), stringResource(R.string.ios_trialTodayDetail), colors.accent, last = false)
        Timeline("reveil", stringResource(R.string.ios_trialDay2), stringResource(R.string.ios_trialDay2Detail), colors.caution, last = false)
        Timeline("etoile", stringResource(R.string.ios_trialLast, days.toString()), stringResource(R.string.ios_trialLastDetail, date), colors.correct, last = true)
    }
}

@Composable
private fun Timeline(icon: String, title: String, detail: String, color: Color, last: Boolean) {
    val colors = Micabo.colors
    Row {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(46.dp).clip(CircleShape).background(color.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
                Icon3D(icon, 30.dp)
            }
            if (!last) Box(Modifier.width(3.dp).height(36.dp).background(color.copy(alpha = 0.35f)))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.padding(top = 4.dp, bottom = 12.dp)) {
            Text(title, style = nunito(17.sp, FontWeight.ExtraBold), color = colors.ink)
            Spacer(Modifier.height(2.dp))
            Text(detail, style = nunito(14.sp, FontWeight.Medium, lineHeight = 19.sp), color = colors.inkSecondary)
        }
    }
}
