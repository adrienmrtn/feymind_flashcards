import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// **La clé d'envoi**, lue dans `keystore.properties` (écrit par la CI depuis les secrets) :
// sans elle, la version de publication n'est simplement pas signée, et la compilation passe.
val keystoreFile = rootProject.file("keystore.properties")
val keystore = Properties().apply {
    if (keystoreFile.exists()) load(FileInputStream(keystoreFile))
}

android {
    namespace = "com.micabo.app"
    compileSdk = 36

    defaultConfig {
        // **L'identifiant de l'app sur Google Play : définitif** une fois le premier build envoyé.
        applicationId = "com.micabo.app"
        minSdk = 26
        targetSdk = 36
        // Le numéro de build vient de la CI (un de plus à chaque envoi), comme pour TestFlight.
        versionCode = (System.getenv("MICABO_VERSION_CODE") ?: "1").toInt()
        versionName = "1.9"
        // La clé publique Android de RevenueCat (`goog_…`) : publique, l'app l'embarque. La CI
        // peut la remplacer par REVENUECAT_ANDROID_KEY.
        buildConfigField("String", "REVENUECAT_KEY", "\"${System.getenv("REVENUECAT_ANDROID_KEY")?.takeIf { it.isNotBlank() } ?: "goog_tWKnMrBUAJTiDzOnwmvfIWTQhqY"}\"")
    }

    signingConfigs {
        if (keystore.isNotEmpty()) {
            create("upload") {
                storeFile = rootProject.file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystore.isNotEmpty()) signingConfig = signingConfigs.getByName("upload")
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
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.06.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.foundation:foundation")
    // Les leçons, gardées en JSON sur le téléphone, et les réponses de Supabase.
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("androidx.core:core-splashscreen:1.0.1")
    // Les achats : Google Play Billing via RevenueCat (ajoute la permission BILLING).
    implementation("com.revenuecat.purchases:purchases:10.24.0")
}
