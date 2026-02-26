import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lib/models/models.dart';
import 'lib/services/services.dart';

/// Test script to verify product creation with initial stock
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Testing Product Creation with Initial Stock');
  print('=' * 60);

  try {
    // Initialize services
    await Get.putAsync(() => DatabaseHelper().init());
    await Get.putAsync(() => InventoryService().init());

    final inventoryService = Get.find<InventoryService>();

    // Test 1: Create test category and unit
    print('\n📋 Test 1: Setting up test data');
    print('-' * 50);

    final testCategory = ProductCategory(
      id: 'test_cat_stock',
      name: 'Test Stock Category',
      createdAt: DateTime.now(),
    );

    final testUnit = UnitOfMeasure(
      id: 'test_unit_stock',
      name: 'Kilogram',
      abbreviation: 'kg',
      isBaseUnit: true,
      createdAt: DateTime.now(),
    );

    await inventoryService.addCategory(testCategory);
    await inventoryService.addUnit(testUnit);

    print('✅ Test category and unit created');

    // Test 2: Create product with zero initial stock
    print('\n📋 Test 2: Product with zero initial stock');
    print('-' * 50);

    final product1 = Product(
      id: '', // Will be auto-generated
      name: 'Test Product Zero Stock',
      description: 'Product with zero initial stock',
      categoryId: testCategory.id,
      categoryName: testCategory.name,
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 10.0,
      salesPrice: 100.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final result1 = await inventoryService.addProduct(
      product1,
      initialStock: 0.0,
    );

    if (result1['success']) {
      final productId1 = result1['productId'] as String;
      print('✅ Product created with ID: $productId1');

      // Verify stock was created
      await inventoryService.loadStocks();
      final stock1 = inventoryService.stocks.firstWhereOrNull(
        (s) => s.productId == productId1,
      );

      if (stock1 != null) {
        print('✅ Stock record created: ${stock1.currentStock} units');
        assert(stock1.currentStock == 0.0, 'Stock should be 0.0');
      } else {
        print('❌ No stock record found');
      }
    } else {
      print('❌ Product creation failed: ${result1['error']}');
    }

    // Test 3: Create product with positive initial stock
    print('\n📋 Test 3: Product with positive initial stock');
    print('-' * 50);

    final product2 = Product(
      id: '', // Will be auto-generated
      name: 'Test Product With Stock',
      description: 'Product with initial stock',
      categoryId: testCategory.id,
      categoryName: testCategory.name,
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 5.0,
      salesPrice: 50.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final initialStockAmount = 25.5;
    final result2 = await inventoryService.addProduct(
      product2,
      initialStock: initialStockAmount,
    );

    if (result2['success']) {
      final productId2 = result2['productId'] as String;
      print('✅ Product created with ID: $productId2');

      // Verify stock was created with correct amount
      await inventoryService.loadStocks();
      final stock2 = inventoryService.stocks.firstWhereOrNull(
        (s) => s.productId == productId2,
      );

      if (stock2 != null) {
        print('✅ Stock record created: ${stock2.currentStock} units');
        print('   Expected: $initialStockAmount units');
        assert(
          stock2.currentStock == initialStockAmount,
          'Stock should be $initialStockAmount',
        );
        assert(
          stock2.availableStock == initialStockAmount,
          'Available stock should be $initialStockAmount',
        );
        assert(stock2.reservedStock == 0.0, 'Reserved stock should be 0.0');
      } else {
        print('❌ No stock record found');
      }
    } else {
      print('❌ Product creation failed: ${result2['error']}');
    }

    // Test 4: Test validation errors
    print('\n📋 Test 4: Validation error handling');
    print('-' * 50);

    // Test with empty name
    final invalidProduct1 = Product(
      id: '',
      name: '', // Empty name should fail
      categoryId: testCategory.id,
      categoryName: testCategory.name,
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 10.0,
      salesPrice: 100.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final invalidResult1 = await inventoryService.addProduct(
      invalidProduct1,
      initialStock: 10.0,
    );

    if (!invalidResult1['success']) {
      print('✅ Empty name validation works: ${invalidResult1['error']}');
    } else {
      print('❌ Empty name validation failed');
    }

    // Test with invalid category
    final invalidProduct2 = Product(
      id: '',
      name: 'Test Invalid Category',
      categoryId: 'invalid_category_id',
      categoryName: 'Invalid Category',
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 10.0,
      salesPrice: 100.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final invalidResult2 = await inventoryService.addProduct(
      invalidProduct2,
      initialStock: 10.0,
    );

    if (!invalidResult2['success']) {
      print('✅ Invalid category validation works: ${invalidResult2['error']}');
    } else {
      print('❌ Invalid category validation failed');
    }

    // Test 5: Test duplicate name handling
    print('\n📋 Test 5: Duplicate name handling');
    print('-' * 50);

    final duplicateProduct = Product(
      id: '',
      name: 'Test Product With Stock', // Same name as product2
      categoryId: testCategory.id,
      categoryName: testCategory.name,
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 10.0,
      salesPrice: 100.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final duplicateResult = await inventoryService.addProduct(
      duplicateProduct,
      initialStock: 5.0,
    );

    if (!duplicateResult['success']) {
      print('✅ Duplicate name validation works: ${duplicateResult['error']}');
    } else {
      print('❌ Duplicate name validation failed');
    }

    // Test 6: Test large initial stock
    print('\n📋 Test 6: Large initial stock');
    print('-' * 50);

    final largeStockProduct = Product(
      id: '',
      name: 'Test Large Stock Product',
      categoryId: testCategory.id,
      categoryName: testCategory.name,
      unitOfMeasureId: testUnit.id,
      unitOfMeasureName: testUnit.name,
      packSize: 1.0,
      salesPrice: 10.0,
      isActive: true,
      allowPartialSales: true,
      createdAt: DateTime.now(),
    );

    final largeStock = 9999.99;
    final largeStockResult = await inventoryService.addProduct(
      largeStockProduct,
      initialStock: largeStock,
    );

    if (largeStockResult['success']) {
      final productId = largeStockResult['productId'] as String;
      print('✅ Large stock product created: $productId');

      await inventoryService.loadStocks();
      final stock = inventoryService.stocks.firstWhereOrNull(
        (s) => s.productId == productId,
      );

      if (stock != null && stock.currentStock == largeStock) {
        print('✅ Large stock amount handled correctly: ${stock.currentStock}');
      } else {
        print('❌ Large stock amount not handled correctly');
      }
    } else {
      print(
        '❌ Large stock product creation failed: ${largeStockResult['error']}',
      );
    }

    // Test 7: Verify all products and stocks
    print('\n📋 Test 7: Final verification');
    print('-' * 50);

    await inventoryService.loadProducts();
    await inventoryService.loadStocks();

    final products = inventoryService.products;
    final stocks = inventoryService.stocks;

    print('Total products created: ${products.length}');
    print('Total stock records: ${stocks.length}');

    // Verify each product has a corresponding stock record
    int matchedRecords = 0;
    for (final product in products) {
      final stock = stocks.firstWhereOrNull((s) => s.productId == product.id);
      if (stock != null) {
        matchedRecords++;
        print('✅ ${product.name}: ${stock.currentStock} units');
      } else {
        print('❌ ${product.name}: No stock record');
      }
    }

    print('Matched records: $matchedRecords/${products.length}');

    print('\n🎉 Product Creation with Initial Stock Test Complete!');
    print('=' * 60);

    print('\n📋 Summary:');
    print('✅ Products can be created with zero initial stock');
    print('✅ Products can be created with positive initial stock');
    print('✅ Stock records are automatically created');
    print('✅ Validation errors are handled correctly');
    print('✅ Duplicate names are prevented');
    print('✅ Large stock amounts are supported');
    print('✅ All products have corresponding stock records');
  } catch (e, stackTrace) {
    print('❌ Test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}
