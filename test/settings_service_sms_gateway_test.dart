import 'package:farm_pro/models/models.dart';
import 'package:farm_pro/services/database_helper.dart';
import 'package:farm_pro/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SettingsService SMS Gateway Configuration', () {
    late SettingsService settingsService;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Initialize GetX
      Get.testMode = true;

      // Create test database helper
      dbHelper = DatabaseHelper();
      Get.put(dbHelper);

      // Initialize settings service
      settingsService = SettingsService();
      Get.put(settingsService);

      await settingsService.init();
    });

    tearDown(() {
      Get.reset();
    });

    test('should validate SMS gateway configuration correctly', () {
      // Test with valid configuration
      final validSettings = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: true,
        smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      final errors = settingsService.validateSmsGatewayConfig(validSettings);
      expect(errors, isEmpty);
    });

    test('should return validation errors for invalid configuration', () {
      // Test with invalid configuration
      final invalidSettings = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: true,
        smsGatewayUrl: '', // Invalid: empty URL
        smsGatewayUsername: 'ab', // Invalid: too short
        smsGatewayPassword: '123', // Invalid: too short
        smsGatewaySenderId: 'VERY_LONG_SENDER_ID', // Invalid: too long
        smsGatewayApiKey: 'short', // Invalid: too short
        smsGatewayFallbackToSim: true,
      );

      final errors = settingsService.validateSmsGatewayConfig(invalidSettings);

      expect(errors['url'], contains('required'));
      expect(errors['username'], contains('at least 3 characters'));
      expect(errors['password'], contains('at least 6 characters'));
      expect(errors['senderId'], contains('11 characters or less'));
      expect(errors['apiKey'], contains('too short'));
    });

    test('should not validate when gateway is disabled', () {
      // Test with disabled gateway
      final disabledSettings = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: false, // Disabled
        smsGatewayUrl: '', // Empty but should not matter
        smsGatewayUsername: '',
        smsGatewayPassword: '',
        smsGatewaySenderId: '',
        smsGatewayApiKey: '',
        smsGatewayFallbackToSim: true,
      );

      final errors = settingsService.validateSmsGatewayConfig(disabledSettings);
      expect(errors, isEmpty); // No validation when disabled
    });

    test('should check if SMS gateway is configured correctly', () {
      // Test with properly configured gateway
      settingsService.systemSettings.value = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: true,
        smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      expect(settingsService.isSmsGatewayConfigured(), isTrue);

      // Test with disabled gateway
      settingsService.systemSettings.value = settingsService
          .systemSettings
          .value
          .copyWith(smsGatewayEnabled: false);

      expect(settingsService.isSmsGatewayConfigured(), isFalse);
    });

    test('should validate sender ID format correctly', () {
      final settingsWithInvalidSenderId = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: true,
        smsGatewayUrl: 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARM-PRO', // Invalid: contains hyphen
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      final errors = settingsService.validateSmsGatewayConfig(
        settingsWithInvalidSenderId,
      );
      expect(errors['senderId'], contains('letters and numbers'));
    });

    test('should validate URL format correctly', () {
      final settingsWithInvalidUrl = SystemSettings(
        id: 'test',
        enablePrinting: true,
        enableSms: true,
        enableManualWeightEntry: true,
        enableBluetoothScale: true,
        defaultPrinterAddress: null,
        defaultScaleAddress: null,
        coffeePrice: 50.0,
        currency: 'KES',
        smsGatewayEnabled: true,
        smsGatewayUrl: 'invalid-url', // Invalid: not HTTP/HTTPS
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      final errors = settingsService.validateSmsGatewayConfig(
        settingsWithInvalidUrl,
      );
      expect(errors['url'], contains('HTTP/HTTPS'));
    });
  });
}
