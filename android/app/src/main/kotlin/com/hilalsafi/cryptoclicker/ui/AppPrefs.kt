package com.hilalsafi.cryptoclicker.ui

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** How the player likes the app (iOS: Preferences in UserDefaults). The game itself is in the save. */
class AppPrefs(context: Context) {
    private val store = context.getSharedPreferences("preferences", Context.MODE_PRIVATE)

    private val _appearance = MutableStateFlow(Appearance.of(store.getString(APPEARANCE, null)))
    /** Light, dark, or the system's choice. */
    val appearance: StateFlow<Appearance> = _appearance.asStateFlow()

    private val _exactNumbers = MutableStateFlow(store.getBoolean(EXACT_NUMBERS, false))
    /** Every digit of the balance instead of the short form. Tapping the balance switches. */
    val exactNumbers: StateFlow<Boolean> = _exactNumbers.asStateFlow()

    private val _haptics = MutableStateFlow(store.getBoolean(HAPTICS, true))
    val haptics: StateFlow<Boolean> = _haptics.asStateFlow()

    fun setAppearance(value: Appearance) {
        _appearance.value = value
        store.edit().putString(APPEARANCE, value.key).apply()
    }

    fun setExactNumbers(value: Boolean) {
        _exactNumbers.value = value
        store.edit().putBoolean(EXACT_NUMBERS, value).apply()
    }

    fun setHaptics(value: Boolean) {
        _haptics.value = value
        store.edit().putBoolean(HAPTICS, value).apply()
    }

    private companion object {
        const val APPEARANCE = "appearance"
        const val EXACT_NUMBERS = "exactNumbers"
        const val HAPTICS = "haptics"
    }
}
