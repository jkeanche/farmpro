import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class RepaymentsScreen extends StatelessWidget {
  const RepaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryController = Get.find<InventoryController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Repayments',
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
      body: Obx(() {
        if (inventoryController.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
            ),
          );
        }

        final repayments = inventoryController.repayments;

        return Column(
          children: [
            // Summary card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Repayments',
                      repayments.length.toString(),
                      Icons.payment,
                      Colors.blue,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Amount',
                      'KSh ${_calculateTotalRepayments(repayments).toStringAsFixed(0)}',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Filters
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddRepaymentDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDateFilterDialog(),
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B4513),
                      side: const BorderSide(color: Color(0xFF8B4513)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Repayments list
            Expanded(
              child:
                  repayments.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Repayments Found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Record credit sale payments',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: repayments.length,
                        itemBuilder: (context, index) {
                          final repayment = repayments[index];
                          return _buildRepaymentCard(repayment);
                        },
                      ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRepaymentCard(Repayment repayment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  repayment.memberName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPaymentMethodColor(
                      repayment.paymentMethod,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    repayment.paymentMethod,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPaymentMethodColor(repayment.paymentMethod),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Amount
            Text(
              'Amount: KSh ${repayment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Payment Date: ${_formatDate(repayment.repaymentDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            // Reference (if available)
            if (repayment.reference != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.receipt, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Reference: ${repayment.reference}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],

            // Notes (if available)
            if (repayment.notes != null && repayment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${repayment.notes}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // User info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Recorded by: ${repayment.userName ?? 'System'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(repayment.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'CASH':
        return Colors.green;
      case 'MOBILE_MONEY':
        return Colors.blue;
      case 'BANK_TRANSFER':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  double _calculateTotalRepayments(List<Repayment> repayments) {
    return repayments.fold(0.0, (sum, repayment) => sum + repayment.amount);
  }

  void _showAddRepaymentDialog() {
    final inventoryController = Get.find<InventoryController>();
    final authService = Get.find<AuthService>();

    final creditSales = inventoryController.creditSales;

    if (creditSales.isEmpty) {
      Get.snackbar(
        'No Credit Sales',
        'There are no outstanding credit sales to record payments for',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    final selectedSale = Rx<Sale?>(null);
    final selectedPaymentMethod = RxString('CASH');

    Get.dialog(
      Dialog(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Repayment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Sale selection
                const Text(
                  'Select Credit Sale:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => DropdownButtonFormField<Sale>(
                    value: selectedSale.value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose a credit sale',
                    ),
                    items:
                        creditSales.map((sale) {
                          return DropdownMenuItem(
                            value: sale,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sale.memberName} - ${sale.receiptNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Balance: KSh ${sale.balanceAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    onChanged: (value) => selectedSale.value = value,
                  ),
                ),
                const SizedBox(height: 16),

                // Payment amount
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (KSh)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Payment method
                const Text(
                  'Payment Method:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Cash'),
                        value: 'CASH',
                        groupValue: selectedPaymentMethod.value,
                        onChanged:
                            (value) => selectedPaymentMethod.value = value!,
                        dense: true,
                      ),
                      RadioListTile<String>(
                        title: const Text('Mobile Money'),
                        value: 'MOBILE_MONEY',
                        groupValue: selectedPaymentMethod.value,
                        onChanged:
                            (value) => selectedPaymentMethod.value = value!,
                        dense: true,
                      ),
                      RadioListTile<String>(
                        title: const Text('Bank Transfer'),
                        value: 'BANK_TRANSFER',
                        groupValue: selectedPaymentMethod.value,
                        onChanged:
                            (value) => selectedPaymentMethod.value = value!,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reference
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt),
                    hintText: 'Transaction ID, Receipt number, etc.',
                  ),
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
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (selectedSale.value == null) {
                          Get.snackbar(
                            'Error',
                            'Please select a credit sale',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          Get.snackbar(
                            'Error',
                            'Please enter a valid payment amount',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        if (amount > selectedSale.value!.balanceAmount) {
                          Get.snackbar(
                            'Error',
                            'Payment amount cannot exceed outstanding balance',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        final user = authService.currentUser.value;
                        final repayment = Repayment(
                          id: const Uuid().v4(),
                          saleId: selectedSale.value!.id,
                          memberId: selectedSale.value!.memberId!,
                          memberName: selectedSale.value!.memberName!,
                          amount: amount,
                          repaymentDate: DateTime.now(),
                          paymentMethod: selectedPaymentMethod.value,
                          reference:
                              referenceController.text.trim().isEmpty
                                  ? null
                                  : referenceController.text.trim(),
                          notes:
                              notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                          userId: user?.id ?? 'system',
                          userName: user?.fullName,
                          createdAt: DateTime.now(),
                        );

                        final inventoryService = Get.find<InventoryService>();
                        final result = await inventoryService.addRepayment(
                          repayment,
                        );

                        if (result['success']) {
                          Get.back();
                          Get.snackbar(
                            'Success',
                            'Payment recorded successfully',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        } else {
                          Get.snackbar(
                            'Error',
                            'Failed to record payment',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: const Text('Add Payment'),
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

  void _showDateFilterDialog() {
    Get.snackbar(
      'Info',
      'Date filtering feature will be implemented',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
