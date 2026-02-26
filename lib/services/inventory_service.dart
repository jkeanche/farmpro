import 'dart:io';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'database_helper.dart';
import 'performance_optimizer.dart';
import 'season_service.dart';

class InventoryService extends GetxService {
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  final Uuid _uuid = const Uuid();
  late final PerformanceOptimizer _performanceOptimizer;

  final RxList<UnitOfMeasure> _units = <UnitOfMeasure>[].obs;
  final RxList<ProductCategory> _categories = <ProductCategory>[].obs;
  final RxList<Product> _products = <Product>[].obs;
  final RxList<Stock> _stocks = <Stock>[].obs;
  final RxList<Sale> _sales = <Sale>[].obs;
  final RxList<Repayment> _repayments = <Repayment>[].obs;
  final RxList<StockAdjustmentHistory> _stockAdjustmentHistory =
      <StockAdjustmentHistory>[].obs;
  final RxList<LowStockAlert> _lowStockAlerts = <LowStockAlert>[].obs;

  List<UnitOfMeasure> get units => _units;
  List<ProductCategory> get categories => _categories;
  List<Product> get products => _products;
  List<Stock> get stocks => _stocks;
  List<Sale> get sales => _sales;
  List<Repayment> get repayments => _repayments;
  List<StockAdjustmentHistory> get stockAdjustmentHistory =>
      _stockAdjustmentHistory;
  List<LowStockAlert> get lowStockAlerts => _lowStockAlerts;

  Future<InventoryService> init() async {
    _performanceOptimizer = PerformanceOptimizer(_dbHelper);
    await _createInventoryTables();
    await _ensureInventoryTablesUpToDate();
    await _performanceOptimizer.optimizeDatabaseIndexes();
    await _createDefaultData();
    await _loadEssentialData();
    return this;
  }

  double _roundPrice(double value) {
    return value.roundToDouble();
  }

  Future<void> _loadEssentialData() async {
    await Future.wait([loadUnits(), loadCategories()]);
    _loadRemainingDataInBackground();
  }

