import AppKit
import ApplicationServices
import CoreGraphics

/// Opens the relevant macOS System Settings privacy pane.
enum PermissionHelper {
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// True when the process can record the screen (prompt already granted or denied).
    static var screenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// True when the process is trusted for Accessibility (input injection).
    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }
}
