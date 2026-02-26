import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/services.dart';

class SettingsController extends GetxController {
  SettingsService get _settingsService => Get.find<SettingsService>();
  BluetoothService get _bluetoothService => Get.find<BluetoothService>();

  Rx<OrganizationSettings?> get organizationSettings =>
      _settingsService.organizationSettings;
  Rx<SystemSettings?> get systemSettings => _settingsService.systemSettings;

  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;

  /// Validates tare weight value with comprehensive validation rules
  /// Returns a TareWeightValidationResult with validation status, errors, and warnings
  TareWeightValidationResult validateTareWeight(double tareWeight) {
    // Check for negative values (Requirement 3.1)
    if (tareWeight < 0) {
      return TareWeightValidationResult.error(
        'Tare weight cannot be negative',
        0.5, // Default fallback value
      );
    }

    // Check for extremely high values that might indicate input errors (before other checks)
    if (tareWeight > 50.0) {
      return TareWeightValidationResult.error(
        'Tare weight is too high (${tareWeight.toStringAsFixed(2)} kg). '
        'Please check your input. Maximum allowed is 50.0 kg.',
        0.5, // Default fallback value
      );
    }

    // Check for unusually low values (Requirement 3.2)
    if (tareWeight < 0.1) {
      return TareWeightValidationResult.success(
        tareWeight,
        warning:
            'Warning: Unusually low tare weight (${tareWeight.toStringAsFixed(2)} kg). '
            'Typical tare weights are between 0.1 kg and 5.0 kg.',
      );
    }

    // Check for unusually high values (Requirement 3.3)
    if (tareWeight > 5.0) {
      return TareWeightValidationResult.success(
        tareWeight,
        warning:
            'Warning: Unusually high tare weight (${tareWeight.toStringAsFixed(2)} kg). '
            'Typical tare weights are between 0.1 kg and 5.0 kg.',
      );
    }

    // Valid tare weight
    return TareWeightValidationResult.success(tareWeight);
  }

  /// Validates tare weight from string input with format checking
  /// Returns a TareWeightValidationResult with validation status, errors, and warnings
  TareWeightValidationResult validateTareWeightFromString(
    String tareWeightStr,
  ) {
    // Check for empty or null input (Requirement 3.5)
    if (tareWeightStr.trim().isEmpty) {
      return TareWeightValidationResult.error(
        'Tare weight cannot be empty',
        0.5, // Default fallback value
      );
    }

    // Try to parse the string to double (Requirement 3.4, 3.5)
    final double? parsedValue = double.tryParse(tareWeightStr.trim());
    if (parsedValue == null) {
      return TareWeightValidationResult.error(
        'Invalid tare weight format. Please enter a valid number (e.g., 0.5, 1.2)',
        0.5, // Default fallback value
      );
    }

    // Validate the parsed value using the main validation method
    return validateTareWeight(parsedValue);
  }

  Future<void> updateOrganizationSettings({
    required String societyName,
    required String factory,
    required String address,
    String? email,
    String? phoneNumber,
    String? website,
    String? slogan,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final currentSettings = organizationSettings.value;
      if (currentSettings == null) {
        throw Exception('Organization settings not found');
      }

      final updatedSettings = OrganizationSettings(
        id: currentSettings.id,
        societyName: societyName,
        logoPath: currentSettings.logoPath,
        factory: factory,
        address: address,
        email: email,
        phoneNumber: phoneNumber,
        website: website,
        slogan: slogan,
      );

      await _settingsService.updateOrganizationSettings(updatedSettings);

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to update organization settings: $e';
      print(errorMessage.value);
    }
  }

