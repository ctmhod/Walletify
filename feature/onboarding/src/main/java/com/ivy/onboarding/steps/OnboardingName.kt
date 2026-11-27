package com.ivy.onboarding.steps

import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.ivy.design.l0_system.UI
import com.ivy.design.l0_system.style
import com.ivy.legacy.IvyWalletPreview
import com.ivy.legacy.utils.setStatusBarDarkTextCompat
import com.ivy.navigation.navigation
import com.ivy.onboarding.components.OnboardingToolbar
import com.ivy.ui.R
import com.ivy.wallet.ui.theme.GradientIvy
import com.ivy.wallet.ui.theme.White
import com.ivy.wallet.ui.theme.components.IvyTitleTextField
import com.ivy.wallet.ui.theme.components.OnboardingButton

@Composable
fun BoxWithConstraintsScope.OnboardingName(
    onContinue: (String) -> Unit,
    onSkip: () -> Unit
) {
    setStatusBarDarkTextCompat(darkText = UI.colors.isLight)

    var name by remember { mutableStateOf(TextFieldValue("")) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { focus.requestFocus() }
    }

    val nav = navigation()
    val canContinue = name.text.isNotBlank()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding()
    ) {
        Spacer(Modifier.height(16.dp))

        OnboardingToolbar(
            hasSkip = true,
            onBack = { nav.onBackPressed() },
            onSkip = onSkip
        )

        Spacer(Modifier.height(24.dp))

        Text(
            modifier = Modifier.padding(horizontal = 32.dp),
            text = stringResource(R.string.what_is_your_name),
            style = UI.typo.h2.style(
                fontWeight = FontWeight.Black
            )
        )

        Spacer(Modifier.height(32.dp))

        IvyTitleTextField(
            modifier = Modifier
                .padding(horizontal = 32.dp)
                .focusRequester(focus),
            dividerModifier = Modifier.padding(horizontal = 24.dp),
            value = name,
            hint = stringResource(R.string.your_name_hint),
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Words,
                imeAction = ImeAction.Done
            )
        ) {
            name = it
        }

        Spacer(Modifier.weight(1f))

        OnboardingButton(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .align(Alignment.CenterHorizontally),
            text = stringResource(R.string.next),
            textColor = White,
            backgroundGradient = GradientIvy,
            hasNext = true,
            enabled = canContinue
        ) {
            onContinue(name.text.trim())
        }

        Spacer(Modifier.height(20.dp))
    }
}

@Preview
@Composable
private fun Preview() {
    IvyWalletPreview {
        OnboardingName(onContinue = {}, onSkip = {})
    }
}
