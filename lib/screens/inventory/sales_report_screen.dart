import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/custom_app_bar.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final InventoryService _inventoryService = Get.find<InventoryService>();

  // State variables
  final RxBool _isLoading = false.obs;
  final RxString _error = ''.obs;
  final RxList<Sale> _sales = <Sale>[].obs;
  final RxList<Sale> _filteredSales = <Sale>[].obs;

  // Date range filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Filter options
  final RxString _selectedSaleType = 'ALL'.obs;
  final RxString _searchQuery = ''.obs;
  final RxBool _showCumulative = true.obs;
  final RxBool _showDetailedView =
      false.obs; // Toggle between summary and detailed view

  // Summary data
  final RxDouble _totalSales = 0.0.obs;
  final RxDouble _totalCash = 0.0.obs;
  final RxDouble _totalCredit = 0.0.obs;
  final RxInt _totalTransactions = 0.obs;

  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();

  // Column widths
  Map<String, double> get _columnWidths {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    // Detailed view columns (showing individual items)
    if (_showDetailedView.value) {
      if (isSmallScreen) {
        return {
          'date': 100.0,
          'receipt': 100.0,
          'memberNumber': 80.0,
          'member': 100.0,
          'item': 120.0,
          'quantity': 70.0,
          'unitPrice': 80.0,
          'total': 90.0,
        };
      } else {
        return {
          'date': 120.0,
          'receipt': 120.0,
          'memberNumber': 100.0,
          'member': 140.0,
          'item': 180.0,
          'quantity': 80.0,
          'unitPrice': 100.0,
          'total': 100.0,
        };
      }
    }

    // Summary view columns (current view)
    if (isSmallScreen) {
      return {
        'date': 100.0,
        'receipt': 100.0,
        'memberNumber': 80.0,
        'member': 100.0,
        'type': 70.0,
        'items': 60.0,
        'amount': 90.0,
        'paid': 70.0,
        'balance': 70.0,
        'actions': 50.0,
      };
    } else {
      return {
        'date': 120.0,
        'receipt': 120.0,
        'memberNumber': 100.0,
        'member': 140.0,
        'type': 80.0,
        'items': 80.0,
        'amount': 100.0,
        'paid': 90.0,
        'balance': 90.0,
        'actions': 50.0,
      };
    }
  }

  // Total table width
  double get _totalTableWidth => _columnWidths.values.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _loadSalesData();
    _syncScrollControllers();
  }

  void _syncScrollControllers() {
    _horizontalScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          !_headerScrollController.position.isScrollingNotifier.value) {
        _headerScrollController.jumpTo(_horizontalScrollController.offset);
      }
    });

    _headerScrollController.addListener(() {
      if (_horizontalScrollController.hasClients &&
          !_horizontalScrollController.position.isScrollingNotifier.value) {
        _horizontalScrollController.jumpTo(_headerScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Sales Report',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalesData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadExcel,
            tooltip: 'Download Report',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareExcel,
            tooltip: 'Share Report',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            onSelected: (value) {
              if (value == 'clear_data') {
                _exportAndClearSales();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_data',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Export & Clear Data',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (_isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_error.value.isNotEmpty) {
        return Center(child: Text('Error: ${_error.value}'));
      }

      return Column(
        children: [
          _buildFiltersSection(),
          _buildSummarySection(),
          const SizedBox(height: 8),
          Expanded(child: _buildSalesList()),
        ],
      );
    });
  }

  Future<void> _loadSalesData() async {
    _isLoading.value = true;
    _error.value = '';

    try {
      final sales = await _inventoryService.loadSalesForDateRange(
        _startDate,
        _endDate,
      );
      _sales.value = sales;
      _applyFilters();
      _calculateSummary();
    } catch (e) {
      _error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to load sales data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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

  void _applyFilters() {
    _filteredSales.value =
        _sales.where((sale) {
          // Filter by sale type
          if (_selectedSaleType.value != 'ALL' &&
              sale.saleType != _selectedSaleType.value) {
            return false;
          }

          // Filter by search query (exact member number match only)
          if (_searchQuery.value.isNotEmpty) {
            final query = _searchQuery.value.trim();
            final memberNumber = (sale.memberNumber ?? '').toString();
            return memberNumber == query;
          }

          return true;
        }).toList();

    _calculateSummary();
  }

  void _calculateSummary() {
    double totalSales = 0;
    double totalCash = 0;
    double totalCredit = 0;

    for (final sale in _filteredSales) {
      totalSales += sale.totalAmount;
      if (sale.saleType == 'CASH') {
        totalCash += sale.totalAmount;
      } else if (sale.saleType == 'CREDIT') {
        totalCredit += sale.totalAmount;
      }
    }

    _totalSales.value = totalSales;
    _totalCash.value = totalCash;
    _totalCredit.value = totalCredit;
    _totalTransactions.value = _filteredSales.length;
  }

  Future<String> _generateExcelFile() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sales Report'];

    if (_showDetailedView.value) {
      // Detailed view: Show individual items
      final headers = [
        TextCellValue('Date'),
        TextCellValue('Receipt #'),
        TextCellValue('Member #'),
        TextCellValue('Member Name'),
        TextCellValue('Item'),
        TextCellValue('Quantity'),
        TextCellValue('Unit Price'),
        TextCellValue('Total'),
      ];
      sheet.appendRow(headers);

      // Add data rows - one row per item
      for (final sale in _filteredSales) {
        for (final item in sale.items) {
          sheet.appendRow([
            TextCellValue(DateFormat('yyyy-MM-dd').format(sale.saleDate)),
            TextCellValue(sale.receiptNumber ?? ''),
            TextCellValue(sale.memberNumber ?? ''),
            TextCellValue(sale.memberName ?? ''),
            TextCellValue(item.productName),
            DoubleCellValue(item.quantity),
            DoubleCellValue(item.unitPrice),
            DoubleCellValue(item.totalPrice),
          ]);
        }
      }
    } else {
      // Summary view: Show sale totals
      final headers = [
        TextCellValue('Date'),
        TextCellValue('Receipt #'),
        TextCellValue('Member #'),
        TextCellValue('Member Name'),
        TextCellValue('Type'),
        TextCellValue('Items'),
        TextCellValue('Amount'),
        TextCellValue('Paid'),
        TextCellValue('Balance'),
      ];
      sheet.appendRow(headers);

      // Add data rows
      for (final sale in _filteredSales) {
        sheet.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(sale.saleDate)),
          TextCellValue(sale.receiptNumber ?? ''),
          TextCellValue(sale.memberNumber ?? ''),
          TextCellValue(sale.memberName ?? ''),
          TextCellValue(sale.saleType),
          IntCellValue(sale.items.length),
          DoubleCellValue(sale.totalAmount),
          DoubleCellValue(sale.paidAmount),
          DoubleCellValue(sale.balanceAmount),
        ]);
      }
    }

    // Save the file to temporary directory
    final directory = await getTemporaryDirectory();
    final fileName =
        'sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return filePath;
  }

  Future<void> _shareExcel() async {
    if (_filteredSales.isEmpty) {
      Get.snackbar(
        'No Data',
        'There are no sales to export',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isLoading.value = true;
      final filePath = await _generateExcelFile();

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Sales Report ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to share sales data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _downloadExcel() async {
    if (_filteredSales.isEmpty) {
      Get.snackbar(
        'No Data',
        'There are no sales to export',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isLoading.value = true;

      // First generate the Excel file in temp directory
      final tempFilePath = await _generateExcelFile();
      final tempFile = File(tempFilePath);

      // Check storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission is required to download files');
        }
      }

      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), use getExternalStorageDirectory()
        // which points to /storage/emulated/0/Android/data/<package_name>/files
        // This doesn't require MANAGE_EXTERNAL_STORAGE permission
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Create a Downloads directory in the app's external storage
          downloadsDir = Directory('${externalDir.path}/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
        } else {
          // Fallback to getApplicationDocumentsDirectory() if external storage is not available
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, use the documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create the destination file path
      final fileName =
          'Sales_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final destPath = '${downloadsDir.path}/$fileName';

      // Copy the file to downloads
      await tempFile.copy(destPath);

      Get.snackbar(
        'Success',
        'Report downloaded to Downloads folder',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Export sales to CSV and clear all sales data
  Future<void> _exportAndClearSales() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Clear Sales Data'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Export all sales to CSV'),
                  Text('2. Save the file to Downloads'),
                  Text('3. Delete ALL sales records'),
                  Text('4. Restore stock for all sold items'),
                  SizedBox(height: 16),
                  Text(
                    '⚠️ This action cannot be undone!',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The exported CSV will be saved as a backup.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Export & Clear'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      _isLoading.value = true;

      // Export sales to CSV
      await _exportSalesToCSV();

      // Clear all sales
      final result = await _inventoryService.deleteAllSales();

      if (result['success']) {
        Get.snackbar(
          'Success',
          '${result['deletedCount']} sale(s) deleted. Stock restored. CSV saved to Downloads.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // Refresh the data
        await _loadSalesData();
      } else {
        Get.snackbar(
          'Error',
          'Failed to clear data: ${result['error']}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to export and clear data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Export all sales to CSV format
  Future<void> _exportSalesToCSV() async {
    // CSV format: Date, Receipt #, Member #, Member Name, Type, Item, Quantity, Unit Price, Total, Paid, Balance
    List<List<dynamic>> csvData = [
      [
        'Date',
        'Receipt #',
        'Member #',
        'Member Name',
        'Type',
        'Item',
        'Quantity',
        'Unit Price',
        'Total',
        'Paid',
        'Balance',
      ],
    ];

    // Add all sales (not just filtered ones for complete backup)
    for (final sale in _sales) {
      for (final item in sale.items) {
        csvData.add([
          DateFormat('yyyy-MM-dd HH:mm:ss').format(sale.saleDate),
          sale.receiptNumber ?? 'N/A',
          sale.memberNumber ?? 'N/A',
          sale.memberName ?? 'Walk-in',
          sale.saleType,
          item.productName,
          item.quantity.toStringAsFixed(2),
          item.unitPrice.toStringAsFixed(2),
          item.totalPrice.toStringAsFixed(2),
          sale.paidAmount.toStringAsFixed(2),
          sale.balanceAmount.toStringAsFixed(2),
        ]);
      }
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = csvString.codeUnits;
    final fileName =
        'Sales_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    // Save to Downloads directory
    await _saveToDownloads(bytes, fileName);
  }

  Future<void> _saveToDownloads(List<int> bytes, String fileName) async {
    try {
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          downloadsDir = Directory('${externalDir.path}/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
        } else {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }

      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      print('✅ File saved to: ${file.path}');
    } catch (e) {
      print('❌ Error saving to downloads: $e');
      rethrow;
    }
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                    onPressed: _selectDateRange,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                    onPressed: _selectDateRange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Sale Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFilterChip('ALL', _selectedSaleType),
                const SizedBox(width: 8),
                _buildFilterChip('CASH', _selectedSaleType),
                const SizedBox(width: 8),
                _buildFilterChip('CREDIT', _selectedSaleType),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'View:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Obx(
                  () => SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Summary'),
                        icon: Icon(Icons.summarize, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Detailed'),
                        icon: Icon(Icons.list_alt, size: 16),
                      ),
                    ],
                    selected: {_showDetailedView.value},
                    onSelectionChanged: (Set<bool> selected) {
                      _showDetailedView.value = selected.first;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by member number',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                _searchQuery.value = value;
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RxString selectedValue) {
    return FilterChip(
      label: Text(label),
      selected: selectedValue.value == label,
      onSelected: (selected) {
        selectedValue.value = selected ? label : 'ALL';
        _applyFilters();
      },
    );
  }

  Widget _buildSummarySection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;

            if (isSmallScreen) {
              // Stack summaries vertically on small screens
              return Column(
                children: [
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Sales',
                        _totalSales,
                        Icons.receipt,
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Transactions',
                        _totalTransactions.value.toDouble().obs,
                        Icons.list_alt,
                        Colors.purple,
                        isCount: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Cash Sales',
                        _totalCash,
                        Icons.money,
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Credit Sales',
                        _totalCredit,
                        Icons.credit_card,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              );
            }

            // Display all in one row on larger screens
            return Row(
              children: [
                _buildSummaryCard(
                  'Total Sales',
                  _totalSales,
                  Icons.receipt,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Cash Sales',
                  _totalCash,
                  Icons.money,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Credit Sales',
                  _totalCredit,
                  Icons.credit_card,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Transactions',
                  _totalTransactions.value.toDouble().obs,
                  Icons.list_alt,
                  Colors.purple,
                  isCount: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    RxDouble amount,
    IconData icon,
    Color color, {
    bool isCount = false,
  }) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  isCount
                      ? amount.value.toInt().toString()
                      : 'KSh ${NumberFormat('#,##0.00').format(amount.value)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    return Obx(() {
      if (_filteredSales.isEmpty) {
        return const Center(
          child: Text('No sales found for the selected filters'),
        );
      }

      return _buildSalesTable();
    });
  }

  Widget _buildSalesTable() {
    return Obx(
      () => Column(
        children: [
          // Table header with horizontal scroll
          SingleChildScrollView(
            controller: _headerScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Container(
              width: _totalTableWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: const Border(bottom: BorderSide(color: Colors.grey)),
              ),
              child:
                  _showDetailedView.value
                      ? Row(
                        children: [
                          _buildHeaderCell('Date', _columnWidths['date']!),
                          _buildHeaderCell(
                            'Receipt #',
                            _columnWidths['receipt']!,
                          ),
                          _buildHeaderCell(
                            'Member #',
                            _columnWidths['memberNumber']!,
                          ),
                          _buildHeaderCell('Member', _columnWidths['member']!),
                          _buildHeaderCell('Item', _columnWidths['item']!),
                          _buildHeaderCell(
                            'Quantity',
                            _columnWidths['quantity']!,
                          ),
                          _buildHeaderCell(
                            'Unit Price',
                            _columnWidths['unitPrice']!,
                          ),
                          _buildHeaderCell('Total', _columnWidths['total']!),
                        ],
                      )
                      : Row(
                        children: [
                          _buildHeaderCell('Date', _columnWidths['date']!),
                          _buildHeaderCell(
                            'Receipt #',
                            _columnWidths['receipt']!,
                          ),
                          _buildHeaderCell(
                            'Member #',
                            _columnWidths['memberNumber']!,
                          ),
                          _buildHeaderCell('Member', _columnWidths['member']!),
                          _buildHeaderCell('Type', _columnWidths['type']!),
                          _buildHeaderCell('Items', _columnWidths['items']!),
                          _buildHeaderCell('Amount', _columnWidths['amount']!),
                          _buildHeaderCell('Paid', _columnWidths['paid']!),
                          _buildHeaderCell(
                            'Balance',
                            _columnWidths['balance']!,
                          ),
                          _buildHeaderCell(
                            'Actions',
                            _columnWidths['actions']!,
                          ),
                        ],
                      ),
            ),
          ),

          // Table body with horizontal scroll
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: _totalTableWidth,
                child:
                    _showDetailedView.value
                        ? _buildDetailedListView()
                        : _buildSummaryListView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSummaryListView() {
    return ListView.builder(
      controller: _verticalScrollController,
      itemCount: _filteredSales.length + 1, // +1 for totals row
      itemBuilder: (context, index) {
        if (index < _filteredSales.length) {
          return _buildSaleRow(_filteredSales[index]);
        } else {
          return _buildTotalsRow();
        }
      },
    );
  }

  Widget _buildDetailedListView() {
    // Calculate total number of items across all sales
    int totalItems = 0;
    for (final sale in _filteredSales) {
      totalItems += sale.items.length;
    }

    print(
      '📊 Detailed view: ${_filteredSales.length} sales, $totalItems total items',
    );

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

    return ListView.builder(
      controller: _verticalScrollController,
      itemCount: totalItems + 1, // +1 for totals row
      itemBuilder: (context, index) {
        if (index < totalItems) {
          // Find which sale and item this index corresponds to
          int currentIndex = 0;
          for (final sale in _filteredSales) {
            if (index < currentIndex + sale.items.length) {
              final itemIndex = index - currentIndex;
              return _buildDetailedItemRow(sale, sale.items[itemIndex]);
            }
            currentIndex += sale.items.length;
          }
        } else {
          return _buildDetailedTotalsRow();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDetailedItemRow(Sale sale, SaleItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(
            DateFormat('MMM dd, yyyy').format(sale.saleDate),
            _columnWidths['date']!,
          ),
          _buildDataCell(
            sale.receiptNumber ?? 'N/A',
            _columnWidths['receipt']!,
          ),
          _buildDataCell(
            sale.memberNumber ?? 'N/A',
            _columnWidths['memberNumber']!,
          ),
          _buildDataCell(
            sale.memberName ?? 'Walk-in',
            _columnWidths['member']!,
          ),
          _buildDataCell(item.productName, _columnWidths['item']!),
          _buildDataCell(
            item.quantity.toStringAsFixed(1),
            _columnWidths['quantity']!,
            textAlign: TextAlign.right,
          ),
          _buildDataCell(
            NumberFormat('#,##0.00').format(item.unitPrice),
            _columnWidths['unitPrice']!,
            textAlign: TextAlign.right,
          ),
          _buildDataCell(
            NumberFormat('#,##0.00').format(item.totalPrice),
            _columnWidths['total']!,
            textAlign: TextAlign.right,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTotalsRow() {
    double grandTotal = 0;
    int totalQuantity = 0;

    for (final sale in _filteredSales) {
      for (final item in sale.items) {
        grandTotal += item.totalPrice;
        totalQuantity += item.quantity.toInt();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          _buildTotalCell(
            'TOTALS',
            _columnWidths['date']! +
                _columnWidths['receipt']! +
                _columnWidths['memberNumber']! +
                _columnWidths['member']! +
                _columnWidths['item']!,
            isBold: true,
          ),
          _buildTotalCell(
            totalQuantity.toString(),
            _columnWidths['quantity']!,
            textAlign: TextAlign.right,
            isBold: true,
          ),
          _buildTotalCell('', _columnWidths['unitPrice']!),
          _buildTotalCell(
            NumberFormat('#,##0.00').format(grandTotal),
            _columnWidths['total']!,
            textAlign: TextAlign.right,
            isBold: true,
            textColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSaleRow(Sale sale) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(
            DateFormat('MMM dd, yyyy').format(sale.saleDate),
            _columnWidths['date']!,
          ),
          _buildDataCell(
            sale.receiptNumber ?? 'N/A',
            _columnWidths['receipt']!,
          ),
          _buildDataCell(
            sale.memberNumber ?? 'N/A',
            _columnWidths['memberNumber']!,
          ),
          _buildDataCell(
            sale.memberName ?? 'Walk-in',
            _columnWidths['member']!,
          ),
          _buildDataCell(
            sale.saleType,
            _columnWidths['type']!,
            textColor: sale.saleType == 'CASH' ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
          _buildDataCell(
            sale.items.length.toString(),
            _columnWidths['items']!,
            textAlign: TextAlign.center,
          ),
          _buildDataCell(
            NumberFormat('#,##0.00').format(sale.totalAmount),
            _columnWidths['amount']!,
            textAlign: TextAlign.right,
          ),
          _buildDataCell(
            NumberFormat('#,##0.00').format(sale.paidAmount),
            _columnWidths['paid']!,
            textAlign: TextAlign.right,
            textColor: Colors.green,
          ),
          _buildDataCell(
            NumberFormat('#,##0.00').format(sale.balanceAmount),
            _columnWidths['balance']!,
            textAlign: TextAlign.right,
            textColor: sale.balanceAmount > 0 ? Colors.red : Colors.green,
            fontWeight: sale.balanceAmount > 0 ? FontWeight.bold : null,
          ),
          SizedBox(
            width: _columnWidths['actions']!,
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
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    TextAlign textAlign = TextAlign.left,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: fontWeight,
          ),
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildTotalsRow() {
    double totalAmount = 0;
    double totalPaid = 0;
    double totalBalance = 0;

    for (final sale in _filteredSales) {
      totalAmount += sale.totalAmount;
      totalPaid += sale.paidAmount;
      totalBalance += sale.balanceAmount;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          _buildTotalCell(
            'TOTALS',
            _columnWidths['date']! +
                _columnWidths['receipt']! +
                _columnWidths['memberNumber']! +
                _columnWidths['member']! +
                _columnWidths['type']! +
                _columnWidths['items']!,
            isBold: true,
          ),
          _buildTotalCell(
            NumberFormat('#,##0.00').format(totalAmount),
            _columnWidths['amount']!,
            textAlign: TextAlign.right,
            isBold: true,
          ),
          _buildTotalCell(
            NumberFormat('#,##0.00').format(totalPaid),
            _columnWidths['paid']!,
            textAlign: TextAlign.right,
            isBold: true,
            textColor: Colors.green,
          ),
          _buildTotalCell(
            NumberFormat('#,##0.00').format(totalBalance),
            _columnWidths['balance']!,
            textAlign: TextAlign.right,
            isBold: true,
            textColor: totalBalance > 0 ? Colors.red : Colors.green,
          ),
          _buildTotalCell('', _columnWidths['actions']!),
        ],
      ),
    );
  }

  Widget _buildTotalCell(
    String text,
    double width, {
    TextAlign textAlign = TextAlign.left,
    bool isBold = false,
    Color? textColor,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadSalesData();
    }
  }
}
