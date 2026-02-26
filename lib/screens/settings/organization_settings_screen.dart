import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../widgets/widgets.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends State<OrganizationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _societyNameController = TextEditingController();
  final _factoryController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _websiteController = TextEditingController();
  final _sloganController = TextEditingController();
  
  final _settingsController = Get.find<SettingsController>();
  
  String? _logoPath;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  void _loadSettings() {
    final settings = _settingsController.organizationSettings.value;
    if (settings != null) {
      _societyNameController.text = settings.societyName;
      _factoryController.text = settings.factory;
      _addressController.text = settings.address;
      _emailController.text = settings.email ?? '';
      _phoneNumberController.text = settings.phoneNumber ?? '';
      _websiteController.text = settings.website ?? '';
      _sloganController.text = settings.slogan ?? '';
      _logoPath = settings.logoPath;
    }
  }
  
  @override
  void dispose() {
    _societyNameController.dispose();
    _factoryController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _websiteController.dispose();
    _sloganController.dispose();
    super.dispose();
  }
  
  Future<void> _uploadLogo() async {
    try {
      final logoPath = await _settingsController.uploadLogo();
      if (logoPath != null) {
        setState(() {
          _logoPath = logoPath;
        });
        
        Get.snackbar(
          'Success',
          'Logo uploaded successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to upload logo: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }
  
  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _settingsController.updateOrganizationSettings(
          societyName: _societyNameController.text.trim(),
          factory: _factoryController.text.trim(),
          address: _addressController.text.trim(),
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phoneNumber: _phoneNumberController.text.trim().isNotEmpty
              ? _phoneNumberController.text.trim()
              : null,
          website: _websiteController.text.trim().isNotEmpty
              ? _websiteController.text.trim()
              : null,
          slogan: _sloganController.text.trim().isNotEmpty
              ? _sloganController.text.trim()
              : null,
        );
        
        Get.back();
        Get.snackbar(
          'Success',
          'Organization settings saved successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to save settings: $e',
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
      appBar: const CustomAppBar(
        title: 'Organization Settings',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Upload
              CustomCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Society Logo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    Center(
                      child: GestureDetector(
                        onTap: _uploadLogo,
                        child: Container(
                          width: 120.0,
                          height: 120.0,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.0,
                            ),
                          ),
                          child: _logoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.file(
                                    File(_logoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 40.0,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Upload Logo',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Center(
                      child: Text(
                        'Tap to upload or change logo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              
              // Society Information
              CustomCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Society Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Society Name
                    CustomTextField(
                      label: 'Society Name',
                      hint: 'Enter society name',
                      controller: _societyNameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter society name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Factory
                    CustomTextField(
                      label: 'Factory Name',
                      hint: 'Enter factory name',
                      controller: _factoryController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter factory name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Address
                    CustomTextField(
                      label: 'Address',
                      hint: 'Enter society address',
                      controller: _addressController,
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter society address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Slogan
                    CustomTextField(
                      label: 'Slogan (Optional)',
                      hint: 'Enter society slogan to display on receipts',
                      controller: _sloganController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Phone Number
                    CustomTextField(
                      label: 'Phone Number (Optional)',
                      hint: 'Enter phone number',
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Email
                    CustomTextField(
                      label: 'Email (Optional)',
                      hint: 'Enter email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Website
                    CustomTextField(
                      label: 'Website (Optional)',
                      hint: 'Enter website URL',
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              
              // Save Button
              Obx(() => CustomButton(
                    text: 'Save Settings',
                    onPressed: _saveSettings,
                    isLoading: _settingsController.isLoading.value,
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
