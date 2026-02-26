import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Units of Measure',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B4513),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
      ),
      body: Obx(() {
        if (inventoryController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inventoryController.units.length,
          itemBuilder: (context, index) {
            final unit = inventoryController.units[index];
            return _buildUnitCard(unit);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        onPressed: () => _showAddUnitDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUnitCard(UnitOfMeasure unit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.straighten, color: Color(0xFF8B4513)),
        title: Text(unit.name),
        subtitle: Text('Abbreviation: ${unit.abbreviation}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUnitDialog(unit);
            } else if (value == 'delete') {
              _showDeleteUnitDialog(unit);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnitDialog() {
    final nameController = TextEditingController();
    final abbreviationController = TextEditingController();
    final descriptionController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Add Unit of Measure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: abbreviationController,
              decoration: const InputDecoration(labelText: 'Abbreviation *'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
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
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final abbreviation = abbreviationController.text.trim();
              
              if (name.isEmpty) {
                Get.snackbar(
                  'Validation Error',
                  'Unit name is required',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (abbreviation.isEmpty) {
                Get.snackbar(
                  'Validation Error',
                  'Abbreviation is required',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (name.length < 2) {
                Get.snackbar(
                  'Validation Error',
                  'Unit name must be at least 2 characters',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (abbreviation.length > 10) {
                Get.snackbar(
                  'Validation Error',
                  'Abbreviation must be 10 characters or less',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              final unit = UnitOfMeasure(
                id: const Uuid().v4(),
                name: name,
                abbreviation: abbreviation,
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                isBaseUnit: true,
                isActive: true,
                createdAt: DateTime.now(),
              );

              final inventoryService = Get.find<InventoryService>();
              final result = await inventoryService.addUnit(unit);

              if (result['success']) {
                Get.back();
                Get.snackbar(
                  'Success',
                  'Unit added successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Error',
                  result['error'] ?? 'Failed to add unit',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(UnitOfMeasure unit) {
    final nameController = TextEditingController(text: unit.name);
    final abbreviationController = TextEditingController(text: unit.abbreviation);
    final descriptionController = TextEditingController(text: unit.description ?? '');

    Get.dialog(
      AlertDialog(
        title: const Text('Edit Unit of Measure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: abbreviationController,
              decoration: const InputDecoration(labelText: 'Abbreviation *'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
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
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final abbreviation = abbreviationController.text.trim();
              
              if (name.isEmpty) {
                Get.snackbar(
                  'Validation Error',
                  'Unit name is required',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (abbreviation.isEmpty) {
                Get.snackbar(
                  'Validation Error',
                  'Abbreviation is required',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (name.length < 2) {
                Get.snackbar(
                  'Validation Error',
                  'Unit name must be at least 2 characters',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (abbreviation.length > 10) {
                Get.snackbar(
                  'Validation Error',
                  'Abbreviation must be 10 characters or less',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              final updatedUnit = unit.copyWith(
                name: name,
                abbreviation: abbreviation,
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                updatedAt: DateTime.now(),
              );

              final inventoryService = Get.find<InventoryService>();
              final result = await inventoryService.updateUnit(updatedUnit);

              if (result['success']) {
                Get.back();
                Get.snackbar(
                  'Success',
                  'Unit updated successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Error',
                  result['error'] ?? 'Failed to update unit',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUnitDialog(UnitOfMeasure unit) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Unit of Measure'),
        content: Text('Are you sure you want to delete "${unit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back(); // Close dialog first
              
              final inventoryService = Get.find<InventoryService>();
              final result = await inventoryService.deleteUnit(unit.id);
              
              if (result['success']) {
                Get.snackbar(
                  'Success',
                  'Unit deleted successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                final error = result['error'] as String;
                final products = result['products'] as List<String>?;
                
                Get.dialog(
                  AlertDialog(
                    title: const Text('Cannot Delete Unit'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error),
                        if (products != null && products.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Products using this unit:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: products.map((product) => 
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('• $product'),
                                ),
                              ).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 