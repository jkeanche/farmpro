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
  double _defaultTareWeight = 0.5;
  String _printMethod = 'bluetooth';
  int _receiptDuplicates = 1;
  bool _autoDisconnectScale = false;
  String _deliveryRestrictionMode = 'multiple';
  final _coffeeProductController = TextEditingController();

  // ── SMS MODE: 'sim' or 'gateway' ──────────────────────────
  String _smsMode = 'sim';

  // SMS Gateway Configuration
  bool _smsGatewayEnabled = false;
  String _smsGatewayUrl = 'https://portal.zettatel.com/SMSApi/send';
  final _smsGatewayUsernameController = TextEditingController();
  final _smsGatewayPasswordController = TextEditingController();
  final _smsGatewaySenderIdController = TextEditingController();
  final _smsGatewayApiKeyController = TextEditingController();
  bool _smsGatewayFallbackToSim = true;

  bool get _gatewayConfigured =>
      _smsGatewayUrl.isNotEmpty &&
      _smsGatewayUsernameController.text.trim().isNotEmpty &&
      _smsGatewayPasswordController.text.trim().isNotEmpty &&
      _smsGatewaySenderIdController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
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

          // SMS mode
          _smsMode = settings.smsMode;
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
      final settings = _settingsController.systemSettings.value;
      if (mounted && settings != null) {
        setState(() {
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

  // ── BLUETOOTH HELPERS ───────────────────────────────────────

  Future<void> _scanBluetoothDevices() async {
    try {
      bool bluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!bluetoothEnabled) {
        await _bluetoothService.requestBluetoothEnable();
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

      await _settingsController.scanBluetoothDevices();

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
      setState(() => _defaultPrinterAddress = deviceAddress);
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

  void _showClassicBluetoothInstructions() =>
      _bluetoothService.showClassicBluetoothPairingInstructions();

  void _addPairedDevice() => _bluetoothService.showAddPairedDeviceDialog();

  // ── SAVE ───────────────────────────────────────────────────

  Future<void> _saveSettings() async {
    try {
      // Validate gateway config if gateway mode is selected
      if (_smsMode == 'gateway') {
        if (!_gatewayConfigured) {
          Get.snackbar(
            'Gateway Not Configured',
            'You have selected Gateway SMS mode but the gateway credentials are incomplete. '
                'Please fill in Username, Password, and Sender ID, or switch to SIM Card mode.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6),
            margin: const EdgeInsets.all(12),
          );
          // Still allow saving so user can fill credentials
        }
      }

      final originalSettings = _settingsController.systemSettings.value;
      final newCoffeeProduct = _coffeeProductController.text.toUpperCase();
      final hasProductChanged =
          originalSettings != null &&
          originalSettings.coffeeProduct.toUpperCase() != newCoffeeProduct;

      if (hasProductChanged) {
        final coffeeCollectionService = Get.find<CoffeeCollectionService>();
        final hasCollections = coffeeCollectionService.collections.isNotEmpty;
        if (hasCollections) {
          final confirmed = await _showCropChangeConfirmationDialog();
          if (!confirmed) return;
          await _backupDatabaseForCropChange();
        }
      }

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
        // SMS mode
        smsMode: _smsMode,
        smsGatewayEnabled: _smsMode == 'gateway',
        smsGatewayUrl: _smsGatewayUrl,
        smsGatewayUsername: _smsGatewayUsernameController.text,
        smsGatewayPassword: _smsGatewayPasswordController.text,
        smsGatewaySenderId: _smsGatewaySenderIdController.text,
        smsGatewayApiKey: _smsGatewayApiKeyController.text,
        smsGatewayFallbackToSim: _smsGatewayFallbackToSim,
      );

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
                      'All your data will be retained.',
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
      await databaseHelper.backupDatabase();
      Navigator.of(context).pop();
      Get.snackbar(
        'Backup Complete',
        'Database backed up successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      Get.snackbar(
        'Backup Error',
        'Failed to backup database: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  // ── DIALOGS ────────────────────────────────────────────────

  void _showTareWeightDialog(BuildContext context) {
    final controller = TextEditingController(
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
                  'Set the default tare weight for coffee containers.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
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
                  final v = double.tryParse(controller.text);
                  if (v != null && v >= 0) {
                    setState(() => _defaultTareWeight = v);
                    Navigator.of(context).pop();
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
                  onChanged: (v) {
                    setState(() => _printMethod = v!);
                    Navigator.of(context).pop();
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Standard Printer'),
                  subtitle: const Text('Use system printer or PDF export'),
                  value: 'standard',
                  groupValue: _printMethod,
                  onChanged: (v) {
                    setState(() => _printMethod = v!);
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
                  onChanged: (v) {
                    setState(() => _deliveryRestrictionMode = v!);
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
                  onChanged: (v) {
                    setState(() => _deliveryRestrictionMode = v!);
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
                  onChanged: (v) {
                    setState(() => _receiptDuplicates = v!);
                    Navigator.of(context).pop();
                  },
                ),
                RadioListTile<int>(
                  title: const Text('Double Copy'),
                  subtitle: const Text('Print two receipts per sale'),
                  value: 2,
                  groupValue: _receiptDuplicates,
                  onChanged: (v) {
                    setState(() => _receiptDuplicates = v!);
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

  void _showSmsGatewayUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: _smsGatewayUrl);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('SMS Gateway URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the SMS gateway API endpoint URL.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Gateway URL',
                    border: OutlineInputBorder(),
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
                  if (controller.text.trim().isNotEmpty) {
                    setState(() => _smsGatewayUrl = controller.text.trim());
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _refreshDefaultPrinter(BuildContext context) async {
    try {
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
      await _printService.refreshAndSelectDefaultPrinter();
      Navigator.of(context).pop();
      Get.snackbar(
        'Success',
        'Default printer refreshed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      Get.snackbar(
        'Error',
        'Failed to refresh default printer: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ── BUILD ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'System Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── GENERAL SETTINGS ────────────────────────────────
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
                  SwitchListTile(
                    title: const Text('Enable Printing'),
                    subtitle: const Text(
                      'Automatically print receipts after coffee collection',
                    ),
                    value: _enablePrinting,
                    onChanged: (v) => setState(() => _enablePrinting = v),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Enable SMS Notifications'),
                    subtitle: const Text('Send SMS notifications to members'),
                    value: _enableSms,
                    onChanged: (v) => setState(() => _enableSms = v),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Enable Manual Weight Entry'),
                    subtitle: const Text(
                      'Allow manual entry of coffee weight (Admins/Managers only)',
                    ),
                    value: _enableManualWeightEntry,
                    onChanged:
                        (v) => setState(() => _enableManualWeightEntry = v),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Enable Bluetooth Scale'),
                    subtitle: const Text('Connect to Bluetooth weighing scale'),
                    value: _enableBluetoothScale,
                    onChanged: (v) => setState(() => _enableBluetoothScale = v),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Auto Disconnect Scale'),
                    subtitle: const Text(
                      'Automatically disconnect scale when leaving collection screen',
                    ),
                    value: _autoDisconnectScale,
                    onChanged:
                        _enableBluetoothScale
                            ? (v) => setState(() => _autoDisconnectScale = v)
                            : null,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.repeat),
                    title: const Text('Daily Collection Limit'),
                    subtitle: Text(
                      _deliveryRestrictionMode == 'single'
                          ? 'Single - one collection per day'
                          : 'Multiple - unlimited collections per day',
                    ),
                    trailing: const Icon(Icons.settings, size: 16),
                    onTap: () => _showCollectionRestrictionDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // ── SMS CONFIGURATION ────────────────────────────────
            CustomCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16.0),

                  // ── SMS MODE TOGGLE ──────────────────────────────
                  Text(
                    'SMS Sending Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'sim',
                          groupValue: _smsMode,
                          onChanged: (v) => setState(() => _smsMode = v!),
                          title: Row(
                            children: const [
                              Icon(
                                Icons.sim_card,
                                size: 20,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text('SIM Card SMS'),
                            ],
                          ),
                          subtitle: const Text(
                            'Send SMS directly from this device\'s SIM card.',
                            style: TextStyle(fontSize: 12),
                          ),
                          activeColor: Colors.blue,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        RadioListTile<String>(
                          value: 'gateway',
                          groupValue: _smsMode,
                          onChanged: (v) => setState(() => _smsMode = v!),
                          title: Row(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 20,
                                color:
                                    _gatewayConfigured
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              const Text('Bulk SMS Gateway'),
                              const SizedBox(width: 6),
                              if (!_gatewayConfigured)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NOT CONFIGURED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            _gatewayConfigured
                                ? 'Using bulk SMS gateway.'
                                : 'Configure gateway.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _gatewayConfigured
                                      ? null
                                      : Colors.orange.shade800,
                            ),
                          ),
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  // Warning when gateway mode is selected but not configured
                  if (_smsMode == 'gateway' && !_gatewayConfigured)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Gateway SMS is selected but credentials are incomplete. '
                              'Fill in Username, Password, and Sender ID below, then save.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // ── GATEWAY CONFIGURATION (shown always for editing) ──
                  Text(
                    'Gateway Credentials',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Gateway URL
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Gateway URL'),
                    subtitle: Text(
                      _smsGatewayUrl,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: () => _showSmsGatewayUrlDialog(context),
                  ),
                  const Divider(),

                  // Username
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Username'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SMS gateway username'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smsGatewayUsernameController,
                          onChanged: (_) => setState(() {}),
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

                  // Password
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Password'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SMS gateway password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smsGatewayPasswordController,
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
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

                  // Sender ID
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Sender ID'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sender ID shown on SMS messages'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _smsGatewaySenderIdController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g., FARMPRO',
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

                  // API Key (optional)
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('API Key (Optional)'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Additional authentication key if required'),
                        const SizedBox(height: 6),
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

                  // SIM Fallback (only meaningful in gateway mode)
                  SwitchListTile(
                    title: const Text('SIM Card Fallback'),
                    subtitle: const Text(
                      'Fall back to SIM card if gateway fails (Gateway mode only)',
                    ),
                    value: _smsGatewayFallbackToSim,
                    onChanged:
                        _smsMode == 'gateway'
                            ? (v) =>
                                setState(() => _smsGatewayFallbackToSim = v)
                            : null,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // ── SYSTEM CONFIGURATION ─────────────────────────────
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
                            final upper = value.toUpperCase();
                            if (upper != value) {
                              _coffeeProductController.value =
                                  _coffeeProductController.value.copyWith(
                                    text: upper,
                                    selection: TextSelection.collapsed(
                                      offset: upper.length,
                                    ),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // ── BLUETOOTH DEVICES ────────────────────────────────
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
                                  'If your scale requires PIN pairing, use manual pairing through Android Settings.',
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
                          ...pairedClassicDevices.map((device) {
                            final isScale =
                                _defaultScaleAddress == device['address'];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.bluetooth,
                                  color: Colors.blue,
                                ),
                                title: Text(device['name'] ?? 'Unknown Device'),
                                subtitle: Text('Address: ${device['address']}'),
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
                          }),
                          const SizedBox(height: 8),
                        ],
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
                          ...connectedDevices.map((device) {
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
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                              trailing:
                                  (isPrinter || isScale)
                                      ? Container(
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
                                      )
                                      : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            onPressed:
                                                () => _connectToPrinter(
                                                  device.address,
                                                ),
                                            child: const Text('Printer'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed:
                                                () => _connectToScale(
                                                  device.address,
                                                ),
                                            child: const Text('Scale'),
                                          ),
                                        ],
                                      ),
                            );
                          }),
                        ],
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
                          ...scannedDevices.map((device) {
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
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                              trailing:
                                  (isPrinter || isScale)
                                      ? Container(
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
                                      )
                                      : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            onPressed:
                                                () => _connectToPrinter(
                                                  device.address,
                                                ),
                                            child: const Text('Printer'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed:
                                                () => _connectToScale(
                                                  device.address,
                                                ),
                                            child: const Text('Scale'),
                                          ),
                                        ],
                                      ),
                            );
                          }),
                        ],
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
                                'If your scale requires PIN pairing, it uses classic Bluetooth and must be paired through Android Settings first.',
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

            // ── SAVE BUTTON ────────────────────────────────────
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
