# Design Document

## Overview

This design document outlines the implementation approach for three filtering and deletion improvements in the Farm Pro application:

1. **Exact Member Number Filtering in Crop Search Screen**: Modify the filtering logic to use exact string matching instead of partial matching
2. **Sale Deletion with Stock Adjustment**: Add delete functionality to the Sales Report screen with automatic inventory restoration
3. **Exact Member Number Search in Sales Report**: Update search to filter by exact member number only

The design focuses on minimal code changes while ensuring data integrity, proper error handling, and maintaining the existing UI/UX patterns.

## Architecture

### Component Overview

The implementation involves modifications to three main components:

1. **CropSearchScreen** (`lib/screens/reports/crop_search_screen.dart`)

   - Update `_filterCollections()` method to use exact member number matching

2. **SalesReportScreen** (`lib/screens/inventory/sales_report_screen.dart`)

   - Add delete button to each sale row
   - Implement delete confirmation dialog
   - Update `_applyFilters()` method for exact member number search
   - Update search field placeholder text

3. **InventoryService** (`lib/services/inventory_service.dart`)
   - Add `deleteSale()` method with stock adjustment logic
   - Create stock movement records for audit trail

### Data Flow

```
User Action (Delete Sale)
    ↓
Confirmation Dialog
    ↓
InventoryService.deleteSale()
    ↓
Database Transaction:
  1. Restore stock for each sale item
  2. Create stock movement records
  3. Mark sale as inactive
    ↓
Refresh UI & Show Success Message
```

## Components and Interfaces

### 1. CropSearchScreen Modifications

#### Modified Method: `_filterCollections()`

**Current Behavior:**

```dart
if (!memberNo.toLowerCase().contains(memberQuery.toLowerCase())) {
  return false;
}
```

**New Behavior:**

```dart
if (memberNo.toLowerCase() != memberQuery.toLowerCase()) {
  return false;
}
```

**Rationale:** Change from `contains()` to exact equality check (`==`) to match only the exact member number.

### 2. SalesReportScreen Modifications

#### A. Modified Method: `_applyFilters()`

**Current Behavior:**

```dart
if (_searchQuery.value.isNotEmpty) {
  final query = _searchQuery.value.toLowerCase();
  return sale.receiptNumber?.toLowerCase().contains(query) == true ||
         sale.memberName?.toLowerCase().contains(query) == true;
}
```

**New Behavior:**

```dart
if (_searchQuery.value.isNotEmpty) {
  final query = _searchQuery.value.trim();
  final memberNumber = (sale.memberId ?? '').toString();
  return memberNumber == query;
}
```

**Rationale:**

- Remove receipt number search
- Remove member name search
- Use exact matching for member number
- Use `memberId` field from Sale model

#### B. Modified Widget: `_buildFiltersSection()`

**Change:** Update search field placeholder text

```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Search by member number',  // Changed from 'Search by receipt # or member'
    prefixIcon: const Icon(Icons.search),
    // ... rest of decoration
  ),
  // ... rest of TextField
)
```

#### C. New Method: `_deleteSale(Sale sale)`

```dart
Future<void> _deleteSale(Sale sale) async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Sale'),
      content: Text(
        'Are you sure you want to delete this sale?\n\n'
        'Receipt: ${sale.receiptNumber ?? 'N/A'}\n'
        'Amount: KSh ${NumberFormat('#,##0.00').format(sale.totalAmount)}\n\n'
        'Stock will be restored for all items.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    _isLoading.value = true;

    final result = await _inventoryService.deleteSale(sale.id);

    if (result['success']) {
      Get.snackbar(
        'Success',
        'Sale deleted successfully. Stock has been restored.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      await _loadSalesData();
    } else {
      Get.snackbar(
        'Error',
        result['error'] ?? 'Failed to delete sale',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  } catch (e) {
    Get.snackbar(
      'Error',
      'Failed to delete sale: $e',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  } finally {
    _isLoading.value = false;
  }
}
```

#### D. Modified Widget: `_buildSaleRow(Sale sale)`

**Add delete button to each row:**

