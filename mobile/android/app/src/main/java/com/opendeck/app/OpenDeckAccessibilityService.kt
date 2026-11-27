package com.opendeck.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/// Session focus mode (ported from omni's FocusAccessibilityService): while a
/// deck session is connected and the user has enabled focus mode, switching to
/// another app brings OpenDeck back to the foreground.
class OpenDeckAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 0
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (!SessionState.deckConnected || !FocusMode.isEnabled(this)) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName || isSystemPackage(pkg)) return

        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
        )
    }

    private fun isSystemPackage(pkg: String): Boolean =
        pkg.startsWith("com.android.systemui") ||
            pkg.startsWith("com.android.permissioncontroller") ||
            pkg.startsWith("com.google.android.permissioncontroller") ||
            pkg.startsWith("com.android.launcher") ||
            pkg.startsWith("com.google.android.apps.nexuslauncher") ||
            pkg.startsWith("com.sec.android.app.launcher")

    override fun onInterrupt() {}
}
