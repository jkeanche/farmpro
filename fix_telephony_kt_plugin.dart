import 'dart:io';

void main() async {
  // Check if the kotlin version of the file exists
  final pubCachePath = '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\hosted\\pub.dev\\telephony-0.2.0\\android\\build.gradle.kts';
  
  try {
    final file = File(pubCachePath);
    
    if (!file.existsSync()) {
      print('Telephony Kotlin build file not found at: $pubCachePath');
      
      // Create the kotlin version with proper syntax
      final gradlePath = '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\hosted\\pub.dev\\telephony-0.2.0\\android\\build.gradle';
      final gradleFile = File(gradlePath);
      
      if (!gradleFile.existsSync()) {
        print('Telephony plugin not found at: $gradlePath');
        return;
      }
      
      // Create a proper kotlin DSL version of the build file
      final kotlinContent = '''
plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.shounakmulay.telephony"
    compileSdk = 33
    
    defaultConfig {
        minSdk = 16
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.10")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core-ktx:1.10.1")
}
''';
      
      // Create kotlin dsl version
      final ktFile = File('$gradlePath.kts');
      await ktFile.writeAsString(kotlinContent);
      
      print('Successfully created Kotlin DSL version of the build file.');
    } else {
      String content = await file.readAsString();
      
      // Update content if needed
      content = content.replaceAll('compileSdkVersion', 'compileSdk =');
      content = content.replaceAll('minSdkVersion', 'minSdk =');
      
      // Add namespace if missing
      if (!content.contains('namespace')) {
        content = content.replaceFirst(
          'android {',
          'android {\n    namespace = "com.shounakmulay.telephony"'
        );
      }
      
      // Write updated content
      await file.writeAsString(content);
      
      print('Successfully updated the Kotlin DSL build file.');
    }
  } catch (e) {
    print('Error fixing telephony plugin Kotlin DSL: $e');
  }
} 