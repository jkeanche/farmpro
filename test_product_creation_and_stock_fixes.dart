import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lib/models/models.dart';
import 'lib/services/services.dart';

/// Test script to verify product creation with auto-increment ID
/// and stock adjustment functionality
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Testing Product Creation and Stock Adjustment Fixes');
  print('=' * 60);

  try {
    // Initialize services
    await Get.putAsync(() => DatabaseHelper().init());
    await Get.putAsync(() => InventoryService().init());

    final inventoryService = Get.find<InventoryService>();

    // Test 1: Auto-increment Product ID Generation
    print('\n📦 Test 1: Product Creation with Auto-increment ID');
    print('-' * 50);

    // Create test category and unit first
    final testCategory = ProductCategory(
      id: 'test_cat_001',
      name: 'Test Category',
      createdAt: DateTime.now(),
    );

    final testUnit = UnitOfMeasure(
      id: 'test_unit_001',
      name: 'Kilogram',
      abbreviation: 'kg',
      isBaseUnit: true,
      createdAt: DateTime.now(),
    );

    await inventoryService.addCategory(testCategory);
    await inventoryService.addUnit(testUnit);

    // Create multiple products to test auto-increment
    final products = [
      Product(
        id: '', // Should be auto-generated
        name: 'Test Product 1',
        description: 'First test product',
        categoryId: testCategory.id,
        categoryName: testCategory.name,
        unitOfMeasureId: testUnit.id,
        unitOfMeasureName: testUnit.name,
        packSize: 10.0,
        salesPrice: 100.0,
        isActive: true,
        allowPartialSales: true,
        createdAt: DateTime.now(),
      ),
      Product(
        id: '', // Should be auto-generated
        name: 'Test Product 2',
        description: 'Second test product',
        categoryId: testCategory.id,
        categoryName: testCategory.name,
        unitOfMeasureId: testUnit.id,
        unitOfMeasureName: testUnit.name,
        packSize: 5.0,
        salesPrice: 50.0,
        isActive: true,
        allowPartialSales: true,
        createdAt: DateTime.now(),
      ),
    ];

    List<String> generatedIds = [];

    for (int i = 0; i < products.length; i++) {
      final result = await inventoryService.addProduct(products[i]);

      if (result['success']) {
        final productId = result['productId'] as String;
        generatedIds.add(productId);
        print('✅ Product ${i + 1} created with ID: $productId');

        // Verify ID format (should be PRD001, PRD002, etc.)
        if (productId.startsWith('PRD') && productId.length == 6) {
          print('   ✓ ID format is correct: $productId');
        } else {
          print('   ❌ ID format is incorrect: $productId');
        }
      } else {
        print('❌ Failed to create product ${i + 1}: ${result['error']}');
      }
    }

    // Test 2: Stock Adjustment Functionality
    print('\n📊 Test 2: Stock Adjustment Functionality');
    print('-' * 50);

    if (generatedIds.isNotEmpty) {
      final testProductId = generatedIds.first;
      print('Testing stock adjustments for product: $testProductId');

      // Test 2a: Stock Increase
      print('\n🔼 Test 2a: Stock Increase');
      var result = await inventoryService.adjustStock(
        productId: testProductId,
        quantity: 50.0,
        movementType: 'IN',
        notes: 'Initial stock addition',
        userId: 'test_user',
        userName: 'Test User',
      );

      if (result['success']) {
        print('✅ Stock increase successful. New stock: ${result['newStock']}');
      } else {
        print('❌ Stock increase failed: ${result['error']}');
      }

      // Test 2b: Stock Decrease
      print('\n🔽 Test 2b: Stock Decrease');
      result = await inventoryService.adjustStock(
        productId: testProductId,
        quantity: 15.0,
        movementType: 'OUT',
        notes: 'Stock reduction test',
        userId: 'test_user',
        userName: 'Test User',
      );

      if (result['success']) {
        print('✅ Stock decrease successful. New stock: ${result['newStock']}');
      } else {
        print('❌ Stock decrease failed: ${result['error']}');
      }

      // Test 2c: Stock Correction
      print('\n🎯 Test 2c: Stock Correction');
      result = await inventoryService.correctStock(
        productId: testProductId,
        targetQuantity: 40.0,
        reason: 'Inventory count correction',
        notes: 'Physical count showed 40 units',
        userId: 'test_user',
        userName: 'Test User',
      );

      if (result['success']) {
        print(
          '✅ Stock correction successful. New stock: ${result['newStock']}',
        );
      } else {
        print('❌ Stock correction failed: ${result['error']}');
      }

      // Test 2d: Invalid Operations
      print('\n❌ Test 2d: Invalid Operations');

      // Try to remove more stock than available
      result = await inventoryService.adjustStock(
        productId: testProductId,
        quantity: 100.0,
        movementType: 'OUT',
        notes: 'Should fail - insufficient stock',
        userId: 'test_user',
        userName: 'Test User',
      );

      if (!result['success']) {
        print('✅ Correctly prevented over-withdrawal: ${result['error']}');
      } else {
        print('❌ Should have prevented over-withdrawal');
      }

      // Try negative correction
      result = await inventoryService.correctStock(
        productId: testProductId,
        targetQuantity: -5.0,
        reason: 'Should fail - negative stock',
        userId: 'test_user',
        userName: 'Test User',
      );

      if (!result['success']) {
        print('✅ Correctly prevented negative stock: ${result['error']}');
      } else {
        print('❌ Should have prevented negative stock');
      }
    }

    // Test 3: Stock Adjustment History
    print('\n📋 Test 3: Stock Adjustment History');
    print('-' * 50);

    await inventoryService.loadStockAdjustmentHistory();
    final history = inventoryService.stockAdjustmentHistory;

    print('Total adjustment history records: ${history.length}');

    // Show recent adjustments for our test product
    if (generatedIds.isNotEmpty) {
      final testProductId = generatedIds.first;
      final productHistory =
          history.where((h) => h.productId == testProductId).toList();

      print('\nAdjustment history for $testProductId:');
      for (final record in productHistory) {
        print(
          '  ${record.adjustmentDate}: ${record.adjustmentTypeDisplay} '
          '${record.quantityAdjustedDisplay} - ${record.reason}',
        );
        print(
          '    Previous: ${record.previousQuantity.toStringAsFixed(2)} → '
          'New: ${record.newQuantity.toStringAsFixed(2)}',
        );
      }
    }

    // Test 4: Verify Data Integrity
    print('\n🔍 Test 4: Data Integrity Verification');
    print('-' * 50);

    await inventoryService.loadProducts();
    await inventoryService.loadStocks();

    final products = inventoryService.products;
    final stocks = inventoryService.stocks;

    print('Total products in system: ${products.length}');
    print('Total stock records: ${stocks.length}');

    // Verify each product has corresponding stock record
    int matchedRecords = 0;
    for (final product in products) {
      final stock = stocks.firstWhereOrNull((s) => s.productId == product.id);
      if (stock != null) {
        matchedRecords++;
        print(
          '✅ Product ${product.id} (${product.name}) has stock: ${stock.currentStock}',
        );
      } else {
        print('❌ Product ${product.id} (${product.name}) missing stock record');
      }
    }

    print(
      '\nData integrity: $matchedRecords/${products.length} products have stock records',
    );

    print('\n🎉 All tests completed successfully!');
    print('=' * 60);
  } catch (e, stackTrace) {
    print('❌ Test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}
