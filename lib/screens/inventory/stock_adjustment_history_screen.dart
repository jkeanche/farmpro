import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../../services/inventory_service.dart';

class StockAdjustmentHistoryScreen extends StatefulWidget {
  const StockAdjustmentHistoryScreen({super.key});

  @override
  State<StockAdjustmentHistoryScreen> createState() =>
      _StockAdjustmentHistoryScreenState();
}

class _StockAdjustmentHistoryScreenState
    extends State<StockAdjustmentHistoryScreen> {
  final InventoryService _inventoryService = Get.find<InventoryService>();

  // Filter state
  String? _selectedCategoryId;
  String? _selectedProductId;
  DateTimeRange? _selectedDateRange;

  // UI state
  bool _isLoading = false;
  bool _isExporting = false;
  List<StockAdjustmentHistory> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _inventoryService.loadStockAdjustmentHistory();
      await _applyFilters();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load adjustment history: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFilters() async {
    try {
      final filtered = await _inventoryService.getFilteredAdjustmentHistory({
        'categoryId': _selectedCategoryId,
        'productId': _selectedProductId,
        'startDate': _selectedDateRange?.start,
        'endDate': _selectedDateRange?.end,
      });

      setState(() {
        _filteredHistory = filtered;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to apply filters: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedProductId = null;
      _selectedDateRange = null;
    });
    _applyFilters();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF8B4513)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _applyFilters();
    }
  }

  Future<void> _exportToCsv() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final csvContent = await _inventoryService.exportAdjustmentHistoryToCsv({
        'categoryId': _selectedCategoryId,
        'productId': _selectedProductId,
        'startDate': _selectedDateRange?.start,
        'endDate': _selectedDateRange?.end,
      });

      if (csvContent.isEmpty) {
        Get.snackbar(
          'No Data',
          'No adjustment history data to export',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName =
          'stock_adjustment_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Stock Adjustment History Export',
        subject:
            'Stock Adjustment History - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
      );

      Get.snackbar(
        'Export Successful',
        'Stock adjustment history exported successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Failed to export data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showAdjustmentDetails(StockAdjustmentHistory adjustment) {
    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getAdjustmentIcon(adjustment.adjustmentType),
                    color: _getAdjustmentColor(adjustment.adjustmentType),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Adjustment Details',
                      style: Get.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Product', adjustment.productName),
              _buildDetailRow('Category', adjustment.categoryName),
              _buildDetailRow(
                'Adjustment Type',
                adjustment.adjustmentTypeDisplay,
              ),
              _buildDetailRow(
                'Previous Quantity',
                adjustment.previousQuantity.toStringAsFixed(2),
              ),
              _buildDetailRow(
                'Quantity Adjusted',
                adjustment.quantityAdjustedDisplay,
              ),
              _buildDetailRow(
                'New Quantity',
                adjustment.newQuantity.toStringAsFixed(2),
              ),
              _buildDetailRow('Reason', adjustment.reason),
              _buildDetailRow(
                'Date',
                DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(adjustment.adjustmentDate),
              ),
              _buildDetailRow('User', adjustment.userName),
              if (adjustment.notes != null && adjustment.notes!.isNotEmpty)
                _buildDetailRow('Notes', adjustment.notes!),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Stock Adjustment History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B4513),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        actions: [
          IconButton(
            onPressed: _isExporting ? null : _exportToCsv,
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.file_download),
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCategoryFilter()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProductFilter()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDateRangeFilter()),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // History list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Categories'),
        ),
        ..._inventoryService.categories.map(
          (category) => DropdownMenuItem<String>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: (value) async {
        setState(() {
          _selectedCategoryId = value;
          // Reset product filter when category changes
          if (value != null) {
            _selectedProductId = null;
          }
        });
        await _applyFilters();
      },
    );
  }

  Widget _buildProductFilter() {
    final availableProducts =
        _selectedCategoryId != null
            ? _inventoryService.products
                .where((p) => p.categoryId == _selectedCategoryId)
                .toList()
            : _inventoryService.products;

    return DropdownButtonFormField<String>(
      value: _selectedProductId,
      decoration: const InputDecoration(
        labelText: 'Product',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Products'),
        ),
        ...availableProducts.map(
          (product) => DropdownMenuItem<String>(
            value: product.id,
            child: Text(product.name),
          ),
        ),
      ],
      onChanged: (value) async {
        setState(() {
          _selectedProductId = value;
        });
        await _applyFilters();
      },
    );
  }

  Widget _buildDateRangeFilter() {
    return InkWell(
      onTap: _selectDateRange,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date Range',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDateRange == null
                  ? 'All Dates'
                  : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
              style: TextStyle(
                color:
                    _selectedDateRange == null
                        ? Colors.grey[600]
                        : Colors.black,
              ),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No adjustment history found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'Try adjusting your filters or clear them to see all history'
                : 'Stock adjustments will appear here once they are made',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategoryId != null ||
        _selectedProductId != null ||
        _selectedDateRange != null;
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredHistory.length,
        itemBuilder: (context, index) {
          final adjustment = _filteredHistory[index];
          return _buildHistoryCard(adjustment);
        },
      ),
    );
  }

  Widget _buildHistoryCard(StockAdjustmentHistory adjustment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAdjustmentDetails(adjustment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getAdjustmentColor(
                        adjustment.adjustmentType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getAdjustmentIcon(adjustment.adjustmentType),
                      color: _getAdjustmentColor(adjustment.adjustmentType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adjustment.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          adjustment.categoryName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        adjustment.quantityAdjustedDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _getAdjustmentColor(adjustment.adjustmentType),
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM dd, HH:mm',
                        ).format(adjustment.adjustmentDate),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuantityInfo(
                      'Previous',
                      adjustment.previousQuantity.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuantityInfo(
                      'New',
                      adjustment.newQuantity.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuantityInfo(
                      'Type',
                      adjustment.adjustmentTypeDisplay,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    adjustment.userName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      adjustment.reason,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  IconData _getAdjustmentIcon(String adjustmentType) {
    switch (adjustmentType) {
      case 'increase':
        return Icons.add_circle;
      case 'decrease':
        return Icons.remove_circle;
      case 'correction':
        return Icons.edit;
      default:
        return Icons.help;
    }
  }

  Color _getAdjustmentColor(String adjustmentType) {
    switch (adjustmentType) {
      case 'increase':
        return Colors.green;
      case 'decrease':
        return Colors.red;
      case 'correction':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
