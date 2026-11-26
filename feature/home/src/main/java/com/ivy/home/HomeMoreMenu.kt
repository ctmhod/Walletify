package com.ivy.home

import androidx.annotation.DrawableRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.ivy.base.legacy.Theme
import com.ivy.design.l0_system.UI
import com.ivy.design.l0_system.style
import com.ivy.design.utils.thenIf
import com.ivy.legacy.ivyWalletCtx
import com.ivy.legacy.utils.clickableNoIndication
import com.ivy.legacy.utils.colorLerp
import com.ivy.legacy.utils.lerp
import com.ivy.legacy.utils.navigationBarInset
import com.ivy.legacy.utils.rememberInteractionSource
import com.ivy.legacy.utils.rememberSwipeListenerState
import com.ivy.legacy.utils.springBounce
import com.ivy.legacy.utils.statusBarInset
import com.ivy.legacy.utils.toDensityPx
import com.ivy.legacy.utils.verticalSwipeListener
import com.ivy.navigation.BudgetScreen
import com.ivy.navigation.CategoriesScreen
import com.ivy.navigation.IvyPreview
import com.ivy.navigation.LoansScreen
import com.ivy.navigation.PlannedPaymentsScreen
import com.ivy.navigation.ReportScreen
import com.ivy.navigation.SearchScreen
import com.ivy.navigation.SettingsScreen
import com.ivy.navigation.navigation
import com.ivy.ui.R
import com.ivy.wallet.ui.theme.Gray
import com.ivy.wallet.ui.theme.components.CircleButtonFilled
import com.ivy.wallet.ui.theme.components.IvyIcon
import com.ivy.wallet.ui.theme.modal.AddModalBackHandling
import java.util.UUID
import kotlin.math.roundToInt

private const val SWIPE_UP_THRESHOLD_CLOSE_MORE_MENU = 300

@Composable
fun BoxWithConstraintsScope.MoreMenu(
    expanded: Boolean,

    balance: Double,
    buffer: Double,
    currency: String,
    theme: Theme,

    setExpanded: (Boolean) -> Unit,
    onSwitchTheme: () -> Unit,
    onBufferClick: () -> Unit,
    onCurrencyClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ivyContext = ivyWalletCtx()

    val percentExpanded by animateFloatAsState(
        targetValue = if (expanded) 1f else 0f,
        animationSpec = springBounce(),
        label = ""
    )
    val iconRotation by animateFloatAsState(
        targetValue = if (expanded) -180f else 0f,
        animationSpec = springBounce(),
        label = ""
    )

    val buttonSizePx = 40.dp.toDensityPx()

    val xBase = ivyContext.screenWidth - 24.dp.toDensityPx()
    val yBaseCollapsed = 20.dp.toDensityPx() + statusBarInset()
    val yBaseExpanded = ivyContext.screenHeight - 48.dp.toDensityPx() - navigationBarInset()

    val yButton = lerp(
        start = yBaseCollapsed,
        end = yBaseExpanded - buttonSizePx,
        fraction = percentExpanded
    )

    // Background
    val colorMedium = UI.colors.medium
    if (percentExpanded > 0.01f) {
        Canvas(
            modifier = modifier
                .fillMaxSize()
                .clickableNoIndication(rememberInteractionSource()) {
                    // do nothing
                }
                .zIndex(500f)
        ) {
            val radiusCollapsed = buttonSizePx / 2f
            val radiusExpanded = ivyContext.screenHeight * 1.5f
            val radius = lerp(radiusCollapsed, radiusExpanded, percentExpanded)

            val yBackground = lerp(
                start = yBaseCollapsed + radius,
                end = yBaseExpanded,
                fraction = percentExpanded
            )

            drawCircle(
                color = colorMedium,
                center = Offset(
                    x = xBase - buttonSizePx / 2f,
                    y = yBackground
                ),
                radius = radius
            )
        }
    }

    if (percentExpanded > 0.01f) {
        Column(
            modifier = modifier
                .statusBarsPadding()
                .navigationBarsPadding()
                .fillMaxSize()
                .alpha(percentExpanded)
                .verticalScroll(rememberScrollState())
                .zIndex(510f)
                .verticalSwipeListener(
                    sensitivity = SWIPE_UP_THRESHOLD_CLOSE_MORE_MENU,
                    state = rememberSwipeListenerState(),
                    onSwipeUp = {
                        setExpanded(false)
                    }
                )
        ) {
            val modalId = remember {
                UUID.randomUUID()
            }

            AddModalBackHandling(
                modalId = modalId,
                visible = expanded
            ) {
                setExpanded(false)
            }

            Content(
                theme = theme,
                onSwitchTheme = onSwitchTheme,
                balance = balance,
                buffer = buffer,
                currency = currency,
                onBufferClick = onBufferClick,
                onCurrencyClick = onCurrencyClick
            )
        }
    }

    CircleButtonFilled(
        modifier = Modifier
            .layout { measurable, constraints ->
                val placeable = measurable.measure(constraints)

                layout(placeable.width, placeable.height) {
                    placeable.place(
                        x = xBase.roundToInt() - buttonSizePx.roundToInt(),
                        y = yButton.roundToInt()
                    )
                }
            }
            .rotate(iconRotation)
            .thenIf(expanded) {
                zIndex(520f)
            }
            .testTag("home_more_menu_arrow"),
        backgroundColor = colorLerp(UI.colors.medium, UI.colors.pure, percentExpanded),
        icon = R.drawable.ic_expandarrow
    ) {
        setExpanded(!expanded)
    }
}

