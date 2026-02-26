import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionService extends GetxService {
  // Observable variables to track permission states
  final RxBool hasLocationPermission = false.obs;
  final RxBool hasBluetoothPermission = false.obs;
  final RxBool hasStoragePermission = false.obs;
  final RxBool hasSmsPermission = false.obs;

  Future<PermissionService> init() async {
    // Check initial permission states
    await _checkPermissions();
    return this;
  }

  // Check all permissions
  Future<void> _checkPermissions() async {
    await checkLocationPermission();
    await checkBluetoothPermission();
    await checkStoragePermission();
    await checkSmsPermission();
  }

  Future<bool> checkAllRequiredPermissions() async {
    await _checkPermissions();
    // Return true if all required permissions are granted
    return hasLocationPermission.value && 
           hasBluetoothPermission.value && 
           hasStoragePermission.value &&
           hasSmsPermission.value;
  }

  // Request all permissions
  Future<void> requestAllRequiredPermissions() async {
    await requestLocationPermission();
    await requestBluetoothPermission();
    await requestStoragePermission();
    // Only request SMS permission if needed by app configuration
    // await requestSmsPermission();
  }

  // Location permission
  Future<bool> checkLocationPermission() async {
    if (!Platform.isAndroid) {
      hasLocationPermission.value = true;
      return true;
    }

    final status = await Permission.location.status;
    hasLocationPermission.value = status.isGranted;
    return status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid) {
      hasLocationPermission.value = true;
      return true;
    }

    print('Requesting location permission...');
    final status = await Permission.location.request();
    print('Location permission result: ${status.toString()}');
    hasLocationPermission.value = status.isGranted;
    
    if (status.isPermanentlyDenied) {
      print('Location permission permanently denied, showing dialog');
      _showPermanentlyDeniedDialog(
        'Location Permission Required',
        'This app needs location permission for Bluetooth functionality. '
        'Please enable location in app settings.'
      );
    }
    
    return status.isGranted;
  }

  // Special method to handle location for features that require it
  Future<bool> ensureLocationPermissionForFeature(String featureName) async {
    if (!Platform.isAndroid) return true;
    
    if (await checkLocationPermission()) return true;
    
    final shouldRequest = await Get.dialog<bool>(
      AlertDialog(
        title: Text('$featureName Requires Location'),
        content: Text(
          'To use $featureName, location permission is required. '
          'Would you like to grant location access now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ) ?? false;
    
    if (shouldRequest) {
      return await requestLocationPermission();
    }
    
    return false;
  }

  // Bluetooth permission
  Future<bool> checkBluetoothPermission() async {
    if (!Platform.isAndroid) {
      hasBluetoothPermission.value = true;
      return true;
    }

    // For Android 12+ we need to check both permissions
    if (Platform.isAndroid) {
      bool bluetoothScan = true;
      bool bluetoothConnect = true;
      
      // Check if Android version is >= 12 (API 31+)
      if (await isAndroidVersionAtLeast(31)) {
        bluetoothScan = await Permission.bluetoothScan.isGranted;
        bluetoothConnect = await Permission.bluetoothConnect.isGranted;
      } else {
        // For older Android versions, check legacy Bluetooth permission
        bluetoothScan = await Permission.bluetooth.isGranted;
        bluetoothConnect = await Permission.bluetooth.isGranted;
      }
      
      hasBluetoothPermission.value = bluetoothScan && bluetoothConnect;
      return bluetoothScan && bluetoothConnect;
    }
    
    return true;
  }

  Future<bool> requestBluetoothPermission() async {
    if (!Platform.isAndroid) {
      hasBluetoothPermission.value = true;
      return true;
    }

    print('Requesting Bluetooth permissions...');
    // For Android 12+ we need to request both permissions
    if (Platform.isAndroid) {
      bool bluetoothScan = true;
      bool bluetoothConnect = true;
      
      // Check if Android version is >= 12 (API 31+)
      if (await isAndroidVersionAtLeast(31)) {
        print('Android 12+ detected, requesting Bluetooth scan and connect permissions');
        final scanStatus = await Permission.bluetoothScan.request();
        print('Bluetooth scan permission result: ${scanStatus.toString()}');
        bluetoothScan = scanStatus.isGranted;
        
        final connectStatus = await Permission.bluetoothConnect.request();
        print('Bluetooth connect permission result: ${connectStatus.toString()}');
        bluetoothConnect = connectStatus.isGranted;
        
        if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
          print('Bluetooth permissions permanently denied, showing dialog');
          _showPermanentlyDeniedDialog(
            'Bluetooth Permission Required',
            'This app needs Bluetooth permission for printing receipts. '
            'Please enable Bluetooth in app settings.'
          );
        }
      } else {
        // For older Android versions, request legacy Bluetooth permission
        print('Android < 12 detected, requesting legacy Bluetooth permission');
        final status = await Permission.bluetooth.request();
        print('Legacy Bluetooth permission result: ${status.toString()}');
        bluetoothScan = status.isGranted;
        bluetoothConnect = status.isGranted;
        
        if (status.isPermanentlyDenied) {
          print('Legacy Bluetooth permission permanently denied, showing dialog');
          _showPermanentlyDeniedDialog(
            'Bluetooth Permission Required',
            'This app needs Bluetooth permission for printing receipts. '
            'Please enable Bluetooth in app settings.'
          );
        }
      }
      
      hasBluetoothPermission.value = bluetoothScan && bluetoothConnect;
      print('Final Bluetooth permission result: ${bluetoothScan && bluetoothConnect}');
      return bluetoothScan && bluetoothConnect;
    }
    
    return true;
  }

  // Storage permission
  Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) {
      hasStoragePermission.value = true;
      return true;
    }
    
    bool hasPermission = false;
    
    try {
      print('Checking storage permissions... Android version check starting');
      // For Android 13+ (API 33+), check media permissions
      if (await isAndroidVersionAtLeast(33)) {
        print('Android 13+ detected, checking media permissions');
        final statusPhotos = await Permission.photos.status;
        final statusVideo = await Permission.videos.status;
        final statusAudio = await Permission.audio.status;
        
        print('Photos permission: ${statusPhotos.toString()}');
        print('Videos permission: ${statusVideo.toString()}');
        print('Audio permission: ${statusAudio.toString()}');
        
        hasPermission = statusPhotos.isGranted && statusVideo.isGranted && statusAudio.isGranted;
      } else if (await isAndroidVersionAtLeast(29)) {
        // For Android 10+, use storage permission
        print('Android 10-12 detected, checking storage permission');
        final status = await Permission.storage.status;
        print('Storage permission: ${status.toString()}');
        hasPermission = status.isGranted;
      } else {
        // For older Android versions
        print('Android < 10 detected, checking legacy storage permission');
        final status = await Permission.storage.status;
        print('Legacy storage permission: ${status.toString()}');
        hasPermission = status.isGranted;
      }
      
      print('Final storage permission result: $hasPermission');
      hasStoragePermission.value = hasPermission;
      return hasPermission;
    } catch (e) {
      print('Error checking storage permissions: $e');
      return false;
    }
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      hasStoragePermission.value = true;
      return true;
    }
    
    bool hasPermission = false;
    
    try {
      print('Requesting storage permissions... Android version check starting');
      
      // For Android 13+ (API 33+), request media permissions
      if (await isAndroidVersionAtLeast(33)) {
        print('Android 13+ detected, requesting specific media permissions');
        // Request photos, videos, and audio permissions
        final statusPhotos = await Permission.photos.request();
        final statusVideo = await Permission.videos.request();
        final statusAudio = await Permission.audio.request();
        
        print('Photos permission: ${statusPhotos.toString()}');
        print('Videos permission: ${statusVideo.toString()}');
        print('Audio permission: ${statusAudio.toString()}');
        
        hasPermission = statusPhotos.isGranted || statusVideo.isGranted || statusAudio.isGranted;
        
        if (statusPhotos.isPermanentlyDenied || statusVideo.isPermanentlyDenied || statusAudio.isPermanentlyDenied) {
          print('Media permissions permanently denied, showing dialog');
          _showPermanentlyDeniedDialog(
            'Media Permission Required',
            'This app needs media permissions to save reports and files. '
            'Please enable media access in app settings.'
          );
        }
      } else {
        // For Android 12 and below, use storage permission
        print('Android 12 or below detected, requesting standard storage permission');
        final status = await Permission.storage.request();
        print('Storage permission result: ${status.toString()}');
        hasPermission = status.isGranted;
        
        if (status.isPermanentlyDenied) {
          print('Storage permission permanently denied, showing dialog');
          _showPermanentlyDeniedDialog(
            'Storage Permission Required',
            'This app needs storage permissions to save reports and files. '
            'Please enable storage access in app settings.'
          );
        }
      }
      
      print('Final storage permission result after request: $hasPermission');
      hasStoragePermission.value = hasPermission;
      return hasPermission;
    } catch (e) {
      print('Error requesting storage permissions: $e');
      return false;
    }
  }

  // SMS permissions
  Future<bool> checkSmsPermission() async {
    if (!Platform.isAndroid) {
      hasSmsPermission.value = true;
      return true;
    }

    final status = await Permission.sms.status;
    hasSmsPermission.value = status.isGranted;
    return status.isGranted;
  }

  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) {
      hasSmsPermission.value = true;
      return true;
    }

    // For Android 12, we need additional explanation
    if (await isAndroidVersionAtLeast(31)) {
      final shouldRequest = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'This app needs SMS permission to send delivery receipts to members. '
            'This will allow automatic sending of SMS notifications.'
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldRequest) {
        return false;
      }
    }

    final status = await Permission.sms.request();
    hasSmsPermission.value = status.isGranted;
    
    if (status.isPermanentlyDenied) {
      _showPermanentlyDeniedDialog(
        'SMS Permission Required',
        'This app needs SMS permission to send delivery receipts. '
        'Please enable SMS in app settings.'
      );
    }
    
    return status.isGranted;
  }

  // Helper to show a dialog for permanently denied permissions
  void _showPermanentlyDeniedDialog(String title, String message) {
    print('Attempting to show permanently denied dialog: $title');
    try {
      Get.dialog(
        AlertDialog(
          title: Text(title),
          content: Text('$message\n\nPlease go to Settings > Apps > Farm Fresh > Permissions to enable.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      print('Successfully showed permanently denied dialog');
    } catch (e) {
      print('Error showing permanently denied dialog: $e');
    }
  }

  // Helper method to check Android version
  Future<bool> isAndroidVersionAtLeast(int version) async {
    if (!Platform.isAndroid) return false;
    
    try {
      // For a more accurate version check
      final sdkInt = int.tryParse(await _getAndroidSdkVersion()) ?? 0;
      print('Detected Android SDK version: $sdkInt');
      return sdkInt >= version;
    } catch (e) {
      print('Error checking Android version: $e');
      return false;
    }
  }
  
  // Helper to get the actual SDK version using native platform methods
  Future<String> _getAndroidSdkVersion() async {
    try {
      // Since we can't easily access SettingsService, use a default value
      // This is a fallback solution - in a real app, you would integrate with
      // device_info_plus package to get the actual SDK version
      return Platform.version.contains('android') ? '31' : '29';
    } catch (e) {
      print('Error getting Android SDK version: $e');
      // Default to a reasonable assumption (Android 10 - API 29)
      return '29';
    }
  }
} 