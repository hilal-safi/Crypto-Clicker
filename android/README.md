# Crypto Clicker for Android

The Google Play version of Crypto Clicker. It plays the same game as the iPhone app, because it runs
the same code: every rule lives in `CryptoClickerKit` (Swift), which is compiled for Android with the
official Swift SDK for Android. The screens are Jetpack Compose (Kotlin).

```
CryptoClickerKit/            the game's rules, shared with iPhone and Apple Watch (unchanged)
android/
  swift/                     the bridge: CryptoClickerKit + GameSession, built into libCryptoClickerJNI.so
    Sources/CryptoClickerBridge/GameSession.swift   mirrors the iOS GameStore, method by method
    Sources/CryptoClickerBridge/Views.swift         what each screen shows, worded as on iOS
    Sources/CryptoClickerBridge/Bridge.swift        JSON in, JSON out
    Sources/CryptoClickerJNI/JNI.swift              the one JNI entry point
  contract/response.json     every key the bridge can send; tested from both sides
  app/                       the Android app (Kotlin + Compose)
```

A tap travels like this: the Compose screen → `GameController` (Kotlin) → JSON →
`libCryptoClickerJNI.so` → `GameSession` (Swift) → `CryptoClickerKit`, and the answer comes back the
same way. Numbers and text are formatted in Swift (`CoinFormat`), so both apps show `12.3K`, `×2`
and `3h 4m` identically. The save is `game.json` in the iPhone app's format.

The iPhone app is unchanged. The only shared file touched is `CryptoClickerKit/Package.swift`, which
skips the String Catalog when the Android build asks it to (`CRYPTOCLICKER_ANDROID`); Xcode builds
exactly as before.

## What's in the Android app so far

- **Mine**: the balance (tap it for every digit), coins per second and per tap, the coin with
  floating `+value`s, the combo, the Bull Run.
- **Shop**: miners with ×1/×10/×100/Max, best value, milestones, Legacy and Mk upgrades; Offline
  Mining; the combo power-ups; upgrades and the purchased list; the purchase popup.
- **Welcome back**: what the miners earned while the app was closed, the best buy, and the
  breakdown.
- **Toasts** for achievements, quests paid and the daily challenge.
- **Settings**: theme, number format, haptics, version, reset; Testing Tools in debug builds.

The Arcade and Trophies tabs say they're coming. Not ported yet: the arcade and casino, trophies and
quests screens, prestige and perks, tokens, airdrops, steps (Health Connect), notifications and
widgets.

## One-time setup on your Mac

1. **Android Studio** (the current stable release) from <https://developer.android.com/studio>.
   Open *Settings > Languages & Frameworks > Android SDK* and install:
   - *SDK Platforms*: Android 16 (API 36)
   - *SDK Tools*: **NDK (Side by side)** version 30 (tick *Show Package Details* to pick it), and
     Android SDK Command-line Tools

2. **Swift 6.4.2 from swift.org**, with swiftly. Xcode's Swift can't build for Android, and this
   doesn't change Xcode: it keeps its own Swift, and the iPhone app builds as before.

   ```sh
   curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg
   installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
   ~/.swiftly/bin/swiftly init --quiet-shell-followup
   . "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh" && hash -r
   swiftly install 6.4.2
   ```

   (`swiftly use xcode` puts Terminal's `swift` back to Xcode's if you prefer; the Android build
   finds 6.4.2 on its own.)

3. **The Swift SDK for Android**, matching that toolchain:

   ```sh
   swiftly run swift sdk install https://download.swift.org/swift-6.4.2-release/android-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_android.artifactbundle.tar.gz --checksum 4d6ad63ea74becd58e123ff58b1b48c3be5ec0db0dff0ea5abe37ac007dd3233 +6.4.2
   swiftly run swift sdk list +6.4.2    # shows swift-6.4.2-RELEASE_android
   ```

That's all. Gradle compiles the Swift game itself whenever you build the app.

## Testing on your phone (the Xcode → iPhone way)

