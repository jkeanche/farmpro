import 'package:flutter/material.dart';
import '../models/coffee_collection.dart';

class EditCollectionDialog extends StatefulWidget {
  final CoffeeCollection collection;
  
  const EditCollectionDialog({super.key, required this.collection});
  
  @override
  State<EditCollectionDialog> createState() => _EditCollectionDialogState();
}

class _EditCollectionDialogState extends State<EditCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _grossWeightController = TextEditingController();
  final _tareWeightController = TextEditingController();
  final _numberOfBagsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _grossWeightController.text = widget.collection.grossWeight.toString();
    _tareWeightController.text = widget.collection.tareWeight.toString();
    _numberOfBagsController.text = widget.collection.numberOfBags.toString();
  }
  
  @override
  void dispose() {
    _grossWeightController.dispose();
    _tareWeightController.dispose();
    _numberOfBagsController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Coffee Collection'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collection Info Display
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member: ${widget.collection.memberName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Receipt: ${widget.collection.receiptNumber ?? 'N/A'}'),
                  Text('Product: ${widget.collection.productType}'),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Number of Bags
            TextFormField(
              controller: _numberOfBagsController,
              decoration: const InputDecoration(
                labelText: 'Number of Bags',
                suffixText: 'bags',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter number of bags';
                }
                try {
                  final bags = int.parse(value);
                  if (bags <= 0) {
                    return 'Number of bags must be greater than 0';
                  }
                } catch (e) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            
            // Gross Weight
            TextFormField(
              controller: _grossWeightController,
              decoration: const InputDecoration(
                labelText: 'Gross Weight',
                suffixText: 'kg',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter gross weight';
                }
                try {
                  final weight = double.parse(value);
                  if (weight <= 0) {
                    return 'Weight must be greater than 0';
                  }
                } catch (e) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            
            // Tare Weight
            TextFormField(
              controller: _tareWeightController,
              decoration: const InputDecoration(
                labelText: 'Tare Weight',
                suffixText: 'kg',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    final weight = double.parse(value);
                    if (weight < 0) {
                      return 'Tare weight cannot be negative';
                    }
                    // Check if tare weight is not greater than gross weight
                    final grossWeight = double.tryParse(_grossWeightController.text) ?? 0.0;
                    if (weight >= grossWeight) {
                      return 'Tare weight must be less than gross weight';
                    }
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            
            // Net Weight Display
            Builder(builder: (context) {
              double gross = 0.0;
              double tare = 0.0;
              try {
                if (_grossWeightController.text.isNotEmpty) {
                  gross = double.parse(_grossWeightController.text);
                }
                if (_tareWeightController.text.isNotEmpty) {
                  tare = double.parse(_tareWeightController.text);
                }
              } catch (_) {}
              final netWeight = gross > tare ? (gross - tare) : 0.0;
              return Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Weight:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${netWeight.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final grossWeight = double.parse(_grossWeightController.text);
              final tareWeight = _tareWeightController.text.isNotEmpty
                  ? double.parse(_tareWeightController.text)
                  : 0.0;
              final numberOfBags = int.parse(_numberOfBagsController.text);
              
              Navigator.of(context).pop({
                'grossWeight': grossWeight,
                'tareWeight': tareWeight,
                'numberOfBags': numberOfBags,
              });
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
} 