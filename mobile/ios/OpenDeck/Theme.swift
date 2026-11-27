import SwiftUI

/// Design tokens shared by the dashboard pages. Dark-first, matching the
/// rest of the app (`preferredColorScheme(.dark)` in `OpenDeckApp`).
enum DeckTheme {
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.96) // #3b82f6
    static let accentDim = Color(red: 0.14, green: 0.39, blue: 0.85)
    static let surface = Color(white: 0.11)
    static let surfaceRaised = Color(white: 0.15)
    static let stroke = Color(white: 0.22)
    static let muted = Color(white: 0.55)
    static let faint = Color(white: 0.38)
    static let track = Color(white: 0.2)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
}
