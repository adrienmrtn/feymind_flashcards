package com.micabo.app.ui.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Person
import com.micabo.app.data.Relation
import com.micabo.app.data.SharedCard
import com.micabo.app.data.SharedCourse
import com.micabo.app.data.SocialProblem
import com.micabo.app.data.Username
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** La phrase d'un échec, comme sur iPhone. */
@Composable
internal fun problemText(problem: SocialProblem): String = when (problem) {
    SocialProblem.Network -> stringResource(R.string.x_error_network)
    SocialProblem.RequestExists -> stringResource(R.string.ios_friends_requestExists)
    is SocialProblem.UsernameTaken -> stringResource(R.string.ios_username_taken, problem.name)
    is SocialProblem.UsernameInvalid -> stringResource(
        when (problem.problem) {
            Username.Problem.EMPTY -> R.string.ios_username_empty
            Username.Problem.TOO_SHORT -> R.string.ios_username_tooShort
            Username.Problem.TOO_LONG -> R.string.ios_username_tooLong
        },
    )
    SocialProblem.Other -> stringResource(R.string.x_error_generic)
}

@Composable
private fun Header(title: String, eyebrow: String?) {
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        BackButton(onClick = { navigator.back() })
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            if (!eyebrow.isNullOrBlank()) {
                Text(eyebrow, style = nunito(13.sp, FontWeight.ExtraBold), color = colors.inkTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(title, style = nunito(24.sp, FontWeight.Black), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun Caption(text: String) {
    Text(text.uppercase(), style = nunito(12.sp, FontWeight.ExtraBold), color = Micabo.colors.inkTertiary, modifier = Modifier.padding(start = 6.dp, bottom = 2.dp))
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    val colors = Micabo.colors
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp)),
    ) { content() }
}

@Composable
private fun Hairline() = androidx.compose.material3.HorizontalDivider(color = Micabo.colors.hairline, modifier = Modifier.padding(start = 16.dp))

/** Un champ d'une ligne, au style de l'app. */
@Composable
private fun Field(value: String, placeholder: String, onChange: (String) -> Unit, prefix: String? = null, onDone: () -> Unit = {}, trailing: @Composable () -> Unit = {}) {
    val colors = Micabo.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp))
            .padding(start = 14.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (prefix != null) {
            Text(prefix, style = nunito(16.sp, FontWeight.Bold), color = colors.inkTertiary)
            Spacer(Modifier.width(6.dp))
        }
        Box(Modifier.weight(1f).padding(vertical = 10.dp)) {
            if (value.isEmpty()) Text(placeholder, style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
            BasicTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                textStyle = nunito(16.sp, FontWeight.SemiBold).copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done, autoCorrectEnabled = false),
                keyboardActions = KeyboardActions(onDone = { onDone() }),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        trailing()
    }
}

/**
 * **Les amis** (`FriendsView`) : son nom d'utilisateur, les demandes reçues d'abord, de quoi
 * chercher quelqu'un, la liste, puis les demandes envoyées. L'ordre est celui de l'urgence.
 */
