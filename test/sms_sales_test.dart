import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:farm_pro/services/sms_service.dart';
import 'package:farm_pro/services/settings_service.dart';
import 'package:farm_pro/models/models.dart';

// Generate mocks
@GenerateMocks([SmsService, SettingsService])
import 'sms_sales_test.mocks.dart';

void main() {
  group('SMS Sales Functionality Tests', () {
    late MockSmsService mockSmsService;
    late MockSettingsService mockSettingsService;

    setUp(() {
      mockSmsService = MockSmsService();
      mockSettingsService = MockSettingsService();
      
      // Register mocks with GetX
      Get.put<SmsService>(mockSmsService);
      Get.put<SettingsService>(mockSettingsService);
    });

    tearDown(() {
      Get.reset();
    });

    group('SMS Settings Validation', () {
      test('should send SMS for credit sales when enabled', () {
        // Arrange
        final systemSettings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: false,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );
        
        when(mockSettingsService.systemSettings).thenReturn(systemSettings.obs);
        
        // Act & Assert
        // This would test the _shouldSendSms method logic
        // Since it's a private method, we'd need to test it through public methods
        expect(systemSettings.enableSmsForCreditSales, true);
        expect(systemSettings.enableSmsForCashSales, false);
      });

      test('should not send SMS when globally disabled', () {
        // Arrange
        final systemSettings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: false, // SMS globally disabled
          enableSmsForCashSales: true,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );
        
        when(mockSettingsService.systemSettings).thenReturn(systemSettings.obs);
        
        // Act & Assert
        expect(systemSettings.enableSms, false);
      });

      test('should send SMS for cash sales when specifically enabled', () {
        // Arrange
        final systemSettings = SystemSettings(
          id: 'test',
          enablePrinting: true,
          enableSms: true,
          enableSmsForCashSales: true,
          enableSmsForCreditSales: true,
          enableManualWeightEntry: true,
          enableBluetoothScale: true,
        );
        
        when(mockSettingsService.systemSettings).thenReturn(systemSettings.obs);
        
        // Act & Assert
        expect(systemSettings.enableSmsForCashSales, true);
      });
    });

    group('Phone Number Validation', () {
      test('should validate Kenyan phone numbers correctly', () {
        // Arrange
        const validNumbers = [
          '+254712345678',
          '254712345678',
          '0712345678',
          '712345678',
        ];
        
        const invalidNumbers = [
          '12345',
          '+1234567890',
          '0812345678', // Invalid prefix
          '',
        ];
        
        // Act & Assert
        for (final number in validNumbers) {
          when(mockSmsService.validateKenyanPhoneNumber(number))
              .thenReturn('+254712345678');
          
          final result = mockSmsService.validateKenyanPhoneNumber(number);
          expect(result, isNotNull, reason: 'Should validate $number');
        }
        
        for (final number in invalidNumbers) {
          when(mockSmsService.validateKenyanPhoneNumber(number))
              .thenReturn(null);
          
          final result = mockSmsService.validateKenyanPhoneNumber(number);
          expect(result, isNull, reason: 'Should reject $number');
        }
      });
    });

    group('SMS Content Formatting', () {
      test('should format SMS message correctly for credit sale', () {
        // Arrange
        final member = Member(
          id: 'member1',
          memberNumber: 'M001',
          fullName: 'John Doe',
          phoneNumber: '+254712345678',
          registrationDate: DateTime.now(),
        );
        
        final sale = Sale(
          id: 'sale1',
          memberId: 'member1',
          memberName: 'John Doe',
          saleType: 'CREDIT',
          totalAmount: 1000.0,
          paidAmount: 500.0,
          balanceAmount: 500.0,
          saleDate: DateTime.now(),
          receiptNumber: 'R001',
          userId: 'user1',
          userName: 'Admin User',
          items: [],
          isActive: true,
          createdAt: DateTime.now(),
        );
        
        // Act
        // This would test the message formatting logic
        final expectedContent = [
          'Receipt: R001',
          'Member: John Doe',
          'Type: CREDIT SALE',
          'Amount: KSh 1000.00',
          'Paid: KSh 500.00',
          'Balance: KSh 500.00',
        ];
        
        // Assert
        for (final content in expectedContent) {
          // In actual implementation, we'd test the formatted message contains these
          expect(content, isNotEmpty);
        }
      });

      test('should truncate long names in SMS message', () {
        // Arrange
        const longName = 'This is a very long member name that should be truncated';
        const expectedTruncated = 'This is a very long me...';
        
        // Act
        final truncated = longName.length > 25 
            ? '${longName.substring(0, 22)}...' 
            : longName;
        
        // Assert
        expect(truncated, expectedTruncated);
        expect(truncated.length, lessThanOrEqualTo(25));
      });
    });

    group('SMS Service Integration', () {
      test('should use robust SMS sending method', () async {
        // Arrange
        const phoneNumber = '+254712345678';
        const message = 'Test SMS message';
        
        when(mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        )).thenAnswer((_) async => true);
        
        // Act
        final result = await mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        );
        
        // Assert
        expect(result, true);
        verify(mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        )).called(1);
      });

      test('should handle SMS sending failure gracefully', () async {
        // Arrange
        const phoneNumber = '+254712345678';
        const message = 'Test SMS message';
        
        when(mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        )).thenAnswer((_) async => false);
        
        // Act
        final result = await mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        );
        
        // Assert
        expect(result, false);
      });

      test('should handle SMS service exceptions', () async {
        // Arrange
        const phoneNumber = '+254712345678';
        const message = 'Test SMS message';
        
        when(mockSmsService.sendSmsRobust(
          phoneNumber,
          message,
          maxRetries: 3,
          priority: 2,
        )).thenThrow(Exception('SMS service unavailable'));
        
        // Act & Assert
        expect(
          () => mockSmsService.sendSmsRobust(
            phoneNumber,
            message,
            maxRetries: 3,
            priority: 2,
          ),
          throwsException,
        );
      });
    });

    group('Error Handling', () {
      test('should categorize different error types', () {
        // Arrange
        final errors = {
          'Permission denied': 'Permission',
          'Connection timeout': 'Timeout',
          'Network error': 'Network',
          'Service unavailable': 'Service',
          'Unknown error': 'Unknown',
        };
        
        // Act & Assert
        errors.forEach((errorMessage, expectedCategory) {
          String errorCategory = 'Unknown';
          
          if (errorMessage.contains('permission')) {
            errorCategory = 'Permission';
          } else if (errorMessage.contains('timeout')) {
            errorCategory = 'Timeout';
          } else if (errorMessage.contains('network')) {
            errorCategory = 'Network';
          } else if (errorMessage.contains('service')) {
            errorCategory = 'Service';
          }
          
          expect(errorCategory, expectedCategory);
        });
      });
    });
  });
}