plugins {
    id("com.android.application") version "8.5.2"
    id("org.jetbrains.kotlin.android") version "1.9.24"
}

android {
    namespace = "com.tamer.rekat"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.tamer.rekat"
        minSdk = 30 // Wear OS 3 (Galaxy Watch4+)
        targetSdk = 35 // Play: Wear OS yeni uygulama/güncelleme API 35+
        versionCode = 1
        versionName = "1.0"
    }
    // Yükleme anahtarı repoda değil: ~/.gradle/gradle.properties içindeki REKAT_* değerleri
    signingConfigs {
        create("release") {
            findProperty("REKAT_STORE_FILE")?.let { storeFile = file(it) }
            storePassword = findProperty("REKAT_STORE_PASSWORD") as String?
            keyAlias = findProperty("REKAT_KEY_ALIAS") as String?
            keyPassword = findProperty("REKAT_KEY_PASSWORD") as String?
        }
    }
    buildTypes {
        release {
            if (hasProperty("REKAT_STORE_FILE")) signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("androidx.wear.tiles:tiles:1.4.1")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("com.google.guava:guava:33.3.1-android")
}
