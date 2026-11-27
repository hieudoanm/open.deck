package com.opendeck.app

import android.content.Context

/// Shared state the accessibility service reads. Kept as a plain singleton
/// because services and the activity can't share a ViewModel.
object SessionState {
    @Volatile var deckConnected = false
}

/// "Session focus mode" preference — while enabled, leaving OpenDeck during
/// an active session brings the app back to the foreground.
object FocusMode {
    private const val PREFS = "opendeck_prefs"
    private const val KEY = "focus_mode"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY, false)

    fun set(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY, enabled).apply()
    }
}
