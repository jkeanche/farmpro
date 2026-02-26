import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/controllers.dart';
import '../../dialogs/stock_adjustment_dialog.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
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
                  Container(height: 40, width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      'Active Products',
                      inventoryController.products
                          .where((p) => p.isActive)
                          .length
                          .toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Products list
            Expanded(
              child:
                  inventoryController.products.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: inventoryController.products.length,
                        itemBuilder: (context, index) {
                          final product = inventoryController.products[index];
                          final stock = inventoryController.getProductStock(
                            product.id,
                          );
                          return _buildProductCard(product, stock);
                        },
                      ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        onPressed: () => _showAddProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Products Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first product',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, Stock? stock) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B4513).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              product.categoryName ?? 'No Category',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B4513),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!product.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleProductAction(value, product),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, size: 20),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'stock',
                          child: ListTile(
                            leading: Icon(Icons.warehouse, size: 20),
                            title: Text('Adjust Stock'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (product.canBeSplit)
                          const PopupMenuItem(
                            value: 'split',
                            child: ListTile(
                              leading: Icon(
                                Icons.content_cut,
                                size: 20,
                                color: Colors.orange,
                              ),
                              title: Text(
                                'Split Product',
                                style: TextStyle(color: Colors.orange),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: ListTile(
                            leading: Icon(Icons.block, size: 20),
                            title: Text('Deactivate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Price',
                    'KSh ${product.salesPrice.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.straighten, size: 18, color: Colors.grey),
                      const SizedBox(height: 4),
                      const Text('Pack Sizes', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: product.packSizes.map((size) => 
                          Text(
                            size.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        ).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Stock',
                    stock != null
                        ? stock.currentStock.toStringAsFixed(1)
                        : '0.0',
                    Icons.inventory,
                    color: _getStockColor(
                      stock?.currentStock ?? 0,
                      product.minimumStock,
                    ),
                  ),
                ),
              ],
            ),
            if (product.barcode != null || product.sku != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (product.barcode != null) ...[
                    Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      product.barcode!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (product.sku != null) ...[
                    if (product.barcode != null) const SizedBox(width: 16),
                    Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      product.sku!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStockColor(double currentStock, double? minimumStock) {
    if (minimumStock == null) return Colors.grey[600]!;
    if (currentStock <= minimumStock * 0.5) return Colors.red;
    if (currentStock <= minimumStock) return Colors.orange;
    return Colors.green;
  }

  void _handleProductAction(String action, Product product) {
    switch (action) {
      case 'edit':
        _showEditProductDialog(product);
        break;
      case 'stock':
        _showStockAdjustmentDialog(product);
        break;
      case 'split':
        _showSplitProductDialog(product);
        break;
      case 'delete':
        _showDeleteProductDialog(product);
        break;
      case 'deactivate':
        _showDeactivateDialog(product);
        break;
    }
  }

  void _showAddProductDialog() {
    final inventoryController = Get.find<InventoryController>();
    inventoryController.showProductForm();

    Get.dialog(
      Dialog(
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(Get.context!).size.height * 0.9,
            minHeight: 300,
          ),
          padding: const EdgeInsets.all(16),
          child: _buildProductForm(isEdit: false),
        ),
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final inventoryController = Get.find<InventoryController>();

    // Pre-fill form with product data
    inventoryController.productNameController.text = product.name;
    inventoryController.productDescriptionController.text =
        product.description ?? '';
    inventoryController.packSizeController.clear();
    inventoryController.salesPriceController.text =
        product.salesPrice.toString();
    inventoryController.costPriceController.text =
        product.costPrice?.toString() ?? '';
    inventoryController.minimumStockController.text =
        product.minimumStock?.toString() ?? '';
    inventoryController.barcodeController.text = product.barcode ?? '';
    inventoryController.skuController.text = product.sku ?? '';
    
    // Set pack sizes
    inventoryController.packSizes.clear();
    inventoryController.packSizes.addAll(product.packSizes);

    // Set selected values
    inventoryController.selectedCategory.value = inventoryController.categories
        .firstWhereOrNull((c) => c.id == product.categoryId);
    inventoryController.selectedUnit.value = inventoryController.units
        .firstWhereOrNull((u) => u.id == product.unitOfMeasureId);
    inventoryController.allowPartialSales.value = product.allowPartialSales;
    inventoryController.canBeSplit.value = product.canBeSplit;

    Get.dialog(
      Dialog(
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(Get.context!).size.height * 0.9,
            minHeight: 300,
          ),
          padding: const EdgeInsets.all(16),
          child: _buildProductForm(isEdit: true, product: product),
        ),
      ),
    );
  }

  Widget _buildProductForm({required bool isEdit, Product? product}) {
    final inventoryController = Get.find<InventoryController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEdit ? 'Edit Product' : 'Add New Product',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Product Name
                TextFormField(
                  controller: inventoryController.productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ), // Reduced padding
                  ),
                ),
                const SizedBox(height: 14), // Reduced from 16 to 14
                // Description
                TextFormField(
                  controller: inventoryController.productDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ), // Reduced padding
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14), // Reduced from 16 to 14
                // Category and Unit Row
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<ProductCategory>(
                          value: inventoryController.selectedCategory.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ), // Reduced padding
                          ),
                          items:
                              inventoryController.categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category.name),
                                );
                              }).toList(),
                          onChanged:
                              (value) => inventoryController
                                  .setSelectedCategory(value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // Reduced from 16 to 12
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<UnitOfMeasure>(
                          value: inventoryController.selectedUnit.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ), // Reduced padding
                          ),
                          items:
                              inventoryController.units.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    '${unit.name} (${unit.abbreviation})',
                                  ),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  inventoryController.setSelectedUnit(value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14), // Reduced from 16 to 14
                // Pack Sizes List
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pack Sizes *',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: inventoryController.packSizeController,
                            decoration: const InputDecoration(
                              labelText: 'Add Pack Size',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              hintText: 'Enter pack size (e.g., 10, 20, 40)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4513),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          onPressed: () {
                            final val = double.tryParse(
                              inventoryController.packSizeController.text,
                            );
                            if (val != null && val > 0) {
                              if (!inventoryController.packSizes.contains(val)) {
                                inventoryController.addPackSize(val);
                                inventoryController.packSizeController.clear();
                              } else {
                                Get.snackbar(
                                  'Duplicate',
                                  'Pack size already exists',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              }
                            } else {
                              Get.snackbar(
                                'Invalid',
                                'Please enter a valid pack size',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        child: inventoryController.packSizes.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pack sizes added',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: 
                                    inventoryController.packSizes.map((size) {
                                  return Chip(
                                    label: Text(
                                      '${size.toStringAsFixed(0)} ${inventoryController.selectedUnit.value?.abbreviation ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () =>
                                        inventoryController.removePackSize(size),
                                    backgroundColor: Colors.grey[100],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    if (inventoryController.packSizes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          'At least one pack size is required',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Sales Price and Cost Price Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller:
                                inventoryController.salesPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Sales Price (KSh) *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: inventoryController.costPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Cost Price (KSh)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Min Stock and Initial Stock Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: inventoryController.minimumStockController,
                        decoration: const InputDecoration(
                          labelText: 'Min Stock',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Initial Stock Quantity (only for new products)
                    if (!isEdit)
                      Expanded(
                        child: TextFormField(
                          controller:
                              inventoryController.initialStockController,
                          decoration: const InputDecoration(
                            labelText: 'Initial Stock *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            helperText: 'Starting stock quantity',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      )
                    else
                      const Expanded(
                        child: SizedBox(),
                      ), // Empty space for edit mode
                  ],
                ),
                const SizedBox(height: 14),
                // Current Stock Display (only for edit mode)
                if (isEdit) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${inventoryController.getProductStock(product?.id ?? '')?.currentStock.toStringAsFixed(1) ?? '0.0'} ${inventoryController.selectedUnit.value?.abbreviation ?? ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Get.back(); // Close product dialog
                            // Navigate to stock adjustment
                            if (product != null) {
                              final stock = inventoryController.getProductStock(
                                product.id,
                              );
                              if (stock != null) {
                                // Show stock adjustment dialog
                                // This would need to be implemented
                              }
                            }
                          },
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text(
                            'Adjust',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Barcode and SKU Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: inventoryController.barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ), // Reduced padding
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // Reduced from 16 to 12
                    Expanded(
                      child: TextFormField(
                        controller: inventoryController.skuController,
                        decoration: const InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ), // Reduced padding
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14), // Reduced from 16 to 14
                // Partial sales feature disabled

                // Can Be Split (visible only in edit mode for now)
                if (isEdit)
                  // Obx(
                  //   () => CheckboxListTile(
                  //     title: const Text('Can Be Split'),
                  //     subtitle: const Text(
                  //       'Product can be split into smaller packs during sales',
                  //     ),
                  //     value: inventoryController.canBeSplit.value,
                  //     onChanged:
                  //         (value) =>
                  //             inventoryController.canBeSplit.value =
                  //                 value ?? false,
                  //     controlAffinity: ListTileControlAffinity.leading,
                  //   ),
                  // ),
              ],
            ),
          ),
        ),

        // Error message
        Obx(() {
          if (inventoryController.error.value.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                inventoryController.error.value,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        const SizedBox(height: 16),

        // Action buttons - wrapped in SafeArea to prevent keyboard overlap
        SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Obx(
                  () => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        inventoryController.isLoading.value
                            ? null
                            : () async {
                              try {
                                final success =
                                    isEdit
                                        ? await _updateProduct(product!)
                                        : await inventoryController
                                            .addProduct();
                                if (success) {
                                  Get.back();
                                }
                              } catch (e) {
                                Get.snackbar(
                                  'Error',
                                  'Failed to save product: $e',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                              }
                            },
                    child:
                        inventoryController.isLoading.value
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(isEdit ? 'Update' : 'Add'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _updateProduct(Product product) async {
    final inventoryController = Get.find<InventoryController>();
    final inventoryService = Get.find<InventoryService>();

    if (!_validateProductForm(inventoryController)) return false;

    inventoryController.isLoading.value = true;
    inventoryController.error.value = '';

    try {
      final updatedProduct = product.copyWith(
        name: inventoryController.productNameController.text.trim(),
        description:
            inventoryController.productDescriptionController.text.trim().isEmpty
                ? null
                : inventoryController.productDescriptionController.text.trim(),
        categoryId: inventoryController.selectedCategory.value!.id,
        categoryName: inventoryController.selectedCategory.value!.name,
        unitOfMeasureId: inventoryController.selectedUnit.value!.id,
        unitOfMeasureName: inventoryController.selectedUnit.value!.name,
        packSize: double.parse(inventoryController.packSizeController.text),
        salesPrice: double.parse(inventoryController.salesPriceController.text),
        costPrice:
            inventoryController.costPriceController.text.trim().isEmpty
                ? null
                : double.parse(inventoryController.costPriceController.text),
        minimumStock:
            inventoryController.minimumStockController.text.trim().isEmpty
                ? null
                : double.parse(inventoryController.minimumStockController.text),
        barcode:
            inventoryController.barcodeController.text.trim().isEmpty
                ? null
                : inventoryController.barcodeController.text.trim(),
        sku:
            inventoryController.skuController.text.trim().isEmpty
                ? null
                : inventoryController.skuController.text.trim(),
        allowPartialSales: inventoryController.allowPartialSales.value,
        canBeSplit: inventoryController.canBeSplit.value,
        updatedAt: DateTime.now(),
      );

      final result = await inventoryService.updateProduct(updatedProduct);

      if (result['success']) {
        Get.snackbar(
          'Success',
          'Product updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      inventoryController.error.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      inventoryController.isLoading.value = false;
    }
  }

  bool _validateProductForm(InventoryController controller) {
    if (controller.productNameController.text.trim().isEmpty) {
      controller.error.value = 'Product name is required';
      return false;
    }

    if (controller.selectedCategory.value == null) {
      controller.error.value = 'Please select a category';
      return false;
    }

    if (controller.selectedUnit.value == null) {
      controller.error.value = 'Please select a unit of measure';
      return false;
    }

    if (controller.packSizeController.text.trim().isEmpty) {
      controller.error.value = 'Pack size is required';
      return false;
    }

    final packSize = double.tryParse(controller.packSizeController.text);
    if (packSize == null || packSize <= 0) {
      controller.error.value = 'Please enter a valid pack size';
      return false;
    }

    if (controller.salesPriceController.text.trim().isEmpty) {
      controller.error.value = 'Sales price is required';
      return false;
    }

    final salesPrice = double.tryParse(controller.salesPriceController.text);
    if (salesPrice == null || salesPrice <= 0) {
      controller.error.value = 'Please enter a valid sales price';
      return false;
    }

    return true;
  }

  void _showStockAdjustmentDialog(Product product) async {
    final inventoryController = Get.find<InventoryController>();

    // Validate product ID early to avoid invalid fetches
    if (product.id.isEmpty) {
      _showErrorSnackbar('Invalid product selected for stock adjustment.');
      return;
    }

    // Fetch or initialize stock (handles null proactively)
    final currentStock = await _getOrInitializeStock(
      product.id,
      inventoryController,
    );
    if (currentStock == null) {
      // Fallback if initialization failed
      _showErrorSnackbar(
        'Failed to load or create stock for "${product.name}". Please try refreshing inventory.',
      );
      return;
    }

    final result = await Get.dialog<bool>(
      StockAdjustmentDialog(product: product, stock: currentStock),
    );

    // Refresh inventory data if adjustment was successful
    if (result == true) {
      await inventoryController.refreshInventoryData();
    }
  }

  Future<Stock?> _getOrInitializeStock(
    String productId,
    InventoryController controller,
  ) async {
    try {
      var stock = controller.getProductStock(productId);
      if (stock != null) {
        return stock; // Stock exists, return it
      }

      // Edge case: No stock record (e.g., new product). Initialize via adjustStock
      print(
        'No stock found for product $productId. Initializing default entry...',
      ); // Logging for debugging
      final inventoryService = Get.find<InventoryService>();

      final result = await inventoryService.adjustStock(
        productId: productId,
        quantity: 0.0,
        movementType: 'IN',
        notes: 'Default stock initialization',
        userId: null,
        userName: null,
      );

      if (result['success'] == true) {
        // Refresh controller to include new stock
        await controller.refreshInventoryData();
        stock = controller.getProductStock(productId);
        print('Default stock initialized successfully for product $productId.');
        return stock;
      } else {
        print('Failed to initialize default stock: ${result['error']}');
        return null;
      }
    } catch (e) {
      print('Error fetching/initializing stock for $productId: $e');
      return null;
    }
  }

  // Reusable helper for error snackbars
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Stock Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      icon: const Icon(Icons.warning, color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }

  void _showDeleteProductDialog(Product product) async {
    final inventoryController = Get.find<InventoryController>();

    // Check if product can be deleted
    final canDelete = await inventoryController.canDeleteProduct(product.id);

    if (!canDelete) {
      final salesHistory = await inventoryController.getProductSalesHistory(
        product.id,
      );

      Get.dialog(
        AlertDialog(
          title: const Text('Cannot Delete Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cannot delete product "${product.name}" because it exists in sales history.',
              ),
              const SizedBox(height: 10),
              Text('Total sales records: ${salesHistory.length}'),
              const SizedBox(height: 10),
              const Text(
                'You can deactivate the product instead to hide it from new sales while preserving history.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Get.back();
                _showDeactivateDialog(product);
              },
              child: const Text('Deactivate Instead'),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back(); // Close dialog

              final success = await inventoryController.deleteProduct(
                product.id,
              );
              if (success) {
                Get.snackbar(
                  'Success',
                  'Product "${product.name}" deleted successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(Product product) {
    Get.dialog(
      AlertDialog(
        title: const Text('Deactivate Product'),
        content: Text(
          'Are you sure you want to deactivate "${product.name}"?\n\nThis will hide the product from sales but preserve all historical data.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Implementation would require adding deactivation method to service
              Get.back();
              Get.snackbar(
                'Info',
                'Product deactivation feature will be implemented',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showSplitProductDialog(Product product) {
    final splitSizeController = TextEditingController();
    final inventoryController = Get.find<InventoryController>();
    final stock = inventoryController.getProductStock(product.id);

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.content_cut, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Split Product',
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

              // Product info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Pack Size: ${product.packSize.toStringAsFixed(1)} ${product.unitOfMeasureName}',
                    ),
                    Text(
                      'Current Price: KSh ${product.salesPrice.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Available Stock: ${stock?.currentStock.toStringAsFixed(1) ?? '0.0'} packs',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Note: Splitting will reduce one pack from current stock and create a new smaller pack product.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Split size input
              TextFormField(
                controller: splitSizeController,
                decoration: InputDecoration(
                  labelText: 'Split Size (${product.unitOfMeasureName})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(
                    Icons.straighten,
                    color: Colors.orange,
                  ),
                  helperText:
                      'Enter size to split from the pack (must be smaller than ${product.packSize.toStringAsFixed(1)})',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
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
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed:
                        () => _performSplit(product, splitSizeController),
                    child: const Text('Split Product'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performSplit(
    Product product,
    TextEditingController splitSizeController,
  ) async {
    final splitSize = double.tryParse(splitSizeController.text);
    if (splitSize == null || splitSize <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid split size',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (splitSize >= product.packSize) {
      Get.snackbar(
        'Error',
        'Split size must be smaller than pack size (${product.packSize.toStringAsFixed(1)})',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final inventoryController = Get.find<InventoryController>();
    final stock = inventoryController.getProductStock(product.id);

    if (stock == null || stock.currentStock < 1) {
      _showErrorSnackbar('Insufficient stock to split');
      return;
    }

    try {
      final success = await inventoryController.splitProduct(
        productId: product.id,
        splitSize: splitSize,
      );

      if (success) {
        Get.back(); // Close the dialog
        Get.snackbar(
          'Success',
          'Product split successfully! New product created with size ${splitSize.toStringAsFixed(1)} ${product.unitOfMeasureName}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to split product: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
