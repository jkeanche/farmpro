import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_constants.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/custom_app_bar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Controllers
  final CoffeeCollectionController _coffeeCollectionController =
      Get.find<CoffeeCollectionController>();
  final MemberController _memberController = Get.find<MemberController>();

  // Collections data
  List<CoffeeCollection> _allCollections = [];
  List<CoffeeCollection> _filteredCollections = [];
  List<CoffeeCollection> _displayedCollections = [];

  // Date filtering
  DateTime? _startDate; // Make optional
  DateTime? _endDate; // Make optional

  // Report view filtering
  String _reportView = 'cumulative'; // cumulative or individual
  String? _selectedMemberId; // Required only for individual view

  // Cumulative data
  List<Map<String, dynamic>> _cumulativeData = [];

  // Real-time updates
  bool _autoRefreshEnabled = true;
  Worker? _collectionsWorker;
  Timer? _refreshTimer;

  // Pagination for performance
  static const int _itemsPerPage = 50;
  int _currentPage = 0;
  bool _hasMoreData = false;

  // Scroll controllers for Excel-like table
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();

  // Table configuration
  static const double _rowHeight = 60.0;
  static const double _headerHeight = 50.0;

  // Dynamic column widths based on screen size
  Map<String, double> get _columnWidths {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return {
      'date': isSmallScreen ? 120.0 : 140.0,
      'member': isSmallScreen ? 140.0 : 160.0,
      'receipt': isSmallScreen ? 100.0 : 120.0,
      'season': isSmallScreen ? 80.0 : 100.0,
      'product': isSmallScreen ? 100.0 : 120.0,
      'gross': isSmallScreen ? 80.0 : 100.0,
      'tare': isSmallScreen ? 80.0 : 100.0,
      'net': isSmallScreen ? 80.0 : 100.0,
      'bags': isSmallScreen ? 60.0 : 80.0,
      'served': isSmallScreen ? 100.0 : 120.0,
    };
  }

  // Get total table width
  double get _totalTableWidth => _columnWidths.values.reduce((a, b) => a + b);

  // Cache calculated values to avoid recomputation
  double _cachedTotalWeight = 0.0;
  int _cachedTotalBags = 0;
  int _cachedMembersCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize collections data
    _initializeCollections();

    // Set up real-time updates
    _setupRealTimeUpdates();

    // Sync horizontal scrolling between header and data
    _setupScrollSync();
  }

  @override
  void dispose() {
    _collectionsWorker?.dispose();
    _refreshTimer?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  void _initializeCollections() {
    _allCollections = _coffeeCollectionController.collections;
    _filterCollections();
  }

  void _setupRealTimeUpdates() {
    // Listen to collections changes for real-time updates with debouncing
    _collectionsWorker = ever(_coffeeCollectionController.reactiveCollections, (
      _,
    ) {
      if (_autoRefreshEnabled) {
        // Debounce updates to prevent excessive rebuilds
        Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _allCollections = _coffeeCollectionController.collections;
            _filterCollections();
          }
        });
      }
    });

    // Set up periodic refresh every 10 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_autoRefreshEnabled && mounted) {
        _coffeeCollectionController.refreshCollections();
      }
    });
  }

  void _setupScrollSync() {
    // Sync horizontal scrolling between header and data table
    _horizontalScrollController.addListener(() {
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_horizontalScrollController.offset);
      }
    });
  }

  void _filterCollections() {
    // Filter collections in background to avoid blocking UI
    Future.microtask(() {
      var filtered = _allCollections.where((collection) {
        // Apply date filter only if both start and end dates are specified
        if (_startDate != null && _endDate != null) {
          final collectionDate = collection.collectionDate;
          final startOfDay = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );
          final endOfDay = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
          );

          return collectionDate.isAfter(startOfDay) &&
              collectionDate.isBefore(endOfDay);
        }

        // If no date filter is applied, include all collections
        return true;
      }).toList();

      // Apply member filter for individual view
      if (_reportView == 'individual' && _selectedMemberId != null) {
        filtered = filtered
            .where((collection) => collection.memberId == _selectedMemberId)
            .toList();
      }

      // Sort by date (newest first)
      filtered.sort((a, b) => b.collectionDate.compareTo(a.collectionDate));

      if (mounted) {
        setState(() {
          _filteredCollections = filtered;
          _currentPage = 0;

          if (_reportView == 'cumulative') {
            _prepareCumulativeData();
          } else {
            _updateDisplayedCollections();
          }

          _updateCachedCalculations();
        });
      }
    });
  }

  void _updateDisplayedCollections() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = math.min(
      startIndex + _itemsPerPage,
      _filteredCollections.length,
    );

    _displayedCollections = _filteredCollections.sublist(startIndex, endIndex);
    _hasMoreData = endIndex < _filteredCollections.length;
  }

  void _loadMoreData() {
    if (_hasMoreData) {
      setState(() {
        _currentPage++;
        _updateDisplayedCollections();
      });
    }
  }

  void _updateCachedCalculations() {
    _cachedTotalWeight = _filteredCollections.fold(
      0.0,
      (sum, collection) => sum + collection.netWeight,
    );
    _cachedTotalBags = _filteredCollections.fold<int>(
      0,
      (sum, c) => sum + c.numberOfBags,
    );
    _cachedMembersCount = _filteredCollections
        .map((c) => c.memberId)
        .toSet()
        .length;
  }

  void _prepareCumulativeData() {
    // Build a quick lookup map for members to avoid costly firstWhere searches
    final Map<String, Member> memberLookup = {
      for (final m in _memberController.members) m.id.toString(): m,
    };
    final Map<String, Map<String, dynamic>> memberAggregation = {};

    // Group collections by member
    for (final collection in _filteredCollections) {
      if (!memberAggregation.containsKey(collection.memberId)) {
        // Get member details
        final member = memberLookup[collection.memberId];

        memberAggregation[collection.memberId] = {
          'memberId': collection.memberId,
          'memberNumber': collection.memberNumber,
          'memberName': member?.fullName ?? 'Unknown',
          'phone': member?.phoneNumber ?? 'N/A',
          'totalWeight': 0.0,
          'totalBags': 0,
          'collectionsCount': 0,
          'coffeeTypes': <String>{},
          'seasons': <String>{},
          'collections': <CoffeeCollection>[],
          'lastCollectionDate': null,
        };
      }

      final memberData = memberAggregation[collection.memberId]!;
      memberData['totalWeight'] += collection.netWeight;
      memberData['totalBags'] += collection.numberOfBags;
      memberData['collectionsCount'] += 1;
      memberData['coffeeTypes'].add(collection.productType);
      memberData['seasons'].add(collection.seasonName);
      memberData['collections'].add(collection);

      // Update last collection date
      final lastDate = memberData['lastCollectionDate'] as DateTime?;
      if (lastDate == null || collection.collectionDate.isAfter(lastDate)) {
        memberData['lastCollectionDate'] = collection.collectionDate;
      }
    }

    // Convert to list and format
    _cumulativeData = memberAggregation.values.map((data) {
      return {
        'memberId': data['memberId'].toString(),
        'memberNumber': data['memberNumber'],
        'memberName': data['memberName'],
        'phone': data['phone'],
        'collectionsCount': data['collectionsCount'],
        'totalWeight': data['totalWeight'],
        'totalBags': data['totalBags'],
        'coffeeTypes': (data['coffeeTypes'] as Set<String>).join(', '),
        'seasons': (data['seasons'] as Set<String>).join(', '),
        'collections': data['collections'],
        'lastCollectionDate': data['lastCollectionDate'] as DateTime?,
      };
    }).toList();

    // Sort by total weight (highest first)
    _cumulativeData.sort(
      (a, b) =>
          (b['totalWeight'] as double).compareTo(a['totalWeight'] as double),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Date Range for Collections',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterCollections();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _filterCollections();
  }

  // Format date helper method
  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  // Export functionality with member aggregation
  Future<void> _exportReport() async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Export ${_reportView == 'cumulative' ? 'Cumulative' : 'Individual'} Report',
          ),
          content: Text(
            'Choose export format for ${_reportView == 'cumulative' ? 'cumulative member summary' : 'individual collection records'}:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('csv'),
              child: const Text('CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('excel'),
              child: const Text('Excel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (choice == null) return;

      // Show loading dialog
      Get.dialog(
        AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('Generating $_reportView ${choice.toUpperCase()} report...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      if (choice == 'excel') {
        await _exportToExcel();
      } else {
        await _exportToCSV();
      }

      Get.back(); // Close loading dialog

      Get.snackbar(
        'Export Complete',
        'Report exported successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Export Error',
        'Failed to export report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Collections Report'];

    // Remove default sheet
    excel.delete('Sheet1');

    if (_reportView == 'cumulative') {
      // Export cumulative view
      await _exportCumulativeToExcel(excel, sheet);
    } else {
      // Export individual collections view
      await _exportIndividualToExcel(excel, sheet);
    }

    // Save and share file
    final bytes = excel.encode()!;
    final fileName =
        'Collections_${_reportView}_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    await _saveAndShareFile(bytes, fileName);
  }

  Future<void> _exportCumulativeToExcel(Excel excel, Sheet sheet) async {
    // Add headers
    final headers = [
      'M/No',
      'Name',
      'Phone',
      'Collections Count',
      'Total Weight (kg)',
      'Total Bags',
      'Coffee Types',
      'Seasons',
      'Last Collection',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
    }

    // Add data rows
    int rowIndex = 1;
    for (final data in _cumulativeData) {
      final values = [
        data['memberNumber'],
        data['memberName'],
        data['phone'],
        data['collectionsCount'],
        (data['totalWeight'] as double).toStringAsFixed(2),
        data['totalBags'],
        data['coffeeTypes'],
        data['seasons'],
        data['lastCollectionDate'] != null
            ? DateFormat(
                'MMM dd, yyyy HH:mm',
              ).format(data['lastCollectionDate'] as DateTime)
            : 'N/A',
      ];

      for (int i = 0; i < values.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
        );
        cell.value = TextCellValue(values[i].toString());
      }
      rowIndex++;
    }

    // Auto-resize columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }

    // Add summary at the bottom
    final summaryRowIndex = rowIndex + 2;
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      'SUMMARY',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 1,
          ),
        )
        .value = TextCellValue(
      'Total Members:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 1,
          ),
        )
        .value = IntCellValue(
      _cumulativeData.length,
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 2,
          ),
        )
        .value = TextCellValue(
      'Total Weight:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 2,
          ),
        )
        .value = TextCellValue(
      '${_cachedTotalWeight.toStringAsFixed(2)} kg',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 3,
          ),
        )
        .value = TextCellValue(
      'Date Range:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 3,
          ),
        )
        .value = TextCellValue(
      _getDateRangeText(),
    );
  }

  Future<void> _exportIndividualToExcel(Excel excel, Sheet sheet) async {
    // Add headers
    final headers = [
      'Date',
      'Member',
      'Member #',
      'Receipt #',
      'Season',
      'Product',
      'Gross Weight (kg)',
      'Tare Weight (kg)',
      'Net Weight (kg)',
      'Bags',
      'Served By',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
    }

    // Add data rows
    int rowIndex = 1;
    // Build member lookup for quick name resolution
    final Map<String, Member> memberLookup = {
      for (final m in _memberController.members) m.id.toString(): m,
    };
    for (final collection in _filteredCollections) {
      final member = memberLookup[collection.memberId];

      final values = [
        DateFormat('MMM dd, yyyy HH:mm').format(collection.collectionDate),
        member?.fullName ?? 'Unknown',
        collection.memberNumber,
        collection.receiptNumber ?? 'N/A',
        collection.seasonName,
        collection.productType,
        collection.grossWeight.toStringAsFixed(2),
        collection.tareWeight.toStringAsFixed(2),
        collection.netWeight.toStringAsFixed(2),
        collection.numberOfBags,
        collection.userName ?? 'Unknown',
      ];

      for (int i = 0; i < values.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
        );
        cell.value = TextCellValue(values[i].toString());
      }
      rowIndex++;
    }

    // Auto-resize columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }

    // Add summary at the bottom
    final summaryRowIndex = rowIndex + 2;
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      'SUMMARY',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 1,
          ),
        )
        .value = TextCellValue(
      'Total Collections:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 1,
          ),
        )
        .value = IntCellValue(
      _filteredCollections.length,
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 2,
          ),
        )
        .value = TextCellValue(
      'Total Weight:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 2,
          ),
        )
        .value = TextCellValue(
      '${_cachedTotalWeight.toStringAsFixed(2)} kg',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 3,
          ),
        )
        .value = TextCellValue(
      'Date Range:',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: summaryRowIndex + 3,
          ),
        )
        .value = TextCellValue(
      _getDateRangeText(),
    );
  }

  Future<void> _exportToCSV() async {
    List<List<dynamic>> csvData = [];

    if (_reportView == 'cumulative') {
      // Export cumulative view
      csvData = [
        [
          'M/No',
          'Name',
          'Phone',
          'Collections Count',
          'Total Weight (kg)',
          'Total Bags',
          'Coffee Types',
          'Seasons',
          'Last Collection',
        ], // Headers
      ];

      // Add data rows
      for (final data in _cumulativeData) {
        csvData.add([
          data['memberNumber'],
          data['memberName'],
          data['phone'],
          data['collectionsCount'],
          (data['totalWeight'] as double).toStringAsFixed(2),
          data['totalBags'],
          data['coffeeTypes'],
          data['seasons'],
          data['lastCollectionDate'] != null
              ? DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(data['lastCollectionDate'] as DateTime)
              : 'N/A',
        ]);
      }

      // Add summary
      csvData.addAll([
        [], // Empty row
        ['SUMMARY'],
        ['Total Members:', _cumulativeData.length],
        ['Total Weight:', '${_cachedTotalWeight.toStringAsFixed(2)} kg'],
        ['Date Range:', _getDateRangeText()],
      ]);
    } else {
      // Export individual collections view
      csvData = [
        [
          'Date',
          'Member',
          'Member #',
          'Receipt #',
          'Season',
          'Product',
          'Gross Weight (kg)',
          'Tare Weight (kg)',
          'Net Weight (kg)',
          'Bags',
          'Served By',
        ], // Headers
      ];

      // Add data rows
      final Map<String, Member> memberLookup = {
        for (final m in _memberController.members) m.id.toString(): m,
      };
      for (final collection in _filteredCollections) {
        final member = memberLookup[collection.memberId];

        csvData.add([
          DateFormat('MMM dd, yyyy HH:mm').format(collection.collectionDate),
          member?.fullName ?? 'Unknown',
          collection.memberNumber,
          collection.receiptNumber ?? 'N/A',
          collection.seasonName,
          collection.productType,
          collection.grossWeight.toStringAsFixed(2),
          collection.tareWeight.toStringAsFixed(2),
          collection.netWeight.toStringAsFixed(2),
          collection.numberOfBags,
          collection.userName ?? 'Unknown',
        ]);
      }

      // Add summary
      csvData.addAll([
        [], // Empty row
        ['SUMMARY'],
        ['Total Collections:', _filteredCollections.length],
        ['Total Weight:', '${_cachedTotalWeight.toStringAsFixed(2)} kg'],
        ['Date Range:', _getDateRangeText()],
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = csvString.codeUnits;
    final fileName =
        'Collections_${_reportView}_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    await _saveAndShareFile(bytes, fileName);
  }

  // Export collections in import template format and clear data
  Future<void> _exportAndClearCollections() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Collection Data'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Export all collections to CSV (import format)'),
              Text('2. Save the file to Downloads'),
              Text('3. Delete ALL collection records'),
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
                'The exported CSV can be used to re-import the data if needed.',
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

      // Show loading dialog
      Get.dialog(
        const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exporting and clearing data...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Export collections in import template format
      await _exportCollectionsForImport();

      // Clear all collections
      final coffeeCollectionService = Get.find<CoffeeCollectionService>();
      final result = await coffeeCollectionService.deleteAllCollections();

      Get.back(); // Close loading dialog

      if (result['success']) {
        Get.snackbar(
          'Success',
          '${result['deletedCount']} collection(s) deleted. CSV saved to Downloads.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // Refresh the data
        await _coffeeCollectionController.refreshCollections();
      } else {
        Get.snackbar(
          'Error',
          'Failed to clear data: ${result['error']}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back(); // Close loading dialog if still open
      Get.snackbar(
        'Error',
        'Failed to export and clear data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Export collections in the import template format
  Future<void> _exportCollectionsForImport() async {
    // CSV format matching import template:
    // Date, Member #, Member Name, Season, Product, Gross Weight, Tare Weight, Net Weight, Bags, Served By
    List<List<dynamic>> csvData = [
      [
        'Date',
        'Member #',
        'Member Name',
        'Season',
        'Product',
        'Gross Weight (kg)',
        'Tare Weight (kg)',
        'Net Weight (kg)',
        'Bags',
        'Served By',
      ],
    ];

    // Build member lookup for quick name resolution
    final Map<String, Member> memberLookup = {
      for (final m in _memberController.members) m.id.toString(): m,
    };

    // Add all collections (not just filtered ones for complete backup)
    for (final collection in _allCollections) {
      final member = memberLookup[collection.memberId];

      csvData.add([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(collection.collectionDate),
        collection.memberNumber,
        member?.fullName ?? 'Unknown',
        collection.seasonName,
        collection.productType,
        collection.grossWeight.toStringAsFixed(2),
        collection.tareWeight.toStringAsFixed(2),
        collection.netWeight.toStringAsFixed(2),
        collection.numberOfBags,
        collection.userName ?? 'Unknown',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = csvString.codeUnits;
    final fileName =
        'Collections_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

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

  Future<void> _saveAndShareFile(List<int> bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Collections Report - Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
    );
  }

  String _getDateRangeText() {
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }
    return 'All Collections (No Date Filter)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Collections Report',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _coffeeCollectionController.refreshCollections(),
            tooltip: 'Refresh Collections',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed:
                (_reportView == 'cumulative'
                    ? _cumulativeData.isNotEmpty
                    : _filteredCollections.isNotEmpty)
                ? _exportReport
                : null,
            tooltip:
                'Export ${_reportView == 'cumulative' ? 'Cumulative' : 'Individual'} Report',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Report Options',
            onSelected: (value) {
              if (value == 'crop_search') {
                Get.toNamed(AppConstants.cropSearchRoute);
              } else if (value == 'clear_data') {
                _exportAndClearCollections();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'crop_search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 12),
                    Text('Search by Crop'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Date Range Filter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Date Range Filter
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Date Range:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: InkWell(
                          onTap: _selectDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _startDate != null && _endDate != null
                                        ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                        : 'All Collections (No Date Filter)',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_startDate != null && _endDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: _clearDateFilter,
                          tooltip: 'Clear Date Filter',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Auto-refresh toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _autoRefreshEnabled = !_autoRefreshEnabled;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _autoRefreshEnabled ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _autoRefreshEnabled ? 'AUTO' : 'OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Report View toggle
                  Row(
                    children: [
                      const Icon(Icons.view_list, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'View:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            _buildViewToggleButton('cumulative', 'Cumulative'),
                            _buildViewToggleButton('individual', 'Single'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Member dropdown (only when individual view)
                  if (_reportView == 'individual')
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMemberId,
                        decoration: const InputDecoration(
                          labelText: 'Member',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All'),
                          ),
                          ..._memberController.members.map(
                            (m) => DropdownMenuItem(
                              value: m.id.toString(),
                              child: Text(
                                '${m.memberNumber} - ${m.fullName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedMemberId = v);
                          _filterCollections();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Compact Summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _reportView == 'cumulative'
                        ? 'Members: ${_cumulativeData.length} • Weight: ${_cachedTotalWeight.toStringAsFixed(1)} kg • Bags: $_cachedTotalBags • Collections: ${_filteredCollections.length}'
                        : 'Collections: ${_filteredCollections.length} • Weight: ${_cachedTotalWeight.toStringAsFixed(1)} kg • Bags: $_cachedTotalBags • Members: $_cachedMembersCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Report Table
          Expanded(
            child: _reportView == 'cumulative'
                ? _buildCumulativeTable()
                : _buildIndividualTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, double width) {
    return Container(
      width: width,
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  // Cumulative table view
  Widget _buildCumulativeTable() {
    if (_cumulativeData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No collections found for the selected period',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Column(
          children: [
            // Fixed header
            _buildCumulativeTableHeader(),

            // Scrollable data with horizontal sync (similar to individual view)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  // Sum of column widths defined in header below
                  const double tableWidth =
                      1000.0; // 200+100+120+100+120+100+140+120

                  return SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: maxWidth,
                        maxWidth: math.max(maxWidth, tableWidth),
                      ),
                      child: SizedBox(
                        width: tableWidth,
                        child: ListView.builder(
                          controller: _verticalScrollController,
                          itemCount: _cumulativeData.length,
                          itemExtent: _rowHeight, // Fixed row height
                          cacheExtent: 200,
                          itemBuilder: (context, index) {
                            final data = _cumulativeData[index];
                            return _CumulativeTableRow(
                              key: ValueKey(data['memberId']),
                              data: data,
                              index: index,
                              onViewDetails: () {
                                setState(() {
                                  _reportView = 'individual';
                                  _selectedMemberId = data['memberId'];
                                });
                                _filterCollections();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Compact table footer
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      'TOTALS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_cachedTotalWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_cachedTotalBags bags',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Individual table view
  Widget _buildIndividualTable() {
    if (_filteredCollections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No collections found for the selected period',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Column(
          children: [
            // Fixed header
            _buildIndividualTableHeader(),

            // Scrollable data with constrained width
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final tableWidth = _totalTableWidth;

                  return SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: maxWidth,
                        maxWidth: math.max(maxWidth, tableWidth),
                      ),
                      child: SizedBox(
                        width: tableWidth,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            // Load more data when near bottom
                            if (scrollInfo.metrics.pixels >=
                                scrollInfo.metrics.maxScrollExtent - 200) {
                              _loadMoreData();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _verticalScrollController,
                            itemCount:
                                _displayedCollections.length +
                                (_hasMoreData ? 1 : 0),
                            itemExtent:
                                _rowHeight, // Fixed height for better performance
                            cacheExtent: 200, // Cache fewer items
                            itemBuilder: (context, index) {
                              if (index >= _displayedCollections.length) {
                                // Loading indicator at bottom
                                return Container(
                                  height: _rowHeight,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                );
                              }
                              final collection = _displayedCollections[index];
                              return _OptimizedCollectionRow(
                                key: ValueKey(collection.id),
                                collection: collection,
                                index: index,
                                columnWidths: _columnWidths,
                                rowHeight: _rowHeight,
                                memberController: _memberController,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Compact table footer
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      'TOTALS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_cachedTotalWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_cachedTotalBags bags',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cumulative table header
  Widget _buildCumulativeTableHeader() {
    const double tableWidth = 1000.0; // Keep in sync with body widths
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: SingleChildScrollView(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(), // Synced externally
        child: SizedBox(
          width: tableWidth,
          child: Row(
            children: [
              _buildHeaderCell('Member Name', 200),
              _buildHeaderCell('Member #', 100),
              _buildHeaderCell('Phone', 120),
              _buildHeaderCell('Collections', 100),
              _buildHeaderCell('Total Weight (kg)', 120),
              _buildHeaderCell('Total Bags', 100),
              _buildHeaderCell('Last Collection', 140),
              _buildHeaderCell('Actions', 120),
            ],
          ),
        ),
      ),
    );
  }

  // Individual table header
  Widget _buildIndividualTableHeader() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: SingleChildScrollView(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        physics:
            const NeverScrollableScrollPhysics(), // Controlled by data scroll
        child: SizedBox(
          width: _totalTableWidth,
          child: Row(
            children: [
              _buildHeaderCell('Date', _columnWidths['date']!),
              _buildHeaderCell('Member', _columnWidths['member']!),
              _buildHeaderCell('Receipt #', _columnWidths['receipt']!),
              _buildHeaderCell('Season', _columnWidths['season']!),
              _buildHeaderCell('Product', _columnWidths['product']!),
              _buildHeaderCell('Gross (kg)', _columnWidths['gross']!),
              _buildHeaderCell('Tare (kg)', _columnWidths['tare']!),
              _buildHeaderCell('Net (kg)', _columnWidths['net']!),
              _buildHeaderCell('Bags', _columnWidths['bags']!),
              _buildHeaderCell('Served By', _columnWidths['served']!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(String value, String label) {
    return InkWell(
      onTap: () {
        setState(() {
          _reportView = value;
          if (value == 'cumulative') _selectedMemberId = null;
        });
        _filterCollections();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _reportView == value ? Colors.blue : Colors.transparent,
          borderRadius: value == 'cumulative'
              ? const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                )
              : const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _reportView == value ? Colors.white : Colors.black,
            fontWeight: _reportView == value
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// Optimized table row widget for better performance
class _OptimizedCollectionRow extends StatelessWidget {
  final CoffeeCollection collection;
  final int index;
  final Map<String, double> columnWidths;
  final double rowHeight;
  final MemberController memberController;

  const _OptimizedCollectionRow({
    super.key,
    required this.collection,
    required this.index,
    required this.columnWidths,
    required this.rowHeight,
    required this.memberController,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;

    // Get member name
    final member = memberController.members.firstWhereOrNull(
      (m) => m.id == collection.memberId,
    );

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(
            DateFormat('MMM dd\nHH:mm').format(collection.collectionDate),
            columnWidths['date']!,
          ),
          _buildDataCell(
            member?.fullName ?? 'Unknown',
            columnWidths['member']!,
          ),
          _buildDataCell(
            collection.receiptNumber ?? 'N/A',
            columnWidths['receipt']!,
          ),
          _buildDataCell(collection.seasonName, columnWidths['season']!),
          _buildDataCell(collection.productType, columnWidths['product']!),
          _buildDataCell(
            collection.grossWeight.toStringAsFixed(2),
            columnWidths['gross']!,
            alignment: Alignment.centerRight,
          ),
          _buildDataCell(
            collection.tareWeight.toStringAsFixed(2),
            columnWidths['tare']!,
            alignment: Alignment.centerRight,
          ),
          _buildDataCell(
            collection.netWeight.toStringAsFixed(2),
            columnWidths['net']!,
            alignment: Alignment.centerRight,
            fontWeight: FontWeight.bold,
          ),
          _buildDataCell(
            collection.numberOfBags.toString(),
            columnWidths['bags']!,
            alignment: Alignment.center,
          ),
          _buildDataCell(
            collection.userName ?? 'Unknown',
            columnWidths['served']!,
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    Alignment alignment = Alignment.centerLeft,
    FontWeight? fontWeight,
    Color? textColor,
  }) {
    return Container(
      width: width,
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: fontWeight,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          textAlign: alignment == Alignment.centerRight
              ? TextAlign.right
              : alignment == Alignment.center
              ? TextAlign.center
              : TextAlign.left,
        ),
      ),
    );
  }
}

// Cumulative table row widget
class _CumulativeTableRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final VoidCallback onViewDetails;

  const _CumulativeTableRow({
    super.key,
    required this.data,
    required this.index,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;

    return Container(
      height: 60.0,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(data['memberName'].toString(), 200),
          _buildDataCell(data['memberNumber'].toString(), 100),
          _buildDataCell(data['phone'].toString(), 120),
          _buildDataCell(
            data['collectionsCount'].toString(),
            100,
            alignment: Alignment.center,
          ),
          _buildDataCell(
            (data['totalWeight'] as double).toStringAsFixed(2),
            120,
            alignment: Alignment.centerRight,
            fontWeight: FontWeight.bold,
            textColor: Colors.green,
          ),
          _buildDataCell(
            data['totalBags'].toString(),
            100,
            alignment: Alignment.center,
            fontWeight: FontWeight.bold,
            textColor: Colors.orange,
          ),
          _buildDataCell(
            data['lastCollectionDate'] != null
                ? DateFormat(
                    'MMM dd\nHH:mm',
                  ).format(data['lastCollectionDate'] as DateTime)
                : 'N/A',
            140,
          ),
          _buildActionsCell(120),
        ],
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    Alignment alignment = Alignment.centerLeft,
    FontWeight? fontWeight,
    Color? textColor,
  }) {
    return Container(
      width: width,
      height: 60.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: fontWeight,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          textAlign: alignment == Alignment.centerRight
              ? TextAlign.right
              : alignment == Alignment.center
              ? TextAlign.center
              : TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildActionsCell(double width) {
    return Container(
      width: width,
      height: 60.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility, size: 16),
            onPressed: onViewDetails,
            tooltip: 'View Details',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