```dart
Widget _buildSaleRow(Sale sale) {
  return InkWell(
    onLongPress: () => _deleteSale(sale),  // Long press to delete
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Existing data cells...
          _buildDataCell(...),

          // Add delete button at the end
          SizedBox(
            width: 50.0,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              onPressed: () => _deleteSale(sale),
              tooltip: 'Delete Sale',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Update column widths to include delete button:**

```dart
Map<String, double> get _columnWidths {
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 600;

  if (isSmallScreen) {
    return {
      'date': 100.0,
      'receipt': 100.0,
      'member': 100.0,
      'type': 70.0,
      'items': 60.0,
      'amount': 90.0,
      'paid': 70.0,
      'balance': 70.0,
      'actions': 50.0,  // New column for delete button
    };
  } else {
    return {
      'date': 120.0,
      'receipt': 120.0,
      'member': 140.0,
      'type': 80.0,
      'items': 80.0,
      'amount': 100.0,
      'paid': 90.0,
      'balance': 90.0,
      'actions': 50.0,  // New column for delete button
    };
  }
}
```

**Add header for actions column:**

```dart
_buildHeaderCell('Actions', _columnWidths['actions']!),
```

### 3. InventoryService Modifications

#### New Method: `deleteSale(String saleId)`

```dart
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

        // Get current stock
        final stockMaps = await txn.query(
          'stock',
          where: 'productId = ?',
          whereArgs: [productId],
        );

        if (stockMaps.isEmpty) {
          throw Exception('Stock record not found for product: $productName');
        }

        final currentStock = (stockMaps.first['currentStock'] as num).toDouble();
        final availableStock = (stockMaps.first['availableStock'] as num).toDouble();
        final newCurrentStock = currentStock + quantity;
        final newAvailableStock = availableStock + quantity;

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
          'quantity': quantity,
          'balanceBefore': currentStock,
          'balanceAfter': newCurrentStock,
          'reference': 'Sale Deletion: ${saleMaps.first['receiptNumber'] ?? saleId}',
          'notes': 'Stock restored due to sale deletion',
          'movementDate': now,
          'userId': 'system',
          'userName': 'System',
        });
      }

      // 4. Mark sale as inactive (soft delete)
      await txn.update(
        'sales',
        {
          'isActive': 0,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    // Reload data to reflect changes
    await Future.wait([
      loadStocks(),
      loadSales(),
    ]);

    return {'success': true};
  } catch (e) {
    print('Error deleting sale: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
```

## Data Models

### Existing Models Used

**Sale Model** (`lib/models/sale.dart`):

- `id`: Unique identifier
- `memberId`: Member identifier (used for exact matching)
- `memberName`: Member display name
- `receiptNumber`: Receipt identifier
- `items`: List of SaleItem objects
- `isActive`: Soft delete flag
- Other fields for amounts, dates, etc.

**SaleItem Model** (`lib/models/sale.dart`):

- `productId`: Product identifier
- `productName`: Product display name
- `quantity`: Quantity sold
- Other fields for pricing

**Stock Model**:

- `productId`: Product identifier
- `currentStock`: Total stock quantity
- `availableStock`: Available for sale
- `reservedStock`: Reserved quantity

### Database Tables

**sales table**:

- Soft delete using `isActive` flag
- No physical deletion to maintain audit trail

**stock table**:

- Updated to restore quantities when sale is deleted

**stock_movements table**:

- New records created with `movementType = 'SALE_REVERSAL'`
- Provides audit trail for stock adjustments

## Error Handling

### CropSearchScreen

- No additional error handling needed (simple filter logic)
- Existing error handling for data loading remains unchanged

### SalesReportScreen

- **Delete Confirmation**: User must confirm before deletion
- **Loading State**: Show loading indicator during deletion
- **Success Feedback**: Display success snackbar with confirmation message
- **Error Feedback**: Display error snackbar with specific error message
- **Transaction Failure**: If any part of deletion fails, entire transaction is rolled back

### InventoryService

- **Transaction Atomicity**: Use database transaction to ensure all-or-nothing operation
- **Stock Record Validation**: Verify stock records exist before updating
- **Sale Validation**: Verify sale exists and is active before deletion
- **Rollback on Error**: Automatic rollback if any operation fails
- **Error Messages**: Return descriptive error messages for UI display

## Testing Strategy

### Unit Tests (Optional)

1. **Filter Logic Tests**:

   - Test exact member number matching in CropSearchScreen
   - Test exact member number search in SalesReportScreen
   - Test empty search/filter behavior

2. **Service Method Tests**:
   - Test `deleteSale()` with valid sale
   - Test `deleteSale()` with non-existent sale
   - Test stock restoration calculations
   - Test transaction rollback on error

### Integration Tests (Optional)

1. **End-to-End Delete Flow**:

   - Create a sale
   - Delete the sale
   - Verify stock is restored
   - Verify sale is marked inactive
   - Verify stock movement record is created

2. **Filter Behavior**:
   - Test exact match filtering with various member numbers
   - Test filter clearing behavior

### Manual Testing

1. **Crop Search Screen**:

   - Enter exact member number → verify only exact matches shown
   - Enter partial member number → verify no results (or only exact match if exists)
   - Clear filter → verify all collections shown

2. **Sales Report Screen**:

   - Search by exact member number → verify only exact matches shown
   - Search by partial member number → verify no results
   - Delete a sale → verify confirmation dialog
   - Confirm deletion → verify success message and stock restored
   - Cancel deletion → verify no changes made
   - Try to delete non-existent sale → verify error handling

3. **Stock Verification**:
   - Note stock levels before sale deletion
   - Delete sale
   - Verify stock levels increased by sold quantities
   - Check stock movement records for audit trail

## Security Considerations

1. **Soft Delete**: Sales are marked inactive rather than physically deleted to maintain audit trail
2. **Transaction Integrity**: Database transactions ensure data consistency
3. **Audit Trail**: Stock movement records provide complete history of changes
4. **User Confirmation**: Confirmation dialog prevents accidental deletions
5. **Error Handling**: Proper error messages without exposing sensitive system information

## Performance Considerations

1. **Filter Performance**: Exact matching is faster than partial matching (no substring search)
2. **Transaction Performance**: Single transaction for all stock updates ensures atomicity without multiple round trips
3. **UI Responsiveness**: Loading indicators prevent UI blocking during deletion
4. **Data Refresh**: Only necessary data (stocks and sales) is reloaded after deletion

## Deployment Notes

1. **Database Migration**: No schema changes required (using existing columns)
2. **Backward Compatibility**: Changes are additive (new method, modified filters)
3. **Testing**: Thoroughly test on development environment before production
4. **Rollback Plan**: If issues arise, can revert code changes without data loss (soft delete preserves data)
