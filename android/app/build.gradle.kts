import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Properties
import javax.inject.Inject
import org.gradle.process.ExecOperations

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// ---------------------------------------------------------------------------------------------
// The native game. Every rule of Crypto Clicker lives in CryptoClickerKit (Swift, shared with the
// iPhone app). android/swift wraps it for Android, and the task below builds that package with the
// Swift SDK for Android into libCryptoClickerJNI.so for each ABI, next to the NDK's libc++_shared.so.
// See android/README.md for installing the toolchain.
// ---------------------------------------------------------------------------------------------

/**
 * Runs `swift build` for each Android ABI and gathers the libraries for the APK. `swift build`
 * works out what needs rebuilding itself, so the task always runs it (a no-op build takes seconds).
 */
abstract class SwiftAndroidBuild : DefaultTask() {
    /** The Swift package to build (android/swift). */
    @get:Internal
    abstract val packageDir: DirectoryProperty

    /** Android ABIs: arm64-v8a, x86_64, armeabi-v7a. */
    @get:Input
    abstract val abis: ListProperty<String>

    /** debug or release. */
    @get:Input
    abstract val configuration: Property<String>

    /** The Swift version, e.g. 6.4.2: the host toolchain and the Swift SDK must both be this one. */
    @get:Input
    abstract val swiftVersion: Property<String>

    /** The installed Swift SDK for Android (`swift sdk list`). */
    @get:Input
    abstract val swiftSdk: Property<String>

    /** The API level in the target triple. */
    @get:Input
    abstract val apiLevel: Property<String>

    /** A `swift` to use instead of looking for the toolchain (gradle property swift.executable). */
    @get:Input
    @get:Optional
    abstract val swiftExecutable: Property<String>

    @get:Internal
    abstract val ndk: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @get:Inject
    abstract val execOperations: ExecOperations

    init {
        outputs.upToDateWhen { false }
    }

    @TaskAction
    fun build() {
        val ndkRoot = ndk.orNull?.asFile ?: throw GradleException(
            "No Android NDK found. Install \"NDK (Side by side)\" version 30 in Android Studio " +
                "(Settings > Languages & Frameworks > Android SDK > SDK Tools), or set ANDROID_NDK_HOME. " +
                "See android/README.md.",
        )
        val swift = swiftCommand()
        checkVersion(swift)
        val out = outputDir.get().asFile
        out.deleteRecursively()
        val packagePath = packageDir.get().asFile
        for (abi in abis.get()) {
            val arch = ARCHES[abi] ?: throw GradleException("Unsupported ABI $abi")
            // A folder per ABI and configuration, so each keeps its own up-to-date build.
            val scratch = File(packagePath, ".build-android/$abi-${configuration.get()}")
            val args = listOf(
                "build",
                "--package-path", packagePath.absolutePath,
                "--scratch-path", scratch.absolutePath,
                "--manifest-cache", "local",
                "--swift-sdk", swiftSdk.get(),
                "--triple", "$arch-unknown-linux-android${apiLevel.get()}",
                "--static-swift-stdlib",
                "-c", configuration.get(),
                "--product", "CryptoClickerJNI",
                // Google Play requires native libraries aligned for 16 KB memory pages.
                "-Xlinker", "-z", "-Xlinker", "max-page-size=16384",
            )
            logger.lifecycle("Building the native game for $abi")
            logger.info(swift(args).joinToString(" "))
            runSwift(swift(args), ndkRoot)
            val library = findLibrary(swift(args + "--show-bin-path"), ndkRoot, scratch)
            val abiDir = File(out, abi).apply { mkdirs() }
            library.copyTo(File(abiDir, LIBRARY), overwrite = true)
            cxxShared(ndkRoot, abi).copyTo(File(abiDir, "libc++_shared.so"), overwrite = true)
        }
    }

    private fun runSwift(command: List<String>, ndkRoot: File, output: ByteArrayOutputStream? = null) {
        execOperations.exec {
            commandLine(command)
            environment("ANDROID_NDK_HOME", ndkRoot.absolutePath)
            environment("ANDROID_NDK_ROOT", ndkRoot.absolutePath)
            // Leaves out the kit's String Catalog, which only Apple's tools compile (see
            // CryptoClickerKit/Package.swift). The kit then uses its English text, as on Linux.
            environment("CRYPTOCLICKER_ANDROID", "1")
            if (output != null) standardOutput = output
        }
    }

