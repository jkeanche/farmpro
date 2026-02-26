import 'dart:io';

void main() async {
  // Path to the telephony plugin's build.gradle file
  final pubCachePath = '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\hosted\\pub.dev\\telephony-0.2.0\\android\\build.gradle';
  
  try {
    final file = File(pubCachePath);
    
    if (!file.existsSync()) {
      print('Telephony plugin not found at: $pubCachePath');
      return;
    }
    
    String content = await file.readAsString();
    
    // Check if namespace is already defined
    if (content.contains('namespace')) {
      print('Namespace is already defined in the plugin.');
      return;
    }
    
    // Add namespace to the android block
    content = content.replaceFirst(
      'android {',
      'android {\n    namespace "com.shounakmulay.telephony"'
    );
    
    // Write the modified content back to the file
    await file.writeAsString(content);
    
    print('Successfully added namespace to telephony plugin.');
  } catch (e) {
    print('Error fixing telephony plugin: $e');
  }
} 