import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';

class StockManagementScreen extends StatelessWidget {
  const StockManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      appBar: AppBar(
        title: const Text(
          'Stock Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF8B4513), // Brown theme
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventoryController.refreshInventoryData(),
          ),
        ],
      ),
      body: Obx(() {
        if (inventoryController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
            ),
          );
        }

        if (inventoryController.error.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${inventoryController.error.value}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => inventoryController.refreshInventoryData(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with stats
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Products',
                      inventoryController.products.length.toString(),
                      Icons.inventory,
                      const Color(0xFF8B4513),
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Low Stock',
                      _getLowStockCount().toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Out of Stock',
                      _getOutOfStockCount().toString(),
                      Icons.error,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            // Filter tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab('All', true),
                  ),
                  Expanded(
                    child: _buildFilterTab('Low Stock', false),
                  ),
                  Expanded(
                    child: _buildFilterTab('Out of Stock', false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stock list
            Expanded(
              child: inventoryController.products.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: inventoryController.products.length,
                      itemBuilder: (context, index) {
                        final product = inventoryController.products[index];
                        final stock = inventoryController.getProductStock(product.id);
                        return _buildStockCard(product, stock);
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterTab(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isSelected ? const Color(0xFF8B4513) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          onTap: () {
            // Implement filter functionality
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Products Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to manage stock',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(Product product, Stock? stock) {
    final currentStock = stock?.currentStock ?? 0.0;
    final stockStatus = _getStockStatus(currentStock, product.minimumStock);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.categoryName ?? 'No Category',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stock status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockStatus['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stockStatus['label'],
                    style: TextStyle(
                      fontSize: 12,
                      color: stockStatus['color'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Stock details
            Row(
              children: [
                Expanded(
                  child: _buildStockDetail(
                    'Current Stock',
                    '${currentStock.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                    Icons.inventory,
                    stockStatus['color'],
                  ),
                ),
                Expanded(
                  child: _buildStockDetail(
                    'Min Stock',
                    product.minimumStock != null 
                        ? '${product.minimumStock!.toStringAsFixed(1)} ${product.unitOfMeasureName}'
                        : 'Not set',
                    Icons.warning_outlined,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStockDetail(
                    'Max Stock',
                    product.maximumStock != null 
                        ? '${product.maximumStock!.toStringAsFixed(1)} ${product.unitOfMeasureName}'
                        : 'Not set',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: () => _showStockAdjustmentDialog(product, 'IN'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Stock In'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _showStockAdjustmentDialog(product, 'OUT'),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Stock Out'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showStockHistoryDialog(product),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockDetail(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, dynamic> _getStockStatus(double currentStock, double? minimumStock) {
    if (currentStock == 0) {
      return {'label': 'Out of Stock', 'color': Colors.red};
    } else if (minimumStock != null && currentStock <= minimumStock) {
      return {'label': 'Low Stock', 'color': Colors.orange};
    } else {
      return {'label': 'In Stock', 'color': Colors.green};
    }
  }

  int _getLowStockCount() {
    final inventoryController = Get.find<InventoryController>();
    return inventoryController.products.where((product) {
      final stock = inventoryController.getProductStock(product.id);
      final currentStock = stock?.currentStock ?? 0.0;
      return product.minimumStock != null && 
             currentStock > 0 && 
             currentStock <= product.minimumStock!;
    }).length;
  }

  int _getOutOfStockCount() {
    final inventoryController = Get.find<InventoryController>();
    return inventoryController.products.where((product) {
      final stock = inventoryController.getProductStock(product.id);
      return (stock?.currentStock ?? 0.0) == 0;
    }).length;
  }

  void _showStockAdjustmentDialog(Product product, String movementType) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final inventoryController = Get.find<InventoryController>();

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${movementType == 'IN' ? 'Stock In' : 'Stock Out'} - ${product.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Current stock info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Stock:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${inventoryController.getProductStock(product.id)?.currentStock.toStringAsFixed(1) ?? '0.0'} ${product.unitOfMeasureName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (${product.unitOfMeasureName})',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    movementType == 'IN' ? Icons.add : Icons.remove,
                    color: movementType == 'IN' ? Colors.green : Colors.red,
                  ),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: movementType == 'IN' ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final quantity = double.tryParse(quantityController.text);
                      if (quantity == null || quantity <= 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a valid quantity',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      final success = await inventoryController.adjustStock(
                        productId: product.id,
                        quantity: quantity,
                        movementType: movementType,
                        notes: notesController.text.trim().isEmpty 
                            ? null 
                            : notesController.text.trim(),
                      );

                      if (success) {
                        Get.back();
                      }
                    },
                    child: Text('${movementType == 'IN' ? 'Add' : 'Remove'} Stock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockHistoryDialog(Product product) async {
    final inventoryController = Get.find<InventoryController>();
    final movements = await inventoryController.getStockMovements(product.id);
    
    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock History - ${product.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              if (movements.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stock movements found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stock movements will appear here when you adjust stock',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: movements.length,
                    itemBuilder: (context, index) {
                      final movement = movements[index];
                      final isIncoming = movement.movementType == 'IN';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncoming ? Colors.green : Colors.red,
                            child: Icon(
                              isIncoming ? Icons.add : Icons.remove,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${isIncoming ? '+' : '-'}${movement.quantity} ${product.unitOfMeasureName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isIncoming ? Colors.green : Colors.red,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Balance: ${movement.balanceAfter}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${movement.movementDate.day}/${movement.movementDate.month}/${movement.movementDate.year} ${movement.movementDate.hour}:${movement.movementDate.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (movement.notes != null)
                                Text(
                                  movement.notes!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              if (movement.userName != null)
                                Text(
                                  'By: ${movement.userName}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),
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
}