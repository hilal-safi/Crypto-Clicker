package com.hilalsafi.cryptoclicker.ui.design

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import kotlinx.coroutines.launch

/**
 * A sheet with a title and a Done button (iOS: a sheet's NavigationStack with an inline title and a
 * confirmation button). [content] gets `close`, which slides the sheet away before [onDismiss].
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppSheet(
    title: String,
    onDismiss: () -> Unit,
    skipPartiallyExpanded: Boolean = true,
    doneTitle: String = "Done",
    content: @Composable ColumnScope.(close: () -> Unit) -> Unit,
) {
    val colors = gameColors
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = skipPartiallyExpanded)
    val scope = rememberCoroutineScope()
    val close: () -> Unit = { scope.launch { sheet.hide() }.invokeOnCompletion { onDismiss() } }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = colors.base, contentColor = colors.text) {
        Column {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title, style = Type.headline, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).padding(start = 8.dp).semantics { heading() },
                )
                TextButton(onClick = close) { Text(doneTitle, style = Type.headline) }
            }
            content(close)
        }
    }
}
