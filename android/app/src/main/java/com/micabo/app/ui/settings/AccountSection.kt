package com.micabo.app.ui.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Patterns
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.SignInEvent
import com.micabo.app.data.Account
import com.micabo.app.data.AuthException
import com.micabo.app.data.NetworkException
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.home.Sheet
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * **Le compte, dans le profil** (`AccountSection` sur iPhone) : sans compte, une carte pour en
 * créer un (Google ou un lien par courriel) ; connecté, l'adresse, la sauvegarde, se
 * déconnecter et supprimer le compte. Les leçons suivent l'élève sur ses autres appareils.
 */
@Composable
fun AccountSection() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val scope = rememberCoroutineScope()
    val account by app.auth.account.collectAsState()
    val sync by app.sync.state.collectAsState()
    val event by app.signIn.collectAsState()
    var sheet by rememberSaveable { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<Throwable?>(null) }

    // Le retour de Google ou du lien : réussi, la feuille se ferme ; raté, elle dit pourquoi.
    LaunchedEffect(event) {
        when (event) {
            SignInEvent.Success -> {
                sheet = false
                app.signInSeen()
            }
            is SignInEvent.Failure -> sheet = true
            null -> Unit
        }
    }

    val friends by app.social.friends.collectAsState()
    val incoming by app.social.incoming.collectAsState()
    LaunchedEffect(account?.userId) { if (account != null) app.social.refresh() }

    val current = account
    if (current == null) {
        Group {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { sheet = true }
                    .padding(horizontal = 18.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(null)
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.ios_createOrSignIn), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink)
                    Text(stringResource(R.string.ios_createOrSignInHelp), style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp), color = colors.inkSecondary)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
            }
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Group {
                Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Avatar(current)
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            current.name.ifBlank { current.email.ifBlank { stringResource(R.string.ios_account) } },
                            style = nunito(16.sp, FontWeight.ExtraBold),
                            color = colors.ink,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (current.name.isNotBlank() && current.email.isNotBlank()) {
                            Text(current.email, style = nunito(14.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                    Text(
                        stringResource(R.string.ios_connected),
                        style = nunito(12.sp, FontWeight.ExtraBold),
                        color = colors.correct,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(colors.correct.copy(alpha = 0.14f)).padding(horizontal = 10.dp, vertical = 4.dp),
                    )
                }
                Divider()
                // La sauvegarde : toucher relance une synchronisation tout de suite.
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 56.dp)
                        .clickable(enabled = !sync.running) { scope.launch { app.sync.sync() } }
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.ios_backup), style = nunito(16.sp, FontWeight.Bold), color = colors.ink)
                        Text(
                            stringResource(
                                when {
                                    sync.running -> R.string.ios_syncing
                                    sync.failed -> R.string.x_sync_failed
                                    else -> R.string.ios_tapToSync
                                },
                            ),
                            style = nunito(13.sp, FontWeight.SemiBold),
                            color = if (sync.failed && !sync.running) colors.wrongInk else colors.inkSecondary,
                        )
                    }
                    if (sync.running) {
                        CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                    } else {
                        Icon(Icons.Filled.Refresh, null, tint = colors.inkTertiary, modifier = Modifier.size(22.dp))
                    }
                }
                Divider()
                Item(stringResource(R.string.common_signOut), null) { confirmSignOut = true }
                Divider()
                Item(stringResource(R.string.ios_deleteAccount), null, danger = true) { confirmDelete = true }
            }
            failure?.let {
                Text(authMessage(it), style = nunito(13.sp, FontWeight.SemiBold), color = colors.wrongInk, modifier = Modifier.padding(horizontal = 6.dp))
            }
            Text(stringResource(R.string.ios_dataFootnote), style = nunito(13.sp, FontWeight.SemiBold, lineHeight = 18.sp), color = colors.inkTertiary, modifier = Modifier.padding(horizontal = 6.dp))
        }
    }

    // Les amis : un compte d'abord, pour qu'ils puissent nous retrouver.
    Group {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .clickable { if (current == null) sheet = true else navigator.push(Screen.Friends) }
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.nav_friends), style = nunito(16.sp, FontWeight.Bold), color = colors.ink)
                Text(
                    when {
                        current == null -> stringResource(R.string.app_friends_needAccount)
                        friends.isNotEmpty() -> pluralStringResource(R.plurals.app_friends_friendCount, friends.size, friends.size)
                        else -> stringResource(R.string.app_friends_findClassmates)
                    },
                    style = nunito(13.sp, FontWeight.SemiBold),
                    color = colors.inkSecondary,
                )
            }
            if (current != null && incoming.isNotEmpty()) {
                Text(
                    incoming.size.toString(),
                    style = nunito(13.sp, FontWeight.Black),
                    color = Color.White,
                    modifier = Modifier.clip(CircleShape).background(colors.wrong).padding(horizontal = 8.dp, vertical = 2.dp),
                )
                Spacer(Modifier.width(6.dp))
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
        }
    }

    if (sheet) {
        SignInSheet(
            failure = (event as? SignInEvent.Failure)?.error,
            onDismiss = {
                sheet = false
                app.signInSeen()
            },
        )
    }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            containerColor = colors.surface,
            title = { Text(stringResource(R.string.ios_signOutQ), style = nunito(20.sp, FontWeight.ExtraBold)) },
            text = { Text(stringResource(R.string.ios_signOutMsg), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmSignOut = false
                    failure = null
                    // Hors de l'écran : quitter le profil ne coupe pas la déconnexion en route.
                    scope.launch { withContext(NonCancellable) { app.signOut() } }
                }) { Text(stringResource(R.string.common_signOut), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmSignOut = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { if (!busy) confirmDelete = false },
            containerColor = colors.surface,
            title = { Text(stringResource(R.string.ios_deleteAccountQ), style = nunito(20.sp, FontWeight.ExtraBold)) },
            text = { Text(stringResource(R.string.x_account_deleteMsg), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    busy = true
                    failure = null
                    scope.launch {
                        val outcome = withContext(NonCancellable) { runCatching { app.deleteAccount() } }
                        busy = false
                        confirmDelete = false
                        failure = outcome.exceptionOrNull()
                    }
                }) {
                    if (busy) {
                        CircularProgressIndicator(color = colors.wrong, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    } else {
                        Text(stringResource(R.string.ios_deleteAccount), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold))
                    }
                }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { confirmDelete = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }
}

/** La pastille du compte : l'initiale, ou une silhouette sans compte. */
@Composable
private fun Avatar(account: Account?) {
    val colors = Micabo.colors
    val initial = account?.let { (it.name.ifBlank { it.email }).trim().firstOrNull()?.uppercaseChar() }
    Box(
        Modifier.size(46.dp).clip(CircleShape).background(if (account == null) colors.surfaceSunken else colors.accent),
        contentAlignment = Alignment.Center,
    ) {
        if (initial != null) {
            Text(initial.toString(), style = nunito(20.sp, FontWeight.Black), color = Color.White)
        } else {
            Icon(Icons.Filled.Person, null, tint = if (account == null) colors.inkSecondary else Color.White, modifier = Modifier.size(26.dp))
        }
    }
}

/** La phrase d'un échec de connexion, comme sur iPhone (`AuthError.localizedDescription`). */
@Composable
private fun authMessage(error: Throwable): String = when {
    error is AuthException && error.code == "providerNotEnabled" -> stringResource(R.string.ios_auth_providerNotEnabled, "Google / Apple")
    error is AuthException && error.code == "emailNotConfirmed" -> stringResource(R.string.ios_auth_emailNotConfirmed)
    error is AuthException && error.code == "rateLimited" -> stringResource(R.string.x_auth_rateLimited)
    error is AuthException && (error.code == "otp_expired" || error.code == "flow_state_expired" || error.code == "flow_state_not_found") ->
        stringResource(R.string.ios_auth_sessionExpired)
    error is NetworkException -> stringResource(R.string.x_error_network)
    else -> stringResource(R.string.ios_auth_invalidResponse)
}

/** Ouvre la page de Google dans un onglet de l'app ; sans navigateur compatible, dans le navigateur. */
private fun openAuthPage(context: Context, url: String) {
    val uri = Uri.parse(url)
    runCatching { CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, uri) }
        .recoverCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

/**
 * **Créer un compte ou se connecter** (`AuthSheet`) : Google, Apple, ou un lien par courriel,
 * sans mot de passe. Le retour arrive par `micabo://auth-callback`, que l'activité passe à
 * l'app. Ouverte aussi depuis l'accroche du parcours d'accueil, pour qui a déjà un compte.
 */
@Composable
internal fun SignInSheet(failure: Throwable?, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var email by rememberSaveable { mutableStateOf("") }
    var sentTo by rememberSaveable { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<Throwable?>(null) }
    val shown = error ?: failure
    val valid = Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches()

    fun send() {
        if (!valid || sending) return
        sending = true
        error = null
        scope.launch {
            runCatching { app.auth.sendMagicLink(email.trim()) }
                .onSuccess { sentTo = email.trim() }
                .onFailure { error = it }
            sending = false
        }
    }

    Sheet(onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Mika(MikaMood.HAPPY, 52.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.onboarding_compteTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
                Text(stringResource(R.string.ios_account_sub), style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp), color = colors.inkSecondary)
            }
        }
        Spacer(Modifier.height(18.dp))
        val target = sentTo
        if (target != null) {
            // Le lien est parti : il rouvre l'app, et la connexion se termine toute seule.
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(colors.surface).border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp)).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Email, null, tint = colors.accent, modifier = Modifier.size(26.dp))
                Spacer(Modifier.width(12.dp))
                Text(stringResource(R.string.onboarding_linkSent, target), style = nunito(16.sp, FontWeight.Bold, lineHeight = 21.sp), color = colors.ink)
            }
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.onboarding_emailNote), style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkTertiary)
            Spacer(Modifier.height(14.dp))
            MicaboSecondaryButton(stringResource(R.string.onboarding_sendLink), onClick = {
                sentTo = null
                send()
            })
        } else {
            MicaboButton(
                stringResource(R.string.onboarding_continueGoogle),
                onClick = {
                    error = null
                    app.signInSeen()
                    openAuthPage(context, app.auth.googleUrl())
                },
            )
            Spacer(Modifier.height(10.dp))
            // Le même chemin que Google (PKCE, `micabo://auth-callback`) : c'est par lui qu'un
            // compte ouvert avec Apple sur l'iPhone retrouve ses leçons ici.
            MicaboButton(
                stringResource(R.string.onboarding_continueApple),
                color = colors.ink,
                contentColor = colors.canvas,
                onClick = {
                    error = null
                    app.signInSeen()
                    openAuthPage(context, app.auth.appleUrl())
                },
            )
            Spacer(Modifier.height(18.dp))
            Text(stringResource(R.string.onboarding_emailLabel), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
            Spacer(Modifier.height(6.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(colors.surface)
                    .border(1.5.dp, if (valid) colors.accent.copy(alpha = 0.5f) else colors.stroke, RoundedCornerShape(18.dp))
                    .padding(horizontal = 16.dp, vertical = 16.dp),
            ) {
                if (email.isEmpty()) {
                    Text(stringResource(R.string.onboarding_emailPlaceholder), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                }
                BasicTextField(
                    value = email,
                    onValueChange = { email = it.take(254).replace("\n", "") },
                    singleLine = true,
                    textStyle = nunito(16.sp, FontWeight.SemiBold).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Send, autoCorrectEnabled = false),
                    keyboardActions = KeyboardActions(onSend = { send() }),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(stringResource(R.string.onboarding_emailNote), style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkTertiary)
            Spacer(Modifier.height(14.dp))
            MicaboSecondaryButton(stringResource(R.string.onboarding_sendLink), onClick = ::send)
        }
        if (shown != null) {
            Spacer(Modifier.height(10.dp))
            Text(authMessage(shown), style = nunito(14.sp, FontWeight.SemiBold), color = colors.wrongInk)
        }
        if (sending) {
            Spacer(Modifier.height(10.dp))
            CircularProgressIndicator(color = colors.accent, strokeWidth = 2.5.dp, modifier = Modifier.size(22.dp).align(Alignment.CenterHorizontally))
        }
        TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
        }
    }
}
