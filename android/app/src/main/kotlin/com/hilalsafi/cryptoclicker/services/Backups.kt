package com.hilalsafi.cryptoclicker.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import com.hilalsafi.cryptoclicker.core.GameController
import com.hilalsafi.cryptoclicker.ui.AppPrefs
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Backups outside the app (iOS: GameBackups' picked folder and the save file): a folder the
 * player picks (on the phone, a memory card or a cloud drive that offers folders), which outlives
 * uninstalling the app, and save files to export and import. Android grants the folder as a
 * document tree, so the app reads and writes the copy there; the native game decides whether the
 * game here may replace it (only an earlier copy of the same game does, unless the player chooses
 * to) and keeps the backups on this phone itself.
 */
class Backups(private val context: Context, private val game: GameController, private val prefs: AppPrefs) {
    private companion object {
        /** The file the copy in the folder is kept in (as on iOS). */
        const val FOLDER_FILE = "Crypto Clicker Backup.json"
        /** Saves are well under a megabyte; anything this big isn't one. */
        const val LARGEST_SAVE = 16L * 1024 * 1024
        const val ACCESS = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    private val mutex = Mutex()

    private val folder: Uri?
        get() = prefs.backupFolder.value.takeIf { it.isNotEmpty() }?.let(Uri::parse)

    /** Keeps the folder the player picked, and backs up there now (unless it has a copy the game here mustn't replace by itself). */
    suspend fun useFolder(tree: Uri) {
        withContext(Dispatchers.IO) { runCatching { context.contentResolver.takePersistableUriPermission(tree, ACCESS) } }
        val name = withContext(Dispatchers.IO) { runCatching { displayName(tree) }.getOrNull() } ?: "Backup folder"
        prefs.backupFolder.set(tree.toString())
        prefs.backupFolderName.set(name)
        syncFolder()
    }

    /** Stops backing up to the folder; the copies already there stay. */
    suspend fun forgetFolder() {
        val tree = folder
        prefs.backupFolder.set("")
        prefs.backupFolderName.set("")
        if (tree != null) withContext(Dispatchers.IO) { runCatching { context.contentResolver.releasePersistableUriPermission(tree, ACCESS) } }
        game.call("backup.inspectFolder")
    }

    /** Reads the folder's copy, for the Backup page: what's there, and whether it may be replaced. */
    suspend fun inspectFolder() {
        val tree = folder
        if (tree == null) {
            game.call("backup.inspectFolder")
            return
        }
        val copy = withContext(Dispatchers.IO) { runCatching { read(tree) }.getOrNull() }
        game.call("backup.inspectFolder", mapOf("id" to prefs.backupFolderName.value, "text" to copy))
    }

    /**
     * Writes the game's copy to the picked folder (every ten minutes or so while playing, as the app
     * leaves, and when asked). The copy there is replaced only when it's an earlier one of this
     * game, unless [replacing]: the player chose to, and it's kept as a snapshot first.
     */
    suspend fun syncFolder(replacing: Boolean = false) {
        mutex.withLock { writeFolderCopy(replacing) }
    }

    private suspend fun writeFolderCopy(replacing: Boolean) {
        val tree = folder ?: return
        try {
            val existing = withContext(Dispatchers.IO) { read(tree) }
            val args = mapOf("id" to prefs.backupFolderName.value, "text" to existing, "flag" to replacing)
            // Nothing to write when the copy there mustn't be replaced: the game says why.
            val data = game.call("backup.folderData", args)?.data ?: return
            withContext(Dispatchers.IO) { write(tree, data) }
            game.call("backup.folderWritten", mapOf("flag" to true))
        } catch (error: Exception) {
            game.call("backup.folderWritten", mapOf("flag" to false, "text" to (error.message ?: "The folder couldn't be reached.")))
        }
    }

    /** Exports the game as a save file, to the document the player made. Returns whether it was written. */
    suspend fun exportSaveFile(to: Uri): Boolean {
        val data = game.call("backup.export")?.data ?: return false
        return withContext(Dispatchers.IO) {
            runCatching {
                context.contentResolver.openOutputStream(to, "wt")?.use { it.write(data.toByteArray(Charsets.UTF_8)) } != null
            }.getOrDefault(false)
        }
    }

    /** Reads a save file the player picked to import: the game asks them to confirm it replaces the game here. */
    suspend fun importSaveFile(from: Uri) {
        val text = withContext(Dispatchers.IO) { runCatching { readLimited(from) }.getOrNull() }
        game.call("backup.readFile", mapOf("text" to (text ?: "")))
    }

    // MARK: The document tree

    private fun displayName(tree: Uri): String? {
        val document = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val cursor = context.contentResolver.query(document, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?: return null
        return cursor.use { if (it.moveToFirst()) it.getString(0) else null }
    }

    /** The copy in the folder, if there is one. */
    private fun find(tree: Uri): Uri? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        val cursor = context.contentResolver.query(children, columns, null, null, null) ?: return null
        val id = cursor.use {
            var found: String? = null
            while (found == null && it.moveToNext()) {
                if (it.getString(1) == FOLDER_FILE) found = it.getString(0)
            }
            found
        }
        return id?.let { DocumentsContract.buildDocumentUriUsingTree(tree, it) }
    }

    private fun read(tree: Uri): String? = find(tree)?.let(::readLimited)

    private fun readLimited(file: Uri): String? =
        context.contentResolver.openInputStream(file)?.use { stream ->
            val bytes = stream.readNBytesCompat(LARGEST_SAVE + 1)
            if (bytes.size > LARGEST_SAVE) null else bytes.toString(Charsets.UTF_8)
        }

    private fun write(tree: Uri, data: String) {
        val resolver = context.contentResolver
        val file = find(tree) ?: DocumentsContract.createDocument(
            resolver, DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree)),
            "application/json", FOLDER_FILE,
        ) ?: throw IOException("The backup couldn't be made in that folder.")
        resolver.openOutputStream(file, "wt")?.use { it.write(data.toByteArray(Charsets.UTF_8)) }
            ?: throw IOException("The folder couldn't be written.")
    }
}

/** Up to [limit] bytes of the stream (InputStream.readNBytes needs API 33). */
private fun java.io.InputStream.readNBytesCompat(limit: Long): ByteArray {
    val out = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(64 * 1024)
    var total = 0L
    while (total < limit) {
        val read = read(buffer, 0, minOf(buffer.size.toLong(), limit - total).toInt())
        if (read < 0) break
        out.write(buffer, 0, read)
        total += read
    }
    return out.toByteArray()
}
