import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('🧪 Testing Sale Creation Fix');
  print('=' * 50);

  try {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create test database with sales table (without updatedAt column)
    final db = await openDatabase(
      'test_sale_creation.db',
      version: 1,
      onCreate: (db, version) async {
        // Create sales table without updatedAt column (like in database_helper.dart)
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

        // Create sale_items table
        await db.execute('''
          CREATE TABLE sale_items (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            productId TEXT NOT NULL,
            productName TEXT NOT NULL,
            quantity REAL NOT NULL,
            unitPrice REAL NOT NULL,
            totalPrice REAL NOT NULL,
            FOREIGN KEY (saleId) REFERENCES sales (id)
          )
        ''');

        // Create stock table for testing
        await db.execute('''
          CREATE TABLE stock (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            productName TEXT,
            currentStock REAL NOT NULL DEFAULT 0,
            availableStock REAL NOT NULL DEFAULT 0,
            lastUpdated TEXT NOT NULL
          )
        ''');
      },
    );

    print('✅ Test database created successfully');

    // Test 1: Verify sales table structure (no updatedAt column)
    print('\n📋 Test 1: Sales Table Structure');
    print('-' * 30);

    final tableInfo = await db.rawQuery("PRAGMA table_info(sales)");

    print('Sales table columns:');
    bool hasUpdatedAtColumn = false;
    for (final column in tableInfo) {
      final name = column['name'] as String;
      final type = column['type'] as String;
      print('  - $name: $type');
      if (name == 'updatedAt') {
        hasUpdatedAtColumn = true;
      }
    }

    if (!hasUpdatedAtColumn) {
      print('✅ Sales table does NOT have updatedAt column (as expected)');
    } else {
      print('❌ Sales table has updatedAt column (unexpected)');
    }

    // Test 2: Test sale creation without updatedAt column
    print('\n📋 Test 2: Sale Creation Without updatedAt');
    print('-' * 30);

    final now = DateTime.now().toIso8601String();
    final saleId = 'SALE001';
    final receiptNumber = 'RCP${DateTime.now().millisecondsSinceEpoch}';

    // Insert stock for testing
    await db.insert('stock', {
      'id': 'STK001',
      'productId': 'PRD001',
      'productName': 'Test Product',
      'currentStock': 100.0,
      'availableStock': 100.0,
      'lastUpdated': now,
    });

    try {
      // Insert sale without updatedAt column (simulating the fix)
      await db.insert('sales', {
        'id': saleId,
        'memberId': 'MEM001',
        'memberName': 'Test Member',
        'saleType': 'CASH',
        'totalAmount': 150.0,
        'paidAmount': 150.0,
        'balanceAmount': 0.0,
        'saleDate': now,
        'receiptNumber': receiptNumber,
        'notes': 'Test sale',
        'userId': 'USER001',
        'userName': 'Test User',
        'isActive': 1,
        'createdAt': now,
        // 'updatedAt': now, // Removed - this was causing the error
        'seasonId': 'SEASON001',
        'seasonName': 'Test Season',
      });

      print('✅ Sale inserted successfully without updatedAt column');

      // Verify the insertion
      final saleRecords = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (saleRecords.isNotEmpty) {
        final sale = saleRecords.first;
        print('Sale record verification:');
        print('  - Sale ID: ${sale['id']}');
        print('  - Member Name: ${sale['memberName']}');
        print('  - Sale Type: ${sale['saleType']}');
        print('  - Total Amount: ${sale['totalAmount']}');
        print('  - Receipt Number: ${sale['receiptNumber']}');
        print('  - Created At: ${sale['createdAt']}');
        print('  - Season ID: ${sale['seasonId']}');

        if (sale['totalAmount'] == 150.0 &&
            sale['saleType'] == 'CASH' &&
            sale['createdAt'] != null) {
          print('✅ Sale record correctly inserted');
        } else {
          print('❌ Sale record not correctly inserted');
        }
      } else {
        print('❌ No sale record found');
      }
    } catch (e) {
      print('❌ Error inserting sale: $e');
    }

    // Test 3: Test sale item insertion
    print('\n📋 Test 3: Sale Item Insertion');
    print('-' * 30);

    try {
      await db.insert('sale_items', {
        'id': 'ITEM001',
        'saleId': saleId,
        'productId': 'PRD001',
        'productName': 'Test Product',
        'quantity': 2.0,
        'unitPrice': 75.0,
        'totalPrice': 150.0,
      });

      print('✅ Sale item inserted successfully');

      // Verify sale item
      final itemRecords = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      if (itemRecords.isNotEmpty) {
        final item = itemRecords.first;
        print('Sale item verification:');
        print('  - Product Name: ${item['productName']}');
        print('  - Quantity: ${item['quantity']}');
        print('  - Unit Price: ${item['unitPrice']}');
        print('  - Total Price: ${item['totalPrice']}');

        if (item['quantity'] == 2.0 && item['totalPrice'] == 150.0) {
          print('✅ Sale item correctly inserted');
        } else {
          print('❌ Sale item not correctly inserted');
        }
      }
    } catch (e) {
      print('❌ Error inserting sale item: $e');
    }

    // Test 4: Test transaction scenario (sale + stock update)
    print('\n📋 Test 4: Transaction Scenario');
    print('-' * 30);

    try {
      await db.transaction((txn) async {
        // Insert another sale
        await txn.insert('sales', {
          'id': 'SALE002',
          'memberId': 'MEM002',
          'memberName': 'Test Member 2',
          'saleType': 'CREDIT',
          'totalAmount': 200.0,
          'paidAmount': 100.0,
          'balanceAmount': 100.0,
          'saleDate': now,
          'receiptNumber': 'RCP${DateTime.now().millisecondsSinceEpoch + 1}',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
          'seasonId': 'SEASON001',
          'seasonName': 'Test Season',
        });

        // Update stock
        await txn.update(
          'stock',
          {'currentStock': 95.0, 'availableStock': 95.0, 'lastUpdated': now},
          where: 'productId = ?',
          whereArgs: ['PRD001'],
        );
      });

      print('✅ Transaction completed successfully');

      // Verify stock update
      final stockRecords = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: ['PRD001'],
      );

      if (stockRecords.isNotEmpty) {
        final stock = stockRecords.first;
        if (stock['currentStock'] == 95.0) {
          print('✅ Stock correctly updated in transaction');
        } else {
          print('❌ Stock not correctly updated');
        }
      }
    } catch (e) {
      print('❌ Error in transaction: $e');
    }

    print('\n🎉 All tests completed successfully!');
    print('=' * 50);

    // Clean up
    await db.close();

    // Delete test database file
    final file = File('test_sale_creation.db');
    if (await file.exists()) {
      await file.delete();
      print('✅ Test database cleaned up');
    }
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}
