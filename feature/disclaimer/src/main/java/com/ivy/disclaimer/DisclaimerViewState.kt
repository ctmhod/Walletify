package com.ivy.disclaimer

import kotlinx.collections.immutable.ImmutableList

data class DisclaimerViewState(
    val checkboxes: ImmutableList<CheckboxViewState>,
    val agreeButtonEnabled: Boolean,
    val allChecked: Boolean = false,
)

data class CheckboxViewState(
    val text: String,
    val checked: Boolean
)

sealed interface DisclaimerViewEvent {
    data class OnCheckboxClick(val index: Int) : DisclaimerViewEvent
    data object OnAgreeAllClick : DisclaimerViewEvent
    data object OnAgreeClick : DisclaimerViewEvent
}