import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.rosexlab.kitchenassistant"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion // Original line removed/commented out
    ndkVersion = "27.0.12077973"      // Updated to specific required version

    compileOptions {
        // Correctly set to Java 11
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        // Correctly set to Java 11
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rosexlab.kitchenassistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

     signingConfigs {
         create("release") {
             keyAlias = keystoreProperties["keyAlias"] as String
             keyPassword = keystoreProperties["keyPassword"] as String
             storeFile = keystoreProperties["storeFile"]?.let { file(it) }
             storePassword = keystoreProperties["storePassword"] as String
         }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
           // signingConfig = signingConfigs.getByName("debug")
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// Optional: Add dependencies block if not present and needed, but usually Flutter handles this.
// dependencies {
//    implementation(kotlin("stdlib-jdk8"))
// }