@Composable
fun FriendsScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val social = app.social
    val scope = rememberCoroutineScope()
    val username by social.username.collectAsState()
    val friends by social.friends.collectAsState()
    val incoming by social.incoming.collectAsState()
    val outgoing by social.outgoing.collectAsState()
    val loading by social.loading.collectAsState()
    val problem by social.problem.collectAsState()
    val ranking by social.ranking.collectAsState()
    var search by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Person>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        social.clearProblem()
        social.refresh()
    }
    // La recherche part après un tiers de seconde sans frappe : une requête par lettre arriverait dans le désordre.
    LaunchedEffect(search) {
        val needle = search.trim()
        if (needle.length < 2) {
            results = emptyList()
            searching = false
            return@LaunchedEffect
        }
        searching = true
        delay(320)
        results = social.search(needle)
        searching = false
    }

    // Les rangées relisent leur relation à l'affichage : après une demande, « Ajouter » devient « Annuler ».
    @Composable
    fun section(caption: String, people: List<Person>) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Caption(caption)
            Card {
                people.forEachIndexed { index, person ->
                    PersonRow(
                        person = person,
                        relation = social.relation(person.id),
                        busy = loading,
                        onOpen = { navigator.push(Screen.FriendProfile(person)) },
                        onAdd = { scope.launch { social.request(person) } },
                        onAccept = { scope.launch { social.accept(person) } },
                        onRemove = { scope.launch { social.remove(person) } },
                    )
                    if (index < people.lastIndex) Hairline()
                }
            }
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().imePadding()) {
        Header(stringResource(R.string.nav_friends), username?.let(Username::display) ?: stringResource(R.string.app_friends_yourAccount))
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            // Le nom d'utilisateur : c'est par lui qu'on se retrouve, sans échanger d'adresse.
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Caption(stringResource(R.string.ios_usernameLabel))
                val typed = name ?: username.orEmpty()
                val preview = Username.normalize(typed)
                val changed = typed.isNotBlank() && preview != username.orEmpty()
                fun save() {
                    scope.launch { if (social.setUsername(typed)) name = null }
                }
                Field(
                    value = typed,
                    placeholder = stringResource(R.string.ios_usernamePlaceholder),
                    onChange = { name = it.take(40) },
                    prefix = "@",
                    onDone = { if (changed) save() },
                ) {
                    if (changed) {
                        TextButton(onClick = { save() }, enabled = !loading) {
                            Text(stringResource(R.string.app_common_save), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.accent)
                        }
                    }
                }
                if (changed) {
                    Text(
                        if (preview.length < Username.MIN) stringResource(R.string.ios_usernameRules) else stringResource(R.string.ios_usernameSavedAs, Username.display(preview)),
                        style = nunito(13.sp, FontWeight.SemiBold),
                        color = colors.inkTertiary,
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }
            }

            problem?.let { Text(problemText(it), style = nunito(14.sp, FontWeight.SemiBold), color = colors.wrongInk) }

            // Le classement de la semaine : seulement avec un cercle, un podium seul n'en est pas un.
            if (ranking.size >= 2) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Caption(stringResource(R.string.ios_weekRanking))
                    Card {
                        ranking.forEachIndexed { index, row ->
                            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text("${index + 1}", style = nunito(15.sp, FontWeight.Black), color = colors.inkTertiary, modifier = Modifier.width(26.dp))
                                Text(
                                    when {
                                        row.isMe -> stringResource(R.string.ios_youLower)
                                        row.username.isNotBlank() -> Username.display(row.username)
                                        else -> stringResource(R.string.app_friends_someone)
                                    },
                                    style = nunito(16.sp, if (row.isMe) FontWeight.Black else FontWeight.Bold),
                                    color = if (row.isMe) colors.accent else colors.ink,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.weight(1f),
                                )
                                Text(pluralStringResource(R.plurals.copy_cards, row.passes, row.passes), style = nunito(14.sp, FontWeight.Bold), color = colors.inkSecondary)
                            }
                            if (index < ranking.lastIndex) Hairline()
                        }
                    }
                    Text(stringResource(R.string.ios_weekRankingHint), style = nunito(12.sp, FontWeight.SemiBold), color = colors.inkTertiary, modifier = Modifier.padding(start = 6.dp))
                }
            }

            if (incoming.isNotEmpty()) section(stringResource(R.string.app_friends_incoming), incoming)

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Caption(stringResource(R.string.app_friends_addSomeone))
                Field(
                    value = search,
                    placeholder = stringResource(R.string.app_friends_usernamePlaceholder),
                    onChange = { search = it.take(40) },
                    prefix = "@",
                ) {
                    if (searching) CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.padding(end = 8.dp).size(18.dp))
                }
            }

            if (results.isNotEmpty()) section(stringResource(R.string.app_friends_results), results)

            if (friends.isNotEmpty()) {
                section(stringResource(R.string.app_friends_list), friends)
            } else if (search.isBlank() && results.isEmpty() && !loading) {
                Column(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Mika(MikaMood.IDLE, 84.dp)
                    Spacer(Modifier.size(8.dp))
                    Text(stringResource(R.string.app_friends_emptyTitle), style = nunito(18.sp, FontWeight.ExtraBold), color = colors.ink)
                    Text(stringResource(R.string.app_friends_emptyBody), style = nunito(15.sp, FontWeight.SemiBold), color = colors.inkSecondary)
                }
            }

            if (outgoing.isNotEmpty()) section(stringResource(R.string.app_friends_outgoing), outgoing)
        }
    }
}

/** Une rangée d'annuaire : le nom, l'école, et l'action qui correspond à la relation. */
@Composable
private fun PersonRow(
    person: Person,
    relation: Relation,
    busy: Boolean,
    onOpen: () -> Unit,
    onAdd: () -> Unit,
    onAccept: () -> Unit,
    onRemove: () -> Unit,
) {
    val colors = Micabo.colors
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = relation == Relation.FRIENDS, onClick = onOpen)
            .padding(start = 16.dp, end = 10.dp, top = 11.dp, bottom = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(38.dp).clip(RoundedCornerShape(50)).background(colors.accentPale), contentAlignment = Alignment.Center) {
            Text(person.username.firstOrNull()?.uppercaseChar()?.toString().orEmpty(), style = nunito(16.sp, FontWeight.Black), color = colors.accent)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(person.handle, style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (person.institution.isNotBlank()) {
                Text(person.institution, style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        when (relation) {
            Relation.UNKNOWN -> Compact(stringResource(R.string.app_common_add), prominent = true, enabled = !busy, onClick = onAdd)
            Relation.AWAITING_ME -> Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Compact(stringResource(R.string.app_friends_accept), prominent = true, enabled = !busy, onClick = onAccept)
                Compact(stringResource(R.string.app_friends_decline), prominent = false, enabled = !busy, onClick = onRemove)
            }
            Relation.REQUESTED -> Compact(stringResource(R.string.app_common_cancel), prominent = false, enabled = !busy, onClick = onRemove)
            Relation.FRIENDS -> Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, stringResource(R.string.app_friends_removeFriend), tint = colors.inkTertiary) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.app_friends_seeCourses)) }, onClick = {
                        menu = false
                        onOpen()
                    })
                    DropdownMenuItem(text = { Text(stringResource(R.string.app_friends_removeFriend), color = colors.wrong) }, onClick = {
                        menu = false
                        onRemove()
                    })
                }
            }
            Relation.ME -> Text(stringResource(R.string.app_friends_you), style = nunito(13.sp, FontWeight.Bold), color = colors.inkTertiary, modifier = Modifier.padding(end = 6.dp))
        }
    }
}

