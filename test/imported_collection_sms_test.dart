import 'package:flutter_test/flutter_test.dart';
import 'package:farm_pro/models/models.dart';

void main() {
  group('Imported Collection SMS Tests', () {
    /// Helper function to simulate the cumulative weight calculation for imported collections
    Map<String, dynamic> simulateImportedCollectionData(
      double netWeight,
      DateTime collectionDate,
    ) {
      // Simulate how imported collection data is stored
      final collection = CoffeeCollection(
        id: 'imported_123',
        memberId: 'member_456',
        memberNumber: 'M001',
        memberName: 'John Doe',
        seasonId: 'season_789',
        seasonName: '2024 Season',
        productType: 'CHERRY',
        grossWeight: netWeight, // For imported collections, gross = net
        tareWeight: 0.0, // Imported collections have no tare weight
        netWeight: netWeight,
        numberOfBags: 1,
        collectionDate: collectionDate,
        isManualEntry: true, // Imported collections are marked as manual entry
        receiptNumber: 'IMP20240115001_1',
        userId: null, // May be null for imported collections
        userName: 'CSV Import',
        pricePerKg: null, // Always null for imported collections
        totalValue: null, // Always null for imported collections
      );

      // Convert to JSON format as it would be stored in database
      return collection.toJson();
    }

    /// Helper function to simulate database query results for member summary
    Map<String, dynamic> simulateMemberSummary(
      List<Map<String, dynamic>> collections,
    ) {
      double totalWeight = 0.0;
      int totalCollections = collections.length;

      for (final collection in collections) {
        final netWeight = collection['netWeight'];
        if (netWeight is num) {
          totalWeight += netWeight.toDouble();
        }
      }

      return {
        'totalCollections': totalCollections,
        'totalWeight': totalWeight,
        'allTimeCollections': totalCollections,
        'allTimeWeight': totalWeight,
      };
    }

    /// Helper function to parse cumulative weight (same as in our fix)
    double parseCumulativeWeight(dynamic rawWeight) {
      double allTimeCumulativeWeight = 0.0;
      try {
        if (rawWeight != null) {
          allTimeCumulativeWeight =
              double.tryParse(rawWeight.toString()) ?? 0.0;
        }

        // Additional validation to ensure the weight is valid and not negative
        if (allTimeCumulativeWeight < 0 ||
            allTimeCumulativeWeight.isNaN ||
            allTimeCumulativeWeight.isInfinite) {
          allTimeCumulativeWeight = 0.0;
        }
      } catch (e) {
        print('Error parsing cumulative weight: $e');
        allTimeCumulativeWeight = 0.0;
      }
      return allTimeCumulativeWeight;
    }

    group('Data Format Consistency', () {
      test(
        'imported collection data should match normal collection format',
        () {
          final importedData = simulateImportedCollectionData(
            25.5,
            DateTime(2024, 1, 15),
          );

          // Verify all required fields are present and properly typed
          expect(importedData['id'], isA<String>());
          expect(importedData['memberId'], isA<String>());
          expect(importedData['memberNumber'], isA<String>());
          expect(importedData['memberName'], isA<String>());
          expect(importedData['netWeight'], isA<double>());
          expect(importedData['grossWeight'], isA<double>());
          expect(importedData['tareWeight'], isA<double>());
          expect(importedData['numberOfBags'], isA<int>());
          expect(importedData['collectionDate'], isA<String>());
          expect(importedData['isManualEntry'], isA<int>());
          expect(importedData['receiptNumber'], isA<String>());

          // Verify specific values for imported collections
          expect(importedData['netWeight'], 25.5);
          expect(importedData['grossWeight'], 25.5); // Should equal net weight
          expect(importedData['tareWeight'], 0.0); // Should be 0 for imported
          expect(
            importedData['isManualEntry'],
            1,
          ); // Should be 1 (true) for imported
          expect(importedData['userName'], 'CSV Import');
          expect(importedData['pricePerKg'], isNull);
          expect(importedData['totalValue'], isNull);
        },
      );

      test(
        'imported collection should create valid CoffeeCollection object',
        () {
          final importedData = simulateImportedCollectionData(
            18.0,
            DateTime(2024, 1, 16),
          );

          // Should be able to recreate CoffeeCollection from the data
          expect(
            () => CoffeeCollection.fromJson(importedData),
            returnsNormally,
          );

          final collection = CoffeeCollection.fromJson(importedData);
          expect(collection.netWeight, 18.0);
          expect(collection.grossWeight, 18.0);
          expect(collection.tareWeight, 0.0);
          expect(collection.isManualEntry, true);
          expect(collection.userName, 'CSV Import');
        },
      );
    });

    group('Cumulative Weight Calculation', () {
      test(
        'should calculate cumulative weight correctly for single imported collection',
        () {
          final collections = [
            simulateImportedCollectionData(25.5, DateTime(2024, 1, 15)),
          ];

          final memberSummary = simulateMemberSummary(collections);
          final cumulativeWeight = parseCumulativeWeight(
            memberSummary['allTimeWeight'],
          );

          expect(cumulativeWeight, 25.5);
        },
      );

      test(
        'should calculate cumulative weight correctly for multiple imported collections',
        () {
          final collections = [
            simulateImportedCollectionData(25.5, DateTime(2024, 1, 15)),
            simulateImportedCollectionData(18.0, DateTime(2024, 1, 16)),
            simulateImportedCollectionData(32.8, DateTime(2024, 1, 17)),
          ];

          final memberSummary = simulateMemberSummary(collections);
          final cumulativeWeight = parseCumulativeWeight(
            memberSummary['allTimeWeight'],
          );

          expect(cumulativeWeight, 76.3); // 25.5 + 18.0 + 32.8
        },
      );

      test('should handle mixed normal and imported collections', () {
        // Simulate a mix of normal and imported collections
        final collections = [
          // Normal collection (has tare weight)
          {
            'netWeight': 20.0,
            'grossWeight': 21.0,
            'tareWeight': 1.0,
            'isManualEntry': 0,
            'userName': 'Admin User',
          },
          // Imported collection (no tare weight)
          simulateImportedCollectionData(25.5, DateTime(2024, 1, 15)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, 45.5); // 20.0 + 25.5
      });

      test('should handle zero weight imported collections', () {
        final collections = [
          simulateImportedCollectionData(0.0, DateTime(2024, 1, 15)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, 0.0);
      });

      test('should handle very small weight imported collections', () {
        final collections = [
          simulateImportedCollectionData(0.1, DateTime(2024, 1, 15)),
          simulateImportedCollectionData(0.05, DateTime(2024, 1, 16)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, closeTo(0.15, 0.001));
      });

      test('should handle large weight imported collections', () {
        final collections = [
          simulateImportedCollectionData(999.99, DateTime(2024, 1, 15)),
          simulateImportedCollectionData(1000.01, DateTime(2024, 1, 16)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, 2000.0);
      });
    });

    group('SMS Message Generation', () {
      test('should generate valid SMS message for imported collection', () {
        final collection = CoffeeCollection.fromJson(
          simulateImportedCollectionData(25.5, DateTime(2024, 1, 15)),
        );

        const societyName = 'Test Society';
        const factoryName = 'Test Factory';
        const allTimeCumulativeWeight = 45.75;

        final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:${collection.receiptNumber}
Date:15/01/24
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(1)} kg
Served By:${collection.userName ?? 'N/A'}''';

        // Verify message contains all required information
        expect(message, contains('TEST SOCIETY'));
        expect(message, contains('T/No:IMP20240115001_1'));
        expect(message, contains('M/No:M001'));
        expect(message, contains('M/Name:John Doe'));
        expect(message, contains('Type:CHERRY'));
        expect(message, contains('Kgs:25.5'));
        expect(message, contains('Bags:1'));
        expect(message, contains('Total:45.8 kg'));
        expect(message, contains('Served By:CSV Import'));

        // Verify no null values in message
        expect(message, isNot(contains('null')));
      });

      test('should handle imported collection with null user info', () {
        final collectionData = simulateImportedCollectionData(
          25.5,
          DateTime(2024, 1, 15),
        );
        collectionData['userId'] = null;
        collectionData['userName'] = null;

        final collection = CoffeeCollection.fromJson(collectionData);

        const societyName = 'Test Society';
        const factoryName = 'Test Factory';
        const allTimeCumulativeWeight = 25.5;

        final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:${collection.receiptNumber}
Date:15/01/24
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(1)} kg
Served By:${collection.userName ?? 'N/A'}''';

        // Should handle null userName gracefully
        expect(message, contains('Served By:N/A'));
        expect(message, isNot(contains('null')));
      });
    });

    group('Edge Cases', () {
      test('should handle imported collection with decimal weights', () {
        final collections = [
          simulateImportedCollectionData(25.567, DateTime(2024, 1, 15)),
          simulateImportedCollectionData(18.123, DateTime(2024, 1, 16)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, closeTo(43.69, 0.001));
      });

      test('should handle imported collection with different date formats', () {
        // Test that different collection dates don't affect weight calculation
        final collections = [
          simulateImportedCollectionData(25.5, DateTime(2023, 12, 31)),
          simulateImportedCollectionData(18.0, DateTime(2024, 1, 1)),
          simulateImportedCollectionData(32.8, DateTime(2024, 6, 15)),
        ];

        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        expect(cumulativeWeight, 76.3);
      });

      test('should handle imported collection with various bag counts', () {
        final collection1 = simulateImportedCollectionData(
          25.5,
          DateTime(2024, 1, 15),
        );
        collection1['numberOfBags'] = 3;

        final collection2 = simulateImportedCollectionData(
          18.0,
          DateTime(2024, 1, 16),
        );
        collection2['numberOfBags'] = 1;

        final collections = [collection1, collection2];
        final memberSummary = simulateMemberSummary(collections);
        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );

        // Weight calculation should not be affected by bag count
        expect(cumulativeWeight, 43.5);

        // But bag count should be preserved
        final recreatedCollection1 = CoffeeCollection.fromJson(collection1);
        expect(recreatedCollection1.numberOfBags, 3);
      });
    });

    group('Error Scenarios', () {
      test('should handle corrupted imported collection data', () {
        // Should not crash when trying to calculate cumulative weight
        final memberSummary = {'allTimeWeight': 'corrupted_value'};

        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );
        expect(cumulativeWeight, 0.0); // Should fallback to 0.0
      });

      test('should handle missing weight data in imported collections', () {
        final memberSummary = {'allTimeWeight': null};

        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );
        expect(cumulativeWeight, 0.0);
      });

      test('should handle negative weights in imported collections', () {
        final memberSummary = {'allTimeWeight': -25.5};

        final cumulativeWeight = parseCumulativeWeight(
          memberSummary['allTimeWeight'],
        );
        expect(cumulativeWeight, 0.0); // Should be corrected to 0.0
      });
    });
  });
}
