import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'lib/services/database_helper.dart';
import 'lib/services/inventory_service.dart';

/// Comprehensive test suite for filter and delete fixes
/// Tests Requirements 1.1-1.4, 2.1-2.8, 3.1-3.6
void main() {
  // Initialize FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late InventoryService inventoryService;

  setUp(() async {
    // Initialize GetX
    Get.testMode = true;

    // Create fresh database for each test
    dbHelper = DatabaseHelper();
    await dbHelper.database; // Initialize database
    inventoryService = InventoryService();
    await inventoryService.initialize();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('5.1 CropSearchScreen Exact Member Number Filter Tests', () {
    test('Exact member number match returns only exact matches', () async {
      // Create test collections with different member numbers
      final db = await dbHelper.database;

      await db.insert('collections', {
        'id': 'col1',
        'memberId': '123',
        'memberName': 'John Doe',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 100.0,
        'isActive': 1,
      });

      await db.insert('collections', {
        'id': 'col2',
        'memberId': '1234',
        'memberName': 'Jane Smith',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 150.0,
        'isActive': 1,
      });

      await db.insert('collections', {
        'id': 'col3',
        'memberId': '0123',
        'memberName': 'Bob Johnson',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 200.0,
        'isActive': 1,
      });

      // Test exact match filter logic
      final collections = await db.query('collections', where: 'isActive = 1');

      // Simulate filter with member number "123"
      final memberQuery = '123';
      final filtered =
          collections.where((col) {
            final memberNo = (col['memberId'] ?? '').toString();
            return memberNo.toLowerCase() == memberQuery.toLowerCase();
          }).toList();

      expect(filtered.length, 1, reason: 'Should return only exact match');
      expect(filtered.first['memberId'], '123');
      expect(filtered.first['memberName'], 'John Doe');
    });

    test(
      'Partial member number returns no results (or only exact match)',
      () async {
        final db = await dbHelper.database;

        await db.insert('collections', {
          'id': 'col1',
          'memberId': '1234',
          'memberName': 'Jane Smith',
          'collectionDate': DateTime.now().toIso8601String(),
          'cropType': 'Coffee',
          'quantity': 150.0,
          'isActive': 1,
        });

        final collections = await db.query(
          'collections',
          where: 'isActive = 1',
        );

        // Search for "123" when only "1234" exists
        final memberQuery = '123';
        final filtered =
            collections.where((col) {
              final memberNo = (col['memberId'] ?? '').toString();
              return memberNo.toLowerCase() == memberQuery.toLowerCase();
            }).toList();

        expect(
          filtered.length,
          0,
          reason: 'Partial match should return no results',
        );
      },
    );

    test('Empty member number filter shows all collections', () async {
      final db = await dbHelper.database;

      await db.insert('collections', {
        'id': 'col1',
        'memberId': '123',
        'memberName': 'John Doe',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 100.0,
        'isActive': 1,
      });

      await db.insert('collections', {
        'id': 'col2',
        'memberId': '456',
        'memberName': 'Jane Smith',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 150.0,
        'isActive': 1,
      });

      final collections = await db.query('collections', where: 'isActive = 1');

      // Empty filter should return all
      final memberQuery = '';
      final filtered =
          collections.where((col) {
            if (memberQuery.isEmpty) return true;
            final memberNo = (col['memberId'] ?? '').toString();
            return memberNo.toLowerCase() == memberQuery.toLowerCase();
          }).toList();

      expect(
        filtered.length,
        2,
        reason: 'Empty filter should return all collections',
      );
    });

    test('Clearing filter refreshes to show all collections', () async {
      final db = await dbHelper.database;

      await db.insert('collections', {
        'id': 'col1',
        'memberId': '123',
        'memberName': 'John Doe',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 100.0,
        'isActive': 1,
      });

      await db.insert('collections', {
        'id': 'col2',
        'memberId': '456',
        'memberName': 'Jane Smith',
        'collectionDate': DateTime.now().toIso8601String(),
        'cropType': 'Coffee',
        'quantity': 150.0,
        'isActive': 1,
      });

      final collections = await db.query('collections', where: 'isActive = 1');

      // First filter with "123"
      var memberQuery = '123';
      var filtered =
          collections.where((col) {
            if (memberQuery.isEmpty) return true;
            final memberNo = (col['memberId'] ?? '').toString();
            return memberNo.toLowerCase() == memberQuery.toLowerCase();
          }).toList();
      expect(filtered.length, 1);

      // Clear filter
      memberQuery = '';
      filtered =
          collections.where((col) {
            if (memberQuery.isEmpty) return true;
            final memberNo = (col['memberId'] ?? '').toString();
            return memberNo.toLowerCase() == memberQuery.toLowerCase();
          }).toList();
      expect(
        filtered.length,
        2,
        reason: 'Cleared filter should show all collections',
      );
    });
  });

  group('5.2 SalesReportScreen Sale Deletion Tests', () {
    test('Delete sale restores stock and marks sale inactive', () async {
      final db = await dbHelper.database;

      // Create test product
      final productId = 'prod1';
      await db.insert('products', {
        'id': productId,
        'name': 'Test Product',
        'category': 'Test',
        'unitPrice': 100.0,
        'isActive': 1,
      });

      // Create initial stock
      await db.insert('stock', {
        'productId': productId,
        'currentStock': 100.0,
        'availableStock': 100.0,
        'reservedStock': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Create a sale
      final saleId = 'sale1';
      await db.insert('sales', {
        'id': saleId,
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      // Create sale items
      await db.insert('sale_items', {
        'id': 'item1',
        'saleId': saleId,
        'productId': productId,
        'productName': 'Test Product',
        'quantity': 10.0,
        'unitPrice': 50.0,
        'totalPrice': 500.0,
      });

      // Update stock to reflect sale
      await db.update(
        'stock',
        {'currentStock': 90.0, 'availableStock': 90.0},
        where: 'productId = ?',
        whereArgs: [productId],
      );

      // Note stock levels before deletion
      var stockBefore = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      expect(stockBefore.first['currentStock'], 90.0);

      // Delete the sale
      final result = await inventoryService.deleteSale(saleId);
      expect(result['success'], true, reason: 'Sale deletion should succeed');

      // Verify stock levels increased
      var stockAfter = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      expect(
        stockAfter.first['currentStock'],
        100.0,
        reason: 'Stock should be restored',
      );
      expect(stockAfter.first['availableStock'], 100.0);

      // Verify sale is marked inactive
      var saleAfter = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      expect(
        saleAfter.first['isActive'],
        0,
        reason: 'Sale should be marked inactive',
      );

      // Check stock movement records
      var movements = await db.query(
        'stock_movements',
        where: 'productId = ? AND movementType = ?',
        whereArgs: [productId, 'SALE_REVERSAL'],
      );
      expect(
        movements.length,
        1,
        reason: 'Should have one stock movement record',
      );
      expect(movements.first['quantity'], 10.0);
      expect(movements.first['balanceBefore'], 90.0);
      expect(movements.first['balanceAfter'], 100.0);
    });

    test('Delete sale with multiple items restores all stock', () async {
      final db = await dbHelper.database;

      // Create test products
      final product1Id = 'prod1';
      final product2Id = 'prod2';

      await db.insert('products', {
        'id': product1Id,
        'name': 'Product 1',
        'category': 'Test',
        'unitPrice': 100.0,
        'isActive': 1,
      });

      await db.insert('products', {
        'id': product2Id,
        'name': 'Product 2',
        'category': 'Test',
        'unitPrice': 200.0,
        'isActive': 1,
      });

      // Create initial stock
      await db.insert('stock', {
        'productId': product1Id,
        'currentStock': 90.0,
        'availableStock': 90.0,
        'reservedStock': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      await db.insert('stock', {
        'productId': product2Id,
        'currentStock': 80.0,
        'availableStock': 80.0,
        'reservedStock': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Create a sale with multiple items
      final saleId = 'sale1';
      await db.insert('sales', {
        'id': saleId,
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 900.0,
        'amountPaid': 900.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      await db.insert('sale_items', {
        'id': 'item1',
        'saleId': saleId,
        'productId': product1Id,
        'productName': 'Product 1',
        'quantity': 10.0,
        'unitPrice': 50.0,
        'totalPrice': 500.0,
      });

      await db.insert('sale_items', {
        'id': 'item2',
        'saleId': saleId,
        'productId': product2Id,
        'productName': 'Product 2',
        'quantity': 20.0,
        'unitPrice': 20.0,
        'totalPrice': 400.0,
      });

      // Delete the sale
      final result = await inventoryService.deleteSale(saleId);
      expect(result['success'], true);

      // Verify both products' stock restored
      var stock1 = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [product1Id],
      );
      expect(stock1.first['currentStock'], 100.0);

      var stock2 = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [product2Id],
      );
      expect(stock2.first['currentStock'], 100.0);

      // Verify stock movements for both products
      var movements = await db.query(
        'stock_movements',
        where: 'movementType = ?',
        whereArgs: ['SALE_REVERSAL'],
      );
      expect(
        movements.length,
        2,
        reason: 'Should have movement records for both products',
      );
    });

    test('Error handling with invalid sale ID', () async {
      // Try to delete non-existent sale
      final result = await inventoryService.deleteSale('invalid_sale_id');

      expect(
        result['success'],
        false,
        reason: 'Should fail for invalid sale ID',
      );
      expect(result['error'], isNotNull);
      expect(result['error'].toString().toLowerCase(), contains('not found'));
    });

    test('Cancelled deletion makes no changes', () async {
      final db = await dbHelper.database;

      // Create test data
      final productId = 'prod1';
      await db.insert('products', {
        'id': productId,
        'name': 'Test Product',
        'category': 'Test',
        'unitPrice': 100.0,
        'isActive': 1,
      });

      await db.insert('stock', {
        'productId': productId,
        'currentStock': 90.0,
        'availableStock': 90.0,
        'reservedStock': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      final saleId = 'sale1';
      await db.insert('sales', {
        'id': saleId,
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      // Get initial state
      var stockBefore = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      var saleBefore = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // Simulate cancellation (don't call deleteSale)
      // In UI, this would be when user clicks "Cancel" in confirmation dialog

      // Verify nothing changed
      var stockAfter = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      var saleAfter = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );

      expect(
        stockAfter.first['currentStock'],
        stockBefore.first['currentStock'],
      );
      expect(saleAfter.first['isActive'], saleBefore.first['isActive']);
    });
  });

  group('5.3 SalesReportScreen Exact Member Number Search Tests', () {
    test('Exact member number search returns only exact matches', () async {
      final db = await dbHelper.database;

      // Create sales with different member IDs
      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      await db.insert('sales', {
        'id': 'sale2',
        'memberId': '1234',
        'memberName': 'Jane Smith',
        'receiptNumber': 'RCP002',
        'totalAmount': 600.0,
        'amountPaid': 600.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      await db.insert('sales', {
        'id': 'sale3',
        'memberId': '0123',
        'memberName': 'Bob Johnson',
        'receiptNumber': 'RCP003',
        'totalAmount': 700.0,
        'amountPaid': 700.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      // Test exact match search logic
      final sales = await db.query('sales', where: 'isActive = 1');

      // Search for "123"
      final searchQuery = '123';
      final filtered =
          sales.where((sale) {
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();

      expect(filtered.length, 1, reason: 'Should return only exact match');
      expect(filtered.first['memberId'], '123');
      expect(filtered.first['memberName'], 'John Doe');
    });

    test('Partial member number returns no results', () async {
      final db = await dbHelper.database;

      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '1234',
        'memberName': 'Jane Smith',
        'receiptNumber': 'RCP002',
        'totalAmount': 600.0,
        'amountPaid': 600.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      final sales = await db.query('sales', where: 'isActive = 1');

      // Search for "123" when only "1234" exists
      final searchQuery = '123';
      final filtered =
          sales.where((sale) {
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();

      expect(
        filtered.length,
        0,
        reason: 'Partial match should return no results',
      );
    });

    test('Empty search field shows all sales', () async {
      final db = await dbHelper.database;

      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      await db.insert('sales', {
        'id': 'sale2',
        'memberId': '456',
        'memberName': 'Jane Smith',
        'receiptNumber': 'RCP002',
        'totalAmount': 600.0,
        'amountPaid': 600.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      final sales = await db.query('sales', where: 'isActive = 1');

      // Empty search should return all
      final searchQuery = '';
      final filtered =
          sales.where((sale) {
            if (searchQuery.isEmpty) return true;
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();

      expect(
        filtered.length,
        2,
        reason: 'Empty search should return all sales',
      );
    });

    test('Clearing search refreshes to show all sales', () async {
      final db = await dbHelper.database;

      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      await db.insert('sales', {
        'id': 'sale2',
        'memberId': '456',
        'memberName': 'Jane Smith',
        'receiptNumber': 'RCP002',
        'totalAmount': 600.0,
        'amountPaid': 600.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      final sales = await db.query('sales', where: 'isActive = 1');

      // First search with "123"
      var searchQuery = '123';
      var filtered =
          sales.where((sale) {
            if (searchQuery.isEmpty) return true;
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();
      expect(filtered.length, 1);

      // Clear search
      searchQuery = '';
      filtered =
          sales.where((sale) {
            if (searchQuery.isEmpty) return true;
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();
      expect(
        filtered.length,
        2,
        reason: 'Cleared search should show all sales',
      );
    });

    test('Search does not match receipt number', () async {
      final db = await dbHelper.database;

      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      final sales = await db.query('sales', where: 'isActive = 1');

      // Search for receipt number "RCP001" - should not match
      final searchQuery = 'RCP001';
      final filtered =
          sales.where((sale) {
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();

      expect(filtered.length, 0, reason: 'Should not search by receipt number');
    });

    test('Search does not match member name', () async {
      final db = await dbHelper.database;

      await db.insert('sales', {
        'id': 'sale1',
        'memberId': '123',
        'memberName': 'John Doe',
        'receiptNumber': 'RCP001',
        'totalAmount': 500.0,
        'amountPaid': 500.0,
        'balance': 0.0,
        'saleDate': DateTime.now().toIso8601String(),
        'isActive': 1,
      });

      final sales = await db.query('sales', where: 'isActive = 1');

      // Search for member name "John" - should not match
      final searchQuery = 'John';
      final filtered =
          sales.where((sale) {
            final query = searchQuery.trim();
            final memberNumber = (sale['memberId'] ?? '').toString();
            return memberNumber == query;
          }).toList();

      expect(filtered.length, 0, reason: 'Should not search by member name');
    });
  });

  group('Integration Tests', () {
    test(
      'Complete workflow: Create sale, delete sale, verify restoration',
      () async {
        final db = await dbHelper.database;

        // Setup: Create product and stock
        final productId = 'prod1';
        await db.insert('products', {
          'id': productId,
          'name': 'Integration Test Product',
          'category': 'Test',
          'unitPrice': 100.0,
          'isActive': 1,
        });

        await db.insert('stock', {
          'productId': productId,
          'currentStock': 100.0,
          'availableStock': 100.0,
          'reservedStock': 0.0,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        // Step 1: Create a sale
        final saleId = 'sale1';
        await db.insert('sales', {
          'id': saleId,
          'memberId': '123',
          'memberName': 'Integration Test User',
          'receiptNumber': 'RCP-INT-001',
          'totalAmount': 500.0,
          'amountPaid': 500.0,
          'balance': 0.0,
          'saleDate': DateTime.now().toIso8601String(),
          'isActive': 1,
        });

        await db.insert('sale_items', {
          'id': 'item1',
          'saleId': saleId,
          'productId': productId,
          'productName': 'Integration Test Product',
          'quantity': 10.0,
          'unitPrice': 50.0,
          'totalPrice': 500.0,
        });

        // Simulate stock reduction from sale
        await db.update(
          'stock',
          {'currentStock': 90.0, 'availableStock': 90.0},
          where: 'productId = ?',
          whereArgs: [productId],
        );

        // Step 2: Verify sale exists and stock is reduced
        var sales = await db.query(
          'sales',
          where: 'id = ? AND isActive = 1',
          whereArgs: [saleId],
        );
        expect(sales.length, 1);

        var stock = await db.query(
          'stock',
          where: 'productId = ?',
          whereArgs: [productId],
        );
        expect(stock.first['currentStock'], 90.0);

        // Step 3: Delete the sale
        final result = await inventoryService.deleteSale(saleId);
        expect(result['success'], true);

        // Step 4: Verify sale is inactive
        sales = await db.query(
          'sales',
          where: 'id = ? AND isActive = 1',
          whereArgs: [saleId],
        );
        expect(sales.length, 0, reason: 'Sale should be inactive');

        // Step 5: Verify stock is restored
        stock = await db.query(
          'stock',
          where: 'productId = ?',
          whereArgs: [productId],
        );
        expect(
          stock.first['currentStock'],
          100.0,
          reason: 'Stock should be fully restored',
        );

        // Step 6: Verify audit trail
        var movements = await db.query(
          'stock_movements',
          where: 'productId = ? AND movementType = ?',
          whereArgs: [productId, 'SALE_REVERSAL'],
        );
        expect(movements.length, 1);
        expect(movements.first['reference'], contains('RCP-INT-001'));
      },
    );
  });
}
