import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AddMemberScreen extends StatefulWidget {
  final Member? member;

  const AddMemberScreen({super.key, this.member});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _zoneController = TextEditingController();
  final _acreageController = TextEditingController();
  final _noTreesController = TextEditingController();
  
  final _memberController = Get.find<MemberController>();
  
  bool _isEditing = false;
  String? _selectedGender;
  bool _isActive = true;
  
  // Gender options
  final List<String?> _genderOptions = [null, 'Male', 'Female', 'Other'];
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.member != null;
    
    if (_isEditing) {
      _memberNumberController.text = widget.member!.memberNumber;
      _fullNameController.text = widget.member!.fullName;
      _idNumberController.text = widget.member!.idNumber ?? '';
      _phoneNumberController.text = widget.member!.phoneNumber ?? '';
      _emailController.text = widget.member!.email ?? '';
      _zoneController.text = widget.member!.zone ?? '';
      _acreageController.text = widget.member!.acreage?.toString() ?? '';
      _noTreesController.text = widget.member!.noTrees?.toString() ?? '';
      _selectedGender = widget.member!.gender;
      _isActive = widget.member!.isActive;
    }
  }
  
  @override
  void dispose() {
    _memberNumberController.dispose();
    _fullNameController.dispose();
    _idNumberController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _zoneController.dispose();
    _acreageController.dispose();
    _noTreesController.dispose();
    super.dispose();
  }
  
  Future<void> _saveMember() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_isEditing) {
          // Parse optional numeric fields
          double? acreage;
          int? noTrees;
          
          if (_acreageController.text.trim().isNotEmpty) {
            acreage = double.tryParse(_acreageController.text.trim());
            if (acreage == null) {
              Get.snackbar(
                'Error',
                'Please enter a valid acreage value',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Theme.of(context).colorScheme.error,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
              );
              return;
            }
          }
          
          if (_noTreesController.text.trim().isNotEmpty) {
            noTrees = int.tryParse(_noTreesController.text.trim());
            if (noTrees == null) {
              Get.snackbar(
                'Error',
                'Please enter a valid number of trees',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Theme.of(context).colorScheme.error,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
              );
              return;
            }
          }
          
          // Update existing member
          final updatedMember = Member(
            id: widget.member!.id,
            memberNumber: widget.member!.memberNumber,
            fullName: _fullNameController.text.trim(),
            idNumber: _idNumberController.text.trim().isNotEmpty
                ? _idNumberController.text.trim()
                : null,
            phoneNumber: _phoneNumberController.text.trim().isNotEmpty
                ? _phoneNumberController.text.trim()
                : null,
            email: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            registrationDate: widget.member!.registrationDate,
            gender: _selectedGender, // Use selected gender
            zone: _zoneController.text.trim().isNotEmpty
                ? _zoneController.text.trim()
                : null,
            acreage: acreage,
            noTrees: noTrees,
            isActive: _isActive // Use active status from toggle
          );
          
          await _memberController.updateMember(updatedMember);
          
          // Force immediate UI update on member screen
          await _memberController.forceCompleteRefresh();
          
          Get.back();
          Get.snackbar(
            'Success',
            'Member updated successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Theme.of(context).colorScheme.primary,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        } else {
          // Parse optional numeric fields for new member
          double? acreage;
          int? noTrees;
          
          if (_acreageController.text.trim().isNotEmpty) {
            acreage = double.tryParse(_acreageController.text.trim());
            if (acreage == null) {
              Get.snackbar(
                'Error',
                'Please enter a valid acreage value',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Theme.of(context).colorScheme.error,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
              );
              return;
            }
          }
          
          if (_noTreesController.text.trim().isNotEmpty) {
            noTrees = int.tryParse(_noTreesController.text.trim());
            if (noTrees == null) {
              Get.snackbar(
                'Error',
                'Please enter a valid number of trees',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Theme.of(context).colorScheme.error,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
              );
              return;
            }
          }
          
          // Add new member
          await _memberController.addMember(
            memberNumber: _memberNumberController.text.trim(),
            fullName: _fullNameController.text.trim(),
            idNumber: _idNumberController.text.trim().isNotEmpty
                ? _idNumberController.text.trim()
                : null,
            phoneNumber: _phoneNumberController.text.trim().isNotEmpty
                ? _phoneNumberController.text.trim()
                : null,
            email: _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            gender: _selectedGender, // Use selected gender
            zone: _zoneController.text.trim().isNotEmpty
                ? _zoneController.text.trim()
                : null,
            acreage: acreage,
            noTrees: noTrees,
            isActive: _isActive // Use active status from toggle
          );
          
          // Force immediate UI update on member screen
          await _memberController.forceCompleteRefresh();
          
          Get.back();
          Get.snackbar(
            'Success',
            'Member added successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Theme.of(context).colorScheme.primary,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to ${_isEditing ? 'update' : 'add'} member: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _isEditing ? 'Edit Member' : 'Add Member',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member Information Card
              CustomCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Member Number Field
                    CustomTextField(
                      label: 'Member Number',
                      hint: 'Enter member number',
                      controller: _memberNumberController,
                      keyboardType: TextInputType.text,
                      readOnly: _isEditing, // Can't change member number when editing
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter member number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Full Name
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'Enter full name',
                      controller: _fullNameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // ID Number (Optional)
                    CustomTextField(
                      label: 'ID Number (Optional)',
                      hint: 'Enter national ID number',
                      controller: _idNumberController,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Phone Number (Optional)
                    CustomTextField(
                      label: 'Phone Number (Optional)',
                      hint: 'Enter phone number',
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Email (Optional)
                    CustomTextField(
                      label: 'Email (Optional)',
                      hint: 'Enter email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Gender Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gender (Optional)'),
                        const SizedBox(height: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedGender,
                              hint: const Text('Select gender'),
                              items: _genderOptions.map((String? gender) {
                                return DropdownMenuItem<String?>(
                                  value: gender,
                                  child: Text(gender ?? 'Not specified'),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Zone Field
                    TextFormField(
                      controller: _zoneController,
                      decoration: const InputDecoration(
                        labelText: 'Zone (Optional)',
                        hintText: 'e.g., Zone A, North, Central',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Acreage and No. Trees Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _acreageController,
                            decoration: const InputDecoration(
                              labelText: 'Acreage (Optional)',
                              hintText: 'e.g., 2.5',
                              border: OutlineInputBorder(),
                              suffixText: 'acres',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: TextFormField(
                            controller: _noTreesController,
                            decoration: const InputDecoration(
                              labelText: 'No. Trees (Optional)',
                              hintText: 'e.g., 150',
                              border: OutlineInputBorder(),
                              suffixText: 'trees',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Active Status Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Member Status'),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    // Status indicator text
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: _isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              
              // Save Button
              Obx(() => CustomButton(
                    text: _isEditing ? 'Update Member' : 'Add Member',
                    onPressed: _saveMember,
                    isLoading: _memberController.isLoading.value,
                    isFullWidth: true,
                    height: 50.0,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