  Future<void> updateSystemSettings({
    required bool enablePrinting,
    required bool enableSms,
    required bool enableManualWeightEntry,
    required bool enableBluetoothScale,
    String? defaultPrinterAddress,
    String? defaultScaleAddress,
    double? defaultTareWeight,
    String? printMethod,
    String? coffeeProduct,
    int? receiptDuplicates,
    bool? autoDisconnectScale,
    String? deliveryRestrictionMode,
    // SMS Gateway Configuration
    bool? smsGatewayEnabled,
    String? smsGatewayUrl,
    String? smsGatewayUsername,
    String? smsGatewayPassword,
    String? smsGatewaySenderId,
    String? smsGatewayApiKey,
    bool? smsGatewayFallbackToSim,
    // Bulk SMS Settings
    bool? enableBulkSms,
    String? bulkSmsDefaultMessage,
    bool? bulkSmsIncludeBalance,
    bool? bulkSmsIncludeName,
    int? bulkSmsMaxRecipients,
    int? bulkSmsBatchDelay,
    bool? bulkSmsConfirmBeforeSend,
    String? bulkSmsFilterType,
    bool? bulkSmsLogActivity,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final currentSettings = systemSettings.value;
      if (currentSettings == null) {
        throw Exception('System settings not found');
      }

      // Validate tare weight if provided (Requirements 3.1, 3.2, 3.3, 3.4, 3.5)
      double finalTareWeight =
          defaultTareWeight ?? currentSettings.defaultTareWeight;
      if (defaultTareWeight != null) {
        final validationResult = validateTareWeight(defaultTareWeight);

        if (!validationResult.isValid) {
          // If validation fails, throw an exception with the error message
          throw Exception(validationResult.errorMessage);
        }

        // If there's a warning, we could log it or handle it differently
        // For now, we'll proceed with the value but could add warning handling later
        if (validationResult.hasWarning) {
          print(
            'Tare weight validation warning: ${validationResult.warningMessage}',
          );
        }

        finalTareWeight = validationResult.validatedValue;
      }

      final updatedSettings = SystemSettings(
        id: currentSettings.id,
        enablePrinting: enablePrinting,
        enableSms: enableSms,
        enableManualWeightEntry: enableManualWeightEntry,
        enableBluetoothScale: enableBluetoothScale,
        defaultPrinterAddress: defaultPrinterAddress,
        defaultScaleAddress: defaultScaleAddress,
        defaultTareWeight: finalTareWeight,
        coffeePrice: currentSettings.coffeePrice,
        currency: currentSettings.currency,
        printMethod: printMethod ?? currentSettings.printMethod,
        coffeeProduct: coffeeProduct ?? currentSettings.coffeeProduct,
        allowProductChange: currentSettings.allowProductChange,
        currentSeasonId: currentSettings.currentSeasonId,
        enableInventory: currentSettings.enableInventory,
        enableCreditSales: currentSettings.enableCreditSales,
        receiptDuplicates:
            receiptDuplicates ?? currentSettings.receiptDuplicates,
        autoDisconnectScale:
            autoDisconnectScale ?? currentSettings.autoDisconnectScale,
        deliveryRestrictionMode:
            deliveryRestrictionMode ?? currentSettings.deliveryRestrictionMode,
        // SMS Gateway Configuration
        smsGatewayEnabled:
            smsGatewayEnabled ?? currentSettings.smsGatewayEnabled,
        smsGatewayUrl: smsGatewayUrl ?? currentSettings.smsGatewayUrl,
        smsGatewayUsername:
            smsGatewayUsername ?? currentSettings.smsGatewayUsername,
        smsGatewayPassword:
            smsGatewayPassword ?? currentSettings.smsGatewayPassword,
        smsGatewaySenderId:
            smsGatewaySenderId ?? currentSettings.smsGatewaySenderId,
        smsGatewayApiKey: smsGatewayApiKey ?? currentSettings.smsGatewayApiKey,
        smsGatewayFallbackToSim:
            smsGatewayFallbackToSim ?? currentSettings.smsGatewayFallbackToSim,
        // Bulk SMS Settings
        enableBulkSms: enableBulkSms ?? currentSettings.enableBulkSms,
        bulkSmsDefaultMessage:
            bulkSmsDefaultMessage ?? currentSettings.bulkSmsDefaultMessage,
        bulkSmsIncludeBalance:
            bulkSmsIncludeBalance ?? currentSettings.bulkSmsIncludeBalance,
        bulkSmsIncludeName:
            bulkSmsIncludeName ?? currentSettings.bulkSmsIncludeName,
        bulkSmsMaxRecipients:
            bulkSmsMaxRecipients ?? currentSettings.bulkSmsMaxRecipients,
        bulkSmsBatchDelay:
            bulkSmsBatchDelay ?? currentSettings.bulkSmsBatchDelay,
        bulkSmsConfirmBeforeSend:
            bulkSmsConfirmBeforeSend ??
            currentSettings.bulkSmsConfirmBeforeSend,
        bulkSmsFilterType:
            bulkSmsFilterType ?? currentSettings.bulkSmsFilterType,
        bulkSmsLogActivity:
            bulkSmsLogActivity ?? currentSettings.bulkSmsLogActivity,
      );

      await _settingsService.updateSystemSettings(updatedSettings);

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to update system settings: $e';
      print(errorMessage.value);
      rethrow; // Re-throw to allow callers to handle validation errors
    }
  }

