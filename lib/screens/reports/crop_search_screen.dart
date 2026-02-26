import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/custom_app_bar.dart';

class CropSearchScreen extends StatefulWidget {
  const CropSearchScreen({super.key});

  @override
  State<CropSearchScreen> createState() => _CropSearchScreenState();
}

class _CropSearchScreenState extends State<CropSearchScreen> {
  // Controllers
  final CoffeeCollectionController _coffeeCollectionController =
      Get.find<CoffeeCollectionController>();
  final MemberController _memberController = Get.find<MemberController>();

  // Search controllers
  final TextEditingController _cropSearchController = TextEditingController();
  Timer? _searchDebounce;

  // Member Number filter
  final TextEditingController _memberNumberController = TextEditingController();
  Timer? _memberDebounce;

  // Collections data
  List<CoffeeCollection> _allCollections = [];
  List<CoffeeCollection> _filteredCollections = [];
  List<CoffeeCollection> _displayedCollections = [];

  // Available crops (unique product types from collections)
  List<String> _availableCrops = [];
  List<String> _filteredCrops = [];
  String? _selectedCrop;

  // Date filtering
  DateTime? _startDate;
  DateTime? _endDate;

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
      'product': isSmallScreen ? 120.0 : 140.0, // Slightly wider for crop names
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
  int _cachedCollectionsCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize collections data
    _initializeCollections();

    // Set up real-time updates
    _setupRealTimeUpdates();

    // Sync horizontal scrolling between header and data
    _setupScrollSync();

    // Setup crop search listener
    _setupCropSearch();

