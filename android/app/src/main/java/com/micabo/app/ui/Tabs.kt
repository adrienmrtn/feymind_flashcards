package com.micabo.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.contentDescription
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
import com.micabo.app.ui.paywall.OfferTab
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
    LaunchedEffect(Unit) {
        app.streak.refresh()
        app.xp.refresh()
    }
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
        // La languette de l'offre, au bord droit, au-dessus de la barre et des boutons du bas.
        OfferTab(Modifier.align(Alignment.CenterEnd).padding(bottom = 120.dp))
    }
}

/**
 * **La barre d'onglets du lot 11** (`MicaboTabBar`) : une pilule qui flotte, sans ombre floue ;
 * l'onglet actif dit son nom dans sa pastille, les autres ne montrent que leur icône (et se
 * nomment à TalkBack). Elle se pose au-dessus de la barre du système.
 */
@Composable
private fun TabBar(selected: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Row(
        modifier
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(percent = 50))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(percent = 50))
            .heightIn(min = 60.dp)
            .padding(6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Tab.entries.forEach { tab ->
            val active = tab == selected
            val name = stringResource(tab.title)
            Pressable(
                onClick = { onSelect(tab) },
                modifier = Modifier
                    .weight(if (active) 1.8f else 1f)
                    .semantics { contentDescription = name; this.selected = active },
            ) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .clip(RoundedCornerShape(percent = 50))
                        .background(if (active) colors.accentWash else colors.surface)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(tab.icon, null, tint = if (active) colors.accentBright else colors.inkTertiary, modifier = Modifier.size(24.dp))
                    if (active) {
                        Spacer(Modifier.width(6.dp))
                        Text(name, style = com.micabo.app.ui.theme.text(14.sp, FontWeight.Bold), color = colors.ink, maxLines = 2, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                }
            }
        }
    }
}
