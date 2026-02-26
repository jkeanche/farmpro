import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';

class NavisionSettingsScreen extends StatefulWidget {
  static const String routeName = '/navision-settings';

  const NavisionSettingsScreen({super.key});

  @override
  State<NavisionSettingsScreen> createState() => _NavisionSettingsScreenState();
}

class _NavisionSettingsScreenState extends State<NavisionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyIdController = TextEditingController();
  
  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool _obscurePassword = true;
  String? _connectionStatus;
  bool? _connectionSuccess;

  NavisionService? _navisionService;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _companyIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the NavisionService instance
      _navisionService = Get.find<NavisionService>();
      
      // Load the saved base URL from settings
      final settingsService = Get.find<SettingsService>();
      final baseUrl = await settingsService.getSetting('navision_base_url') ?? '';
      
      // Load credentials
      final credentials = await _navisionService?.getCredentials() ?? {};
      
      setState(() {
        _baseUrlController.text = baseUrl;
        _usernameController.text = credentials['username'] ?? '';
        _passwordController.text = credentials['password'] ?? '';
        _companyIdController.text = credentials['companyId'] ?? '';
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error loading settings: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save the base URL to settings
      final settingsService = Get.find<SettingsService>();
      await settingsService.saveSetting('navision_base_url', _baseUrlController.text);
      
      // Save credentials
      await _navisionService?.saveCredentials(
        username: _usernameController.text,
        password: _passwordController.text,
        companyId: _companyIdController.text,
      );
      
      Get.snackbar(
        'Success',
        'Navision settings saved successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error saving settings: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
      _connectionSuccess = null;
    });

    try {
      // Create a temporary NavisionService with the current settings
      final tempService = NavisionService(baseUrl: _baseUrlController.text);
      
      // Save credentials temporarily
      await tempService.saveCredentials(
        username: _usernameController.text,
        password: _passwordController.text,
        companyId: _companyIdController.text,
      );
      
      // Test the connection
      final success = await tempService.testConnection();
      
      setState(() {
        _connectionSuccess = success;
        _connectionStatus = success 
            ? 'Connection successful!' 
            : 'Connection failed. Please check your settings.';
      });
    } catch (e) {
      setState(() {
        _connectionSuccess = false;
        _connectionStatus = 'Error testing connection: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _syncFarmers() async {
    if (_navisionService == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Get.snackbar(
        'Syncing',
        'Syncing farmers from Navision...',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      // Pull farmers from Navision
      final farmers = await _navisionService!.pullFarmers();
      
      // TODO: Save farmers to local database
      // This would typically be handled by a FarmerService or similar
      
      Get.snackbar(
        'Success',
        'Successfully synced ${farmers.length} farmers',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error syncing farmers: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Navision Integration',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Microsoft Dynamics 365 Business Central (Navision) Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        hintText: 'https://api.businesscentral.dynamics.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the API base URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyIdController,
                      decoration: const InputDecoration(
                        labelText: 'Company ID',
                        hintText: 'Enter your company ID or GUID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your company ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveSettings,
                            child: const Text('Save Settings'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || _isTestingConnection ? null : _testConnection,
                            child: _isTestingConnection
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Test Connection'),
                          ),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _connectionSuccess == true
                              ? Colors.green.shade100
                              : _connectionSuccess == false
                                  ? Colors.red.shade100
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            color: _connectionSuccess == true
                                ? Colors.green.shade800
                                : _connectionSuccess == false
                                    ? Colors.red.shade800
                                    : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Data Synchronization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _syncFarmers,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync Farmers from Navision'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () {
                        // TODO: Implement sync collections functionality
                        Get.snackbar(
                          'Coming Soon',
                          'This feature is coming soon',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text('Send Coffee Collections to Navision'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