    /** The library swift build made: in its bin folder, or failing that anywhere in the scratch folder. */
    private fun findLibrary(showBinPath: List<String>, ndkRoot: File, scratch: File): File {
        val binPath = ByteArrayOutputStream()
        runCatching { runSwift(showBinPath, ndkRoot, binPath) }
        val fromBinPath = binPath.toString().trim().lines().lastOrNull()?.let { File(it.trim(), LIBRARY) }
        if (fromBinPath != null && fromBinPath.isFile) return fromBinPath
        return scratch.walkTopDown()
            .filter { it.isFile && it.name == LIBRARY }
            .maxByOrNull { it.lastModified() }
            ?: throw GradleException("swift build finished, but $LIBRARY isn't under $scratch")
    }

    /**
     * How to run `swift` with the toolchain asked for (installed by swiftly or the swift.org
     * installer): a function from the arguments to the whole command line.
     */
    private fun swiftCommand(): (List<String>) -> List<String> {
        swiftExecutable.orNull?.let { swift -> return { arguments -> listOf(swift) + arguments } }
        val version = swiftVersion.get()
        val home = System.getProperty("user.home")
        val swiftlyHome = System.getenv("SWIFTLY_HOME_DIR")
        val toolchains = listOfNotNull(
            // macOS: swiftly and the swift.org installer put toolchains here.
            "$home/Library/Developer/Toolchains/swift-$version-RELEASE.xctoolchain/usr/bin/swift",
            "/Library/Developer/Toolchains/swift-$version-RELEASE.xctoolchain/usr/bin/swift",
            // Linux: swiftly.
            swiftlyHome?.let { "$it/toolchains/$version/usr/bin/swift" },
            "$home/.local/share/swiftly/toolchains/$version/usr/bin/swift",
        )
        toolchains.firstOrNull { File(it).canExecute() }?.let { swift -> return { arguments -> listOf(swift) + arguments } }
        val swiftly = listOfNotNull(
            swiftlyHome?.let { "$it/bin/swiftly" },
            "$home/.swiftly/bin/swiftly",
            "$home/.local/share/swiftly/bin/swiftly",
            "$home/.local/bin/swiftly",
            "/opt/homebrew/bin/swiftly",
            "/usr/local/bin/swiftly",
        ).firstOrNull { File(it).canExecute() }
        // swiftly picks the toolchain from an argument starting with "+".
        if (swiftly != null) return { arguments -> listOf(swiftly, "run", "swift") + arguments + "+$version" }
        return { arguments -> listOf("swift") + arguments }
    }

    /** Fails early, with what to do, when the toolchain isn't the version the Swift SDK needs. */
    private fun checkVersion(swift: (List<String>) -> List<String>) {
        val version = swiftVersion.get()
        val output = ByteArrayOutputStream()
        val result = runCatching {
            execOperations.exec {
                commandLine(swift(listOf("--version")))
                standardOutput = output
                errorOutput = output
                isIgnoreExitValue = true
            }
        }
        val text = output.toString()
        if (result.isFailure || result.getOrNull()?.exitValue != 0 || !text.contains("Swift version $version")) {
            throw GradleException(
                "The native game needs the Swift $version toolchain from swift.org (not Xcode's), with the " +
                    "matching Swift SDK for Android. Install it with: swiftly install $version, then " +
                    "swift sdk install (see android/README.md). Found: ${swift(emptyList()).joinToString(" ")} -> " +
                    (text.lines().firstOrNull { it.isNotBlank() } ?: result.exceptionOrNull()?.message ?: "nothing"),
            )
        }
    }

    /** The NDK's C++ library, which the Swift runtime needs alongside it. */
    private fun cxxShared(ndkRoot: File, abi: String): File {
        val triple = NDK_TRIPLES[abi] ?: throw GradleException("Unsupported ABI $abi")
        val prebuilt = File(ndkRoot, "toolchains/llvm/prebuilt").listFiles()?.firstOrNull { it.isDirectory }
            ?: throw GradleException("$ndkRoot doesn't look like an Android NDK")
        val library = File(prebuilt, "sysroot/usr/lib/$triple/libc++_shared.so")
        if (!library.isFile) throw GradleException("libc++_shared.so isn't in $ndkRoot for $abi")
        return library
    }

