// The native methods of `com.hilalsafi.cryptoclicker.core.NativeBridge` (Kotlin).
//
// Requests and responses cross as UTF-8 bytes rather than Java strings: JNI's string functions use
// "modified UTF-8", which can't carry the emoji the game shows (they are outside the Basic
// Multilingual Plane), so bytes keep every character intact.

#if os(Android)
import Android
import Foundation
import CryptoClickerBridge

/// `NativeBridge.call(request: ByteArray): ByteArray?`: one JSON request, one JSON response.
@_cdecl("Java_com_hilalsafi_cryptoclicker_core_NativeBridge_call")
public func NativeBridge_call(
    _ env: UnsafeMutablePointer<JNIEnv?>,
    _ clazz: jclass?,
    _ request: jbyteArray?
) -> jbyteArray? {
    guard let request, let jni = env.pointee?.pointee else { return nil }
    let length = jni.GetArrayLength(env, request)
    var bytes = [jbyte](repeating: 0, count: Int(max(0, length)))
    if length > 0 {
        jni.GetByteArrayRegion(env, request, 0, length, &bytes)
    }
    let requestData = bytes.withUnsafeBytes { Data($0) }

    let response = Bridge.handle(requestData)

    let count = jsize(response.count)
    guard let result = jni.NewByteArray(env, count) else { return nil } // Out of memory: Java throws.
    if count > 0 {
        response.withUnsafeBytes { raw in
            jni.SetByteArrayRegion(env, result, 0, count, raw.bindMemory(to: jbyte.self).baseAddress)
        }
    }
    return result
}
#endif
