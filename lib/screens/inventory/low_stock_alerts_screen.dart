import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/models.dart';
import '../../services/services.dart';

class LowStockAlertsScreen extends StatefulWidget {
  const LowStockAlertsScreen({super.key});

  @override
  State<LowStockAlertsScreen> createState() => _LowStockAlertsScreenState();
}

class _LowStockAlertsScreenState extends State<LowStockAlertsScreen> {
  final InventoryService _inventoryService = Get.find<InventoryService>();

  String? _selectedCategoryId;
  String? _selectedSeverity;

  List<LowStockAlert> _filteredAlerts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _inventoryService.generateLowStockAlerts();
      final alerts = await _inventoryService.getFilteredLowStockAlerts(
        categoryId: _selectedCategoryId,
        status: _selectedSeverity,
      );

      setState(() {
        _filteredAlerts = alerts;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load low stock alerts: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acknowledgeAlert(String alertId) async {
    final success = await _inventoryService.acknowledgeAlert(alertId);
    if (success) {
      _loadAlerts();
      Get.snackbar(
        'Success',
        'Alert acknowledged successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to acknowledge alert',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Alerts'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAlerts.isEmpty
              ? const Center(
                child: Text(
                  'No low stock alerts found',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                itemCount: _filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = _filteredAlerts[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(alert.productName),
                      subtitle: Text('Current Stock: ${alert.currentQuantity}'),
                      trailing:
                          alert.isAcknowledged
                              ? const Icon(Icons.check, color: Colors.green)
                              : IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _acknowledgeAlert(alert.id),
                              ),
                    ),
                  );
                },
              ),
    );
  }
}
