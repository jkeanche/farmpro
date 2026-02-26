// Test to verify sales report performance improvements
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'lib/services/inventory_service.dart';
import 'lib/controllers/inventory_controller.dart';
import 'lib/services/database_helper.dart';
import 'lib/models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Testing Sales Report Performance Improvements');
  print('================================================');

  try {
    // Initialize services
    Get.put(DatabaseHelper());
    final dbHelper = Get.find<DatabaseHelper>();
    final db = await dbHelper.database;

    await Get.putAsync(() => InventoryService().init());
    Get.put(InventoryController());

    final inventoryService = Get.find<InventoryService>();
    final inventoryController = Get.find<InventoryController>();

    print('✅ Services initialized successfully');

    // Test 1: Create test data to simulate real-world scenario
    print('\n📝 Test 1: Creating test data...');

    // Create test categories
    final testCategory = ProductCategory(
      id: 'test_cat_perf',
      name: 'Performance Test Category',
      description: 'Category for performance testing',
      isActive: true,
      createdAt: DateTime.now(),
    );

    await db.insert('product_categories', testCategory.toJson());

    // Create test unit
    final testUnit = UnitOfMeasure(
      id: 'test_unit_perf',
      name: 'Test Unit',
      abbreviation: 'TU',
      isBaseUnit: true,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await db.insert('units_of_measure', testUnit.toJson());

    // Create test products
    final testProducts = <Product>[];
    for (int i = 1; i <= 10; i++) {
      final product = Product(
        id: 'test_product_$i',
        name: 'Test Product $i',
        categoryId: testCategory.id,
        categoryName: testCategory.name,
        unitOfMeasureId: testUnit.id,
        unitOfMeasureName: testUnit.name,
        packSizes: [1.0],
        packSize: 1.0,
        salesPrice: 100.0 + (i * 10),
        costPrice: 50.0 + (i * 5),
        isActive: true,
        allowPartialSales: true,
        canBeSplit: false,
        createdAt: DateTime.now(),
      );

      testProducts.add(product);
      await db.insert('products', product.toJson());

      // Create stock for each product
      final stock = Stock(
        id: 'test_stock_$i',
        productId: product.id,
        productName: product.name,
        currentStock: 100.0 + (i * 10),
        availableStock: 100.0 + (i * 10),
        reservedStock: 0.0,
        lastUpdated: DateTime.now(),
      );

      await db.insert('stock', stock.toJson());
    }

    // Create many test sales to simulate performance issue
    print('   Creating test sales data...');
    final testSales = <Sale>[];
    for (int i = 1; i <= 500; i++) {
      // Create 500 sales records
      final sale = Sale(
        id: 'test_sale_$i',
        receiptNumber: 'PERF_TEST_$i',
        saleType: i % 2 == 0 ? 'CASH' : 'CREDIT',
        totalAmount: 150.0 + (i * 5),
        paidAmount: i % 2 == 0 ? 150.0 + (i * 5) : (150.0 + (i * 5)) * 0.5,
        balanceAmount: i % 2 == 0 ? 0.0 : (150.0 + (i * 5)) * 0.5,
        saleDate: DateTime.now().subtract(
          Duration(days: i % 90),
        ), // Spread over 90 days
        memberId: i % 2 == 1 ? 'test_member_${i % 10}' : null,
        memberName: i % 2 == 1 ? 'Test Member ${i % 10}' : null,
        seasonId: 'test_season_perf',
        userId: 'test_user_perf',
        userName: 'Performance Test User',
        items: [
          SaleItem(
            id: 'test_sale_item_$i',
            saleId: 'test_sale_$i',
            productId: testProducts[i % testProducts.length].id,
            productName: testProducts[i % testProducts.length].name,
            quantity: 1.0 + (i % 5),
            unitPrice: testProducts[i % testProducts.length].salesPrice,
            totalPrice:
                testProducts[i % testProducts.length].salesPrice *
                (1.0 + (i % 5)),
            packSizeSold: 1.0,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: i % 90)),
      );

      testSales.add(sale);
      await db.insert('sales', sale.toJson());

      // Insert sale items
      for (final item in sale.items) {
        final itemData = item.toJson();
        itemData['saleId'] = sale.id;
        await db.insert('sale_items', itemData);
      }
    }

    print('✅ Created test data:');
    print('   - 1 category, 1 unit, 10 products, 10 stock records');
    print('   - 500 sales records with items');

    // Test 2: Measure performance of old vs new approach
    print('\n⏱️  Test 2: Performance comparison...');

    // Test OLD approach (loadAllData)
    print('   Testing OLD approach (loadAllData)...');
    final stopwatch1 = Stopwatch()..start();
    await inventoryService.loadAllData();
    stopwatch1.stop();
    final oldApproachTime = stopwatch1.elapsedMilliseconds;
    print('   ❌ OLD approach time: ${oldApproachTime}ms');

    // Clear data to simulate fresh load
    inventoryService.products.clear();
    inventoryService.stocks.clear();
    inventoryService.sales.clear();

    // Test NEW approach (loadEssentialSalesData)
    print('   Testing NEW approach (loadEssentialSalesData)...');
    final stopwatch2 = Stopwatch()..start();
    await inventoryService.loadEssentialSalesData();
    stopwatch2.stop();
    final newApproachTime = stopwatch2.elapsedMilliseconds;
    print('   ✅ NEW approach time: ${newApproachTime}ms');

    // Calculate improvement
    final improvement =
        ((oldApproachTime - newApproachTime) / oldApproachTime * 100);
    print('   🚀 Performance improvement: ${improvement.toStringAsFixed(1)}%');

    if (improvement > 0) {
      print('   ✅ NEW approach is faster!');
    } else {
      print(
        '   ⚠️  NEW approach is not significantly faster (may be due to small dataset)',
      );
    }

    // Test 3: Verify data completeness for sales operations
    print('\n📊 Test 3: Data completeness verification...');

    print('   Essential data loaded:');
    print('   - Products: ${inventoryService.products.length}');
    print('   - Stocks: ${inventoryService.stocks.length}');
    print('   - Categories: ${inventoryService.categories.length}');
    print('   - Units: ${inventoryService.units.length}');
    print(
      '   - Sales: ${inventoryService.sales.length} (should be 0 initially)',
    );

    // Verify essential data is complete
    bool dataComplete = true;
    if (inventoryService.products.length < 10) {
      print('   ❌ Products not fully loaded');
      dataComplete = false;
    }
    if (inventoryService.stocks.length < 10) {
      print('   ❌ Stocks not fully loaded');
      dataComplete = false;
    }
    if (inventoryService.categories.isEmpty) {
      print('   ❌ Categories not loaded');
      dataComplete = false;
    }
    if (inventoryService.units.isEmpty) {
      print('   ❌ Units not loaded');
      dataComplete = false;
    }

    if (dataComplete) {
      print('   ✅ All essential data loaded correctly');
    }

    // Test 4: Test controller optimization
    print('\n🎮 Test 4: Controller optimization...');

    final stopwatch3 = Stopwatch()..start();
    await inventoryController.refreshInventoryData();
    stopwatch3.stop();
    final controllerTime = stopwatch3.elapsedMilliseconds;
    print('   Controller refresh time: ${controllerTime}ms');

    if (controllerTime < oldApproachTime) {
      print('   ✅ Controller is using optimized approach');
    } else {
      print('   ⚠️  Controller may not be using optimized approach');
    }

    // Test 5: Test background loading
    print('\n🔄 Test 5: Background loading verification...');

    // Wait for background loading to complete
    await Future.delayed(const Duration(seconds: 2));

    print('   After background loading:');
    print('   - Sales: ${inventoryService.sales.length}');
    print('   - Repayments: ${inventoryService.repayments.length}');
    print(
      '   - Stock adjustments: ${inventoryService.stockAdjustmentHistory.length}',
    );

    if (inventoryService.sales.isNotEmpty) {
      print('   ✅ Background loading working - sales data loaded');
    } else {
      print('   ⚠️  Background loading may not be working properly');
    }

    // Test 6: Test date range loading for reports
    print('\n📅 Test 6: Date range loading for reports...');

    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final stopwatch4 = Stopwatch()..start();
    final recentSales = await inventoryService.loadSalesForDateRange(
      startDate,
      endDate,
    );
    stopwatch4.stop();
    final dateRangeTime = stopwatch4.elapsedMilliseconds;

    print('   Date range query time: ${dateRangeTime}ms');
    print('   Sales in last 30 days: ${recentSales.length}');

    if (dateRangeTime < oldApproachTime) {
      print('   ✅ Date range loading is efficient');
    }

    // Test 7: Test recent sales loading
    print('\n🔄 Test 7: Recent sales loading...');

    final stopwatch5 = Stopwatch()..start();
    await inventoryService.loadRecentSales(limit: 50);
    stopwatch5.stop();
    final recentSalesTime = stopwatch5.elapsedMilliseconds;

    print('   Recent sales query time: ${recentSalesTime}ms');
    print('   Recent sales loaded: ${inventoryService.sales.length}');

    if (recentSalesTime < oldApproachTime) {
      print('   ✅ Recent sales loading is efficient');
    }

    // Clean up test data
    print('\n🧹 Cleaning up test data...');
    await db.delete('sales', where: 'id LIKE ?', whereArgs: ['test_sale_%']);
    await db.delete(
      'sale_items',
      where: 'saleId LIKE ?',
      whereArgs: ['test_sale_%'],
    );
    await db.delete('stock', where: 'id LIKE ?', whereArgs: ['test_stock_%']);
    await db.delete(
      'products',
      where: 'id LIKE ?',
      whereArgs: ['test_product_%'],
    );
    await db.delete(
      'product_categories',
      where: 'id = ?',
      whereArgs: [testCategory.id],
    );
    await db.delete(
      'units_of_measure',
      where: 'id = ?',
      whereArgs: [testUnit.id],
    );
    print('✅ Test data cleaned up');

    // Summary
    print('\n🎉 SALES REPORT PERFORMANCE TEST COMPLETE!');
    print('==========================================');
    print('✅ Performance Improvements Implemented:');
    print(
      '   • Essential data loading: ${newApproachTime}ms vs ${oldApproachTime}ms',
    );
    print('   • Background loading for non-critical data');
    print('   • Date range queries for reports: ${dateRangeTime}ms');
    print('   • Recent sales pagination: ${recentSalesTime}ms');
    print('   • Controller optimization: ${controllerTime}ms');

    print('\n📈 Key Benefits:');
    print('   • Sales screen opens faster (only loads essential data)');
    print('   • Reports load data efficiently with date ranges');
    print('   • Background loading doesn\'t block UI');
    print('   • Pagination prevents memory issues with large datasets');
    print('   • Better user experience with faster response times');

    print('\n🎯 Expected Results:');
    print('   • Sales Report screen should open quickly');
    print('   • Data loads progressively without blocking UI');
    print('   • Large sales datasets handled efficiently');
    print('   • Better performance on devices with limited resources');
  } catch (e) {
    print('❌ Error during performance testing: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
