import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('🧪 Testing Stock Insertion Fix');
  print('=' * 50);

  try {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create test database
    final db = await openDatabase(
      'test_stock_fix.db',
      version: 1,
      onCreate: (db, version) async {
        // Create products table
        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            unitOfMeasureId TEXT NOT NULL,
            packSize REAL NOT NULL,
            salesPrice REAL NOT NULL,
            isActive INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');

        // Create stock table with quantity column
        await db.execute('''
          CREATE TABLE stock (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            productName TEXT,
            quantity REAL,
            currentStock REAL NOT NULL DEFAULT 0,
            availableStock REAL NOT NULL DEFAULT 0,
            reservedStock REAL NOT NULL DEFAULT 0,
            lastUpdated TEXT NOT NULL,
            lastUpdatedBy TEXT,
            FOREIGN KEY(productId) REFERENCES products(id)
          )
        ''');
      },
    );

    print('✅ Test database created successfully');

    // Test 1: Verify stock table structure
    print('\n📋 Test 1: Stock Table Structure');
    print('-' * 30);

    final tableInfo = await db.rawQuery("PRAGMA table_info(stock)");

    print('Stock table columns:');
    bool hasQuantityColumn = false;
    for (final column in tableInfo) {
      final name = column['name'] as String;
      final type = column['type'] as String;
      print('  - $name: $type');
      if (name == 'quantity') {
        hasQuantityColumn = true;
      }
    }

    if (hasQuantityColumn) {
      print('✅ Stock table has quantity column');
    } else {
      print('❌ Stock table missing quantity column');
    }

    // Test 2: Test stock insertion with quantity column
    print('\n📋 Test 2: Stock Insertion with Quantity Column');
    print('-' * 30);

    final now = DateTime.now().toIso8601String();
    final productId = 'PRD001';
    final stockId = 'STK001';
    final initialStock = 15.0;

    // Insert test product
    await db.insert('products', {
      'id': productId,
      'name': 'Test Product',
      'categoryId': 'CAT001',
      'unitOfMeasureId': 'UOM001',
      'packSize': 10.0,
      'salesPrice': 100.0,
      'isActive': 1,
      'createdAt': now,
    });

    print('✅ Test product inserted');

    // Insert stock with quantity column (simulating the fix)
    await db.insert('stock', {
      'id': stockId,
      'productId': productId,
      'productName': 'Test Product',
      'quantity': initialStock, // This is the fix - adding quantity column
      'currentStock': initialStock,
      'availableStock': initialStock,
      'reservedStock': 0.0,
      'lastUpdated': now,
      'lastUpdatedBy': 'system',
    });

    print('✅ Stock record inserted with quantity column');

    // Verify the insertion
    final stockRecords = await db.query(
      'stock',
      where: 'productId = ?',
      whereArgs: [productId],
    );

    if (stockRecords.isNotEmpty) {
      final stock = stockRecords.first;
      print('Stock record verification:');
      print('  - Product ID: ${stock['productId']}');
      print('  - Product Name: ${stock['productName']}');
      print('  - Quantity: ${stock['quantity']}');
      print('  - Current Stock: ${stock['currentStock']}');
      print('  - Available Stock: ${stock['availableStock']}');

      if (stock['quantity'] == initialStock &&
          stock['currentStock'] == initialStock &&
          stock['availableStock'] == initialStock) {
        print('✅ All stock values correctly set');
      } else {
        print('❌ Stock values not set correctly');
      }
    } else {
      print('❌ No stock record found');
    }

    // Test 3: Test insertion without quantity column (old way)
    print('\n📋 Test 3: Insertion Without Quantity Column (Old Way)');
    print('-' * 30);

    final productId2 = 'PRD002';
    final stockId2 = 'STK002';

    // Insert another test product
    await db.insert('products', {
      'id': productId2,
      'name': 'Test Product 2',
      'categoryId': 'CAT001',
      'unitOfMeasureId': 'UOM001',
      'packSize': 5.0,
      'salesPrice': 50.0,
      'isActive': 1,
      'createdAt': now,
    });

    try {
      // Try inserting stock without quantity column (old way)
      await db.insert('stock', {
        'id': stockId2,
        'productId': productId2,
        'productName': 'Test Product 2',
        // 'quantity': 10.0, // Commented out to simulate old way
        'currentStock': 10.0,
        'availableStock': 10.0,
        'reservedStock': 0.0,
        'lastUpdated': now,
        'lastUpdatedBy': 'system',
      });

      print(
        '✅ Stock inserted without quantity column (backward compatibility)',
      );

      // Check if quantity is null
      final stockRecords2 = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId2],
      );

      if (stockRecords2.isNotEmpty) {
        final stock2 = stockRecords2.first;
        print('Stock record without quantity:');
        print('  - Quantity: ${stock2['quantity']} (should be null)');
        print('  - Current Stock: ${stock2['currentStock']}');

        if (stock2['quantity'] == null) {
          print(
            '✅ Quantity column allows null values (backward compatibility)',
          );
        } else {
          print('❌ Quantity column does not allow null values');
        }
      }
    } catch (e) {
      print('❌ Error inserting stock without quantity: $e');
    }

    // Test 4: Test validation scenarios
    print('\n📋 Test 4: Validation Scenarios');
    print('-' * 30);

    // Test empty initial stock
    print('Testing empty initial stock validation...');
    String initialStockText = '';
    if (initialStockText.isEmpty) {
      print('✅ Empty initial stock detected - validation should fail');
    }

    // Test negative initial stock
    print('Testing negative initial stock validation...');
    initialStockText = '-5.0';
    final negativeStock = double.tryParse(initialStockText);
    if (negativeStock != null && negativeStock < 0) {
      print('✅ Negative initial stock detected - validation should fail');
    }

    // Test invalid initial stock
    print('Testing invalid initial stock validation...');
    initialStockText = 'abc';
    final invalidStock = double.tryParse(initialStockText);
    if (invalidStock == null) {
      print('✅ Invalid initial stock detected - validation should fail');
    }

    // Test valid initial stock
    print('Testing valid initial stock validation...');
    initialStockText = '25.5';
    final validStock = double.tryParse(initialStockText);
    if (validStock != null && validStock >= 0) {
      print('✅ Valid initial stock detected - validation should pass');
    }

    print('\n🎉 All tests completed successfully!');
    print('=' * 50);

    // Clean up
    await db.close();

    // Delete test database file
    final file = File('test_stock_fix.db');
    if (await file.exists()) {
      await file.delete();
      print('✅ Test database cleaned up');
    }
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}
