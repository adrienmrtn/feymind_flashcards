package com.micabo.app.ui.league

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.LeagueRow
import com.micabo.app.data.Username
import com.micabo.app.data.XpMath
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.Tab
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MikaSays
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.xp.leagueColor
import com.micabo.app.ui.xp.leagueEmoji
import com.micabo.app.ui.xp.leagueName
import com.micabo.app.ui.xp.xpInk
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Les jours qui restent à la semaine de la ligue : elle finit lundi à minuit, heure locale. */
private fun daysLeft(today: LocalDate = LocalDate.now()): Int =
    ChronoUnit.DAYS.between(today, XpMath.weekStart(today).plusDays(7)).toInt().coerceAtLeast(1)

/**
 * **La ligue de la semaine** : la ligue de l'élève d'après son XP depuis lundi, ce qui manque
 * pour la suivante, et le classement avec ses amis (`friends_league`). Sans compte, sans ami, ou
 * quand le serveur ne répond pas : sa seule ligne, et de quoi ajouter ou inviter des amis.
 */
@Composable
fun LeagueScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val status by app.xp.status.collectAsState()
    val account by app.auth.account.collectAsState()
    var rows by remember { mutableStateOf<List<LeagueRow>?>(null) }
    var loading by remember { mutableStateOf(true) }
    val inviteMessage = stringResource(R.string.kx_league_inviteMessage)

    LaunchedEffect(account?.userId) {
        app.xp.refresh()
        loading = true
        rows = app.social.league()
        loading = false
    }

    // Sa propre ligne prend l'XP d'ici, plus fraîche que celle montée au dernier passage.
    val board = remember(rows, status.week, account?.userId) {
        val fetched = rows.orEmpty().map { if (it.isMe) it.copy(xpWeek = maxOf(it.xpWeek, status.week)) else it }
        val withMe = if (fetched.any { it.isMe }) fetched else fetched + LeagueRow(account?.userId.orEmpty(), "", "", status.week, isMe = true)
        withMe.sortedByDescending { it.xpWeek }
    }
    val alone = board.size <= 1
    val league = status.league
    val next = XpMath.nextLeague(status.week)

    fun addFriends() {
        if (account != null) {
            navigator.push(Screen.Friends)
        } else {
            // Les amis demandent un compte : le Profil, où il se crée.
            navigator.home()
            navigator.tab = Tab.PROFILE
        }
    }

    fun invite() {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, inviteMessage)
        }
        runCatching { context.startActivity(Intent.createChooser(send, null)) }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            BackButton(onClick = { navigator.back() })
            Spacer(Modifier.width(12.dp))
            Text(stringResource(R.string.kx_league_title), style = nunito(22.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.weight(1f))
        }
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(26.dp))
                        .background(colors.surface)
                        .border(2.dp, leagueColor(league.id).copy(alpha = 0.55f), RoundedCornerShape(26.dp))
                        .padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon3D("trophee", 84.dp)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "${leagueEmoji(league.id)} ${stringResource(R.string.kx_league_name, leagueName(league.id))}",
                        style = nunito(26.sp, FontWeight.Black),
                        color = colors.ink,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        stringResource(R.string.kx_league_weekLine, status.week.toString()),
                        style = nunito(16.sp, FontWeight.ExtraBold),
                        color = xpInk(),
                    )
                    Spacer(Modifier.height(14.dp))
                    if (next != null) {
                        val floor = league.floor
                        ProgressBar((status.week - floor).toFloat() / (next.first.floor - floor).coerceAtLeast(1), color = leagueColor(next.first.id), height = 10.dp)
                        Spacer(Modifier.height(8.dp))
                        Text(
                            stringResource(R.string.kx_league_toNext, next.second.toString(), leagueName(next.first.id)),
                            style = nunito(15.sp, FontWeight.SemiBold, lineHeight = 20.sp),
                            color = colors.inkSecondary,
                            textAlign = TextAlign.Center,
                        )
                    } else {
                        Text(stringResource(R.string.kx_league_top), style = nunito(15.sp, FontWeight.Bold), color = colors.inkSecondary, textAlign = TextAlign.Center)
                    }
                    Spacer(Modifier.height(12.dp))
                    val days = daysLeft()
                    Text(
                        "⏳ " + pluralStringResource(R.plurals.kx_league_endsIn, days, days),
                        style = nunito(13.sp, FontWeight.ExtraBold),
                        color = colors.inkSecondary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(colors.surfaceMuted)
                            .padding(horizontal = 12.dp, vertical = 5.dp),
                    )
                }
            }
            item {
                Row(Modifier.padding(top = 10.dp, start = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.kx_league_ranking), style = nunito(18.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.weight(1f))
                    if (loading) CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                }
            }
            itemsIndexed(board, key = { index, row -> row.userId.ifEmpty { "me-$index" } }) { index, row ->
                RankRow(index + 1, row)
            }
            if (alone && !loading) {
                item {
                    Spacer(Modifier.height(6.dp))
                    MikaSays(stringResource(R.string.kx_league_alone), mood = MikaMood.WAVE)
                }
                item {
                    Spacer(Modifier.height(4.dp))
                    MicaboButton(stringResource(R.string.kx_league_addFriends), onClick = ::addFriends)
                }
                item { MicaboSecondaryButton(stringResource(R.string.kx_league_invite), onClick = ::invite) }
            } else if (!loading) {
                item {
                    Spacer(Modifier.height(6.dp))
                    MicaboSecondaryButton(stringResource(R.string.kx_league_invite), onClick = ::invite)
                }
            }
        }
        Spacer(Modifier.navigationBarsPadding())
    }
}

/** Une ligne du classement : le rang, l'initiale, le nom et l'XP ; la sienne ressort. */
@Composable
private fun RankRow(rank: Int, row: LeagueRow) {
    val colors = Micabo.colors
    val name = when {
        row.isMe -> stringResource(R.string.kx_league_you)
        row.displayName.isNotBlank() -> row.displayName
        row.username.isNotBlank() -> Username.display(row.username)
        else -> stringResource(R.string.app_friends_someone)
    }
    val initial = name.trim().removePrefix("@").firstOrNull()?.uppercaseChar()?.toString() ?: "?"
    val tint = colors.toneVivid[((row.userId.hashCode() % 5) + 5) % 5]
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(if (row.isMe) colors.accentWash else colors.surface)
            .border(if (row.isMe) 2.dp else 1.5.dp, if (row.isMe) colors.accent.copy(alpha = 0.55f) else colors.stroke, RoundedCornerShape(20.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            when (rank) {
                1 -> "🥇"
                2 -> "🥈"
                3 -> "🥉"
                else -> rank.toString()
            },
            style = nunito(17.sp, FontWeight.Black),
            color = colors.inkTertiary,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(30.dp),
        )
        Spacer(Modifier.width(8.dp))
        Box(Modifier.size(40.dp).clip(CircleShape).background(if (row.isMe) colors.accent else tint), contentAlignment = Alignment.Center) {
            Text(initial, style = nunito(18.sp, FontWeight.Black), color = Color.White)
        }
        Spacer(Modifier.width(12.dp))
        Text(
            name,
            style = nunito(16.sp, if (row.isMe) FontWeight.Black else FontWeight.Bold),
            color = if (row.isMe) colors.accent else colors.ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        Text("${row.xpWeek} XP", style = nunito(15.sp, FontWeight.ExtraBold), color = xpInk())
    }
}