@Composable
private fun Compact(title: String, prominent: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val colors = Micabo.colors
    Text(
        title,
        style = nunito(13.sp, FontWeight.ExtraBold),
        color = if (prominent) Color.White else colors.inkSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (prominent) colors.accent else colors.surfaceSunken)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
    )
}

/**
 * **Le profil d'un ami** (`FriendProfileView`) : son école et ses cours partagés, rien d'autre.
 * Ce qui s'affiche, c'est la base qui le décide.
 */
@Composable
fun FriendProfileScreen(person: Person) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    var courses by remember { mutableStateOf<List<SharedCourse>?>(null) }
    var counts by remember { mutableStateOf<Map<String, Int>>(emptyMap()) }

    LaunchedEffect(person.id) {
        val found = app.social.courses(person)
        courses = found
        counts = app.social.cardCounts(found.map { it.id })
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Header(person.handle, person.institution.ifBlank { stringResource(R.string.ios_friend) })
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val list = courses
            when {
                list == null -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(stringResource(R.string.app_friends_loadingCourses), style = nunito(14.sp, FontWeight.SemiBold), color = colors.inkTertiary)
                }
                list.isEmpty() -> Card {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.app_friends_nothingToSee), style = nunito(18.sp, FontWeight.ExtraBold), color = colors.ink)
                        Text(stringResource(R.string.app_friends_noShared, person.handle), style = nunito(15.sp, FontWeight.SemiBold), color = colors.inkSecondary)
                    }
                }
                else -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Caption(stringResource(R.string.app_friends_theirCourses))
                    Card {
                        list.forEachIndexed { index, course ->
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable { navigator.push(Screen.SharedCourse(course, person)) }
                                    .padding(horizontal = 16.dp, vertical = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(course.title, style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                    val count = counts[course.id] ?: 0
                                    val parts = listOfNotNull(
                                        course.subject.takeIf { it.isNotBlank() },
                                        if (count > 0) pluralStringResource(R.plurals.copy_cards, count, count) else null,
                                    )
                                    Text(
                                        parts.joinToString(" · ").ifEmpty { stringResource(R.string.ios_sharedCourse) },
                                        style = nunito(13.sp, FontWeight.SemiBold),
                                        color = colors.inkTertiary,
                                    )
                                }
                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
                            }
                            if (index < list.lastIndex) Hairline()
                        }
                    }
                }
            }
        }
    }
}

/**
 * **Le cours d'un ami** (`SharedCourseView`) : son résumé et ses cartes, en lecture, et un
 * bouton pour en faire sa propre leçon. Le texte du cours part dans la barre de l'accueil,
 * où Mika écrit la leçon comme pour n'importe quel texte.
 */
@Composable
fun SharedCourseScreen(course: SharedCourse, author: Person) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    var cards by remember { mutableStateOf<List<SharedCard>>(emptyList()) }

    LaunchedEffect(course.id) {
        cards = app.social.cards(course.id)
        app.social.recordView(course.id)
    }

    val source = remember(course, cards) {
        listOf(course.rawText, course.contextText, course.summary).firstOrNull { it.trim().length >= 40 }
            ?: cards.joinToString("\n") { "${it.front} — ${it.back}" }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Header(course.title, listOfNotNull(author.handle, course.subject.takeIf { it.isNotBlank() }).joinToString(" · "))
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val summary = course.summary.ifBlank { course.rawText.take(600) }
            if (summary.isNotBlank()) {
                Text(summary.trim(), style = nunito(16.sp, FontWeight.Medium, lineHeight = 23.sp), color = colors.ink)
            } else {
                Card { Text(stringResource(R.string.ios_sharedNoSheet), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink, modifier = Modifier.padding(18.dp)) }
            }
            if (cards.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Caption(stringResource(R.string.ios_cardsSection, cards.size.toString()))
                    Card {
                        cards.forEachIndexed { index, card ->
                            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(card.front, style = nunito(15.sp, FontWeight.Bold), color = colors.ink)
                                Text(card.back, style = nunito(14.sp, FontWeight.Medium), color = colors.inkSecondary)
                            }
                            if (index < cards.lastIndex) Hairline()
                        }
                    }
                }
            }
        }
        Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
            MicaboButton(
                stringResource(R.string.x_friends_adopt),
                enabled = source.trim().length >= 40,
                onClick = {
                    app.composer.reset()
                    app.composer.addShared(course.title, source)
                    app.social.recordAdopt(course.id)
                    app.analytics.track("shared_course_adopted", emptyMap())
                    navigator.home()
                },
            )
        }
    }
}
