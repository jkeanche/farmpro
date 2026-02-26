import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lib/controllers/controllers.dart';
import 'lib/models/models.dart';
import 'lib/services/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Testing Product Creation Fixes');
  print('=' * 50);

  try {
    // Initialize services
    await Get.putAsync(() => DatabaseHelper().init());
    await Get.putAsync(() => InventoryService().init());
    Get.put(AuthService());
    Get.put(InventoryController());

    final inventoryController = Get.find<InventoryController>();
    final inventoryService = Get.find<InventoryService>();
    final dbHelper = Get.find<DatabaseHelper>();

    print('✅ Services initialized successfully');

    // Test 1: Verify stock table has quantity column
    print('\n📋 Test 1: Stock Table Structure Verification');
    print('-' * 30);

    final db = await dbHelper.database;
    final tableInfo = await db.rawQuery("PRAGMA table_info(stock)");

    print('Stock table columns:');
    bool hasQuantityColumn = false;
    for (final column in tableInfo) {
      final name = column['name'] as String;
      print('  - $name: ${column['type']}');
      if (name == 'quantity') {
        hasQuantityColumn = true;
      }
    }

    if (hasQuantityColumn) {
      print('✅ Stock table has quantity column');
    } else {
      print('❌ Stock table missing quantity column');
    }

    // Test 2: Test product creation with initial stock
    print('\n📋 Test 2: Product Creation with Initial Stock');
    print('-' * 30);

    // Load required data
    await inventoryController.refreshInventoryData();

    // Set up product form data
    inventoryController.productNameController.text = 'Test Product Fix';
    inventoryController.productDescriptionController.text =
        'Test product for fixes';

    // Select category and unit
    final category = inventoryController.categories.first;
    final unit = inventoryController.units.first;
    inventoryController.selectedCategory.value = category;
    inventoryController.selectedUnit.value = unit;

    // Add pack size and set prices
    inventoryController.addPackSize(10.0);
    inventoryController.salesPriceController.text = '100.0';
    inventoryController.costPriceController.text = '80.0';
    inventoryController.minimumStockController.text = '5.0';
    inventoryController.initialStockController.text = '15.0';

    // Test product creation
    final success = await inventoryController.addProduct();

    if (success) {
      print('✅ Product created successfully');

      // Verify stock was created with quantity column
      final stockRecords = await db.query(
        'stock',
        where: 'productName = ?',
        whereArgs: ['Test Product Fix'],
      );

      if (stockRecords.isNotEmpty) {
        final stock = stockRecords.first;
        print('Stock record created:');
        print('  - Product ID: ${stock['productId']}');
        print('  - Product Name: ${stock['productName']}');
        print('  - Quantity: ${stock['quantity']}');
        print('  - Current Stock: ${stock['currentStock']}');
        print('  - Available Stock: ${stock['availableStock']}');

        if (stock['quantity'] == 15.0) {
          print('✅ Stock quantity column properly set');
        } else {
          print('❌ Stock quantity column not set correctly');
        }
      } else {
        print('❌ No stock record found');
      }
    } else {
      print('❌ Product creation failed: ${inventoryController.error.value}');
    }

    // Test 3: Test validation for required initial stock
    print('\n📋 Test 3: Initial Stock Validation');
    print('-' * 30);

    // Clear form
    inventoryController.productNameController.text = 'Test Product Validation';
    inventoryController.selectedCategory.value = category;
    inventoryController.selectedUnit.value = unit;
    inventoryController.addPackSize(5.0);
    inventoryController.salesPriceController.text = '50.0';
    inventoryController.initialStockController.text = ''; // Empty initial stock

    // Test validation
    final validationResult = await inventoryController.addProduct();

    if (!validationResult &&
        inventoryController.error.value.contains(
          'Initial stock quantity is required',
        )) {
      print('✅ Initial stock validation working correctly');
    } else {
      print('❌ Initial stock validation not working');
      print('Error: ${inventoryController.error.value}');
    }

    // Test 4: Test negative initial stock validation
    print('\n📋 Test 4: Negative Initial Stock Validation');
    print('-' * 30);

    inventoryController.initialStockController.text = '-5.0'; // Negative value

    final negativeValidationResult = await inventoryController.addProduct();

    if (!negativeValidationResult &&
        inventoryController.error.value.contains('non-negative number')) {
      print('✅ Negative initial stock validation working correctly');
    } else {
      print('❌ Negative initial stock validation not working');
      print('Error: ${inventoryController.error.value}');
    }

    // Test 5: Test invalid initial stock validation
    print('\n📋 Test 5: Invalid Initial Stock Validation');
    print('-' * 30);

    inventoryController.initialStockController.text = 'abc'; // Invalid value

    final invalidValidationResult = await inventoryController.addProduct();

    if (!invalidValidationResult &&
        inventoryController.error.value.contains('non-negative number')) {
      print('✅ Invalid initial stock validation working correctly');
    } else {
      print('❌ Invalid initial stock validation not working');
      print('Error: ${inventoryController.error.value}');
    }

    print('\n🎉 All tests completed!');
    print('=' * 50);
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}
