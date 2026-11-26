package com.hilalsafi.cryptoclicker.ui.settings

import android.content.Context
import android.text.format.DateUtils
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CreateNewFolder
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.FileDownload
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.FolderOff
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Restore
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.hilalsafi.cryptoclicker.core.BackupConflict
import com.hilalsafi.cryptoclicker.core.BackupEntry
import com.hilalsafi.cryptoclicker.ui.LocalBackups
import com.hilalsafi.cryptoclicker.ui.LocalGame
import com.hilalsafi.cryptoclicker.ui.WantViews
import com.hilalsafi.cryptoclicker.ui.design.ListHeader
import com.hilalsafi.cryptoclicker.ui.design.SettingsNote
import com.hilalsafi.cryptoclicker.ui.design.Type
import com.hilalsafi.cryptoclicker.ui.design.ValueRow
import com.hilalsafi.cryptoclicker.ui.design.rememberFeedback
import com.hilalsafi.cryptoclicker.ui.design.semibold
import com.hilalsafi.cryptoclicker.ui.theme.Palette
import com.hilalsafi.cryptoclicker.ui.theme.gameColors
import com.hilalsafi.cryptoclicker.ui.theme.rowCard
import kotlinx.coroutines.launch

/**
 * Settings › Backup and Save Files (iOS: BackupView): keeping the game safe and moving it. The
 * automatic backups on this phone, a backup folder the player picks (which outlives uninstalling
 * the app), restoring from any of them, and a save file to export or import. Health Connect's
 * steps stay on this phone throughout.
 */
@Composable
fun ColumnScope.BackupPage() {
    WantViews("backup")
    val game = LocalGame.current
    val backups = LocalBackups.current
    val context = LocalContext.current
    val colors = gameColors
    val feedback = rememberFeedback()
    val scope = rememberCoroutineScope()
    val view by game.game.collectAsState()
    val page = view?.backup
    var confirmsReplace by remember { mutableStateOf(false) }
    var exportFailed by remember { mutableStateOf(false) }

    // The folder's copy is read as the page opens, so it can say what's there.
    LaunchedEffect(backups) { backups?.inspectFolder() }

    val exporter = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) scope.launch { if (backups?.exportSaveFile(uri) != true) exportFailed = true }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch { backups?.importSaveFile(uri) }
    }
    val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { tree ->
        if (tree != null) scope.launch {
            backups?.useFolder(tree)
            backups?.inspectFolder()
        }
    }

    if (page == null) return

    ListHeader("On This Phone")
    Card {
        ValueRow("Last backup", page.lastBackup?.let(::ago) ?: "Not yet")
        HorizontalDivider(color = colors.cardBorder)
        ActionRow("Back Up Now", Icons.Rounded.Refresh) {
            game.command("backup.now")
            scope.launch {
                backups?.syncFolder()
                backups?.inspectFolder()
            }
        }
    }
    SettingsNote("Your game is copied every ten minutes or so while you play and whenever you leave the app, with a copy a day for the last week, and kept as a snapshot before a restore or a reset replaces it. Your phone's own backup to your Google account includes them, when that's on.")

    ListHeader("Backup Folder")
    Card {
        val folder = page.folder
        if (folder != null) {
            ValueRow("Folder", folder.name)
            val conflict = folder.conflict
            when {
                conflict != null -> {
                    ProblemLine(conflictText(context, conflict), Palette.orange)
                    HorizontalDivider(color = colors.cardBorder)
                    ActionRow("Restore It…", Icons.Rounded.Restore) { game.command("backup.restore", mapOf("id" to "folder")) }
                    HorizontalDivider(color = colors.cardBorder)
                    ActionRow("Replace with This Game…", Icons.Rounded.Sync) { confirmsReplace = true }
                }
                folder.failure != null -> ProblemLine("The last backup couldn't be written: ${folder.failure}", colors.loss)
                else -> folder.backedUpAt?.let { ValueRow("Last backup", ago(it)) }
            }
            HorizontalDivider(color = colors.cardBorder)
            ActionRow("Choose Another Folder…", Icons.Rounded.Folder) { folderPicker.launch(null) }
            HorizontalDivider(color = colors.cardBorder)
            ActionRow("Stop Backing Up There", Icons.Rounded.FolderOff, tint = colors.loss) {
                scope.launch { backups?.forgetFolder() }
            }
        } else {
            ActionRow("Choose a Folder…", Icons.Rounded.CreateNewFolder) { folderPicker.launch(null) }
        }
    }
    SettingsNote("Pick a folder on this phone, a memory card or a cloud drive that offers folders, and your game is backed up there too, so it outlives uninstalling the app and a new phone can carry on from it: install Crypto Clicker, pick the same folder here and restore. A backup only ever replaces an earlier copy of this game: a copy further on, or of another game, stays until you choose.")

    if (page.entries.isNotEmpty()) {
        ListHeader("Restore")
        Card {
            page.entries.forEachIndexed { index, entry ->
                if (index > 0) HorizontalDivider(color = colors.cardBorder)
                BackupRow(entry) { game.command("backup.restore", mapOf("id" to entry.id)) }
            }
        }
        SettingsNote("Tap a backup to carry on from it. Restoring replaces the game on this phone.")
    }

    ListHeader("Save File")
    Card {
        ActionRow("Export Save File", Icons.Rounded.FileUpload) { exporter.launch("Crypto Clicker Save.json") }
        HorizontalDivider(color = colors.cardBorder)
        ActionRow("Import Save File…", Icons.Rounded.FileDownload) {
            importer.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
        }
    }
    SettingsNote("Export a save file to keep a copy yourself or move your game to another phone, and import one to carry on from it. Importing replaces the game on this phone. Steps from Health Connect stay on this phone.")

    page.pending?.let { copy ->
        AlertDialog(
            onDismissRequest = { game.command("backup.dismiss") },
            title = { Text("Replace your game?") },
            text = {
                Text("The game in ${copy.source} was last played ${dateTime(context, copy.savedAt)}: ${copy.holds}. It replaces the game on this phone, which is kept first as a snapshot in the backups on this phone.")
            },
            confirmButton = {
                TextButton(onClick = {
                    game.command("backup.confirm")
                    feedback.success()
                    // The folder's copy follows the game carried on from, when it may.
                    scope.launch {
                        backups?.syncFolder()
                        backups?.inspectFolder()
                    }
                }) { Text("Replace My Game", color = colors.loss) }
            },
            dismissButton = { TextButton(onClick = { game.command("backup.dismiss") }) { Text("Cancel") } },
        )
    }
    page.problem?.let { problem ->
        AlertDialog(
            onDismissRequest = { game.command("backup.dismiss") },
            title = { Text("Couldn't open that save") },
            text = { Text(problem) },
            confirmButton = { TextButton(onClick = { game.command("backup.dismiss") }) { Text("OK") } },
        )
    }
    if (confirmsReplace) {
        AlertDialog(
            onDismissRequest = { confirmsReplace = false },
            title = { Text("Replace the backup?") },
            text = { Text("The backup in the backup folder is replaced by the game on this phone. It's kept first as a snapshot on this phone, where you can still restore it.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmsReplace = false
                    scope.launch {
                        backups?.syncFolder(replacing = true)
                        backups?.inspectFolder()
                    }
                }) { Text("Replace It", color = colors.loss) }
            },
            dismissButton = { TextButton(onClick = { confirmsReplace = false }) { Text("Cancel") } },
        )
    }
    if (exportFailed) {
        AlertDialog(
            onDismissRequest = { exportFailed = false },
            title = { Text("Couldn't export the save") },
            text = { Text("The save file couldn't be written there. Try another place.") },
            confirmButton = { TextButton(onClick = { exportFailed = false }) { Text("OK") } },
        )
    }
}

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().rowCard(gameColors, cornerRadius = 18.dp, padding = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
}

