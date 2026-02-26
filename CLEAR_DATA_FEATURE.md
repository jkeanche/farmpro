# Clear Data Feature Implementation

## Overview

Added "Export & Clear Data" functionality to both the Collections Report and Sales Report screens. This feature allows users to export all data to CSV format and then clear the database, providing a clean slate while maintaining a backup.

## Changes Made

### 1. Services Layer

#### `lib/services/coffee_collection_service.dart`

- **Added Method**: `deleteAllCollections()`
  - Deletes all collection records from the database
  - Returns a map with success status and deleted count
  - Automatically refreshes collections after deletion

#### `lib/services/inventory_service.dart`

- **Added Method**: `deleteAllSales()`
  - Deletes all sales records (soft delete - marks as inactive)
  - Restores stock for all sold items
  - Creates stock movement records for audit trail
  - Returns a map with success status and deleted count
  - Automatically refreshes sales and stock after deletion

### 2. Collections Report Screen

#### `lib/screens/reports/reports_screen.dart`

**New Methods:**

- `_exportAndClearCollections()` - Main method that:

  1. Shows confirmation dialog with warnings
  2. Exports collections to CSV in import template format
  3. Deletes all collections from database
  4. Shows success/error feedback
  5. Refreshes the report view

- `_exportCollectionsForImport()` - Exports collections in import template format:

  - CSV columns: Date, Member #, Member Name, Season, Product, Gross Weight, Tare Weight, Net Weight, Bags, Served By
  - Exports ALL collections (not just filtered ones) for complete backup
  - Saves to Downloads directory

- `_saveToDownloads()` - Helper method to save files to Downloads directory
  - Handles Android and iOS file paths
  - Creates Download directory if it doesn't exist

**UI Changes:**

- Added "Export & Clear Data" option to the "More Options" menu (three-dot menu)
- Displayed in red to indicate destructive action
- Icon: `delete_sweep`

### 3. Sales Report Screen

#### `lib/screens/inventory/sales_report_screen.dart`

**New Methods:**

- `_exportAndClearSales()` - Main method that:

  1. Shows confirmation dialog with warnings
  2. Exports sales to CSV format
  3. Deletes all sales from database
  4. Restores stock for all items
  5. Shows success/error feedback
  6. Refreshes the report view

- `_exportSalesToCSV()` - Exports sales in detailed format:

  - CSV columns: Date, Receipt #, Member #, Member Name, Type, Item, Quantity, Unit Price, Total, Paid, Balance
  - Exports ALL sales (not just filtered ones) for complete backup
  - One row per item (detailed view)
  - Saves to Downloads directory

- `_saveToDownloads()` - Helper method to save files to Downloads directory
  - Same implementation as reports screen

**UI Changes:**

- Added "Export & Clear Data" option to a new "More Options" menu
- Displayed in red to indicate destructive action
- Icon: `delete_sweep`

**Import Added:**

- Added `package:csv/csv.dart` import for CSV generation

## CSV Export Formats

### Collections Export (Import Template Format)

```csv
Date,Member #,Member Name,Season,Product,Gross Weight (kg),Tare Weight (kg),Net Weight (kg),Bags,Served By
2024-01-15 10:30:00,M001,John Doe,2024,CHERRY,100.50,0.50,100.00,2,Admin
```

This format matches the import template, allowing users to re-import the data if needed.

### Sales Export Format

```csv
Date,Receipt #,Member #,Member Name,Type,Item,Quantity,Unit Price,Total,Paid,Balance
2024-01-15 14:20:00,RCP001,M001,John Doe,CASH,Fertilizer,5.00,500.00,2500.00,2500.00,0.00
```

This format provides detailed transaction records with one row per item sold.

## User Flow

### Collections Report - Clear Data

1. User opens Collections Report
2. Clicks three-dot menu → "Export & Clear Data"
3. Confirmation dialog appears with warnings:
   - Will export all collections to CSV
   - Will save to Downloads
   - Will delete ALL collection records
   - Action cannot be undone
4. User confirms
5. System:
   - Exports all collections to CSV (import format)
   - Saves file to Downloads as `Collections_Backup_YYYYMMDD_HHMMSS.csv`
   - Deletes all collection records
   - Shows success message with count
   - Refreshes the report view

### Sales Report - Clear Data

1. User opens Sales Report
2. Clicks three-dot menu → "Export & Clear Data"
3. Confirmation dialog appears with warnings:
   - Will export all sales to CSV
   - Will save to Downloads
   - Will delete ALL sales records
   - Will restore stock for all items
   - Action cannot be undone
4. User confirms
5. System:
   - Exports all sales to CSV (detailed format)
   - Saves file to Downloads as `Sales_Backup_YYYYMMDD_HHMMSS.csv`
   - Deletes all sales records (soft delete)
   - Restores stock for all sold items
   - Creates stock movement audit records
   - Shows success message with count
   - Refreshes the report view

## Safety Features

1. **Confirmation Dialog**: Requires explicit user confirmation before proceeding
2. **Warning Messages**: Clear warnings that action cannot be undone
3. **Automatic Backup**: Always exports data before deletion
4. **File Naming**: Timestamped filenames prevent overwriting
5. **Stock Restoration**: Sales deletion automatically restores inventory
6. **Audit Trail**: Stock movements are recorded for sales deletions
7. **Soft Delete**: Sales are marked inactive rather than hard deleted
8. **Error Handling**: Comprehensive try-catch blocks with user feedback

## File Locations

### Android

- Files saved to: `/storage/emulated/0/Android/data/<package_name>/files/Download/`
- Accessible through file manager

### iOS

- Files saved to: App's Documents directory
- Accessible through Files app

## Testing Checklist

- [ ] Collections Report: Export & Clear with data
- [ ] Collections Report: Export & Clear with no data
- [ ] Collections Report: Cancel confirmation dialog
- [ ] Collections Report: Verify CSV format matches import template
- [ ] Collections Report: Verify file saved to Downloads
- [ ] Collections Report: Verify all collections deleted
- [ ] Sales Report: Export & Clear with data
- [ ] Sales Report: Export & Clear with no data
- [ ] Sales Report: Cancel confirmation dialog
- [ ] Sales Report: Verify CSV format is correct
- [ ] Sales Report: Verify file saved to Downloads
- [ ] Sales Report: Verify all sales deleted
- [ ] Sales Report: Verify stock restored correctly
- [ ] Sales Report: Verify stock movements recorded
- [ ] Error handling: Test with permission denied
- [ ] Error handling: Test with storage full
- [ ] UI: Verify red color for destructive action
- [ ] UI: Verify success/error messages display correctly

## Notes

- The collections CSV uses the import template format, allowing users to re-import the data
- The sales CSV uses a detailed format with one row per item for complete transaction history
- Stock is automatically restored when sales are deleted
- All deletions are logged with timestamps in the filename
- The feature is intentionally placed in a menu to prevent accidental activation
- Red color and warning icons indicate the destructive nature of the action
