package com.micabo.app.ui.settings

import android.app.Activity
import android.content.Intent
import android.net.Uri
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.micabo.app.BuildConfig
import com.micabo.app.R
import com.micabo.app.i18n.AppLocale
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.onboarding.COUNTRIES
import com.micabo.app.ui.onboarding.countryFlag
import com.micabo.app.ui.onboarding.countryName
import com.micabo.app.ui.onboarding.tierName
import com.micabo.app.data.Tiers
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

/** **Les réglages** : Pro, la langue, le pays, la marche d'études, les liens, tout effacer. */
@Composable
fun SettingsScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val colors = Micabo.colors
    val profile by app.prefs.profile.collectAsState()
    val isPro by app.billing.isPro.collectAsState()
    var picker by remember { mutableStateOf<String?>(null) }
    var confirmReset by remember { mutableStateOf(false) }
    val language = AppLocale.resolved(profile.language)

    fun open(url: String) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            BackButton(onClick = { navigator.back() })
            Spacer(Modifier.width(14.dp))
            Text(stringResource(R.string.lesson_profile_settings), style = nunito(24.sp, FontWeight.Black), color = colors.ink)
        }
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            // Pro.
            Pressable(onClick = { if (!isPro) navigator.push(Screen.Paywall("")) }) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(colors.accent, colors.tonePale[4].let { colors.toneVivid[4] })))
                        .padding(18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon3D("couronne", 54.dp)
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            if (isPro) "Micabo Pro" else stringResource(R.string.lesson_profile_goPro),
                            style = nunito(19.sp, FontWeight.Black),
                            color = androidx.compose.ui.graphics.Color.White,
                        )
                        Text(
                            stringResource(R.string.lesson_profile_goProBody),
                            style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp),
                            color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                        )
                    }
                }
            }

            Group {
                Item(stringResource(R.string.lesson_profile_language), language.label) { picker = "language" }
                Divider()
                Item(stringResource(R.string.ios_country), "${countryFlag(profile.country.ifEmpty { "other" })}  ${countryName(profile.country)}") { picker = "country" }
                Divider()
                Item(stringResource(R.string.x_settings_level), tierName(profile.tier)) { picker = "tier" }
            }

            Group {
                Item(stringResource(R.string.lesson_profile_privacy), null) { open("https://micabo.app/confidentialite") }
                Divider()
                Item(stringResource(R.string.lesson_profile_terms), null) { open("https://micabo.app/conditions") }
                Divider()
                Item(stringResource(R.string.lesson_profile_contact), null) { open("mailto:team@micabo.app") }
            }

            Group {
                Item(stringResource(R.string.x_settings_reset), null, danger = true) { confirmReset = true }
            }

            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Mika(MikaMood.IDLE, 64.dp)
                Text("Micabo ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkTertiary)
            }
        }
    }

    when (picker) {
        "language" -> Picker(
            options = AppLocale.entries.map { it.code },
            selected = language.code,
            label = { AppLocale.of(it)?.label.orEmpty() },
            onDismiss = { picker = null },
            onPick = { code ->
                picker = null
                if (code != language.code) {
                    app.prefs.update { it.copy(language = code) }
                    (context as? Activity)?.recreate()
                }
            },
        )
        "country" -> Picker(
            options = COUNTRIES,
            selected = profile.country,
            label = { "${countryFlag(it)}  ${countryName(it)}" },
            onDismiss = { picker = null },
            onPick = { code ->
                picker = null
                app.prefs.update { it.copy(country = code) }
            },
        )
        "tier" -> Picker(
            options = Tiers.all,
            selected = profile.tier,
            label = { tierName(it) },
            onDismiss = { picker = null },
            onPick = { tier ->
                picker = null
                app.prefs.update { it.copy(tier = tier) }
            },
        )
    }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            containerColor = colors.surface,
            title = { Text(stringResource(R.string.x_settings_resetTitle), style = nunito(20.sp, FontWeight.ExtraBold)) },
            text = { Text(stringResource(R.string.x_settings_resetBody), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmReset = false
                    app.lessons.deleteAll()
                    val language = app.prefs.profile.value.language
                    app.prefs.reset()
                    app.prefs.update { it.copy(language = language) }
                    navigator.home()
                }) { Text(stringResource(R.string.x_settings_reset), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmReset = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }
}

@Composable
private fun Group(content: @Composable () -> Unit) {
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
private fun Divider() = HorizontalDivider(color = Micabo.colors.hairline, modifier = Modifier.padding(start = 18.dp))

@Composable
private fun Item(title: String, value: String?, danger: Boolean = false, onClick: () -> Unit) {
    val colors = Micabo.colors
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = nunito(16.sp, FontWeight.Bold), color = if (danger) colors.wrong else colors.ink, modifier = Modifier.weight(1f))
        if (value != null) {
            Text(value, style = nunito(15.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1)
            Spacer(Modifier.width(6.dp))
        }
        if (!danger) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
    }
}

@Composable
private fun Picker(options: List<String>, selected: String, label: @Composable (String) -> String, onDismiss: () -> Unit, onPick: (String) -> Unit) {
    val colors = Micabo.colors
    Dialog(onDismissRequest = onDismiss) {
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(max = 560.dp)
                .clip(RoundedCornerShape(26.dp))
                .background(colors.surface),
        ) {
            LazyColumn(Modifier.padding(vertical = 10.dp)) {
                items(options) { option ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onPick(option) }
                            .padding(horizontal = 20.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(label(option), style = nunito(17.sp, FontWeight.Bold), color = if (option == selected) colors.accent else colors.ink, modifier = Modifier.weight(1f))
                        if (option == selected) Icon(Icons.Filled.Check, null, tint = colors.accent, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }
}
