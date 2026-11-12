// Android Gradle plugin 9 compiles Kotlin itself ("built-in Kotlin"). It runs on the Kotlin Gradle
// plugin found here, which must match the Compose compiler plugin (libs.versions.toml: kotlin).
buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.10")
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