@Composable
private fun ColumnScope.Content(
    balance: Double,
    buffer: Double,
    currency: String,
    theme: Theme,

    onSwitchTheme: () -> Unit,
    onBufferClick: () -> Unit,
    onCurrencyClick: () -> Unit,
) {
    Spacer(Modifier.height(24.dp))

    val nav = navigation()
    SearchButton {
        nav.navigateTo(
            screen = SearchScreen
        )
    }

    Spacer(Modifier.height(16.dp))

    QuickAccess(
        onSavingsGoalClick = onBufferClick
    )

    Spacer(Modifier.weight(1f))
}

@Composable
private fun SearchButton(
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(UI.shapes.rFull)
            .background(UI.colors.pure)
            .border(1.dp, Gray, UI.shapes.rFull)
            .clickable {
                onClick()
            },
        verticalAlignment = Alignment.CenterVertically
    ) {
        Spacer(Modifier.width(12.dp))

        IvyIcon(icon = R.drawable.ic_search)

        Spacer(Modifier.width(12.dp))

        Text(
            modifier = Modifier.padding(
                vertical = 12.dp,
            ),
            text = stringResource(R.string.search_transactions),
            style = UI.typo.b2.style(
                fontWeight = FontWeight.SemiBold,
                color = UI.colors.pureInverse
            )
        )

        Spacer(Modifier.width(16.dp))
    }
}

@Composable
private fun QuickAccess(
    onSavingsGoalClick: () -> Unit
) {
    Column {
        val nav = navigation()

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 24.dp, end = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.quick_access),
                style = UI.typo.b2.style()
            )

            Spacer(Modifier.weight(1f))

            CircleButtonFilled(
                icon = R.drawable.ic_home_gear,
                contentDescription = stringResource(R.string.settings),
                backgroundColor = UI.colors.pure,
                tint = UI.colors.pureInverse,
                clickAreaPadding = 10.dp
            ) {
                nav.navigateTo(SettingsScreen)
            }
        }

        Spacer(Modifier.height(8.dp))

        MoreMenuButton(
            icon = R.drawable.home_more_menu_categories,
            label = stringResource(R.string.categories)
        ) {
            nav.navigateTo(CategoriesScreen)
        }

        MoreMenuButton(
            icon = R.drawable.home_more_menu_planned_payments,
            label = stringResource(R.string.planned_payments)
        ) {
            nav.navigateTo(PlannedPaymentsScreen)
        }

        MoreMenuButton(
            icon = R.drawable.home_more_menu_savings_goal,
            label = stringResource(R.string.savings_goal)
        ) {
            onSavingsGoalClick()
        }

        MoreMenuButton(
            icon = R.drawable.home_more_menu_reports,
            label = stringResource(R.string.reports),
        ) {
            nav.navigateTo(ReportScreen)
        }

        MoreMenuButton(
            icon = R.drawable.home_more_menu_budgets,
            label = stringResource(R.string.budgets),
        ) {
            nav.navigateTo(BudgetScreen)
        }

        MoreMenuButton(
            icon = R.drawable.home_more_menu_loans,
            label = stringResource(R.string.loans),
        ) {
            nav.navigateTo(LoansScreen)
        }
    }
}

@Composable
private fun MoreMenuButton(
    @DrawableRes icon: Int,
    label: String,

    backgroundColor: Color = UI.colors.pure,
    tint: Color = UI.colors.pureInverse,

    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(UI.shapes.r4)
            .background(backgroundColor)
            .clickable { onClick() }
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IvyIcon(
            icon = icon,
            tint = tint
        )

        Spacer(Modifier.width(16.dp))

        Text(
            text = label,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            style = UI.typo.b2.style(
                color = tint,
                fontWeight = FontWeight.ExtraBold
            )
        )
    }
}

@Preview
@Composable
private fun BoxWithConstraintsScope.Preview_Expanded() {
    IvyPreview {
        MoreMenu(
            expanded = true,
            balance = 7523.43,
            buffer = 5000.0,
            currency = "BGN",
            theme = Theme.LIGHT,
            setExpanded = {
            },
            onSwitchTheme = {},
            onBufferClick = {},
            onCurrencyClick = {}
        )
    }
}

@Preview
@Composable
private fun BoxWithConstraintsScope.Preview() {
    IvyPreview {
        var expanded by remember { mutableStateOf(false) }

        MoreMenu(
            expanded = expanded,
            balance = 7523.43,
            buffer = 5000.0,
            currency = "BGN",
            theme = Theme.LIGHT,
            setExpanded = {
                expanded = it
            },
            onSwitchTheme = {},
            onBufferClick = {},
            onCurrencyClick = {}
        )
    }
}
