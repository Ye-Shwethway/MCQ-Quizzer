import java.util.Properties

plugins {
    id("com.android.application")
    // AGP owns Kotlin compilation; do not apply the legacy Kotlin Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadSigningPropertiesFile = rootProject.file("key.properties")
val uploadSigningProperties = Properties().apply {
    if (uploadSigningPropertiesFile.exists()) {
        uploadSigningPropertiesFile.inputStream().use { input -> load(input) }
    }
}

fun uploadSigningValue(propertyName: String, environmentName: String): String? =
    uploadSigningProperties.getProperty(propertyName)?.trim()?.takeIf(String::isNotEmpty)
        ?: System.getenv(environmentName)?.trim()?.takeIf(String::isNotEmpty)

val uploadStoreFile = uploadSigningValue("storeFile", "MCQ_UPLOAD_STORE_FILE")
val uploadStorePassword = uploadSigningValue("storePassword", "MCQ_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = uploadSigningValue("keyAlias", "MCQ_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = uploadSigningValue("keyPassword", "MCQ_UPLOAD_KEY_PASSWORD")
val uploadSigningConfigured = listOf(
    uploadStoreFile,
    uploadStorePassword,
    uploadKeyAlias,
    uploadKeyPassword,
).all { it != null }

val releaseArtifactRequested = gradle.startParameter.taskNames.any { requestedTask ->
    requestedTask.substringAfterLast(':').matches(
        Regex("(?:assemble|bundle|package).*Release", RegexOption.IGNORE_CASE),
    )
}

if (releaseArtifactRequested && !uploadSigningConfigured) {
    throw GradleException(
        "Release signing is not configured. Provide ignored android/key.properties " +
            "or MCQ_UPLOAD_* environment variables; see android/key.properties.example.",
    )
}

if (releaseArtifactRequested && !rootProject.file(uploadStoreFile!!).isFile) {
    throw GradleException("The configured release upload keystore file does not exist.")
}

android {
    namespace = "com.thorne.mcqquizzer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.thorne.mcqquizzer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // The upload key signs the AAB sent to Play; Google Play App Signing
            // holds the distinct app-signing key used for distributed APKs.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