  void _loadRemainingDataInBackground() {
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        await loadProducts();
        await loadStocks();
        await Future.wait([
          loadSales(),
          loadRepayments(),
          loadStockAdjustmentHistory(),
        ]);
        print('✓ Inventory data loaded in background');
      } catch (e) {
        print('❌ Error loading inventory data in background: $e');
        _retryEssentialDataLoading();
      }
    });
  }

  void _retryEssentialDataLoading() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await Future.wait([loadProducts(), loadStocks()]);
        print('✓ Essential inventory data retry successful');
      } catch (e) {
        print('❌ Essential inventory data retry failed: $e');
      }
    });
  }

  Future<void> _createInventoryTables() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units_of_measure (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, abbreviation TEXT NOT NULL, description TEXT,
        isBaseUnit INTEGER NOT NULL DEFAULT 0, baseUnitId TEXT, conversionFactor REAL,
        isActive INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, color TEXT, icon TEXT,
        isActive INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, categoryId TEXT NOT NULL,
        categoryName TEXT, unitOfMeasureId TEXT NOT NULL, unitOfMeasureName TEXT,
        packSize REAL NOT NULL, salesPrice REAL NOT NULL, costPrice REAL, minimumStock REAL,
        maximumStock REAL, barcode TEXT, sku TEXT, isActive INTEGER NOT NULL DEFAULT 1,
        allowPartialSales INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL, updatedAt TEXT,
        canBeSplit INTEGER NOT NULL DEFAULT 0, maxSplitSize REAL, parentProductId TEXT,
        isSplitProduct INTEGER NOT NULL DEFAULT 0, originalPackSize REAL, packSizes TEXT,
        FOREIGN KEY(categoryId) REFERENCES product_categories(id),
        FOREIGN KEY(unitOfMeasureId) REFERENCES units_of_measure(id),
        FOREIGN KEY(parentProductId) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock (
        id TEXT PRIMARY KEY, productId TEXT NOT NULL, productName TEXT,
        currentStock REAL NOT NULL DEFAULT 0, availableStock REAL NOT NULL DEFAULT 0,
        reservedStock REAL NOT NULL DEFAULT 0, lastUpdated TEXT NOT NULL, lastUpdatedBy TEXT,
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id TEXT PRIMARY KEY, productId TEXT NOT NULL, movementType TEXT NOT NULL,
        quantity REAL NOT NULL, balanceBefore REAL NOT NULL, balanceAfter REAL NOT NULL,
        reference TEXT, notes TEXT, movementDate TEXT NOT NULL, userId TEXT, userName TEXT,
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY, memberId TEXT, memberName TEXT, memberNumber TEXT, saleType TEXT NOT NULL,
        totalAmount REAL NOT NULL, paidAmount REAL NOT NULL, balanceAmount REAL NOT NULL,
        saleDate TEXT NOT NULL, receiptNumber TEXT, notes TEXT, userId TEXT NOT NULL,
        userName TEXT, isActive INTEGER NOT NULL DEFAULT 1, createdAt TEXT NOT NULL,
        updatedAt TEXT, seasonId TEXT, seasonName TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY, saleId TEXT NOT NULL, productId TEXT NOT NULL,
        productName TEXT NOT NULL, quantity REAL NOT NULL, unitPrice REAL NOT NULL,
        totalPrice REAL NOT NULL, notes TEXT, packSizeSold REAL,
        FOREIGN KEY(saleId) REFERENCES sales(id),
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS repayments (
        id TEXT PRIMARY KEY, saleId TEXT NOT NULL, memberId TEXT NOT NULL, memberName TEXT NOT NULL,
        amount REAL NOT NULL, repaymentDate TEXT NOT NULL, paymentMethod TEXT NOT NULL,
        reference TEXT, notes TEXT, userId TEXT NOT NULL, userName TEXT, createdAt TEXT NOT NULL,
        FOREIGN KEY(saleId) REFERENCES sales(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustment_history (
        id TEXT PRIMARY KEY, productId TEXT NOT NULL, productName TEXT NOT NULL,
        categoryId TEXT NOT NULL, categoryName TEXT NOT NULL, quantityAdjusted REAL NOT NULL,
        previousQuantity REAL NOT NULL, newQuantity REAL NOT NULL, adjustmentType TEXT NOT NULL,
        reason TEXT NOT NULL, adjustmentDate TEXT NOT NULL, userId TEXT NOT NULL,
        userName TEXT NOT NULL, notes TEXT,
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS low_stock_alerts (
        id TEXT PRIMARY KEY, productId TEXT NOT NULL, productName TEXT NOT NULL,
        categoryId TEXT NOT NULL, categoryName TEXT NOT NULL, currentQuantity REAL NOT NULL,
        minimumLevel REAL NOT NULL, shortfall REAL NOT NULL, alertDate TEXT NOT NULL,
        severity TEXT NOT NULL, isAcknowledged INTEGER NOT NULL DEFAULT 0,
        acknowledgedDate TEXT, acknowledgedBy TEXT,
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');
  }

  Future<void> _ensureInventoryTablesUpToDate() async {
    final db = await _dbHelper.database;
    await _migrateInventoryTables(db);
  }

  Future<void> _migrateInventoryTables(Database db) async {
    try {
      await db.transaction((txn) async {
        var unitsTableInfo = await txn.rawQuery(
          "PRAGMA table_info(units_of_measure)",
        );
        final unitsExistingColumns =
            unitsTableInfo.map((col) => col['name'] as String).toSet();
        if (!unitsExistingColumns.contains('abbreviation')) {
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN abbreviation TEXT',
          );
        }
        if (!unitsExistingColumns.contains('baseUnitId')) {
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN baseUnitId TEXT',
          );
        }
        if (!unitsExistingColumns.contains('conversionFactor')) {
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN conversionFactor REAL',
          );
        }

        var categoriesTableInfo = await txn.rawQuery(
          "PRAGMA table_info(product_categories)",
        );
        final categoriesExistingColumns =
            categoriesTableInfo.map((col) => col['name'] as String).toSet();
        if (!categoriesExistingColumns.contains('color')) {
          await txn.execute(
            'ALTER TABLE product_categories ADD COLUMN color TEXT',
          );
        }
        if (!categoriesExistingColumns.contains('icon')) {
          await txn.execute(
            'ALTER TABLE product_categories ADD COLUMN icon TEXT',
          );
        }

        var productsTableInfo = await txn.rawQuery(
          "PRAGMA table_info(products)",
        );
        final productsExistingColumns =
            productsTableInfo.map((col) => col['name'] as String).toSet();
        if (!productsExistingColumns.contains('canBeSplit')) {
          await txn.execute(
            'ALTER TABLE products ADD COLUMN canBeSplit INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (!productsExistingColumns.contains('maxSplitSize')) {
          await txn.execute(
            'ALTER TABLE products ADD COLUMN maxSplitSize REAL',
          );
        }
        if (!productsExistingColumns.contains('parentProductId')) {
          await txn.execute(
            'ALTER TABLE products ADD COLUMN parentProductId TEXT',
          );
        }
        if (!productsExistingColumns.contains('isSplitProduct')) {
          await txn.execute(
            'ALTER TABLE products ADD COLUMN isSplitProduct INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (!productsExistingColumns.contains('originalPackSize')) {
          await txn.execute(
            'ALTER TABLE products ADD COLUMN originalPackSize REAL',
          );
        }
        if (!productsExistingColumns.contains('packSizes')) {
          await txn.execute('ALTER TABLE products ADD COLUMN packSizes TEXT');
        }

        var saleItemsTableInfo = await txn.rawQuery(
          "PRAGMA table_info(sale_items)",
        );
        final saleItemsColumns =
            saleItemsTableInfo.map((col) => col['name'] as String).toSet();
        if (!saleItemsColumns.contains('packSizeSold')) {
          await txn.execute(
            'ALTER TABLE sale_items ADD COLUMN packSizeSold REAL',
          );
        }
        if (!saleItemsColumns.contains('notes')) {
          await txn.execute('ALTER TABLE sale_items ADD COLUMN notes TEXT');
        }

        var stockTableInfo = await txn.rawQuery("PRAGMA table_info(stock)");
        final stockExistingColumns =
            stockTableInfo.map((col) => col['name'] as String).toSet();
        if (!stockExistingColumns.contains('productName')) {
          await txn.execute('ALTER TABLE stock ADD COLUMN productName TEXT');
        }
        if (!stockExistingColumns.contains('currentStock')) {
          await txn.execute(
            'ALTER TABLE stock ADD COLUMN currentStock REAL DEFAULT 0',
          );
        }
        if (!stockExistingColumns.contains('availableStock')) {
          await txn.execute(
            'ALTER TABLE stock ADD COLUMN availableStock REAL DEFAULT 0',
          );
        }
        if (!stockExistingColumns.contains('reservedStock')) {
          await txn.execute(
            'ALTER TABLE stock ADD COLUMN reservedStock REAL DEFAULT 0',
          );
        }
        if (!stockExistingColumns.contains('lastUpdatedBy')) {
          await txn.execute('ALTER TABLE stock ADD COLUMN lastUpdatedBy TEXT');
        }

        var salesTableInfo = await txn.rawQuery("PRAGMA table_info(sales)");
        final salesColumns =
            salesTableInfo.map((col) => col['name'] as String).toSet();
        if (!salesColumns.contains('seasonName')) {
          await txn.execute('ALTER TABLE sales ADD COLUMN seasonName TEXT');
        }
        if (!salesColumns.contains('seasonId')) {
          await txn.execute('ALTER TABLE sales ADD COLUMN seasonId TEXT');
        }
        if (!salesColumns.contains('updatedAt')) {
          await txn.execute('ALTER TABLE sales ADD COLUMN updatedAt TEXT');
        }
        if (!salesColumns.contains('memberNumber')) {
          await txn.execute('ALTER TABLE sales ADD COLUMN memberNumber TEXT');
        }

        var repaymentsInfo = await txn.rawQuery(
          "PRAGMA table_info(repayments)",
        );
        final repaymentsCols =
            repaymentsInfo.map((col) => col['name'] as String).toSet();
        if (!repaymentsCols.contains('reference')) {
          await txn.execute('ALTER TABLE repayments ADD COLUMN reference TEXT');
        }
        if (!repaymentsCols.contains('notes')) {
          await txn.execute('ALTER TABLE repayments ADD COLUMN notes TEXT');
        }
      });
      print('Inventory tables migration completed successfully');
    } catch (e) {
      print('Error migrating inventory tables: $e');
    }
  }

  Future<void> _createDefaultData() async {
    final db = await _dbHelper.database;
    if ((await db.rawQuery(
          'SELECT COUNT(*) as count FROM units_of_measure',
        )).first['count'] ==
        0) {
      await _createDefaultUnits();
    }
    if ((await db.rawQuery(
          'SELECT COUNT(*) as count FROM product_categories',
        )).first['count'] ==
        0) {
      await _createDefaultCategories();
    }
  }

  Future<void> _createDefaultUnits() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final defaultUnits = [
      {
        'id': _uuid.v4(),
        'name': 'Kilogram',
        'abbreviation': 'kg',
        'isBaseUnit': 1,
        'createdAt': now,
      },
      {
        'id': _uuid.v4(),
        'name': 'Piece',
        'abbreviation': 'pcs',
        'isBaseUnit': 1,
        'createdAt': now,
      },
    ];
    for (final unit in defaultUnits) {
      await db.insert('units_of_measure', unit);
    }
  }

  Future<void> _createDefaultCategories() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final defaultCategories = [
      {
        'id': _uuid.v4(),
        'name': 'Fertilizers',
        'color': '#4CAF50',
        'icon': 'agriculture',
        'createdAt': now,
      },
      {
        'id': _uuid.v4(),
        'name': 'Tools',
        'color': '#FF9800',
        'icon': 'build',
        'createdAt': now,
      },
    ];
    for (final category in defaultCategories) {
      await db.insert('product_categories', category);
    }
  }

  /// Generates auto-increment product ID in format PRD001, PRD002, etc.
  Future<String> _generateAutoIncrementProductId() async {
    final db = await _dbHelper.database;

    // Get the highest existing product ID number
    final result = await db.rawQuery('''
      SELECT id FROM products 
      WHERE id LIKE 'PRD%' 
      ORDER BY CAST(SUBSTR(id, 4) AS INTEGER) DESC 
      LIMIT 1
    ''');

    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastId = result.first['id'] as String;
      final numberPart = lastId.substring(3); // Remove 'PRD' prefix
      final lastNumber = int.tryParse(numberPart) ?? 0;
      nextNumber = lastNumber + 1;
    }

    // Format as PRD001, PRD002, etc.
    return 'PRD${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> loadAllData() async {
    await Future.wait([
      loadUnits(),
      loadCategories(),
      loadProducts(),
      loadStocks(),
      loadSales(),
      loadRepayments(),
      loadStockAdjustmentHistory(),
    ]);
  }

  Future<void> loadEssentialSalesData() async {
    await Future.wait([
      loadUnits(),
      loadCategories(),
      loadProducts(),
      loadStocks(),
    ]);
  }

  Future<void> loadRecentSales({int limit = 100}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sales',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'saleDate DESC',
        limit: limit,
      );
      _sales.value = maps.map((map) => Sale.fromJson(map)).toList();
    } catch (e) {
      print('Error loading recent sales: $e');
      _sales.value = [];
    }
  }

  Future<List<Sale>> loadSalesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await _dbHelper.database;
      final salesMaps = await db.query(
        'sales',
        where: 'isActive = ? AND saleDate >= ? AND saleDate <= ?',
        whereArgs: [1, startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'saleDate DESC',
      );

      // Load items for each sale
      List<Sale> salesList = [];
      for (final saleMap in salesMaps) {
        final itemsMaps = await db.query(
          'sale_items',
          where: 'saleId = ?',
          whereArgs: [saleMap['id']],
        );
        final items = itemsMaps.map((map) => SaleItem.fromJson(map)).toList();
        final saleData = Map<String, dynamic>.from(saleMap);
        saleData['items'] = items.map((item) => item.toJson()).toList();
        salesList.add(Sale.fromJson(saleData));
      }

      return salesList;
    } catch (e) {
      print('Error loading sales for date range: $e');
      return [];
    }
  }

  Future<void> loadUnits() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'units_of_measure',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'name',
      );
      _units.value = maps.map((map) => UnitOfMeasure.fromJson(map)).toList();
    } catch (e) {
      print('Error loading units: $e');
    }
  }

  Future<void> loadCategories() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'product_categories',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'name',
      );
      _categories.value =
          maps.map((map) => ProductCategory.fromJson(map)).toList();
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT p.*, c.name as categoryName, u.name as unitOfMeasureName
        FROM products p
        LEFT JOIN product_categories c ON p.categoryId = c.id
        LEFT JOIN units_of_measure u ON p.unitOfMeasureId = u.id
        WHERE p.isActive = 1 ORDER BY p.name
      ''');
      _products.value = maps.map((map) => Product.fromJson(map)).toList();
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> loadStocks() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT s.*, p.name as productName FROM stock s
        LEFT JOIN products p ON s.productId = p.id ORDER BY p.name
      ''');
      _stocks.value = maps.map((map) => Stock.fromJson(map)).toList();
    } catch (e) {
      print('Error loading stocks: $e');
    }
  }

  Future<void> loadSales() async {
    try {
      final db = await _dbHelper.database;
      final salesMaps = await db.query(
        'sales',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'saleDate DESC',
      );
      List<Sale> salesList = [];
      for (final saleMap in salesMaps) {
        final itemsMaps = await db.query(
          'sale_items',
          where: 'saleId = ?',
          whereArgs: [saleMap['id']],
        );
        final items = itemsMaps.map((map) => SaleItem.fromJson(map)).toList();
        final saleData = Map<String, dynamic>.from(saleMap);
        saleData['items'] = items.map((item) => item.toJson()).toList();
        salesList.add(Sale.fromJson(saleData));
      }
      _sales.value = salesList;
    } catch (e) {
      print('Error loading sales: $e');
    }
  }

  Future<Map<String, dynamic>> deleteSale(String saleId) async {
    try {
      final db = await _dbHelper.database;

      // Start transaction to ensure atomicity
      await db.transaction((txn) async {
        // 1. Get sale details with items
        final saleMaps = await txn.query(
          'sales',
          where: 'id = ? AND isActive = 1',
          whereArgs: [saleId],
        );

        if (saleMaps.isEmpty) {
          throw Exception('Sale not found or already deleted');
        }

        // 2. Get sale items
        final itemsMaps = await txn.query(
          'sale_items',
          where: 'saleId = ?',
          whereArgs: [saleId],
        );

        if (itemsMaps.isEmpty) {
          throw Exception('No items found for this sale');
        }

        final now = DateTime.now().toIso8601String();

        // 3. Restore stock for each item
        for (final itemMap in itemsMaps) {
          final productId = itemMap['productId'] as String;
          final quantity = (itemMap['quantity'] as num).toDouble();
          final productName = itemMap['productName'] as String;
          final packSizeSold = (itemMap['packSizeSold'] as num?)?.toDouble();

          // Get product's master pack size
          final productMaps = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );

          if (productMaps.isEmpty) {
            throw Exception('Product not found: $productName');
          }

          final masterPackSize =
              (productMaps.first['packSize'] as num?)?.toDouble() ?? 1.0;
          final selectedPackSize = packSizeSold ?? quantity;

          // Calculate units to restore using the same formula as sale creation
          // unitsToRestore = quantity * (selectedPackSize / masterPackSize)
          final unitsToRestore = quantity * (selectedPackSize / masterPackSize);

          // Get current stock
          final stockMaps = await txn.query(
            'stock',
            where: 'productId = ?',
            whereArgs: [productId],
          );

          if (stockMaps.isEmpty) {
            throw Exception('Stock record not found for product: $productName');
          }

          final currentStock =
              (stockMaps.first['currentStock'] as num).toDouble();
          final availableStock =
              (stockMaps.first['availableStock'] as num).toDouble();
          final newCurrentStock = currentStock + unitsToRestore;
          final newAvailableStock = availableStock + unitsToRestore;

          // Update stock
          await txn.update(
            'stock',
            {
              'currentStock': newCurrentStock,
              'availableStock': newAvailableStock,
              'lastUpdated': now,
              'lastUpdatedBy': 'system',
            },
            where: 'productId = ?',
            whereArgs: [productId],
          );

          // Create stock movement record for audit trail
          await txn.insert('stock_movements', {
            'id': _uuid.v4(),
            'productId': productId,
            'movementType': 'SALE_REVERSAL',
            'quantity': unitsToRestore,
            'balanceBefore': currentStock,
            'balanceAfter': newCurrentStock,
            'reference':
                'Sale Deletion: ${saleMaps.first['receiptNumber'] ?? saleId}',
            'notes':
                'Stock restored due to sale deletion (qty: $quantity, pack: $selectedPackSize/$masterPackSize)',
            'movementDate': now,
            'userId': 'system',
            'userName': 'System',
          });
        }

        // 4. Mark sale as inactive (soft delete)
        await txn.update(
          'sales',
          {'isActive': 0, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      });

      // Reload data to reflect changes
      await Future.wait([loadStocks(), loadSales()]);

      return {'success': true};
    } catch (e) {
      print('Error deleting sale: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete all sales (used for clearing data after export)
  /// This marks all sales as inactive and restores stock for all items
  Future<Map<String, dynamic>> deleteAllSales() async {
    try {
      final db = await _dbHelper.database;
      int deletedCount = 0;

      // Start transaction to ensure atomicity
      await db.transaction((txn) async {
        // 1. Get all active sales
        final saleMaps = await txn.query('sales', where: 'isActive = 1');

        if (saleMaps.isEmpty) {
          return;
        }

        final now = DateTime.now().toIso8601String();

        // 2. Process each sale
        for (final saleMap in saleMaps) {
          final saleId = saleMap['id'] as String;

          // Get sale items
          final itemsMaps = await txn.query(
            'sale_items',
            where: 'saleId = ?',
            whereArgs: [saleId],
          );

          // Restore stock for each item
          for (final itemMap in itemsMaps) {
            final productId = itemMap['productId'] as String;
            final quantity = (itemMap['quantity'] as num).toDouble();
            final productName = itemMap['productName'] as String;
            final packSizeSold = (itemMap['packSizeSold'] as num?)?.toDouble();

            // Get product's master pack size
            final productMaps = await txn.query(
              'products',
              where: 'id = ?',
              whereArgs: [productId],
              limit: 1,
            );

            if (productMaps.isEmpty) {
              print('Warning: Product not found: $productName');
              continue;
            }

            final masterPackSize =
                (productMaps.first['packSize'] as num?)?.toDouble() ?? 1.0;
            final selectedPackSize = packSizeSold ?? quantity;

            // Calculate units to restore
            final unitsToRestore =
                quantity * (selectedPackSize / masterPackSize);

            // Get current stock
            final stockMaps = await txn.query(
              'stock',
              where: 'productId = ?',
              whereArgs: [productId],
            );

            if (stockMaps.isEmpty) {
              print(
                'Warning: Stock record not found for product: $productName',
              );
              continue;
            }

            final currentStock =
                (stockMaps.first['currentStock'] as num).toDouble();
            final availableStock =
                (stockMaps.first['availableStock'] as num).toDouble();
            final newCurrentStock = currentStock + unitsToRestore;
            final newAvailableStock = availableStock + unitsToRestore;

            // Update stock
            await txn.update(
              'stock',
              {
                'currentStock': newCurrentStock,
                'availableStock': newAvailableStock,
                'lastUpdated': now,
                'lastUpdatedBy': 'system',
              },
              where: 'productId = ?',
              whereArgs: [productId],
            );

            // Create stock movement record for audit trail
            await txn.insert('stock_movements', {
              'id': _uuid.v4(),
              'productId': productId,
              'movementType': 'SALE_REVERSAL',
              'quantity': unitsToRestore,
              'balanceBefore': currentStock,
              'balanceAfter': newCurrentStock,
              'reference':
                  'Bulk Sale Deletion: ${saleMap['receiptNumber'] ?? saleId}',
              'notes':
                  'Stock restored due to bulk sale deletion (qty: $quantity, pack: $selectedPackSize/$masterPackSize)',
              'movementDate': now,
              'userId': 'system',
              'userName': 'System',
            });
          }

          // Mark sale as inactive (soft delete)
          await txn.update(
            'sales',
            {'isActive': 0, 'updatedAt': now},
            where: 'id = ?',
            whereArgs: [saleId],
          );

          deletedCount++;
        }
      });

      // Reload data to reflect changes
      await Future.wait([loadStocks(), loadSales()]);

      return {
        'success': true,
        'deletedCount': deletedCount,
        'message':
            'Successfully deleted $deletedCount sale(s) and restored stock',
      };
    } catch (e) {
      print('Error deleting all sales: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> loadRepayments() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('repayments', orderBy: 'repaymentDate DESC');
      _repayments.value = maps.map((map) => Repayment.fromJson(map)).toList();
    } catch (e) {
      print('Error loading repayments: $e');
    }
  }

  Future<void> loadStockAdjustmentHistory() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'stock_adjustment_history',
        orderBy: 'adjustmentDate DESC',
        limit: 200,
      );
      _stockAdjustmentHistory.value =
          maps.map((map) => StockAdjustmentHistory.fromJson(map)).toList();
    } catch (e) {
      print('Error loading stock adjustment history: $e');
      _stockAdjustmentHistory.value = [];
    }
  }

  Future<Map<String, dynamic>> addUnit(UnitOfMeasure unit) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'units_of_measure',
        where: 'LOWER(name) = ? AND isActive = 1',
        whereArgs: [unit.name.toLowerCase()],
      )).isNotEmpty) {
        return {
          'success': false,
          'error': 'A unit with name "${unit.name}" already exists',
        };
      }
      if ((await db.query(
        'units_of_measure',
        where: 'LOWER(abbreviation) = ? AND isActive = 1',
        whereArgs: [unit.abbreviation.toLowerCase()],
      )).isNotEmpty) {
        return {
          'success': false,
          'error':
              'A unit with abbreviation "${unit.abbreviation}" already exists',
        };
      }
      await db.insert('units_of_measure', unit.toJson());
      await loadUnits();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to add unit: $e'};
    }
  }

  Future<Map<String, dynamic>> updateUnit(UnitOfMeasure unit) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'units_of_measure',
        where: 'LOWER(name) = ? AND isActive = 1 AND id != ?',
        whereArgs: [unit.name.toLowerCase(), unit.id],
      )).isNotEmpty) {
        return {
          'success': false,
          'error': 'A unit with name "${unit.name}" already exists',
        };
      }
      if ((await db.query(
        'units_of_measure',
        where: 'LOWER(abbreviation) = ? AND isActive = 1 AND id != ?',
        whereArgs: [unit.abbreviation.toLowerCase(), unit.id],
      )).isNotEmpty) {
        return {
          'success': false,
          'error':
              'A unit with abbreviation "${unit.abbreviation}" already exists',
        };
      }
      await db.update(
        'units_of_measure',
        unit.toJson(),
        where: 'id = ?',
        whereArgs: [unit.id],
      );
      await loadUnits();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to update unit: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteUnit(String unitId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'units_of_measure',
        {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [unitId],
      );
      await loadUnits();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete unit: $e'};
    }
  }

  Future<Map<String, dynamic>> addCategory(ProductCategory category) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'product_categories',
        where: 'LOWER(name) = ? AND isActive = 1',
        whereArgs: [category.name.toLowerCase()],
      )).isNotEmpty) {
        return {
          'success': false,
          'error': 'A category with name "${category.name}" already exists',
        };
      }
      await db.insert('product_categories', category.toJson());
      await loadCategories();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to add category: $e'};
    }
  }

  Future<Map<String, dynamic>> updateCategory(ProductCategory category) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'product_categories',
        where: 'LOWER(name) = ? AND isActive = 1 AND id != ?',
        whereArgs: [category.name.toLowerCase(), category.id],
      )).isNotEmpty) {
        return {
          'success': false,
          'error': 'A category with name "${category.name}" already exists',
        };
      }
      await db.update(
        'product_categories',
        category.toJson(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      await loadCategories();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to update category: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteCategory(String categoryId) async {
    try {
      final db = await _dbHelper.database;
      final productsInCategory = await db.query(
        'products',
        where: 'categoryId = ? AND isActive = 1',
        whereArgs: [categoryId],
      );
      if (productsInCategory.isNotEmpty) {
        return {
          'success': false,
          'error':
              'Cannot delete category. It has ${productsInCategory.length} products.',
        };
      }
      await db.update(
        'product_categories',
        {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [categoryId],
      );
      await loadCategories();
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete category: $e'};
    }
  }

  Future<Map<String, dynamic>> addProduct(
    Product product, {
    double initialStock = 0.0,
  }) async {
    String productId = await _generateAutoIncrementProductId();

    if (product.name.isEmpty) {
      return {'success': false, 'error': 'Product name is required'};
    }
    if (product.categoryId.isEmpty || product.unitOfMeasureId.isEmpty) {
      return {
        'success': false,
        'error': 'Category and unit of measure are required',
      };
    }
    if (product.packSize <= 0 || product.salesPrice <= 0) {
      return {
        'success': false,
        'error': 'Pack size and sales price must be positive',
      };
    }

    try {
      final db = await _dbHelper.database;

      // ... existing duplicate checks ...

      final now = DateTime.now().toIso8601String();
      final stockId = _uuid.v4();

      // Round prices before creating product
      final productWithId = product.copyWith(
        id: productId,
        salesPrice: _roundPrice(product.salesPrice),
        costPrice:
            product.costPrice != null ? _roundPrice(product.costPrice!) : null,
      );

      await db.transaction((txn) async {
        await txn.insert(
          'products',
          productWithId.toJson()
            ..['createdAt'] = now
            ..['updatedAt'] = now,
        );

        await txn.insert('stock', {
          'id': stockId,
          'productId': productId,
          'productName': product.name,
          'quantity': initialStock,
          'currentStock': initialStock,
          'availableStock': initialStock,
          'reservedStock': 0.0,
          'lastUpdated': now,
          'lastUpdatedBy': 'system',
        });
      });

      _products.add(
        productWithId.copyWith(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _products.refresh();

      final newStock = Stock(
        id: stockId,
        productId: productId,
        productName: product.name,
        currentStock: initialStock,
        availableStock: initialStock,
        reservedStock: 0.0,
        lastUpdated: DateTime.now(),
        lastUpdatedBy: 'system',
      );
      _stocks.add(newStock);
      _stocks.refresh();

      return {'success': true, 'productId': productId};
    } on DatabaseException catch (e) {
      return {
        'success': false,
        'error': 'Database error adding product: ${e.toString()}',
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to add product: $e'};
    }
  }

  // Update the updateProduct method:
  Future<Map<String, dynamic>> updateProduct(Product product) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'products',
        where: 'LOWER(name) = ? AND isActive = 1 AND id != ?',
        whereArgs: [product.name.toLowerCase(), product.id],
      )).isNotEmpty) {
        return {
          'success': false,
          'error': 'A product with name "${product.name}" already exists',
        };
      }

      // Round prices before updating
      final updatedProduct = product.copyWith(
        salesPrice: _roundPrice(product.salesPrice),
        costPrice:
            product.costPrice != null ? _roundPrice(product.costPrice!) : null,
      );

      await db.update(
        'products',
        updatedProduct.toJson(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await db.update(
        'stock',
        {
          'productName': product.name,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
        where: 'productId = ?',
        whereArgs: [product.id],
      );
      await Future.wait([loadProducts(), loadStocks()]);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to update product: $e'};
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      final db = await _dbHelper.database;
      if ((await db.query(
        'sale_items',
        where: 'productId = ?',
        whereArgs: [productId],
      )).isNotEmpty) {
        return false;
      }
      if ((await db.query(
        'stock_movements',
        where: 'productId = ?',
        whereArgs: [productId],
      )).isNotEmpty) {
        return false;
      }
      await db.update(
        'products',
        {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await Future.wait([loadProducts(), loadStocks()]);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  // _createInitialStock method removed as logic is now inlined in addProduct for better atomicity and maintainability

  Future<void> _recordStockMovement(
    String productId,
    String movementType,
    double quantity,
    double balanceBefore,
    double balanceAfter,
    String reference,
    String? userId,
    String? userName,
  ) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('stock_movements', {
        'id': _uuid.v4(),
        'productId': productId,
        'movementType': movementType,
        'quantity': quantity,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'reference': reference,
        'movementDate': DateTime.now().toIso8601String(),
        'userId': userId,
        'userName': userName,
      });
    } catch (e) {
      print('Error recording stock movement: $e');
    }
  }

  Future<void> _recordStockAdjustment(
    String productId,
    double quantityAdjusted,
    double previousQuantity,
    double newQuantity,
    String reason,
    String? userId,
    String? userName,
  ) async {
    try {
      final db = await _dbHelper.database;
      final productInfo = await db.rawQuery(
        'SELECT p.name as productName, c.id as categoryId, c.name as categoryName FROM products p LEFT JOIN product_categories c ON p.categoryId = c.id WHERE p.id = ?',
        [productId],
      );
      if (productInfo.isNotEmpty) {
        final info = productInfo.first;
        await db.insert('stock_adjustment_history', {
          'id': _uuid.v4(),
          'productId': productId,
          'productName': info['productName'],
          'categoryId': info['categoryId'],
          'categoryName': info['categoryName'],
          'quantityAdjusted': quantityAdjusted,
          'previousQuantity': previousQuantity,
          'newQuantity': newQuantity,
          'adjustmentType': quantityAdjusted > 0 ? 'INCREASE' : 'DECREASE',
          'reason': reason,
          'adjustmentDate': DateTime.now().toIso8601String(),
          'userId': userId ?? 'system',
          'userName': userName ?? 'System',
        });
      }
    } catch (e) {
      print('Error recording stock adjustment: $e');
    }
  }

  Future<Map<String, dynamic>> addRepayment(Repayment repayment) async {
    try {
      final db = await _dbHelper.database;

      // Round repayment amount
      final roundedAmount = _roundPrice(repayment.amount);
      final roundedRepayment = repayment.copyWith(amount: roundedAmount);

      final result = await db.transaction((txn) async {
        await txn.insert('repayments', roundedRepayment.toJson());
        final sale = await txn.query(
          'sales',
          where: 'id = ?',
          whereArgs: [repayment.saleId],
        );
        if (sale.isNotEmpty) {
          final currentBalance = sale.first['balanceAmount'] as double? ?? 0.0;
          final newBalance = _roundPrice(currentBalance - roundedAmount);
          final currentPaid = sale.first['paidAmount'] as double? ?? 0.0;
          final newPaid = _roundPrice(currentPaid + roundedAmount);

          await txn.update(
            'sales',
            {'balanceAmount': newBalance, 'paidAmount': newPaid},
            where: 'id = ?',
            whereArgs: [repayment.saleId],
          );
        }
        return {'success': true};
      });

      await loadSales();
      await loadRepayments();

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Failed to add repayment: $e'};
    }
  }

  /// Adjusts stock levels for a product, supporting inbound (IN) or outbound (OUT) movements.
  /// Validates inputs, ensures atomicity with transaction, and updates in-memory cache.
  /// Returns success with new stock level or error details.
  Future<Map<String, dynamic>> adjustStock({
    required String productId,
    required double quantity,
    required String movementType,
    String? notes,
    String? userId,
    String? userName,
  }) async {
    // Input validation
    if (quantity <= 0) {
      return {'success': false, 'error': 'Quantity must be greater than 0'};
    }
    if (!['IN', 'OUT'].contains(movementType)) {
      return {
        'success': false,
        'error': 'Invalid movement type. Must be "IN" or "OUT"',
      };
    }

    final effectiveUserId = userId ?? 'system';
    final effectiveUserName = userName ?? 'System User';
    final effectiveNotes = notes ?? 'Stock adjustment';
    final now = DateTime.now().toIso8601String();

    try {
      final db = await _dbHelper.database;

      // Check if product exists
      final productRecord = await db.query(
        'products',
        where: 'id = ? AND isActive = 1',
        whereArgs: [productId],
      );
      if (productRecord.isEmpty) {
        return {'success': false, 'error': 'Product not found or inactive'};
      }

      final productInfo = await db.rawQuery(
        '''SELECT p.name as productName, c.id as categoryId, c.name as categoryName
           FROM products p
           LEFT JOIN product_categories c ON p.categoryId = c.id
           WHERE p.id = ?''',
        [productId],
      );
      if (productInfo.isEmpty) {
        return {'success': false, 'error': 'Product information not available'};
      }

      // Fetch current stock or prepare to create
      final stockRecord = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      double currentStock;
      bool createNewStock = false;
      if (stockRecord.isEmpty) {
        currentStock = 0.0;
        createNewStock = true;
      } else {
        currentStock = stockRecord.first['currentStock'] as double? ?? 0.0;
      }
      final adjustmentQuantity = movementType == 'IN' ? quantity : -quantity;
      final newStock = currentStock + adjustmentQuantity;

      if (newStock < 0) {
        return {
          'success': false,
          'error':
              'Insufficient stock. Current: $currentStock, Requested: ${quantity.abs()}',
        };
      }

      // Perform atomic update
      await db.transaction((txn) async {
        final info = productInfo.first;
        if (createNewStock) {
          await txn.insert('stock', {
            'id': _uuid.v4(),
            'productId': productId,
            'productName': info['productName'] as String,
            'currentStock': newStock,
            'availableStock': newStock,
            'reservedStock': 0.0,
            'lastUpdated': now,
            'lastUpdatedBy': effectiveUserId,
          });
        } else {
          await txn.update(
            'stock',
            {
              'currentStock': newStock,
              'availableStock': newStock,
              'lastUpdated': now,
              'lastUpdatedBy': effectiveUserId,
            },
            where: 'productId = ?',
            whereArgs: [productId],
          );
        }

        // Record stock movement
        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'productId': productId,
          'movementType': movementType,
          'quantity': quantity,
          'balanceBefore': currentStock,
          'balanceAfter': newStock,
          'reference': effectiveNotes,
          'notes': effectiveNotes,
          'movementDate': now,
          'userId': effectiveUserId,
          'userName': effectiveUserName,
        });

        // Record stock adjustment history with proper adjustment type mapping
        String adjustmentType;
        double recordedQuantity;

        if (movementType == 'IN') {
          adjustmentType = 'increase';
          recordedQuantity = quantity; // Positive quantity for increase
        } else {
          adjustmentType = 'decrease';
          recordedQuantity =
              quantity; // Positive quantity for decrease (actual amount removed)
        }

        await txn.insert('stock_adjustment_history', {
          'id': _uuid.v4(),
          'productId': productId,
          'productName': info['productName'] as String,
          'categoryId': info['categoryId'] as String? ?? '',
          'categoryName': info['categoryName'] as String? ?? '',
          'quantityAdjusted': recordedQuantity,
          'previousQuantity': currentStock,
          'newQuantity': newStock,
          'adjustmentType': adjustmentType,
          'reason': effectiveNotes,
          'adjustmentDate': now,
          'userId': effectiveUserId,
          'userName': effectiveUserName,
          'notes': effectiveNotes,
        });
      });

      // Update in-memory cache for performance (avoids full reload)
      final stockIndex = _stocks.indexWhere((s) => s.productId == productId);
      if (stockIndex != -1) {
        _stocks[stockIndex] = _stocks[stockIndex].copyWith(
          currentStock: newStock,
          availableStock: newStock,
          lastUpdated: DateTime.now(),
          lastUpdatedBy: effectiveUserId,
        );
        _stocks.refresh(); // Notify GetX observers
      } else {
        // Fallback: reload if not in cache (edge case)
        await loadStocks();
      }

      return {'success': true, 'newStock': newStock};
    } on DatabaseException catch (e) {
      return {
        'success': false,
        'error': 'Database error during stock adjustment: $e',
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to adjust stock: $e'};
    }
  }

  /// Corrects stock to a specific quantity by calculating the difference
  /// and performing the appropriate adjustment
  Future<Map<String, dynamic>> correctStock({
    required String productId,
    required double targetQuantity,
    required String reason,
    String? notes,
    String? userId,
    String? userName,
  }) async {
    if (targetQuantity < 0) {
      return {'success': false, 'error': 'Target quantity cannot be negative'};
    }

    try {
      final db = await _dbHelper.database;

      // Get current stock
      final stockRecord = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );

      double currentStock = 0.0;
      if (stockRecord.isNotEmpty) {
        currentStock = stockRecord.first['currentStock'] as double? ?? 0.0;
      }

      final difference = targetQuantity - currentStock;

      if (difference == 0) {
        return {
          'success': false,
          'error': 'No adjustment needed - target equals current stock',
        };
      }

      // Determine movement type and quantity
      final movementType = difference > 0 ? 'IN' : 'OUT';
      final adjustmentQuantity = difference.abs();

      final correctionNotes =
          notes != null && notes.isNotEmpty ? '$reason - $notes' : reason;

      // Use the existing adjustStock method but record as correction in history
      return await _adjustStockWithCorrectionHistory(
        productId: productId,
        quantity: adjustmentQuantity,
        movementType: movementType,
        targetQuantity: targetQuantity,
        reason: correctionNotes,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      return {'success': false, 'error': 'Failed to correct stock: $e'};
    }
  }

  /// Internal method to handle stock adjustments with correction history
  Future<Map<String, dynamic>> _adjustStockWithCorrectionHistory({
    required String productId,
    required double quantity,
    required String movementType,
    required double targetQuantity,
    required String reason,
    String? userId,
    String? userName,
  }) async {
    final effectiveUserId = userId ?? 'system';
    final effectiveUserName = userName ?? 'System User';
    final now = DateTime.now().toIso8601String();

    try {
      final db = await _dbHelper.database;

      // Get product and current stock info
      final productInfo = await db.rawQuery(
        '''SELECT p.name as productName, c.id as categoryId, c.name as categoryName
           FROM products p
           LEFT JOIN product_categories c ON p.categoryId = c.id
           WHERE p.id = ?''',
        [productId],
      );

      if (productInfo.isEmpty) {
        return {'success': false, 'error': 'Product information not available'};
      }

      final stockRecord = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );

      double currentStock = 0.0;
      bool createNewStock = false;

      if (stockRecord.isEmpty) {
        currentStock = 0.0;
        createNewStock = true;
      } else {
        currentStock = stockRecord.first['currentStock'] as double? ?? 0.0;
      }

      // Perform atomic update
      await db.transaction((txn) async {
        final info = productInfo.first;

        if (createNewStock) {
          await txn.insert('stock', {
            'id': _uuid.v4(),
            'productId': productId,
            'productName': info['productName'] as String,
            'currentStock': targetQuantity,
            'availableStock': targetQuantity,
            'reservedStock': 0.0,
            'lastUpdated': now,
            'lastUpdatedBy': effectiveUserId,
          });
        } else {
          await txn.update(
            'stock',
            {
              'currentStock': targetQuantity,
              'availableStock': targetQuantity,
              'lastUpdated': now,
              'lastUpdatedBy': effectiveUserId,
            },
            where: 'productId = ?',
            whereArgs: [productId],
          );
        }

        // Record stock movement
        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'productId': productId,
          'movementType': movementType,
          'quantity': quantity,
          'balanceBefore': currentStock,
          'balanceAfter': targetQuantity,
          'reference': reason,
          'notes': reason,
          'movementDate': now,
          'userId': effectiveUserId,
          'userName': effectiveUserName,
        });

        // Record stock adjustment history as correction
        await txn.insert('stock_adjustment_history', {
          'id': _uuid.v4(),
          'productId': productId,
          'productName': info['productName'] as String,
          'categoryId': info['categoryId'] as String? ?? '',
          'categoryName': info['categoryName'] as String? ?? '',
          'quantityAdjusted':
              targetQuantity, // For corrections, store the target quantity
          'previousQuantity': currentStock,
          'newQuantity': targetQuantity,
          'adjustmentType': 'correction',
          'reason': reason,
          'adjustmentDate': now,
          'userId': effectiveUserId,
          'userName': effectiveUserName,
          'notes': reason,
        });
      });

      // Update in-memory cache
      final stockIndex = _stocks.indexWhere((s) => s.productId == productId);
      if (stockIndex != -1) {
        _stocks[stockIndex] = _stocks[stockIndex].copyWith(
          currentStock: targetQuantity,
          availableStock: targetQuantity,
          lastUpdated: DateTime.now(),
          lastUpdatedBy: effectiveUserId,
        );
        _stocks.refresh();
      } else {
        await loadStocks();
      }

      return {'success': true, 'newStock': targetQuantity};
    } on DatabaseException catch (e) {
      return {
        'success': false,
        'error': 'Database error during stock correction: $e',
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to correct stock: $e'};
    }
  }

  Future<Map<String, dynamic>> createSale({
    required List<SaleItem> items,
    String? memberId,
    String? memberName,
    String? memberNumber,
    required String saleType,
    required double paidAmount,
    String? notes,
    required String userId,
    required String userName,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final saleId = _uuid.v4();
      final receiptNumber = 'RCP${DateTime.now().millisecondsSinceEpoch}';

      // Calculate and round total amount
      final totalAmount = _roundPrice(
        items.fold(0.0, (sum, item) => sum + item.totalPrice),
      );
      final roundedPaidAmount = _roundPrice(paidAmount);
      final balanceAmount = _roundPrice(totalAmount - roundedPaidAmount);

      final seasonService = Get.find<SeasonService>();
      final currentSeason = seasonService.activeSeason;

      final result = await db.transaction((txn) async {
        await txn.insert('sales', {
          'id': saleId,
          'memberId': memberId,
          'memberName': memberName,
          'memberNumber': memberNumber,
          'saleType': saleType,
          'totalAmount': totalAmount,
          'paidAmount': roundedPaidAmount,
          'balanceAmount': balanceAmount,
          'saleDate': now,
          'receiptNumber': receiptNumber,
          'notes': notes,
          'userId': userId,
          'userName': userName,
          'isActive': 1,
          'createdAt': now,
          'seasonId': currentSeason?.id,
          'seasonName': currentSeason?.name,
        });

        for (final item in items) {
          final saleItemId = _uuid.v4();

          // Round sale item prices
          final roundedItem = {
            ...item.toJson(),
            'id': saleItemId,
            'saleId': saleId,
            'unitPrice': _roundPrice(item.unitPrice),
            'totalPrice': _roundPrice(item.totalPrice),
          };

          await txn.insert('sale_items', roundedItem);

          final productRecord = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          final double masterPackSize =
              productRecord.isNotEmpty
                  ? ((productRecord.first['packSize'] as num?)?.toDouble() ??
                      1.0)
                  : 1.0;
          final double selectedPackSize = item.packSizeSold;
          final double unitsToDeduct =
              item.quantity * (selectedPackSize / masterPackSize);
          final stockRecord = await txn.query(
            'stock',
            where: 'productId = ?',
            whereArgs: [item.productId],
          );
          if (stockRecord.isNotEmpty) {
            final currentStock =
                (stockRecord.first['currentStock'] as num?)?.toDouble() ?? 0.0;
            final newStock = currentStock - unitsToDeduct;
            if (newStock < 0) {
              throw Exception('Insufficient stock for ${item.productName}');
            }
            await txn.update(
              'stock',
              {
                'currentStock': newStock,
                'availableStock': newStock,
                'lastUpdated': now,
                'lastUpdatedBy': userId,
              },
              where: 'productId = ?',
              whereArgs: [item.productId],
            );
            await txn.insert('stock_movements', {
              'id': _uuid.v4(),
              'productId': item.productId,
              'movementType': 'OUT',
              'quantity': unitsToDeduct,
              'balanceBefore': currentStock,
              'balanceAfter': newStock,
              'reference': 'Sale $receiptNumber',
              'notes': 'Sale to ${memberName ?? 'Customer'}',
              'movementDate': now,
              'userId': userId,
              'userName': userName,
            });
          }
        }
        return {
          'success': true,
          'saleId': saleId,
          'receiptNumber': receiptNumber,
        };
      });

      await loadSales();
      await loadStocks();

      return result;
    } on DatabaseException catch (e) {
      // Check if it's a missing column error
      if (e.toString().contains('no such column: memberNumber')) {
        return {
          'success': false,
          'error':
              'Database needs to be updated. Please restart the app to apply migrations.',
        };
      }
      return {'success': false, 'error': 'Database error: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to create sale: $e'};
    }
  }

  Future<Map<String, dynamic>> splitProduct({
    required String productId,
    required double splitSize,
    String? userId,
    String? userName,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final productRecord = await db.query(
        'products',
        where: 'id = ? AND isActive = 1',
        whereArgs: [productId],
      );
      if (productRecord.isEmpty) {
        return {'success': false, 'error': 'Product not found'};
      }

      final originalProduct = Product.fromJson(productRecord.first);
      if (!originalProduct.canBeSplit) {
        return {'success': false, 'error': 'Product cannot be split'};
      }
      if (splitSize <= 0 || splitSize >= originalProduct.packSize) {
        return {'success': false, 'error': 'Invalid split size'};
      }

      final stockRecord = await db.query(
        'stock',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      if (stockRecord.isEmpty) {
        return {'success': false, 'error': 'No stock found for product'};
      }

      final currentStock = stockRecord.first['currentStock'] as double? ?? 0.0;
      if (currentStock < 1) {
        return {'success': false, 'error': 'Insufficient stock to split'};
      }

      final result = await db.transaction((txn) async {
        final splitProductId = _uuid.v4();
        final splitProduct = originalProduct.copyWith(
          id: splitProductId,
          name:
              '${originalProduct.name} ($splitSize${originalProduct.unitOfMeasureName})',
          packSize: splitSize,
          parentProductId: productId,
          isSplitProduct: true,
          originalPackSize: originalProduct.packSize,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await txn.insert('products', splitProduct.toJson());
        await txn.insert('stock', {
          'id': _uuid.v4(),
          'productId': splitProductId,
          'productName': splitProduct.name,
          'currentStock': 0.0,
          'availableStock': 0.0,
          'lastUpdated': now,
          'lastUpdatedBy': userId,
        });

        final splitUnitsPerOriginal = originalProduct.packSize / splitSize;
        await txn.update(
          'stock',
          {
            'currentStock': currentStock - 1,
            'availableStock': currentStock - 1,
            'lastUpdated': now,
            'lastUpdatedBy': userId,
          },
          where: 'productId = ?',
          whereArgs: [productId],
        );
        await txn.update(
          'stock',
          {
            'currentStock': splitUnitsPerOriginal,
            'availableStock': splitUnitsPerOriginal,
            'lastUpdated': now,
            'lastUpdatedBy': userId,
          },
          where: 'productId = ?',
          whereArgs: [splitProductId],
        );

        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'productId': productId,
          'movementType': 'OUT',
          'quantity': 1.0,
          'balanceBefore': currentStock,
          'balanceAfter': currentStock - 1,
          'reference': 'Product Split',
          'notes':
              'Split into $splitSize${originalProduct.unitOfMeasureName} units',
          'movementDate': now,
          'userId': userId,
          'userName': userName,
        });
        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'productId': splitProductId,
          'movementType': 'IN',
          'quantity': splitUnitsPerOriginal,
          'balanceBefore': 0.0,
          'balanceAfter': splitUnitsPerOriginal,
          'reference': 'Product Split',
          'notes': 'Created from splitting ${originalProduct.name}',
          'movementDate': now,
          'userId': userId,
          'userName': userName,
        });

        return {'success': true, 'splitProductId': splitProductId};
      });

      // Reload data after successful transaction
      await loadProducts();
      await loadStocks();

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Failed to split product: $e'};
    }
  }

  Future<List<Product>> getSplitProducts(String parentProductId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'products',
        where: 'parentProductId = ? AND isActive = 1',
        whereArgs: [parentProductId],
        orderBy: 'packSize ASC',
      );
      return maps.map((map) => Product.fromJson(map)).toList();
    } catch (e) {
      print('Error getting split products: $e');
      return [];
    }
  }

  Future<bool> hasBeenSplit(String productId) async {
    try {
      final db = await _dbHelper.database;
      final splitProducts = await db.query(
        'products',
        where: 'parentProductId = ? AND isActive = 1',
        whereArgs: [productId],
      );
      return splitProducts.isNotEmpty;
    } catch (e) {
      print('Error checking if product has been split: $e');
      return false;
    }
  }

  List<Sale> getMemberCreditSales(String memberId) {
    return _sales
        .where((sale) => sale.memberId == memberId && sale.balanceAmount > 0)
        .toList();
  }

  Stock? getStockByProductId(String productId) {
    return _stocks.firstWhereOrNull((s) => s.productId == productId);
  }

  List<Sale> get creditSales =>
      _sales
          .where((s) => s.saleType == 'CREDIT' && s.balanceAmount > 0)
          .toList();

  double getMemberTotalCredit(String memberId) {
    return _sales
        .where((s) => s.memberId == memberId && s.saleType == 'CREDIT')
        .fold(0.0, (sum, sale) => sum + sale.balanceAmount);
  }

  /// Get member's total credit for the current inventory season only
  /// This is used for SMS and receipts to show accurate seasonal totals
  Future<double> getMemberSeasonCredit(String memberId) async {
    try {
      final db = await _dbHelper.database;
      final seasonService = Get.find<SeasonService>();
      final currentSeason = seasonService.activeSeason;

      if (currentSeason == null) {
        print('⚠️  No active inventory season - returning 0 for member credit');
        return 0.0;
      }

      // Query database for current season credit sales only
      final result = await db.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(balanceAmount), 0.0) as totalCredit,
          COUNT(*) as creditSalesCount
        FROM sales 
        WHERE memberId = ? 
          AND saleType = 'CREDIT' 
          AND seasonId = ?
          AND isActive = 1
      ''',
        [memberId, currentSeason.id],
      );

      if (result.isNotEmpty) {
        final data = result.first;
        final totalCredit = data['totalCredit'] as double? ?? 0.0;
        final salesCount = data['creditSalesCount'] as int? ?? 0;

        print('🔍 Member $memberId season credit calculation:');
        print('   - Season: ${currentSeason.name}');
        print('   - Credit Sales Count: $salesCount');
        print(
          '   - Total Credit Balance: KSh ${totalCredit.toStringAsFixed(2)}',
        );

        return totalCredit;
      }

      return 0.0;
    } catch (e) {
      print('❌ Error calculating member season credit: $e');
      return 0.0;
    }
  }

  Future<List<StockAdjustmentHistory>> getFilteredAdjustmentHistory(
    Map<String, dynamic>? filter,
  ) async {
    try {
      final db = await _dbHelper.database;
      String whereClause = '1 = 1';
      List<dynamic> whereArgs = [];

      if (filter != null) {
        if (filter['categoryId'] != null) {
          whereClause += ' AND categoryId = ?';
          whereArgs.add(filter['categoryId']);
        }
        if (filter['productId'] != null) {
          whereClause += ' AND productId = ?';
          whereArgs.add(filter['productId']);
        }
        if (filter['startDate'] != null) {
          whereClause += ' AND adjustmentDate >= ?';
          whereArgs.add((filter['startDate'] as DateTime).toIso8601String());
        }
        if (filter['endDate'] != null) {
          whereClause += ' AND adjustmentDate <= ?';
          whereArgs.add((filter['endDate'] as DateTime).toIso8601String());
        }
      }

      final maps = await db.query(
        'stock_adjustment_history',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'adjustmentDate DESC',
      );
      return maps.map((map) => StockAdjustmentHistory.fromJson(map)).toList();
    } catch (e) {
      print('Error getting filtered adjustment history: $e');
      return [];
    }
  }

  Future<String> exportAdjustmentHistoryToCsv(
    Map<String, dynamic>? filter,
  ) async {
    final history = await getFilteredAdjustmentHistory(filter);
    if (history.isEmpty) {
      return "";
    }
    List<List<dynamic>> rows = [];
    rows.add([
      'Date',
      'Product',
      'Category',
      'Type',
      'Quantity Adjusted',
      'Previous Quantity',
      'New Quantity',
      'Reason',
      'User',
      'Notes',
    ]);
    for (var item in history) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(item.adjustmentDate),
        item.productName,
        item.categoryName,
        item.adjustmentTypeDisplay,
        item.quantityAdjustedDisplay,
        item.previousQuantity,
        item.newQuantity,
        item.reason,
        item.userName,
        item.notes ?? '',
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<bool> generateLowStockAlerts() async => true;
  Future<bool> acknowledgeAlert(String alertId) async => true;
  Future<List<Product>> getProductsInCategory(String categoryId) async =>
      _products.where((p) => p.categoryId == categoryId).toList();
  Future<List<Map<String, dynamic>>> getProductSalesHistory(
    String productId,
  ) async => [];
  Future<List<StockMovement>> getStockMovements(String productId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'stock_movements',
        where: 'productId = ?',
        whereArgs: [productId],
        orderBy: 'movementDate DESC',
      );
      return maps.map((map) => StockMovement.fromJson(map)).toList();
    } catch (e) {
      print('Error getting stock movements: $e');
      return [];
    }
  }

  List<Product> get lowStockProducts {
    List<Product> low = [];
    for (var stock in _stocks) {
      final product = _products.firstWhereOrNull(
        (p) => p.id == stock.productId,
      );
      if (product != null &&
          product.minimumStock != null &&
          stock.currentStock <= product.minimumStock!) {
        low.add(product);
      }
    }
    return low;
  }

  List<Product> get outOfStockProducts =>
      _stocks
          .where((s) => s.currentStock <= 0)
          .map((s) => _products.firstWhere((p) => p.id == s.productId))
          .toList();

  Future<bool> canDeleteCategory(String categoryId) async {
    final products = await getProductsInCategory(categoryId);
    return products.isEmpty;
  }

  Future<bool> canDeleteProduct(String productId) async {
    final sales = _sales.where(
      (s) => s.items.any((item) => item.productId == productId),
    );
    return sales.isEmpty;
  }

  double getTotalStockValue() {
    final total = _stocks.fold(0.0, (total, stock) {
      final product = _products.firstWhereOrNull(
        (p) => p.id == stock.productId,
      );
      return total + (stock.currentStock * (product?.salesPrice ?? 0.0));
    });
    return _roundPrice(total);
  }

  Map<String, int> getCategoryProductCounts() {
    Map<String, int> counts = {};
    for (var category in _categories) {
      counts[category.id] =
          _products.where((p) => p.categoryId == category.id).length;
    }
    return counts;
  }

  Future<List<LowStockAlert>> getFilteredLowStockAlerts({
    String? categoryId,
    String? status,
  }) async => [];

  Future<String> exportSalesToCsv(List<Sale> sales) async {
    final db = await _dbHelper.database;
    List<List<dynamic>> rows = [];
    rows.add([
      'Receipt Number',
      'Date',
      'Member Number',
      'Member Name',
      'Total Amount',
      'Paid Amount',
      'Balance',
      'Sale Type',
      'User',
    ]);
    for (var sale in sales) {
      // If memberNumber is not in the sale record, fetch it from members table
      String? memberNumber = sale.memberNumber;
      if ((memberNumber == null || memberNumber.isEmpty) &&
          sale.memberId != null) {
        final memberRecords = await db.query(
          'members',
          columns: ['memberNumber'],
          where: 'id = ?',
          whereArgs: [sale.memberId],
          limit: 1,
        );
        if (memberRecords.isNotEmpty) {
          memberNumber = memberRecords.first['memberNumber'] as String?;
        }
      }

      rows.add([
        sale.receiptNumber,
        DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate),
        memberNumber ?? 'N/A',
        sale.memberName ?? 'N/A',
        sale.totalAmount,
        sale.paidAmount,
        sale.balanceAmount,
        sale.saleType,
        sale.userName,
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/sales_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }
}
