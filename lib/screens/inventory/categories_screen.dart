import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      appBar: AppBar(
        title: const Text(
          'Product Categories',
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
                      'Total Categories',
                      inventoryController.categories.length.toString(),
                      Icons.category,
                      const Color(0xFF8B4513),
                    ),
                  ),
                  Container(height: 40, width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      'Products',
                      inventoryController.products.length.toString(),
                      Icons.inventory,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Categories list
            Expanded(
              child:
                  inventoryController.categories.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: inventoryController.categories.length,
                        itemBuilder: (context, index) {
                          final category =
                              inventoryController.categories[index];
                          final productCount =
                              inventoryController.products
                                  .where((p) => p.categoryId == category.id)
                                  .length;
                          return _buildCategoryCard(category, productCount);
                        },
                      ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        onPressed: () => _showAddCategoryDialog(),
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
          Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Categories Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first category',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ProductCategory category, int productCount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Category icon/color
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _parseColor(category.color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _parseIcon(category.icon),
                color: _parseColor(category.color),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Category details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (category.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.description!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$productCount products',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              category.isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                category.isActive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton<String>(
              onSelected: (value) => _handleCategoryAction(value, category),
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
                      value: 'products',
                      child: ListTile(
                        leading: Icon(Icons.inventory, size: 20),
                        title: Text('View Products'),
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
                    PopupMenuItem(
                      value: category.isActive ? 'deactivate' : 'activate',
                      child: ListTile(
                        leading: Icon(
                          category.isActive ? Icons.block : Icons.check_circle,
                          size: 20,
                        ),
                        title: Text(
                          category.isActive ? 'Deactivate' : 'Activate',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return const Color(0xFF8B4513);
    }
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF8B4513);
    }
  }

  IconData _parseIcon(String? iconString) {
    switch (iconString) {
      case 'agriculture':
        return Icons.agriculture;
      case 'build':
        return Icons.build;
      case 'inventory':
        return Icons.inventory;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'eco':
        return Icons.eco;
      case 'grass':
        return Icons.grass;
      default:
        return Icons.category;
    }
  }

  void _handleCategoryAction(String action, ProductCategory category) {
    switch (action) {
      case 'edit':
        _showEditCategoryDialog(category);
        break;
      case 'products':
        _showCategoryProducts(category);
        break;
      case 'delete':
        _showDeleteCategoryDialog(category);
        break;
      case 'activate':
      case 'deactivate':
        _toggleCategoryStatus(category);
        break;
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final RxString selectedColor = '#4CAF50'.obs;
    final RxString selectedIcon = 'category'.obs;

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Category',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Category Name
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Icon selection (color auto-assigned)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Icon'),
                  const SizedBox(height: 8),
                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: selectedIcon.value,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items:
                          [
                                'category',
                                'agriculture',
                                'build',
                                'inventory',
                                'local_cafe',
                                'eco',
                                'grass',
                              ]
                              .map(
                                (icon) => DropdownMenuItem(
                                  value: icon,
                                  child: Row(
                                    children: [
                                      Icon(_parseIcon(icon), size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          icon,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => selectedIcon.value = value!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Obx(
                      () => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _parseColor(
                            selectedColor.value,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _parseIcon(selectedIcon.value),
                          color: _parseColor(selectedColor.value),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            nameController.text.isEmpty
                                ? 'Category Name'
                                : nameController.text,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Category name is required',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      final category = ProductCategory(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        description:
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                        color: selectedColor.value,
                        icon: selectedIcon.value,
                        isActive: true,
                        createdAt: DateTime.now(),
                      );

                      final inventoryService = Get.find<InventoryService>();
                      final result = await inventoryService.addCategory(
                        category,
                      );

                      if (result['success']) {
                        Get.back();
                        Get.snackbar(
                          'Success',
                          'Category added successfully',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      } else {
                        Get.snackbar(
                          'Error',
                          result['message'] ?? 'Failed to add category',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    child: const Text('Add Category'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCategoryDialog(ProductCategory category) {
    final nameController = TextEditingController(text: category.name);
    final descriptionController = TextEditingController(
      text: category.description ?? '',
    );
    final RxString selectedColor = (category.color ?? '#4CAF50').obs;
    final RxString selectedIcon = (category.icon ?? 'category').obs;

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Category',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Category Name
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Icon selection (color auto-assigned)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Icon'),
                  const SizedBox(height: 8),
                  Obx(
                    () => DropdownButtonFormField<String>(
                      value: selectedIcon.value,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items:
                          [
                                'category',
                                'agriculture',
                                'build',
                                'inventory',
                                'local_cafe',
                                'eco',
                                'grass',
                              ]
                              .map(
                                (icon) => DropdownMenuItem(
                                  value: icon,
                                  child: Row(
                                    children: [
                                      Icon(_parseIcon(icon), size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          icon,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => selectedIcon.value = value!,
                    ),
                  ),
                ],
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
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Category name is required',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      final updatedCategory = category.copyWith(
                        name: nameController.text.trim(),
                        description:
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                        color: selectedColor.value,
                        icon: selectedIcon.value,
                        updatedAt: DateTime.now(),
                      );

                      final inventoryService = Get.find<InventoryService>();
                      final result = await inventoryService.updateCategory(
                        updatedCategory,
                      );

                      if (result['success']) {
                        Get.back();
                        Get.snackbar(
                          'Success',
                          'Category updated successfully',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      } else {
                        Get.snackbar(
                          'Error',
                          result['message'] ?? 'Failed to update category',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
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

  void _showCategoryProducts(ProductCategory category) {
    final inventoryController = Get.find<InventoryController>();
    final categoryProducts =
        inventoryController.products
            .where((p) => p.categoryId == category.id)
            .toList();

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${category.name} Products',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              if (categoryProducts.isEmpty)
                Expanded(
                  child: Center(
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
                          'No products in this category',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: categoryProducts.length,
                    itemBuilder: (context, index) {
                      final product = categoryProducts[index];
                      return ListTile(
                        leading: Icon(
                          Icons.inventory,
                          color: _parseColor(category.color),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          'KSh ${product.salesPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '${product.packSize} ${product.unitOfMeasureName}',
                          style: const TextStyle(fontSize: 12),
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

  void _showDeleteCategoryDialog(ProductCategory category) async {
    final inventoryController = Get.find<InventoryController>();

    // Check if category can be deleted
    final canDelete = await inventoryController.canDeleteCategory(category.id);

    if (!canDelete) {
      final products = await inventoryController.getProductsInCategory(
        category.id,
      );

      Get.dialog(
        AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cannot delete category "${category.name}" because it contains ${products.length} product(s):',
              ),
              const SizedBox(height: 10),
              ...products.take(5).map((product) => Text('• ${product.name}')),
              if (products.length > 5)
                Text('... and ${products.length - 5} more'),
              const SizedBox(height: 10),
              const Text('Please move or delete these products first.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
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

              final success = await inventoryController.deleteCategory(
                category.id,
              );
              if (success) {
                Get.snackbar(
                  'Success',
                  'Category "${category.name}" deleted successfully',
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

  void _toggleCategoryStatus(ProductCategory category) {
    Get.dialog(
      AlertDialog(
        title: Text(
          '${category.isActive ? 'Deactivate' : 'Activate'} Category',
        ),
        content: Text(
          'Are you sure you want to ${category.isActive ? 'deactivate' : 'activate'} "${category.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: category.isActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Implementation would require adding toggle status method to service
              Get.back();
              Get.snackbar(
                'Info',
                'Category status toggle feature will be implemented',
                backgroundColor: Colors.blue,
                colorText: Colors.white,
              );
            },
            child: Text(category.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}