    private companion object {
        const val LIBRARY = "libCryptoClickerJNI.so"
        val ARCHES = mapOf("arm64-v8a" to "aarch64", "x86_64" to "x86_64", "armeabi-v7a" to "armv7")
        val NDK_TRIPLES = mapOf(
            "arm64-v8a" to "aarch64-linux-android",
            "x86_64" to "x86_64-linux-android",
            "armeabi-v7a" to "arm-linux-androideabi",
        )
    }
}

/** Sorts version folder names like 30.0.14904198 numerically. */
fun versionKey(name: String): String =
    name.split('.', '-').joinToString(".") { (it.toIntOrNull() ?: 0).toString().padStart(10, '0') }

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

val home: String = System.getProperty("user.home")

val androidSdkDir: File? = listOfNotNull(
    localProperties.getProperty("sdk.dir"),
    System.getenv("ANDROID_HOME"),
    System.getenv("ANDROID_SDK_ROOT"),
    "$home/Library/Android/sdk",
    "$home/Android/Sdk",
).map(::File).firstOrNull { it.isDirectory }

/** The NDK for the Swift SDK: swift.ndk, ANDROID_NDK_HOME, or the newest installed with the Android SDK. */
val ndkDir: File? = listOfNotNull(
    providers.gradleProperty("swift.ndk").orNull,
    System.getenv("ANDROID_NDK_HOME"),
    System.getenv("ANDROID_NDK_ROOT"),
).map(::File).firstOrNull { File(it, "toolchains/llvm/prebuilt").isDirectory }
    ?: androidSdkDir?.resolve("ndk")?.listFiles()
        ?.filter { File(it, "toolchains/llvm/prebuilt").isDirectory }
        ?.maxByOrNull { versionKey(it.name) }

val swiftVersionSetting: String = providers.gradleProperty("swift.version").get()
val swiftApiLevelSetting: String = providers.gradleProperty("swift.androidApiLevel").get()

/**
 * The ABIs to build: swift.abis if set; else, when Android Studio is deploying to a device, just
 * that device's; else 64-bit ARM (phones) and x86_64 (emulators on Intel, Chromebooks).
 */
val swiftAbis: List<String> = run {
    val supported = listOf("arm64-v8a", "x86_64", "armeabi-v7a")
    val requested = providers.gradleProperty("swift.abis").orNull
        ?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }
    val device = providers.gradleProperty("android.injected.build.abi").orNull
        ?.split(',')?.map { it.trim() }?.firstOrNull { it in supported }
    when {
        !requested.isNullOrEmpty() -> requested
        device != null -> listOf(device)
        else -> listOf("arm64-v8a", "x86_64")
    }
}

// Signing for Google Play uploads: android/keystore.properties (never committed). See README.md.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

android {
    namespace = "com.hilalsafi.cryptoclicker"
    compileSdk = 36
    // The same NDK the native game is built against strips and packages its libraries.
    ndkDir?.let { ndkPath = it.absolutePath }

    defaultConfig {
        // Permanent once the app is on Google Play.
        applicationId = "com.hilalsafi.cryptoclicker"
        minSdk = 26
        targetSdk = 36
        // Raise versionCode for every upload to Google Play. versionName follows the iOS app.
        versionCode = 1
        versionName = "2.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfigs.findByName("upload")?.let { signingConfig = it }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        // Native libraries stay uncompressed and 16 KB aligned in the APK.
        jniLibs.useLegacyPackaging = false
    }
}

androidComponents {
    onVariants { variant ->
        val variantName = variant.name.replaceFirstChar { it.uppercase() }
        val swiftBuild = tasks.register<SwiftAndroidBuild>("swiftBuild$variantName") {
            group = "swift"
            description = "Builds the native game (android/swift) for the ${variant.name} build."
            packageDir.set(rootProject.layout.projectDirectory.dir("swift"))
            abis.set(swiftAbis)
            configuration.set(if (variant.buildType == "release") "release" else "debug")
            swiftVersion.set(swiftVersionSetting)
            swiftSdk.set(providers.gradleProperty("swift.sdk").orElse("swift-$swiftVersionSetting-RELEASE_android"))
            apiLevel.set(swiftApiLevelSetting)
            swiftExecutable.set(providers.gradleProperty("swift.executable"))
            ndkDir?.let { ndk.set(it) }
            outputDir.set(layout.buildDirectory.dir("swift/${variant.name}/jniLibs"))
        }
        variant.sources.jniLibs?.addGeneratedSourceDirectory(swiftBuild, SwiftAndroidBuild::outputDir)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.kotlinx.coroutines.android)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    testImplementation(libs.junit)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
}
