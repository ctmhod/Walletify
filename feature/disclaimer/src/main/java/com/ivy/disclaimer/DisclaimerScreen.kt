package com.ivy.disclaimer

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.ivy.disclaimer.CheckboxViewState
import com.ivy.disclaimer.composables.AcceptTermsText
import com.ivy.disclaimer.composables.AgreeButton
import com.ivy.disclaimer.composables.AgreementTerm
import com.ivy.disclaimer.composables.DisclaimerTopAppBar
import com.ivy.navigation.screenScopedViewModel

@Composable
fun DisclaimerScreenImpl() {
    val viewModel: DisclaimerViewModel = screenScopedViewModel()
    val viewState = viewModel.uiState()
    DisclaimerScreenUi(viewState = viewState, onEvent = viewModel::onEvent)
}

@Composable
fun DisclaimerScreenUi(
    viewState: DisclaimerViewState,
    onEvent: (DisclaimerViewEvent) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = {
            DisclaimerTopAppBar()
        },
        content = { innerPadding ->
            Content(
                modifier = Modifier.padding(innerPadding),
                viewState = viewState,
                onEvent = onEvent,
            )
        }
    )
}

@Composable
private fun Content(
    viewState: DisclaimerViewState,
    onEvent: (DisclaimerViewEvent) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp)
        ) {
            item {
                Spacer(modifier = Modifier.height(4.dp))
                AcceptTermsText()
            }
            itemsIndexed(items = viewState.checkboxes) { _, item ->
                Spacer(modifier = Modifier.height(8.dp))
                AgreementTerm(viewState = item)
            }
            item {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            AgreeButton(
                enabled = true,
            ) { onEvent(DisclaimerViewEvent.OnAgreeClick) }
        }
    }
}