  Future<String?> uploadLogo() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Use image picker to select an image
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        isLoading.value = false;
        return null;
      }

      // Create a File from the picked image
      final File imageFile = File(pickedFile.path);

      print('Selected image file path: ${imageFile.path}');
      print('Image file exists: ${await imageFile.exists()}');
      print('Image file size: ${await imageFile.length()} bytes');

      // Save the logo using the settings service
      final logoPath = await _settingsService.saveOrganizationLogo(imageFile);

      if (logoPath != null) {
        // Verify the saved logo file
        final File savedLogoFile = File(logoPath);
        print('Saved logo path: $logoPath');
        print('Saved logo exists: ${await savedLogoFile.exists()}');
        print('Saved logo size: ${await savedLogoFile.length()} bytes');
      } else {
        print('Failed to save logo - returned path is null');
      }

      isLoading.value = false;
      return logoPath;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to upload logo: $e';
      print(errorMessage.value);
      return null;
    }
  }

  Future<void> scanBluetoothDevices() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Check if Bluetooth is enabled first
      bool isEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        // Try to turn on Bluetooth
        bool turnedOn = await _bluetoothService.requestBluetoothEnable();
        if (!turnedOn) {
          isLoading.value = false;
          errorMessage.value = 'Bluetooth is not enabled';
          throw Exception('Bluetooth is not enabled');
        }
      }

      // Start the scan
      await _bluetoothService.startScan();

      // Allow some time for the scan results to be processed
      await Future.delayed(const Duration(seconds: 2));

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to scan Bluetooth devices: $e';
      print(errorMessage.value);
      rethrow;
    }
  }

  Future<void> connectToPrinter(String deviceAddress) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Find the device in the list of scanned devices
      final device = _bluetoothService.devices.firstWhereOrNull(
        (device) => device.address == deviceAddress,
      );

      if (device == null) {
        throw Exception('Printer device not found');
      }

      await _bluetoothService.connectToPrinter(device);

      // Update system settings with the new printer address
      if (systemSettings.value != null) {
        await updateSystemSettings(
          enablePrinting: systemSettings.value!.enablePrinting,
          enableSms: systemSettings.value!.enableSms,
          enableManualWeightEntry:
              systemSettings.value!.enableManualWeightEntry,
          enableBluetoothScale: systemSettings.value!.enableBluetoothScale,
          defaultPrinterAddress: deviceAddress,
          defaultScaleAddress: systemSettings.value!.defaultScaleAddress,
          printMethod:
              'bluetooth', // Set to bluetooth since we're connecting to a bluetooth printer
        );
      }

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to connect to printer: $e';
      print(errorMessage.value);
    }
  }

  Future<void> connectToScale(String deviceAddress) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Find the device in the list of scanned devices
      final device = _bluetoothService.devices.firstWhereOrNull(
        (device) => device.address == deviceAddress,
      );

      if (device == null) {
        throw Exception('Scale device not found');
      }

      await _bluetoothService.connectToScale(device);

      // Update system settings with the new scale address
      if (systemSettings.value != null) {
        await updateSystemSettings(
          enablePrinting: systemSettings.value!.enablePrinting,
          enableSms: systemSettings.value!.enableSms,
          enableManualWeightEntry:
              systemSettings.value!.enableManualWeightEntry,
          enableBluetoothScale: systemSettings.value!.enableBluetoothScale,
          defaultPrinterAddress: systemSettings.value!.defaultPrinterAddress,
          defaultScaleAddress: deviceAddress,
          printMethod: systemSettings.value!.printMethod,
        );
      }

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to connect to scale: $e';
      print(errorMessage.value);
    }
  }
}
