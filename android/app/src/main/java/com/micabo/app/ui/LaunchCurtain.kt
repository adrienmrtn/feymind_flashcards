package com.micabo.app.ui

import android.content.Context
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.edit
import com.micabo.app.R
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.drawMika
import com.micabo.app.ui.theme.display
import kotlinx.coroutines.delay

/**
 * **L'écran de lancement animé** (`LaunchCurtain`) : la première image reprend celle du système
 * (le marine, Mika au centre) ; puis Mika passe en fondu à son clin d'œil, sans sauter ni
 * rebondir, et « Micabo » monte sous lui. Six dixièmes de seconde ; **à la toute première
 * ouverture, environ 2,6 s** (le geste en 1,2 s, puis Mika reste 1,4 s), comme sur l'iPhone.
 */
object LaunchCurtain {
    /** Vrai une fois le rideau levé pendant ce lancement : changer de langue ne le rejoue pas. */
    var lifted = false
    private const val FIRST_OPEN = "launch.firstOpenPlayed"
    const val FIRST_GESTURE_MS = 1_200
    const val FIRST_HOLD_MS = 1_400L
    const val GESTURE_MS = 600

    fun isFirstOpen(context: Context): Boolean =
        !context.getSharedPreferences("micabo", Context.MODE_PRIVATE).getBoolean(FIRST_OPEN, false)

    fun markPlayed(context: Context) =
        context.getSharedPreferences("micabo", Context.MODE_PRIVATE).edit { putBoolean(FIRST_OPEN, true) }
}

@Composable
fun LaunchCurtainView(onFinished: () -> Unit) {
    val context = LocalContext.current
    val first = remember { LaunchCurtain.isFirstOpen(context) }
    val played = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        LaunchCurtain.markPlayed(context)
        played.animateTo(1f, tween(if (first) LaunchCurtain.FIRST_GESTURE_MS else LaunchCurtain.GESTURE_MS, easing = LinearEasing))
        if (first) delay(LaunchCurtain.FIRST_HOLD_MS)
        LaunchCurtain.lifted = true
        onFinished()
    }
    val progress = played.value
    Box(Modifier.fillMaxSize().background(Color(0xFF0B0F1C)).clearAndSetSemantics { }, contentAlignment = Alignment.Center) {
        Box(Modifier.size(200.dp).graphicsLayer { scaleX = 1f + 0.04f * progress; scaleY = 1f + 0.04f * progress }) {
            Image(painterResource(R.drawable.launch_mika), contentDescription = null, modifier = Modifier.size(200.dp).graphicsLayer { alpha = 1f - progress })
            Canvas(Modifier.size(200.dp).graphicsLayer { alpha = progress }) { drawMika(MikaMood.WINK, night = true) }
        }
        Text(
            "Micabo",
            style = display(40.sp),
            color = Color.White,
            modifier = Modifier.offset(y = (148 - 16 * progress).dp).graphicsLayer { alpha = progress },
        )
    }
}
