import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'season_service.dart';
import 'settings_service.dart';
import 'sms_service.dart';

class CoffeeCollectionService extends GetxService {
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  SeasonService get _seasonService => Get.find<SeasonService>();
  SettingsService get _settingsService => Get.find<SettingsService>();
  final Uuid _uuid = const Uuid();

  final RxList<CoffeeCollection> _collections = <CoffeeCollection>[].obs;
  final RxList<CoffeeCollection> _todaysCollections = <CoffeeCollection>[].obs;

  List<CoffeeCollection> get collections => _collections;
  List<CoffeeCollection> get todaysCollections => _todaysCollections;

  // Expose reactive collections for real-time updates
  RxList<CoffeeCollection> get reactiveCollections => _collections;
  RxList<CoffeeCollection> get reactiveTodaysCollections => _todaysCollections;

  Future<CoffeeCollectionService> init() async {
    await _createCollectionTable();
    // Load only today's collections at startup for immediate use
    await loadTodaysCollections();

    // Load all collections in background
    _loadAllCollectionsInBackground();
    return this;
  }

  Future<void> _createCollectionTable() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS coffee_collections (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        memberNumber TEXT NOT NULL,
        memberName TEXT NOT NULL,
        seasonId TEXT NOT NULL,
        seasonName TEXT NOT NULL,
        productType TEXT NOT NULL,
        grossWeight REAL NOT NULL,
        tareWeight REAL NOT NULL DEFAULT 0.0,
        netWeight REAL NOT NULL,
        numberOfBags INTEGER NOT NULL DEFAULT 1,
        collectionDate TEXT NOT NULL,
        isManualEntry INTEGER NOT NULL DEFAULT 0,
        receiptNumber TEXT,
        userId TEXT,
        userName TEXT,
        pricePerKg REAL,
        totalValue REAL,
        FOREIGN KEY(memberId) REFERENCES members(id),
        FOREIGN KEY(seasonId) REFERENCES seasons(id)
      )
    ''');

    // Add numberOfBags column to existing tables (migration)
    // Check if column exists before attempting to add it
    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(coffee_collections)',
      );
      final hasNumberOfBags = tableInfo.any(
        (column) => column['name'] == 'numberOfBags',
      );

      if (!hasNumberOfBags) {
        await db.execute(
          'ALTER TABLE coffee_collections ADD COLUMN numberOfBags INTEGER NOT NULL DEFAULT 1',
        );
        print('Added numberOfBags column to coffee_collections table');
      } else {
        print('numberOfBags column already exists, skipping migration');
      }
    } catch (e) {
      print('Error during numberOfBags column migration: $e');
    }
  }

  Future<void> loadCollections() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'coffee_collections',
        orderBy: 'collectionDate DESC',
      );

      _collections.value =
          maps.map((map) => CoffeeCollection.fromJson(map)).toList();
    } catch (e) {
      print('Error loading collections: $e');
    }
  }

  Future<void> loadTodaysCollections() async {
    try {
      final db = await _dbHelper.database;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final List<Map<String, dynamic>> maps = await db.query(
        'coffee_collections',
        where: 'collectionDate >= ? AND collectionDate < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        orderBy: 'collectionDate DESC',
      );

      _todaysCollections.value =
          maps.map((map) => CoffeeCollection.fromJson(map)).toList();
    } catch (e) {
      print('Error loading today\'s collections: $e');
    }
  }

  Future<CoffeeCollection?> addCollection({
    required String memberId,
    required String memberNumber,
    required String memberName,
    required double grossWeight,
    required double tareWeight,
    int numberOfBags = 1,
    required bool isManualEntry,
    String? userId,
    String? userName,
  }) async {
    try {
      // Check if season is active
      if (!_seasonService.canStartCollection()) {
        throw Exception(AppConstants.seasonClosedMessage);
      }

      final currentSeason = _seasonService.currentSeason!;
      final systemSettings = _settingsService.systemSettings.value;

      final db = await _dbHelper.database;

      // Check delivery restriction if in single mode
      if (systemSettings.deliveryRestrictionMode == 'single') {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final existingCollections = await db.query(
          'coffee_collections',
          where: 'memberId = ? AND collectionDate >= ? AND collectionDate < ?',
          whereArgs: [
            memberId,
            startOfDay.toIso8601String(),
            endOfDay.toIso8601String(),
          ],
        );

        if (existingCollections.isNotEmpty) {
          throw Exception(
            'Member $memberName has already made a delivery today. Only one delivery per day is allowed.',
          );
        }
      }
      final netWeight = grossWeight - tareWeight;

      // Generate receipt number
      final receiptNumber = await _generateReceiptNumber();

      final collection = CoffeeCollection(
        id: _uuid.v4(),
        memberId: memberId,
        memberNumber: memberNumber,
        memberName: memberName,
        seasonId: currentSeason.id,
        seasonName: currentSeason.name,
        productType: systemSettings.coffeeProduct,
        grossWeight: grossWeight,
        tareWeight: tareWeight,
        netWeight: netWeight,
        numberOfBags: numberOfBags,
        collectionDate: DateTime.now(),
        isManualEntry: isManualEntry,
        receiptNumber: receiptNumber,
        userId: userId,
        userName: userName,
        pricePerKg: null,
        totalValue: null,
      );

      await db.insert('coffee_collections', collection.toJson());
      await loadCollections();
      await loadTodaysCollections();

      return collection;
    } catch (e) {
      print('Error adding collection: $e');
      return null;
    }
  }

  Future<String> _generateReceiptNumber() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final datePrefix =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    // Get count of today's collections
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM coffee_collections 
      WHERE collectionDate >= ? AND collectionDate < ?
    ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    final count = result.first['count'] as int;
    final sequenceNumber = (count + 1).toString().padLeft(4, '0');

    return 'COF$datePrefix$sequenceNumber';
  }

  Future<bool> updateCollection(CoffeeCollection collection) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'coffee_collections',
        collection.toJson(),
        where: 'id = ?',
        whereArgs: [collection.id],
      );

      await loadCollections();
      await loadTodaysCollections();
      return true;
    } catch (e) {
      print('Error updating collection: $e');
      return false;
    }
  }

  Future<bool> deleteCollection(String collectionId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'coffee_collections',
        where: 'id = ?',
        whereArgs: [collectionId],
      );

      await loadCollections();
      await loadTodaysCollections();
      return true;
    } catch (e) {
      print('Error deleting collection: $e');
      return false;
    }
  }

  /// Delete all collections (used for clearing data after export)
  Future<Map<String, dynamic>> deleteAllCollections() async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete('coffee_collections');

      await loadCollections();
      await loadTodaysCollections();

      return {
        'success': true,
        'deletedCount': count,
        'message': 'Successfully deleted $count collection(s)',
      };
    } catch (e) {
      print('Error deleting all collections: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<CoffeeCollection>> getMemberCollections(
    String memberId, {
    String? seasonId,
  }) async {
    try {
      final db = await _dbHelper.database;
      String whereClause = 'memberId = ?';
      List<dynamic> whereArgs = [memberId];

      if (seasonId != null) {
        whereClause += ' AND seasonId = ?';
        whereArgs.add(seasonId);
      } else if (_seasonService.currentSeason != null) {
        whereClause += ' AND seasonId = ?';
        whereArgs.add(_seasonService.currentSeason!.id);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'coffee_collections',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'collectionDate DESC',
      );

      return maps.map((map) => CoffeeCollection.fromJson(map)).toList();
    } catch (e) {
      print('Error getting member collections: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getMemberAllTimeSummary(String memberId) async {
    try {
      final db = await _dbHelper.database;

      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as totalCollections,
          SUM(netWeight) as totalWeight
        FROM coffee_collections 
        WHERE memberId = ?
      ''',
        [memberId],
      );

      if (result.isNotEmpty) {
        final data = result.first;
        return {
          'totalCollections': data['totalCollections'] ?? 0,
          'totalWeight': data['totalWeight'] ?? 0.0,
        };
      }

      return {'totalCollections': 0, 'totalWeight': 0.0};
    } catch (e) {
      print('Error getting member all-time summary: $e');
      return {'totalCollections': 0, 'totalWeight': 0.0};
    }
  }

  Future<Map<String, dynamic>> getMemberSeasonSummary(
    String memberId, {
    String? seasonId,
  }) async {
    try {
      final db = await _dbHelper.database;
      final systemSettings = _settingsService.systemSettings.value;

      String whereClause = 'memberId = ?';
      List<dynamic> whereArgs = [memberId];

      if (seasonId != null) {
        whereClause += ' AND seasonId = ?';
        whereArgs.add(seasonId);
      } else if (_seasonService.currentSeason != null) {
        whereClause += ' AND seasonId = ?';
        whereArgs.add(_seasonService.currentSeason!.id);
      }

      // Get current season/specific season totals with NULL handling
      final seasonResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalCollections,
          COALESCE(SUM(netWeight), 0.0) as totalWeight
        FROM coffee_collections 
        WHERE $whereClause
      ''', whereArgs);

      // Get cumulative totals for current crop and season ONLY (not all-time across all seasons)
      // This ensures SMS and receipts show totals for the current crop and season
      String cumulativeWhereClause = 'memberId = ?';
      List<dynamic> cumulativeWhereArgs = [memberId];

      // Filter by current coffee season if available
      if (_seasonService.activeCoffeeSeason != null) {
        cumulativeWhereClause += ' AND seasonId = ?';
        cumulativeWhereArgs.add(_seasonService.activeCoffeeSeason!.id);
      }

      // Filter by current crop type if available
      cumulativeWhereClause += ' AND productType = ?';
      cumulativeWhereArgs.add(systemSettings.coffeeProduct);

      final allTimeResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as allTimeCollections,
          COALESCE(SUM(CAST(netWeight AS REAL)), 0.0) as allTimeWeight,
          SUM(CAST(netWeight AS REAL)) as rawSum,
          COUNT(CASE WHEN netWeight IS NOT NULL THEN 1 END) as nonNullCount
        FROM coffee_collections 
        WHERE $cumulativeWhereClause
      ''', cumulativeWhereArgs);

      Map<String, dynamic> result = {
        'totalCollections': 0,
        'totalWeight': 0.0,
        'allTimeCollections': 0,
        'allTimeWeight': 0.0,
      };

      if (seasonResult.isNotEmpty) {
        final data = seasonResult.first;
        result['totalCollections'] = data['totalCollections'] ?? 0;
        result['totalWeight'] = data['totalWeight'] ?? 0.0;
      }

      if (allTimeResult.isNotEmpty) {
        final data = allTimeResult.first;
        result['allTimeCollections'] = data['allTimeCollections'] ?? 0;
        result['allTimeWeight'] = data['allTimeWeight'] ?? 0.0;

        // Debug logging for SMS issue
        print(
          '🔍 DB Debug - Member $memberId cumulative summary (current season & crop only):',
        );
        print(
          '   - Season: ${_seasonService.activeCoffeeSeason?.name ?? "No active coffee season"}',
        );
        print('   - Crop Type: ${systemSettings.coffeeProduct}');
        print('   - Query: WHERE $cumulativeWhereClause');
        print('   - Args: $cumulativeWhereArgs');
        print(
          '   - Cumulative Collections: ${data['allTimeCollections']} (${data['allTimeCollections'].runtimeType})',
        );
        print(
          '   - Cumulative Weight (COALESCE): ${data['allTimeWeight']} (${data['allTimeWeight'].runtimeType})',
        );
        print(
          '   - Raw SUM: ${data['rawSum']} (${data['rawSum'].runtimeType})',
        );
        print(
          '   - Non-null count: ${data['nonNullCount']} (${data['nonNullCount'].runtimeType})',
        );
      }

      return result;
    } catch (e) {
      print('Error getting member season summary: $e');
      return {
        'totalCollections': 0,
        'totalWeight': 0.0,
        'allTimeCollections': 0,
        'allTimeWeight': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> getSeasonSummary({String? seasonId}) async {
    try {
      final db = await _dbHelper.database;
      String whereClause = '1 = 1';
      List<dynamic> whereArgs = [];

      if (seasonId != null) {
        whereClause = 'seasonId = ?';
        whereArgs.add(seasonId);
      } else if (_seasonService.currentSeason != null) {
        whereClause = 'seasonId = ?';
        whereArgs.add(_seasonService.currentSeason!.id);
      }

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalCollections,
          COUNT(DISTINCT memberId) as totalMembers,
          SUM(netWeight) as totalWeight
        FROM coffee_collections 
        WHERE $whereClause
      ''', whereArgs);

      if (result.isNotEmpty) {
        final data = result.first;
        return {
          'totalCollections': data['totalCollections'] ?? 0,
          'totalMembers': data['totalMembers'] ?? 0,
          'totalWeight': data['totalWeight'] ?? 0.0,
        };
      }

      return {'totalCollections': 0, 'totalMembers': 0, 'totalWeight': 0.0};
    } catch (e) {
      print('Error getting season summary: $e');
      return {'totalCollections': 0, 'totalMembers': 0, 'totalWeight': 0.0};
    }
  }

  double get todaysTotalWeight {
    return _todaysCollections.fold(
      0.0,
      (sum, collection) => sum + collection.netWeight,
    );
  }

  int get todaysTotalCollections => _todaysCollections.length;

  // Load all collections in background to avoid blocking startup
  void _loadAllCollectionsInBackground() {
    Future.delayed(const Duration(milliseconds: 200), () async {
      try {
        await loadCollections();
        print('All coffee collections loaded in background');
      } catch (e) {
        print('Error loading all collections in background: $e');
      }
    });
  }

  // Import collections from CSV
  Future<List<CoffeeCollection>> importCollectionsFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) {
        throw Exception('No file selected');
      }

      File file = File(result.files.single.path!);
      String csvContent = await file.readAsString();

      // Parse CSV
      List<List<dynamic>> csvData = const CsvToListConverter().convert(
        csvContent,
      );

      if (csvData.isEmpty) {
        throw Exception('CSV file is empty');
      }

      List<CoffeeCollection> importedCollections = [];
      List<String> errors = [];
      int skippedRows = 0;

      // Get required services
      // final memberService = Get.find<MemberService>();
      AuthService? authService;
      User? currentUser;

      try {
        authService = Get.find<AuthService>();
        currentUser = authService.currentUser.value;
      } catch (e) {
        print('AuthService not found, using default user info for import');
        currentUser = null;
      }

      // Check if season is active
      if (!_seasonService.canStartCollection()) {
        throw Exception(AppConstants.seasonClosedMessage);
      }

      final currentSeason = _seasonService.currentSeason!;
      final systemSettings = _settingsService.systemSettings.value;

      // Get organization settings for SMS compatibility
      final orgSettings = _settingsService.organizationSettings.value;
      final societyName = orgSettings.societyName;
      final factoryName = orgSettings.factory;

      print('🏢 Import Settings:');
      print('   - Society: $societyName');
      print('   - Factory: $factoryName');
      print('   - Product Type: ${systemSettings.coffeeProduct}');
      print('   - Current User: ${currentUser?.fullName ?? "CSV Import"}');
      print('   - Season: ${currentSeason.name}');

      // Validate CSV header
      if (csvData.isNotEmpty) {
        final headerRow = csvData[0];
        print('CSV Header detected: ${headerRow.join(", ")}');

        // Check if header contains expected columns (case-insensitive)
        final headerStr = headerRow.join('|').toLowerCase();
        final hasValidHeaders =
            headerStr.contains('member') &&
            (headerStr.contains('net weight') ||
                headerStr.contains('weight')) &&
            headerStr.contains('date');

        if (!hasValidHeaders) {
          print(
            '⚠️  Header validation warning - Expected columns: Member Number, Net Weight (kg), Date',
          );
          print('   Found header: ${headerRow.join(", ")}');

          // Still proceed but add warning to errors
          errors.add(
            'Warning: CSV header may not match expected format. Expected: Member Number, Net Weight (kg), Date',
          );
        }
      }

      // Remove header row and empty/comment rows
      List<List<dynamic>> dataRows = [];
      for (int i = 1; i < csvData.length; i++) {
        List<dynamic> row = csvData[i];
        // Skip empty rows and comment rows
        if (row.isEmpty ||
            (row.length == 1 &&
                (row[0] == null || row[0].toString().trim().isEmpty)) ||
            (row.isNotEmpty && row[0].toString().trim().startsWith('#'))) {
          skippedRows++;
          continue;
        }
        dataRows.add(row);
      }

      final totalRows = dataRows.length;
      if (totalRows == 0) {
        throw Exception('No valid data rows found in CSV file');
      }

      // Process in chunks of 50 records
      const chunkSize = 50;
      final totalChunks = (totalRows / chunkSize).ceil();

      // Show initial progress dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Importing Collections'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Preparing to import $totalRows collections...'),
              const SizedBox(height: 8),
              Text('Processing in chunks of $chunkSize records'),
              if (skippedRows > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Skipped $skippedRows empty/comment rows',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        barrierDismissible: false,
      );

      final db = await _dbHelper.database;

      // Process each chunk
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        final startIndex = chunkIndex * chunkSize;
        final endIndex = (startIndex + chunkSize).clamp(0, totalRows);
        final chunk = dataRows.sublist(startIndex, endIndex);
        final chunkNumber = chunkIndex + 1;

        // Update progress dialog
        Get.back(); // Close previous dialog
        Get.dialog(
          AlertDialog(
            title: const Text('Importing Collections'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: chunkIndex / totalChunks,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 16),
                Text('Processing chunk $chunkNumber of $totalChunks'),
                const SizedBox(height: 8),
                Text('Records ${startIndex + 1} to $endIndex of $totalRows'),
                const SizedBox(height: 8),
                Text('Successfully imported: ${importedCollections.length}'),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Errors: ${errors.length}',
                    style: TextStyle(color: Colors.red[600]),
                  ),
                ],
              ],
            ),
          ),
          barrierDismissible: false,
        );

        // Process chunk with pre-validation and simple transaction
        try {
          print('🔄 Starting chunk $chunkNumber with ${chunk.length} records');
          int chunkSuccessCount = 0;
          List<Map<String, dynamic>> validCollections = [];

          // First: Validate and prepare data outside transaction
          for (int i = 0; i < chunk.length; i++) {
            final rowIndex = startIndex + i;
            final actualRowNumber = rowIndex + 2 + skippedRows;

            try {
              List<dynamic> row = chunk[i];

              // Validate minimum required columns
              if (row.length < 3) {
                errors.add(
                  'Row $actualRowNumber: Insufficient columns. Expected: Member Number, Net Weight (kg), Date. Found ${row.length} columns: ${row.join(", ")}',
                );
                continue;
              }

              // Extract data from CSV row
              String memberNumber = _getStringValue(row, 0).trim();
              String netWeightStr = _getStringValue(row, 1).trim();
              String dateStr = _getStringValue(row, 2).trim();

              // Debug logging for problematic rows
              if (memberNumber.isEmpty ||
                  netWeightStr.isEmpty ||
                  dateStr.isEmpty) {
                print(
                  '🔍 Row $actualRowNumber debug - Raw data: [${row.join(", ")}]',
                );
                print('   - Member Number: "$memberNumber"');
                print('   - Net Weight: "$netWeightStr"');
                print('   - Date: "$dateStr"');
              }

              // Validate required fields
              if (memberNumber.isEmpty ||
                  netWeightStr.isEmpty ||
                  dateStr.isEmpty) {
                errors.add(
                  'Row $actualRowNumber: Member number, net weight, and date are required',
                );
                continue;
              }

              // Parse net weight
              double netWeight;
              try {
                netWeight = double.parse(netWeightStr);
                if (netWeight <= 0) {
                  errors.add(
                    'Row $actualRowNumber: Net weight must be greater than 0',
                  );
                  continue;
                }
              } catch (e) {
                errors.add(
                  'Row $actualRowNumber: Invalid net weight format: $netWeightStr',
                );
                continue;
              }

              // Parse date
              DateTime collectionDate;
              try {
                try {
                  collectionDate = DateFormat('yyyy-MM-dd').parse(dateStr);
                } catch (e1) {
                  try {
                    collectionDate = DateFormat('dd/MM/yyyy').parse(dateStr);
                  } catch (e2) {
                    try {
                      collectionDate = DateFormat('MM/dd/yyyy').parse(dateStr);
                    } catch (e3) {
                      try {
                        collectionDate = DateFormat(
                          'yyyy-MM-dd HH:mm:ss',
                        ).parse(dateStr);
                      } catch (e4) {
                        errors.add(
                          'Row $actualRowNumber: Invalid date format. Use yyyy-MM-dd, dd/MM/yyyy, or MM/dd/yyyy',
                        );
                        continue;
                      }
                    }
                  }
                }
              } catch (e) {
                errors.add(
                  'Row $actualRowNumber: Invalid date format: $dateStr',
                );
                continue;
              }

              // Find member by member number OUTSIDE transaction
              print('🔍 Looking up member: $memberNumber');
              final memberResult = await db.query(
                'members',
                where: 'memberNumber = ?',
                whereArgs: [memberNumber],
                limit: 1,
              );

              if (memberResult.isEmpty) {
                errors.add(
                  'Row $actualRowNumber: Member not found: $memberNumber',
                );
                continue;
              }

              final memberData = memberResult.first;
              final isActive = (memberData['isActive'] as int?) == 1;

              if (!isActive) {
                errors.add(
                  'Row $actualRowNumber: Member is inactive: $memberNumber',
                );
                continue;
              }

              // Optional fields with defaults - ensure SMS compatibility
              int numberOfBags = 1; // Default to 1 for imported collections
              if (row.length > 3 && _getStringValue(row, 3).isNotEmpty) {
                try {
                  numberOfBags = int.parse(_getStringValue(row, 3));
                  if (numberOfBags <= 0) {
                    numberOfBags = 1; // Ensure positive value
                  }
                } catch (e) {
                  numberOfBags = 1; // Fallback to 1
                }
              }

              // Generate receipt number with proper format for SMS
              final datePrefix =
                  '${collectionDate.year}${collectionDate.month.toString().padLeft(2, '0')}${collectionDate.day.toString().padLeft(2, '0')}';
              final timestamp =
                  DateTime.now().millisecondsSinceEpoch.toString();
              final receiptNumber =
                  'IMP$datePrefix${timestamp.substring(timestamp.length - 4)}_${(i + 1).toString().padLeft(3, '0')}';

              // Ensure proper user attribution for SMS
              final importUserId = currentUser?.id ?? 'csv_import_user';
              final importUserName = currentUser?.fullName ?? 'CSV Import';

              // Create CoffeeCollection object with all SMS-required fields properly set
              final collection = CoffeeCollection(
                id: _uuid.v4(),
                memberId: memberData['id'] as String,
                memberNumber: memberData['memberNumber'] as String,
                memberName: memberData['fullName'] as String,
                seasonId: currentSeason.id,
                seasonName: currentSeason.name,
                productType:
                    systemSettings
                        .coffeeProduct, // Ensures SMS shows correct crop type
                grossWeight:
                    netWeight, // For imported: gross = net (no container weight)
                tareWeight: 0.0, // Imported collections have no tare weight
                netWeight:
                    netWeight, // This is the key field for SMS weight display
                numberOfBags:
                    numberOfBags, // Ensures SMS shows correct bag count
                collectionDate:
                    collectionDate, // Properly formatted date for SMS
                isManualEntry: true, // Mark as imported/manual entry
                receiptNumber: receiptNumber, // Unique receipt number for SMS
                userId: importUserId, // User who performed the import
                userName:
                    importUserName, // Name shown in "Served By" field in SMS
                pricePerKg: null, // Not applicable for imported collections
                totalValue: null, // Not applicable for imported collections
              );

              print('📋 Collection created for SMS compatibility:');
              print(
                '   - Member: ${collection.memberName} (${collection.memberNumber})',
              );
              print('   - Product: ${collection.productType}');
              print('   - Weight: ${collection.netWeight} kg');
              print('   - Bags: ${collection.numberOfBags}');
              print(
                '   - Date: ${DateFormat('dd/MM/yy').format(collection.collectionDate)}',
              );
              print('   - Receipt: ${collection.receiptNumber}');
              print('   - Served By: ${collection.userName}');

              // Convert to JSON using the same method as normal collections
              final collectionData = collection.toJson();

              // Validate SMS-required fields before adding to valid collections
              final smsValidation = _validateSmsRequiredFields(collection);
              if (!smsValidation['isValid']) {
                errors.add(
                  'Row $actualRowNumber: SMS validation failed - ${smsValidation['error']}',
                );
                print(
                  '❌ SMS validation failed for row $actualRowNumber: ${smsValidation['error']}',
                );
                continue;
              }

              validCollections.add(collectionData);
              print(
                '✅ Validated row $actualRowNumber for member: $memberNumber (SMS-ready)',
              );
            } catch (e) {
              errors.add('Row $actualRowNumber: $e');
              print('❌ Error validating row $actualRowNumber: $e');
            }
          }

          // Second: Simple batch insert in transaction
          if (validCollections.isNotEmpty) {
            print(
              '📝 Starting transaction to insert ${validCollections.length} validated collections',
            );

            await db.transaction((txn) async {
              for (final collectionData in validCollections) {
                try {
                  await txn.insert('coffee_collections', collectionData);
                  chunkSuccessCount++;

                  // Create CoffeeCollection object for return list
                  final collection = CoffeeCollection(
                    id: collectionData['id'] as String,
                    memberId: collectionData['memberId'] as String,
                    memberNumber: collectionData['memberNumber'] as String,
                    memberName: collectionData['memberName'] as String,
                    seasonId: collectionData['seasonId'] as String,
                    seasonName: collectionData['seasonName'] as String,
                    productType: collectionData['productType'] as String,
                    grossWeight: collectionData['grossWeight'] as double,
                    tareWeight: collectionData['tareWeight'] as double,
                    netWeight: collectionData['netWeight'] as double,
                    numberOfBags: collectionData['numberOfBags'] as int,
                    collectionDate: DateTime.parse(
                      collectionData['collectionDate'] as String,
                    ),
                    isManualEntry: true,
                    receiptNumber: collectionData['receiptNumber'] as String,
                    userId: collectionData['userId'] as String?,
                    userName: collectionData['userName'] as String?,
                    pricePerKg: null,
                    totalValue: null,
                  );

                  importedCollections.add(collection);
                } catch (e) {
                  errors.add('Database insert error: $e');
                  print('❌ Error inserting collection: $e');
                }
              }
            });

            print('🎯 Transaction completed for chunk $chunkNumber');
          }

          print(
            '✅ Completed chunk $chunkNumber: $chunkSuccessCount/${chunk.length} records imported successfully, ${importedCollections.length} total imported so far',
          );

          // Small delay to allow UI to update
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('Error processing chunk $chunkNumber: $e');
          errors.add('Chunk $chunkNumber failed: $e');
          // Continue with next chunk instead of failing completely
        }
      }

      // Close progress dialog
      Get.back();

      // Refresh collections data to ensure imported data is available
      await loadCollections();
      await loadTodaysCollections();

      // Show completion summary with SMS option
      final successCount = importedCollections.length;
      final errorCount = errors.length;

      String summaryTitle;
      String summaryMessage;

      if (successCount > 0 && errorCount == 0) {
        summaryTitle = 'Import Successful';
        summaryMessage = 'Successfully imported all $successCount collections!';
      } else if (successCount > 0 && errorCount > 0) {
        summaryTitle = 'Import Partially Successful';
        summaryMessage =
            'Imported $successCount collections successfully.\n$errorCount records had errors.';
      } else {
        summaryTitle = 'Import Failed';
        summaryMessage =
            'No collections were imported.\n$errorCount records had errors.';
      }

      // Ask user if they want to send SMS notifications for imported collections
      bool shouldSendSms = false;
      if (successCount > 0) {
        shouldSendSms = await _askUserForSmsNotifications(successCount);
      }

      // Send SMS notifications if requested
      if (shouldSendSms && importedCollections.isNotEmpty) {
        print(
          '📱 Starting SMS sending for ${importedCollections.length} imported collections...',
        );
        print('🔍 SMS Validation Check:');

        // Validate SMS readiness for all collections
        int smsReadyCount = 0;
        for (final collection in importedCollections) {
          final validation = _validateSmsRequiredFields(collection);
          if (validation['isValid']) {
            smsReadyCount++;
          } else {
            print(
              '⚠️  Collection ${collection.receiptNumber} not SMS-ready: ${validation['error']}',
            );
          }
        }

        print(
          '✅ $smsReadyCount/${importedCollections.length} collections are SMS-ready',
        );

        if (smsReadyCount > 0) {
          await _sendSmsForImportedCollections(importedCollections);
        } else {
          print('❌ No collections are ready for SMS sending');
        }
      }

      // Show detailed results dialog
      Get.dialog(
        AlertDialog(
          title: Text(summaryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summaryMessage),
              if (errorCount > 0) ...[
                const SizedBox(height: 16),
                const Text(
                  'Sample Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        errors.take(10).join('\n'), // Show first 10 errors
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                if (errors.length > 10) ...[
                  const SizedBox(height: 4),
                  Text(
                    '... and ${errors.length - 10} more errors',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('OK')),
          ],
        ),
      );

      // Reload collections after import
      await loadCollections();
      await loadTodaysCollections();

      if (errors.isNotEmpty) {
        print('Import completed with ${errors.length} errors:');
        for (String error in errors.take(20)) {
          // Log first 20 errors
          print('  $error');
        }
      }

      return importedCollections;
    } catch (e) {
      // Close any open dialogs
      try {
        Get.back();
      } catch (_) {}

      Get.snackbar(
        'Import Error',
        'Failed to import collections: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      throw Exception('Failed to import collections: $e');
    }
  }

  // Helper method to safely get string value from CSV row
  String _getStringValue(List<dynamic> row, int index) {
    if (index >= row.length || row[index] == null) {
      return '';
    }
    return row[index].toString();
  }

  /// Validate that all SMS-required fields are present and valid
  Map<String, dynamic> _validateSmsRequiredFields(CoffeeCollection collection) {
    final errors = <String>[];

    // Check member information
    if (collection.memberName.isEmpty) {
      errors.add('Member name is required for SMS');
    }
    if (collection.memberNumber.isEmpty) {
      errors.add('Member number is required for SMS');
    }

    // Check collection details
    if (collection.productType.isEmpty) {
      errors.add('Product type is required for SMS');
    }
    if (collection.netWeight <= 0) {
      errors.add('Net weight must be greater than 0 for SMS');
    }
    if (collection.numberOfBags <= 0) {
      errors.add('Number of bags must be greater than 0 for SMS');
    }

    // Check receipt and date
    if (collection.receiptNumber == null || collection.receiptNumber!.isEmpty) {
      errors.add('Receipt number is required for SMS');
    }

    // Check user information
    if (collection.userName == null || collection.userName!.isEmpty) {
      errors.add('User name is required for SMS (Served By field)');
    }

    // Check season information
    if (collection.seasonId.isEmpty || collection.seasonName.isEmpty) {
      errors.add('Season information is required for SMS');
    }

    return {
      'isValid': errors.isEmpty,
      'error': errors.isEmpty ? null : errors.join(', '),
      'errors': errors,
    };
  }

  // Generate receipt number using an open transaction to avoid database locks
  // Future<String> _generateImportReceiptNumberTx(DatabaseExecutor txn, DateTime collectionDate) async {
  //   final datePrefix = '${collectionDate.year}${collectionDate.month.toString().padLeft(2, '0')}${collectionDate.day.toString().padLeft(2, '0')}';

  //   final startOfDay = DateTime(collectionDate.year, collectionDate.month, collectionDate.day);
  //   final endOfDay = startOfDay.add(const Duration(days: 1));

  //   final result = await txn.rawQuery('''
  //     SELECT COUNT(*) as count FROM coffee_collections
  //     WHERE collectionDate >= ? AND collectionDate < ?
  //   ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

  //   final count = (result.first['count'] as int?) ?? 0;
  //   final sequenceNumber = (count + 1).toString().padLeft(4, '0');
  //   return 'IMP$datePrefix$sequenceNumber';
  // }

  /// Helper method to ask user if they want to send SMS notifications for imported collections
  Future<bool> _askUserForSmsNotifications(int successCount) async {
    try {
      final result = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Send SMS Notifications?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Successfully imported $successCount collections.'),
              const SizedBox(height: 16),
              const Text(
                'Would you like to send SMS notifications to members for their imported collections?',
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: This will send SMS messages to all members with valid phone numbers.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Skip SMS'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Send SMS'),
            ),
          ],
        ),
      );
      return result ?? false;
    } catch (e) {
      print('Error asking user for SMS notifications: $e');
      return false;
    }
  }

  /// Send SMS notifications for imported collections
  Future<void> _sendSmsForImportedCollections(
    List<CoffeeCollection> collections,
  ) async {
    if (collections.isEmpty) return;

    try {
      // Show progress dialog
      Get.dialog(
        AlertDialog(
          title: const Text('Sending SMS Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Sending SMS notifications for ${collections.length} collections...',
              ),
              const SizedBox(height: 8),
              const Text('This may take a few moments.'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      final smsService = Get.find<SmsService>();
      int successCount = 0;
      int failureCount = 0;

      // Send SMS for each collection with delay to avoid overwhelming the system
      for (int i = 0; i < collections.length; i++) {
        final collection = collections[i];

        try {
          print(
            '📱 Sending SMS ${i + 1}/${collections.length} for ${collection.memberName}',
          );

          // Use the main SMS sending method which respects current mode settings
          final success = await smsService.sendCoffeeCollectionSMS(collection);

          if (success) {
            successCount++;
            print('✅ SMS sent successfully for ${collection.memberName}');
          } else {
            failureCount++;
            print('❌ SMS failed for ${collection.memberName}');
          }

          // Add small delay between SMS sends to avoid overwhelming the system
          if (i < collections.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          failureCount++;
          print('❌ Error sending SMS for ${collection.memberName}: $e');
        }
      }

      // Close progress dialog
      Get.back();

      // Show results
      final String resultTitle =
          successCount > 0 ? 'SMS Notifications Sent' : 'SMS Sending Failed';
      final String resultMessage =
          successCount > 0
              ? 'Successfully sent $successCount SMS notifications.\n${failureCount > 0 ? '$failureCount failed.' : ''}'
              : 'Failed to send SMS notifications. Please check your SMS settings and member phone numbers.';

      Get.dialog(
        AlertDialog(
          title: Text(resultTitle),
          content: Text(resultMessage),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('OK')),
          ],
        ),
      );

      print('📊 SMS Summary: $successCount sent, $failureCount failed');
    } catch (e) {
      // Close progress dialog if still open
      try {
        Get.back();
      } catch (_) {}

      print('❌ Error in SMS sending process: $e');

      Get.dialog(
        AlertDialog(
          title: const Text('SMS Error'),
          content: Text('Failed to send SMS notifications: ${e.toString()}'),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  /// Download CSV template for collection import
  Future<File?> downloadCollectionImportTemplate() async {
    try {
      // Create CSV template content
      final csvContent = [
        ['Member Number', 'Net Weight (kg)', 'Date', 'Number of Bags'],
        ['M001', '25.5', '2024-01-15', '2'],
        ['M002', '18.0', '2024-01-15', '1'],
        ['M003', '32.8', '2024-01-15', '3'],
        [
          '# This is a comment line - it will be ignored during import',
          '',
          '',
          '',
        ],
        [
          '# Date formats supported: yyyy-MM-dd, dd/MM/yyyy, MM/dd/yyyy',
          '',
          '',
          '',
        ],
        ['# Number of Bags is optional (defaults to 1)', '', '', ''],
      ];

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvContent);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/coffee_collection_import_template.csv',
      );

      // Write CSV content to file
      await file.writeAsString(csvString);

      return file;
    } catch (e) {
      print('Error creating CSV template: $e');
      return null;
    }
  }
}
