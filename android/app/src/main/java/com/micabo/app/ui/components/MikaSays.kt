package com.micabo.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

/**
 * **Mika qui parle** : la mascotte, et sa phrase dans une bulle dont la pointe est tournée vers
 * elle. Le côté suit le sens de lecture (à droite de Mika en français, à gauche en arabe).
 */
@Composable
fun MikaSays(text: String, modifier: Modifier = Modifier, mood: MikaMood = MikaMood.HAPPY, size: Dp = 64.dp) {
    val colors = Micabo.colors
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Mika(mood, size)
        Spacer(Modifier.width(8.dp))
        Box(
            Modifier
                .weight(1f)
                .clip(RoundedCornerShape(topStart = 6.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 20.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(topStart = 6.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 20.dp))
                .padding(horizontal = 14.dp, vertical = 11.dp),
        ) {
            Text(text, style = nunito(15.sp, FontWeight.SemiBold, lineHeight = 21.sp), color = colors.ink)
        }
    }
}
