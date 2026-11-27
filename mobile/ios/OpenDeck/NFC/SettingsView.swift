import SwiftUI

/// NFC Toolkit settings — port of omni's `SettingsView` (Android
/// `SettingsScreen` parity), backed by `SettingsStore`.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsRow(
                        label: "Auto-open URLs",
                        description: "Automatically open URLs when scanning a tag",
                        isOn: $settings.autoOpenUrl
                    )
                    settingsRow(
                        label: "Dark mode",
                        description: "Use dark theme",
                        isOn: $settings.darkMode
                    )
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DeckTheme.surface.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func settingsRow(label: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(DeckTheme.accent)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(DeckTheme.muted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DeckTheme.accent)
        }
        .listRowBackground(DeckTheme.surfaceRaised)
    }
}
