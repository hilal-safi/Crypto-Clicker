package com.hilalsafi.cryptoclicker.core

/**
 * The native game: `libCryptoClickerJNI.so`, which the Gradle build compiles from `android/swift`
 * (the shared CryptoClickerKit plus the bridge) for each Android ABI.
 */
object NativeBridge {
    init {
        // The Swift runtime is linked into the library statically; it needs the NDK's C++ library.
        System.loadLibrary("c++_shared")
        System.loadLibrary("CryptoClickerJNI")
    }

    /** One JSON request in, one JSON response out, as UTF-8 bytes. */
    @JvmStatic
    external fun call(request: ByteArray): ByteArray?
}

/** Sends JSON requests to the game and returns its JSON responses. */
fun interface GameEngine {
    fun call(request: String): String
}

/** The real game, in Swift. */
class NativeEngine : GameEngine {
    override fun call(request: String): String =
        NativeBridge.call(request.encodeToByteArray())?.decodeToString()
            ?: throw IllegalStateException("The game returned nothing")
}
