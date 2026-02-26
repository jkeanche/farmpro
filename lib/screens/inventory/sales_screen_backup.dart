import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();
    final seasonController = Get.find<SeasonController>();

    // Controller for member number input when creating credit sales
    final TextEditingController memberNumberController =
        TextEditingController();

    Future<void> searchMemberByNumber() async {
      final number = memberNumberController.text.trim();
      if (number.isEmpty) {
        Get.snackbar(
          'Error',
          'Enter member number',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      final memberController = Get.find<MemberController>();
      final member = await memberController.getMemberByNumber(number);
      if (member != null) {
        Get.find<InventoryController>().setSelectedMember(member);
        Get.snackbar(
          'Member Selected',
          member.fullName,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Not Found',
          'Member not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      appBar: AppBar(
        title: const Text(
          'Create Sale',
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

        return Column(
          children: [
            // Season status warning
            Obx(() {
              if (!seasonController.canCreateSale) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cannot Create Sales',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              seasonController.saleBlockReason ??
                                  'No active season available',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/settings/season-management'),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
              }

              final activeSeason = seasonController.activeSeason;
              if (activeSeason != null) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Season: ${activeSeason.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        activeSeason.dateRangeText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            }),

            // Sale type and total header
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
              child: Column(
                children: [
                  // Sale type selection
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => RadioListTile<String>(
                            title: const Text('Cash'),
                            value: 'CASH',
                            groupValue: inventoryController.saleType.value,
                            onChanged: (value) =>
                                inventoryController.setSaleType(value!),
                            dense: true,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Obx(
                          () => RadioListTile<String>(
                            title: const Text('Credit'),
                            value: 'CREDIT',
                            groupValue: inventoryController.saleType.value,
                            onChanged: (value) =>
                                inventoryController.setSaleType(value!),
                            dense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(),

                  // Member selection for credit sales
                  Obx(() {
                    if (inventoryController.saleType.value == 'CREDIT') {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: memberNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Member Number',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B4513),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: searchMemberByNumber,
                                child: const Icon(Icons.search, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  // Total amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Obx(
                        () => Text(
                          'KSh ${inventoryController.totalAmount.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B4513),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Products section
            Expanded(child: _buildProductsSection(context)),

            // Cart Summary and Complete Sale Button
            _buildBottomSection(context),
          ],
        );
      }),
    );
  }

  Widget _buildProductsSection(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),

            // Products grid with responsive design
            inventoryController.products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                      double childAspectRatio = constraints.maxWidth > 600
                          ? 1.0
                          : 1.2;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: inventoryController.products.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final product = inventoryController.products[index];
                          final stock = inventoryController.getProductStock(
                            product.id,
                          );
                          return _buildProductCard(product, stock);
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, Stock? stock) {
    final hasStock = stock != null && stock.currentStock > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: hasStock ? () => _showAddToCartDialog(product) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hasStock ? null : Colors.grey[100],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: hasStock ? Colors.black : Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Category
              Text(
                product.categoryName ?? 'No Category',
                style: TextStyle(
                  fontSize: 11,
                  color: hasStock ? Colors.grey[600] : Colors.grey[400],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),

              // Price and stock
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'KSh ${product.salesPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasStock ? const Color(0xFF8B4513) : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: hasStock
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasStock
                            ? stock.currentStock.toStringAsFixed(1)
                            : 'Out',
                        style: TextStyle(
                          fontSize: 10,
                          color: hasStock ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Add button
              if (hasStock)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 30), // Slightly reduced height
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 12),
                    label: const Text('Add', style: TextStyle(fontSize: 11)),
                    onPressed: () => _showAddToCartDialog(product),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleItemCard(SaleItem saleItem, int index) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 6,
      ), // Reduced margin for compact design
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(
          10,
        ), // Reduced padding to prevent overflow
        child: Column(
          children: [
            // First row: Product name and price
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    saleItem.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // Prevent text overflow
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'KSh ${saleItem.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Second row: Quantity details and actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${saleItem.quantity.toStringAsFixed(1)} × KSh ${saleItem.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons with flexible layout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit button
                    GestureDetector(
                      onTap: () => _showEditQuantityDialog(saleItem, index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Remove button
                    GestureDetector(
                      onTap: () =>
                          Get.find<InventoryController>().removeSaleItem(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cart Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              if (inventoryController.saleItems.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cart is empty',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B4513).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          color: Color(0xFF8B4513),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cart Summary',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B4513),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${inventoryController.saleItems.length} items',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Total Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'KSh ${inventoryController.totalAmount.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B4513),
                          ),
                        ),
                      ],
                    ),

                    // Quick item preview (first 2 items)
                    if (inventoryController.saleItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Column(
                        children: inventoryController.saleItems.take(2).map((
                          item,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.quantity.toStringAsFixed(1)} × KSh ${item.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (inventoryController.saleItems.length > 2)
                        Text(
                          '+ ${inventoryController.saleItems.length - 2} more items...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            }),
          ),

          // Complete Sale Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: inventoryController.saleItems.isEmpty ? 0 : 2,
                  ),
                  icon: inventoryController.isLoading.value
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
                      : Icon(
                          inventoryController.saleItems.isEmpty
                              ? Icons.shopping_cart_outlined
                              : Icons.shopping_cart_checkout,
                          size: 20,
                        ),
                  label: Text(
                    inventoryController.isLoading.value
                        ? 'Processing...'
                        : inventoryController.saleItems.isEmpty
                        ? 'Add items to cart'
                        : 'Review Cart & Complete Sale',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed:
                      inventoryController.saleItems.isEmpty ||
                          inventoryController.isLoading.value
                      ? null
                      : () => _showCartDialog(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToCartDialog(Product product) {
    final quantityController = TextEditingController();
    final inventoryController = Get.find<InventoryController>();
    final stock = inventoryController.getProductStock(product.id);
    final RxDouble selectedPackSize =
        (product.packSizes.isNotEmpty
                ? product.packSizes.first
                : product.packSize)
            .obs;

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
                'Add ${product.name} to Cart',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                      'Price: KSh ${product.salesPrice.toStringAsFixed(2)} per pack',
                    ),
                    Text(
                      'Pack Size: ${selectedPackSize.value} ${product.unitOfMeasureName}',
                    ),
                    Text(
                      'Available Stock: ${stock?.currentStock.toStringAsFixed(1) ?? '0.0'}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantity input
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (${product.unitOfMeasureName})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Pack size selection
              if (product.packSizes.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Pack Size'),
                    const SizedBox(height: 8),
                    Obx(
                      () => DropdownButton<double>(
                        value: selectedPackSize.value,
                        isExpanded: true,
                        items: product.packSizes
                            .map(
                              (size) => DropdownMenuItem<double>(
                                value: size,
                                child: Text(
                                  '${size.toStringAsFixed(0)} ${product.unitOfMeasureName}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            selectedPackSize.value = val ?? product.packSize,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  if (product.canBeSplit)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Get.back();
                        _showSplitAndAddDialog(product);
                      },
                      child: const Text('Split & Add'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
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

                      if (quantity > (stock?.currentStock ?? 0)) {
                        Get.snackbar(
                          'Error',
                          'Insufficient stock available',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      inventoryController.addSaleItem(
                        product,
                        quantity,
                        selectedPackSize.value,
                      );
                      Get.back();
                    },
                    child: const Text('Add to Cart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditQuantityDialog(SaleItem saleItem, int index) {
    final quantityController = TextEditingController(
      text: saleItem.quantity.toString(),
    );
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
                'Edit Quantity - ${saleItem.productName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Quantity input
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
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
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
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

                      inventoryController.updateSaleItemQuantity(
                        index,
                        quantity,
                      );
                      Get.back();
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberSelection() {
    final memberController = Get.find<MemberController>();

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  // Implement search
                },
              ),
              const SizedBox(height: 16),

              // Members list
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    itemCount: memberController.activeMembers.length,
                    itemBuilder: (context, index) {
                      final member = memberController.activeMembers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF8B4513),
                          child: Text(
                            member.fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(member.fullName),
                        subtitle: Text('Member #${member.memberNumber}'),
                        onTap: () {
                          Get.find<InventoryController>().setSelectedMember(
                            member,
                          );
                          Get.back();
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCartDialog() {
    final inventoryController = Get.find<InventoryController>();

    Get.dialog(
      Dialog(
        child: Container(
          width: MediaQuery.of(Get.context!).size.width * 0.9,
          height: MediaQuery.of(Get.context!).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: Color(0xFF8B4513),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Shopping Cart',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),

              // Sale type display (read-only)
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF8B4513),
                  ),
                  const SizedBox(width: 6),
                  Obx(
                    () => Text(
                      'Sale Type: ${inventoryController.saleType.value}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                  ),
                ],
              ),

              // Member selection for credit sales
              Obx(() {
                if (inventoryController.saleType.value == 'CREDIT') {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inventoryController.selectedMember.value != null
                                  ? 'Member: ${inventoryController.selectedMember.value!.fullName}'
                                  : 'Select Member for Credit Sale',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color:
                                    inventoryController.selectedMember.value !=
                                        null
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B4513),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showMemberSelection(),
                            child: const Text('Select Member'),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: 16),

              // Total amount
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
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Obx(
                      () => Text(
                        'KSh ${inventoryController.totalAmount.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cart items
              Expanded(
                child: Obx(() {
                  if (inventoryController.saleItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cart is empty',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add products to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: inventoryController.saleItems.length,
                    itemBuilder: (context, index) {
                      final saleItem = inventoryController.saleItems[index];
                      return _buildSaleItemCard(saleItem, index);
                    },
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Payment section for cash sales
              Obx(() {
                if (inventoryController.saleType.value == 'CASH') {
                  return Column(
                    children: [
                      TextFormField(
                        controller: inventoryController.paidAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (KSh)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Notes
              TextFormField(
                controller: inventoryController.saleNotesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Complete sale button
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: inventoryController.isLoading.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.shopping_cart_checkout, size: 20),
                    label: Text(
                      inventoryController.isLoading.value
                          ? 'Processing...'
                          : 'Complete Sale',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed:
                        inventoryController.saleItems.isEmpty ||
                            inventoryController.isLoading.value
                        ? null
                        : () {
                            Get.back(); // Close cart dialog
                            _completeSale();
                          },
                  ),
                ),
              ),

              // Error message
              Obx(() {
                if (inventoryController.error.value.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      inventoryController.error.value,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeSale() async {
    final inventoryController = Get.find<InventoryController>();

    // Validate the sale before processing
    if (inventoryController.saleItems.isEmpty) {
      Get.snackbar(
        'Error',
        'Please add at least one item to the sale',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (inventoryController.saleType.value == 'CREDIT' &&
        inventoryController.selectedMember.value == null) {
      Get.snackbar(
        'Error',
        'Please select a member for credit sales',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Capture sale data before clearing form
      final saleItems = List<SaleItem>.from(inventoryController.saleItems);
      final selectedMember = inventoryController.selectedMember.value;
      final saleType = inventoryController.saleType.value;
      final totalAmount = inventoryController.totalAmount.value;
      final paidAmount =
          double.tryParse(inventoryController.paidAmountController.text) ?? 0.0;
      final notes = inventoryController.saleNotesController.text.trim();

      final success = await inventoryController.createSale();

      if (success) {
        print('=== SALE COMPLETED SUCCESSFULLY ===');

        // Create a sale object for receipt and SMS
        final sale = Sale(
          id: '', // This would be generated by the service
          memberId: selectedMember?.id,
          memberName: selectedMember?.fullName,
          saleType: saleType,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          balanceAmount: totalAmount - paidAmount,
          saleDate: DateTime.now(),
          receiptNumber: await _generateReceiptNumber(),
          notes: notes.isEmpty ? null : notes,
          userId: Get.find<AuthService>().currentUser.value?.id ?? '',
          userName:
              Get.find<AuthService>().currentUser.value?.fullName ??
              'Unknown User',
          items: saleItems,
          isActive: true,
          createdAt: DateTime.now(),
        );

        // **CRITICAL: Send SMS IMMEDIATELY for credit sales before any other operations**
        if (saleType == 'CREDIT' && selectedMember != null) {
          print('🚀 PRIORITY 1: Sending SMS notification...');
          await _sendSaleSMS(sale, selectedMember);

          // **IMPORTANT: Add a safety delay to ensure SMS is fully processed**
          print('⏳ Adding safety delay after SMS...');
          await Future.delayed(const Duration(seconds: 2));
        }

        // Only then proceed with printing (which can cause lifecycle issues)
        print('🖨️  PRIORITY 2: Processing receipt printing...');
        await _printSaleReceipt(sale);

        print('✅ PRIORITY 3: Sale process completed successfully');
      } else if (inventoryController.error.value.isNotEmpty) {
        // Show detailed error message if available
        Get.snackbar(
          'Sale Failed',
          inventoryController.error.value,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
      // Note: Success handling is now done in the controller
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to complete sale: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<String> _generateReceiptNumber() async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePrefix =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'SAL$datePrefix$timePrefix';
  }

  Future<void> _printSaleReceipt(Sale sale) async {
    try {
      final settingsController = Get.find<SettingsController>();
      final settings = settingsController.systemSettings.value;

      if (settings?.enablePrinting != true) {
        print('Receipt printing is disabled in settings');
        return;
      }

      final orgSettings = settingsController.organizationSettings.value;
      final printService = Get.find<PrintService>();

      // Prepare receipt data for sale
      final receiptData = {
        'type': 'sale',
        'societyName': orgSettings?.societyName ?? 'Farm Pro Society',
        'factory': orgSettings?.factory ?? 'Main Store',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath,
        'memberName': sale.memberName,
        'memberNumber': sale.memberId, // Could be member number if available
        'receiptNumber': sale.receiptNumber,
        'date': DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate),
        'saleType': sale.saleType,
        'isCreditSale': sale.saleType == 'CREDIT',
        'totalAmount': sale.totalAmount.toStringAsFixed(2),
        'paidAmount': sale.paidAmount.toStringAsFixed(2),
        'balanceAmount': sale.balanceAmount.abs().toStringAsFixed(2),
        'items': sale.items
            .map(
              (item) => {
                'productName': item.productName,
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

      // Check if using standard print method
      if (settings?.printMethod == 'standard') {
        // Use dialog based printing for standard method
        await printService.printReceiptWithDialog(receiptData);
      } else {
        // Use direct printing for bluetooth method
        await printService.printReceipt(receiptData);
      }

      print('Sale receipt printed successfully for ${sale.receiptNumber}');
    } catch (e) {
      print('Failed to print sale receipt: $e');
      // Don't show error to user as this is not critical
    }
  }

  Future<void> _sendSaleSMS(Sale sale, Member member) async {
    try {
      print('=== SALE SMS SENDING START ===');
      print('📱 Sending SMS for sale ${sale.receiptNumber}');
      print('👤 Member: ${member.fullName} (ID: ${member.id})');

      // Get services
      final smsService = Get.find<SmsService>();
      final settingsService = Get.find<SettingsService>();

      // Check if SMS is enabled
      final sysSettings = settingsService.systemSettings.value;
      if (sysSettings.enableSms != true) {
        print('❌ SMS is disabled in system settings');
        return;
      }

      // Get member phone number
      if (member.phoneNumber == null || member.phoneNumber!.isEmpty) {
        print('❌ No phone number available for member ${member.fullName}');
        return;
      }

      final phoneNumberToUse = member.phoneNumber!;
      print('📱 Using phone number for SMS: $phoneNumberToUse');

      // Validate phone number
      final validatedNumber = smsService.validateKenyanPhoneNumber(
        phoneNumberToUse,
      );
      if (validatedNumber == null) {
        print(
          '❌ Invalid phone number for member ${member.fullName}: $phoneNumberToUse',
        );
        Get.snackbar(
          'SMS Warning',
          'Invalid phone number for ${member.fullName}: $phoneNumberToUse. Please update to valid Kenyan format.',
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      print('✅ Phone number validated successfully: $validatedNumber');

      // Build message content
      final orgSettings = settingsService.organizationSettings.value;
      final societyName = orgSettings.societyName;
      final factoryName = orgSettings.factory;

      final receiptNo = sale.receiptNumber ?? 'N/A';
      final formattedDate = DateFormat('dd/MM/yy').format(sale.saleDate);

      final message =
          '''${societyName.toUpperCase()}
Fac:$factoryName
Receipt:$receiptNo
Date:$formattedDate
Member:${member.fullName}
Type:${sale.saleType} SALE
Amount:KSh ${sale.totalAmount.toStringAsFixed(2)}
Paid:KSh ${sale.paidAmount.toStringAsFixed(2)}
Balance:KSh ${sale.balanceAmount.abs().toStringAsFixed(2)}
S/By:${sale.userName ?? 'N/A'}''';

      print('📤 Message prepared successfully');
      print('📤 Message content: $message');

      // Send SMS using robust method with retry logic
      print('📤 Sending SMS using robust method with retry logic...');
      final success = await smsService.sendSmsRobust(
        validatedNumber,
        message,
        maxRetries: 3,
        priority: 2,
      );

      print('📤 SMS send result: $success');
      print('=== SALE SMS SENDING END ===');

      // Show confirmation to user
    } catch (e) {
      print('❌ EXCEPTION in sale SMS sending: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      Get.snackbar(
        'SMS Error',
        'Error sending SMS: ${e.toString()}',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showSplitAndAddDialog(Product product) {
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
                          'Split & Add to Cart',
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
                      'Price per ${product.unitOfMeasureName}: KSh ${product.pricePerUnit.toStringAsFixed(2)}',
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
                        'Split during sale: Create a custom pack size for this sale without affecting inventory.',
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
                  labelText: 'Custom Pack Size (${product.unitOfMeasureName})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(
                    Icons.straighten,
                    color: Colors.orange,
                  ),
                  helperText:
                      'Enter custom size for this sale (max ${product.packSize.toStringAsFixed(1)})',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (value) {
                  // Real-time price calculation
                  final size = double.tryParse(value);
                  if (size != null && size > 0) {
                    // final price = product.pricePerUnit * size;
                    // You could add a price display here
                  }
                },
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
                    onPressed: () =>
                        _performSplitAndAdd(product, splitSizeController),
                    child: const Text('Add to Cart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSplitAndAdd(
    Product product,
    TextEditingController splitSizeController,
  ) {
    final splitSize = double.tryParse(splitSizeController.text);
    if (splitSize == null || splitSize <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid pack size',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (splitSize > product.packSize) {
      Get.snackbar(
        'Error',
        'Pack size cannot be larger than original (${product.packSize.toStringAsFixed(1)})',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final inventoryController = Get.find<InventoryController>();
    final stock = inventoryController.getProductStock(product.id);

    if (stock == null || stock.currentStock < 1) {
      Get.snackbar(
        'Error',
        'Insufficient stock available',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Create a temporary split product for the sale
    final splitProduct = Product(
      id: product.id, // Keep the same ID for inventory tracking
      name:
          '${product.name} (${splitSize.toStringAsFixed(1)} ${product.unitOfMeasureName})',
      description: product.description,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      unitOfMeasureId: product.unitOfMeasureId,
      unitOfMeasureName: product.unitOfMeasureName,
      packSize: splitSize,
      salesPrice: product.pricePerUnit * splitSize,
      costPrice: product.costPrice != null
          ? (product.costPrice! * splitSize) / product.packSize
          : null,
      isActive: true,
      allowPartialSales: product.allowPartialSales,
      createdAt: product.createdAt,
      isSplitProduct: true,
      originalPackSize: product.packSize,
    );

    // Add to cart with quantity 1 (since we're selling 1 custom pack)
    inventoryController.addSaleItem(splitProduct, 1.0, splitProduct.packSize);

    Get.back(); // Close the dialog
    Get.snackbar(
      'Added to Cart',
      'Custom pack (${splitSize.toStringAsFixed(1)} ${product.unitOfMeasureName}) added for KSh ${splitProduct.salesPrice.toStringAsFixed(2)}',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
}
