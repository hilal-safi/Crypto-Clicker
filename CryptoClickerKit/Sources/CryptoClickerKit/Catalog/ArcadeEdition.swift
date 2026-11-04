import Foundation

/// The arcade's two looks. The crypto edition, the default, makes every game a crypto game of its
/// own: Block Chain, Merge Mining, Hash Chain, Hash Smash, Bubble Market, 21 Million and Diamond
/// Hands, with crypto names for their pieces and power-ups, crypto pictures, and a few rules of
/// their own (Block Chain's shorter well and gas spikes, Scam Invaders' server racks). The classic
/// edition brings the games back as they were, so the two can be compared (Testing Tools).
///
/// Only names, looks and those few rules change: records, quests, challenges and rewards are the
/// same in both.
public enum ArcadeEdition: String, CaseIterable, Codable, Sendable {
    case crypto, classic

    /// The edition on screen. The app sets it at launch and when the testing switch changes; the
    /// rest of the code only reads it, for names and pictures. Engines never do: the app hands each
    /// game its rules (see `TetrisGame.Rules`, `InvadersGame.FirewallStyle`), so tests can play
    /// either edition side by side.
    nonisolated(unsafe) public static var current: ArcadeEdition = .crypto

    /// `crypto` in the crypto edition, `classic` in the classic one.
    public func pick<Value>(_ crypto: Value, classic: Value) -> Value {
        self == .classic ? classic : crypto
    }

    /// `crypto` in the edition on screen, `classic` in the classic one.
    public static func pick<Value>(_ crypto: Value, classic: Value) -> Value {
        current.pick(crypto, classic: classic)
    }

    public var name: String {
        switch self {
        case .crypto: localized("Crypto")
        case .classic: localized("Classic")
        }
    }
}
