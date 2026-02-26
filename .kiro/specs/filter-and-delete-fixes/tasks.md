# Implementation Plan

- [x] 1. Update CropSearchScreen member number filter to use exact matching

  - Modify the `_filterCollections()` method in `lib/screens/reports/crop_search_screen.dart`
  - Change member number comparison from `contains()` to exact equality check (`==`)
  - Test the filter with various member numbers to ensure only exact matches are returned
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [-] 2. Add sale deletion functionality to InventoryService

  - [x] 2.1 Implement `deleteSale()` method in `lib/services/inventory_service.dart`

    - Create method signature that accepts `saleId` and returns `Map<String, dynamic>`
    - Implement database transaction to ensure atomicity
    - Query sale and sale items from database
    - Loop through each sale item and restore stock quantities
    - Create stock movement records for audit trail with `movementType = 'SALE_REVERSAL'`
    - Mark sale as inactive (soft delete) by setting `isActive = 0`
    - Reload stocks and sales data after successful deletion
    - Return success/error response map
    - _Requirements: 2.3, 2.4, 2.7, 2.8_

-

- [x] 3. Update SalesReportScreen to support sale deletion

  - [x] 3.1 Add delete button to sales table

    - Update `_columnWidths` map to include 'actions' column (50.0 width)
    - Add 'Actions' header cell in `_buildSalesTable()` method
    - Modify `_buildSaleRow()` to include delete IconButton at the end
    - Style delete button with red color and appropriate size
    - _Requirements: 2.1_

  - [x] 3.2 Implement delete confirmation and execution logic

    - Create `_deleteSale(Sale sale)` method
    - Show confirmation AlertDialog with sale details (receipt number, amount)
    - Include warning that stock will be restored
    - Handle user confirmation/cancellation
    - Call `_inventoryService.deleteSale()` on confirmation
    - Show loading indicator during deletion
    - Display success/error snackbar based on result
    - Reload sales data after successful deletion
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6_

-

- [x] 4. Update SalesReportScreen search to use exact member number matching

  - [x] 4.1 Modify search filter logic

    - Update `_applyFilters()` method in `lib/screens/inventory/sales_report_screen.dart`
    - Remove receipt number search logic
    - Remove member name search logic
    - Implement exact member number matching using `memberId` field
    - Use trim() to remove whitespace from search query
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 4.2 Update search field placeholder text

    - Modify `_buildFiltersSection()` method
    - Change TextField hintText from 'Search by receipt # or member' to 'Search by member number'
    - _Requirements: 3.6_

-

- [-] 5. Test all implementations

  - [-] 5.1 Test CropSearchScreen exact member number filter

    - Enter exact member number and verify only exact matches shown
    - Enter partial member number and verify no results (or only exact match)
    - Clear filter and verify all collections shown
    - Test with empty member number field
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ] 5.2 Test SalesReportScreen sale deletion

    - Create a test sale with multiple items
    - Note stock levels before deletion
    - Click delete button and verify confirmation dialog appears
    - Cancel deletion and verify no changes
    - Confirm deletion and verify success message
    - Verify stock levels increased by sold quantities
    - Check stock movement records for audit trail
    - Verify sale is marked as inactive in database
    - Test error handling with invalid sale ID
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

  - [ ] 5.3 Test SalesReportScreen exact member number search
    - Enter exact member number and verify only exact matches shown
    - Enter partial member number and verify no results
    - Clear search and verify all sales shown
    - Test with empty search field
    - Verify placeholder text shows 'Search by member number'
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