    // Setup member number search listener
    _setupMemberNumberSearch();
  }

  @override
  void dispose() {
    _collectionsWorker?.dispose();
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _cropSearchController.dispose();
    _memberDebounce?.cancel();
    _memberNumberController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  void _initializeCollections() {
    _allCollections = _coffeeCollectionController.collections;
    _extractAvailableCrops();
    _filterCollections();
  }

  void _extractAvailableCrops() {
    // Extract unique crop types from all collections
    final cropSet = <String>{};
    for (final collection in _allCollections) {
      if (collection.productType.isNotEmpty) {
        cropSet.add(collection.productType);
      }
    }

    _availableCrops = cropSet.toList()..sort();
    _filteredCrops = List.from(_availableCrops);
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
            _extractAvailableCrops();
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

  void _setupCropSearch() {
    _cropSearchController.addListener(() {
      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _filterCrops(_cropSearchController.text);
      });
    });
  }

  void _setupMemberNumberSearch() {
    _memberNumberController.addListener(() {
      if (_memberDebounce?.isActive ?? false) _memberDebounce!.cancel();
      _memberDebounce = Timer(const Duration(milliseconds: 300), () {
        _filterCollections();
      });
    });
  }

  void _filterCrops(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCrops = List.from(_availableCrops);
      } else {
        _filteredCrops =
            _availableCrops
                .where(
                  (crop) => crop.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  void _filterCollections() {
    // Filter collections in background to avoid blocking UI
    Future.microtask(() {
      var filtered =
          _allCollections.where((collection) {
            // Apply crop filter
            if (_selectedCrop != null && _selectedCrop!.isNotEmpty) {
              if (collection.productType != _selectedCrop) {
                return false;
              }
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

              if (!(collectionDate.isAfter(startOfDay) &&
                  collectionDate.isBefore(endOfDay))) {
                return false;
              }
            }

            // Apply member number filter
            final memberQuery = _memberNumberController.text.trim();
            if (memberQuery.isNotEmpty) {
              final memberNo = (collection.memberNumber ?? '').toString();
              if (memberNo.toLowerCase() != memberQuery.toLowerCase()) {
                return false;
              }
            }

            // If no date filter is applied, include all collections
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
    _cachedMembersCount =
        _filteredCollections.map((c) => c.memberId).toSet().length;
    _cachedCollectionsCount = _filteredCollections.length;
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
      helpText: 'Select Date Range for Crop Collections',
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

  void _clearCropFilter() {
    setState(() {
      _selectedCrop = null;
      _cropSearchController.clear();
    });
    _filterCollections();
  }

  // Export functionality
  Future<void> _exportReport() async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Export Crop Search Report'),
              content: Text(
                'Choose export format for ${_selectedCrop ?? "all crops"} collections:',
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
              Text('Generating ${choice.toUpperCase()} report...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      if (choice == 'csv') {
        await _exportToCsv();
      } else {
        await _exportToExcel();
      }

      Get.back(); // Close loading dialog

      Get.snackbar(
        'Export Complete',
        'Crop search report exported successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Export Failed',
        'Failed to export report: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Crop_Collections'];

    // Add headers
    final headers = [
      'Date',
      'Member Number',
      'Member Name',
      'Receipt Number',
      'Season',
      'Crop Type',
      'Gross Weight (kg)',
      'Tare Weight (kg)',
      'Net Weight (kg)',
      'Number of Bags',
      'Served By',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }

    // Build member lookup map for efficient access
    final Map<String, Member> memberLookup = {
      for (final m in _memberController.members) m.id.toString(): m,
    };

    // Add data
    for (int i = 0; i < _filteredCollections.length; i++) {
      final collection = _filteredCollections[i];
      final member = memberLookup[collection.memberId];

      final row = [
        DateFormat('yyyy-MM-dd HH:mm').format(collection.collectionDate),
        collection.memberNumber,
        member?.fullName ?? collection.memberName,
        collection.receiptNumber ?? 'N/A',
        collection.seasonName,
        collection.productType,
        collection.grossWeight.toStringAsFixed(2),
        collection.tareWeight.toStringAsFixed(2),
        collection.netWeight.toStringAsFixed(2),
        collection.numberOfBags.toString(),
        collection.userName ?? 'Unknown',
      ];

      for (int j = 0; j < row.length; j++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
            .value = TextCellValue(row[j]);
      }
    }

    final bytes = excel.encode()!;
    final fileName =
        'Crop_Search_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    await _saveAndShareFile(bytes, fileName);
  }

  Future<void> _exportToCsv() async {
    final csvData = <List<String>>[];

    // Add headers
    csvData.add([
      'Date',
      'Member Number',
      'Member Name',
      'Receipt Number',
      'Season',
      'Crop Type',
      'Gross Weight (kg)',
      'Tare Weight (kg)',
      'Net Weight (kg)',
      'Number of Bags',
      'Served By',
    ]);

    // Build member lookup map for efficient access
    final Map<String, Member> memberLookup = {
      for (final m in _memberController.members) m.id.toString(): m,
    };

    // Add data
    for (final collection in _filteredCollections) {
      final member = memberLookup[collection.memberId];

      csvData.add([
        DateFormat('yyyy-MM-dd HH:mm').format(collection.collectionDate),
        collection.memberNumber,
        member?.fullName ?? collection.memberName,
        collection.receiptNumber ?? 'N/A',
        collection.seasonName,
        collection.productType,
        collection.grossWeight.toStringAsFixed(2),
        collection.tareWeight.toStringAsFixed(2),
        collection.netWeight.toStringAsFixed(2),
        collection.numberOfBags.toString(),
        collection.userName ?? 'Unknown',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final bytes = csvString.codeUnits;
    final fileName =
        'Crop_Search_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    await _saveAndShareFile(bytes, fileName);
  }

  Future<void> _saveAndShareFile(List<int> bytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          'Crop Search Report - Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
    );
  }

  String _getDateRangeText() {
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }
    return 'All Dates (No Date Filter)';
  }

  String _getCropFilterText() {
    if (_selectedCrop != null && _selectedCrop!.isNotEmpty) {
      return _selectedCrop!;
    }
    return 'All Crops (No Crop Filter)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Crop Search',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _coffeeCollectionController.refreshCollections(),
            tooltip: 'Refresh Collections',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _filteredCollections.isNotEmpty ? _exportReport : null,
            tooltip: 'Export Crop Report',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Controls
          _buildSearchAndFilters(),

          // Summary Statistics
          _buildSummaryStats(),

          // Collections Table
          Expanded(child: _buildCollectionsTable()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop Search
          Row(
            children: [
              const Icon(Icons.search, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Search Crop:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: TextField(
                    controller: _cropSearchController,
                    decoration: const InputDecoration(
                      hintText: 'Type crop name to search...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Crop Selection Dropdown
          if (_filteredCrops.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.agriculture, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Select Crop:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCrop,
                        hint: const Text(
                          'Select a crop type...',
                          style: TextStyle(fontSize: 13),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Crops',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          ..._filteredCrops.map(
                            (crop) => DropdownMenuItem<String>(
                              value: crop,
                              child: Text(
                                crop,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCrop = value;
                          });
                          _filterCollections();
                        },
                      ),
                    ),
                  ),
                ),
                if (_selectedCrop != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: _clearCropFilter,
                    tooltip: 'Clear Crop Filter',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),
          ],

          // Date Range and Auto-refresh Controls
          SingleChildScrollView(
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
                                  _getDateRangeText(),
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

                // Member Number Filter
                Row(
                  children: [
                    const Icon(Icons.badge, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Member No.:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: TextField(
                          controller: _memberNumberController,
                          decoration: InputDecoration(
                            hintText: 'Enter member number...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintStyle: const TextStyle(fontSize: 13),
                            suffixIcon:
                                _memberNumberController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Clear Member Number',
                                      onPressed: () {
                                        _memberNumberController.clear();
                                        _filterCollections();
                                      },
                                    )
                                    : null,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    return Container(
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
              'Crop: ${_getCropFilterText()} • Collections: $_cachedCollectionsCount • Weight: ${_cachedTotalWeight.toStringAsFixed(1)} kg • Bags: $_cachedTotalBags • Members: $_cachedMembersCount',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsTable() {
    if (_filteredCollections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _selectedCrop != null
                  ? 'No collections found for "$_selectedCrop"'
                  : 'No collections found for the selected criteria',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_selectedCrop != null || _startDate != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _clearCropFilter();
                  _clearDateFilter();
                  _memberNumberController.clear();
                  _filterCollections();
                },
                child: const Text('Clear All Filters'),
              ),
            ],
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
            _buildTableHeader(),

            // Scrollable data
            Expanded(child: _buildTableData()),

            // Load more button
            if (_hasMoreData)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: TextButton(
                  onPressed: _loadMoreData,
                  child: Text(
                    'Load More (${_filteredCollections.length - _displayedCollections.length} remaining)',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SingleChildScrollView(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildHeaderCell('Date', _columnWidths['date']!),
            _buildHeaderCell('Member', _columnWidths['member']!),
            _buildHeaderCell('Receipt', _columnWidths['receipt']!),
            _buildHeaderCell('Season', _columnWidths['season']!),
            _buildHeaderCell('Crop Type', _columnWidths['product']!),
            _buildHeaderCell('Gross (kg)', _columnWidths['gross']!),
            _buildHeaderCell('Tare (kg)', _columnWidths['tare']!),
            _buildHeaderCell('Net (kg)', _columnWidths['net']!),
            _buildHeaderCell('Bags', _columnWidths['bags']!),
            _buildHeaderCell('Served By', _columnWidths['served']!),
          ],
        ),
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

  // Calculate totals for the current filtered collections
  Map<String, dynamic> _calculateTotals() {
    double totalGross = 0;
    double totalTare = 0;
    double totalNet = 0;
    int totalBags = 0;

    for (final collection in _filteredCollections) {
      totalGross += collection.grossWeight;
      totalTare += collection.tareWeight;
      totalNet += collection.netWeight;
      totalBags += collection.numberOfBags;
    }

    return {
      'totalGross': totalGross,
      'totalTare': totalTare,
      'totalNet': totalNet,
      'totalBags': totalBags,
    };
  }

  // Build the totals row
  Widget _buildTotalsRow() {
    final totals = _calculateTotals();

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // Date column
          Container(
            width: _columnWidths['date'],
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Text(
              'TOTALS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // Member column (empty)
          Container(
            width: _columnWidths['member'],
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
          ),

          // Receipt column (empty)
          Container(
            width: _columnWidths['receipt'],
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
          ),

          // Season column (empty)
          Container(
            width: _columnWidths['season'],
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
          ),

          // Crop Type column (empty)
          Container(
            width: _columnWidths['product'],
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
          ),

          // Gross Weight
          _buildTotalCell(
            totals['totalGross'].toStringAsFixed(2),
            _columnWidths['gross']!,
          ),

          // Tare Weight
          _buildTotalCell(
            totals['totalTare'].toStringAsFixed(2),
            _columnWidths['tare']!,
          ),

          // Net Weight
          _buildTotalCell(
            totals['totalNet'].toStringAsFixed(2),
            _columnWidths['net']!,
          ),

          // Bags
          _buildTotalCell(
            totals['totalBags'].toString(),
            _columnWidths['bags']!,
          ),

          // Served By (empty)
          Container(
            width: _columnWidths['served'],
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCell(String value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildTableData() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: maxWidth,
              maxWidth: math.max(maxWidth, _totalTableWidth),
            ),
            child: Column(
              children: [
                // Data rows
                SizedBox(
                  width: _totalTableWidth,
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    shrinkWrap: true,
                    itemCount: _displayedCollections.length,
                    itemExtent: _rowHeight,
                    cacheExtent: 200,
                    itemBuilder: (context, index) {
                      final collection = _displayedCollections[index];
                      return _CollectionTableRow(
                        key: ValueKey(collection.id),
                        collection: collection,
                        index: index,
                        columnWidths: _columnWidths,
                        memberController: _memberController,
                      );
                    },
                  ),
                ),

                // Totals row (only if we have data)
                if (_displayedCollections.isNotEmpty) _buildTotalsRow(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollectionTableRow extends StatelessWidget {
  final CoffeeCollection collection;
  final int index;
  final Map<String, double> columnWidths;
  final MemberController memberController;

  const _CollectionTableRow({
    super.key,
    required this.collection,
    required this.index,
    required this.columnWidths,
    required this.memberController,
  });

  @override
  Widget build(BuildContext context) {
    // Build member lookup map for efficient access
    final Map<String, Member> memberLookup = {
      for (final m in memberController.members) m.id.toString(): m,
    };

    final member = memberLookup[collection.memberId];
    final isEvenRow = index % 2 == 0;

    return Container(
      height: 60.0,
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildDataCell(
            DateFormat('MMM dd, yy\nHH:mm').format(collection.collectionDate),
            columnWidths['date']!,
          ),
          _buildDataCell(
            '${collection.memberNumber}\n${member?.fullName ?? collection.memberName}',
            columnWidths['member']!,
          ),
          _buildDataCell(
            collection.receiptNumber ?? 'N/A',
            columnWidths['receipt']!,
          ),
          _buildDataCell(collection.seasonName, columnWidths['season']!),
          _buildDataCell(
            collection.productType,
            columnWidths['product']!,
            highlight: true, // Highlight crop type
          ),
          _buildDataCell(
            collection.grossWeight.toStringAsFixed(1),
            columnWidths['gross']!,
          ),
          _buildDataCell(
            collection.tareWeight.toStringAsFixed(1),
            columnWidths['tare']!,
          ),
          _buildDataCell(
            collection.netWeight.toStringAsFixed(1),
            columnWidths['net']!,
            fontWeight: FontWeight.w600,
          ),
          _buildDataCell(
            collection.numberOfBags.toString(),
            columnWidths['bags']!,
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
    bool highlight = false,
    FontWeight? fontWeight,
  }) {
    return Container(
      width: width,
      height: 60.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
        color: highlight ? Colors.blue[50] : null,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: fontWeight,
            color: highlight ? Colors.blue[800] : null,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}
