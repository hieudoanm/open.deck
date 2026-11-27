import Foundation

/// User defaults backed settings — port of omni's `SettingsStore`
/// (keys `auto_open_url` / `dark_mode`, same defaults). `ObservableObject`
/// instead of `@Observable` because open.deck targets iOS 16.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let autoOpenUrl = "auto_open_url"
        static let darkMode = "dark_mode"
    }

    private let defaults: UserDefaults

    /// Automatically open URLs when scanning a tag.
    @Published var autoOpenUrl: Bool {
        didSet { defaults.set(autoOpenUrl, forKey: Keys.autoOpenUrl) }
    }

    /// HUD dark theme. Defaults to true, matching Android/omni.
    @Published var darkMode: Bool {
        didSet { defaults.set(darkMode, forKey: Keys.darkMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoOpenUrl = defaults.object(forKey: Keys.autoOpenUrl) as? Bool ?? false
        darkMode = defaults.object(forKey: Keys.darkMode) as? Bool ?? true
    }
}