/** A button as a list row: an icon and a title, in the accent colour. */
@Composable
private fun ActionRow(title: String, icon: ImageVector, tint: Color = gameColors.accent, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
        Text(title, style = Type.body, color = tint)
    }
}

/** Something that stopped a backup, or why one isn't replaced. */
@Composable
private fun ProblemLine(text: String, color: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(Icons.Rounded.Warning, null, tint = color, modifier = Modifier.padding(top = 2.dp).size(18.dp))
        Text(text, style = Type.subheadline, color = color)
    }
}

/** A backup to restore: when it was played, what it holds, and where it is (iOS: BackupRow). */
@Composable
private fun BackupRow(entry: BackupEntry, restore: () -> Unit) {
    val colors = gameColors
    val context = LocalContext.current
    Column(
        Modifier.fillMaxWidth().clickable(onClickLabel = "Restores this backup", onClick = restore).padding(vertical = 2.dp)
            .semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(dateTime(context, entry.savedAt), style = Type.headline, modifier = Modifier.weight(1f))
            Text(entry.place, style = Type.subheadline.semibold, color = colors.accent)
        }
        Text(entry.holds, style = Type.subheadline, color = colors.subtext)
        if (entry.fromAnotherDevice) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Rounded.Devices, null, tint = colors.subtext, modifier = Modifier.size(16.dp))
                Text("From another device", style = Type.subheadline, color = colors.subtext)
            }
        }
    }
}

/** Why a backup in the folder isn't replaced by the game here, and what it holds (iOS: ConflictNote). */
private fun conflictText(context: Context, conflict: BackupConflict): String {
    val holds = "${conflict.holds}, last backed up ${dateTime(context, conflict.savedAt)}"
    val place = "the backup folder"
    return when (conflict.kind) {
        "furtherOn" -> "The backup in $place is of this game but further on ($holds): it was played on another device, or after the copy this game was restored from. It isn't replaced, so nothing is lost: restore it to carry on from there, or replace it with the game here."
        "otherGame" -> "The backup in $place is of another game ($holds): one from another device, or the game here before a reset or a restore. It isn't replaced by this one unless you choose to."
        else -> "The backup in $place was made by a newer version of Crypto Clicker ($holds). Update the app to restore it. It isn't replaced unless you choose to."
    }
}

/** "Nov 26, 2026, 2:03 PM", in the phone's language. */
private fun dateTime(context: Context, seconds: Double): String =
    DateUtils.formatDateTime(context, (seconds * 1000).toLong(),
        DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_SHOW_YEAR or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_SHOW_TIME)

/** "5 minutes ago", in the phone's language. */
private fun ago(seconds: Double): String =
    DateUtils.getRelativeTimeSpanString((seconds * 1000).toLong(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()
