# Fix: Detailed View Empty Table Issue

## Problem

When switching to the Detailed view in the Sales Report Screen, the table was empty even though sales data existed.

## Root Cause

The `loadSalesForDateRange()` method in `InventoryService` was only querying the `sales` table but not loading the associated items from the `sale_items` table.

### Original Code

```dart
Future<List<Sale>> loadSalesForDateRange(
  DateTime startDate,
  DateTime endDate,
) async {
  try {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'sales',
      where: 'isActive = ? AND saleDate >= ? AND saleDate <= ?',
      whereArgs: [1, startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'saleDate DESC',
    );
    return maps.map((map) => Sale.fromJson(map)).toList();
  } catch (e) {
    print('Error loading sales for date range: $e');
    return [];
  }
}
```

**Issue:** The `Sale` objects were created without their `items` list populated, resulting in empty arrays.

## Solution

Updated `loadSalesForDateRange()` to load sale items for each sale, following the same pattern used in the `loadSales()` method.

### Fixed Code

```dart
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
```

## Changes Made

1. **Query Sale Items**: For each sale, query the `sale_items` table to get associated items
2. **Parse Items**: Convert item maps to `SaleItem` objects
3. **Merge Data**: Add items to sale data before creating `Sale` object
4. **Return Complete Sales**: Return sales with fully populated items lists

## Additional Improvements

Added debug logging and empty state handling in the detailed view:

```dart
Widget _buildDetailedListView() {
  // Calculate total number of items across all sales
  int totalItems = 0;
  for (final sale in _filteredSales) {
    totalItems += sale.items.length;
  }

  print('📊 Detailed view: ${_filteredSales.length} sales, $totalItems total items');

  // If no items, show empty message
  if (totalItems == 0) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _filteredSales.isEmpty
              ? 'No sales found'
              : 'No items found in selected sales',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  // ... rest of the list view
}
```

## Impact

### Before Fix

- Summary view: ✅ Worked correctly
- Detailed view: ❌ Empty table (items.length = 0 for all sales)

### After Fix

- Summary view: ✅ Still works correctly
- Detailed view: ✅ Shows all items with proper data
- Debug logging: ✅ Helps identify data issues
- Empty state: ✅ Shows helpful message when no items exist

## Testing Checklist

- [x] Summary view displays correctly
- [x] Detailed view displays items
- [x] Item quantities are correct
- [x] Item prices are correct
- [x] Totals row calculates correctly
- [x] Excel export includes items in detailed view
- [x] Switching between views works smoothly
- [x] Empty state shows appropriate message

## Performance Considerations

The fix adds N+1 queries (one per sale) to load items. For large date ranges with many sales, this could impact performance. Future optimization could use a JOIN query:

```sql
SELECT s.*, si.*
FROM sales s
LEFT JOIN sale_items si ON s.id = si.saleId
WHERE s.isActive = 1
  AND s.saleDate >= ?
  AND s.saleDate <= ?
ORDER BY s.saleDate DESC
```

However, the current approach is simpler and works well for typical use cases (30-90 day date ranges).

## Related Files Modified

1. `lib/services/inventory_service.dart` - Fixed `loadSalesForDateRange()` method
2. `lib/screens/inventory/sales_report_screen.dart` - Added debug logging and empty state handling
