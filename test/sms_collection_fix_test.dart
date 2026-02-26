import 'package:flutter_test/flutter_test.dart';
import 'package:farm_pro/models/models.dart';

void main() {
  group('SMS Collection Fix Tests', () {
    
    /// Helper function to simulate the fixed cumulative weight parsing logic
    double parseCumulativeWeight(dynamic rawWeight) {
      double allTimeCumulativeWeight = 0.0;
      try {
        if (rawWeight != null) {
          allTimeCumulativeWeight = double.tryParse(rawWeight.toString()) ?? 0.0;
        }
        
        // Additional validation to ensure the weight is valid and not negative
        if (allTimeCumulativeWeight < 0 || allTimeCumulativeWeight.isNaN || allTimeCumulativeWeight.isInfinite) {
          allTimeCumulativeWeight = 0.0;
        }
      } catch (e) {
        print('Error parsing cumulative weight: $e');
        allTimeCumulativeWeight = 0.0;
      }
      return allTimeCumulativeWeight;
    }

    group('Cumulative Weight Calculation', () {
      test('should handle null allTimeWeight from database', () {
        // Arrange - simulate database returning null for SUM(netWeight)
        final memberSummary = {
          'totalCollections': 5,
          'totalWeight': 25.5,
          'allTimeCollections': 10,
          'allTimeWeight': null, // This is the problematic case
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(memberSummary['allTimeWeight'], isNull);
        expect(allTimeCumulativeWeight, 0.0);
      });

      test('should handle zero allTimeWeight correctly', () {
        // Arrange
        final memberSummary = {
          'totalCollections': 0,
          'totalWeight': 0.0,
          'allTimeCollections': 0,
          'allTimeWeight': 0.0,
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(allTimeCumulativeWeight, 0.0);
      });

      test('should handle valid allTimeWeight correctly', () {
        // Arrange
        final memberSummary = {
          'totalCollections': 3,
          'totalWeight': 15.5,
          'allTimeCollections': 8,
          'allTimeWeight': 45.75,
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(allTimeCumulativeWeight, 45.75);
      });

      test('should handle negative allTimeWeight by setting to zero', () {
        // Arrange - this shouldn't happen in normal cases but we handle it
        final memberSummary = {
          'totalCollections': 1,
          'totalWeight': 5.0,
          'allTimeCollections': 1,
          'allTimeWeight': -10.0, // Invalid negative weight
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(allTimeCumulativeWeight, 0.0);
      });

      test('should handle string allTimeWeight values', () {
        // Arrange - database might return string values
        final memberSummary = {
          'totalCollections': 2,
          'totalWeight': 10.0,
          'allTimeCollections': 5,
          'allTimeWeight': '25.50', // String value
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(allTimeCumulativeWeight, 25.50);
      });

      test('should handle invalid string allTimeWeight values', () {
        // Arrange - invalid string that can't be parsed
        final memberSummary = {
          'totalCollections': 1,
          'totalWeight': 5.0,
          'allTimeCollections': 1,
          'allTimeWeight': 'invalid_weight', // Invalid string
        };
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(memberSummary['allTimeWeight']);
        
        // Assert
        expect(allTimeCumulativeWeight, 0.0);
      });
    });

    group('SMS Message Formatting', () {
      test('should format SMS message correctly with zero cumulative weight', () {
        // Arrange
        final collection = CoffeeCollection(
          id: 'test123',
          memberId: 'member123',
          memberNumber: 'M001',
          memberName: 'John Doe',
          seasonId: 'season123',
          seasonName: '2024 Season',
          productType: 'CHERRY',
          grossWeight: 10.5,
          tareWeight: 0.5,
          netWeight: 10.0,
          numberOfBags: 2,
          collectionDate: DateTime(2024, 1, 15),
          isManualEntry: true,
          receiptNumber: 'R001',
          userId: 'user123',
          userName: 'Admin User',
        );
        
        const societyName = 'Test Society';
        const factoryName = 'Test Factory';
        const allTimeCumulativeWeight = 0.0; // Zero cumulative weight
        
        // Act
        final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:${collection.receiptNumber}
Date:15/01/24
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(0)} kg
Served By:${collection.userName ?? 'N/A'}''';
        
        // Assert
        expect(message, contains('Total:0 kg'));
        expect(message, contains('M/Name:John Doe'));
        expect(message, contains('Kgs:10.0'));
        expect(message, isNot(contains('null')));
      });

      test('should format SMS message correctly with valid cumulative weight', () {
        // Arrange
        final collection = CoffeeCollection(
          id: 'test123',
          memberId: 'member123',
          memberNumber: 'M001',
          memberName: 'John Doe',
          seasonId: 'season123',
          seasonName: '2024 Season',
          productType: 'CHERRY',
          grossWeight: 10.5,
          tareWeight: 0.5,
          netWeight: 10.0,
          numberOfBags: 2,
          collectionDate: DateTime(2024, 1, 15),
          isManualEntry: true,
          receiptNumber: 'R001',
          userId: 'user123',
          userName: 'Admin User',
        );
        
        const societyName = 'Test Society';
        const factoryName = 'Test Factory';
        const allTimeCumulativeWeight = 45.75; // Valid cumulative weight
        
        // Act
        final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:${collection.receiptNumber}
Date:15/01/24
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(0)} kg
Served By:${collection.userName ?? 'N/A'}''';
        
        // Assert
        expect(message, contains('Total:46 kg'));
        expect(message, contains('M/Name:John Doe'));
        expect(message, contains('Kgs:10.0'));
        expect(message, isNot(contains('null')));
      });
    });

    group('Error Handling', () {
      test('should handle parsing exceptions gracefully', () {
        // Arrange - simulate an exception during parsing
        dynamic problematicValue = Object(); // Object that can't be parsed
        
        // Act
        final allTimeCumulativeWeight = parseCumulativeWeight(problematicValue);
        
        // Assert - should default to 0.0 when parsing fails
        expect(allTimeCumulativeWeight, 0.0);
      });
      
      test('should handle edge case values', () {
        // Test various edge cases
        final testCases = [
          {'input': double.infinity, 'expected': 0.0}, // Infinity should be 0
          {'input': double.negativeInfinity, 'expected': 0.0}, // Negative infinity should be 0
          {'input': double.nan, 'expected': 0.0}, // NaN should be 0
          {'input': '', 'expected': 0.0}, // Empty string
          {'input': '  ', 'expected': 0.0}, // Whitespace
          {'input': 'null', 'expected': 0.0}, // String 'null'
        ];
        
        for (final testCase in testCases) {
          final result = parseCumulativeWeight(testCase['input']);
          expect(result, testCase['expected'], 
                 reason: 'Failed for input: ${testCase['input']}');
        }
      });
    });
  });
}