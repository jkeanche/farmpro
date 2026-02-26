import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxString _selectedCategory = 'all'.obs;
  final RxString _selectedStockStatus = 'all'.obs;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Stock Adjustment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B4513),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventoryController.refreshInventoryData(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterSection(),
          _buildStockStatusSummary(),
          Expanded(child: _buildProductsList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    final inventoryController = Get.find<InventoryController>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) => _searchQuery.value = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    value: _selectedCategory.value,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Categories'),
                      ),
                      ...inventoryController.categories.map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => _selectedCategory.value = value ?? 'all',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => DropdownButtonFormField<String>(
                    value: _selectedStockStatus.value,
                    decoration: const InputDecoration(
                      labelText: 'Stock Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Products'),
                      ),
                      DropdownMenuItem(value: 'low', child: Text('Low Stock')),
                      DropdownMenuItem(
                        value: 'out',
                        child: Text('Out of Stock'),
                      ),
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Normal Stock'),
                      ),
                    ],
                    onChanged:
                        (value) => _selectedStockStatus.value = value ?? 'all',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatusSummary() {
    final inventoryController = Get.find<InventoryController>();

    return Obx(() {
      final lowStockCount = inventoryController.lowStockProducts.length;
      final outOfStockCount = inventoryController.outOfStockProducts.length;
      final totalProducts = inventoryController.products.length;
      final totalStockValue = inventoryController.totalStockValue;

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildSummaryItem(
                  'Total Products',
                  totalProducts.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Low Stock',
                  lowStockCount.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Out of Stock',
                  outOfStockCount.toString(),
                  Icons.remove_circle,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.attach_money, color: Color(0xFF8B4513)),
                  const SizedBox(width: 8),
                  Text(
                    'Total Stock Value: KSh ${totalStockValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    final inventoryController = Get.find<InventoryController>();

    return Obx(() {
      final products = _getFilteredProducts();

      if (products.isEmpty) {
        return const EmptyState(
          icon: Icons.inventory,
          title: 'No Products Found',
          message: 'Try adjusting your search or filter criteria.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final stock = inventoryController.getProductStock(product.id);
          return _buildProductCard(product, stock);
        },
      );
    });
  }

  List<Product> _getFilteredProducts() {
    final inventoryController = Get.find<InventoryController>();
    var products = inventoryController.products.toList();

    if (_searchQuery.value.isNotEmpty) {
      products =
          products
              .where(
                (product) =>
                    product.name.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    ) ||
                    (product.description?.toLowerCase().contains(
                          _searchQuery.value.toLowerCase(),
                        ) ??
                        false) ||
                    (product.barcode?.contains(_searchQuery.value) ?? false) ||
                    (product.sku?.toLowerCase().contains(
                          _searchQuery.value.toLowerCase(),
                        ) ??
                        false),
              )
              .toList();
    }

    if (_selectedCategory.value != 'all') {
      products =
          products
              .where((product) => product.categoryId == _selectedCategory.value)
              .toList();
    }

    if (_selectedStockStatus.value != 'all') {
      products =
          products.where((product) {
            final stock = inventoryController.getProductStock(product.id);
            final currentStock = stock?.currentStock ?? 0.0;

            switch (_selectedStockStatus.value) {
              case 'low':
                return product.minimumStock != null &&
                    currentStock > 0 &&
                    currentStock <= product.minimumStock!;
              case 'out':
                return currentStock == 0;
              case 'normal':
                return product.minimumStock == null ||
                    currentStock > product.minimumStock!;
              default:
                return true;
            }
          }).toList();
    }

    return products;
  }

  Widget _buildProductCard(Product product, Stock? stock) {
    final currentStock = stock?.currentStock ?? 0.0;
    final stockStatus = _getStockStatus(product, currentStock);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: stockStatus['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory,
                    color: stockStatus['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (product.canBeSplit)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SPLITTABLE',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (product.isSplitProduct)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SPLIT',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (product.description?.isNotEmpty ?? false)
                        Text(
                          product.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if (product.isSplitProduct &&
                          product.originalPackSize != null)
                        Text(
                          'Original: ${product.originalPackSize!.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stockStatus['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stockStatus['label'],
                    style: TextStyle(
                      fontSize: 10,
                      color: stockStatus['color'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStockInfo(
                    'Current Stock',
                    '${currentStock.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                    stockStatus['color'],
                  ),
                ),
                if (product.minimumStock != null)
                  Expanded(
                    child: _buildStockInfo(
                      'Min Stock',
                      '${product.minimumStock!.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                      Colors.orange,
                    ),
                  ),
                Expanded(
                  child: _buildStockInfo(
                    'Value',
                    'KSh ${((product.costPrice ?? product.salesPrice) * currentStock).toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _showStockAdjustmentDialog(product, 'IN'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('In', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _showStockAdjustmentDialog(product, 'OUT'),
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('Out', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B4513),
                      side: const BorderSide(color: Color(0xFF8B4513)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed:
                        () => _showStockAdjustmentDialog(product, 'ADJUSTMENT'),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Adjust', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showStockHistoryDialog(product),
                  icon: const Icon(Icons.history, color: Color(0xFF8B4513)),
                  tooltip: 'View History',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStockStatus(Product product, double currentStock) {
    if (currentStock == 0) {
      return {'label': 'Out of Stock', 'color': Colors.red};
    } else if (product.minimumStock != null &&
        currentStock <= product.minimumStock!) {
      return {'label': 'Low Stock', 'color': Colors.orange};
    } else {
      return {'label': 'In Stock', 'color': Colors.green};
    }
  }

  void _showStockAdjustmentDialog(Product product, String type) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final reasonController = TextEditingController();
    final inventoryController = Get.find<InventoryController>();

    String movementType = type == 'ADJUSTMENT' ? 'IN' : type;
    final RxString selectedMovementType = movementType.obs;

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(Get.context!).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      type == 'IN'
                          ? Icons.add_circle
                          : type == 'OUT'
                          ? Icons.remove_circle
                          : Icons.tune,
                      color:
                          type == 'IN'
                              ? Colors.green
                              : type == 'OUT'
                              ? Colors.red
                              : const Color(0xFF8B4513),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'IN'
                                ? 'Stock In'
                                : type == 'OUT'
                                ? 'Stock Out'
                                : 'Stock Adjustment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                if (type == 'ADJUSTMENT')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjustment Type:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text(
                                  'Increase',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: 'IN',
                                groupValue: selectedMovementType.value,
                                onChanged:
                                    (value) =>
                                        selectedMovementType.value = value!,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text(
                                  'Decrease',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: 'OUT',
                                groupValue: selectedMovementType.value,
                                onChanged:
                                    (value) =>
                                        selectedMovementType.value = value!,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                TextFormField(
                  controller: quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity (${product.unitOfMeasureName})',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      type == 'IN' ||
                              (type == 'ADJUSTMENT' &&
                                  selectedMovementType.value == 'IN')
                          ? Icons.add
                          : Icons.remove,
                      color:
                          type == 'IN' ||
                                  (type == 'ADJUSTMENT' &&
                                      selectedMovementType.value == 'IN')
                              ? Colors.green
                              : Colors.red,
                    ),
                    helperText:
                        'Enter the quantity to ${type == 'IN'
                            ? 'add'
                            : type == 'OUT'
                            ? 'remove'
                            : 'adjust'}',
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                    helperText: 'Reason for this adjustment (required)',
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
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
                        backgroundColor:
                            type == 'IN'
                                ? Colors.green
                                : type == 'OUT'
                                ? Colors.red
                                : const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed:
                          () => _performStockAdjustment(
                            product,
                            quantityController,
                            reasonController,
                            notesController,
                            type == 'ADJUSTMENT'
                                ? selectedMovementType.value
                                : type,
                          ),
                      child: Text(
                        type == 'IN'
                            ? 'Add'
                            : type == 'OUT'
                            ? 'Remove'
                            : 'Adjust',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performStockAdjustment(
    Product product,
    TextEditingController quantityController,
    TextEditingController reasonController,
    TextEditingController notesController,
    String movementType,
  ) async {
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

    if (reasonController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please provide a reason for this adjustment',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final inventoryController = Get.find<InventoryController>();
    final notes =
        '${reasonController.text.trim()}${notesController.text.trim().isNotEmpty ? ' - ${notesController.text.trim()}' : ''}';

    try {
      final success = await inventoryController.adjustStock(
        productId: product.id,
        quantity: quantity,
        movementType: movementType,
        notes: notes,
      );

      if (success) {
        // Close the dialog (and any overlay) immediately after adjustment
        Get.back(closeOverlays: true);

        // Force update of the stock display
        setState(() {});
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to adjust stock: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
              Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF8B4513)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Movement History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (movements.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No stock movements found',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
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
                            backgroundColor:
                                isIncoming ? Colors.green : Colors.red,
                            child: Icon(
                              isIncoming ? Icons.add : Icons.remove,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${isIncoming ? '+' : '-'}${movement.quantity.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isIncoming ? Colors.green : Colors.red,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Balance: ${movement.balanceAfter.toStringAsFixed(1)}',
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
