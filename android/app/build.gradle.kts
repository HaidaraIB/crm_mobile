plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

// Check if keystore file exists (file() is relative to project root, which is android/ directory)
val keystoreFileExists = keystoreProperties?.let { props ->
    val storeFilePath = props["storeFile"] ?: ""
    if (storeFilePath.isNotEmpty()) {
        // Try app directory first (most common location)
        val keystoreFile = file("app/$storeFilePath")
        if (keystoreFile.exists()) {
            true
        } else {
            // Try project root
            file(storeFilePath).exists()
        }
    } else {
        false
    }
} ?: false

android {
    namespace = "com.example.crm_mobile"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.crm_mobile"
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
                    val storeFilePath = props["storeFile"] ?: ""
                    if (storeFilePath.isNotEmpty()) {
                        // Try app directory first, then project root
                        val keystoreFile = file("app/$storeFilePath")
                        storeFile = if (keystoreFile.exists()) {
                            keystoreFile
                        } else {
                            file(storeFilePath)
                        }
                    }
                    storePassword = props["storePassword"] ?: ""
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreFileExists && keystoreProperties != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
