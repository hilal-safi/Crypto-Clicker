import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to `defaultValue` when the key is missing or unreadable.
    /// Saves therefore survive fields being added, removed or corrupted between versions.
    func value<T: Decodable>(_ key: Key, default defaultValue: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? defaultValue
    }

    /// Decodes a `[String: V]` object into a dictionary keyed by an enum, dropping unknown keys.
    func enumKeyed<E: RawRepresentable & Hashable, V: Decodable>(_ key: Key, as _: E.Type) -> [E: V]
    where E.RawValue == String {
        let raw: [String: V] = value(key, default: [:])
        var result: [E: V] = [:]
        for (name, item) in raw {
            if let enumKey = E(rawValue: name) { result[enumKey] = item }
        }
        return result
    }

    /// Decodes a `[String]` array into a set of enum cases, dropping unknown values.
    func enumSet<E: RawRepresentable & Hashable>(_ key: Key, as _: E.Type) -> Set<E> where E.RawValue == String {
        let raw: [String] = value(key, default: [])
        return Set(raw.compactMap(E.init(rawValue:)))
    }
}

extension Dictionary where Key: RawRepresentable, Key.RawValue == String {
    /// The dictionary with enum keys replaced by their raw strings, so it encodes as a JSON object.
    var stringKeyed: [String: Value] {
        var result: [String: Value] = [:]
        for (key, value) in self { result[key.rawValue] = value }
        return result
    }
}

extension Set where Element: RawRepresentable, Element.RawValue == String {
    /// Raw values sorted for stable output.
    var sortedRawValues: [String] { map(\.rawValue).sorted() }
}

/// JSON coders configured so that non-finite numbers never make a save unreadable.
public enum GameCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return decoder
    }
}
