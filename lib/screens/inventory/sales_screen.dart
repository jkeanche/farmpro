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
        // Don't show snackbar - will be shown in label below season notification
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
      resizeToAvoidBottomInset: false, // Prevent automatic keyboard resizing
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

        return SafeArea(
          child: Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
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
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
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
                                  onPressed:
                                      () => Get.toNamed(
                                        '/settings/season-management',
                                      ),
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
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
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
                                  'Season: ${activeSeason.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  activeSeason.dateRangeText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      }),

                      // Selected member display (for both cash and credit sales)
                      Obx(() {
                        final selectedMember =
                            inventoryController.selectedMember.value;
                        if (selectedMember != null) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected Member: ${selectedMember.fullName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        'Member #: ${selectedMember.memberNumber}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      () => inventoryController
                                          .setSelectedMember(null),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
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
                                      groupValue:
                                          inventoryController.saleType.value,
                                      onChanged:
                                          (value) => inventoryController
                                              .setSaleType(value!),
                                      dense: true,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Obx(
                                    () => RadioListTile<String>(
                                      title: const Text('Credit'),
                                      value: 'CREDIT',
                                      groupValue:
                                          inventoryController.saleType.value,
                                      onChanged:
                                          (value) => inventoryController
                                              .setSaleType(value!),
                                      dense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(),

                            // Member selection for both cash and credit sales
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: memberNumberController,
                                        decoration: const InputDecoration(
                                          labelText: 'Member Number (Required)',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.text,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF8B4513,
                                        ),
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
                            ),

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
                      _buildProductsSection(context),
                    ],
                  ),
                ),
              ),

              // Fixed bottom section that stays at bottom
              _buildBottomSection(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProductsSection(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Container(
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
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  double childAspectRatio =
                      constraints.maxWidth > 600 ? 1.0 : 1.2;
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
          padding: const EdgeInsets.all(
            8,
          ), // Reduced padding to prevent overflow
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hasStock ? null : Colors.grey[100],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product name
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 13, // Slightly smaller font
                  fontWeight: FontWeight.bold,
                  color: hasStock ? Colors.black : Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4), // Reduced spacing
              // Category
              Text(
                product.categoryName ?? 'No Category',
                style: TextStyle(
                  fontSize: 10, // Smaller font
                  color: hasStock ? Colors.grey[600] : Colors.grey[400],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 6), // Reduced spacing
              // Price and stock
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'KSh ${product.salesPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12, // Smaller font
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
                        horizontal: 4,
                        vertical: 1,
                      ), // Reduced padding
                      decoration: BoxDecoration(
                        color:
                            hasStock
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasStock
                            ? stock.currentStock.toStringAsFixed(1)
                            : 'Out',
                        style: TextStyle(
                          fontSize: 9, // Smaller font
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

              const SizedBox(height: 4), // Reduced spacing
              // Add button
              if (hasStock)
                SizedBox(
                  width: double.infinity,
                  height: 24, // Fixed height to prevent overflow
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                      ), // Minimal padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 10),
                    label: const Text('Add', style: TextStyle(fontSize: 10)),
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
                    '${saleItem.productName} (${saleItem.packSizeSold.toStringAsFixed(0)})',
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
                      onTap:
                          () => Get.find<InventoryController>().removeSaleItem(
                            index,
                          ),
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
                        children:
                            inventoryController.saleItems.take(2).map((item) {
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
                  icon:
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

    // Sort pack sizes in descending order (largest first)
    final sortedPackSizes = List<double>.from(product.packSizes)
      ..sort((a, b) => b.compareTo(a));
    final RxMap<double, bool> selectedPackSizes = <double, bool>{}.obs;
    final RxDouble selectedPackSize =
        (sortedPackSizes.isNotEmpty ? sortedPackSizes.first : product.packSize)
            .obs;

    // Initialize all pack sizes as not selected
    for (final size in sortedPackSizes) {
      selectedPackSizes[size] = false;
    }
    // Select the first pack size by default if available
    if (sortedPackSizes.isNotEmpty) {
      selectedPackSizes[sortedPackSizes.first] = true;
    }

    // Calculate price per pack based on the highest pack size
    final double highestPackSize =
        sortedPackSizes.isNotEmpty ? sortedPackSizes.first : product.packSize;
    final double pricePerHighestPack =
        product.salesPrice; // This is the price for the highest pack size

    // Function to calculate price for a given pack size
    double calculatePriceForPackSize(double packSize) {
      return (pricePerHighestPack / highestPackSize) * packSize;
    }

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
                    Obx(() {
                      final currentPackSize = selectedPackSize.value;
                      final priceForPack = calculatePriceForPackSize(
                        currentPackSize,
                      );
                      return Text(
                        'Price: KSh ${priceForPack.toStringAsFixed(2)} for ${currentPackSize.toStringAsFixed(0)} ${product.unitOfMeasureName ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      'Available Stock: ${stock?.currentStock.toStringAsFixed(1) ?? '0.0'} ${product.unitOfMeasureName ?? ''}',
                    ),
                    if (sortedPackSizes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Base Price: KSh ${product.salesPrice.toStringAsFixed(2)} for ${highestPackSize.toStringAsFixed(0)} ${product.unitOfMeasureName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pack size selection
              if (sortedPackSizes.isNotEmpty) ...[
                const Text(
                  'Select Pack Size *',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Column(
                    children:
                        sortedPackSizes.map((size) {
                          final priceForPack = calculatePriceForPackSize(size);
                          final unitPrice = priceForPack / size;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Radio<double>(
                              value: size,
                              groupValue: selectedPackSize.value,
                              onChanged: (value) {
                                selectedPackSize.value = value!;
                              },
                            ),
                            title: Text(
                              '${size.toStringAsFixed(0)} ${product.unitOfMeasureName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Text(
                              'KSh ${priceForPack.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'KSh ${unitPrice.toStringAsFixed(2)} per ${product.unitOfMeasureName?.toLowerCase() ?? 'unit'}'
                              ' (${(unitPrice / (pricePerHighestPack / highestPackSize) * 100).toStringAsFixed(0)}% of base price)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            onTap: () {
                              selectedPackSize.value = size;
                            },
                          );
                        }).toList(),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
              ],

              // Quantity input
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (packs)',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter number of packs',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
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
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
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
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final quantity = double.tryParse(quantityController.text);
                      if (quantity == null ||
                          quantity <= 0 ||
                          quantity % 1 != 0) {
                        Get.snackbar(
                          'Invalid Quantity',
                          'Please enter a valid whole number quantity',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      final double packSizeChosen = selectedPackSize.value;
                      final double highestPackSize =
                          sortedPackSizes.isNotEmpty
                              ? sortedPackSizes.first
                              : product.packSize;

                      // Calculate the equivalent quantity in terms of the highest pack size
                      final double equivalentQuantity =
                          quantity * (packSizeChosen / highestPackSize);

                      // Calculate the total price based on the selected pack size
                      final double priceForPack = calculatePriceForPackSize(
                        packSizeChosen,
                      );
                      final double totalPrice = priceForPack * quantity;

                      if (equivalentQuantity > (stock?.currentStock ?? 0)) {
                        Get.snackbar(
                          'Insufficient Stock',
                          'Not enough stock available for the selected pack size and quantity',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      // Add the item to cart with the calculated values
                      inventoryController.addSaleItem(
                        product.copyWith(
                          packSize: packSizeChosen,
                          salesPrice: priceForPack,
                        ),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(Get.context!).viewInsets.bottom + 16,
            ),
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
                    icon:
                        inventoryController.isLoading.value
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
                            : const Icon(
                              Icons.shopping_cart_checkout,
                              size: 20,
                            ),
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

    // Both cash and credit sales require a member
    if (inventoryController.selectedMember.value == null) {
      Get.snackbar(
        'Error',
        'Please select a member for this sale',
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
          memberNumber: selectedMember?.memberNumber,
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

        // **CRITICAL: Send SMS IMMEDIATELY for qualifying sales before any other operations**
        if (selectedMember != null && _shouldSendSms(saleType)) {
          print(
            '🚀 PRIORITY 1: Sending SMS notification for $saleType sale...',
          );

          // Show SMS sending status
          // Get.snackbar(
          //   '📱 Sending SMS',
          //   'Sending sale notification to ${selectedMember.fullName}...',
          //   backgroundColor: Colors.blue.withOpacity(0.9),
          //   colorText: Colors.white,
          //   duration: const Duration(seconds: 2),
          //   snackPosition: SnackPosition.BOTTOM,
          //   icon: const SizedBox(
          //     width: 20,
          //     height: 20,
          //     child: CircularProgressIndicator(
          //       strokeWidth: 2,
          //       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          //     ),34w3q
          //   ),
          //   showProgressIndicator: true,
          // );

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

      // Get member details for receipt
      Member? member;
      if (sale.memberId != null) {
        final memberService = Get.find<MemberService>();
        member = await memberService.getMemberById(sale.memberId!);
      }

      // Calculate total balance for the member
      final inventoryService = Get.find<InventoryService>();
      double totalBalance = 0.0;
      double cumulativeForSeason = 0.0;

      // Prefer using SeasonController to get active season totals for member
      try {
        final seasonController = Get.find<SeasonController>();
        final activeSeason = seasonController.activeSeason;
        if (sale.memberId != null) {
          // Fallback: inventory service provides all-time credit total
          totalBalance = inventoryService.getMemberTotalCredit(sale.memberId!);

          // For CREDIT sales compute cumulative as the member's total for the active inventory season
          if (activeSeason != null && sale.saleType == 'CREDIT') {
            // SeasonController.getMemberSeasonTotal is async, so call and await it
            try {
              cumulativeForSeason = await seasonController.getMemberSeasonTotal(
                sale.memberId!,
                activeSeason.id,
              );
            } catch (e) {
              // If async call fails, fall back to inventory service total
              cumulativeForSeason = totalBalance;
            }
          }
        }
      } catch (e) {
        // If season controller is not available, fall back to inventory service total
        if (sale.memberId != null) {
          totalBalance = inventoryService.getMemberTotalCredit(sale.memberId!);
        }
      }

      // Prepare receipt data for sale
      final receiptData = {
        'type': 'sale',
        'societyName': orgSettings?.societyName ?? 'Farm Pro Society',
        'factory': orgSettings?.factory ?? 'Main Store',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath,
        'memberName': sale.memberName,
        'memberNumber':
            member?.memberNumber ??
            'N/A', // Use actual member number from database
        'receiptNumber': sale.receiptNumber,
        'date': DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate),
        'saleType': sale.saleType,
        'isCreditSale': sale.saleType == 'CREDIT',
        'totalAmount': sale.totalAmount.toStringAsFixed(2),
        'paidAmount': sale.paidAmount.toStringAsFixed(2),
        'balanceAmount': sale.balanceAmount.abs().toStringAsFixed(2),
        // For receipts we show 'cumulative' as season cumulative for credit sales when available
        'totalBalance': totalBalance.toStringAsFixed(
          2,
        ), // Add total balance (all-time)
        'cumulative':
            (sale.saleType == 'CREDIT' && cumulativeForSeason > 0)
                ? cumulativeForSeason.toStringAsFixed(2)
                : sale.totalAmount.toStringAsFixed(2),
        'items':
            sale.items
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

      // Use the detailed receipt data for inventory sales
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

  bool _shouldSendSms(String saleType) {
    try {
      final settingsService = Get.find<SettingsService>();
      final sysSettings = settingsService.systemSettings.value;

      // Check if SMS is enabled globally
      if (sysSettings.enableSms != true) {
        print('📱 SMS globally disabled in system settings');
        return false;
      }

      // Check specific SMS settings based on sale type
      if (saleType == 'CASH') {
        final enableForCash = sysSettings.enableSmsForCashSales;
        print('📱 SMS for cash sales: $enableForCash');
        return enableForCash;
      } else if (saleType == 'CREDIT') {
        final enableForCredit = sysSettings.enableSmsForCreditSales;
        print('📱 SMS for credit sales: $enableForCredit');
        return enableForCredit;
      }

      return false;
    } catch (e) {
      print('❌ Error checking SMS settings: $e');
      return false;
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
          'Invalid phone number for ${member.fullName}: $phoneNumberToUse\nPlease update to valid Kenyan format (e.g., +254712345678 or 0712345678)',
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
          icon: const Icon(Icons.warning, color: Colors.white),
          shouldIconPulse: true,
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

      // Enhanced SMS message formatting with validation
      final memberNameTruncated =
          member.fullName.length > 25
              ? '${member.fullName.substring(0, 22)}...'
              : member.fullName;
      final userNameTruncated =
          (sale.userName ?? 'N/A').length > 15
              ? '${(sale.userName ?? 'N/A').substring(0, 12)}...'
              : (sale.userName ?? 'N/A');

      // Compute cumulative amount (total balance for CREDIT sales, matching receipt logic)
      double smsCumulative = sale.totalAmount;
      double totalBalance = 0.0;
      double cumulativeForSeason = 0.0;

      try {
        final inventoryService = Get.find<InventoryService>();
        final seasonController = Get.find<SeasonController>();
        final activeSeason = seasonController.activeSeason;

        if (sale.saleType == 'CREDIT') {
          // Get total balance (all-time credit total)
          totalBalance = inventoryService.getMemberTotalCredit(member.id);

          // Get season cumulative if available
          if (activeSeason != null) {
            try {
              cumulativeForSeason = await seasonController.getMemberSeasonTotal(
                member.id,
                activeSeason.id,
              );
            } catch (e) {
              cumulativeForSeason = totalBalance;
            }
          }

          // Use the same logic as receipt: season cumulative if available, otherwise total balance
          smsCumulative =
              (cumulativeForSeason > 0) ? cumulativeForSeason : totalBalance;
        }
      } catch (e) {
        // Fallback to sale amount if all else fails
        smsCumulative = sale.totalAmount;
      }

      final message =
          '''${societyName.toUpperCase()}
${factoryName.isNotEmpty ? 'Factory: $factoryName' : ''}
Receipt: $receiptNo
Date: $formattedDate
Member: $memberNameTruncated
Type: ${sale.saleType} SALE
Amount: KSh ${sale.totalAmount.toStringAsFixed(2)}
Paid: KSh ${sale.paidAmount.toStringAsFixed(2)}
Balance: KSh ${sale.balanceAmount.abs().toStringAsFixed(2)}
Cumulative: KSh ${smsCumulative.toStringAsFixed(2)}
Served By: $userNameTruncated
Thank you for your business!'''.trim();

      // Validate SMS message length (SMS limit is typically 160 characters per segment)
      if (message.length > 320) {
        // Allow up to 2 SMS segments
        print(
          '⚠️ SMS message is long (${message.length} chars), may be split into multiple segments',
        );
      }

      print('📤 Message prepared successfully (${message.length} characters)');
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

      // Show enhanced confirmation to user
      if (success) {
        Get.snackbar(
          '✅ SMS Sent',
          'Sale notification sent to ${member.fullName}',
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        Get.snackbar(
          '⚠️ SMS Failed',
          'Could not send SMS to ${member.fullName}',
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
          icon: const Icon(Icons.warning, color: Colors.white),
        );
      }
    } catch (e) {
      // Comprehensive error logging without exposing sensitive data
      print('❌ EXCEPTION in sale SMS sending: $e');
      print('❌ Member ID: ${member.id}');
      print('❌ Sale Type: ${sale.saleType}');
      print('❌ Receipt Number: ${sale.receiptNumber}');
      print('❌ Phone Number Length: ${member.phoneNumber?.length ?? 0}');
      print(
        '❌ SMS Service Available: ${Get.find<SmsService>().isSmsAvailable.value}',
      );
      print('❌ Stack trace: ${StackTrace.current}');

      // Categorize error types for better monitoring
      String errorCategory = 'Unknown';
      String userMessage = 'Error sending SMS: ${e.toString()}';

      if (e.toString().contains('permission')) {
        errorCategory = 'Permission';
        userMessage =
            'SMS permission denied. Please enable SMS permissions in settings.';
      } else if (e.toString().contains('timeout')) {
        errorCategory = 'Timeout';
        userMessage = 'SMS sending timed out. Please check network connection.';
      } else if (e.toString().contains('network')) {
        errorCategory = 'Network';
        userMessage = 'Network error while sending SMS. Please try again.';
      } else if (e.toString().contains('service')) {
        errorCategory = 'Service';
        userMessage = 'SMS service unavailable. Please try again later.';
      }

      print('❌ Error Category: $errorCategory');

      Get.snackbar(
        '❌ SMS Error ($errorCategory)',
        userMessage,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.error_outline, color: Colors.white),
        shouldIconPulse: true,
        margin: const EdgeInsets.all(16),
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
                    onPressed:
                        () => _performSplitAndAdd(product, splitSizeController),
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
      costPrice:
          product.costPrice != null
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
