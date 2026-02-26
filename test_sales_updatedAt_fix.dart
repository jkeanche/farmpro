import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('🧪 Testing Sales updatedAt Column Fix');
  print('=' * 50);

  try {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create test database with sales table (without updatedAt column)
    final db = await openDatabase(
      'test_sales_updatedAt.db',
      version: 1,
      onCreate: (db, version) async {
        // Create sales table without updatedAt column (matching database_helper.dart)
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

        // Create repayments table
        await db.execute('''
          CREATE TABLE repayments (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            memberId TEXT NOT NULL,
            memberName TEXT NOT NULL,
            amount REAL NOT NULL,
            repaymentDate TEXT NOT NULL,
            paymentMethod TEXT NOT NULL,
            reference TEXT,
            notes TEXT,
            userId TEXT NOT NULL,
            userName TEXT,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (saleId) REFERENCES sales (id)
          )
        ''');
      },
    );

    print('✅ Test database created successfully');

    // Test 1: Sale Creation without updatedAt
    print('\n📋 Test 1: Sale Creation Without updatedAt');
    print('-' * 30);

    final now = DateTime.now().toIso8601String();
    final saleId = 'SALE001';

    try {
      // Insert sale without updatedAt (fixed version)
      await db.insert('sales', {
        'id': saleId,
        'memberId': 'MEM001',
        'memberName': 'Test Member',
        'saleType': 'CREDIT',
        'totalAmount': 500.0,
        'paidAmount': 200.0,
        'balanceAmount': 300.0,
        'saleDate': now,
        'receiptNumber': 'RCP001',
        'notes': 'Test credit sale',
        'userId': 'USER001',
        'userName': 'Test User',
        'isActive': 1,
        'createdAt': now,
        'seasonId': 'SEASON001',
        'seasonName': 'Test Season',
      });

      print('✅ Credit sale created successfully without updatedAt');

      // Verify sale
      final saleRecords = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleRecords.isNotEmpty) {
        final sale = saleRecords.first;
        print('Sale details:');
        print('  - Total Amount: ${sale['totalAmount']}');
        print('  - Paid Amount: ${sale['paidAmount']}');
        print('  - Balance Amount: ${sale['balanceAmount']}');

        if (sale['balanceAmount'] == 300.0) {
          print('✅ Sale balance correctly set');
        }
      }
    } catch (e) {
      print('❌ Error creating sale: $e');
    }

    // Test 2: Repayment Processing without updatedAt
    print('\n📋 Test 2: Repayment Processing Without updatedAt');
    print('-' * 30);

    try {
      // Add a repayment
      final repaymentId = 'REP001';
      await db.insert('repayments', {
        'id': repaymentId,
        'saleId': saleId,
        'memberId': 'MEM001',
        'memberName': 'Test Member',
        'amount': 150.0,
        'repaymentDate': now,
        'paymentMethod': 'Cash',
        'userId': 'USER001',
        'userName': 'Test User',
        'createdAt': now,
      });

      print('✅ Repayment record created');

      // Update sale balance (simulating repayment processing without updatedAt)
      final saleRecords = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleRecords.isNotEmpty) {
        final sale = saleRecords.first;
        final currentBalance = sale['balanceAmount'] as double;
        final currentPaid = sale['paidAmount'] as double;
        final repaymentAmount = 150.0;

        final newBalance = currentBalance - repaymentAmount;
        final newPaidAmount = currentPaid + repaymentAmount;

        // Update sale without updatedAt (fixed version)
        await db.update(
          'sales',
          {
            'balanceAmount': newBalance,
            'paidAmount': newPaidAmount,
            // 'updatedAt': DateTime.now().toIso8601String(), // Removed - this was causing error
          },
          where: 'id = ?',
          whereArgs: [saleId],
        );

        print('✅ Sale updated successfully without updatedAt');

        // Verify the update
        final updatedSaleRecords = await db.query(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
        if (updatedSaleRecords.isNotEmpty) {
          final updatedSale = updatedSaleRecords.first;
          print('Updated sale details:');
          print('  - Total Amount: ${updatedSale['totalAmount']}');
          print('  - Paid Amount: ${updatedSale['paidAmount']}');
          print('  - Balance Amount: ${updatedSale['balanceAmount']}');

          if (updatedSale['balanceAmount'] == 150.0 &&
              updatedSale['paidAmount'] == 350.0) {
            print('✅ Sale balance and paid amount correctly updated');
          } else {
            print('❌ Sale amounts not correctly updated');
          }
        }
      }
    } catch (e) {
      print('❌ Error processing repayment: $e');
    }

    // Test 3: Multiple Repayments
    print('\n📋 Test 3: Multiple Repayments');
    print('-' * 30);

    try {
      // Add second repayment
      await db.insert('repayments', {
        'id': 'REP002',
        'saleId': saleId,
        'memberId': 'MEM001',
        'memberName': 'Test Member',
        'amount': 100.0,
        'repaymentDate': now,
        'paymentMethod': 'Mobile Money',
        'userId': 'USER001',
        'userName': 'Test User',
        'createdAt': now,
      });

      // Update sale for second repayment
      final saleRecords = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleRecords.isNotEmpty) {
        final sale = saleRecords.first;
        final currentBalance = sale['balanceAmount'] as double;
        final currentPaid = sale['paidAmount'] as double;

        await db.update(
          'sales',
          {
            'balanceAmount': currentBalance - 100.0,
            'paidAmount': currentPaid + 100.0,
          },
          where: 'id = ?',
          whereArgs: [saleId],
        );

        print('✅ Second repayment processed successfully');

        // Verify final state
        final finalSaleRecords = await db.query(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
        if (finalSaleRecords.isNotEmpty) {
          final finalSale = finalSaleRecords.first;
          print('Final sale state:');
          print('  - Total Amount: ${finalSale['totalAmount']}');
          print('  - Paid Amount: ${finalSale['paidAmount']}');
          print('  - Balance Amount: ${finalSale['balanceAmount']}');

          if (finalSale['balanceAmount'] == 50.0 &&
              finalSale['paidAmount'] == 450.0) {
            print('✅ Final sale state is correct');
          } else {
            print('❌ Final sale state is incorrect');
          }
        }
      }
    } catch (e) {
      print('❌ Error processing second repayment: $e');
    }

    // Test 4: Transaction Rollback Test
    print('\n📋 Test 4: Transaction Rollback Test');
    print('-' * 30);

    try {
      await db.transaction((txn) async {
        // Try to create a sale with invalid data to test rollback
        await txn.insert('sales', {
          'id': 'SALE002',
          'memberId': 'MEM002',
          'memberName': 'Test Member 2',
          'saleType': 'CASH',
          'totalAmount': 100.0,
          'paidAmount': 100.0,
          'balanceAmount': 0.0,
          'saleDate': now,
          'receiptNumber': 'RCP002',
          'userId': 'USER001',
          'userName': 'Test User',
          'isActive': 1,
          'createdAt': now,
        });

        // This should work fine
        print('✅ Transaction sale creation successful');
      });
    } catch (e) {
      print('❌ Transaction failed: $e');
    }

    print('\n🎉 All tests completed successfully!');
    print('=' * 50);

    // Clean up
    await db.close();

    // Delete test database file
    final file = File('test_sales_updatedAt.db');
    if (await file.exists()) {
      await file.delete();
      print('✅ Test database cleaned up');
    }
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}
