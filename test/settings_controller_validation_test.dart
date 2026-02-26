import 'package:farm_pro/controllers/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsController Tare Weight Validation Tests', () {
    late SettingsController controller;

    setUp(() {
      controller = SettingsController();
    });

    group('validateTareWeight', () {
      test('should return error for negative values', () {
        final result = controller.validateTareWeight(-1.0);

        expect(result.isValid, false);
        expect(result.hasError, true);
        expect(result.errorMessage, contains('cannot be negative'));
        expect(result.validatedValue, 0.5); // fallback value
      });

      test('should return warning for unusually low values', () {
        final result = controller.validateTareWeight(0.05);

        expect(result.isValid, true);
        expect(result.hasWarning, true);
        expect(result.warningMessage, contains('Unusually low tare weight'));
        expect(result.validatedValue, 0.05);
      });

      test('should return warning for unusually high values', () {
        final result = controller.validateTareWeight(10.0);

        expect(result.isValid, true);
        expect(result.hasWarning, true);
        expect(result.warningMessage, contains('Unusually high tare weight'));
        expect(result.validatedValue, 10.0);
      });

      test('should return error for extremely high values', () {
        final result = controller.validateTareWeight(100.0);

        expect(result.isValid, false);
        expect(result.hasError, true);
        expect(result.errorMessage, contains('too high'));
        expect(result.validatedValue, 0.5); // fallback value
      });

      test('should return success for normal values', () {
        final result = controller.validateTareWeight(1.5);

        expect(result.isValid, true);
        expect(result.hasError, false);
        expect(result.hasWarning, false);
        expect(result.validatedValue, 1.5);
      });
    });

    group('validateTareWeightFromString', () {
      test('should return error for empty string', () {
        final result = controller.validateTareWeightFromString('');

        expect(result.isValid, false);
        expect(result.hasError, true);
        expect(result.errorMessage, contains('cannot be empty'));
      });

      test('should return error for invalid format', () {
        final result = controller.validateTareWeightFromString('abc');

        expect(result.isValid, false);
        expect(result.hasError, true);
        expect(result.errorMessage, contains('Invalid tare weight format'));
      });

      test('should validate parsed value correctly', () {
        final result = controller.validateTareWeightFromString('1.5');

        expect(result.isValid, true);
        expect(result.hasError, false);
        expect(result.validatedValue, 1.5);
      });

      test('should handle negative string values', () {
        final result = controller.validateTareWeightFromString('-1.0');

        expect(result.isValid, false);
        expect(result.hasError, true);
        expect(result.errorMessage, contains('cannot be negative'));
      });
    });
  });
}
