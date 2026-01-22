plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

import java.io.File

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = if (keystorePropertiesFile.exists()) {
    try {
        val propsMap = mutableMapOf<String, String>()
        keystorePropertiesFile.readLines().forEach { line ->
            if (line.contains("=") && !line.trimStart().startsWith("#")) {
                val parts = line.split("=", limit = 2)
                if (parts.size == 2) {
                    propsMap[parts[0].trim()] = parts[1].trim()
                }
            }
        }
        propsMap
    } catch (e: Exception) {
        null
    }
} else {
    null
}

// Check if keystore file exists.
// NOTE: This script runs in the :app module (android/app). The keystore is typically stored in android/.
val keystoreFileExists = keystoreProperties?.let { props ->
    val storeFilePath = (props["storeFile"] ?: "").trim()
    if (storeFilePath.isEmpty()) return@let false

    val storeFileCandidate: File = run {
        val f = File(storeFilePath)
        when {
            f.isAbsolute -> f
            else -> rootProject.file(storeFilePath) // relative to android/
        }
    }
    storeFileCandidate.exists()
} ?: false

android {
    namespace = "com.loopcrm.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID for Google Play Store
        applicationId = "com.loopcrm.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (keystoreFileExists && keystoreProperties != null) {
            create("release") {
                keystoreProperties?.let { props ->
                    keyAlias = props["keyAlias"] ?: ""
                    keyPassword = props["keyPassword"] ?: ""
                    val storeFilePath = (props["storeFile"] ?: "").trim()
                    if (storeFilePath.isNotEmpty()) {
                        val storeFileCandidate: File = run {
                            val f = File(storeFilePath)
                            when {
                                f.isAbsolute -> f
                                else -> rootProject.file(storeFilePath) // relative to android/
                            }
                        }
                        storeFile = storeFileCandidate
                    }
                    storePassword = props["storePassword"] ?: ""
                }
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to debug signing for release builds.
            if (!(keystoreFileExists && keystoreProperties != null)) {
                throw GradleException(
                    "Release signing is not configured. Ensure android/key.properties exists " +
                        "and points to a valid keystore file (e.g. android/crm-release-key.jks)."
                )
            }
            signingConfig = signingConfigs.getByName("release")
            // Enable code shrinking and obfuscation for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core:1.12.0")
    implementation("androidx.core:core-ktx:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:-options")
    // Ensure Java 17 is used
    sourceCompatibility = "17"
    targetCompatibility = "17"
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
