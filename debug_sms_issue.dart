// Debug script to identify the SMS issue with imported collections
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'lib/services/database_helper.dart';
import 'lib/models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Debugging SMS Issue with Imported Collections');
  print('================================================');
  
  try {
    // Initialize services
    Get.put(DatabaseHelper());
    final dbHelper = Get.find<DatabaseHelper>();
    final db = await dbHelper.database;
    
    print('✅ Database initialized');
    
    // Check if there are any imported collections in the database
    print('\n📊 Checking imported collections in database...');
    final importedCollections = await db.query(
      'coffee_collections',
      where: 'isManualEntry = ? AND userName = ?',
      whereArgs: [1, 'CSV Import'],
      limit: 5,
    );
    
    print('Found ${importedCollections.length} imported collections');
    
    if (importedCollections.isNotEmpty) {
      for (final collection in importedCollections) {
        print('\n🔍 Imported Collection Details:');
        print('   ID: ${collection['id']}');
        print('   Member ID: ${collection['memberId']}');
        print('   Member Name: ${collection['memberName']}');
        print('   Net Weight: ${collection['netWeight']} (${collection['netWeight'].runtimeType})');
        print('   Gross Weight: ${collection['grossWeight']} (${collection['grossWeight'].runtimeType})');
        print('   Tare Weight: ${collection['tareWeight']} (${collection['tareWeight'].runtimeType})');
        print('   User Name: ${collection['userName']}');
        print('   Is Manual Entry: ${collection['isManualEntry']}');
        
        // Test the member summary query for this specific member
        final memberId = collection['memberId'] as String;
        print('\n🔍 Testing member summary query for member: $memberId');
        
        // Test the exact query used in getMemberSeasonSummary
        final allTimeResult = await db.rawQuery('''
          SELECT 
            COUNT(*) as allTimeCollections,
            COALESCE(SUM(netWeight), 0.0) as allTimeWeight,
            SUM(netWeight) as rawSum,
            AVG(netWeight) as avgWeight,
            MIN(netWeight) as minWeight,
            MAX(netWeight) as maxWeight
          FROM coffee_collections 
          WHERE memberId = ?
        ''', [memberId]);
        
        if (allTimeResult.isNotEmpty) {
          final data = allTimeResult.first;
          print('   Query Results:');
          print('   - All Time Collections: ${data['allTimeCollections']} (${data['allTimeCollections'].runtimeType})');
          print('   - All Time Weight (COALESCE): ${data['allTimeWeight']} (${data['allTimeWeight'].runtimeType})');
          print('   - Raw SUM: ${data['rawSum']} (${data['rawSum'].runtimeType})');
          print('   - Average Weight: ${data['avgWeight']} (${data['avgWeight'].runtimeType})');
          print('   - Min Weight: ${data['minWeight']} (${data['minWeight'].runtimeType})');
          print('   - Max Weight: ${data['maxWeight']} (${data['maxWeight'].runtimeType})');
          
          // Test the parsing logic
          final rawWeight = data['allTimeWeight'];
          print('\n🔍 Testing weight parsing logic:');
          print('   Raw weight value: $rawWeight (${rawWeight.runtimeType})');
          
          double allTimeCumulativeWeight = 0.0;
          try {
            if (rawWeight != null) {
              allTimeCumulativeWeight = double.tryParse(rawWeight.toString()) ?? 0.0;
            }
            
            // Additional validation to ensure the weight is valid and not negative
            if (allTimeCumulativeWeight < 0 || allTimeCumulativeWeight.isNaN || allTimeCumulativeWeight.isInfinite) {
              allTimeCumulativeWeight = 0.0;
            }
            print('   Parsed weight: $allTimeCumulativeWeight');
          } catch (e) {
            print('   ❌ Error parsing weight: $e');
            allTimeCumulativeWeight = 0.0;
          }
          
          // Test SMS message generation
          print('\n📱 Testing SMS message generation:');
          final testCollection = CoffeeCollection.fromJson(collection);
          
          final message = '''TEST SOCIETY
Fac:Test Factory
T/No:${testCollection.receiptNumber}
Date:15/01/24
M/No:${testCollection.memberNumber}
M/Name:${testCollection.memberName}
Type:${testCollection.productType}
Kgs:${testCollection.netWeight.toStringAsFixed(1)}
Bags:${testCollection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(0)} kg
Served By:${testCollection.userName ?? 'N/A'}''';
          
          print('   Generated SMS Message:');
          print('   ----------------------');
          print(message);
          print('   ----------------------');
          
          // Check for potential issues
          if (message.contains('null')) {
            print('   ❌ SMS contains null values!');
          } else {
            print('   ✅ SMS message looks good');
          }
          
          if (allTimeCumulativeWeight == 0.0) {
            print('   ⚠️  Cumulative weight is 0.0 - this might be the issue!');
          }
        }
        
        break; // Only test the first imported collection
      }
    } else {
      print('⚠️  No imported collections found in database');
      
      // Create a test imported collection to debug
      print('\n🧪 Creating test imported collection...');
      final testCollection = {
        'id': 'test_imported_123',
        'memberId': 'test_member_456',
        'memberNumber': 'M999',
        'memberName': 'Test Member',
        'seasonId': 'test_season',
        'seasonName': '2024 Test Season',
        'productType': 'CHERRY',
        'grossWeight': 25.5,
        'tareWeight': 0.0,
        'netWeight': 25.5,
        'numberOfBags': 1,
        'collectionDate': DateTime.now().toIso8601String(),
        'isManualEntry': 1,
        'receiptNumber': 'TEST_IMP_001',
        'userId': null,
        'userName': 'CSV Import',
        'pricePerKg': null,
        'totalValue': null,
      };
      
      // Insert test collection
      await db.insert('coffee_collections', testCollection);
      print('✅ Test imported collection created');
      
      // Test the query on this test collection
      final testMemberId = testCollection['memberId'] as String;
      final testResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as allTimeCollections,
          COALESCE(SUM(netWeight), 0.0) as allTimeWeight,
          SUM(netWeight) as rawSum
        FROM coffee_collections 
        WHERE memberId = ?
      ''', [testMemberId]);
      
      if (testResult.isNotEmpty) {
        final data = testResult.first;
        print('   Test Query Results:');
        print('   - Collections: ${data['allTimeCollections']}');
        print('   - Weight (COALESCE): ${data['allTimeWeight']} (${data['allTimeWeight'].runtimeType})');
        print('   - Raw SUM: ${data['rawSum']} (${data['rawSum'].runtimeType})');
      }
      
      // Clean up test data
      await db.delete('coffee_collections', where: 'id = ?', whereArgs: [testCollection['id']]);
      print('✅ Test data cleaned up');
    }
    
    // Check database schema
    print('\n🔍 Checking database schema for coffee_collections table...');
    final schemaResult = await db.rawQuery("PRAGMA table_info(coffee_collections)");
    print('Coffee Collections Table Schema:');
    for (final column in schemaResult) {
      print('   - ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
    }
    
    print('\n🎯 DIAGNOSIS COMPLETE');
    print('====================');
    
  } catch (e) {
    print('❌ Error during debugging: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}