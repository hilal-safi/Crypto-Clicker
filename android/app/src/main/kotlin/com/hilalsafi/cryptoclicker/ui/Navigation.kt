package com.hilalsafi.cryptoclicker.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import com.hilalsafi.cryptoclicker.ui.design.Type

/**
 * The pages pushed over a tab's own screen (iOS: a NavigationStack's path), as route strings such
 * as "statistics" or "game/snake". The system back gesture pops them.
 */
@Stable
class Navigator(initial: List<String> = emptyList()) {
    val stack = mutableStateListOf<String>().apply { addAll(initial) }
    val top: String? get() = stack.lastOrNull()
    val isAtRoot: Boolean get() = stack.isEmpty()

    fun push(route: String) {
        if (stack.lastOrNull() != route) stack.add(route)
    }

    fun pop() {
        if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex)
    }

    /** Back to the tab's own screen, then [route] on top of it if one is given. */
    fun reset(route: String? = null) {
        stack.clear()
        if (route != null) stack.add(route)
    }

    companion object {
        val saver = Saver<Navigator, List<String>>(save = { it.stack.toList() }, restore = { Navigator(it) })
    }
}

@Composable
fun rememberNavigator(): Navigator = rememberSaveable(saver = Navigator.saver) { Navigator() }

/**
 * A tab's screen with the pages pushed over it: the top one shows, sliding in from the side, and
 * each keeps its scroll position while another is on top.
 */
@Composable
fun NavHost(navigator: Navigator, root: @Composable () -> Unit, page: @Composable (String) -> Unit) {
    val states = rememberSaveableStateHolder()
    BackHandler(enabled = !navigator.isAtRoot) { navigator.pop() }
    val depth = navigator.stack.size
    AnimatedContent(
        targetState = navigator.top to depth,
        transitionSpec = {
            val forward = targetState.second > initialState.second
            if (forward) {
                (slideInHorizontally(tween(280)) { it } + fadeIn(tween(200))) togetherWith (slideOutHorizontally(tween(280)) { -it / 4 } + fadeOut(tween(200)))
            } else {
                (slideInHorizontally(tween(280)) { -it / 4 } + fadeIn(tween(200))) togetherWith (slideOutHorizontally(tween(280)) { it } + fadeOut(tween(200)))
            }
        },
        contentKey = { it.first ?: "" },
        label = "pages",
    ) { (route, _) ->
        Box(Modifier.fillMaxSize()) {
            if (route == null) {
                states.SaveableStateProvider("root") { root() }
            } else {
                states.SaveableStateProvider(route) { page(route) }
            }
        }
    }
}

/**
 * A pushed page: a title bar with a back button over [content], which is given the padding to
 * keep clear of the bars (iOS: a navigation destination with its title).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PageScaffold(
    title: String,
    onBack: () -> Unit,
    contentPadding: PaddingValues,
    actions: @Composable RowScope.() -> Unit = {},
    background: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        background()
        Column(Modifier.fillMaxSize()) {
            CenterAlignedTopAppBar(
                title = { Text(title, style = Type.headline, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back") }
                },
                actions = actions,
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Transparent, scrolledContainerColor = Color.Transparent),
                modifier = Modifier.statusBarsPadding(),
                windowInsets = androidx.compose.foundation.layout.WindowInsets(0),
            )
            Box(Modifier.fillMaxSize()) {
                content(PaddingValues(bottom = contentPadding.calculateBottomPadding()))
            }
        }
    }
}
