plugins {
    id("com.android.library")
}

android {
    // This must differ from the app's namespace, com.zulip.flutter.
    // It doesn't need to match the package of ZulipShimPlugin.
    namespace = "com.zulip.flutter.zulip_plugin"

    // This Gradle project holds only ZulipShimPlugin, which forwards to the
    // app's ZulipPlugin. The Gradle project exists only because the Flutter
    // Gradle plugin expects every Flutter plugin to have one.

    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
