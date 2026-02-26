import 'package:farm_pro/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Service SMS Columns Tests', () {
    group('SystemSettings Model', () {
      test('should create SystemSettings with default SMS values', () {
        final settings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        expect(settings.enableSmsForCashSales, false); // Default value
        expect(settings.enableSmsForCreditSales, true); // Default value
        expect(settings.enableSms, true);
      });

      test('should create SystemSettings with custom SMS values', () {
        final settings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: true,
          enableSmsForCreditSales: false,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        expect(settings.enableSmsForCashSales, true);
        expect(settings.enableSmsForCreditSales, false);
      });

      test('should handle fromJson with missing SMS columns', () {
        final json = {
          'id': 'test',
          'enablePrinting': 1,
          'enableSms': 1,
          'enableManualWeightEntry': 1,
          'enableBluetoothScale': 1,
          // Missing enableSmsForCashSales and enableSmsForCreditSales
        };

        final settings = SystemSettings.fromJson(json);

        expect(settings.enableSmsForCashSales, false); // Default fallback
        expect(settings.enableSmsForCreditSales, true); // Default fallback
        expect(settings.enableSms, true);
      });

      test('should handle fromJson with null SMS columns', () {
        final json = {
          'id': 'test',
          'enablePrinting': 1,
          'enableSms': 1,
          'enableSmsForCashSales': null,
          'enableSmsForCreditSales': null,
          'enableManualWeightEntry': 1,
          'enableBluetoothScale': 1,
        };

        final settings = SystemSettings.fromJson(json);

        expect(settings.enableSmsForCashSales, false); // Default fallback
        expect(settings.enableSmsForCreditSales, true); // Default fallback
      });

      test('should handle fromJson with integer SMS columns', () {
        final json = {
          'id': 'test',
          'enablePrinting': 1,
          'enableSms': 1,
          'enableSmsForCashSales': 1,
          'enableSmsForCreditSales': 0,
          'enableManualWeightEntry': 1,
          'enableBluetoothScale': 1,
        };

        final settings = SystemSettings.fromJson(json);

        expect(settings.enableSmsForCashSales, true);
        expect(settings.enableSmsForCreditSales, false);
      });

      test('should handle fromJson with boolean SMS columns', () {
        final json = {
          'id': 'test',
          'enablePrinting': true,
          'enableSms': true,
          'enableSmsForCashSales': true,
          'enableSmsForCreditSales': false,
          'enableManualWeightEntry': true,
          'enableBluetoothScale': true,
        };

        final settings = SystemSettings.fromJson(json);

        expect(settings.enableSmsForCashSales, true);
        expect(settings.enableSmsForCreditSales, false);
      });

      test('should convert to JSON correctly', () {
        final settings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: true,
          enableSmsForCreditSales: false,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        final json = settings.toJson();

        expect(json['enableSmsForCashSales'], true);
        expect(json['enableSmsForCreditSales'], false);
        expect(json['enableSms'], true);
      });

      test('should copy with SMS values correctly', () {
        final originalSettings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        final updatedSettings = originalSettings.copyWith(
          enableSmsForCashSales: true,
          enableSmsForCreditSales: false,
        );

        expect(updatedSettings.enableSmsForCashSales, true);
        expect(updatedSettings.enableSmsForCreditSales, false);
        expect(updatedSettings.enableSms, true); // Should remain unchanged
        expect(updatedSettings.id, 'test'); // Should remain unchanged
      });
    });

    group('Error Handling Scenarios', () {
      test('should handle malformed JSON gracefully', () {
        final json = {
          'id': 'test',
          'enablePrinting': 'invalid', // Invalid type
          'enableSms': 'true', // String instead of bool/int
          'enableSmsForCashSales': 'yes', // Invalid value
          'enableSmsForCreditSales': 2, // Invalid int value
          'enableManualWeightEntry': null,
          'enableBluetoothScale': {},
        };

        // The fromJson method should handle these gracefully
        final settings = SystemSettings.fromJson(json);

        // Should use default values for invalid inputs
        expect(settings.enableSmsForCashSales, false); // 'yes' should be false
        expect(
          settings.enableSmsForCreditSales,
          false,
        ); // 2 should be false (only 1 is true)
      });

      test('should handle empty JSON', () {
        final json = <String, dynamic>{};

        // Should not throw and should use defaults
        expect(() => SystemSettings.fromJson(json), returnsNormally);

        final settings = SystemSettings.fromJson(json);
        expect(settings.enableSmsForCashSales, false);
        expect(settings.enableSmsForCreditSales, true);
      });
    });

    group('SMS Logic Validation', () {
      test('should determine SMS sending correctly for cash sales', () {
        final settingsWithCashSmsEnabled = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: true,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        final settingsWithCashSmsDisabled = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        // Simulate SMS logic for cash sales
        bool shouldSendSmsForCash1 =
            settingsWithCashSmsEnabled.enableSms &&
            settingsWithCashSmsEnabled.enableSmsForCashSales;
        bool shouldSendSmsForCash2 =
            settingsWithCashSmsDisabled.enableSms &&
            settingsWithCashSmsDisabled.enableSmsForCashSales;

        expect(shouldSendSmsForCash1, true);
        expect(shouldSendSmsForCash2, false);
      });

      test('should determine SMS sending correctly for credit sales', () {
        final settingsWithCreditSmsEnabled = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        final settingsWithCreditSmsDisabled = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: false,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        // Simulate SMS logic for credit sales
        bool shouldSendSmsForCredit1 =
            settingsWithCreditSmsEnabled.enableSms &&
            settingsWithCreditSmsEnabled.enableSmsForCreditSales;
        bool shouldSendSmsForCredit2 =
            settingsWithCreditSmsDisabled.enableSms &&
            settingsWithCreditSmsDisabled.enableSmsForCreditSales;

        expect(shouldSendSmsForCredit1, true);
        expect(shouldSendSmsForCredit2, false);
      });

      test('should not send SMS when globally disabled', () {
        final settingsWithSmsDisabled = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: false, // SMS globally disabled
          enableSmsForCashSales: true,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );

        // Even with specific SMS types enabled, global SMS disabled should prevent sending
        bool shouldSendSmsForCash =
            settingsWithSmsDisabled.enableSms &&
            settingsWithSmsDisabled.enableSmsForCashSales;
        bool shouldSendSmsForCredit =
            settingsWithSmsDisabled.enableSms &&
            settingsWithSmsDisabled.enableSmsForCreditSales;

        expect(shouldSendSmsForCash, false);
        expect(shouldSendSmsForCredit, false);
      });
    });
  });
}
