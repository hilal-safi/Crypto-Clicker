import SwiftUI
import UniformTypeIdentifiers
import CryptoClickerKit

/// Keeping the game safe and moving it: the iCloud backup (and restoring from it), and a save file
/// to export or import. Apple Health's steps stay on this iPhone either way.
struct BackupView: View {
    @Environment(GameStore.self) private var store
    @AppStorage(Preferences.iCloudBackupKey) private var backsUp = true
    @State private var choosingFile = false
    /// A copy waiting for the player to confirm it replaces the game here.
    @State private var pending: PendingCopy?
    @State private var problem: String?
    @State private var restored = 0

    var body: some View {
        let backup = store.cloudBackup
        let latest = backup.latest
        List {
            Section {
                Toggle("Back Up to iCloud", isOn: $backsUp)
                    .disabled(!backup.isAvailable)
                    .onChange(of: backsUp) { _, isOn in
                        if isOn { backup.backUp(store.game, force: true) }
                    }
                if let latest {
                    LabeledContent("Last backup", value: latest.savedAt.formatted(.relative(presentation: .named)))
                    Button("Restore from iCloud…", systemImage: "icloud.and.arrow.down") { restoreFromICloud() }
                }
            } header: {
                Text("iCloud")
            } footer: {
                SettingsNote(iCloudNote(available: backup.isAvailable, newerElsewhere: backup.hasMoreProgressElsewhere(than: store.game)))
            }

            Section {
                ShareLink(item: SaveFile(game: store.game),
                          preview: SharePreview("Crypto Clicker save", image: Image(systemName: "doc.badge.gearshape"))) {
                    Label("Export Save File", systemImage: "square.and.arrow.up")
                }
                Button("Import Save File…", systemImage: "square.and.arrow.down") { choosingFile = true }
            } header: {
                Text("Save File")
            } footer: {
                SettingsNote("Export a save file to keep a copy yourself or move your game to another iPhone, and import one to carry on from it. Importing replaces the game on this iPhone.")
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { backup.refreshAvailability() }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            read(result)
        }
        .alert(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
               presenting: pending) { copy in
            Button("Replace My Game", role: .destructive) {
                store.importGame(copy.game)
                restored += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: { copy in
            Text(copy.message)
        }
        .alert("Couldn't open that save", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
        .sensoryFeedback(.success, trigger: restored)
    }

    private func iCloudNote(available: Bool, newerElsewhere: Bool) -> String {
        guard available else {
            return "iCloud isn't available: sign in to iCloud in the Settings app to back up your game."
        }
        if newerElsewhere {
            return "The backup in iCloud is from another device and further on than this game, so it isn't replaced. Restore it to carry on from there."
        }
        return "A copy of your game goes to iCloud every ten minutes or so while you play, and when you leave the app. A new iPhone can carry on from it. Steps from Apple Health stay on this iPhone."
    }

    private func restoreFromICloud() {
        do {
            pending = PendingCopy(game: try store.cloudBackup.restore(), source: "the iCloud backup")
        } catch {
            problem = Self.explanation(of: error)
        }
    }

    private func read(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pending = PendingCopy(game: try SaveTransfer.game(from: data), source: "this save file")
        } catch {
            problem = Self.explanation(of: error)
        }
    }

    private static func explanation(of error: Error) -> String {
        switch error as? SaveTransfer.ReadError {
        case .newerVersion: "It was saved by a newer version of Crypto Clicker. Update the app, then try again."
        case .unreadable: "It isn't a Crypto Clicker save, or it's damaged."
        case nil: error.localizedDescription
        }
    }
}

/// A copy of a game waiting to replace the one here, with what it holds.
private struct PendingCopy {
    let game: GameState
    /// Where it's from: "the iCloud backup", "this save file".
    let source: String

    var title: String { "Replace your game?" }

    var message: String {
        let summary = SaveTransfer.Summary(of: game)
        let prestiges = summary.prestiges == 1 ? "1 prestige" : "\(CoinFormat.grouped(summary.prestiges)) prestiges"
        return "The game in \(source) was last played \(summary.savedAt.formatted(date: .abbreviated, time: .shortened)): \(CoinFormat.short(summary.lifetimeCoins)) coins mined, \(prestiges). It replaces the game on this iPhone, which can't be undone."
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
