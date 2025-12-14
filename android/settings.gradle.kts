pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")

        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }

        properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
            ?: error("Flutter SDK not found. Set flutter.sdk in local.properties or FLUTTER_ROOT")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "predicted_app"
include(":app")
