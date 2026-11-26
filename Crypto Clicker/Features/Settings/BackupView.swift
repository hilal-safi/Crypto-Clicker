import SwiftUI
import UniformTypeIdentifiers
import CryptoClickerKit

/// Keeping the game safe and moving it: the automatic backups (on this iPhone, in iCloud where the
/// app has the iCloud capability, and in a folder the player picks, such as iCloud Drive),
/// restoring from any of them, and a save file to export or import. Apple Health's steps stay on
/// this iPhone throughout.
struct BackupView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.openURL) private var openURL
    @AppStorage(Preferences.iCloudBackupKey) private var backsUpToICloud = true
    /// What the file picker is choosing: a save file to import, or a folder for backups.
    @State private var picking: Picking?
    /// A copy waiting for the player to confirm it replaces the game here.
    @State private var pending: PendingCopy?
    @State private var problem: String?
    @State private var restored = 0
    @State private var entries: [GameBackups.Entry] = []
    /// A backup elsewhere waiting for the player to confirm the game here replaces it.
    @State private var replacing: Destination?
    /// The picked folder's copy, when the game here doesn't replace it by itself (read with the
    /// list, not on every redraw).
    @State private var folderConflict: GameBackups.FolderConflict?
    /// Goes up when the backups' status may have changed, to show it.
    @State private var redraws = 0

    private enum Picking {
        case saveFile, folder
    }

    /// Where a backup goes besides this iPhone.
    private enum Destination {
        case folder, iCloud

        var name: String {
            switch self {
            case .folder: String(localized: "the backup folder")
            case .iCloud: String(localized: "iCloud")
            }
        }
    }

    var body: some View {
        let backups = store.backups
        let _ = redraws
        List {
            automaticSection(backups)
            cloudSection(store.cloudBackup)
            folderSection(backups)
            restoreSection
            Section {
                ShareLink(item: SaveFile(game: store.game),
                          preview: SharePreview("Crypto Clicker save", image: Image(systemName: "doc.badge.gearshape"))) {
                    Label("Export Save File", systemImage: "square.and.arrow.up")
                }
                Button("Import Save File…", systemImage: "square.and.arrow.down") { picking = .saveFile }
            } header: {
                Text("Save File")
            } footer: {
                SettingsNote("Export a save file to keep a copy yourself or move your game to another iPhone, and import one to carry on from it. Importing replaces the game on this iPhone.")
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.cloudBackup.refreshAvailability()
            reload()
        }
        .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                      allowedContentTypes: picking == .folder ? [.folder] : [.json]) { result in
            picked(result)
        }
        .alert("Replace your game?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
               presenting: pending) { copy in
            Button("Replace My Game", role: .destructive) {
                store.importGame(copy.game)
                restored += 1
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: { copy in
            Text(copy.message)
        }
        .alert("Replace the backup?", isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } }),
               presenting: replacing) { destination in
            Button("Replace It", role: .destructive) { replace(destination) }
            Button("Cancel", role: .cancel) {}
        } message: { destination in
            Text("The backup in \(destination.name) is replaced by the game on this iPhone. It's kept first as a snapshot on this iPhone, where you can still restore it.")
        }
        .alert("Couldn't open that save", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
        .sensoryFeedback(.success, trigger: restored)
    }

    // MARK: Sections

    private func automaticSection(_ backups: GameBackups) -> some View {
        Section {
            LabeledContent("Last backup", value: backups.lastLocalBackup.map(Self.relative) ?? "Not yet")
            Button("Back Up Now", systemImage: "arrow.clockwise.circle") {
                backups.backUp(store.game, force: true)
                store.cloudBackup.backUp(store.game, force: true)
                reload()
            }
            Button("Show in Files", systemImage: "folder") { showInFiles(backups.localFolder) }
        } header: {
            Text("On This iPhone")
        } footer: {
            SettingsNote("Your game is copied every ten minutes or so while you play and whenever you leave the app, with a copy a day for the last week, and kept as a snapshot before a restore or a reset replaces it. They're in the Files app, under On My iPhone › Crypto Clicker, and your iPhone's own backup includes them.")
        }
    }

    /// The iCloud backup: on where the app has the iCloud capability (Key-value storage) and the
    /// iPhone is signed in to iCloud; otherwise the switch is off and the note says why.
    private func cloudSection(_ backup: CloudBackup) -> some View {
        Section {
            // Off while iCloud can't be used, whatever the setting, so it never looks like it's on.
            Toggle("Back Up to iCloud", isOn: Binding(get: { backsUpToICloud && backup.isAvailable },
                                                      set: { backsUpToICloud = $0 }))
                .disabled(!backup.isAvailable)
                .onChange(of: backsUpToICloud) { _, isOn in
                    if isOn { backup.backUp(store.game, force: true) }
                }
            if backup.isAvailable, let latest = backup.latest {
                LabeledContent("Last backup", value: Self.relative(latest.savedAt))
                if backsUpToICloud, let conflict = backup.conflict(with: store.game) {
                    ConflictNote(conflict: conflict, place: Destination.iCloud.name, copy: latest)
                    Button("Replace with This Game…", systemImage: "arrow.triangle.2.circlepath") { replacing = .iCloud }
                }
                Button("Restore from iCloud…", systemImage: "icloud.and.arrow.down") { restoreFromICloud() }
            }
            if backup.isAvailable && backsUpToICloud {
                switch backup.status {
                case .tooLarge(let size):
                    Problem("Your game is too big for iCloud's backup (\(size.formatted(.byteCount(style: .file)))), so it isn't backed up there. The backups on this iPhone and in a folder have no limit.")
                case .full:
                    Problem("iCloud's storage for Crypto Clicker is full, so the latest backup wasn't kept. The backups on this iPhone and in a folder still are.")
                case .failed(let reason):
                    Problem("The last backup to iCloud didn't go through: \(reason)")
                case .none, .backedUp, .conflict:
                    EmptyView()
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            SettingsNote(backup.isAvailable
                ? "A copy of your game goes to iCloud every ten minutes or so while you play, and when you leave the app. A new iPhone can carry on from it. It only ever replaces an earlier copy of this game: a copy further on, or of another game, stays until you choose."
                : "iCloud backup needs iCloud turned on for this app and an iPhone signed in to iCloud. The backups on this iPhone and in a folder work without it.")
        }
    }

    private func folderSection(_ backups: GameBackups) -> some View {
        Section {
            if let name = backups.pickedFolderName {
                LabeledContent("Folder", value: name)
                if let found = folderConflict {
                    ConflictNote(conflict: found.conflict, place: Destination.folder.name, copy: found.entry.header)
                    Button("Restore It…", systemImage: "arrow.down.doc") { restore(found.entry) }
                    Button("Replace with This Game…", systemImage: "arrow.triangle.2.circlepath") { replacing = .folder }
                } else {
                    switch backups.folderStatus {
                    case .none, .conflict:
                        EmptyView()
                    case .backedUp(let date):
                        LabeledContent("Last backup", value: Self.relative(date))
                    case .failed(let reason):
                        Problem("The last backup couldn't be written: \(reason)")
                    }
                }
                Button("Choose Another Folder…", systemImage: "folder.badge.gearshape") { picking = .folder }
                Button("Stop Backing Up There", systemImage: "folder.badge.minus", role: .destructive) {
                    backups.forgetFolder()
                    reload()
                }
            } else {
                Button("Choose a Folder…", systemImage: "folder.badge.plus") { picking = .folder }
            }
        } header: {
            Text("Backup Folder")
        } footer: {
            SettingsNote("Pick a folder in Files, such as one in iCloud Drive, and your game is backed up there too, so a new iPhone can carry on from it: install Crypto Clicker, pick the same folder here and restore. A backup only ever replaces an earlier copy of this game: a copy further on, or of another game, stays until you choose.")
        }
    }

    @ViewBuilder
    private var restoreSection: some View {
        if !entries.isEmpty {
            Section {
                ForEach(entries) { entry in
                    Button {
                        restore(entry)
                    } label: {
                        BackupRow(entry: entry, place: place(of: entry))
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Restore")
            } footer: {
                SettingsNote("Tap a backup to carry on from it. Restoring replaces the game on this iPhone.")
            }
        }
    }

    // MARK: Actions

    private func reload() {
        entries = store.backups.entries()
        folderConflict = store.backups.folderConflict(with: store.game)
        redraws += 1
    }

    private func place(of entry: GameBackups.Entry) -> String {
        switch entry.place {
        case .folder: String(localized: "Backup folder")
        case .latest: String(localized: "Latest on this iPhone")
        case .daily: String(localized: "Daily copy")
        case .snapshot(.restore): String(localized: "Before a restore")
        case .snapshot(.reset): String(localized: "Before a reset")
        case .snapshot(.folderCopy): String(localized: "Folder copy, replaced")
        case .snapshot(.iCloudCopy): String(localized: "iCloud copy, replaced")
        }
    }

    /// Replaces the backup in `destination` with the game here, keeping it as a snapshot first.
    private func replace(_ destination: Destination) {
        switch destination {
        case .folder: store.backups.replaceFolderCopy(with: store.game)
        case .iCloud: store.cloudBackup.replace(with: store.game, keepingCopyIn: store.backups)
        }
        reload()
    }

    private func restoreFromICloud() {
        do {
            pending = PendingCopy(game: try store.cloudBackup.restore(), source: "the iCloud backup")
        } catch {
            problem = Self.explanation(of: error)
        }
    }

    private func restore(_ entry: GameBackups.Entry) {
        do {
            pending = PendingCopy(game: try store.backups.game(in: entry), source: "this backup")
        } catch {
            problem = Self.explanation(of: error)
        }
    }

    private func picked(_ result: Result<URL, Error>) {
        let mode = picking
        picking = nil
        do {
            let url = try result.get()
            if mode == .folder {
                store.backups.useFolder(url, for: store.game)
                reload()
                return
            }
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            pending = PendingCopy(game: try SaveTransfer.game(from: Data(contentsOf: url)), source: "this save file")
        } catch {
            problem = Self.explanation(of: error)
        }
    }

    /// Opens the Files app at `folder`.
    private func showInFiles(_ folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let url = URL(string: "shareddocuments://" + folder.path(percentEncoded: true)) { openURL(url) }
    }

    private static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private static func explanation(of error: Error) -> String {
        switch error as? SaveTransfer.ReadError {
        case .newerVersion: "It was saved by a newer version of Crypto Clicker. Update the app, then try again."
        case .unreadable: "It isn't a Crypto Clicker save, or it's damaged."
        case nil: error.localizedDescription
        }
    }
}

/// A backup to restore: when it was played, what it holds, and where it is.
private struct BackupRow: View {
    let entry: GameBackups.Entry
    let place: String

    var body: some View {
        let header = entry.header
        let prestiges = header.prestiges == 1 ? "1 prestige" : "\(CoinFormat.grouped(header.prestiges)) prestiges"
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(header.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer(minLength: 8)
                Text(place)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text("\(CoinFormat.short(header.lifetimeCoins)) coins mined · \(prestiges)")
                .font(.subheadline)
                .foregroundStyle(.subtext)
            if !entry.isFromThisDevice && header.device != nil {
                Label("From another device", systemImage: "iphone.and.arrow.forward")
                    .font(.subheadline)
                    .foregroundStyle(.subtext)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Restores this backup")
    }
}

/// Why a backup elsewhere isn't replaced by the game here, and what it holds.
private struct ConflictNote: View {
    let conflict: SaveTransfer.Conflict
    /// "iCloud", "the backup folder".
    let place: String
    let copy: SaveTransfer.Header

    var body: some View {
        let prestiges = copy.prestiges == 1 ? "1 prestige" : "\(CoinFormat.grouped(copy.prestiges)) prestiges"
        let holds = "\(CoinFormat.short(copy.lifetimeCoins)) coins mined, \(prestiges), last backed up \(copy.savedAt.formatted(date: .abbreviated, time: .shortened))"
        Label {
            switch conflict {
            case .furtherOn:
                Text("The backup in \(place) is of this game but further on (\(holds)): it was played on another device, or after the copy this game was restored from. It isn't replaced, so nothing is lost: restore it to carry on from there, or replace it with the game here.")
            case .otherGame:
                Text("The backup in \(place) is of another game (\(holds)): one from another device, or the game here before a reset or a restore. It isn't replaced by this one unless you choose to.")
            case .newerVersion:
                Text("The backup in \(place) was made by a newer version of Crypto Clicker (\(holds)). Update the app to restore it. It isn't replaced unless you choose to.")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.subheadline)
        .foregroundStyle(.orange)
    }
}

/// Something that stopped a backup, in red.
private struct Problem: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
    }
}

/// A copy of a game waiting to replace the one here, with what it holds.
private struct PendingCopy {
    let game: GameState
    /// Where it's from: "this backup", "the iCloud backup", "this save file".
    let source: String

    var message: String {
        let summary = SaveTransfer.Summary(of: game)
        let prestiges = summary.prestiges == 1 ? "1 prestige" : "\(CoinFormat.grouped(summary.prestiges)) prestiges"
        return "The game in \(source) was last played \(summary.savedAt.formatted(date: .abbreviated, time: .shortened)): \(CoinFormat.short(summary.lifetimeCoins)) coins mined, \(prestiges). It replaces the game on this iPhone, which is kept first as a snapshot in the backups on this iPhone."
    }
}

/// The game as a save file to share: JSON, without Apple Health data (`SaveTransfer`). Encoded
/// only when it's shared.
struct SaveFile: Transferable {
    let game: GameState

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            try SaveTransfer.data(of: file.game)
        }
        .suggestedFileName("Crypto Clicker Save.json")
    }
}
