import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;
  static bool _databaseInitialized = false;

  // Constants
  static const String _inMemoryDatabasePath = ':memory:';

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null && _databaseInitialized) return _database!;
    _database = await _initDatabase();
    _databaseInitialized = true;
    return _database!;
  }

  Future<String> getDatabasePath() async {
    if (kIsWeb) {
      return _inMemoryDatabasePath; // For web, use in-memory database
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms
        Directory documentsDirectory = await getApplicationDocumentsDirectory();
        return join(documentsDirectory.path, 'farm_pro.db');
      } else {
        // Desktop platforms - store in current directory
        return 'farm_pro.db';
      }
    } catch (e) {
      print('Error determining database path: $e');
      // Fallback to current directory
      return 'farm_pro.db';
    }
  }

  Future<Database> _initDatabase() async {
    try {
      String path = await getDatabasePath();
      print('Database path: $path');

      // Open the database
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDb,
        onOpen: (db) {
          print('Database opened successfully');
        },
      );
    } catch (e) {
      print('Error initializing database: $e');
      // Emergency fallback - use in-memory database
      return await openDatabase(
        _inMemoryDatabasePath,
        version: 1,
        onCreate: _createDb,
      );
    }
  }

  Future<void> _createDb(Database db, int version) async {
    // Create Routes table
    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Create Members table with optimized schema and indexes
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        memberNumber TEXT NOT NULL,
        fullName TEXT NOT NULL,
        idNumber TEXT,
        phoneNumber TEXT,
        email TEXT,
        registrationDate TEXT NOT NULL,
        gender TEXT,
        zone TEXT,
        acreage REAL,
        noTrees INTEGER,
        isActive INTEGER DEFAULT 1,
        searchText TEXT, -- Optimized search field
        createdAt INTEGER DEFAULT (strftime('%s', 'now')),
        updatedAt INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Create indexes for optimized queries
    await db.execute(
      'CREATE INDEX idx_members_member_number ON members(memberNumber)',
    );
    await db.execute('CREATE INDEX idx_members_id_number ON members(idNumber)');
    await db.execute('CREATE INDEX idx_members_is_active ON members(isActive)');
    await db.execute('CREATE INDEX idx_members_zone ON members(zone)');
    await db.execute('CREATE INDEX idx_members_full_name ON members(fullName)');
    await db.execute(
      'CREATE INDEX idx_members_search_text ON members(searchText)',
    );
    await db.execute(
      'CREATE INDEX idx_members_created_at ON members(createdAt)',
    );

    // Composite indexes for common queries
    await db.execute(
      'CREATE INDEX idx_members_active_name ON members(isActive, fullName)',
    );
    await db.execute(
      'CREATE INDEX idx_members_zone_active ON members(zone, isActive)',
    );

    // Create Coffee Deliveries table
    await db.execute('''
      CREATE TABLE coffee_deliveries (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        memberNumber TEXT NOT NULL,
        memberName TEXT NOT NULL,
        grossWeight REAL NOT NULL,
        tareWeight REAL DEFAULT 0,
        netWeight REAL NOT NULL,
        deliveryDate TEXT NOT NULL,
        isManualEntry INTEGER NOT NULL,
        receiptNumber TEXT,
        userId TEXT,
        userName TEXT,
        FOREIGN KEY (memberId) REFERENCES members (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        fullName TEXT NOT NULL,
        role INTEGER NOT NULL,
        email TEXT NOT NULL,
        phoneNumber TEXT,
        password TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');

    // Create Organization Settings table
    await db.execute('''
      CREATE TABLE organization_settings (
        id TEXT PRIMARY KEY,
        societyName TEXT NOT NULL,
        logoPath TEXT,
        factory TEXT NOT NULL,
        address TEXT,
        email TEXT,
        phoneNumber TEXT,
        website TEXT,
        slogan TEXT
      )
    ''');

    // Create System Settings table
    await db.execute('''
      CREATE TABLE system_settings (
        id TEXT PRIMARY KEY,
        enablePrinting INTEGER NOT NULL,
        enableSms INTEGER NOT NULL,
        enableSmsForCashSales INTEGER DEFAULT 0,
        enableSmsForCreditSales INTEGER DEFAULT 1,
        enableManualWeightEntry INTEGER NOT NULL,
        enableBluetoothScale INTEGER NOT NULL,
        defaultPrinterAddress TEXT,
        defaultScaleAddress TEXT,
        coffeePrice REAL NOT NULL,
        currency TEXT NOT NULL,
        defaultTareWeight REAL DEFAULT 0.5,
        printMethod TEXT DEFAULT 'bluetooth',
        coffeeProduct TEXT,
        allowProductChange INTEGER DEFAULT 1,
        currentSeasonId TEXT,
        enableInventory INTEGER DEFAULT 1,
        enableCreditSales INTEGER DEFAULT 1,
        receiptDuplicates INTEGER DEFAULT 1,
        autoDisconnectScale INTEGER DEFAULT 0,
        deliveryRestrictionMode TEXT DEFAULT 'multiple',
        
        -- SMS Gateway Configuration columns
        smsGatewayEnabled INTEGER DEFAULT 1,
        smsGatewayUrl TEXT DEFAULT 'https://portal.zettatel.com/SMSApi/send',
        smsGatewayUsername TEXT DEFAULT '',
        smsGatewayPassword TEXT DEFAULT '',
        smsGatewaySenderId TEXT DEFAULT 'FARMPRO',
        smsGatewayApiKey TEXT DEFAULT '',
        smsGatewayFallbackToSim INTEGER DEFAULT 1,

        -- Bulk SMS Settings columns
        enableBulkSms INTEGER DEFAULT 1,
        bulkSmsDefaultMessage TEXT DEFAULT 'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
        bulkSmsIncludeBalance INTEGER DEFAULT 1,
        bulkSmsIncludeName INTEGER DEFAULT 1,
        bulkSmsMaxRecipients INTEGER DEFAULT 50,
        bulkSmsBatchDelay INTEGER DEFAULT 2,
        bulkSmsConfirmBeforeSend INTEGER DEFAULT 1,
        bulkSmsFilterType TEXT DEFAULT 'all',
        bulkSmsLogActivity INTEGER DEFAULT 1
      )
    ''');

    // Create default admin user
    await db.insert('users', {
      'id': 'admin',
      'username': 'admin',
      'fullName': 'Admin',
      'role': 0, // UserRole.admin.index = 0
      'email': 'admin@coffeepro.co.ke',
      'password': 'admin', // In a real app, this would be hashed
      'createdAt': DateTime.now().toIso8601String(),
      'isActive': 1,
    });

    // Create default organization settings
    await db.insert('organization_settings', {
      'id': 'default',
      'societyName': 'Coffee Pro Society',
      'factory': 'Main Factory',
      'address': 'P.O. Box 123, Nairobi',
      'email': 'info@coffeepro.co.ke',
      'phoneNumber': '+254 700 000000',
      'website': 'www.coffeepro.co.ke',
      'slogan': 'Premium Coffee, Premium Returns',
    });

    // Create Seasons table
    await db.execute('''
      CREATE TABLE seasons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        isActive INTEGER DEFAULT 0,
        isClosed INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        closedAt TEXT
      )
    ''');

    // Create Coffee Collections table
    await db.execute('''
      CREATE TABLE coffee_collections (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        memberNumber TEXT NOT NULL,
        memberName TEXT NOT NULL,
        seasonId TEXT NOT NULL,
        seasonName TEXT NOT NULL,
        productType TEXT NOT NULL,
        grossWeight REAL NOT NULL,
        tareWeight REAL DEFAULT 0,
        netWeight REAL NOT NULL,
        pricePerKg REAL,
        totalValue REAL,
        collectionDate TEXT NOT NULL,
        isManualEntry INTEGER NOT NULL,
        receiptNumber TEXT,
        userId TEXT,
        userName TEXT,
        FOREIGN KEY (memberId) REFERENCES members (id),
        FOREIGN KEY (seasonId) REFERENCES seasons (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create Units of Measure table
    await db.execute('''
      CREATE TABLE units_of_measure (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL,
        description TEXT,
        isBaseUnit INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Create Product Categories table
    await db.execute('''
      CREATE TABLE product_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Create Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        categoryId TEXT NOT NULL,
        unitOfMeasureId TEXT NOT NULL,
        salesPrice REAL NOT NULL,
        packSize REAL DEFAULT 1,
        allowPartialSales INTEGER DEFAULT 1,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (categoryId) REFERENCES product_categories (id),
        FOREIGN KEY (unitOfMeasureId) REFERENCES units_of_measure (id)
      )
    ''');

    // Create Stock table
    await db.execute('''
      CREATE TABLE stock (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        quantity REAL NOT NULL,
        lastUpdated TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // Create Stock Adjustment History table
    await db.execute('''
      CREATE TABLE stock_adjustment_history (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        quantityAdjusted REAL NOT NULL,
        previousQuantity REAL NOT NULL,
        newQuantity REAL NOT NULL,
        adjustmentType TEXT NOT NULL,
        reason TEXT NOT NULL,
        adjustmentDate TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (productId) REFERENCES products (id),
        FOREIGN KEY (categoryId) REFERENCES product_categories (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create Low Stock Alerts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS low_stock_alerts (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        currentQuantity REAL NOT NULL,
        minimumLevel REAL NOT NULL,
        shortfall REAL NOT NULL,
        alertDate TEXT NOT NULL,
        severity TEXT NOT NULL,
        isAcknowledged INTEGER NOT NULL DEFAULT 0,
        acknowledgedDate TEXT,
        acknowledgedBy TEXT,
        FOREIGN KEY (productId) REFERENCES products (id),
        FOREIGN KEY (categoryId) REFERENCES product_categories (id)
      )
    ''');

    // Create indexes for stock adjustment history for efficient querying
    await db.execute(
      'CREATE INDEX idx_stock_adjustment_history_product_id ON stock_adjustment_history(productId)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_adjustment_history_category_id ON stock_adjustment_history(categoryId)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_adjustment_history_adjustment_date ON stock_adjustment_history(adjustmentDate)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_adjustment_history_user_id ON stock_adjustment_history(userId)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_adjustment_history_adjustment_type ON stock_adjustment_history(adjustmentType)',
    );

    // Create Sales table
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
        userId TEXT,
        userName TEXT,
        notes TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (memberId) REFERENCES members (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create Sale Items table
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitPrice REAL NOT NULL,
        totalPrice REAL NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales (id),
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // Create Repayments table
    await db.execute('''
      CREATE TABLE repayments (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        memberId TEXT NOT NULL,
        memberName TEXT,
        amount REAL NOT NULL,
        paymentMethod TEXT DEFAULT 'Cash',
        repaymentDate TEXT NOT NULL,
        notes TEXT,
        userId TEXT,
        userName TEXT,
        createdAt TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (saleId) REFERENCES sales (id),
        FOREIGN KEY (memberId) REFERENCES members (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create default system settings
    await db.insert('system_settings', {
      'id': 'default',
      'enablePrinting': 1,
      'enableSms': 1,
      'enableSmsForCashSales': 0,
      'enableSmsForCreditSales': 1,
      'enableManualWeightEntry': 1,
      'enableBluetoothScale': 1,
      'coffeePrice': 120.0,
      'currency': 'KES',
      'defaultTareWeight': 0.5,
      'printMethod': 'bluetooth',
      'allowProductChange': 1,
      'enableInventory': 1,
      'enableCreditSales': 1,
      'receiptDuplicates': 1,
      'autoDisconnectScale': 0,
      'deliveryRestrictionMode': 'multiple',

      // SMS Gateway Configuration defaults
      'smsGatewayEnabled': 1,
      'smsGatewayUrl': 'https://portal.zettatel.com/SMSApi/send',
      'smsGatewayUsername': '',
      'smsGatewayPassword': '',
      'smsGatewaySenderId': 'FARMPRO',
      'smsGatewayApiKey': '',
      'smsGatewayFallbackToSim': 1,

      // Bulk SMS Settings defaults
      'enableBulkSms': 1,
      'bulkSmsDefaultMessage':
          'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
      'bulkSmsIncludeBalance': 1,
      'bulkSmsIncludeName': 1,
      'bulkSmsMaxRecipients': 50,
      'bulkSmsBatchDelay': 2,
      'bulkSmsConfirmBeforeSend': 1,
      'bulkSmsFilterType': 'all',
      'bulkSmsLogActivity': 1,
    });

    // Create default route
    await db.insert('routes', {
      'id': 'default',
      'name': 'Default Route',
      'description': 'Default route for all members',
      'isActive': 1,
    });

    // Create default units of measure
    await db.insert('units_of_measure', {
      'id': 'kg',
      'name': 'Kilogram',
      'abbreviation': 'kg',
      'description': 'Weight measurement',
      'isBaseUnit': 1,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await db.insert('units_of_measure', {
      'id': 'pcs',
      'name': 'Pieces',
      'abbreviation': 'pcs',
      'description': 'Count measurement',
      'isBaseUnit': 0,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await db.insert('units_of_measure', {
      'id': 'ltr',
      'name': 'Liter',
      'abbreviation': 'L',
      'description': 'Volume measurement',
      'isBaseUnit': 0,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Create default product categories
    await db.insert('product_categories', {
      'id': 'fertilizer',
      'name': 'Fertilizers',
      'description': 'Farm fertilizers and soil amendments',
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await db.insert('product_categories', {
      'id': 'pesticide',
      'name': 'Pesticides',
      'description': 'Crop protection products',
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await db.insert('product_categories', {
      'id': 'equipment',
      'name': 'Farm Equipment',
      'description': 'Farming tools and equipment',
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Create app_settings table for custom settings
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT
      )
    ''');
  }

  // Helper method to convert 1/0 to true/false
  bool intToBool(int value) => value == 1;

  // Helper method to convert true/false to 1/0
  int boolToInt(bool value) => value ? 1 : 0;

  // Update database schema if needed
  Future<void> updateDatabaseSchema() async {
    final db = await database;

    try {
      print('Starting database schema update...');
      // Batch all schema checks and updates to reduce database calls
      await db.transaction((txn) async {
        // Check if organization_settings table has slogan and factory columns
        var orgTableInfo = await txn.rawQuery(
          "PRAGMA table_info(organization_settings)",
        );
        bool hasSloganColumn = orgTableInfo.any(
          (column) => column['name'] == 'slogan',
        );
        bool hasFactoryColumn = orgTableInfo.any(
          (column) => column['name'] == 'factory',
        );

        if (!hasSloganColumn) {
          print('Adding slogan column to organization_settings table');
          await txn.execute(
            'ALTER TABLE organization_settings ADD COLUMN slogan TEXT',
          );
        }

        if (!hasFactoryColumn) {
          print('Adding factory column to organization_settings table');
          await txn.execute(
            'ALTER TABLE organization_settings ADD COLUMN factory TEXT NOT NULL DEFAULT "Main Factory"',
          );
        }

        // Check and update system_settings table
        var sysTableInfo = await txn.rawQuery(
          "PRAGMA table_info(system_settings)",
        );

        // Batch check all columns at once
        final requiredColumns = {
          'defaultTareWeight': 'REAL DEFAULT 0.5',
          'printMethod': 'TEXT DEFAULT "bluetooth"',
          'coffeePrice': 'REAL DEFAULT 120.0',
          'coffeeProduct': 'TEXT',
          'allowProductChange': 'INTEGER DEFAULT 1',
          'currentSeasonId': 'TEXT',
          'enableInventory': 'INTEGER DEFAULT 1',
          'enableCreditSales': 'INTEGER DEFAULT 1',
          'receiptDuplicates': 'INTEGER DEFAULT 1',
          'autoDisconnectScale': 'INTEGER DEFAULT 0',
          'deliveryRestrictionMode': 'TEXT DEFAULT "multiple"',
          'enableSmsForCashSales': 'INTEGER DEFAULT 0',
          'enableSmsForCreditSales': 'INTEGER DEFAULT 1',

          // SMS Gateway Configuration columns
          'smsGatewayEnabled': 'INTEGER DEFAULT 1',
          'smsGatewayUrl':
              'TEXT DEFAULT "https://portal.zettatel.com/SMSApi/send"',
          'smsGatewayUsername': 'TEXT DEFAULT ""',
          'smsGatewayPassword': 'TEXT DEFAULT ""',
          'smsGatewaySenderId': 'TEXT DEFAULT "FARMPRO"',
          'smsGatewayApiKey': 'TEXT DEFAULT ""',
          'smsGatewayFallbackToSim': 'INTEGER DEFAULT 1',

          // Bulk SMS Settings columns
          'enableBulkSms': 'INTEGER DEFAULT 1',
          'bulkSmsDefaultMessage':
              'TEXT DEFAULT "Dear {name}, your current balance is KSh {balance}. Thank you for your business."',
          'bulkSmsIncludeBalance': 'INTEGER DEFAULT 1',
          'bulkSmsIncludeName': 'INTEGER DEFAULT 1',
          'bulkSmsMaxRecipients': 'INTEGER DEFAULT 50',
          'bulkSmsBatchDelay': 'INTEGER DEFAULT 2',
          'bulkSmsConfirmBeforeSend': 'INTEGER DEFAULT 1',
          'bulkSmsFilterType': 'TEXT DEFAULT "all"',
          'bulkSmsLogActivity': 'INTEGER DEFAULT 1',
        };

        final existingColumns =
            sysTableInfo.map((col) => col['name'] as String).toSet();

        for (final entry in requiredColumns.entries) {
          if (!existingColumns.contains(entry.key)) {
            print('Adding ${entry.key} column to system_settings table');
            await txn.execute(
              'ALTER TABLE system_settings ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }

        // Handle special case for coffeePrice migration from coffeePrice
        if (!existingColumns.contains('coffeePrice') &&
            existingColumns.contains('coffeePrice')) {
          await txn.execute(
            'UPDATE system_settings SET coffeePrice = coffeePrice WHERE coffeePrice IS NULL',
          );
        }

        // Check and update members table to remove route fields and add new fields
        await _updateMembersTableOptimized(txn);

        // Check and update seasons table
        var seasonTableInfo = await txn.rawQuery("PRAGMA table_info(seasons)");
        bool hasClosedAtColumn = seasonTableInfo.any(
          (column) => column['name'] == 'closedAt',
        );

        if (!hasClosedAtColumn) {
          print('Adding closedAt column to seasons table');
          await txn.execute('ALTER TABLE seasons ADD COLUMN closedAt TEXT');
        }

        // Check and update units_of_measure table
        var unitsTableInfo = await txn.rawQuery(
          "PRAGMA table_info(units_of_measure)",
        );
        final unitsExistingColumns =
            unitsTableInfo.map((col) => col['name'] as String).toSet();

        if (!unitsExistingColumns.contains('abbreviation')) {
          print('Adding abbreviation column to units_of_measure table');
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN abbreviation TEXT',
          );
          // Copy symbol to abbreviation if symbol exists
          if (unitsExistingColumns.contains('symbol')) {
            await txn.execute(
              'UPDATE units_of_measure SET abbreviation = symbol WHERE abbreviation IS NULL',
            );
          }
        }

        if (!unitsExistingColumns.contains('isBaseUnit')) {
          print('Adding isBaseUnit column to units_of_measure table');
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN isBaseUnit INTEGER DEFAULT 0',
          );
        }

        if (!unitsExistingColumns.contains('createdAt')) {
          print('Adding createdAt column to units_of_measure table');
          await txn.execute(
            'ALTER TABLE units_of_measure ADD COLUMN createdAt TEXT DEFAULT (datetime("now"))',
          );
        }

        // Check and update products table to add missing columns
        print('Checking products table schema...');
        var productsTableInfo = await txn.rawQuery(
          "PRAGMA table_info(products)",
        );
        final productsExistingColumns =
            productsTableInfo.map((col) => col['name'] as String).toSet();
        print('Existing products table columns: $productsExistingColumns');

        final requiredProductColumns = {
          'categoryName': 'TEXT',
          'unitOfMeasureName': 'TEXT',
          'costPrice': 'REAL',
          'minimumStock': 'REAL',
          'maximumStock': 'REAL',
          'barcode': 'TEXT',
          'sku': 'TEXT',
          'updatedAt': 'TEXT',
        };

        for (final entry in requiredProductColumns.entries) {
          if (!productsExistingColumns.contains(entry.key)) {
            print('Adding ${entry.key} column to products table');
            await txn.execute(
              'ALTER TABLE products ADD COLUMN ${entry.key} ${entry.value}',
            );
          } else {
            print('Column ${entry.key} already exists in products table');
          }
        }

        // Check and update stock table to match inventory service schema
        var stockTableInfo = await txn.rawQuery("PRAGMA table_info(stock)");
        final stockExistingColumns =
            stockTableInfo.map((col) => col['name'] as String).toSet();

        final requiredStockColumns = {
          'productName': 'TEXT',
          'currentStock': 'REAL NOT NULL DEFAULT 0',
          'availableStock': 'REAL NOT NULL DEFAULT 0',
          'reservedStock': 'REAL NOT NULL DEFAULT 0',
          'lastUpdatedBy': 'TEXT',
        };

        for (final entry in requiredStockColumns.entries) {
          if (!stockExistingColumns.contains(entry.key)) {
            print('Adding ${entry.key} column to stock table');
            await txn.execute(
              'ALTER TABLE stock ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }

        // Migrate old stock table structure if needed
        if (stockExistingColumns.contains('quantity') &&
            !stockExistingColumns.contains('currentStock')) {
          print('Migrating stock table from old structure');
          await txn.execute('''
            UPDATE stock 
            SET currentStock = quantity, availableStock = quantity
            WHERE currentStock IS NULL
          ''');
        }

        // Update categoryName and unitOfMeasureName for existing products
        if (!productsExistingColumns.contains('categoryName')) {
          print('Updating categoryName for existing products');
          await txn.execute('''
            UPDATE products 
            SET categoryName = (
              SELECT pc.name 
              FROM product_categories pc 
              WHERE pc.id = products.categoryId
            )
            WHERE categoryName IS NULL
          ''');
        }

        if (!productsExistingColumns.contains('unitOfMeasureName')) {
          print('Updating unitOfMeasureName for existing products');
          await txn.execute('''
            UPDATE products 
            SET unitOfMeasureName = (
              SELECT uom.name 
              FROM units_of_measure uom 
              WHERE uom.id = products.unitOfMeasureId
            )
            WHERE unitOfMeasureName IS NULL
          ''');
        }

        // Update productName in stock table for existing records
        if (!stockExistingColumns.contains('productName')) {
          print('Updating productName for existing stock records');
          await txn.execute('''
            UPDATE stock 
            SET productName = (
              SELECT p.name 
              FROM products p 
              WHERE p.id = stock.productId
            )
            WHERE productName IS NULL
          ''');
        }

        // Check and create stock_adjustment_history table if it doesn't exist
        var tables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='stock_adjustment_history'",
        );

        if (tables.isEmpty) {
          print('Creating stock_adjustment_history table');
          await txn.execute('''
            CREATE TABLE stock_adjustment_history (
              id TEXT PRIMARY KEY,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              categoryId TEXT NOT NULL,
              categoryName TEXT NOT NULL,
              quantityAdjusted REAL NOT NULL,
              previousQuantity REAL NOT NULL,
              newQuantity REAL NOT NULL,
              adjustmentType TEXT NOT NULL,
              reason TEXT NOT NULL,
              adjustmentDate TEXT NOT NULL,
              userId TEXT NOT NULL,
              userName TEXT NOT NULL,
              notes TEXT,
              FOREIGN KEY (productId) REFERENCES products (id),
              FOREIGN KEY (categoryId) REFERENCES product_categories (id),
              FOREIGN KEY (userId) REFERENCES users (id)
            )
          ''');

          // Create indexes for stock adjustment history for efficient querying
          await txn.execute(
            'CREATE INDEX idx_stock_adjustment_history_product_id ON stock_adjustment_history(productId)',
          );
          await txn.execute(
            'CREATE INDEX idx_stock_adjustment_history_category_id ON stock_adjustment_history(categoryId)',
          );
          await txn.execute(
            'CREATE INDEX idx_stock_adjustment_history_adjustment_date ON stock_adjustment_history(adjustmentDate)',
          );
          await txn.execute(
            'CREATE INDEX idx_stock_adjustment_history_user_id ON stock_adjustment_history(userId)',
          );
          await txn.execute(
            'CREATE INDEX idx_stock_adjustment_history_adjustment_type ON stock_adjustment_history(adjustmentType)',
          );
        }

        // Check and create low_stock_alerts table if it doesn't exist
        var alertTables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='low_stock_alerts'",
        );

        if (alertTables.isEmpty) {
          print('Creating low_stock_alerts table');
          await txn.execute('''
            CREATE TABLE low_stock_alerts (
              id TEXT PRIMARY KEY,
              productId TEXT NOT NULL,
              productName TEXT NOT NULL,
              categoryId TEXT NOT NULL,
              categoryName TEXT NOT NULL,
              currentQuantity REAL NOT NULL,
              minimumLevel REAL NOT NULL,
              shortfall REAL NOT NULL,
              alertDate TEXT NOT NULL,
              severity TEXT NOT NULL,
              isAcknowledged INTEGER NOT NULL DEFAULT 0,
              acknowledgedDate TEXT,
              acknowledgedBy TEXT,
              FOREIGN KEY (productId) REFERENCES products (id),
              FOREIGN KEY (categoryId) REFERENCES product_categories (id)
            )
          ''');

          // Create indexes for low stock alerts for efficient querying
          await txn.execute(
            'CREATE INDEX idx_low_stock_alerts_product_id ON low_stock_alerts(productId)',
          );
          await txn.execute(
            'CREATE INDEX idx_low_stock_alerts_category_id ON low_stock_alerts(categoryId)',
          );
          await txn.execute(
            'CREATE INDEX idx_low_stock_alerts_severity ON low_stock_alerts(severity)',
          );
          await txn.execute(
            'CREATE INDEX idx_low_stock_alerts_acknowledged ON low_stock_alerts(isAcknowledged)',
          );
          await txn.execute(
            'CREATE INDEX idx_low_stock_alerts_alert_date ON low_stock_alerts(alertDate)',
          );
        }

        // Check sales table for new columns
        var salesTableInfo = await txn.rawQuery("PRAGMA table_info(sales)");
        bool hasReceiptNumber = salesTableInfo.any(
          (c) => c['name'] == 'receiptNumber',
        );
        bool hasItemsColumn = salesTableInfo.any((c) => c['name'] == 'items');
        if (!hasReceiptNumber) {
          print('Adding receiptNumber column to sales table');
          await txn.execute('ALTER TABLE sales ADD COLUMN receiptNumber TEXT');
        }
        if (!hasItemsColumn) {
          print('Adding items column to sales table');
          await txn.execute('ALTER TABLE sales ADD COLUMN items TEXT');
        }
      });

      print('Database schema update completed successfully');
    } catch (e) {
      print('Error updating database schema: $e');
      // Don't throw error to prevent app crash - schema updates are not critical for basic functionality
    }
  }

  Future<void> _updateMembersTableOptimized(Transaction txn) async {
    try {
      // Get current table structure
      var tableInfo = await txn.rawQuery("PRAGMA table_info(members)");
      final existingColumns =
          tableInfo.map((col) => col['name'] as String).toSet();

      // Define required columns
      final requiredColumns = {
        'zone': 'TEXT',
        'acreage': 'REAL',
        'noTrees': 'INTEGER',
      };

      // Add missing columns
      for (final entry in requiredColumns.entries) {
        if (!existingColumns.contains(entry.key)) {
          print('Adding ${entry.key} column to members table');
          await txn.execute(
            'ALTER TABLE members ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }

      // Remove route-related columns if they exist (optional cleanup)
      final routeColumns = ['routeId', 'routeName'];
      for (final column in routeColumns) {
        if (existingColumns.contains(column)) {
          print(
            'Note: $column column exists but will not be removed to avoid data loss',
          );
          // We don't remove columns as SQLite doesn't support DROP COLUMN easily
          // and it's safer to leave them for data preservation
        }
      }
    } catch (e) {
      print('Error updating members table: $e');
      // Continue without throwing to prevent app crash
    }
  }

  // Backup database to external storage
  Future<void> backupDatabase() async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Create backup filename with timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupFileName = 'farm_pro_backup_$timestamp.db';

      // Get external storage directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('External storage not available');
      }

      final backupPath = '${directory.path}/$backupFileName';

      // Copy database file to backup location
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);

      print('Database backed up to: $backupPath');
    } catch (e) {
      print('Error backing up database: $e');
      throw Exception('Failed to backup database: $e');
    }
  }

  // Clear all coffee collections
  Future<void> clearCoffeeCollections() async {
    try {
      final db = await database;
      await db.delete('coffee_collections');
      print('All coffee collections cleared');
    } catch (e) {
      print('Error clearing coffee collections: $e');
      throw Exception('Failed to clear coffee collections: $e');
    }
  }
}
