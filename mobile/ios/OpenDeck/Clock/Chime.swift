import AudioToolbox
import UIKit

/// Completion chimes for the Clock pages — system sounds stand in for the
/// macOS `NSSound` Glass/Basso pair used by omni.
enum Chime {
    /// Timer finished, or a work phase ended.
    static func workPhaseEnded() {
        AudioServicesPlaySystemSound(1007) // Tink
    }

    /// A break phase ended.
    static func breakPhaseEnded() {
        AudioServicesPlaySystemSound(1054) // Hero
    }

    static func timerFinished() {
        AudioServicesPlaySystemSound(1007)
    }
}
