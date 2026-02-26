import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('🧪 Testing Sale Items Unique ID Fix');
  print('=' * 50);

  try {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create test database
    final db = await openDatabase(
      'test_sale_items_unique.db',
      version: 1,
      onCreate: (db, version) async {
        // Create sales table
        await db.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            memberId TEXT,
            memberName TEXT,
            saleType TEXT NOT NULL,
            totalAmount REAL NOT NULL,
            paidAmount REAL DEFAULT 0,
            balanceAmount REAL DEFAULT 0,
            saleDate TEXT NOT NULL,
            receiptNumber TEXT,
            notes TEXT,
            userId TEXT,
            userName TEXT,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL,
            seasonId TEXT,
            seasonName TEXT
          )
        ''');

        // Create sale_items table with unique constraint on id
        await db.execute('''
          CREATE TABLE sale_items (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL,
            unitPrice REAL NOT NULL,
            totalPrice REAL NOT NULL,
            packSizeSold REAL,
            FOREIGN KEY (saleId) REFERENCES sales (id)
          )
        ''');

        // Create stock table
        await db.execute('''
          CREATE TABLE stock (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            productName TEXT,
            currentStock REAL NOT NULL DEFAULT 0,
            availableStock REAL NOT NULL DEFAULT 0,
            lastUpdated TEXT NOT NULL,
            lastUpdatedBy TEXT
          )
        ''');

        // Create stock_movements table
        await db.execute('''
          CREATE TABLE stock_movements (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            movementType TEXT NOT NULL,
            quantity REAL NOT NULL,
            balanceBefore REAL NOT NULL,
            balanceAfter REAL NOT NULL,
            reference TEXT,
            notes TEXT,
            movementDate TEXT NOT NULL,
            userId TEXT,
            userName TEXT
          )
        ''');
      },
    );

    print('✅ Test database created successfully');

    // Test 1: Single Sale Item (should work)
    print('\n📋 Test 1: Single Sale Item');
    print('-' * 30);

    final now = DateTime.now().toIso8601String();

    // Insert test stock
    await db.insert('stock', {
      'id': 'STK001',
      'productId': 'PRD001',
      'productName': 'Test Product 1',
      'currentStock': 100.0,
      'availableStock': 100.0,
      'lastUpdated': now,
      'lastUpdatedBy': 'system',
    });

    try {
      await db.transaction((txn) async {
        final saleId = 'SALE001';

        // Insert sale
        await txn.insert('sales', {
          'id': saleId,
          'memberId': 'MEM001',
          'memberName': 'Test Member',
          'saleType': 'CASH',
          'totalAmount': 100.0,
          'paidAmount': 100.0,
          'balanceAmount': 0.0,
          'saleDate': now,
          'receiptNumber': 'RCP001',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
        });

        // Insert single sale item with unique ID (simulating the fix)
        final saleItemId = 'ITEM_${DateTime.now().millisecondsSinceEpoch}_1';
        await txn.insert('sale_items', {
          'id': saleItemId, // Unique ID generated
          'saleId': saleId,
          'productId': 'PRD001',
          'productName': 'Test Product 1',
          'quantity': 1.0,
          'unitPrice': 100.0,
          'totalPrice': 100.0,
          'packSizeSold': 1.0,
        });
      });

      print('✅ Single sale item inserted successfully');
    } catch (e) {
      print('❌ Single sale item failed: $e');
    }

    // Test 2: Multiple Sale Items with Unique IDs (should work)
    print('\n📋 Test 2: Multiple Sale Items with Unique IDs');
    print('-' * 30);

    // Insert more test stock
    await db.insert('stock', {
      'id': 'STK002',
      'productId': 'PRD002',
      'productName': 'Test Product 2',
      'currentStock': 50.0,
      'availableStock': 50.0,
      'lastUpdated': now,
      'lastUpdatedBy': 'system',
    });

    await db.insert('stock', {
      'id': 'STK003',
      'productId': 'PRD003',
      'productName': 'Test Product 3',
      'currentStock': 75.0,
      'availableStock': 75.0,
      'lastUpdated': now,
      'lastUpdatedBy': 'system',
    });

    try {
      await db.transaction((txn) async {
        final saleId = 'SALE002';

        // Insert sale
        await txn.insert('sales', {
          'id': saleId,
          'memberId': 'MEM002',
          'memberName': 'Test Member 2',
          'saleType': 'CASH',
          'totalAmount': 350.0,
          'paidAmount': 350.0,
          'balanceAmount': 0.0,
          'saleDate': now,
          'receiptNumber': 'RCP002',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
        });

        // Insert multiple sale items with unique IDs (simulating the fix)
        final baseTime = DateTime.now().millisecondsSinceEpoch;

        final saleItems = [
          {
            'id': 'ITEM_${baseTime}_1', // Unique ID
            'saleId': saleId,
            'productId': 'PRD001',
            'productName': 'Test Product 1',
            'quantity': 2.0,
            'unitPrice': 100.0,
            'totalPrice': 200.0,
            'packSizeSold': 1.0,
          },
          {
            'id': 'ITEM_${baseTime}_2', // Unique ID
            'saleId': saleId,
            'productId': 'PRD002',
            'productName': 'Test Product 2',
            'quantity': 1.0,
            'unitPrice': 75.0,
            'totalPrice': 75.0,
            'packSizeSold': 1.0,
          },
          {
            'id': 'ITEM_${baseTime}_3', // Unique ID
            'saleId': saleId,
            'productId': 'PRD003',
            'productName': 'Test Product 3',
            'quantity': 1.0,
            'unitPrice': 75.0,
            'totalPrice': 75.0,
            'packSizeSold': 1.0,
          },
        ];

        for (final item in saleItems) {
          await txn.insert('sale_items', item);
        }
      });

      print('✅ Multiple sale items with unique IDs inserted successfully');

      // Verify all items were inserted
      final saleItemsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sale_items WHERE saleId = ?',
        ['SALE002'],
      );
      final count = saleItemsCount.first['count'] as int;
      print('Sale items inserted: $count');

      if (count == 3) {
        print('✅ All 3 sale items correctly inserted');
      } else {
        print('❌ Expected 3 sale items, got $count');
      }
    } catch (e) {
      print('❌ Multiple sale items failed: $e');
    }

    // Test 3: Duplicate IDs (should fail - demonstrating the original problem)
    print('\n📋 Test 3: Duplicate IDs (Original Problem)');
    print('-' * 30);

    try {
      await db.transaction((txn) async {
        final saleId = 'SALE003';

        // Insert sale
        await txn.insert('sales', {
          'id': saleId,
          'memberId': 'MEM003',
          'memberName': 'Test Member 3',
          'saleType': 'CASH',
          'totalAmount': 200.0,
          'paidAmount': 200.0,
          'balanceAmount': 0.0,
          'saleDate': now,
          'receiptNumber': 'RCP003',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
        });

        // Try to insert sale items with duplicate IDs (simulating the original bug)
        final duplicateItems = [
          {
            'id': '', // Empty ID - causes duplicate
            'saleId': saleId,
            'productId': 'PRD001',
            'productName': 'Test Product 1',
            'quantity': 1.0,
            'unitPrice': 100.0,
            'totalPrice': 100.0,
            'packSizeSold': 1.0,
          },
          {
            'id': '', // Empty ID - causes duplicate
            'saleId': saleId,
            'productId': 'PRD002',
            'productName': 'Test Product 2',
            'quantity': 1.0,
            'unitPrice': 100.0,
            'totalPrice': 100.0,
            'packSizeSold': 1.0,
          },
        ];

        for (final item in duplicateItems) {
          await txn.insert('sale_items', item);
        }
      });

      print('❌ Duplicate IDs should have failed but didn\'t');
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        print('✅ Duplicate IDs correctly failed with unique constraint error');
        print('Error (expected): ${e.toString().substring(0, 100)}...');
      } else {
        print('❌ Unexpected error: $e');
      }
    }

    // Test 4: UUID Generation Simulation
    print('\n📋 Test 4: UUID Generation Simulation');
    print('-' * 30);

    // Simulate UUID generation (like _uuid.v4())
    String generateUuid() {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp * 1000 + (timestamp % 1000)).toString();
      return 'uuid_$random';
    }

    try {
      await db.transaction((txn) async {
        final saleId = 'SALE004';

        // Insert sale
        await txn.insert('sales', {
          'id': saleId,
          'memberId': 'MEM004',
          'memberName': 'Test Member 4',
          'saleType': 'CASH',
          'totalAmount': 300.0,
          'paidAmount': 300.0,
          'balanceAmount': 0.0,
          'saleDate': now,
          'receiptNumber': 'RCP004',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
        });

        // Insert sale items with generated UUIDs (simulating the fix)
        final uuidItems = [
          {
            'id': generateUuid(), // Generated UUID
            'saleId': saleId,
            'productId': 'PRD001',
            'productName': 'Test Product 1',
            'quantity': 2.0,
            'unitPrice': 100.0,
            'totalPrice': 200.0,
            'packSizeSold': 1.0,
          },
          {
            'id': generateUuid(), // Generated UUID
            'saleId': saleId,
            'productId': 'PRD002',
            'productName': 'Test Product 2',
            'quantity': 1.0,
            'unitPrice': 100.0,
            'totalPrice': 100.0,
            'packSizeSold': 1.0,
          },
        ];

        for (final item in uuidItems) {
          await txn.insert('sale_items', item);
          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 1));
        }
      });

      print('✅ UUID generation simulation successful');

      // Verify unique IDs were generated
      final items = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: ['SALE004'],
      );

      print('Generated IDs:');
      for (final item in items) {
        print('  - ${item['id']}');
      }

      // Check if all IDs are unique
      final ids = items.map((item) => item['id']).toSet();
      if (ids.length == items.length) {
        print('✅ All generated IDs are unique');
      } else {
        print('❌ Some generated IDs are duplicates');
      }
    } catch (e) {
      print('❌ UUID generation simulation failed: $e');
    }

    print('\n🎉 All tests completed!');
    print('=' * 50);

    // Summary
    print('\n📊 Fix Summary:');
    print('- Issue: UNIQUE constraint failed: sale_items.id');
    print('- Root cause: Sale items created with empty/duplicate IDs');
    print('- Solution: Generate unique ID for each sale item during insertion');
    print('- Implementation: Use _uuid.v4() for each sale item');

    // Clean up
    await db.close();

    // Delete test database file
    final file = File('test_sale_items_unique.db');
    if (await file.exists()) {
      await file.delete();
      print('✅ Test database cleaned up');
    }
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}
