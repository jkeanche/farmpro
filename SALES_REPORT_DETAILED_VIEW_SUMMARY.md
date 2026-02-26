# Sales Report Detailed View Feature

## Overview

Added a toggle feature to the Sales Report Screen that allows users to switch between two views:

1. **Summary View** (existing) - Shows sale totals per transaction
2. **Detailed View** (new) - Shows individual items purchased in each sale

## Changes Made

### 1. Added View Toggle State

```dart
final RxBool _showDetailedView = false.obs; // Toggle between summary and detailed view
```

### 2. Updated Column Widths

Modified `_columnWidths` getter to return different column configurations based on the view:

**Summary View Columns:**

- Date
- Receipt #
- Member #
- Member Name
- Type (CASH/CREDIT)
- Items (count)
- Amount
- Paid
- Balance
- Actions

**Detailed View Columns:**

- Date
- Receipt #
- Member #
- Member Name
- Item (product name)
- Quantity
- Unit Price
- Total

### 3. Added View Toggle UI

Added a segmented button in the filters section:

```dart
SegmentedButton<bool>(
  segments: [
    ButtonSegment(value: false, label: 'Summary', icon: Icon(Icons.summarize)),
    ButtonSegment(value: true, label: 'Detailed', icon: Icon(Icons.list_alt)),
  ],
  selected: {_showDetailedView.value},
  onSelectionChanged: (Set<bool> selected) {
    _showDetailedView.value = selected.first;
  },
)
```

### 4. Updated Excel Export

Modified `_generateExcelFile()` to support both views:

**Summary View Export:**

- One row per sale transaction
- Shows: Date, Receipt #, Member #, Member Name, Type, Items Count, Amount, Paid, Balance

**Detailed View Export:**

- One row per item
- Shows: Date, Receipt #, Member #, Member Name, Item, Quantity, Unit Price, Total
- Multiple rows for sales with multiple items

### 5. Added New List View Methods

#### `_buildSummaryListView()`

- Displays the existing summary view
- One row per sale transaction
- Shows totals row at the bottom

#### `_buildDetailedListView()`

- Displays individual items from all sales
- Calculates total number of items across all sales
- Maps each index to the correct sale and item
- Shows detailed totals row at the bottom

#### `_buildDetailedItemRow(Sale sale, SaleItem item)`

- Renders a single item row
- Shows sale info + item details
- Displays: Date, Receipt #, Member #, Member Name, Item Name, Quantity, Unit Price, Total

#### `_buildDetailedTotalsRow()`

- Shows totals for detailed view
- Calculates:
  - Total quantity of all items
  - Grand total of all item prices
- Displays in a highlighted row

### 6. Updated Table Header

Modified table header to show different columns based on view:

- Uses conditional rendering with `_showDetailedView.value`
- Dynamically builds header row based on current view

## User Experience

### Summary View (Default)

- Quick overview of all sales transactions
- Shows payment status (Cash/Credit)
- Displays balance information
- Includes delete action button
- Best for: Financial reconciliation, payment tracking

### Detailed View

- Itemized breakdown of all purchases
- Shows what products were sold
- Displays quantities and prices
- Best for: Inventory analysis, product performance tracking

### Switching Views

1. User clicks the segmented button in filters section
2. Table instantly updates to show selected view
3. Column headers change to match view
4. Data is reorganized accordingly

### Export Behavior

- **Download** and **Share** buttons respect current view
- Summary view exports sale totals
- Detailed view exports itemized list
- Excel file name includes timestamp
- File format: `.xlsx`

## Benefits

1. **Flexibility**: Users can analyze data at different levels of detail
2. **No Data Loss**: Both views use the same filtered data
3. **Consistent UX**: Same filters apply to both views
4. **Export Options**: Can export either summary or detailed reports
5. **Performance**: Efficient rendering using ListView.builder
6. **Responsive**: Works on both small and large screens

## Technical Implementation

### State Management

- Uses GetX reactive variables (Rx)
- Automatic UI updates when view changes
- No manual setState() calls needed

### Performance Optimization

- ListView.builder for efficient scrolling
- Only renders visible items
- Reuses widgets where possible

### Data Mapping

- Detailed view flattens sale items into single list
- Maintains relationship between sales and items
- Efficient index calculation for large datasets

## Testing Recommendations

1. **View Toggle**: Switch between views multiple times
2. **Filtering**: Apply filters in both views
3. **Export**: Download/share reports in both views
4. **Large Datasets**: Test with many sales and items
5. **Scrolling**: Verify horizontal and vertical scrolling
6. **Totals**: Confirm calculations are correct in both views
7. **Empty State**: Test with no sales data
8. **Member Search**: Search by member number in both views

## Future Enhancements

Potential improvements:

- Add sorting options (by date, amount, member, etc.)
- Include product category filtering in detailed view
- Add charts/graphs for visual analysis
- Export to PDF format
- Print functionality
- Date grouping in detailed view
- Subtotals per sale in detailed view
