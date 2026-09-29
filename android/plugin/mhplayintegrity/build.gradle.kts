plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.mulliganhills.playintegrity"
    compileSdk = 36            // must be >= the game's target SDK (36 required for new apps from 2026-08-31)
    defaultConfig {
        minSdk = 24            // must be <= the game's minSdk (set in the export preset)
        consumerProguardFiles("consumer-rules.pro")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    // Godot's Android library, provided by the engine at runtime -> compileOnly.
    // Option A (preferred, exact match to your engine): download godot-lib.<version>.template_release.aar
    // from the Godot release page (see docs/GODOT_VERSION.md) and put it in plugin/mhplayintegrity/libs/.
    compileOnly(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))
    // Option B: Maven Central `org.godotengine:godot:<version>.stable` (UNVERIFIED coordinates/availability).
    // compileOnly("org.godotengine:godot:4.4.1.stable")

    // Play Integrity API. VERSION UNVERIFIED: check
    // https://developer.android.com/google/play/integrity/reference/com/google/android/play/core/release-notes
    implementation("com.google.android.play:integrity:1.4.0")
}
