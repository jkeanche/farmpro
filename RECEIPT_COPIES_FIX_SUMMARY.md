# Receipt Copies Fix Summary

## Issue

The `_generateReceiptPdf` method in `print_service.dart` was not creating the correct number of copies as specified in system settings. Although the `receiptDuplicates` setting was being read from system settings, the copies parameter was never passed to the PDF generation method.

## Root Cause

1. The `printReceipt` method was looping and calling print methods multiple times
2. However, `_generateReceiptPdf` was always called with the default `copies = 1` parameter
3. The PDF generation method has built-in logic to create multiple pages (copies) in a single PDF, but this was never being utilized
4. The external loop was redundant and ineffective

## Changes Made

### 1. Updated `printReceipt` Method

**Before:**

```dart
// Print the specified number of copies
for (int i = 0; i < copiesToPrint; i++) {
  if (currentPrintMethod.value == PrintMethod.bluetooth) {
    await _printViaBluetoothPrinter(receiptData);
  } else {
    await _printViaDirectPrinter(receiptData);
  }

  // Small delay between prints to avoid overwhelming the printer
  if (i < copiesToPrint - 1) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
```

**After:**

```dart
// Print with the specified number of copies
if (currentPrintMethod.value == PrintMethod.bluetooth) {
  await _printViaBluetoothPrinter(receiptData, copiesToPrint);
} else {
  await _printViaDirectPrinter(receiptData, copiesToPrint);
}
```

### 2. Updated `_printViaBluetoothPrinter` Method

**Before:**

```dart
Future<void> _printViaBluetoothPrinter(
  Map<String, dynamic> receiptData,
) async {
  // ...
  final pdf = await _generateReceiptPdf(receiptData);
  // ...
}
```

**After:**

```dart
Future<void> _printViaBluetoothPrinter(
  Map<String, dynamic> receiptData,
  int copies,
) async {
  // ...
  final pdf = await _generateReceiptPdf(receiptData, copies: copies);
  // ...
}
```

### 3. Updated `_printViaDirectPrinter` Method

**Before:**

```dart
Future<void> _printViaDirectPrinter(Map<String, dynamic> receiptData) async {
  // ...
  final pdf = await _generateReceiptPdf(receiptData);
  // ...
}
```

**After:**

```dart
Future<void> _printViaDirectPrinter(
  Map<String, dynamic> receiptData,
  int copies,
) async {
  // ...
  final pdf = await _generateReceiptPdf(receiptData, copies: copies);
  // ...
}
```

### 4. Updated `printCoffeeCollectionReceipt` Method

- Added explicit `copiesToPrint = 1` for coffee collection receipts (typically single copy)
- Updated method calls to pass the copies parameter

### 5. Updated `printInventorySaleReceipt` Method

- Reads `receiptDuplicates` from system settings
- Passes the copies parameter to print methods
- This ensures inventory sale receipts respect the system setting for number of copies

## How It Works Now

1. **System Settings**: The `receiptDuplicates` setting (1 or 2) is stored in system settings
2. **Print Request**: When printing an inventory sale receipt, the system reads the `receiptDuplicates` value
3. **PDF Generation**: The `_generateReceiptPdf` method receives the `copies` parameter
4. **Multiple Pages**: The PDF generator creates multiple pages (one per copy) in a single PDF document:
   ```dart
   for (int copyNumber = 0; copyNumber < copies; copyNumber++) {
     pdf.addPage(/* receipt content */);
   }
   ```
5. **Single Print Job**: The entire multi-page PDF is sent to the printer as one job

## Benefits

1. **Correct Behavior**: Receipts now print the correct number of copies as configured
2. **Efficient**: Single print job instead of multiple separate jobs
3. **Cleaner Code**: Removed redundant loop and simplified logic
4. **Consistent**: All print methods now properly handle the copies parameter

## Testing Recommendations

1. Set `receiptDuplicates` to 2 in system settings
2. Create an inventory sale
3. Verify that 2 copies of the receipt are generated in the PDF
4. Test with both Bluetooth and direct printing methods
5. Verify coffee collection receipts still print single copy
