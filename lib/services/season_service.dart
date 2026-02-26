import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'database_helper.dart';

class SeasonService extends GetxService {
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  final Uuid _uuid = const Uuid();

  final RxList<Season> _seasons = <Season>[].obs;
  final Rx<Season?> _activeInventorySeason = Rx<Season?>(null);
  final Rx<Season?> _activeCoffeeSeason = Rx<Season?>(null);

  List<Season> get seasons => _seasons;

  // Inventory period (used for stock / sales)
  Season? get activeSeason => _activeInventorySeason.value;

  // Coffee crop season (used for collections)
  Season? get activeCoffeeSeason => _activeCoffeeSeason.value;

  Future<SeasonService> init() async {
    await _createSeasonTables();
    await _ensureSeasonTablesUpToDate();
    await loadSeasons();
    await _loadActiveSeasons();
    return this;
  }

  Future<void> _createSeasonTables() async {
    final db = await _dbHelper.database;

    // Seasons table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seasons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        startDate TEXT NOT NULL,
        endDate TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        totalSales REAL NOT NULL DEFAULT 0.0,
        totalTransactions INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        createdBy TEXT,
        createdByName TEXT,
        type TEXT NOT NULL DEFAULT 'inventory'
      )
    ''');

    // Create index for active season lookup
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_seasons_active ON seasons(isActive)
    ''');
  }

  Future<void> _ensureSeasonTablesUpToDate() async {
    final db = await _dbHelper.database;

    try {
      // --- Ensure seasons table has all required columns ---
      final seasonTableInfo = await db.rawQuery("PRAGMA table_info(seasons)");
      final seasonColumns =
          seasonTableInfo.map((col) => col['name'] as String).toSet();

      Future<void> addColumn(String name, String definition) async {
        if (!seasonColumns.contains(name)) {
          print('Adding $name column to seasons table');
          await db.execute('ALTER TABLE seasons ADD COLUMN $definition');
        }
      }

      await addColumn('startDate', 'startDate TEXT');
      await addColumn('endDate', 'endDate TEXT');
      await addColumn('isActive', 'isActive INTEGER NOT NULL DEFAULT 1');
      await addColumn('totalSales', 'totalSales REAL NOT NULL DEFAULT 0.0');
      await addColumn(
        'totalTransactions',
        'totalTransactions INTEGER NOT NULL DEFAULT 0',
      );
      await addColumn('createdAt', 'createdAt TEXT');
      await addColumn('updatedAt', 'updatedAt TEXT');
      await addColumn('createdBy', 'createdBy TEXT');
      await addColumn('createdByName', 'createdByName TEXT');
      await addColumn('type', 'type TEXT NOT NULL DEFAULT "inventory"');

      // Backfill NULL type values (for legacy rows) to 'inventory'
      await db.execute(
        "UPDATE seasons SET type = 'inventory' WHERE type IS NULL",
      );

      // Check if sales table has seasonId column
      final salesTableInfo = await db.rawQuery("PRAGMA table_info(sales)");
      final salesColumns =
          salesTableInfo.map((col) => col['name'] as String).toSet();

      if (!salesColumns.contains('seasonId')) {
        print('Adding seasonId column to sales table');
        await db.execute('ALTER TABLE sales ADD COLUMN seasonId TEXT');
      }

      if (!salesColumns.contains('seasonName')) {
        print('Adding seasonName column to sales table');
        await db.execute('ALTER TABLE sales ADD COLUMN seasonName TEXT');
      }
    } catch (e) {
      print('Error updating season tables: $e');
    }
  }

  Future<void> loadSeasons() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'seasons',
        orderBy: 'startDate DESC',
      );

      _seasons.value = maps.map((map) => Season.fromJson(map)).toList();
    } catch (e) {
      print('Error loading seasons: $e');
    }
  }

  Future<void> _loadActiveSeasons() async {
    try {
      _activeInventorySeason.value = _seasons.firstWhereOrNull(
        (s) => s.isActive && s.type == 'inventory',
      );
      _activeCoffeeSeason.value = _seasons.firstWhereOrNull(
        (s) => s.isActive && s.type == 'coffee',
      );
    } catch (e) {
      print('Error loading active seasons: $e');
    }
  }

  Future<bool> createSeason({
    required String name,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    String? userId,
    String? userName,
    String type = 'inventory', // 'inventory' or 'coffee'
  }) async {
    try {
      final db = await _dbHelper.database;

      // Check if there's already an active season of this type
      final existingActiveSeason = await _getActiveSeason(type);
      if (existingActiveSeason != null) {
        throw Exception(
          'There is already an active season: ${existingActiveSeason.name}. Please close it first.',
        );
      }

      // Validate dates
      if (endDate != null && endDate.isBefore(startDate)) {
        throw Exception('End date cannot be before start date');
      }

      final season = Season(
        id: _uuid.v4(),
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        isActive: true,
        totalSales: 0.0,
        totalTransactions: 0,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
        type: type,
      );

      await db.insert('seasons', season.toJson());
      await loadSeasons();
      await _loadActiveSeasons();

      return true;
    } catch (e) {
      print('Error creating season: $e');
      return false;
    }
  }

  Future<bool> updateSeason(Season season) async {
    try {
      final db = await _dbHelper.database;

      // If this season is being made active, deactivate other active seasons of the SAME type
      if (season.isActive) {
        await _deactivateAllSeasons(season.type);
      }

      final updatedSeason = season.copyWith(updatedAt: DateTime.now());

      await db.update(
        'seasons',
        updatedSeason.toJson(),
        where: 'id = ?',
        whereArgs: [season.id],
      );

      await loadSeasons();
      await _loadActiveSeasons();

      return true;
    } catch (e) {
      print('Error updating season: $e');
      return false;
    }
  }

  Future<bool> closeSeason(
    String seasonId, {
    String? userId,
    String? userName,
  }) async {
    try {
      final db = await _dbHelper.database;

      // Get the season
      final seasonResult = await db.query(
        'seasons',
        where: 'id = ?',
        whereArgs: [seasonId],
      );

      if (seasonResult.isEmpty) {
        throw Exception('Season not found');
      }

      final season = Season.fromJson(seasonResult.first);

      // Close the season
      final closedSeason = season.copyWith(
        isActive: false,
        endDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.update(
        'seasons',
        closedSeason.toJson(),
        where: 'id = ?',
        whereArgs: [seasonId],
      );

      await loadSeasons();
      await _loadActiveSeasons();

      return true;
    } catch (e) {
      print('Error closing season: $e');
      return false;
    }
  }

  Future<void> _deactivateAllSeasons([String? type]) async {
    final db = await _dbHelper.database;
    if (type == null) {
      await db.update('seasons', {
        'isActive': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'seasons',
        {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'type = ?',
        whereArgs: [type],
      );
    }
  }

  Future<Season?> _getActiveSeason(String type) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'seasons',
        where: 'isActive = ? AND type = ?',
        whereArgs: [1, type],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return Season.fromJson(result.first);
      }
      return null;
    } catch (e) {
      print('Error getting active season: $e');
      return null;
    }
  }

  Future<List<MemberSeasonSummary>> getMemberSeasonSummaries(
    String seasonId,
  ) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT 
          s.memberId,
          s.memberName,
          s.seasonId,
          s.seasonName,
          SUM(s.totalAmount) as totalPurchases,
          COUNT(*) as totalTransactions,
          MAX(s.saleDate) as lastPurchaseDate,
          AVG(s.totalAmount) as averagePurchase
        FROM sales s
        WHERE s.seasonId = ? AND s.isActive = 1 AND s.memberId IS NOT NULL
        GROUP BY s.memberId, s.memberName, s.seasonId, s.seasonName
        ORDER BY totalPurchases DESC
      ''',
        [seasonId],
      );

      return results.map((map) => MemberSeasonSummary.fromJson(map)).toList();
    } catch (e) {
      print('Error getting member season summaries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSeasonStatistics(String seasonId) async {
    try {
      final db = await _dbHelper.database;

      // Get sales statistics
      final salesStats = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as totalSales,
          SUM(totalAmount) as totalAmount,
          COUNT(DISTINCT memberId) as uniqueMembers,
          AVG(totalAmount) as averageSale
        FROM sales
        WHERE seasonId = ? AND isActive = 1
      ''',
        [seasonId],
      );

      // Get product sales
      final productStats = await db.rawQuery(
        '''
        SELECT 
          si.productName,
          SUM(si.quantity) as totalQuantity,
          SUM(si.totalPrice) as totalRevenue,
          COUNT(*) as salesCount
        FROM sale_items si
        INNER JOIN sales s ON si.saleId = s.id
        WHERE s.seasonId = ? AND s.isActive = 1
        GROUP BY si.productId, si.productName
        ORDER BY totalRevenue DESC
        LIMIT 10
      ''',
        [seasonId],
      );

      return {
        'sales': salesStats.isNotEmpty ? salesStats.first : {},
        'topProducts': productStats,
      };
    } catch (e) {
      print('Error getting season statistics: $e');
      return {'sales': {}, 'topProducts': []};
    }
  }

  Future<double> getMemberSeasonTotal(String memberId, String seasonId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT SUM(totalAmount) as total
        FROM sales
        WHERE memberId = ? AND seasonId = ? AND isActive = 1
      ''',
        [memberId, seasonId],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting member season total: $e');
      return 0.0;
    }
  }

  Future<bool> updateSeasonTotals(String seasonId) async {
    try {
      final db = await _dbHelper.database;

      // Calculate totals from sales
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as totalTransactions,
          SUM(totalAmount) as totalSales
        FROM sales
        WHERE seasonId = ? AND isActive = 1
      ''',
        [seasonId],
      );

      if (result.isNotEmpty) {
        final stats = result.first;
        await db.update(
          'seasons',
          {
            'totalSales': stats['totalSales'] ?? 0.0,
            'totalTransactions': stats['totalTransactions'] ?? 0,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [seasonId],
        );
      }

      await loadSeasons();
      return true;
    } catch (e) {
      print('Error updating season totals: $e');
      return false;
    }
  }

  // Check if we can create a sale (must have active season)
  bool canCreateSale() {
    return _activeInventorySeason.value != null &&
        _activeInventorySeason.value!.isCurrentlyActive;
  }

  // Get the reason why sales can't be created
  String? getSaleBlockReason() {
    if (_activeInventorySeason.value == null) {
      return 'No active inventory season found.';
    }

    if (!_activeInventorySeason.value!.isCurrentlyActive) {
      return 'Current inventory season is not active. Please activate a season or create a new one.';
    }

    return null;
  }

  // Legacy compatibility methods
  bool canStartCollection() {
    return _activeCoffeeSeason.value != null &&
        _activeCoffeeSeason.value!.isCurrentlyActive;
  }

  Season? get currentSeason => activeCoffeeSeason;

  String get currentSeasonDisplay => activeCoffeeSeason?.name ?? 'No Season';

  Future<void> createDefaultSeasonIfNeeded() async {
    try {
      final currentYear = DateTime.now().year;
      // Ensure at least one inventory period exists
      final hasInventory = _seasons.any((s) => s.type == 'inventory');
      if (!hasInventory) {
        await createSeason(
          name: 'Inventory $currentYear',
          description: 'Default inventory period',
          startDate: DateTime(currentYear, 1, 1),
          endDate: DateTime(currentYear, 12, 31),
          type: 'inventory',
        );
      }

      // Ensure at least one coffee season exists (e.g., 2024/2025)
      final hasCoffee = _seasons.any((s) => s.type == 'coffee');
      if (!hasCoffee) {
        final nextYear = currentYear + 1;
        await createSeason(
          name: '$currentYear/$nextYear',
          description: 'Default coffee season',
          startDate: DateTime(
            currentYear,
            10,
            1,
          ), // typical coffee season start
          endDate: DateTime(nextYear, 9, 30),
          type: 'coffee',
        );
      }
    } catch (e) {
      print('Error creating default season: $e');
    }
  }
}
