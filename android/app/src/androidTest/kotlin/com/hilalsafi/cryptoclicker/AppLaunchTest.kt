package com.hilalsafi.cryptoclicker

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Opens the app as a player would: the coin appears, it can be tapped, and the Shop opens. */
@RunWith(AndroidJUnit4::class)
class AppLaunchTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun opensTheMineAndTheShop() {
        compose.waitUntil(timeoutMillis = 20_000) {
            compose.onAllNodesWithContentDescription("Mine coin").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithContentDescription("Mine coin").performClick()
        compose.onNodeWithText("Shop").performClick()
        compose.waitUntil(timeoutMillis = 10_000) {
            compose.onAllNodesWithText("Miners").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Settings").performClick()
        compose.waitUntil(timeoutMillis = 10_000) {
            compose.onAllNodesWithText("Reset All Progress").fetchSemanticsNodes().isNotEmpty()
        }
    }
}
