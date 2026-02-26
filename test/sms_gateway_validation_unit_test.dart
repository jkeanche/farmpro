import 'package:farm_pro/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Create a simple validation function for testing
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
      errors['username'] = 'SMS Gateway username must be at least 3 characters';
    }

    // Validate password
    if (settings.smsGatewayPassword.isEmpty) {
      errors['password'] =
          'SMS Gateway password is required when gateway is enabled';
    } else if (settings.smsGatewayPassword.length < 6) {
      errors['password'] = 'SMS Gateway password must be at least 6 characters';
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

void main() {
  group('SMS Gateway Validation Unit Tests', () {
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

      final errors = validateSmsGatewayConfig(validSettings);
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

      final errors = validateSmsGatewayConfig(invalidSettings);

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

      final errors = validateSmsGatewayConfig(disabledSettings);
      expect(errors, isEmpty); // No validation when disabled
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

      final errors = validateSmsGatewayConfig(settingsWithInvalidSenderId);
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

      final errors = validateSmsGatewayConfig(settingsWithInvalidUrl);
      expect(errors['url'], contains('HTTP/HTTPS'));
    });

    test('should validate all required fields when gateway is enabled', () {
      final settingsWithMissingFields = SystemSettings(
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
        smsGatewayUrl: '',
        smsGatewayUsername: '',
        smsGatewayPassword: '',
        smsGatewaySenderId: '',
        smsGatewayApiKey: '',
        smsGatewayFallbackToSim: true,
      );

      final errors = validateSmsGatewayConfig(settingsWithMissingFields);

      expect(errors['url'], isNotNull);
      expect(errors['username'], isNotNull);
      expect(errors['password'], isNotNull);
      expect(errors['senderId'], isNotNull);
      expect(errors['apiKey'], isNotNull);
    });

    test('should accept valid HTTPS URLs', () {
      final settingsWithHttpsUrl = SystemSettings(
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
        smsGatewayUrl: 'https://api.example.com/sms',
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      final errors = validateSmsGatewayConfig(settingsWithHttpsUrl);
      expect(errors['url'], isNull);
    });

    test('should accept valid HTTP URLs', () {
      final settingsWithHttpUrl = SystemSettings(
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
        smsGatewayUrl: 'http://api.example.com/sms',
        smsGatewayUsername: 'testuser',
        smsGatewayPassword: 'testpass123',
        smsGatewaySenderId: 'FARMPRO',
        smsGatewayApiKey: 'test-api-key-12345',
        smsGatewayFallbackToSim: true,
      );

      final errors = validateSmsGatewayConfig(settingsWithHttpUrl);
      expect(errors['url'], isNull);
    });
  });
}
