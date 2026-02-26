import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';
import '../../widgets/custom_app_bar.dart';
// import '../../dialogs/edit_collection_dialog.dart'; // Commented out - edit functionality disabled

class MemberCollectionReportScreen extends StatefulWidget {
  final Member? initialMember;

  const MemberCollectionReportScreen({super.key, this.initialMember});

  @override
  State<MemberCollectionReportScreen> createState() =>
      _MemberCollectionReportScreenState();
}

// Data model for cumulative view
class _MemberCumulativeData {
  final Member member;
  final int totalCollections;
  final double totalWeight;
  final int totalBags;
  final DateTime? lastCollectionDate;
  final List<CoffeeCollection> collections;

  _MemberCumulativeData({
    required this.member,
    required this.totalCollections,
    required this.totalWeight,
    required this.totalBags,
    this.lastCollectionDate,
    required this.collections,
  });
}

class _MemberCollectionReportScreenState
    extends State<MemberCollectionReportScreen> {
  final MemberController _memberController = Get.find<MemberController>();
  final CoffeeCollectionController _coffeeCollectionController =
      Get.find<CoffeeCollectionController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  // final SmsService _smsService = Get.find<SmsService>();

  // Scroll controllers for Excel-like functionality
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();

  Member? _selectedMember;
  List<CoffeeCollection> _filteredCollections = [];
  List<CoffeeCollection> _displayedCollections = [];
  List<_MemberCumulativeData> _cumulativeData = []; // For cumulative view
  List<_MemberCumulativeData> _displayedCumulativeData =
      []; // For cumulative view pagination
  DateTime? _startDate; // Make optional
  DateTime? _endDate; // Make optional
  bool _autoRefreshEnabled = true;

  // Report view filter - new addition
  bool _showIndividualCollections =
      false; // false = cumulative (default), true = individual

  // Pagination for better performance
  static const int _itemsPerPage = 50;
  int _currentPage = 0;
  bool _hasMoreData = false;

  // Real-time update workers
  Worker? _collectionsWorker;
  Timer? _refreshTimer;

  // Excel-like table configuration with responsive widths
  static const double _rowHeight = 60.0;
  static const double _headerHeight = 50.0;

  // Dynamic column widths based on screen size and view type
  Map<String, double> get _columnWidths {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    if (_showIndividualCollections) {
      // Individual collections view (current structure)
      return {
        'date': isSmallScreen ? 110.0 : 140.0,
        'receipt': isSmallScreen ? 100.0 : 120.0,
        'season': isSmallScreen ? 80.0 : 100.0,
        'product': isSmallScreen ? 100.0 : 120.0,
        'gross': isSmallScreen ? 80.0 : 100.0,
        'tare': isSmallScreen ? 80.0 : 100.0,
        'net': isSmallScreen ? 80.0 : 100.0,
        'bags': isSmallScreen ? 60.0 : 80.0,
        'served': isSmallScreen ? 100.0 : 120.0,
        'actions': isSmallScreen ? 120.0 : 150.0,
      };
    } else {
      // Cumulative view
      return {
        'member': isSmallScreen ? 150.0 : 200.0,
        'memberNumber': isSmallScreen ? 100.0 : 120.0,
        'phone': isSmallScreen ? 120.0 : 140.0,
        'totalCollections': isSmallScreen ? 100.0 : 120.0,
        'totalWeight': isSmallScreen ? 100.0 : 120.0,
        'totalBags': isSmallScreen ? 80.0 : 100.0,
        'lastCollection': isSmallScreen ? 110.0 : 140.0,
        'actions': isSmallScreen ? 120.0 : 150.0,
      };
    }
  }

  // Get total table width
  double get _totalTableWidth => _columnWidths.values.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();

    // Get member from arguments if available
    if (Get.arguments != null && Get.arguments is Member) {
      _selectedMember = Get.arguments as Member;
      _filterCollections();
    }

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

  void _setupRealTimeUpdates() {
    if (_autoRefreshEnabled) {
      // Listen to collections changes
      _collectionsWorker = ever(_coffeeCollectionController.collections.obs, (
        _,
      ) {
        if (mounted && _autoRefreshEnabled) {
          print('Collections updated - refreshing report');
          _filterCollections();
        }
      });

      // Also set up a timer for periodic refresh to catch any missed updates
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && _autoRefreshEnabled) {
          _filterCollections();
        }
      });
    }
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
    if (_showIndividualCollections) {
      _filterIndividualCollections();
    } else {
      _prepareCumulativeData();
    }
  }

  void _filterIndividualCollections() {
    if (_selectedMember == null) {
      setState(() {
        _filteredCollections = [];
        _displayedCollections = [];
        _currentPage = 0;
        _hasMoreData = false;
      });
      return;
    }

    final allCollections = _coffeeCollectionController.collections;

    // Filter collections in background to avoid blocking UI
    Future.microtask(() {
      final filtered =
          allCollections.where((collection) {
            // Filter by member
            if (collection.memberId != _selectedMember!.id) {
              return false;
            }

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

            // If no date filter is applied, include all collections for this member
            return true;
          }).toList();

      // Sort by date (newest first)
      filtered.sort((a, b) => b.collectionDate.compareTo(a.collectionDate));

      if (mounted) {
        setState(() {
          _filteredCollections = filtered;
          _currentPage = 0;
          _updateDisplayedCollections();
          _updateCachedCalculations();
        });
      }
    });
  }

  void _prepareCumulativeData() {
    final allCollections = _coffeeCollectionController.collections;
    final allMembers = _memberController.members;

    // Group collections by member and calculate cumulative data
    Future.microtask(() {
      final Map<String, List<CoffeeCollection>> memberCollections = {};

      // Filter collections by date if specified
      final filteredCollections = allCollections.where((collection) {
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
        return true;
      });

      // Group filtered collections by member
      for (final collection in filteredCollections) {
        if (!memberCollections.containsKey(collection.memberId)) {
          memberCollections[collection.memberId] = [];
        }
        memberCollections[collection.memberId]!.add(collection);
      }

      // Create cumulative data for each member with collections
      final cumulativeData = <_MemberCumulativeData>[];

      for (final entry in memberCollections.entries) {
        final memberId = entry.key;
        final collections = entry.value;

        // Find the member
        final member = allMembers.firstWhereOrNull((m) => m.id == memberId);
        if (member == null) continue;

        // Calculate totals
        final totalWeight = collections.fold<double>(
          0.0,
          (sum, c) => sum + c.netWeight,
        );
        final totalBags = collections.fold<int>(
          0,
          (sum, c) => sum + c.numberOfBags,
        );
        final lastCollection =
            collections.isNotEmpty
                ? collections.reduce(
                  (a, b) => a.collectionDate.isAfter(b.collectionDate) ? a : b,
                )
                : null;

        cumulativeData.add(
          _MemberCumulativeData(
            member: member,
            totalCollections: collections.length,
            totalWeight: totalWeight,
            totalBags: totalBags,
            lastCollectionDate: lastCollection?.collectionDate,
            collections: collections,
          ),
        );
      }

      // Sort by total weight (highest first)
      cumulativeData.sort((a, b) => b.totalWeight.compareTo(a.totalWeight));

      if (mounted) {
        setState(() {
          _cumulativeData = cumulativeData;
          _currentPage = 0;
          _updateDisplayedCumulativeData();
          _updateCumulativeCachedCalculations();
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

  void _updateDisplayedCumulativeData() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = math.min(
      startIndex + _itemsPerPage,
      _cumulativeData.length,
    );

    _displayedCumulativeData = _cumulativeData.sublist(startIndex, endIndex);
    _hasMoreData = endIndex < _cumulativeData.length;
  }

  void _loadMoreData() {
    if (_hasMoreData) {
      setState(() {
        _currentPage++;
        if (_showIndividualCollections) {
          _updateDisplayedCollections();
        } else {
          _updateDisplayedCumulativeData();
        }
      });
    }
  }

  Future<void> _selectMember() async {
    final members = _memberController.members;

    final selectedMember = await showDialog<Member>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Member'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    title: Text(member.fullName),
                    subtitle: Text('Member #: ${member.memberNumber}'),
                    onTap: () => Navigator.of(context).pop(member),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (selectedMember != null) {
      setState(() {
        _selectedMember = selectedMember;
      });
      _filterCollections();
    }
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
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
      _filterCollections();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  // Cache calculated values to avoid recomputation
  double _cachedTotalWeight = 0.0;
  int _cachedTotalBags = 0;

  void _updateCachedCalculations() {
    if (_showIndividualCollections) {
      _cachedTotalWeight = _filteredCollections.fold(
        0.0,
        (sum, collection) => sum + collection.netWeight,
      );
      _cachedTotalBags = _filteredCollections.fold<int>(
        0,
        (sum, c) => sum + c.numberOfBags,
      );
    } else {
      _cachedTotalWeight = _cumulativeData.fold(
        0.0,
        (sum, data) => sum + data.totalWeight,
      );
      _cachedTotalBags = _cumulativeData.fold<int>(
        0,
        (sum, data) => sum + data.totalBags,
      );
    }
  }

  // Cache calculated values to avoid recomputation

  void _updateCumulativeCachedCalculations() {
    _cachedTotalWeight = _cumulativeData.fold(
      0.0,
      (sum, data) => sum + data.totalWeight,
    );
    _cachedTotalBags = _cumulativeData.fold<int>(
      0,
      (sum, data) => sum + data.totalBags,
    );
    _updateCachedCalculations(); // Update main cache as well
  }

  Future<void> _exportCollectionsToExcel() async {
    try {
      if (_filteredCollections.isEmpty || _selectedMember == null) {
        Get.snackbar(
          'Error',
          'No data available to export',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      print('Exporting ${_filteredCollections.length} collections to Excel');

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Member Collections'];

      // Remove default sheet if it exists
      excel.delete('Sheet1');

      // Add header information
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'Coffee Collection Report for: ${_selectedMember!.fullName}',
      );
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Member Number: ${_selectedMember!.memberNumber}',
      );
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'ID Number: ${_selectedMember!.idNumber ?? 'N/A'}',
      );
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
        'Phone: ${_selectedMember!.phoneNumber ?? "N/A"}',
      );
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        _startDate != null && _endDate != null
            ? 'Date Range: ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}'
            : 'Date Range: All Collections (No Filter)',
      );
      sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue(
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
      );

      // Add header row
      final headers = [
        'Date',
        'Receipt Number',
        'Season',
        'Product Type',
        'Gross Weight (kg)',
        'Tare Weight (kg)',
        'Net Weight (kg)',
        'Number of Bags',
        'Served By',
      ];

      // Create header cells with column references
      final headerColumns = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
      for (var i = 0; i < headers.length; i++) {
        final cellRef = '${headerColumns[i]}8';
        sheet.cell(CellIndex.indexByString(cellRef)).value = TextCellValue(
          headers[i],
        );
      }

      // Add collection data
      var rowIndex = 9;
      double totalWeight = 0;

      for (final collection in _filteredCollections) {
        totalWeight += collection.netWeight;

        // Use explicit cell references
        sheet.cell(CellIndex.indexByString('A$rowIndex')).value = TextCellValue(
          DateFormat('yyyy-MM-dd HH:mm').format(collection.collectionDate),
        );
        sheet.cell(CellIndex.indexByString('B$rowIndex')).value = TextCellValue(
          collection.receiptNumber ?? 'N/A',
        );
        sheet.cell(CellIndex.indexByString('C$rowIndex')).value = TextCellValue(
          collection.seasonName,
        );
        sheet.cell(CellIndex.indexByString('D$rowIndex')).value = TextCellValue(
          collection.productType,
        );
        sheet
            .cell(CellIndex.indexByString('E$rowIndex'))
            .value = DoubleCellValue(collection.grossWeight);
        sheet
            .cell(CellIndex.indexByString('F$rowIndex'))
            .value = DoubleCellValue(collection.tareWeight);
        sheet
            .cell(CellIndex.indexByString('G$rowIndex'))
            .value = DoubleCellValue(collection.netWeight);
        sheet.cell(CellIndex.indexByString('H$rowIndex')).value = IntCellValue(
          collection.numberOfBags,
        );
        sheet.cell(CellIndex.indexByString('I$rowIndex')).value = TextCellValue(
          collection.userName ?? 'N/A',
        );

        rowIndex++;
      }

      // Add total row
      sheet.cell(CellIndex.indexByString('A$rowIndex')).value = TextCellValue(
        'TOTAL',
      );
      sheet.cell(CellIndex.indexByString('G$rowIndex')).value = DoubleCellValue(
        totalWeight,
      );

      // Save Excel file
      final directory = await getTemporaryDirectory();
      final memberName = _selectedMember!.fullName
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w\s-]'), '');
      final fileName =
          _startDate != null && _endDate != null
              ? 'coffee_collections_${memberName}_${DateFormat('yyyyMMdd').format(_startDate!)}_to_${DateFormat('yyyyMMdd').format(_endDate!)}.xlsx'
              : 'coffee_collections_${memberName}_all_collections.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      await file.writeAsBytes(excelBytes);

      print('Excel file written to: $filePath');
      print('File size: ${file.lengthSync()} bytes');

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            _startDate != null && _endDate != null
                ? 'Coffee Collection Report for ${_selectedMember!.fullName} (${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)})'
                : 'Coffee Collection Report for ${_selectedMember!.fullName} (All Collections)',
      );

      Get.snackbar(
        'Success',
        'Report exported successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error exporting to Excel: $e');
      Get.snackbar(
        'Error',
        'Failed to export report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _printCollectionReceipt(CoffeeCollection collection) async {
    try {
      final orgSettings = _settingsController.organizationSettings.value;
      final sysSettings = _settingsController.systemSettings.value;

      // Calculate all-time cumulative weight for this member (across all seasons)
      final memberSummary = await _coffeeCollectionController
          .getMemberSeasonSummary(collection.memberId);

      // Ensure we have a valid cumulative weight value with robust parsing
      double allTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = memberSummary['allTimeWeight'];
        print(
          '🔍 Report SMS Debug - Raw weight from DB: $rawWeight (${rawWeight.runtimeType}) for member ${collection.memberName}',
        );

        if (rawWeight != null) {
          // Handle different data types that might come from the database
          if (rawWeight is num) {
            allTimeCumulativeWeight = rawWeight.toDouble();
          } else if (rawWeight is String) {
            allTimeCumulativeWeight = double.tryParse(rawWeight) ?? 0.0;
          } else {
            // Try to convert to string first, then parse
            allTimeCumulativeWeight =
                double.tryParse(rawWeight.toString()) ?? 0.0;
          }
        }

        // Additional validation to ensure the weight is valid and not negative
        if (allTimeCumulativeWeight < 0 ||
            allTimeCumulativeWeight.isNaN ||
            allTimeCumulativeWeight.isInfinite) {
          print(
            '⚠️  Report SMS Debug - Invalid weight detected: $allTimeCumulativeWeight, setting to 0.0',
          );
          allTimeCumulativeWeight = 0.0;
        }

        print(
          '✅ Report SMS Debug - Final cumulative weight: $allTimeCumulativeWeight kg for member ${collection.memberName}',
        );
      } catch (e) {
        print(
          '❌ Error parsing cumulative weight for member ${collection.memberName}: $e',
        );
        print('   Raw memberSummary: $memberSummary');
        allTimeCumulativeWeight = 0.0;
      }

      // Prepare receipt data for coffee collection
      final receiptData = {
        'type': 'coffee_collection',
        'societyName': orgSettings?.societyName ?? 'Coffee Pro Society',
        'factory': orgSettings?.factory ?? 'Main Factory',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath, // Include logo path for receipt
        'memberName': collection.memberName,
        'memberNumber': collection.memberNumber,
        'receiptNumber': collection.receiptNumber,
        'date': DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(collection.collectionDate),
        'productType': collection.productType,
        'seasonName': collection.seasonName,
        'numberOfBags': collection.numberOfBags.toString(),
        'grossWeight': collection.grossWeight.toStringAsFixed(2),
        'tareWeightPerBag':
            collection.numberOfBags > 0
                ? (collection.tareWeight / collection.numberOfBags)
                    .toStringAsFixed(2)
                : '0.00',
        'totalTareWeight': collection.tareWeight.toStringAsFixed(2),
        'netWeight': collection.netWeight.toStringAsFixed(2),

        'allTimeCumulativeWeight': allTimeCumulativeWeight.toStringAsFixed(2),
        'entryType':
            collection.isManualEntry ? 'Manual Entry' : 'Scale Reading',
        'servedBy': collection.userName ?? 'Unknown User',
        'slogan': orgSettings?.slogan ?? 'Premium Coffee, Premium Returns',
      };

      // Check if using standard print method
      if (sysSettings?.printMethod == 'standard') {
        // Use dialog based printing for standard method
        await Get.find<PrintService>().printReceiptWithDialog(receiptData);
      } else {
        // Use direct printing for bluetooth method
        await Get.find<PrintService>().printReceipt(receiptData);
      }

      Get.snackbar(
        'Success',
        'Receipt printed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to print receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(CoffeeCollection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete this coffee collection record?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('This action cannot be undone.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Receipt Number',
                        collection.receiptNumber ?? 'N/A',
                      ),
                      _buildDetailRow('Member', collection.memberName),
                      _buildDetailRow(
                        'Date',
                        DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(collection.collectionDate),
                      ),
                      _buildDetailRow(
                        'Net Weight',
                        '${collection.netWeight.toStringAsFixed(2)} kg',
                      ),
                    ],
                  ),
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Delete the collection first
        await _coffeeCollectionController.deleteCollection(collection.id);

        // Refresh list
        _filterCollections();

        // Send SMS notification after deletion (with updated cumulative weight)
        // await _sendCollectionUpdateSMS(collection, isEdit: false);

        Get.snackbar(
          'Success',
          'Coffee collection record deleted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete collection: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    }
  }

  /*
  Future<void> _sendCollectionUpdateSMS(CoffeeCollection collection, {required bool isEdit}) async {
    // Prevent duplicate SMS sending
    if (_isSendingSMS) {
      print('SMS sending already in progress for ${collection.memberName}, skipping duplicate');
      return;
    }
    
    _isSendingSMS = true;
    
    try {
      // Always attempt to send SMS - don't check if SMS is enabled
      print('Attempting to send ${isEdit ? "update" : "deletion"} SMS for collection ${collection.receiptNumber}');

      // Get member to validate phone number
      final member = await _memberController.getMemberByNumber(collection.memberNumber);
      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print('No phone number available for member ${collection.memberName}');
        return;
      }

      // Validate phone number before proceeding
      final validatedNumber = _smsService.validateKenyanPhoneNumber(member.phoneNumber!);
      if (validatedNumber == null) {
        print('Invalid phone number for member ${collection.memberName}: ${member.phoneNumber} - Kenyan phone validation failed');
        Get.snackbar(
          'SMS Warning',
          'Invalid phone number for ${collection.memberName}: ${member.phoneNumber}. Please update to valid Kenyan format.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final orgSettings = _settingsController.organizationSettings.value;
      final societyName = orgSettings?.societyName ?? 'Farm Pro Society';
      
      // Calculate new all-time cumulative weight for this member (across all seasons)
      final memberSummary = await _coffeeCollectionController.getMemberSeasonSummary(collection.memberId);
      
      // Ensure we have a valid cumulative weight value
      double newAllTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = memberSummary['allTimeWeight'];
        if (rawWeight != null) {
          newAllTimeCumulativeWeight = double.tryParse(rawWeight.toString()) ?? 0.0;
        }
        
        // Additional validation to ensure the weight is valid and not negative
        if (newAllTimeCumulativeWeight < 0 || newAllTimeCumulativeWeight.isNaN || newAllTimeCumulativeWeight.isInfinite) {
          newAllTimeCumulativeWeight = 0.0;
        }
      } catch (e) {
        print('Error parsing cumulative weight for member ${collection.memberName}: $e');
        newAllTimeCumulativeWeight = 0.0;
      }
      
      // Create SMS message
      String message;
      if (isEdit) {
        message = '''Your coffee collection has been updated:
Updated details:
Date: ${DateFormat('dd/MM/yy').format(collection.collectionDate)}
Weight: ${collection.netWeight.toStringAsFixed(0)} kg
Bags: ${collection.numberOfBags}
Receipt #: ${collection.receiptNumber ?? "N/A"}
Total: ${newAllTimeCumulativeWeight.toStringAsFixed(0)} kg
$societyName''';
      } else {
        message = '''Coffee collection record removed:
Removed details:
Date: ${DateFormat('dd/MM/yy').format(collection.collectionDate)}
Weight: ${collection.netWeight.toStringAsFixed(1)} kg
Bags: ${collection.numberOfBags}
Receipt #: ${collection.receiptNumber ?? "N/A"}
New total: ${newAllTimeCumulativeWeight.toStringAsFixed(1)} kg
$societyName''';
      }
      
      print('Sending SMS immediately to $validatedNumber for collection ${isEdit ? "update" : "deletion"}');
      
      // Send SMS immediately with robust retry logic
      final success = await _smsService.sendSmsRobust(validatedNumber, message, maxRetries: 3, priority: 1);
      
      // Show confirmation to user
      Get.snackbar(
        success ? 'SMS Sent' : 'SMS Failed',
        success 
          ? '${isEdit ? "Update" : "Deletion"} notification sent to ${collection.memberName}'
          : 'Failed to send ${isEdit ? "update" : "deletion"} notification to ${collection.memberName}',
        backgroundColor: success ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Failed to send SMS notification: $e');
      // Don't block the UI for SMS issues
    } finally {
      _isSendingSMS = false;
    }
  }
*/

  // Excel-like table header
  Widget _buildTableHeader() {
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
            children:
                _showIndividualCollections
                    ? _buildIndividualViewHeaders()
                    : _buildCumulativeViewHeaders(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIndividualViewHeaders() {
    return [
      _buildHeaderCell('Date', _columnWidths['date']!),
      _buildHeaderCell('Receipt #', _columnWidths['receipt']!),
      _buildHeaderCell('Season', _columnWidths['season']!),
      _buildHeaderCell('Product', _columnWidths['product']!),
      _buildHeaderCell('Gross (kg)', _columnWidths['gross']!),
      _buildHeaderCell('Tare (kg)', _columnWidths['tare']!),
      _buildHeaderCell('Net (kg)', _columnWidths['net']!),
      _buildHeaderCell('Bags', _columnWidths['bags']!),
      _buildHeaderCell('Served By', _columnWidths['served']!),
      _buildHeaderCell('Actions', _columnWidths['actions']!),
    ];
  }

  List<Widget> _buildCumulativeViewHeaders() {
    return [
      _buildHeaderCell('Member Name', _columnWidths['member']!),
      _buildHeaderCell('Member #', _columnWidths['memberNumber']!),
      _buildHeaderCell('Phone', _columnWidths['phone']!),
      _buildHeaderCell('Collections', _columnWidths['totalCollections']!),
      _buildHeaderCell('Total Weight (kg)', _columnWidths['totalWeight']!),
      _buildHeaderCell('Total Bags', _columnWidths['totalBags']!),
      _buildHeaderCell('Last Collection', _columnWidths['lastCollection']!),
      _buildHeaderCell('Actions', _columnWidths['actions']!),
    ];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Member Collection Report',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _coffeeCollectionController.refreshCollections(),
            tooltip: 'Refresh Collections',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed:
                _filteredCollections.isNotEmpty
                    ? _exportCollectionsToExcel
                    : null,
            tooltip: 'Share Report as Excel',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Filters
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Member Selection
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selectMember,
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
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedMember != null
                                      ? _selectedMember!.fullName
                                      : 'Select Member',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        _selectedMember != null
                                            ? Colors.black
                                            : Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Range
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDateRange,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _startDate != null && _endDate != null
                                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                            : 'All Collections (No Date Filter)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontStyle:
                                              _startDate == null
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                          color:
                                              _startDate == null
                                                  ? Colors.grey[600]
                                                  : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_startDate != null && _endDate != null) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _filterCollections();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Report View Filter
                Row(
                  children: [
                    const Icon(Icons.view_list, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Report View:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showIndividualCollections = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      !_showIndividualCollections
                                          ? Colors.blue
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        !_showIndividualCollections
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  'Cumulative',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        !_showIndividualCollections
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                    fontWeight:
                                        !_showIndividualCollections
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showIndividualCollections = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _showIndividualCollections
                                          ? Colors.blue
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        _showIndividualCollections
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  'Single',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        _showIndividualCollections
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                    fontWeight:
                                        _showIndividualCollections
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Compact Summary with Auto-refresh Toggle
          if (_selectedMember != null || !_showIndividualCollections) ...[
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
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
                      _showIndividualCollections
                          ? '${_selectedMember!.fullName} • Collections: ${_filteredCollections.length} • Weight: ${_cachedTotalWeight.toStringAsFixed(1)} kg • Bags: $_cachedTotalBags'
                          : 'Members: ${_cumulativeData.length} • Total Weight: ${_cachedTotalWeight.toStringAsFixed(1)} kg • Total Bags: $_cachedTotalBags • Total Collections: ${_cumulativeData.fold<int>(0, (sum, data) => sum + data.totalCollections)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),
          ],

          // Excel-like Collections Table
          Expanded(
            child:
                (_showIndividualCollections && _selectedMember == null)
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Please select a member to view individual collections',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : (_showIndividualCollections
                        ? _filteredCollections.isEmpty
                        : _cumulativeData.isEmpty)
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _startDate != null && _endDate != null
                                ? 'No collections found for the selected period'
                                : (_showIndividualCollections
                                    ? 'No collections found for this member'
                                    : 'No member collections found'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Column(
                          children: [
                            // Fixed header
                            _buildTableHeader(),

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
                                        maxWidth: math.max(
                                          maxWidth,
                                          tableWidth,
                                        ),
                                      ),
                                      child: SizedBox(
                                        width: tableWidth,
                                        child: NotificationListener<
                                          ScrollNotification
                                        >(
                                          onNotification: (
                                            ScrollNotification scrollInfo,
                                          ) {
                                            // Load more data when near bottom
                                            if (scrollInfo.metrics.pixels >=
                                                scrollInfo
                                                        .metrics
                                                        .maxScrollExtent -
                                                    200) {
                                              _loadMoreData();
                                            }
                                            return false;
                                          },
                                          child: ListView.builder(
                                            controller:
                                                _verticalScrollController,
                                            itemCount:
                                                _showIndividualCollections
                                                    ? _displayedCollections
                                                            .length +
                                                        (_hasMoreData ? 1 : 0)
                                                    : _displayedCumulativeData
                                                            .length +
                                                        (_hasMoreData ? 1 : 0),
                                            itemExtent:
                                                _rowHeight, // Fixed height for better performance
                                            cacheExtent:
                                                200, // Cache fewer items
                                            itemBuilder: (context, index) {
                                              if (_showIndividualCollections) {
                                                if (index >=
                                                    _displayedCollections
                                                        .length) {
                                                  // Loading indicator at bottom
                                                  return Container(
                                                    height: _rowHeight,
                                                    alignment: Alignment.center,
                                                    child:
                                                        const CircularProgressIndicator(),
                                                  );
                                                }
                                                final collection =
                                                    _displayedCollections[index];
                                                return _OptimizedTableRow(
                                                  key: ValueKey(collection.id),
                                                  collection: collection,
                                                  index: index,
                                                  columnWidths: _columnWidths,
                                                  rowHeight: _rowHeight,
                                                  onPrint:
                                                      () =>
                                                          _printCollectionReceipt(
                                                            collection,
                                                          ),
                                                  onDelete:
                                                      () =>
                                                          _showDeleteConfirmation(
                                                            collection,
                                                          ),
                                                );
                                              } else {
                                                if (index >=
                                                    _displayedCumulativeData
                                                        .length) {
                                                  // Loading indicator at bottom
                                                  return Container(
                                                    height: _rowHeight,
                                                    alignment: Alignment.center,
                                                    child:
                                                        const CircularProgressIndicator(),
                                                  );
                                                }
                                                final cumulativeData =
                                                    _displayedCumulativeData[index];
                                                return _OptimizedCumulativeRow(
                                                  key: ValueKey(
                                                    cumulativeData.member.id,
                                                  ),
                                                  cumulativeData:
                                                      cumulativeData,
                                                  index: index,
                                                  columnWidths: _columnWidths,
                                                  rowHeight: _rowHeight,
                                                  onViewDetails:
                                                      () => _viewMemberDetails(
                                                        cumulativeData,
                                                      ),
                                                  onExportMember:
                                                      () =>
                                                          _exportMemberCollections(
                                                            cumulativeData,
                                                          ),
                                                );
                                              }
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
                                border: Border(
                                  top: BorderSide(color: Colors.grey[300]!),
                                ),
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
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.0,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Helper methods for cumulative view actions
  void _viewMemberDetails(_MemberCumulativeData cumulativeData) {
    // Navigate to individual collections view for this member
    setState(() {
      _selectedMember = cumulativeData.member;
      _showIndividualCollections = true;
    });
    _filterCollections();
  }

  void _exportMemberCollections(_MemberCumulativeData cumulativeData) {
    // Set the member and export their collections
    setState(() {
      _selectedMember = cumulativeData.member;
      _filteredCollections = cumulativeData.collections;
    });
    _exportCollectionsToExcel();
  }
}

// Optimized table row widget for better performance
class _OptimizedTableRow extends StatelessWidget {
  final CoffeeCollection collection;
  final int index;
  final Map<String, double> columnWidths;
  final double rowHeight;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _OptimizedTableRow({
    super.key,
    required this.collection,
    required this.index,
    required this.columnWidths,
    required this.rowHeight,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;

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
          _buildActionCell(),
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
          textAlign:
              alignment == Alignment.centerRight
                  ? TextAlign.right
                  : alignment == Alignment.center
                  ? TextAlign.center
                  : TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildActionCell() {
    return Container(
      width: columnWidths['actions']!,
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: IconButton(
              onPressed: onPrint,
              icon: const Icon(Icons.print),
              tooltip: 'Print',
              color: Colors.green,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          Flexible(
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              color: Colors.red,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }
}

// Optimized cumulative row widget for better performance
class _OptimizedCumulativeRow extends StatelessWidget {
  final _MemberCumulativeData cumulativeData;
  final int index;
  final Map<String, double> columnWidths;
  final double rowHeight;
  final VoidCallback onViewDetails;
  final VoidCallback onExportMember;

  const _OptimizedCumulativeRow({
    super.key,
    required this.cumulativeData,
    required this.index,
    required this.columnWidths,
    required this.rowHeight,
    required this.onViewDetails,
    required this.onExportMember,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(
            cumulativeData.member.fullName,
            columnWidths['member']!,
          ),
          _buildDataCell(
            cumulativeData.member.memberNumber.toString(),
            columnWidths['memberNumber']!,
          ),
          _buildDataCell(
            cumulativeData.member.phoneNumber ?? 'N/A',
            columnWidths['phone']!,
          ),
          _buildDataCell(
            cumulativeData.totalCollections.toString(),
            columnWidths['totalCollections']!,
          ),
          _buildDataCell(
            cumulativeData.totalWeight.toStringAsFixed(2),
            columnWidths['totalWeight']!,
          ),
          _buildDataCell(
            cumulativeData.totalBags.toString(),
            columnWidths['totalBags']!,
          ),
          _buildDataCell(
            cumulativeData.lastCollectionDate != null
                ? _formatDate(cumulativeData.lastCollectionDate!)
                : 'N/A',
            columnWidths['lastCollection']!,
          ),
          _buildActionCell(),
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
          textAlign:
              alignment == Alignment.centerRight
                  ? TextAlign.right
                  : alignment == Alignment.center
                  ? TextAlign.center
                  : TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildActionCell() {
    return Container(
      width: columnWidths['actions']!,
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: IconButton(
              onPressed: onViewDetails,
              icon: const Icon(Icons.info),
              tooltip: 'View Details',
              color: Colors.blue,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          Flexible(
            child: IconButton(
              onPressed: onExportMember,
              icon: const Icon(Icons.share),
              tooltip: 'Export Member Collections',
              color: Colors.orange,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
