import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Performance optimization service for inventory management
class PerformanceOptimizer {
  final DatabaseHelper _dbHelper;
  
  // Cache for frequently accessed data
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  PerformanceOptimizer(this._dbHelper);

  /// Optimize database with proper indexing for inventory operations
  Future<void> optimizeDatabaseIndexes() async {
    final db = await _dbHelper.database;
    
    try {
      await db.transaction((txn) async {
        // Critical indexes for stock_adjustment_history table performance
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_date_desc', 
          'stock_adjustment_history', ['adjustmentDate DESC']);
        
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_product_date', 
          'stock_adjustment_history', ['productId', 'adjustmentDate DESC']);
        
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_category_date', 
          'stock_adjustment_history', ['categoryId', 'adjustmentDate DESC']);
        
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_user_date', 
          'stock_adjustment_history', ['userId', 'adjustmentDate DESC']);
        
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_type_date', 
          'stock_adjustment_history', ['adjustmentType', 'adjustmentDate DESC']);
        
        // Composite index for common filter combinations
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_cat_prod_date', 
          'stock_adjustment_history', ['categoryId', 'productId', 'adjustmentDate DESC']);
        
        // Index for date range queries
        await _createIndexIfNotExists(txn, 'idx_stock_adj_hist_date_range', 
          'stock_adjustment_history', ['adjustmentDate', 'categoryId', 'productId']);
        
        // Optimize products table for frequent lookups
        await _createIndexIfNotExists(txn, 'idx_products_category_active', 
          'products', ['categoryId', 'isActive']);
        
        await _createIndexIfNotExists(txn, 'idx_products_name_active', 
          'products', ['name', 'isActive']);
        
        await _createIndexIfNotExists(txn, 'idx_products_active_name', 
          'products', ['isActive', 'name']);
        
        // Optimize stock table for real-time updates
        await _createIndexIfNotExists(txn, 'idx_stock_product_updated', 
          'stock', ['productId', 'lastUpdated']);
        
        await _createIndexIfNotExists(txn, 'idx_stock_current_stock', 
          'stock', ['currentStock', 'productId']);
        
        // Optimize sales tables for reporting
        await _createIndexIfNotExists(txn, 'idx_sales_date_active', 
          'sales', ['saleDate DESC', 'isActive']);
        
        await _createIndexIfNotExists(txn, 'idx_sale_items_product_sale', 
          'sale_items', ['productId', 'saleId']);
        
        // Optimize stock_movements table if it exists
        await _createIndexIfNotExists(txn, 'idx_stock_movements_product_date', 
          'stock_movements', ['productId', 'movementDate DESC']);
        
        // Optimize categories table
        await _createIndexIfNotExists(txn, 'idx_categories_active_name', 
          'product_categories', ['isActive', 'name']);
        
        print('✓ Enhanced database indexes optimized successfully');
      });
    } catch (e) {
      print('Error optimizing database indexes: $e');
    }
  }

  /// Create index if it doesn't already exist
  Future<void> _createIndexIfNotExists(Transaction txn, String indexName, 
      String tableName, List<String> columns) async {
    try {
      // Check if index exists
      final result = await txn.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='index' AND name=?
      ''', [indexName]);
      
      if (result.isEmpty) {
        final columnList = columns.join(', ');
        await txn.execute('''
          CREATE INDEX $indexName ON $tableName ($columnList)
        ''');
        print('✓ Created index: $indexName');
      }
    } catch (e) {
      print('Warning: Could not create index $indexName: $e');
    }
  }

  /// Analyze database performance and suggest optimizations
  Future<Map<String, dynamic>> analyzePerformance() async {
    final db = await _dbHelper.database;
    final analysis = <String, dynamic>{};
    
    try {
      // Analyze table sizes
      final tableSizes = await _getTableSizes(db);
      analysis['tableSizes'] = tableSizes;
      
      // Analyze index usage
      final indexInfo = await _getIndexInfo(db);
      analysis['indexes'] = indexInfo;
      
      // Check for missing indexes on frequently queried columns
      final recommendations = await _getOptimizationRecommendations(db);
      analysis['recommendations'] = recommendations;
      
      // Memory usage analysis
      final memoryInfo = await _getMemoryUsage(db);
      analysis['memory'] = memoryInfo;
      
      print('✓ Performance analysis completed');
      return analysis;
    } catch (e) {
      print('Error analyzing performance: $e');
      return {'error': e.toString()};
    }
  }

  /// Get table sizes for analysis
  Future<Map<String, int>> _getTableSizes(Database db) async {
    final sizes = <String, int>{};
    final tables = [
      'stock_adjustment_history',
      'products',
      'stock',
      'sales',
      'sale_items',
      'stock_movements',
    ];
    
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        sizes[table] = result.first['count'] as int;
      } catch (e) {
        sizes[table] = 0; // Table might not exist
      }
    }
    
    return sizes;
  }

  /// Get index information
  Future<List<Map<String, dynamic>>> _getIndexInfo(Database db) async {
    try {
      return await db.rawQuery('''
        SELECT name, tbl_name, sql 
        FROM sqlite_master 
        WHERE type='index' AND name NOT LIKE 'sqlite_%'
        ORDER BY tbl_name, name
      ''');
    } catch (e) {
      print('Error getting index info: $e');
      return [];
    }
  }

  /// Get optimization recommendations
  Future<List<String>> _getOptimizationRecommendations(Database db) async {
    final recommendations = <String>[];
    
    try {
      // Check for large tables without proper indexes
      final tableSizes = await _getTableSizes(db);
      
      if (tableSizes['stock_adjustment_history']! > 1000) {
        recommendations.add('Consider partitioning stock_adjustment_history by date for better performance');
      }
      
      if (tableSizes['sales']! > 5000) {
        recommendations.add('Consider archiving old sales data to improve query performance');
      }
      
      // Check for missing foreign key indexes
      final indexes = await _getIndexInfo(db);
      final indexNames = indexes.map((idx) => idx['name'] as String).toSet();
      
      if (!indexNames.contains('idx_stock_adj_hist_product_date')) {
        recommendations.add('Add composite index on stock_adjustment_history (productId, adjustmentDate)');
      }
      
      return recommendations;
    } catch (e) {
      print('Error generating recommendations: $e');
      return ['Error analyzing database for recommendations'];
    }
  }

  /// Get memory usage information
  Future<Map<String, dynamic>> _getMemoryUsage(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA page_count');
      final pageCount = result.first['page_count'] as int;
      
      final pageSizeResult = await db.rawQuery('PRAGMA page_size');
      final pageSize = pageSizeResult.first['page_size'] as int;
      
      final totalSize = pageCount * pageSize;
      
      return {
        'pageCount': pageCount,
        'pageSize': pageSize,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting memory usage: $e');
      return {};
    }
  }

  /// Optimize query performance with pagination
  Future<List<Map<String, dynamic>>> getPagedAdjustmentHistory({
    int page = 1,
    int pageSize = 50,
    String? categoryId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    
    try {
      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];
      
      if (categoryId != null && categoryId.isNotEmpty) {
        whereConditions.add('categoryId = ?');
        whereArgs.add(categoryId);
      }
      
      if (productId != null && productId.isNotEmpty) {
        whereConditions.add('productId = ?');
        whereArgs.add(productId);
      }
      
      if (startDate != null && endDate != null) {
        whereConditions.add('adjustmentDate BETWEEN ? AND ?');
        whereArgs.add(startDate.toIso8601String());
        whereArgs.add(endDate.toIso8601String());
      }
      
      String whereClause = whereConditions.isEmpty ? '' : 'WHERE ${whereConditions.join(' AND ')}';
      final offset = (page - 1) * pageSize;
      
      final result = await db.rawQuery('''
        SELECT * FROM stock_adjustment_history
        $whereClause
        ORDER BY adjustmentDate DESC
        LIMIT ? OFFSET ?
      ''', [...whereArgs, pageSize, offset]);
      
      return result;
    } catch (e) {
      print('Error getting paged adjustment history: $e');
      return [];
    }
  }

  /// Get total count for pagination
  Future<int> getAdjustmentHistoryCount({
    String? categoryId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    
    try {
      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];
      
      if (categoryId != null && categoryId.isNotEmpty) {
        whereConditions.add('categoryId = ?');
        whereArgs.add(categoryId);
      }
      
      if (productId != null && productId.isNotEmpty) {
        whereConditions.add('productId = ?');
        whereArgs.add(productId);
      }
      
      if (startDate != null && endDate != null) {
        whereConditions.add('adjustmentDate BETWEEN ? AND ?');
        whereArgs.add(startDate.toIso8601String());
        whereArgs.add(endDate.toIso8601String());
      }
      
      String whereClause = whereConditions.isEmpty ? '' : 'WHERE ${whereConditions.join(' AND ')}';
      
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM stock_adjustment_history
        $whereClause
      ''', whereArgs);
      
      return result.first['count'] as int;
    } catch (e) {
      print('Error getting adjustment history count: $e');
      return 0;
    }
  }

  /// Clean up old data to improve performance
  Future<void> cleanupOldData({
    int daysToKeep = 365,
  }) async {
    final db = await _dbHelper.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    try {
      await db.transaction((txn) async {
        // Archive old stock movements (keep adjustment history)
        final deletedMovements = await txn.delete(
          'stock_movements',
          where: 'movementDate < ?',
          whereArgs: [cutoffDate.toIso8601String()],
        );
        
        print('✓ Cleaned up $deletedMovements old stock movements');
        
        // Vacuum database to reclaim space
        await txn.execute('VACUUM');
        print('✓ Database vacuumed successfully');
      });
    } catch (e) {
      print('Error cleaning up old data: $e');
    }
  }

  /// Cache frequently accessed data with expiry
  T? getCachedData<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _cache[key] as T?;
  }

  /// Store data in cache with timestamp
  void setCachedData<T>(String key, T data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Clear expired cache entries
  void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('✓ Cleared ${expiredKeys.length} expired cache entries');
    }
  }

  /// Get cached adjustment history with fallback to database
  Future<List<Map<String, dynamic>>> getCachedAdjustmentHistory({
    String? categoryId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey = 'adjustment_history_${categoryId ?? 'all'}_${productId ?? 'all'}_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';
    
    // Try to get from cache first
    final cached = getCachedData<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) {
      print('✓ Retrieved adjustment history from cache');
      return cached;
    }
    
    // Fallback to database
    final data = await getPagedAdjustmentHistory(
      categoryId: categoryId,
      productId: productId,
      startDate: startDate,
      endDate: endDate,
      pageSize: 1000, // Get more data for caching
    );
    
    // Cache the result
    setCachedData(cacheKey, data);
    print('✓ Cached adjustment history data');
    
    return data;
  }

  /// Optimize memory usage by disposing unused resources
  void optimizeMemoryUsage() {
    // Clear expired cache entries
    clearExpiredCache();
    
    // Clear all cache if memory pressure is high
    if (_cache.length > 100) {
      _cache.clear();
      _cacheTimestamps.clear();
      print('✓ Cleared all cache due to memory pressure');
    }
    
    print('✓ Memory optimization completed');
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'cacheSize': _cache.length,
      'cacheHitRatio': _calculateCacheHitRatio(),
      'memoryUsage': _cache.length * 1024, // Rough estimate
      'lastOptimization': DateTime.now().toIso8601String(),
    };
  }

  double _calculateCacheHitRatio() {
    // This would need to be tracked over time in a real implementation
    return _cache.isNotEmpty ? 0.75 : 0.0; // Placeholder
  }
}