import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';

class StockAdjustmentDialog extends StatefulWidget {
  final Product product;
  final Stock stock;

  const StockAdjustmentDialog({
    super.key,
    required this.product,
    required this.stock,
  });

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  final InventoryService _inventoryService = Get.find<InventoryService>();
  final AuthService _authService = Get.find<AuthService>();

  String _selectedAdjustmentType = 'increase';
  String _selectedReason = '';
  String _customReason = '';
  bool _isLoading = false;

  // Predefined reasons for stock adjustments
  final List<String> _predefinedReasons = [
    'Damaged goods',
    'Expired products',
    'Theft/Loss',
    'Found stock',
    'Supplier return',
    'Customer return',
    'Inventory count correction',
    'Transfer in',
    'Transfer out',
    'Quality control rejection',
    'Other (specify)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedReason = _predefinedReasons.first;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _quantityLabel {
    switch (_selectedAdjustmentType) {
      case 'increase':
        return 'Quantity to Add';
      case 'decrease':
        return 'Quantity to Remove';
      case 'correction':
        return 'New Stock Quantity';
      default:
        return 'Quantity';
    }
  }

  String get _quantityHint {
    switch (_selectedAdjustmentType) {
      case 'increase':
        return 'Enter amount to add to current stock';
      case 'decrease':
        return 'Enter amount to remove from current stock';
      case 'correction':
        return 'Enter the correct stock quantity';
      default:
        return 'Enter quantity';
    }
  }

  double? get _calculatedNewQuantity {
    final inputQuantity = double.tryParse(_quantityController.text);
    if (inputQuantity == null) return null;

    switch (_selectedAdjustmentType) {
      case 'increase':
        return widget.stock.currentStock + inputQuantity;
      case 'decrease':
        return widget.stock.currentStock - inputQuantity;
      case 'correction':
        return inputQuantity;
      default:
        return null;
    }
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a quantity';
    }

    final quantity = double.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid number';
    }

    if (quantity <= 0) {
      return 'Quantity must be greater than 0';
    }

    // Additional validation based on adjustment type
    switch (_selectedAdjustmentType) {
      case 'decrease':
        if (quantity > widget.stock.currentStock) {
          return 'Cannot remove more than current stock (${widget.stock.currentStock.toStringAsFixed(2)})';
        }
        break;
      case 'correction':
        if (quantity < 0) {
          return 'Stock quantity cannot be negative';
        }
        break;
    }

    return null;
  }

  String get _effectiveReason {
    return _selectedReason == 'Other (specify)'
        ? _customReason
        : _selectedReason;
  }

  bool get _isFormValid {
    return _formKey.currentState?.validate() == true &&
        _effectiveReason.isNotEmpty;
  }

  Future<void> _submitAdjustment() async {
    if (!_isFormValid) return;

    final currentUser = _authService.currentUser.value;
    if (currentUser == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final inputQuantity = double.parse(_quantityController.text);
      final notes =
          _notesController.text.trim().isEmpty
              ? _effectiveReason
              : '$_effectiveReason - ${_notesController.text.trim()}';

      Map<String, dynamic> result;

      if (_selectedAdjustmentType == 'correction') {
        // Use the dedicated correction method
        result = await _inventoryService.correctStock(
          productId: widget.product.id,
          targetQuantity: inputQuantity,
          reason: _effectiveReason,
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
          userId: currentUser.id,
          userName: currentUser.fullName,
        );
      } else {
        // For increase/decrease, use the input quantity directly
        final movementType =
            _selectedAdjustmentType == 'increase' ? 'IN' : 'OUT';

        result = await _inventoryService.adjustStock(
          productId: widget.product.id,
          quantity: inputQuantity,
          movementType: movementType,
          notes: notes,
          userId: currentUser.id,
          userName: currentUser.fullName,
        );
      }

      if (mounted) {
        if (result['success']) {
          _showSuccessSnackBar('Stock adjustment recorded successfully');
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          _showErrorSnackBar(
            'Failed to record stock adjustment: ${result['error']}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stock Adjustment'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Information Card
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${widget.product.categoryName ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Unit: ${widget.product.unitOfMeasureName ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Current Stock: ${widget.stock.currentStock.toStringAsFixed(2)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Adjustment Type Selection
                Text(
                  'Adjustment Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Stock Increase'),
                      subtitle: const Text('Add items to current stock'),
                      value: 'increase',
                      groupValue: _selectedAdjustmentType,
                      onChanged: (value) {
                        setState(() {
                          _selectedAdjustmentType = value!;
                          _quantityController.clear();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('Stock Decrease'),
                      subtitle: const Text('Remove items from current stock'),
                      value: 'decrease',
                      groupValue: _selectedAdjustmentType,
                      onChanged: (value) {
                        setState(() {
                          _selectedAdjustmentType = value!;
                          _quantityController.clear();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('Stock Correction'),
                      subtitle: const Text('Set stock to exact quantity'),
                      value: 'correction',
                      groupValue: _selectedAdjustmentType,
                      onChanged: (value) {
                        setState(() {
                          _selectedAdjustmentType = value!;
                          _quantityController.clear();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quantity Input
                CustomTextField(
                  label: _quantityLabel,
                  hint: _quantityHint,
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateQuantity,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    setState(
                      () {},
                    ); // Trigger rebuild to update calculated quantity
                  },
                ),
                const SizedBox(height: 16),

                // Calculated New Quantity Display
                if (_calculatedNewQuantity != null)
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Stock Quantity:',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _calculatedNewQuantity!.toStringAsFixed(2),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Reason Selection
                Text(
                  'Reason for Adjustment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items:
                      _predefinedReasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value!;
                      if (value != 'Other (specify)') {
                        _customReason = '';
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Custom Reason Input (shown when "Other" is selected)
                if (_selectedReason == 'Other (specify)')
                  CustomTextField(
                    label: 'Custom Reason',
                    hint: 'Please specify the reason for adjustment',
                    controller: TextEditingController(text: _customReason),
                    onChanged: (value) {
                      setState(() {
                        _customReason = value;
                      });
                    },
                    validator: (value) {
                      if (_selectedReason == 'Other (specify)' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please specify the reason';
                      }
                      return null;
                    },
                  ),
                if (_selectedReason == 'Other (specify)')
                  const SizedBox(height: 16),

                // Notes Input (Optional)
                CustomTextField(
                  label: 'Additional Notes (Optional)',
                  hint: 'Enter any additional notes about this adjustment',
                  controller: _notesController,
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        CustomButton(
          text: 'Record Adjustment',
          onPressed: _isLoading ? () {} : _submitAdjustment,
          isLoading: _isLoading,
          buttonType: ButtonType.primary,
        ),
      ],
    );
  }
}
