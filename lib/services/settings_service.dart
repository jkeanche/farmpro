import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database_helper.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final Rx<OrganizationSettings> organizationSettings =
      OrganizationSettings(
        id: 'default',
        societyName: 'Farm Fresh Cooperative',
        logoPath: null,
        factory: 'Main Factory',
        address: 'P.O. Box 123, Nairobi',
        email: 'info@farmfresh.co.ke',
        phoneNumber: '',
        website: 'www.farmfresh.co.ke',
        slogan: 'Quality Coffee, Quality Life',
      ).obs;

  final Rx<SystemSettings> systemSettings =
      SystemSettings(
        id: 'default',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        // SMS Gateway defaults
        smsGatewayEnabled: true,
        smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername: '',
        smsGatewayPassword: '',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: '',
        smsGatewayFallbackToSim: true,
        // Bulk SMS defaults
        enableBulkSms: true,
        bulkSmsDefaultMessage:
            'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
        bulkSmsIncludeBalance: true,
        bulkSmsIncludeName: true,
        bulkSmsMaxRecipients: 50,
        bulkSmsBatchDelay: 2,
        bulkSmsConfirmBeforeSend: true,
        bulkSmsFilterType: 'all',
        bulkSmsLogActivity: true,
      ).obs;

  // Dedicated reactive tare weight property for fine-grained updates
  final RxDouble defaultTareWeight = 0.5.obs;

  Future<SettingsService> init() async {
    // Update database schema if needed
    await _dbHelper.updateDatabaseSchema();

    // Load settings from database
    await _loadSettings();

    // Load sensitive SMS credentials from secure storage
    await _loadSensitiveSettings();

    return this;
  }

  // Load sensitive settings from secure storage and update the system settings
  Future<void> _loadSensitiveSettings() async {
    try {
      // Get current settings
      final currentSettings = systemSettings.value;

      // Load SMS credentials from secure storage
      final username =
          await _secureStorage.read(key: 'sms_username') ??
          currentSettings.smsGatewayUsername;
      final password =
          await _secureStorage.read(key: 'sms_password') ??
          currentSettings.smsGatewayPassword;
      final senderId =
          await _secureStorage.read(key: 'sms_sender_id') ??
          currentSettings.smsGatewaySenderId;
      final apiKey =
          await _secureStorage.read(key: 'sms_api_key') ??
          currentSettings.smsGatewayApiKey;

      // Only update if any of the values have changed
      if (username != currentSettings.smsGatewayUsername ||
          password != currentSettings.smsGatewayPassword ||
          senderId != currentSettings.smsGatewaySenderId ||
          apiKey != currentSettings.smsGatewayApiKey) {
        // Create new settings with updated values
        systemSettings.value = SystemSettings(
          id: currentSettings.id,
          enablePrinting: currentSettings.enablePrinting,
          enableSms: currentSettings.enableSms,
          enableSmsForCashSales: currentSettings.enableSmsForCashSales,
          enableSmsForCreditSales: currentSettings.enableSmsForCreditSales,
          enableManualWeightEntry: currentSettings.enableManualWeightEntry,
          enableBluetoothScale: currentSettings.enableBluetoothScale,
          defaultPrinterAddress: currentSettings.defaultPrinterAddress,
          defaultScaleAddress: currentSettings.defaultScaleAddress,
          coffeePrice: currentSettings.coffeePrice,
          currency: currentSettings.currency,
          defaultTareWeight: currentSettings.defaultTareWeight,
          printMethod: currentSettings.printMethod,
          coffeeProduct: currentSettings.coffeeProduct,
          allowProductChange: currentSettings.allowProductChange,
          currentSeasonId: currentSettings.currentSeasonId,
          enableInventory: currentSettings.enableInventory,
          enableCreditSales: currentSettings.enableCreditSales,
          receiptDuplicates: currentSettings.receiptDuplicates,
          autoDisconnectScale: currentSettings.autoDisconnectScale,
          deliveryRestrictionMode: currentSettings.deliveryRestrictionMode,
          // Update SMS Gateway settings with secure values
          smsGatewayEnabled: currentSettings.smsGatewayEnabled,
          smsGatewayUrl: currentSettings.smsGatewayUrl,
          smsGatewayUsername: username,
          smsGatewayPassword: password,
          smsGatewaySenderId: senderId,
          smsGatewayApiKey: apiKey,
          smsGatewayFallbackToSim: currentSettings.smsGatewayFallbackToSim,
          // Bulk SMS Settings
          enableBulkSms: currentSettings.enableBulkSms,
          bulkSmsDefaultMessage: currentSettings.bulkSmsDefaultMessage,
          bulkSmsIncludeBalance: currentSettings.bulkSmsIncludeBalance,
          bulkSmsIncludeName: currentSettings.bulkSmsIncludeName,
          bulkSmsMaxRecipients: currentSettings.bulkSmsMaxRecipients,
          bulkSmsBatchDelay: currentSettings.bulkSmsBatchDelay,
          bulkSmsConfirmBeforeSend: currentSettings.bulkSmsConfirmBeforeSend,
          bulkSmsFilterType: currentSettings.bulkSmsFilterType,
          bulkSmsLogActivity: currentSettings.bulkSmsLogActivity,
        );
      }
    } catch (e) {
      print('Error loading sensitive settings: $e');
    }
  }

  // Save sensitive settings to secure storage
  Future<void> _saveSensitiveSettings() async {
    try {
      final settings = systemSettings.value;
      await _secureStorage.write(
        key: 'sms_username',
        value: settings.smsGatewayUsername,
      );
      await _secureStorage.write(
        key: 'sms_password',
        value: settings.smsGatewayPassword,
      );
      await _secureStorage.write(
        key: 'sms_sender_id',
        value: settings.smsGatewaySenderId,
      );
      await _secureStorage.write(
        key: 'sms_api_key',
        value: settings.smsGatewayApiKey,
      );
    } catch (e) {
      print('Error saving sensitive settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final db = await _dbHelper.database;

      // Load organization settings
      try {
        final List<Map<String, dynamic>> orgSettingsMaps = await db.query(
          'organization_settings',
        );
        if (orgSettingsMaps.isNotEmpty) {
          organizationSettings.value = OrganizationSettings.fromJson(
            orgSettingsMaps.first,
          );
        }
      } catch (e) {
        print('Error loading organization settings: $e');
        // Keep default organization settings if loading fails
      }

      // Load system settings with enhanced error handling
      try {
        final List<Map<String, dynamic>> systemSettingsMaps = await db.query(
          'system_settings',
        );
        print(
          '📊 Found ${systemSettingsMaps.length} system_settings record(s)',
        );
        if (systemSettingsMaps.isNotEmpty) {
          // Create a mutable copy of the database map
          final Map<String, dynamic> settingsMap = Map<String, dynamic>.from(
            systemSettingsMaps.first,
          );
          print('📖 System settings record ID: ${settingsMap['id']}');
          print(
            '📖 Raw defaultTareWeight from database: ${settingsMap['defaultTareWeight']}',
          );

          // Add default values for missing SMS columns to prevent errors
          settingsMap['enableSmsForCashSales'] ??= false;
          settingsMap['enableSmsForCreditSales'] ??= true;

          // Add default values for SMS gateway fields
          settingsMap['smsGatewayEnabled'] ??= true;
          settingsMap['smsGatewayUrl'] ??=
              'https://portal.zettatel.com/SMSApi/send';
          settingsMap['smsGatewayUsername'] ??= '';
          settingsMap['smsGatewayPassword'] ??= '';
          settingsMap['smsGatewaySenderId'] ??= 'FARMPRO';
          settingsMap['smsGatewayApiKey'] ??= '';
          settingsMap['smsGatewayFallbackToSim'] ??= true;

          // Add default values for bulk SMS fields
          settingsMap['enableBulkSms'] ??= true;
          settingsMap['bulkSmsDefaultMessage'] ??=
              'Dear {name}, your current balance is KSh {balance}. Thank you for your business.';
          settingsMap['bulkSmsIncludeBalance'] ??= true;
          settingsMap['bulkSmsIncludeName'] ??= true;
          settingsMap['bulkSmsMaxRecipients'] ??= 50;
          settingsMap['bulkSmsBatchDelay'] ??= 2;
          settingsMap['bulkSmsConfirmBeforeSend'] ??= true;
          settingsMap['bulkSmsFilterType'] ??= 'all';
          settingsMap['bulkSmsLogActivity'] ??= true;

          // Load sensitive data from secure storage
          final username = await _secureStorage.read(key: 'sms_username') ?? '';
          final password = await _secureStorage.read(key: 'sms_password') ?? '';
          final senderId =
              await _secureStorage.read(key: 'sms_sender_id') ?? 'FARMPRO';
          final apiKey = await _secureStorage.read(key: 'sms_api_key') ?? '';

          // Override secure storage values in the map
          settingsMap['smsGatewayUsername'] = username;
          settingsMap['smsGatewayPassword'] = password;
          settingsMap['smsGatewaySenderId'] = senderId;
          settingsMap['smsGatewayApiKey'] = apiKey;

          // Use fromJson which has proper int-to-bool conversion
          final settings = SystemSettings.fromJson(settingsMap);

          // Update system settings
          systemSettings.value = settings;
          // Initialize reactive tare weight with loaded value
          defaultTareWeight.value = settings.defaultTareWeight;
          print(
            '📥 Loaded defaultTareWeight from database: ${settings.defaultTareWeight}',
          );
        }
      } catch (e) {
        print('❌ Error loading system settings: $e');
        print('⚠️ Using default settings with defaultTareWeight: 0.5');
        // If loading fails, ensure we have default system settings with SMS columns
        systemSettings.value = SystemSettings(
          id: 'default',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
          defaultPrinterAddress: null,
          defaultScaleAddress: null,
          coffeePrice: 50.0,
          currency: 'KES',
          defaultTareWeight: 0.5,
          // SMS Gateway defaults
          smsGatewayEnabled: true,
          smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
          smsGatewayUsername: '',
          smsGatewayPassword: '',
          smsGatewaySenderId: 'FARMPRO',
          smsGatewayApiKey: '',
          smsGatewayFallbackToSim: true,
          // Bulk SMS defaults
          enableBulkSms: true,
          bulkSmsDefaultMessage:
              'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
          bulkSmsIncludeBalance: true,
          bulkSmsIncludeName: true,
          bulkSmsMaxRecipients: 50,
          bulkSmsBatchDelay: 2,
          bulkSmsConfirmBeforeSend: true,
          bulkSmsFilterType: 'all',
          bulkSmsLogActivity: true,
        );
        defaultTareWeight.value = 0.5;
      }
    } catch (e) {
      print('Critical error loading settings: $e');
      // Ensure we have some default settings even if everything fails
      systemSettings.value = SystemSettings(
        id: 'default',
        enablePrinting: true,
        enableSms: true,
        enableSmsForCashSales: false,
        enableSmsForCreditSales: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        defaultTareWeight: 0.5,
        // SMS Gateway defaults
        smsGatewayEnabled: true,
        smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername: '',
        smsGatewayPassword: '',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: '',
        smsGatewayFallbackToSim: true,
        // Bulk SMS defaults
        enableBulkSms: true,
        bulkSmsDefaultMessage:
            'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
        bulkSmsIncludeBalance: true,
        bulkSmsIncludeName: true,
        bulkSmsMaxRecipients: 50,
        bulkSmsBatchDelay: 2,
        bulkSmsConfirmBeforeSend: true,
        bulkSmsFilterType: 'all',
        bulkSmsLogActivity: true,
      );
      defaultTareWeight.value = 0.5;
    }
  }

  Future<void> updateOrganizationSettings(OrganizationSettings settings) async {
    final db = await _dbHelper.database;

    await db.update(
      'organization_settings',
      settings.toJson(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );

    organizationSettings.value = settings;
  }

  Future<void> updateSystemSettings(SystemSettings settings) async {
    try {
      final db = await _dbHelper.database;

      // Save sensitive data to secure storage
      await _secureStorage.write(
        key: 'sms_username',
        value: settings.smsGatewayUsername,
      );
      await _secureStorage.write(
        key: 'sms_password',
        value: settings.smsGatewayPassword,
      );
      await _secureStorage.write(
        key: 'sms_sender_id',
        value: settings.smsGatewaySenderId,
      );
      await _secureStorage.write(
        key: 'sms_api_key',
        value: settings.smsGatewayApiKey,
      );

      // Create a copy of settings for database storage
      final settingsForDb = SystemSettings(
        id: settings.id,
        enablePrinting: settings.enablePrinting,
        enableSms: settings.enableSms,
        enableManualWeightEntry: settings.enableManualWeightEntry,
        enableBluetoothScale: settings.enableBluetoothScale,
        defaultPrinterAddress: settings.defaultPrinterAddress,
        defaultScaleAddress: settings.defaultScaleAddress,
        coffeePrice: settings.coffeePrice,
        currency: settings.currency,
        defaultTareWeight: settings.defaultTareWeight,
        printMethod: settings.printMethod,
        coffeeProduct: settings.coffeeProduct,
        allowProductChange: settings.allowProductChange,
        currentSeasonId: settings.currentSeasonId,
        enableInventory: settings.enableInventory,
        enableCreditSales: settings.enableCreditSales,
        receiptDuplicates: settings.receiptDuplicates,
        autoDisconnectScale: settings.autoDisconnectScale,
        deliveryRestrictionMode: settings.deliveryRestrictionMode,
        // SMS Gateway - store non-sensitive data in database
        smsGatewayEnabled: settings.smsGatewayEnabled,
        smsGatewayUrl: settings.smsGatewayUrl,
        smsGatewayUsername: settings.smsGatewayUsername,
        smsGatewayPassword: settings.smsGatewayPassword,
        smsGatewaySenderId: settings.smsGatewaySenderId,
        smsGatewayApiKey: settings.smsGatewayApiKey,
        smsGatewayFallbackToSim: settings.smsGatewayFallbackToSim,
        // Bulk SMS Settings
        enableBulkSms: settings.enableBulkSms,
        bulkSmsDefaultMessage: settings.bulkSmsDefaultMessage,
        bulkSmsIncludeBalance: settings.bulkSmsIncludeBalance,
        bulkSmsIncludeName: settings.bulkSmsIncludeName,
        bulkSmsMaxRecipients: settings.bulkSmsMaxRecipients,
        bulkSmsBatchDelay: settings.bulkSmsBatchDelay,
        bulkSmsConfirmBeforeSend: settings.bulkSmsConfirmBeforeSend,
        bulkSmsFilterType: settings.bulkSmsFilterType,
        bulkSmsLogActivity: settings.bulkSmsLogActivity,
      );

      // Convert bool to int for boolean fields
      final Map<String, dynamic> settingsMap = settings.toJson();
      settingsMap['enablePrinting'] = _dbHelper.boolToInt(
        settings.enablePrinting,
      );
      settingsMap['enableSms'] = _dbHelper.boolToInt(settings.enableSms);
      settingsMap['enableSmsForCashSales'] = _dbHelper.boolToInt(
        settings.enableSmsForCashSales,
      );
      settingsMap['enableSmsForCreditSales'] = _dbHelper.boolToInt(
        settings.enableSmsForCreditSales,
      );
      settingsMap['enableManualWeightEntry'] = _dbHelper.boolToInt(
        settings.enableManualWeightEntry,
      );
      settingsMap['enableBluetoothScale'] = _dbHelper.boolToInt(
        settings.enableBluetoothScale,
      );
      settingsMap['allowProductChange'] = _dbHelper.boolToInt(
        settings.allowProductChange,
      );
      settingsMap['enableInventory'] = _dbHelper.boolToInt(
        settings.enableInventory,
      );
      settingsMap['enableCreditSales'] = _dbHelper.boolToInt(
        settings.enableCreditSales,
      );
      settingsMap['autoDisconnectScale'] = _dbHelper.boolToInt(
        settings.autoDisconnectScale,
      );

      // Convert SMS gateway boolean fields to int
      settingsMap['smsGatewayEnabled'] = _dbHelper.boolToInt(
        settings.smsGatewayEnabled,
      );
      settingsMap['smsGatewayFallbackToSim'] = _dbHelper.boolToInt(
        settings.smsGatewayFallbackToSim,
      );

      // Convert bulk SMS boolean fields to int
      settingsMap['enableBulkSms'] = _dbHelper.boolToInt(
        settings.enableBulkSms,
      );
      settingsMap['bulkSmsIncludeBalance'] = _dbHelper.boolToInt(
        settings.bulkSmsIncludeBalance,
      );
      settingsMap['bulkSmsIncludeName'] = _dbHelper.boolToInt(
        settings.bulkSmsIncludeName,
      );
      settingsMap['bulkSmsConfirmBeforeSend'] = _dbHelper.boolToInt(
        settings.bulkSmsConfirmBeforeSend,
      );
      settingsMap['bulkSmsLogActivity'] = _dbHelper.boolToInt(
        settings.bulkSmsLogActivity,
      );

      // Don't store sensitive credentials in database - they go to secure storage
      settingsMap.remove('smsGatewayPassword');
      settingsMap.remove('smsGatewayApiKey');

      // First, try to update with all columns
      try {
        print(
          '💾 Saving defaultTareWeight to database: ${settingsMap['defaultTareWeight']}',
        );
        print('💾 Updating system_settings where id = ${settings.id}');

        final updateCount = await db.update(
          'system_settings',
          settingsMap,
          where: 'id = ?',
          whereArgs: [settings.id],
        );

        print(
          '✅ Successfully saved settings to database (updated $updateCount row(s))',
        );

        if (updateCount == 0) {
          print(
            '⚠️ WARNING: No rows were updated! The record with id="${settings.id}" may not exist.',
          );
          // Try to verify if the record exists
          final existingRecords = await db.query(
            'system_settings',
            where: 'id = ?',
            whereArgs: [settings.id],
          );
          print(
            '📊 Found ${existingRecords.length} record(s) with id="${settings.id}"',
          );
          if (existingRecords.isEmpty) {
            print('🔧 Attempting to insert new record...');
            await db.insert('system_settings', settingsMap);
            print('✅ Inserted new system_settings record');
          }
        }
      } catch (e) {
        print('Error updating system settings with all columns: $e');

        // If update fails, try to update database schema first
        await _dbHelper.updateDatabaseSchema();

        // Then try the update again
        try {
          await db.update(
            'system_settings',
            settingsMap,
            where: 'id = ?',
            whereArgs: [settings.id],
          );
        } catch (e2) {
          print('Error updating system settings after schema update: $e2');

          // As a last resort, update only the columns that exist
          await _updateSystemSettingsSelectively(db, settings, settingsMap);
        }
      }

      // Handle secure credential persistence for SMS Gateway
      String effectivePassword = settings.smsGatewayPassword;
      String effectiveApiKey = settings.smsGatewayApiKey;
      try {
        if (!settings.smsGatewayEnabled) {
          // Gateway disabled: clear stored credentials
          await _clearSmsGatewayCredentials();
          effectivePassword = '';
          effectiveApiKey = '';
        } else {
          // Gateway enabled: store credentials if provided (non-empty)
          final newPassword = settings.smsGatewayPassword;
          final newApiKey = settings.smsGatewayApiKey;
          if ((newPassword.isNotEmpty) || (newApiKey.isNotEmpty)) {
            await _storeSmsGatewayCredentialsSecurely(
              password: newPassword,
              apiKey: newApiKey,
            );
            // Use newly provided credentials at runtime
            effectivePassword = newPassword;
            effectiveApiKey = newApiKey;
          } else {
            // No new credentials provided - keep previously stored values for runtime
            final stored = await getSmsGatewayCredentials();
            effectivePassword = stored['password'] ?? '';
            effectiveApiKey = stored['apiKey'] ?? '';
          }
        }
      } catch (e) {
        print(
          'Warning: Failed to persist SMS credentials in updateSystemSettings: $e',
        );
      }

      // Ensure runtime settings include effective credentials
      final runtimeSettings = settings.copyWith(
        smsGatewayPassword: effectivePassword,
        smsGatewayApiKey: effectiveApiKey,
      );
      systemSettings.value = runtimeSettings;

      // Update reactive tare weight if it changed
      if (settings.defaultTareWeight != defaultTareWeight.value) {
        defaultTareWeight.value = settings.defaultTareWeight;
      }
    } catch (e) {
      print('Critical error updating system settings: $e');
      // Don't throw to prevent app crash - just log the error
      // The UI should handle this gracefully
    }
  }

  /// Selectively update system settings by checking which columns exist
  Future<void> _updateSystemSettingsSelectively(
    Database db,
    SystemSettings settings,
    Map<String, dynamic> settingsMap,
  ) async {
    try {
      // Get current table structure
      final tableInfo = await db.rawQuery("PRAGMA table_info(system_settings)");
      final existingColumns =
          tableInfo.map((col) => col['name'] as String).toSet();

      // Filter settingsMap to only include existing columns
      final filteredMap = <String, dynamic>{};
      for (final entry in settingsMap.entries) {
        if (existingColumns.contains(entry.key)) {
          filteredMap[entry.key] = entry.value;
        } else {
          print(
            'Skipping column ${entry.key} as it does not exist in database',
          );
        }
      }

      if (filteredMap.isNotEmpty) {
        await db.update(
          'system_settings',
          filteredMap,
          where: 'id = ?',
          whereArgs: [settings.id],
        );
        print(
          'Successfully updated system settings with ${filteredMap.length} columns',
        );
      } else {
        print('No valid columns found for system settings update');
      }
    } catch (e) {
      print('Error in selective system settings update: $e');
      // Even this fallback failed - just continue without throwing
    }
  }

  /// Update default tare weight with validation and notifications
  Future<void> updateDefaultTareWeight(double newTareWeight) async {
    try {
      // Basic validation
      if (newTareWeight < 0) {
        throw Exception('Tare weight cannot be negative');
      }

      // Update the system settings with new tare weight
      final updatedSettings = systemSettings.value.copyWith(
        defaultTareWeight: newTareWeight,
      );

      // Save to database
      await updateSystemSettings(updatedSettings);

      // The reactive tare weight is already updated in updateSystemSettings
      print('✅ Default tare weight updated to: ${newTareWeight}kg');
    } catch (e) {
      print('❌ Error updating default tare weight: $e');
      rethrow;
    }
  }

  /// Stream getter for tare weight changes
  Stream<double> get tareWeightStream => defaultTareWeight.stream;

  /// Validate SMS gateway configuration parameters
  Map<String, String> validateSmsGatewayConfig(SystemSettings settings) {
    final errors = <String, String>{};

    // Validate URL format
    if (settings.smsGatewayEnabled) {
      if (settings.smsGatewayUrl.isEmpty) {
        errors['url'] = 'SMS Gateway URL is required when gateway is enabled';
      } else {
        try {
          final uri = Uri.parse(settings.smsGatewayUrl);
          if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
            errors['url'] = 'SMS Gateway URL must be a valid HTTP/HTTPS URL';
          }
        } catch (e) {
          errors['url'] = 'Invalid SMS Gateway URL format';
        }
      }

      // Validate username
      if (settings.smsGatewayUsername.isEmpty) {
        errors['username'] =
            'SMS Gateway username is required when gateway is enabled';
      } else if (settings.smsGatewayUsername.length < 3) {
        errors['username'] =
            'SMS Gateway username must be at least 3 characters';
      }

      // Validate password
      if (settings.smsGatewayPassword.isEmpty) {
        errors['password'] =
            'SMS Gateway password is required when gateway is enabled';
      } else if (settings.smsGatewayPassword.length < 6) {
        errors['password'] =
            'SMS Gateway password must be at least 6 characters';
      }

      // Validate API key
      if (settings.smsGatewayApiKey.isEmpty) {
        errors['apiKey'] =
            'SMS Gateway API key is required when gateway is enabled';
      } else if (settings.smsGatewayApiKey.length < 10) {
        errors['apiKey'] = 'SMS Gateway API key appears to be too short';
      }

      // Validate sender ID
      if (settings.smsGatewaySenderId.isEmpty) {
        errors['senderId'] =
            'SMS Gateway sender ID is required when gateway is enabled';
      } else if (settings.smsGatewaySenderId.length > 11) {
        errors['senderId'] =
            'SMS Gateway sender ID must be 11 characters or less';
      } else if (!RegExp(
        r'^[A-Za-z0-9]+$',
      ).hasMatch(settings.smsGatewaySenderId)) {
        errors['senderId'] =
            'SMS Gateway sender ID can only contain letters and numbers';
      }
    }

    return errors;
  }

  /// Check if SMS gateway configuration is complete and valid
  bool isSmsGatewayConfigured() {
    final settings = systemSettings.value;
    if (!settings.smsGatewayEnabled) return false;

    final errors = validateSmsGatewayConfig(settings);
    return errors.isEmpty;
  }

  /// Update SMS gateway configuration with validation and secure storage
  Future<Map<String, String>> updateSmsGatewayConfig({
    required bool enabled,
    required String url,
    required String username,
    required String password,
    required String senderId,
    required String apiKey,
    required bool fallbackToSim,
  }) async {
    try {
      // Create updated settings with new SMS gateway config
      final updatedSettings = systemSettings.value.copyWith(
        smsGatewayEnabled: enabled,
        smsGatewayUrl: url.trim(),
        smsGatewayUsername: username.trim(),
        smsGatewayPassword:
            password, // Don't trim password in case spaces are intentional
        smsGatewaySenderId: senderId.trim().toUpperCase(),
        smsGatewayApiKey: apiKey.trim(),
        smsGatewayFallbackToSim: fallbackToSim,
      );

      // Validate the configuration
      final validationErrors = validateSmsGatewayConfig(updatedSettings);
      if (validationErrors.isNotEmpty) {
        return validationErrors;
      }

      // Store sensitive credentials securely
      if (enabled) {
        await _storeSmsGatewayCredentialsSecurely(
          password: password,
          apiKey: apiKey,
        );
      } else {
        // Clear stored credentials when gateway is disabled
        await _clearSmsGatewayCredentials();
      }

      // Save the validated settings (credentials are stored securely)
      await updateSystemSettings(updatedSettings);

      print('✅ SMS Gateway configuration updated successfully');
      return {}; // Empty map indicates success
    } catch (e) {
      print('❌ Error updating SMS gateway configuration: $e');
      return {'general': 'Failed to save SMS gateway configuration: $e'};
    }
  }

  /// Store SMS gateway credentials securely
  Future<void> _storeSmsGatewayCredentialsSecurely({
    required String password,
    required String apiKey,
  }) async {
    try {
      await _secureStorage.write(key: 'sms_gateway_password', value: password);
      await _secureStorage.write(key: 'sms_gateway_api_key', value: apiKey);
      print('✅ SMS Gateway credentials stored securely');
    } catch (e) {
      print('❌ Error storing SMS gateway credentials: $e');
      rethrow;
    }
  }

  /// Retrieve SMS gateway credentials from secure storage
  Future<Map<String, String?>> getSmsGatewayCredentials() async {
    try {
      final password = await _secureStorage.read(key: 'sms_gateway_password');
      final apiKey = await _secureStorage.read(key: 'sms_gateway_api_key');

      return {'password': password, 'apiKey': apiKey};
    } catch (e) {
      print('❌ Error retrieving SMS gateway credentials: $e');
      return {'password': null, 'apiKey': null};
    }
  }

  /// Clear stored SMS gateway credentials
  Future<void> _clearSmsGatewayCredentials() async {
    try {
      await _secureStorage.delete(key: 'sms_gateway_password');
      await _secureStorage.delete(key: 'sms_gateway_api_key');
      print('✅ SMS Gateway credentials cleared');
    } catch (e) {
      print('❌ Error clearing SMS gateway credentials: $e');
    }
  }

  /// Get complete SMS gateway configuration including secure credentials
  Future<SystemSettings> getCompleteSystemSettings() async {
    final credentials = await getSmsGatewayCredentials();

    return systemSettings.value.copyWith(
      smsGatewayPassword: credentials['password'] ?? '',
      smsGatewayApiKey: credentials['apiKey'] ?? '',
    );
  }

  Future<String?> saveOrganizationLogo(File logoFile) async {
    try {
      print('Original logo file path: ${logoFile.path}');
      print('Original logo file exists: ${await logoFile.exists()}');
      print('Original logo file size: ${await logoFile.length()} bytes');

      final directory = await getApplicationDocumentsDirectory();
      final logoPath = '${directory.path}/organization_logo.png';

      print('Target logo path: $logoPath');

      // Delete existing file if it exists
      final targetFile = File(logoPath);
      if (await targetFile.exists()) {
        print('Existing logo file found, deleting it first');
        await targetFile.delete();
      }

      // Copy the file to the app's documents directory
      final File newLogoFile = await logoFile.copy(logoPath);

      // Verify the copied file
      print('Copied logo file exists: ${await newLogoFile.exists()}');
      print('Copied logo file size: ${await newLogoFile.length()} bytes');

      // Update the organization settings
      final updatedSettings = organizationSettings.value.copyWith(
        logoPath: logoPath,
      );
      await updateOrganizationSettings(updatedSettings);

      print('Organization settings updated with new logo path');

      return logoPath;
    } catch (e) {
      print('Error saving organization logo: $e');
      // Try with a more basic approach
      try {
        print('Attempting alternative approach to save logo');
        final directory = await getApplicationDocumentsDirectory();
        final logoPath = '${directory.path}/organization_logo.png';

        // Read source file as bytes
        final bytes = await logoFile.readAsBytes();
        print('Read ${bytes.length} bytes from source file');

        // Write bytes to target file
        final File newFile = File(logoPath);
        await newFile.writeAsBytes(bytes);
        print('Wrote ${bytes.length} bytes to target file');

        // Verify written file
        if (await newFile.exists()) {
          print('Written file exists, size: ${await newFile.length()} bytes');

          // Update the organization settings
          final updatedSettings = organizationSettings.value.copyWith(
            logoPath: logoPath,
          );
          await updateOrganizationSettings(updatedSettings);

          return logoPath;
        }
      } catch (e2) {
        print('Alternative approach also failed: $e2');
      }
      return null;
    }
  }

  // Get a setting value by key
  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> result = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }

    return null;
  }

  // Save a setting with key and value
  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;

    // Check if the setting already exists
    final List<Map<String, dynamic>> result = await db.query(
      'app_settings',
      columns: ['id'],
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      // Update existing setting
      await db.update(
        'app_settings',
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      // Insert new setting
      await db.insert('app_settings', {'key': key, 'value': value});
    }
  }
}