1. On the phone, open *Settings > About phone* and tap *Build number* seven times. Then in
   *Settings > System > Developer options*, turn on **USB debugging** (and **Wireless debugging**
   if you'd rather not use a cable).
2. Plug the phone in and accept *Allow USB debugging?*. Over Wi-Fi instead: in Android Studio open
   *Device Manager > Pair Devices Using Wi-Fi* and scan the code from *Wireless debugging* on the
   phone.
3. In Android Studio, *File > Open* the **`android`** folder (not the repository root). Let Gradle sync.
4. Pick the phone in the device menu at the top and press **Run** (▶, or Ctrl-R).

The first build compiles the Swift game for your phone's processor and takes a few minutes; after
that only what changed is rebuilt. **Logcat** is Xcode's console. Debug builds have the **Testing
Tools** at the bottom of Settings (coins, miners, upgrades, Offline Mining, Bull Run, "pretend I was
away"), like the iPhone's Testing Tools in builds run from Xcode; Google Play builds leave them out.

### The emulator (the iOS Simulator)

*Device Manager > +* > a Pixel phone with an Android 16 (API 36) **arm64-v8a** system image (on an
Intel Mac, x86_64). Then press Run with it selected.

### Without Android Studio

- With the phone connected: `cd android && ./gradlew installDebug`.
- From GitHub: every push runs **Actions > Android**, which uploads `crypto-clicker-debug-apk`. Download
  it and run `adb install -r app-debug.apk`, or open the APK on the phone (it asks to allow installing
  from that app the first time).

### Friends and family: Google Play testing (the TestFlight way)

Upload a build to the **Internal testing** track in Play Console and add testers by email: it reaches
them in minutes, through the Play Store, with updates like any app. See *Releasing* below.

## Tests

| What | Command | Runs on |
| --- | --- | --- |
| JSON, the contract, `GameController` | `cd android && ./gradlew testDebugUnitTest` | your Mac (JVM) |
| The native game and the UI on Android | `cd android && ./gradlew connectedDebugAndroidTest` | a phone or emulator |
| The bridge (`GameSession`, JSON, contract) | `swift test --package-path android/swift` | your Mac |
| The game's rules | `swift test --package-path CryptoClickerKit` | your Mac |

GitHub Actions (`.github/workflows/android.yml`) runs all of these on every push to `android` (and
on pull requests touching it), runs the kit's and the bridge's tests again on an Android emulator,
checks the native libraries are 16 KB aligned, and builds the Google Play bundle.

## Keeping iPhone and Android the same game

- **Rules** belong in `CryptoClickerKit`. Change them once and both apps have the change.
- **What happens around the rules** (catching up after time away, autosave, toasts, the combo, the
  purchase popup) is in `GameSession.swift`, which mirrors `Crypto Clicker/App/GameStore.swift`
  method by method. When `GameStore` changes, make the same change there.
- **Wording** shown on Android is built in `Views.swift` with the iPhone app's English. New fields go
  in the Swift view, the Kotlin model (`core/Models.kt`) and `contract/response.json`; the tests on
  both sides fail if the three disagree.

## Releasing on Google Play

1. **Create the upload key** once, and keep it safe (with a backup):

   ```sh
   keytool -genkeypair -v -keystore ~/crypto-clicker-upload.jks -alias upload \
     -keyalg RSA -keysize 4096 -validity 10000
   ```

   Then create `android/keystore.properties` (it's in `.gitignore`; never commit it):

   ```properties
   storeFile=/Users/you/crypto-clicker-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

2. **Raise `versionCode`** in `app/build.gradle.kts` for every upload (`versionName` follows the iPhone
   app's version).
3. **Build the bundle**: `cd android && ./gradlew bundleRelease`, which makes
   `app/build/outputs/bundle/release/app-release.aab`.
4. In **Play Console**, create the app (package `com.hilalsafi.cryptoclicker`, which is permanent) and
   keep **Play App Signing** on: Google holds the app's signing key, you keep the upload key.
5. Upload the bundle to **Internal testing** first and try it on your phone.
6. A **personal developer account created after 13 November 2023** must run a **closed test with at
   least 12 testers opted in for 14 days in a row** before it can apply for production. Organization
   accounts don't.
7. Fill in the store listing and *App content*:
   - Icon: `android/play/icon-512.png`. You'll also need a 1024 × 500 feature graphic and at least
     two phone screenshots.
   - Privacy policy: the same URL as the App Store listing.
   - Data safety: the app collects and shares no data and has no internet access. (Android's own
     backup of the save to the player's Google account isn't collection by you.)
   - Content rating: no gambling in this version. When the Arcade's casino games come to Android,
     answer yes to simulated gambling.
   - Ads: none.

The app targets Android 16 (API 36) and its native libraries are aligned for 16 KB pages, as Google
Play requires.

## When something goes wrong

- *"The native game needs the Swift 6.4.2 toolchain from swift.org"*: install it with swiftly (setup
  step 2). If it's somewhere unusual, set `swift.executable=/path/to/usr/bin/swift` in
  `~/.gradle/gradle.properties`.
- *"No Android NDK found"*: install NDK 30 (setup step 1), or set `ANDROID_NDK_HOME`.
- *No Swift SDK for Android* (`swift build` can't find `swift-6.4.2-RELEASE_android`): setup step 3.
- To build the native game for chosen processors only: `./gradlew assembleDebug -Pswift.abis=arm64-v8a`.
  Android Studio already builds just your device's when you press Run.
