import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/inventory_service.dart';
import '../../services/print_service.dart';
import '../../services/season_service.dart';
import '../../widgets/custom_app_bar.dart';

class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({super.key});

  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

class _InventoryReportsScreenState extends State<InventoryReportsScreen> {
  // Services & Controllers
  final InventoryService _inventoryService = Get.find<InventoryService>();
  final MemberController _memberController = Get.find<MemberController>();
  final SeasonService _seasonService = Get.find<SeasonService>();

  // Raw data
  List<Sale> _allSales = [];
  List<Sale> _filteredSales = [];
  List<Sale> _displayedSales = [];

  // Cumulative data
  List<Map<String, dynamic>> _cumulativeData = [];

  // Filters
  DateTimeRange? _dateRange;
  String _saleType = 'ALL'; // ALL / CASH / CREDIT
  String _viewType = 'individual'; // individual / cumulative
  Member? _selectedMember;

  // Pagination
  static const int _itemsPerPage = 50;
  int _currentPage = 0;
  bool _hasMoreData = false;

  // Loading state
  final RxBool _isLoading = false.obs;

  // Scroll controllers (Excel-like)
  final ScrollController _hScroll = ScrollController();
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSales();
    _hScroll.addListener(() {
      if (_headerScroll.hasClients) {
        _headerScroll.jumpTo(_hScroll.offset);
      }
    });
  }

  Future<void> _loadSales() async {
    _isLoading.value = true;
    // Fetch and filter in a separate microtask to allow UI to render loading indicator
    await Future.microtask(() {
      _allSales = _inventoryService.sales.toList();
      _applyFilters();
    });
    _isLoading.value = false;
  }

  void _applyFilters() {
    List<Sale> list = _allSales;

    // Active inventory period default
    final activePeriod = _seasonService.activeSeason;
    if (activePeriod != null) {
      list = list.where((s) => s.seasonId == activePeriod.id).toList();
    }

    // Date filter
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
      );
      list =
          list
              .where(
                (s) => s.saleDate.isAfter(start) && s.saleDate.isBefore(end),
              )
              .toList();
    }

    // Sale type
    if (_saleType != 'ALL') {
      list = list.where((s) => s.saleType == _saleType).toList();
    }

    // Member filter (only individual view)
    if (_selectedMember != null) {
      list = list.where((s) => s.memberId == _selectedMember!.id).toList();
    }

    // Sort newest first
    list.sort((a, b) => b.saleDate.compareTo(a.saleDate));

    setState(() {
      _filteredSales = list;
      _currentPage = 0;
      if (_viewType == 'cumulative') {
        _prepareCumulative();
      } else {
        _updateDisplay();
      }
    });
  }

  void _updateDisplay() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = math.min(
      startIndex + _itemsPerPage,
      _filteredSales.length,
    );
    _displayedSales = _filteredSales.sublist(startIndex, endIndex);
    _hasMoreData = endIndex < _filteredSales.length;
  }

  void _prepareCumulative() {
    final Map<String, Map<String, dynamic>> map = {};
    for (final sale in _filteredSales) {
      if (sale.memberId == null) continue;
      map.putIfAbsent(sale.memberId!, () {
        return {
          'member': sale.memberName ?? 'Unknown',
          'memberId': sale.memberId,
          'total': 0.0,
          'paid': 0.0,
          'balance': 0.0,
          'transactions': 0,
          'lastDate': sale.saleDate,
        };
      });
      final m = map[sale.memberId!]!;
      m['total'] += sale.totalAmount;
      m['paid'] += sale.paidAmount;
      m['balance'] += sale.balanceAmount;
      m['transactions'] += 1;
      if (sale.saleDate.isAfter(m['lastDate'])) m['lastDate'] = sale.saleDate;
    }
    _cumulativeData = map.values.toList();
  }

  // Export helpers
  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[];
    if (_viewType == 'individual') {
      rows.add([
        'Date',
        'Receipt',
        'Member',
        'Type',
        'Total',
        'Paid',
        'Balance',
        'Served By',
      ]);
      for (final s in _filteredSales) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(s.saleDate),
          s.receiptNumber,
          s.memberName ?? '-',
          s.saleType,
          s.totalAmount,
          s.paidAmount,
          s.balanceAmount,
          s.userName,
        ]);
      }
    } else {
      rows.add([
        'Member',
        'Total',
        'Paid',
        'Balance',
        'Transactions',
        'Last Sale',
      ]);
      for (final m in _cumulativeData) {
        rows.add([
          m['member'],
          m['total'],
          m['paid'],
          m['balance'],
          m['transactions'],
          DateFormat('yyyy-MM-dd').format(m['lastDate']),
        ]);
      }
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path)..writeAsStringSync(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report');
  }

  // UI helpers
  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date range
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _dateRange == null
                    ? 'All Dates'
                    : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} → ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 1),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                  _applyFilters();
                }
              },
            ),
            // Sale type
            DropdownButton<String>(
              value: _saleType,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
              ],
              onChanged: (v) {
                setState(() => _saleType = v!);
                _applyFilters();
              },
            ),
            // Member dropdown
            DropdownButton<Member?>(
              hint: const Text('Member'),
              value: _selectedMember,
              items:
                  [
                    const DropdownMenuItem<Member?>(
                      value: null,
                      child: Text('All Members'),
                    ),
                  ] +
                  _memberController.members
                      .map(
                        (m) => DropdownMenuItem<Member?>(
                          value: m,
                          child: Text(m.fullName),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                setState(() => _selectedMember = v);
                _applyFilters();
              },
            ),
            // View toggle
            DropdownButton<String>(
              value: _viewType,
              items: const [
                DropdownMenuItem(
                  value: 'individual',
                  child: Text('Single Records'),
                ),
                DropdownMenuItem(
                  value: 'cumulative',
                  child: Text('Cumulative'),
                ),
              ],
              onChanged: (v) {
                setState(() => _viewType = v!);
                _applyFilters();
              },
            ),
            // Export button CSV only
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_viewType == 'individual') {
      return _buildIndividualTable();
    } else {
      return _buildCumulativeTable();
    }
  }

  Widget _buildIndividualTable() {
    if (_filteredSales.isEmpty) {
      return const Center(child: Text('No sales found'));
    }
    return Scrollbar(
      controller: _vScroll,
      child: SingleChildScrollView(
        controller: _vScroll,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Receipt')),
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Paid')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('Items')),
              DataColumn(label: Text('Served By')),
              DataColumn(label: Text('Actions')),
            ],
            rows:
                _displayedSales
                    .map(
                      (s) => DataRow(
                        cells: [
                          DataCell(
                            Text(DateFormat('yyyy-MM-dd').format(s.saleDate)),
                          ),
                          DataCell(Text(s.receiptNumber ?? '')),
                          DataCell(Text(s.memberName ?? '-')),
                          DataCell(Text(s.saleType)),
                          DataCell(Text(s.totalAmount.toStringAsFixed(2))),
                          DataCell(Text(s.paidAmount.toStringAsFixed(2))),
                          DataCell(Text(s.balanceAmount.toStringAsFixed(2))),
                          DataCell(Text(s.items.length.toString())),
                          DataCell(Text(s.userName ?? '')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  tooltip: 'Details',
                                  onPressed: () => _showSaleDetailsDialog(s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print, size: 18),
                                  tooltip: 'Reprint',
                                  onPressed: () => _reprintSaleReceipt(s),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCumulativeTable() {
    if (_cumulativeData.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return Scrollbar(
      controller: _vScroll,
      child: SingleChildScrollView(
        controller: _vScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Member')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Paid')),
              DataColumn(label: Text('Balance')),
              DataColumn(label: Text('Transactions')),
              DataColumn(label: Text('Last Sale')),
            ],
            rows:
                _cumulativeData
                    .map(
                      (m) => DataRow(
                        cells: [
                          DataCell(Text(m['member'])),
                          DataCell(
                            Text((m['total'] as double).toStringAsFixed(2)),
                          ),
                          DataCell(
                            Text((m['paid'] as double).toStringAsFixed(2)),
                          ),
                          DataCell(
                            Text((m['balance'] as double).toStringAsFixed(2)),
                          ),
                          DataCell(Text(m['transactions'].toString())),
                          DataCell(
                            Text(
                              DateFormat('yyyy-MM-dd').format(m['lastDate']),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  void _showSaleDetailsDialog(Sale sale) {
    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt, color: Color(0xFF8B4513)),
                  const SizedBox(width: 8),
                  Text(
                    'Sale Details - ${sale.receiptNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scrollable table
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Qty')),
                          DataColumn(label: Text('Unit Price')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows:
                            sale.items
                                .map(
                                  (i) => DataRow(
                                    cells: [
                                      DataCell(Text(i.productName)),
                                      DataCell(
                                        Text(i.quantity.toStringAsFixed(1)),
                                      ),
                                      DataCell(
                                        Text(i.unitPrice.toStringAsFixed(2)),
                                      ),
                                      DataCell(
                                        Text(i.totalPrice.toStringAsFixed(2)),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Subtotal: KSh ${sale.totalAmount.toStringAsFixed(2)}'),
              Text('Paid: KSh ${sale.paidAmount.toStringAsFixed(2)}'),
              Text('Balance: KSh ${sale.balanceAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reprintSaleReceipt(Sale sale) async {
    final settingsController = Get.find<SettingsController>();
    final settings = settingsController.systemSettings.value;
    if (settings?.enablePrinting != true) return;

    try {
      final orgSettings = settingsController.organizationSettings.value;
      final printService = Get.find<PrintService>();

      final receiptData = {
        'type': 'sale',
        'societyName': orgSettings?.societyName ?? 'Farm Pro Society',
        'factory': orgSettings?.factory ?? 'Main Store',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath,
        'memberName': sale.memberName,
        'memberNumber': sale.memberId,
        'receiptNumber': sale.receiptNumber,
        'date': DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate),
        'saleType': sale.saleType,
        'totalAmount': sale.totalAmount.toStringAsFixed(2),
        'paidAmount': sale.paidAmount.toStringAsFixed(2),
        'balanceAmount': sale.balanceAmount.abs().toStringAsFixed(2),
        'items': sale.items
            .map(
              (item) => {
                'productName':
                    '${item.productName} (${item.packSizeSold.toStringAsFixed(0)})',
                'quantity': item.quantity.toStringAsFixed(1),
                'unitPrice': item.unitPrice.toStringAsFixed(2),
                'totalPrice': item.totalPrice.toStringAsFixed(2),
              },
            )
            .toList(),
        'notes': sale.notes ?? '',
        'servedBy': sale.userName ?? 'Unknown User',
        'slogan': orgSettings?.slogan ?? 'Quality Products, Great Service',
      };

      if (settings?.printMethod == 'standard') {
        await printService.printReceiptWithDialog(receiptData);
      } else {
        await printService.printReceipt(receiptData);
      }
    } catch (e) {
      print('Error reprinting receipt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: const CustomAppBar(title: 'Inventory Sales Reports'),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _buildFilters(),
            const Divider(height: 1),
            Expanded(child: _buildTable()),
            if (_hasMoreData && _viewType == 'individual')
              TextButton(
                onPressed: () {
                  setState(() => _updateDisplay());
                },
                child: const Text('Load More'),
              ),
          ],
        );
      }),
    );
  }
}
