import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/controllers.dart';
import '../../services/database_helper.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _settingsController = Get.find<SettingsController>();
  final _bluetoothService = Get.find<BluetoothService>();
  final _printService = Get.find<PrintService>();
  final _permissionService = Get.find<PermissionService>();

  bool _enablePrinting = true;
  bool _enableSms = true;
  bool _enableManualWeightEntry = true;
  bool _enableBluetoothScale = true;
  String? _defaultPrinterAddress;
  String? _defaultScaleAddress;
  double _defaultTareWeight = 0.5; // Default tare weight for coffee containers
  String _printMethod = 'bluetooth'; // Default print method
  int _receiptDuplicates = 1; // Number of receipt copies for inventory sales
  bool _autoDisconnectScale =
      false; // Auto disconnect scale when leaving screen
  String _deliveryRestrictionMode =
      'multiple'; // Default to multiple deliveries per day
  final _coffeeProductController = TextEditingController();

  // SMS Gateway Configuration
  bool _smsGatewayEnabled = true;
  String _smsGatewayUrl = 'https://portal.zettatel.com/SMSApi/send';
  final _smsGatewayUsernameController = TextEditingController();
  final _smsGatewayPasswordController = TextEditingController();
  final _smsGatewaySenderIdController = TextEditingController();
  final _smsGatewayApiKeyController = TextEditingController();
  bool _smsGatewayFallbackToSim = true;

  @override
  void initState() {
    super.initState();
    // Load settings and then load sensitive settings from secure storage
    _loadSettings().then((_) => _loadSensitiveSettings());
  }

  @override
  void dispose() {
    _coffeeProductController.dispose();
    _smsGatewayUsernameController.dispose();
    _smsGatewayPasswordController.dispose();
    _smsGatewaySenderIdController.dispose();
    _smsGatewayApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = _settingsController.systemSettings.value;
    if (settings != null) {
      print(
        '🔧 SystemSettingsScreen: Loading defaultTareWeight = ${settings.defaultTareWeight}',
      );
      if (mounted) {
        setState(() {
          _enablePrinting = settings.enablePrinting;
          _enableSms = settings.enableSms;
          _enableManualWeightEntry = settings.enableManualWeightEntry;
          _enableBluetoothScale = settings.enableBluetoothScale;
          _defaultPrinterAddress = settings.defaultPrinterAddress;
          _defaultScaleAddress = settings.defaultScaleAddress;
          _defaultTareWeight = settings.defaultTareWeight;
          _printMethod = settings.printMethod;
          _receiptDuplicates = settings.receiptDuplicates;
          _autoDisconnectScale = settings.autoDisconnectScale;
          _deliveryRestrictionMode = settings.deliveryRestrictionMode;
          _coffeeProductController.text = settings.coffeeProduct;

          // SMS Gateway Configuration
          _smsGatewayEnabled = settings.smsGatewayEnabled;
          _smsGatewayUrl = settings.smsGatewayUrl;
          _smsGatewayUsernameController.text = settings.smsGatewayUsername;
          _smsGatewayPasswordController.text = settings.smsGatewayPassword;
          _smsGatewaySenderIdController.text = settings.smsGatewaySenderId;
          _smsGatewayApiKeyController.text = settings.smsGatewayApiKey;
          _smsGatewayFallbackToSim = settings.smsGatewayFallbackToSim;
        });
      }
    }
  }

  Future<void> _loadSensitiveSettings() async {
    try {
      // Get the current settings from the controller
      final settings = _settingsController.systemSettings.value;
      if (mounted && settings != null) {
        setState(() {
          // Update SMS Gateway settings with current values
          _smsGatewayUsernameController.text = settings.smsGatewayUsername;
          _smsGatewayPasswordController.text = settings.smsGatewayPassword;
          _smsGatewaySenderIdController.text = settings.smsGatewaySenderId;
          _smsGatewayApiKeyController.text = settings.smsGatewayApiKey;
        });
      }
    } catch (e) {
      print('Error loading sensitive settings: $e');
    }
  }

  Future<void> _scanBluetoothDevices() async {
    try {
      // First check if Bluetooth is available and enabled
      bool bluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!bluetoothEnabled) {
        await _bluetoothService.requestBluetoothEnable();
        // Double check if user granted it
        bluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
        if (!bluetoothEnabled) {
          Get.snackbar(
            'Bluetooth Disabled',
            'Please enable Bluetooth to scan for devices',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Theme.of(context).colorScheme.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
          return;
        }
      }

      // Check and request permissions using PermissionService
      bool hasPermissions = await _permissionService.checkBluetoothPermission();
      if (!hasPermissions) {
        hasPermissions = await _permissionService.requestBluetoothPermission();
        if (!hasPermissions) {
          Get.snackbar(
            'Permission Required',
            'Bluetooth permissions are required for scanning',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Theme.of(context).colorScheme.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
          return;
        }
      }

      // Start BLE scan
      await _settingsController.scanBluetoothDevices();

      // If no devices were found after scanning
      if (_bluetoothService.devices.isEmpty) {
        Get.snackbar(
          'No Devices Found',
          'No Bluetooth devices were detected. For classic Bluetooth scales, use manual pairing.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to scan Bluetooth devices: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> _connectToPrinter(String deviceAddress) async {
    try {
      await _settingsController.connectToPrinter(deviceAddress);
      setState(() {
        _defaultPrinterAddress = deviceAddress;
      });

      Get.snackbar(
        'Success',
        'Connected to printer',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.primary,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to connect to printer: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> _connectToScale(String deviceAddress) async {
    try {
      await _settingsController.connectToScale(deviceAddress);
      setState(() {
        _defaultScaleAddress = deviceAddress;
        _enableBluetoothScale = true;
      });

      Get.snackbar(
        'Success',
        'Connected to scale',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.primary,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to connect to scale: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // Connect to classic Bluetooth scale with manual pairing
  Future<void> _connectToClassicScale(String address) async {
    try {
      bool connected = await _bluetoothService.connectToClassicDeviceByAddress(
        address,
      );

      if (connected) {
        setState(() {
          _defaultScaleAddress = address;
          _enableBluetoothScale = true;
        });

        Get.snackbar(
          'Scale Connected',
          'Successfully connected to classic Bluetooth scale',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Connection Error',
        'Failed to connect to classic scale: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Show classic Bluetooth setup instructions
  void _showClassicBluetoothInstructions() {
    _bluetoothService.showClassicBluetoothPairingInstructions();
  }

  // Add paired classic Bluetooth device
  void _addPairedDevice() {
    _bluetoothService.showAddPairedDeviceDialog();
  }

  Future<void> _saveSettings() async {
    try {
      // Validate SMS gateway configuration if enabled
      if (_smsGatewayEnabled) {
        final username = _smsGatewayUsernameController.text.trim();
        final password = _smsGatewayPasswordController.text.trim();
        final senderId = _smsGatewaySenderIdController.text.trim();

        if (username.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'SMS Gateway username is required when gateway is enabled',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        if (password.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'SMS Gateway password is required when gateway is enabled',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        if (senderId.isEmpty) {
          Get.snackbar(
            'Validation Error',
            'SMS Gateway Sender ID is required when gateway is enabled',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        // Validate URL format
        final uri = Uri.tryParse(_smsGatewayUrl);
        if (_smsGatewayUrl.isEmpty || uri == null || !uri.hasAbsolutePath) {
          Get.snackbar(
            'Validation Error',
            'Please enter a valid SMS Gateway URL',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }

      // Check if coffee product has changed
      final originalSettings = _settingsController.systemSettings.value;
      final newCoffeeProduct = _coffeeProductController.text.toUpperCase();
      final hasProductChanged =
          originalSettings != null &&
          originalSettings.coffeeProduct.toUpperCase() != newCoffeeProduct;

      if (hasProductChanged) {
        // Check if there are existing collections
        final coffeeCollectionService = Get.find<CoffeeCollectionService>();
        final hasCollections = coffeeCollectionService.collections.isNotEmpty;

        if (hasCollections) {
          // Show confirmation dialog
          final confirmed = await _showCropChangeConfirmationDialog();
          if (!confirmed) {
            return; // User cancelled
          }

          // Backup database (preserve all data)
          await _backupDatabaseForCropChange();
        }
      }

      print(
        '💾 SystemSettingsScreen: Saving defaultTareWeight = $_defaultTareWeight',
      );
      await _settingsController.updateSystemSettings(
        enablePrinting: _enablePrinting,
        enableSms: _enableSms,
        enableManualWeightEntry: _enableManualWeightEntry,
        enableBluetoothScale: _enableBluetoothScale,
        defaultPrinterAddress: _defaultPrinterAddress,
        defaultScaleAddress: _defaultScaleAddress,
        defaultTareWeight: _defaultTareWeight,
        printMethod: _printMethod,
        receiptDuplicates: _receiptDuplicates,
        coffeeProduct: _coffeeProductController.text,
        autoDisconnectScale: _autoDisconnectScale,
        deliveryRestrictionMode: _deliveryRestrictionMode,
        // SMS Gateway Configuration
        smsGatewayEnabled: _smsGatewayEnabled,
        smsGatewayUrl: _smsGatewayUrl,
        smsGatewayUsername: _smsGatewayUsernameController.text,
        smsGatewayPassword: _smsGatewayPasswordController.text,
        smsGatewaySenderId: _smsGatewaySenderIdController.text,
        smsGatewayApiKey: _smsGatewayApiKeyController.text,
        smsGatewayFallbackToSim: _smsGatewayFallbackToSim,
      );

      // Update PrintService with the selected print method
      if (_printMethod == 'bluetooth') {
        _printService.setPrintMethod('bluetooth');
      } else {
        _printService.setPrintMethod('standard');
      }

      Get.back();

      Get.snackbar(
        'Success',
        'Settings updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving settings: $e');
      Get.snackbar(
        'Error',
        'Failed to save settings: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> _showCropChangeConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: const Text('Crop/Season Change Detected'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are changing the coffee product/crop type. This will:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Text('• Create a backup of your current database'),
                    Text('• Preserve all existing coffee collections and data'),
                    Text(
                      '• Allow you to revert to previous crop settings if needed',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'All your data will be retained. You can switch back to the previous crop type at any time to access historical collections.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _backupDatabaseForCropChange() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Creating database backup...'),
                ],
              ),
            ),
      );

      final databaseHelper = Get.find<DatabaseHelper>();

      // Create database backup (preserve all data)
      await databaseHelper.backupDatabase();

      // Close loading dialog
      Navigator.of(context).pop();

      Get.snackbar(
        'Backup Complete',
        'Database backed up successfully. All data has been preserved.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error backing up database: $e');
      Get.snackbar(
        'Backup Error',
        'Failed to backup database: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow; // Re-throw to prevent settings save
    }
  }

  // Show dialog to set default tare weight
  void _showTareWeightDialog(BuildContext context) {
    final TextEditingController tareWeightController = TextEditingController(
      text: _defaultTareWeight.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Default Tare Weight'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set the default tare weight for coffee containers. This value will be pre-filled during coffee collection.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tareWeightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tare Weight (kg)',
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newValue = double.tryParse(tareWeightController.text);
                  if (newValue != null && newValue >= 0) {
                    print(
                      '📏 Setting new tare weight: $newValue (was: $_defaultTareWeight)',
                    );
                    setState(() {
                      _defaultTareWeight = newValue;
                    });
                    Navigator.of(context).pop();

                    // Show confirmation that the value has been updated locally
                    Get.snackbar(
                      'Tare Weight Updated',
                      'New default tare weight: ${newValue.toStringAsFixed(1)} kg\nRemember to save settings to apply changes.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 3),
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                      'Please enter a valid tare weight',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  // Show dialog to select print method
  void _showPrintMethodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Print Method'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Bluetooth Printer'),
                  subtitle: const Text('Use a Bluetooth thermal printer'),
                  value: 'bluetooth',
                  groupValue: _printMethod,
                  onChanged: (value) {
                    setState(() {
                      _printMethod = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Standard Printer'),
                  subtitle: const Text('Use system printer or PDF export'),
                  value: 'standard',
                  groupValue: _printMethod,
                  onChanged: (value) {
                    setState(() {
                      _printMethod = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Show dialog to select collection restriction mode
  void _showCollectionRestrictionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Daily Collection Limit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose how many times a member can make coffee collections in the same day:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text('Multiple Collections'),
                  subtitle: const Text(
                    'Members can make unlimited collections per day',
                  ),
                  value: 'multiple',
                  groupValue: _deliveryRestrictionMode,
                  onChanged: (value) {
                    setState(() {
                      _deliveryRestrictionMode = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Single Collection'),
                  subtitle: const Text(
                    'Members can only make one collection per day',
                  ),
                  value: 'single',
                  groupValue: _deliveryRestrictionMode,
                  onChanged: (value) {
                    setState(() {
                      _deliveryRestrictionMode = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Show dialog to select number of receipt copies for inventory sales
  void _showReceiptCopiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Inventory Receipt Copies'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select how many copies to print for inventory sale receipts:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                RadioListTile<int>(
                  title: const Text('Single Copy'),
                  subtitle: const Text('Print one receipt per sale'),
                  value: 1,
                  groupValue: _receiptDuplicates,
                  onChanged: (value) {
                    setState(() {
                      _receiptDuplicates = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                RadioListTile<int>(
                  title: const Text('Double Copy'),
                  subtitle: const Text('Print two receipts per sale'),
                  value: 2,
                  groupValue: _receiptDuplicates,
                  onChanged: (value) {
                    setState(() {
                      _receiptDuplicates = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Show dialog to set SMS Gateway URL
  void _showSmsGatewayUrlDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController(
      text: _smsGatewayUrl,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('SMS Gateway URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the SMS gateway API endpoint URL. This is typically provided by your SMS service provider.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Gateway URL',
                    border: OutlineInputBorder(),
                    hintText: 'https://api.smsgateway.com/send',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newUrl = urlController.text.trim();
                  if (newUrl.isNotEmpty) {
                    setState(() {
                      _smsGatewayUrl = newUrl;
                    });
                    Navigator.of(context).pop();

                    Get.snackbar(
                      'Gateway URL Updated',
                      'SMS gateway URL has been updated. Remember to save settings to apply changes.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 3),
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                      'Please enter a valid URL',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  // Refresh default printer
  Future<void> _refreshDefaultPrinter(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Refreshing default printer...'),
                ],
              ),
            ),
      );

      // Refresh and select default printer
      await _printService.refreshAndSelectDefaultPrinter();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      Get.snackbar(
        'Success',
        'Default printer refreshed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('Error refreshing default printer: $e');
      Get.snackbar(
        'Error',
        'Failed to refresh default printer: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'System Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Settings
            CustomCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),

                  // Enable Printing
                  SwitchListTile(
                    title: const Text('Enable Printing'),
                    subtitle: const Text(
                      'Automatically print receipts after coffee collection',
                    ),
                    value: _enablePrinting,
                    onChanged: (value) {
                      setState(() {
                        _enablePrinting = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  // Enable SMS
                  SwitchListTile(
                    title: const Text('Enable SMS Notifications'),
                    subtitle: const Text('Send SMS notifications to members'),
                    value: _enableSms,
                    onChanged: (value) {
                      setState(() {
                        _enableSms = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  // Enable Manual Weight Entry
                  SwitchListTile(
                    title: const Text('Enable Manual Weight Entry'),
                    subtitle: const Text('Allow manual entry of coffee weight'),
                    value: _enableManualWeightEntry,
                    onChanged: (value) {
                      setState(() {
                        _enableManualWeightEntry = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  // Enable Bluetooth Scale
                  SwitchListTile(
                    title: const Text('Enable Bluetooth Scale'),
                    subtitle: const Text('Connect to Bluetooth weighing scale'),
                    value: _enableBluetoothScale,
                    onChanged: (value) {
                      setState(() {
                        _enableBluetoothScale = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  // Auto Disconnect Scale
                  SwitchListTile(
                    title: const Text('Auto Disconnect Scale'),
                    subtitle: const Text(
                      'Automatically disconnect scale when leaving collection screen',
                    ),
                    value: _autoDisconnectScale,
                    onChanged:
                        _enableBluetoothScale
                            ? (value) {
                              setState(() {
                                _autoDisconnectScale = value;
                              });
                            }
                            : null, // Disable if Bluetooth scale is not enabled
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  const Divider(),

                  // Collection Restriction Mode
                  ListTile(
                    leading: const Icon(Icons.repeat),
                    title: const Text('Daily Collection Limit'),
                    subtitle: Text(
                      _deliveryRestrictionMode == 'single'
                          ? 'Single - Members can only make one collection per day'
                          : 'Multiple - Members can make multiple collections per day',
                    ),
                    trailing: const Icon(Icons.settings, size: 16),
                    onTap: () => _showCollectionRestrictionDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // SMS Gateway Configuration
            CustomCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS Gateway Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),

                  // Enable SMS Gateway
                  SwitchListTile(
                    title: const Text('Enable SMS Gateway'),
                    subtitle: const Text(
                      'Use SMS gateway service for sending messages',
                    ),
                    value: _smsGatewayEnabled,
                    onChanged: (value) {
                      setState(() {
                        _smsGatewayEnabled = value;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),

                  if (_smsGatewayEnabled) ...[
                    const Divider(),

                    // SMS Gateway URL
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: const Text('Gateway URL'),
                      subtitle: Text(_smsGatewayUrl),
                      trailing: const Icon(Icons.edit, size: 16),
                      onTap: () => _showSmsGatewayUrlDialog(context),
                    ),

                    const Divider(),

                    // SMS Gateway Username
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Username'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enter your SMS gateway username'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _smsGatewayUsernameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter username',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // SMS Gateway Password
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Password'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enter your SMS gateway password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _smsGatewayPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter password',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // SMS Gateway Sender ID
                    ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Sender ID'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sender ID that appears on SMS messages'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _smsGatewaySenderIdController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'e.g., FARMPRO',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              // Auto-convert to uppercase as user types
                              final upperValue = value.toUpperCase();
                              if (upperValue != value) {
                                _smsGatewaySenderIdController
                                    .value = _smsGatewaySenderIdController.value
                                    .copyWith(
                                      text: upperValue,
                                      selection: TextSelection.collapsed(
                                        offset: upperValue.length,
                                      ),
                                    );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // SMS Gateway API Key (Optional)
                    ListTile(
                      leading: const Icon(Icons.key),
                      title: const Text('API Key (Optional)'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API key for additional authentication (if required)',
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _smsGatewayApiKeyController,
                            decoration: const InputDecoration(
                              hintText: 'Enter API key (optional)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // SMS Gateway Fallback to SIM
                    SwitchListTile(
                      title: const Text('SIM Card Fallback'),
                      subtitle: const Text('Use SIM card if gateway fails'),
                      value: _smsGatewayFallbackToSim,
                      onChanged: (value) {
                        setState(() {
                          _smsGatewayFallbackToSim = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // System Configuration
            CustomCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),

                  // Print Method
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: const Text('Print Method'),
                    subtitle: Text(
                      _printMethod == 'bluetooth'
                          ? 'Bluetooth Printer'
                          : 'Standard Printer',
                    ),
                    trailing: const Icon(Icons.settings, size: 16),
                    onTap: () => _showPrintMethodDialog(context),
                  ),

                  const Divider(),

                  // Receipt Copies for Inventory Sales
                  ListTile(
                    leading: const Icon(Icons.content_copy),
                    title: const Text('Inventory Receipt Copies'),
                    subtitle: Text(
                      _receiptDuplicates == 1
                          ? 'Single copy'
                          : '$_receiptDuplicates copies',
                    ),
                    trailing: const Icon(Icons.settings, size: 16),
                    onTap: () => _showReceiptCopiesDialog(context),
                  ),

                  const Divider(),

                  // Refresh Default Printer (only show for standard print method)
                  if (_printMethod == 'standard') ...[
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Refresh Default Printer'),
                      subtitle: const Text(
                        'Update to use system default printer',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _refreshDefaultPrinter(context),
                    ),

                    const Divider(),
                  ],

                  // Default Tare Weight
                  ListTile(
                    leading: const Icon(Icons.scale),
                    title: const Text('Default Tare Weight'),
                    subtitle: Text(
                      '${_defaultTareWeight.toStringAsFixed(1)} kg',
                    ),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: () => _showTareWeightDialog(context),
                  ),

                  const Divider(),

                  // Coffee Product
                  ListTile(
                    leading: const Icon(Icons.local_cafe),
                    title: const Text('Coffee Product'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Enter coffee product type'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _coffeeProductController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., MBUNI, CHERRY',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) {
                            // Auto-convert to uppercase as user types
                            final upperValue = value.toUpperCase();
                            if (upperValue != value) {
                              _coffeeProductController.value =
                                  _coffeeProductController.value.copyWith(
                                    text: upperValue,
                                    selection: TextSelection.collapsed(
                                      offset: upperValue.length,
                                    ),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(),
                ],
              ),
            ),

            const SizedBox(height: 16.0),

            // Bluetooth Devices
            CustomCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bluetooth Devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Obx(
                        () =>
                            _bluetoothService.isScanning.value
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                )
                                : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _scanBluetoothDevices,
                                  tooltip: 'Scan for devices',
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Bluetooth Devices List
                  Obx(() {
                    final connectedDevices = _bluetoothService.connectedDevices;
                    final scannedDevices = _bluetoothService.devices;
                    final pairedClassicDevices =
                        _bluetoothService.classicDeviceInfo;

                    if (connectedDevices.isEmpty &&
                        scannedDevices.isEmpty &&
                        pairedClassicDevices.isEmpty) {
                      return Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text('No Bluetooth devices found'),
                            ),
                          ),
                          // Add manual pairing option for classic Bluetooth
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Classic Bluetooth Scale?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'If your scale requires PIN pairing (like 1234), use manual pairing through Android Settings.',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _showClassicBluetoothInstructions,
                                        icon: const Icon(Icons.help_outline),
                                        label: const Text('Pairing Guide'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _addPairedDevice,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Paired Device'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Paired Classic Devices Section
                        if (pairedClassicDevices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Paired Classic Bluetooth Devices',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pairedClassicDevices.length,
                            itemBuilder: (context, index) {
                              final device = pairedClassicDevices[index];
                              final isScale =
                                  _defaultScaleAddress == device['address'];

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.bluetooth,
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    device['name'] ?? 'Unknown Device',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Address: ${device['address']}'),
                                      Text(
                                        'Status: ${device['pin']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isScale)
                                        const Chip(
                                          label: Text('Active Scale'),
                                          backgroundColor: Colors.green,
                                          labelStyle: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed:
                                            () => _connectToClassicScale(
                                              device['address']!,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              isScale
                                                  ? Colors.orange
                                                  : Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(
                                          isScale ? 'Reconnect' : 'Connect',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Connected BLE Devices Section
                        if (connectedDevices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Connected BLE Devices',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: connectedDevices.length,
                            itemBuilder: (context, index) {
                              final device = connectedDevices[index];
                              final isPrinter =
                                  _defaultPrinterAddress == device.address;
                              final isScale =
                                  _defaultScaleAddress == device.address;

                              return ListTile(
                                title: Text(
                                  device.name?.isNotEmpty == true
                                      ? device.name!
                                      : 'Unknown Device',
                                ),
                                subtitle: Text(device.address),
                                leading: Icon(
                                  isScale
                                      ? Icons.scale
                                      : isPrinter
                                      ? Icons.print
                                      : Icons.bluetooth,
                                  color:
                                      (isPrinter || isScale)
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : null,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isPrinter && !isScale) ...[
                                      ElevatedButton(
                                        onPressed: () {
                                          _connectToPrinter(device.address);
                                        },
                                        child: const Text('Printer'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          _connectToScale(device.address);
                                        },
                                        child: const Text('Scale'),
                                      ),
                                    ],
                                    if (isPrinter || isScale) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          isPrinter ? 'Printer' : 'Scale',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // Available BLE Devices Section
                        if (scannedDevices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Available BLE Devices',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: scannedDevices.length,
                            itemBuilder: (context, index) {
                              final device = scannedDevices[index];
                              final isPrinter =
                                  _defaultPrinterAddress == device.address;
                              final isScale =
                                  _defaultScaleAddress == device.address;

                              return ListTile(
                                title: Text(
                                  device.name?.isNotEmpty == true
                                      ? device.name!
                                      : 'Unknown Device',
                                ),
                                subtitle: Text(device.address),
                                leading: Icon(
                                  isScale
                                      ? Icons.scale
                                      : isPrinter
                                      ? Icons.print
                                      : Icons.bluetooth,
                                  color:
                                      (isPrinter || isScale)
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : null,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isPrinter && !isScale) ...[
                                      ElevatedButton(
                                        onPressed: () {
                                          _connectToPrinter(device.address);
                                        },
                                        child: const Text('Printer'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          _connectToScale(device.address);
                                        },
                                        child: const Text('Scale'),
                                      ),
                                    ],
                                    if (isPrinter || isScale) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          isPrinter ? 'Printer' : 'Scale',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // Classic Bluetooth information section
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'Classic Bluetooth Scales',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'If your scale requires PIN pairing (like 1234 or 0000), it uses classic Bluetooth. '
                                'These devices need to be paired manually through Android Settings, then added here.',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _showClassicBluetoothInstructions,
                                      icon: const Icon(
                                        Icons.settings_bluetooth,
                                      ),
                                      label: const Text('Setup Guide'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _addPairedDevice,
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text('Paired Device'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 8.0),
                  Center(
                    child: CustomButton(
                      text: 'Scan for Devices',
                      onPressed: _scanBluetoothDevices,
                      buttonType: ButtonType.outline,
                      icon: Icons.bluetooth_searching,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Save Button
            Obx(
              () => CustomButton(
                text: 'Save Settings',
                onPressed: _saveSettings,
                isLoading: _settingsController.isLoading.value,
                isFullWidth: true,
                height: 50.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
