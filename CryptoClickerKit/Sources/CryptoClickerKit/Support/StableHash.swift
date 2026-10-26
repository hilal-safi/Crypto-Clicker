import Foundation

/// A hash that is the same on every launch and device (unlike `hashValue`), for seeding daily
/// quests, the daily challenge and market prices.
enum StableHash {
    /// 64-bit FNV-1a of the string's UTF-8 bytes.
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// The bits of a date, so a moment can seed a hash without converting it to an integer.
    static func of(_ date: Date) -> UInt64 {
        date.timeIntervalSinceReferenceDate.bitPattern
    }

    /// Mixes several numbers into one well-spread 64-bit value.
    static func mix(_ values: UInt64...) -> UInt64 {
        var z: UInt64 = 0x9E37_79B9_7F4A_7C15
        for value in values {
            z ^= value &+ 0x9E37_79B9_7F4A_7C15 &+ (z << 6) &+ (z >> 2)
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
        }
        return z
    }

    /// A number in `0..<1` from a mixed value.
    static func unit(_ value: UInt64) -> Double {
        Double(value >> 11) / Double(UInt64(1) << 53)
    }
}
