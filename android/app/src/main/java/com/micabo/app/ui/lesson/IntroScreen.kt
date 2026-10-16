package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.delay

/** **L'intro** : ce que tu vas apprendre, le temps estimé, et c'est parti. */
@Composable
fun IntroScreen(id: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]
    if (lesson == null) {
        LeaveWhenMissing()
        return
    }
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    var shown by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        for (step in 1..(lesson.intro.lines.size + 1)) {
            delay(220)
            shown = step
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) { CloseButton(onClick = { navigator.back() }) }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(contentAlignment = Alignment.Center) {
                Box(Modifier.size(170.dp).clip(CircleShape).background(tone.pale))
                Icon3D(lesson.icon, 110.dp)
            }
            Spacer(Modifier.height(18.dp))
            Text(stringResource(R.string.lesson_intro_title), style = nunito(28.sp, FontWeight.Black), color = colors.ink)
            Spacer(Modifier.height(20.dp))
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                lesson.intro.lines.forEachIndexed { index, line ->
                    AnimatedVisibility(visible = shown > index, enter = fadeIn(tween(300)) + slideInVertically(tween(300)) { it / 2 }) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(18.dp))
                                .background(colors.surface)
                                .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp))
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(Modifier.size(30.dp).clip(CircleShape).background(tone.vivid), contentAlignment = Alignment.Center) {
                                Text("${index + 1}", style = nunito(15.sp, FontWeight.Black), color = androidx.compose.ui.graphics.Color.White)
                            }
                            Spacer(Modifier.width(12.dp))
                            RichText(line, style = nunito(17.sp, FontWeight.Bold, lineHeight = 23.sp))
                        }
                    }
                }
            }
            if (lesson.intro.minutes > 0) {
                Spacer(Modifier.height(18.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Mika(MikaMood.IDLE, 48.dp)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        stringResource(R.string.lesson_intro_estimate, lesson.intro.minutes.toString()),
                        style = nunito(15.sp, FontWeight.Bold),
                        color = colors.inkSecondary,
                    )
                }
            }
            Spacer(Modifier.height(24.dp))
        }
        Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
            MicaboButton(stringResource(R.string.lesson_intro_go), onClick = {
                app.lessons.complete(id, "intro")
                if (lesson.themes.isNotEmpty()) navigator.replace(Screen.Notes(id, 0)) else navigator.back()
            })
        }
    }
}
