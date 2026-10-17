package com.micabo.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.exams.ExamsScreen
import com.micabo.app.ui.home.HomeScreen
import com.micabo.app.ui.lessons.LessonsScreen
import com.micabo.app.ui.settings.ProfileScreen
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

private val Tab.icon: ImageVector
    get() = when (this) {
        Tab.HOME -> Icons.Filled.Home
        Tab.LESSONS -> Icons.AutoMirrored.Filled.List
        Tab.EXAMS -> Icons.Filled.DateRange
        Tab.PROFILE -> Icons.Filled.Person
    }

private val Tab.title: Int
    get() = when (this) {
        Tab.HOME -> R.string.lesson_tab_home
        Tab.LESSONS -> R.string.lesson_tab_lessons
        Tab.EXAMS -> R.string.lesson_tab_exams
        Tab.PROFILE -> R.string.lesson_tab_profile
    }

/** **Les onglets** (`RootTabView`) : Accueil, Leçons, Examens, Profil, et la barre qui flotte en bas. */
@Composable
fun TabsScreen(navigator: Navigator) {
    val app = LocalApp.current
    // Minuit a pu passer depuis la dernière ouverture : la série se relit.
    LaunchedEffect(Unit) { app.streak.refresh() }
    Box(Modifier.fillMaxSize()) {
        AnimatedContent(
            targetState = navigator.tab,
            transitionSpec = { fadeIn(tween(200)) togetherWith fadeOut(tween(150)) },
            label = "tab",
        ) { tab ->
            when (tab) {
                Tab.HOME -> HomeScreen()
                Tab.LESSONS -> LessonsScreen()
                Tab.EXAMS -> ExamsScreen()
                Tab.PROFILE -> ProfileScreen()
            }
        }
        TabBar(navigator.tab, onSelect = { navigator.tab = it }, modifier = Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun TabBar(selected: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Row(
        modifier
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 10.dp)
            .fillMaxWidth()
            .shadow(14.dp, RoundedCornerShape(28.dp), ambientColor = colors.ink.copy(alpha = 0.12f), spotColor = colors.ink.copy(alpha = 0.12f))
            .clip(RoundedCornerShape(28.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(28.dp))
            // Au moins 64 : avec un grand texte système, l'intitulé ne se coupe plus.
            .heightIn(min = 64.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tab.entries.forEach { tab ->
            val active = tab == selected
            val tint by animateColorAsState(if (active) colors.accent else colors.inkTertiary, label = "tint")
            Pressable(onClick = { onSelect(tab) }, modifier = Modifier.weight(1f)) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(50))
                            .background(if (active) colors.accentWash else colors.surface)
                            .padding(horizontal = 16.dp, vertical = 3.dp),
                    ) {
                        Icon(tab.icon, null, tint = tint, modifier = Modifier.size(24.dp))
                    }
                    Spacer(Modifier.height(2.dp))
                    Text(
                        stringResource(tab.title),
                        style = nunito(12.sp, if (active) FontWeight.ExtraBold else FontWeight.Bold),
                        color = tint,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}
