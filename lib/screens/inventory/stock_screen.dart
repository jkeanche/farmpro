import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../dialogs/stock_adjustment_dialog.dart';
import '../../models/models.dart';
import '../../services/inventory_service.dart';
import 'stock_adjustment_history_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxString _selectedFilter =
      'all'.obs; // all, low, out_of_stock, available

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryService = Get.find<InventoryService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Stock Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B4513),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        actions: [
          IconButton(
            onPressed: () {
              Get.to(() => const StockAdjustmentHistoryScreen());
            },
            icon: const Icon(Icons.history),
            tooltip: 'Stock Adjustment History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery.value = '';
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                Obx(
                  () => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Available', 'available'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Low Stock', 'low'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Out of Stock', 'out_of_stock'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stock list
          Expanded(
            child: Obx(() {
              final filteredStocks = _getFilteredStocks(
                inventoryService.stocks,
              );

              if (inventoryService.stocks.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No stock items found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add products to start managing stock',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              if (filteredStocks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items match your search',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery.value = '';
                          _selectedFilter.value = 'all';
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredStocks.length,
                itemBuilder: (context, index) {
                  final stock = filteredStocks[index];
                  return _buildStockCard(stock);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(Stock stock) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStockLevelColor(stock.currentStock),
          child: Text(
            stock.currentStock.toInt().toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          stock.productName ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${stock.availableStock.toStringAsFixed(2)}'),
            Text('Reserved: ${stock.reservedStock.toStringAsFixed(2)}'),
            Text(
              'Last Updated: ${DateFormat('MMM dd, yyyy').format(stock.lastUpdated)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stock.currentStock.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStockLevelColor(stock.currentStock),
                  ),
                ),
                Text(
                  'units',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showStockAdjustmentDialog(stock),
              icon: const Icon(Icons.edit),
              tooltip: 'Adjust Stock',
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustmentDialog(Stock stock) async {
    final inventoryService = Get.find<InventoryService>();

    // Find the product for this stock
    final product = inventoryService.products.firstWhereOrNull(
      (p) => p.id == stock.productId,
    );

    if (product == null) {
      Get.snackbar(
        'Error',
        'Product information not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final result = await Get.dialog<bool>(
      StockAdjustmentDialog(product: product, stock: stock),
    );

    // Refresh stock data if adjustment was successful
    if (result == true) {
      await inventoryService.loadStocks();
    }
  }

  Widget _buildFilterChip(String label, String value) {
    return Obx(
      () => FilterChip(
        label: Text(label),
        selected: _selectedFilter.value == value,
        onSelected: (selected) {
          _selectedFilter.value = selected ? value : 'all';
        },
        selectedColor: const Color(0xFF8B4513).withOpacity(0.2),
        checkmarkColor: const Color(0xFF8B4513),
      ),
    );
  }

  List<Stock> _getFilteredStocks(List<Stock> stocks) {
    var filtered =
        stocks.where((stock) {
          // Search filter
          final searchQuery = _searchQuery.value.toLowerCase();
          if (searchQuery.isNotEmpty) {
            final productName = (stock.productName ?? '').toLowerCase();
            if (!productName.contains(searchQuery)) {
              return false;
            }
          }

          // Stock level filter
          switch (_selectedFilter.value) {
            case 'available':
              return stock.currentStock > 10;
            case 'low':
              return stock.currentStock > 0 && stock.currentStock <= 10;
            case 'out_of_stock':
              return stock.currentStock <= 0;
            case 'all':
            default:
              return true;
          }
        }).toList();

    // Sort by stock level (critical items first)
    filtered.sort((a, b) {
      if (a.currentStock <= 0 && b.currentStock > 0) return -1;
      if (b.currentStock <= 0 && a.currentStock > 0) return 1;
      if (a.currentStock <= 10 && b.currentStock > 10) return -1;
      if (b.currentStock <= 10 && a.currentStock > 10) return 1;
      return (a.productName ?? '').compareTo(b.productName ?? '');
    });

    return filtered;
  }

  Color _getStockLevelColor(double quantity) {
    if (quantity <= 0) {
      return Colors.red;
    } else if (quantity <= 10) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
