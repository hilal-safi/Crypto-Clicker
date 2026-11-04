import Foundation

// The kit's text for players (names, rules, quests, achievements) comes from its own String
// Catalog, `Resources/Localizable.xcstrings`, so the game can be translated without touching
// the code: Xcode adds every `localized("…")` to the catalog when it builds, values marked
// where they go ("Win %lld hands", "Clear %@ lines"), and translations are added there.
//
// Elsewhere (the tests on Linux, the WebAssembly check) there's no catalog, and the text is the
// English as written. Numbers go in as whole numbers or as text already formatted (CoinFormat),
// never as a `Double`, which a catalog would print with six decimals.

#if canImport(Darwin)
/// The text in the player's language, from the kit's String Catalog.
func localized(_ value: String.LocalizationValue) -> String {
    #if SWIFT_PACKAGE
    String(localized: value, bundle: .module)
    #else
    String(localized: value)
    #endif
}
#else
/// The text as written: there's no String Catalog here.
func localized(_ value: String) -> String { value }
#endif
