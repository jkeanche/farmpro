import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';

class CoffeeCollectionForm extends StatelessWidget {
  const CoffeeCollectionForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CoffeeCollectionController>();
    final memberController = Get.find<MemberController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Coffee Collection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            children: [
              // Member selection
              Obx(() => DropdownButtonFormField<Member>(
                value: controller.selectedMember.value,
                decoration: const InputDecoration(
                  labelText: 'Select Member',
                  border: OutlineInputBorder(),
                ),
                items: memberController.members.map((member) => 
                  DropdownMenuItem(
                    value: member,
                    child: Text('${member.memberNumber} - ${member.fullName}'),
                  ),
                ).toList(),
                onChanged: (member) => controller.setSelectedMember(member!),
                validator: (value) => value == null ? 'Please select a member' : null,
              )),
              const SizedBox(height: 16.0),
              
              // Weight inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller.grossWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Gross Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final weight = double.tryParse(value!);
                        if (weight == null || weight <= 0) return 'Invalid weight';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: controller.tareWeightController,
                      decoration: const InputDecoration(
                        labelText: 'Tare Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final weight = double.tryParse(value!);
                        if (weight == null || weight < 0) return 'Invalid weight';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              
              // Net weight display
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Weight:'),
                      Obx(() => Text(
                        '${controller.netWeight.value.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              
              // Manual entry checkbox
              Obx(() => CheckboxListTile(
                title: const Text('Manual Entry'),
                subtitle: const Text('Check if not using electronic scale'),
                value: controller.isManualEntry.value,
                onChanged: (value) => controller.setManualEntry(value ?? false),
              )),
              
              const Spacer(),
              
              // Error display
              Obx(() {
                final error = controller.error.value;
                if (error.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8.0),
                      Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              }),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: Obx(() => ElevatedButton(
                  onPressed: controller.isCollecting.value 
                      ? null 
                      : () async {
                          final collection = await controller.addCollection();
                          if (collection != null) {
                            Get.back();
                          
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                  ),
                  child: controller.isCollecting.value
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                            SizedBox(width: 16.0),
                            Text('Recording Collection...'),
                          ],
                        )
                      : const Text('Post Value'),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 