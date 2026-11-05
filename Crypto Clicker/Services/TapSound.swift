import AudioToolbox

/// The short system "tock" played on each tap when sounds are enabled.
enum TapSound {
    static func play() {
        AudioServicesPlaySystemSound(1104)
    }
}
