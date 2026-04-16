import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/gap_scale_service.dart';
import '../../services/services.dart';
import '../../widgets/custom_text_field.dart';

class CoffeeCollectionScreen extends StatefulWidget {
  const CoffeeCollectionScreen({super.key});

  @override
  State<CoffeeCollectionScreen> createState() => _CoffeeCollectionScreenState();
}

class _CoffeeCollectionScreenState extends State<CoffeeCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNumberController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _tareWeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _numberOfBagsController = TextEditingController();

  final CoffeeCollectionController _coffeeCollectionController =
      Get.find<CoffeeCollectionController>();
  final MemberController _memberController = Get.find<MemberController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  final AuthController _authController = Get.find<AuthController>();
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();
  final GapScaleService _gapScaleService = Get.find<GapScaleService>();
  final PrintService _printService = Get.find<PrintService>();

  Member? _selectedMember;
  bool _isManualEntry = true;
  bool _isBluetoothScaleConnected = false;
  bool _isHoldEnabled = false;
  double _accumulatedWeight = 0.0;

  CoffeeCollection? _lastSuccessfulCollection;
  final Set<String> _printedReceiptIds = <String>{};

  Worker? _gapWeightWorker;
  Worker? _gapConnectionWorker;
  Worker? _classicBluetoothWorker;

  String _collectionMode = 'manual';
  bool _isAutoModeAvailable = false;
  bool _showWeightMonitor = false;
  bool _isWeightMonitorActive = false;
  final bool _isConnectingToScale = false;

  Timer? _backgroundWeightTimer;

  // Track if member phone was updated
  bool _memberPhoneUpdated = false;

  // Stream subscriptions for weight monitoring
  StreamSubscription<double>? _bluetoothWeightSubscription;
  StreamSubscription<double>? _gapWeightSubscription;

  // Member search optimization
  Timer? _memberSearchDebounce;
  final bool _isMemberSearching = false;

  // ── Role helpers ──────────────────────────────────────────────────────────
  /// True when the logged-in user is a clerk – enforces Bluetooth-only mode.
  bool get _isClerk =>
      _authController.currentUser.value?.role == UserRole.clerk;

  /// Clerks are NOT allowed to switch to manual mode.
  bool get _allowManualMode => !_isClerk;

  @override
  void initState() {
    super.initState();

    _initializeCollectionMode();

    final defaultTareWeight =
        _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
    _tareWeightController.text = defaultTareWeight.toStringAsFixed(2);
    _numberOfBagsController.text = '1';

    _grossWeightController.addListener(_calculateNetWeight);
    _tareWeightController.addListener(_calculateTotalTareWeight);
    _numberOfBagsController.addListener(_calculateTotalTareWeight);

    _settingsController.systemSettings.listen((settings) {
      if (settings != null) {
        if (_tareWeightController.text !=
            settings.defaultTareWeight.toStringAsFixed(2)) {
          setState(() {
            _tareWeightController.text = settings.defaultTareWeight
                .toStringAsFixed(2);
          });
        }
        _updateCollectionModeAvailability(settings);
      }
    });

    _setupScaleWorkers();
    _refreshMembersData();

    ever(_memberController.isLoading, (bool loading) {
      if (!loading && mounted) {
        print('Members data refreshed - updating search cache');
        _memberController.searchMembers('');
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _memberNumberController.dispose();
    _grossWeightController.dispose();
    _tareWeightController.dispose();
    _netWeightController.dispose();
    _numberOfBagsController.dispose();

    _gapWeightWorker?.dispose();
    _gapConnectionWorker?.dispose();
    _classicBluetoothWorker?.dispose();
    _backgroundWeightTimer?.cancel();
    _memberSearchDebounce?.cancel();

    _bluetoothWeightSubscription?.cancel();
    _gapWeightSubscription?.cancel();

    _cleanupBluetoothOnDispose();

    super.dispose();
  }

  Future<void> _cleanupBluetoothOnDispose() async {
    try {
      print('Coffee Collection Screen disposing - cleaning up Bluetooth streams');
      _bluetoothService.stopContinuousWeightStream();

      final settings = _settingsController.systemSettings.value;
      if (settings?.autoDisconnectScale == true) {
        print('Auto-disconnect enabled - disconnecting from scale');
        await Future.wait([
          _bluetoothService.disconnectScale(),
          _gapScaleService.disconnect(),
        ]);
        print('Scale disconnected automatically on screen exit');
      } else {
        print('Auto-disconnect disabled - keeping scale connection for other screens');
      }
    } catch (e) {
      print('Error during Bluetooth cleanup on dispose: $e');
    }
  }

  void _initializeCollectionMode() {
    final settings = _settingsController.systemSettings.value;
    if (settings != null) {
      _updateCollectionModeAvailability(settings);
    }

    // ── Clerk enforcement: always start in Auto mode ──────────────────────
    if (_isClerk) {
      _collectionMode = 'auto';
      _isManualEntry = false;
    }
  }

  void _updateCollectionModeAvailability(settings) {
    setState(() {
      _isAutoModeAvailable = settings.enableBluetoothScale;

      // If auto mode is unavailable AND user is NOT a clerk, fall back to manual.
      // Clerks stay in auto regardless (scale may not be connected yet).
      if (!_isAutoModeAvailable && _collectionMode == 'auto' && _allowManualMode) {
        _collectionMode = 'manual';
        _isManualEntry = true;
      }

      // Clerks can never be in manual mode.
      if (_isClerk) {
        _collectionMode = 'auto';
        _isManualEntry = false;
      }
    });
  }

  void _setupScaleWorkers() {
    _gapConnectionWorker = ever(_gapScaleService.isConnected, (bool connected) {
      setState(() {
        _isBluetoothScaleConnected = connected;
        _updateCollectionModeFromConnection();
      });

      if (connected) {
        _startGapWeightMonitoring();
      } else {
        _stopGapWeightMonitoring();
      }
    });

    _classicBluetoothWorker = ever(_bluetoothService.isScaleConnected, (
      bool connected,
    ) {
      setState(() {
        _isBluetoothScaleConnected =
            connected || _gapScaleService.isConnected.value;
        _updateCollectionModeFromConnection();
      });

      if (connected) {
        _startBluetoothWeightMonitoring();
      } else {
        _stopBluetoothWeightMonitoring();
      }
    });
  }

  void _startGapWeightMonitoring() {
    _gapWeightSubscription?.cancel();
    _gapWeightSubscription = _gapScaleService.currentWeight.listen((double weight) {
      if (_gapScaleService.isConnected.value &&
          (_collectionMode == 'auto' || _isWeightMonitorActive)) {
        setState(() {
          _grossWeightController.text = weight.toStringAsFixed(2);
        });
      }
    });
  }

  void _stopGapWeightMonitoring() {
    _gapWeightSubscription?.cancel();
    _gapWeightSubscription = null;
  }

  void _startBluetoothWeightMonitoring() {
    _bluetoothWeightSubscription?.cancel();

    if (!_bluetoothService.isScaleConnected.value) {
      print('Cannot start Bluetooth weight monitoring - scale not connected');
      return;
    }

    try {
      final weightStream = _bluetoothService.getContinuousWeightStream();

      _bluetoothWeightSubscription = weightStream.listen(
        (double weight) {
          if (_bluetoothService.isScaleConnected.value &&
              (_collectionMode == 'auto' || _isWeightMonitorActive)) {
            setState(() {
              _grossWeightController.text = weight.toStringAsFixed(2);
            });
          }
        },
        onError: (error) {
          print('Error in Bluetooth weight stream: $error');
        },
        onDone: () {
          print('Bluetooth weight stream completed');
          _bluetoothWeightSubscription = null;
        },
      );

      print('Started Bluetooth weight monitoring');
    } catch (e) {
      print('Error starting Bluetooth weight monitoring: $e');
      if (e.toString().contains('Stream has already been listened to')) {
        _bluetoothService.stopContinuousWeightStream();
        Future.delayed(Duration(milliseconds: 500), () {
          _startBluetoothWeightMonitoring();
        });
      }
    }
  }

  void _stopBluetoothWeightMonitoring() {
    _bluetoothWeightSubscription?.cancel();
    _bluetoothWeightSubscription = null;
    _bluetoothService.stopContinuousWeightStream();
  }

  void _updateCollectionModeFromConnection() {
    // Only fall back to manual if the user is allowed manual mode
    if (!_isBluetoothScaleConnected &&
        _collectionMode == 'auto' &&
        _allowManualMode) {
      setState(() {
        _collectionMode = 'manual';
        _isManualEntry = true;
      });
    }
    // Clerks stay in auto even when scale is disconnected (they'll reconnect)
  }

  void _calculateTotalTareWeight() {
    if (_tareWeightController.text.isNotEmpty &&
        _numberOfBagsController.text.isNotEmpty) {
      try {
        final tarePerBag = double.parse(_tareWeightController.text);
        final numberOfBags = int.parse(_numberOfBagsController.text);
        _calculateNetWeight();
      } catch (e) {
        _calculateNetWeight();
      }
    } else {
      _calculateNetWeight();
    }
  }

  void _calculateNetWeight() {
    if (_grossWeightController.text.isNotEmpty &&
        _tareWeightController.text.isNotEmpty &&
        _numberOfBagsController.text.isNotEmpty) {
      try {
        final grossWeight = double.parse(_grossWeightController.text);
        final tarePerBag = double.parse(_tareWeightController.text);
        final numberOfBags = int.parse(_numberOfBagsController.text);
        final totalTareWeight = tarePerBag * numberOfBags;
        final netWeight = grossWeight - totalTareWeight;

        if (netWeight >= 0) {
          _netWeightController.text = netWeight.toStringAsFixed(2);
        } else {
          _netWeightController.text = '0.00';
        }
      } catch (e) {
        _netWeightController.text = '0.00';
      }
    } else {
      _netWeightController.text = '0.00';
    }
  }

  Future<void> _getWeightFromScale() async {
    try {
      double? weight;

      if (_gapScaleService.isConnected.value) {
        weight = _gapScaleService.currentWeight.value;
      } else if (_bluetoothService.isScaleConnected.value) {
        weight = await _bluetoothService.readWeightFromScale();
      }

      if (weight != null && weight >= 0) {
        final nonNullWeight = weight;
        setState(() {
          _grossWeightController.text = nonNullWeight.toStringAsFixed(2);
        });

        Get.snackbar(
          'Scale Reading',
          'Weight updated: ${nonNullWeight.toStringAsFixed(2)} kg',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Scale Error',
          'Unable to get weight from scale',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get weight from scale: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _switchToManualMode() async {
    // Clerks cannot switch to manual mode
    if (!_allowManualMode) return;

    setState(() {
      _collectionMode = 'manual';
      _isManualEntry = true;
      _showWeightMonitor = false;
      _isWeightMonitorActive = false;
    });

    _stopBluetoothWeightMonitoring();
    _stopGapWeightMonitoring();

    bool wasConnected = false;
    try {
      if (_gapScaleService.isConnected.value) {
        wasConnected = true;
        await _gapScaleService.disconnect();
        print('Disconnected from GAP scale when switching to manual mode');
      } else if (_bluetoothService.isScaleConnected.value) {
        wasConnected = true;
        await _bluetoothService.disconnectScale();
        print('Disconnected from Bluetooth scale when switching to manual mode');
      }
    } catch (e) {
      print('Error disconnecting from scale: $e');
    }

    _resetTareWeightToDefault();

    Get.snackbar(
      'Manual Mode Enabled',
      wasConnected
          ? 'Scale disconnected. You can now enter weight manually or use scale buttons.'
          : 'You can now enter weight manually or use scale buttons.',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _switchToAutoMode() {
    setState(() {
      _collectionMode = 'auto';
      _isManualEntry = false;
      _showWeightMonitor = true;
      _isWeightMonitorActive = true;
    });

    if (_gapScaleService.isConnected.value) {
      _startGapWeightMonitoring();
    } else if (_bluetoothService.isScaleConnected.value) {
      _startBluetoothWeightMonitoring();
    }

    _resetTareWeightToDefault();

    Get.snackbar(
      'Auto Mode Enabled',
      'Weight will be read automatically from the scale.',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  Future<void> _connectToScaleAndEnableAutoMode() async {
    try {
      Get.dialog(
        AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Expanded(child: Text('Checking Bluetooth...')),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      bool bluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!bluetoothEnabled) {
        Get.back();

        await Get.dialog(
          AlertDialog(
            title: const Text('Enable Bluetooth'),
            content: const Text(
              'Bluetooth is currently disabled. Please enable Bluetooth to connect to your scale.\n\n'
              'Would you like to open Bluetooth settings?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Get.back();
                  Get.snackbar(
                    'Enable Bluetooth',
                    'Please enable Bluetooth in your device settings and try again',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 4),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      Get.back();
      Get.dialog(
        AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Expanded(child: Text('Connecting to scale...')),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      final settings = _settingsController.systemSettings.value;
      String? configuredScaleAddress = settings?.defaultScaleAddress;

      if (configuredScaleAddress?.isNotEmpty ?? false) {
        bool connected = await _bluetoothService.connectToScaleByAddress(
          configuredScaleAddress!,
        );

        if (connected) {
          Get.until((route) => route.isFirst);
          _switchToAutoMode();
          Get.snackbar(
            'Connected & Auto Mode Enabled',
            'Successfully connected to your saved scale.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      Get.back();
      await _showScaleSelectionDialog();
    } catch (e) {
      Get.until((route) => route.isFirst);
      Get.snackbar(
        'Connection Error',
        'Failed to connect to scale: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showScaleSelectionDialog() async {
    try {
      await _bluetoothService.startScan();
      await Future.delayed(const Duration(seconds: 2));
      await _bluetoothService.stopScan();

      if (_bluetoothService.devices.isEmpty) {
        Get.until((route) => route.isFirst);
        _bluetoothService.showClassicBluetoothPairingInstructions();
        return;
      }

      await Get.dialog(
        AlertDialog(
          title: const Text('Select Your Scale'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select your Bluetooth scale from the list:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _bluetoothService.devices.length,
                    itemBuilder: (context, index) {
                      final device = _bluetoothService.devices[index];
                      return ListTile(
                        leading: const Icon(Icons.scale),
                        title: Text(
                          device.name?.isNotEmpty == true
                              ? device.name!
                              : 'Unknown Device',
                        ),
                        subtitle: Text(device.address),
                        onTap: () async {
                          await _connectToSelectedScale(device.address);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                _bluetoothService.showClassicBluetoothPairingInstructions();
              },
              child: const Text('Pair New Device'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.until((route) => route.isFirst);
      Get.snackbar(
        'Error',
        'Failed to scan for devices: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _connectToSelectedScale(String deviceAddress) async {
    try {
      Get.back();

      Get.dialog(
        AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Expanded(child: Text('Connecting to scale...')),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      bool connected = await _bluetoothService.connectToScaleByAddress(
        deviceAddress,
      );

      Get.until((route) => route.isFirst);

      if (connected) {
        _switchToAutoMode();
        Get.snackbar(
          'Connected & Auto Mode Enabled',
          'Successfully connected to your scale.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Connection Failed',
          'Could not connect to the selected scale.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.until((route) => route.isFirst);
      Get.snackbar(
        'Connection Error',
        'Failed to connect to scale: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _holdWeight() {
    if (_grossWeightController.text.isNotEmpty) {
      final weight = double.tryParse(_grossWeightController.text);
      if (weight != null && weight >= 0) {
        setState(() {
          _isHoldEnabled = true;
          _accumulatedWeight += weight;
        });

        Get.snackbar(
          'Weight Held',
          'Added ${weight.toStringAsFixed(2)} kg to accumulated weight',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );

        _grossWeightController.clear();
        _netWeightController.clear();
      }
    }
  }

  Future<void> _saveCoffeeCollection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMember == null) {
      Get.snackbar(
        'Error',
        'Please select a member',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (!_selectedMember!.isActive) {
      Get.snackbar(
        'Error',
        'Cannot collect coffee from inactive member',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final double grossWeight =
          _isHoldEnabled
              ? _accumulatedWeight
              : double.parse(_grossWeightController.text);

      final double tarePerBag = double.parse(_tareWeightController.text);
      final int numberOfBags = int.parse(_numberOfBagsController.text);
      final double totalTareWeight = tarePerBag * numberOfBags;

      if (grossWeight <= totalTareWeight) {
        Get.snackbar(
          'Error',
          'Gross weight must be greater than total tare weight',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      _coffeeCollectionController.setSelectedMember(_selectedMember!);
      _coffeeCollectionController.setGrossWeight(grossWeight);
      _coffeeCollectionController.setTareWeight(totalTareWeight);
      _coffeeCollectionController.numberOfBagsController.text =
          numberOfBags.toString();
      _coffeeCollectionController.setManualEntry(_isManualEntry);

      final collection = await _coffeeCollectionController.addCollection();

      if (collection != null) {
        print('=== COLLECTION POSTED SUCCESSFULLY ===');
        print('📄 Collection ID: ${collection.id}');
        print('🧾 Receipt Number: ${collection.receiptNumber}');

        print('🚀 PRIORITY 1: Sending SMS notification...');
        await _sendCollectionSMS(collection);

        print('⏳ Adding safety delay after SMS...');
        await Future.delayed(const Duration(seconds: 2));

        print('🖨️  PRIORITY 2: Processing receipt printing...');
        await _printCollectionReceipt(collection);

        print('✅ PRIORITY 3: Completing collection process...');
        _clearForm();

        print('=== COLLECTION PROCESS COMPLETED ===');
      } else {
        Get.snackbar(
          'Error',
          _coffeeCollectionController.error.value.isNotEmpty
              ? _coffeeCollectionController.error.value
              : 'Failed to post collection',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to post collection: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _printCollectionReceipt(CoffeeCollection collection) async {
    try {
      final settings = _settingsController.systemSettings.value;
      if (settings?.enablePrinting != true) {
        print('Receipt printing is disabled in settings');
        return;
      }

      final orgSettings = _settingsController.organizationSettings.value;
      final sysSettings = _settingsController.systemSettings.value;

      final member = _memberController.getMemberByNumber(
        collection.memberNumber,
      );

      final memberSummary = await _coffeeCollectionController
          .getMemberSeasonSummary(collection.memberId);
      final allTimeCumulativeWeight = memberSummary['allTimeWeight'] ?? 0.0;

      final receiptData = {
        'type': 'coffee_collection',
        'societyName': orgSettings?.societyName ?? 'Coffee Pro Society',
        'factory': orgSettings?.factory ?? 'Main Factory',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath,
        'memberName': collection.memberName,
        'memberNumber': collection.memberNumber,
        'receiptNumber': collection.receiptNumber,
        'date': DateFormat('yyyy-MM-dd HH:mm').format(collection.collectionDate),
        'productType': collection.productType,
        'seasonName': collection.seasonName,
        'numberOfBags': collection.numberOfBags.toString(),
        'grossWeight': collection.grossWeight.toStringAsFixed(2),
        'tareWeightPerBag':
            collection.numberOfBags > 0
                ? (collection.tareWeight / collection.numberOfBags)
                    .toStringAsFixed(2)
                : '0.00',
        'totalTareWeight': collection.tareWeight.toStringAsFixed(2),
        'netWeight': collection.netWeight.toStringAsFixed(2),
        'allTimeCumulativeWeight': allTimeCumulativeWeight.toStringAsFixed(2),
        'entryType':
            collection.isManualEntry ? 'Manual Entry' : 'Scale Reading',
        'servedBy': collection.userName ?? 'Unknown User',
        'slogan': orgSettings?.slogan ?? 'Premium Coffee, Premium Returns',
      };

      if (sysSettings?.printMethod == 'standard') {
        await _printService.printReceiptWithDialog(receiptData);
      } else {
        await _printService.printReceipt(receiptData);
      }
    } catch (e) {
      print('Failed to print receipt: $e');
    }
  }

  Future<void> _sendCollectionSMS(CoffeeCollection collection) async {
    try {
      print('=== SIMPLIFIED SMS SENDING START ===');
      print('📱 Sending SMS for collection ${collection.receiptNumber}');

      final smsService = Get.find<SmsService>();
      final settingsService = Get.find<SettingsService>();
      final memberService = Get.find<MemberService>();

      final sysSettings = settingsService.systemSettings.value;
      if (sysSettings.enableSms != true) {
        print('❌ SMS is disabled in system settings');
        return;
      }

      final member = await memberService.getMemberById(collection.memberId);
      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print('❌ No phone number available for member ${collection.memberName}');
        return;
      }

      final phoneNumberToUse = member.phoneNumber!;
      final validatedNumber = smsService.validateKenyanPhoneNumber(phoneNumberToUse);
      if (validatedNumber == null) {
        print('❌ Invalid phone number for member ${collection.memberName}: $phoneNumberToUse');
        Get.snackbar(
          'SMS Warning',
          'Invalid phone number for ${collection.memberName}: $phoneNumberToUse. Please update to valid Kenyan format.',
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final orgSettings = settingsService.organizationSettings.value;
      final societyName = orgSettings.societyName ?? 'Farm Pro Society';
      final factoryName = orgSettings.factory ?? '';

      final memberSummary = await _coffeeCollectionController
          .getMemberSeasonSummary(collection.memberId);
      final allTimeCumulativeWeight = memberSummary['allTimeWeight'] ?? 0.0;

      final receiptNo = collection.receiptNumber ?? 'N/A';
      final formattedDate = DateFormat('dd/MM/yy').format(collection.collectionDate);

      final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:$receiptNo
Date:$formattedDate
Season:${collection.seasonName}
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Total:${allTimeCumulativeWeight.toStringAsFixed(1)} kg
S/By:${collection.userName ?? 'N/A'}''';

      print('📤 Sending SMS using current mode settings...');
      final success = await smsService.sendSms(
        validatedNumber,
        message,
      );

      print('📤 SMS send result: $success');
      print('=== SIMPLIFIED SMS SENDING END ===');
    } catch (e) {
      print('❌ EXCEPTION in simplified SMS sending: $e');
      Get.snackbar(
        'SMS Error',
        'Error sending SMS: ${e.toString()}',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _clearForm() {
    setState(() {
      _selectedMember = null;
      _memberNumberController.clear();
      _grossWeightController.clear();
      _netWeightController.clear();
      _numberOfBagsController.text = '1';
      _isHoldEnabled = false;
      _accumulatedWeight = 0.0;
      _memberPhoneUpdated = false;

      final defaultTareWeight =
          _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
      _tareWeightController.text = defaultTareWeight.toStringAsFixed(2);
    });

    if (_collectionMode == 'auto') {
      if (_gapScaleService.isConnected.value) {
        _startGapWeightMonitoring();
      } else if (_bluetoothService.isScaleConnected.value) {
        _startBluetoothWeightMonitoring();
      }
    }
  }

  Future<void> _editMemberPhone() async {
    if (_selectedMember == null) return;

    final currentPhone = _selectedMember!.phoneNumber ?? '';
    final TextEditingController phoneController = TextEditingController(
      text: currentPhone,
    );

    try {
      final result = await Get.dialog<String>(
        AlertDialog(
          title: const Text('Edit Phone Number'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member: ${_selectedMember!.fullName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g., 0712345678 or +254712345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 15,
                    autofocus: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            if (currentPhone.isNotEmpty)
              TextButton(
                onPressed: () => Get.back(result: ''),
                child: const Text('Clear'),
              ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) {
                  Get.back(result: '');
                } else {
                  try {
                    final smsService = Get.find<SmsService>();
                    final validatedPhone = smsService.validateKenyanPhoneNumber(phone);
                    if (validatedPhone != null) {
                      Get.back(result: validatedPhone);
                    } else {
                      Get.snackbar(
                        'Invalid Phone Number',
                        'Please enter a valid Kenyan phone number',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  } catch (e) {
                    print('Error validating phone number: $e');
                    Get.snackbar(
                      'Error',
                      'Unable to validate phone number. Please try again.',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (result != null) {
        try {
          Get.dialog(
            AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Updating phone number...')),
                ],
              ),
            ),
            barrierDismissible: false,
          );

          final memberService = Get.find<MemberService>();
          final updatedMember = _selectedMember!.copyWith(
            phoneNumber: result.isEmpty ? null : result,
          );

          await memberService.updateMember(updatedMember);

          setState(() {
            _selectedMember = updatedMember;
            _memberPhoneUpdated = true;
          });

          await _memberController.refreshMembers();
          Get.back();

          if (result.isEmpty) {
            Get.snackbar(
              'Phone Number Cleared',
              'Phone number cleared for ${_selectedMember!.fullName}',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
            );
          } else {
            Get.snackbar(
              'Phone Number Updated',
              'Phone number updated for ${_selectedMember!.fullName}: $result',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          }
        } catch (e) {
          try {
            Get.back();
          } catch (_) {}

          print('Error updating member phone number: $e');
          Get.snackbar(
            'Update Failed',
            'Failed to update phone number: ${e.toString()}',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      print('Error in phone editing dialog: $e');
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          phoneController.dispose();
        } catch (e) {
          print('Error disposing phone controller: $e');
        }
      });
    }
  }

  void _resetTareWeightToDefault() {
    final defaultTareWeight =
        _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
    setState(() {
      _tareWeightController.text = defaultTareWeight.toStringAsFixed(2);
    });
  }

  Future<void> _disconnectFromScale() async {
    try {
      bool? shouldDisconnect = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Disconnect Scale'),
          content: const Text(
            'Are you sure you want to disconnect from the scale?\n\n'
            'You will need to reconnect to use auto mode again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disconnect'),
            ),
          ],
        ),
      );

      if (shouldDisconnect == true) {
        Get.dialog(
          AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                const Expanded(child: Text('Disconnecting from scale...')),
              ],
            ),
          ),
          barrierDismissible: false,
        );

        await Future.wait([
          _bluetoothService.disconnectScale(),
          _gapScaleService.disconnect(),
        ]);

        Get.until((route) => route.isFirst);

        // Clerks cannot switch to manual after disconnect; show a warning instead
        if (_allowManualMode) {
          await _switchToManualMode();
        } else {
          setState(() {
            _isBluetoothScaleConnected = false;
          });
          Get.snackbar(
            'Scale Disconnected',
            'Scale disconnected. Please reconnect to continue collecting.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      Get.until((route) => route.isFirst);
      Get.snackbar(
        'Disconnect Error',
        'Failed to disconnect from scale: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import Collections',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'CSV Import Instructions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Required: Member Number, Net Weight (kg), Date\n'
                    '• Date formats: yyyy-MM-dd, dd/MM/yyyy, MM/dd/yyyy\n'
                    '• Optional: Number of Bags (defaults to 1)\n'
                    '• One member can have multiple collections\n'
                    '• Duplicates will be skipped automatically',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadImportTemplate();
              },
              icon: const Icon(Icons.download),
              label: const Text('Download CSV Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _importCollectionsFromCsv();
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Import from CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16.0),
              ),
            ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImportTemplate() async {
    try {
      await _coffeeCollectionController.downloadCollectionImportTemplate();
    } catch (e) {
      print('Error downloading template: $e');
      Get.snackbar(
        'Error',
        'Failed to download CSV template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _importCollectionsFromCsv() async {
    try {
      bool? shouldImport = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Import Collections'),
          content: const Text(
            'This will import coffee collections from a CSV file.\n\n'
            'Make sure your CSV has the following columns:\n'
            '• Member Number\n'
            '• Net Weight (kg)\n'
            '• Date\n'
            '• Number of Bags (optional)\n\n'
            'Duplicates will be automatically skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (shouldImport == true) {
        Get.dialog(
          AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                const Expanded(child: Text('Importing collections...')),
              ],
            ),
          ),
          barrierDismissible: false,
        );

        final importedCollections =
            await _coffeeCollectionController.importCollectionsFromCsv();

        Get.back();

        if (importedCollections.isNotEmpty) {
          print('Successfully imported ${importedCollections.length} collections');

          await Future.wait([
            _coffeeCollectionController.refreshCollections(),
            _refreshReportsData(),
          ]);

          Get.snackbar(
            'Import Successful',
            'Successfully imported ${importedCollections.length} coffee collections.\n'
                'Collection reports have been updated.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
            maxWidth: 400,
          );

          _showPostImportOptions(importedCollections.length);
        } else {
          print('No collections were imported');
          Get.snackbar(
            'Import Complete',
            'No new collections were imported.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      try {
        Get.back();
      } catch (_) {}

      print('Error importing collections: $e');
      Get.snackbar(
        'Import Error',
        'Failed to import collections: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _refreshReportsData() async {
    try {
      final seasonController = Get.find<SeasonController>();
      await seasonController.refreshSeasons();
      print('Reports data refreshed after collection import');
    } catch (e) {
      print('Error refreshing reports data: $e');
    }
  }

  void _showPostImportOptions(int importedCount) {
    Get.dialog(
      AlertDialog(
        title: const Text('Import Complete'),
        content: Text(
          'Successfully imported $importedCount collections.\n\n'
          'Would you like to view the updated collection reports?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Stay Here'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed('/reports');
            },
            child: const Text('View Reports'),
          ),
        ],
      ),
    );
  }

  Future<Member?> _searchMemberAsync(String query) async {
    try {
      if (_memberController.members.isEmpty) {
        await _refreshMembersData();
      }

      final memberService = Get.find<MemberService>();

      final memberByNumber = await memberService.getMemberByMemberNumber(query);
      if (memberByNumber != null) {
        return memberByNumber;
      }

      final quickResults = await memberService.quickSearchMembers(query, limit: 1);
      if (quickResults.isNotEmpty) {
        return quickResults.first;
      }
      return null;
    } catch (e) {
      print('Error in async member search: $e');
      return null;
    }
  }

  Future<List<Member>> _searchMembersAsync(String query) async {
    try {
      if (_memberController.members.isEmpty) {
        await _refreshMembersData();
      }

      final memberService = Get.find<MemberService>();
      return await memberService.quickSearchMembers(query, limit: 30);
    } catch (e) {
      print('Error in async members search: $e');
      return [];
    }
  }

  Widget _buildMemberSearchResults(List<Member> members) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: members.length,
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: 56,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        final member = members[index];
        return _CollectionMemberSearchItem(
          member: member,
          onSelected: (selectedMember) {
            setState(() {
              _selectedMember = selectedMember;
              _memberNumberController.text = selectedMember.memberNumber;
              _memberPhoneUpdated = false;
            });
          },
        );
      },
    );
  }

  Future<void> _refreshMembersData() async {
    try {
      await _memberController.refreshMembers();
      print('Members data refreshed for collection screen');
    } catch (e) {
      print('Error refreshing members data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Collection'),
        backgroundColor: Colors.brown[50],
        foregroundColor: Colors.brown[800],
        actions: [
          // Bluetooth disconnect button (only show when connected)
          Obx(() {
            bool isAnyScaleConnected =
                _gapScaleService.isConnected.value ||
                _bluetoothService.isScaleConnected.value;
            if (isAnyScaleConnected) {
              return IconButton(
                icon: const Icon(Icons.bluetooth_disabled),
                onPressed: _disconnectFromScale,
                tooltip: 'Disconnect Scale',
              );
            }
            return const SizedBox.shrink();
          }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _showImportOptions();
                  break;
                case 'history':
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Import Collections'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Collection History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Season info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.eco, color: Colors.green),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Season',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Obx(
                              () => Text(
                                _coffeeCollectionController.currentSeasonDisplay,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () => !_coffeeCollectionController.canCollect
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'CLOSED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // Member search and selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Selection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16.0),

                      // ── Member number + Find button ─────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _memberNumberController,
                              label: 'Member Number or Search',
                              hint: 'Enter member number or search by name',
                              prefix: const Icon(Icons.search),
                              onChanged: (value) async {
                                if (value.isNotEmpty) {
                                  if (_memberController.members.isEmpty) {
                                    await _refreshMembersData();
                                  }

                                  final memberByNumber = await _memberController
                                      .getMemberByNumber(value);
                                  if (memberByNumber != null) {
                                    setState(() {
                                      _selectedMember = memberByNumber;
                                      _memberPhoneUpdated = false;
                                    });
                                    return;
                                  }

                                  final searchResults =
                                      _memberController.searchMembers(value);
                                  if (searchResults.length == 1) {
                                    setState(() {
                                      _selectedMember = searchResults.first;
                                      _memberPhoneUpdated = false;
                                    });
                                  } else if (searchResults.isEmpty) {
                                    try {
                                      final asyncMember =
                                          await _searchMemberAsync(value);
                                      setState(() {
                                        _selectedMember = asyncMember;
                                        _memberPhoneUpdated = false;
                                      });
                                    } catch (e) {
                                      setState(() {
                                        _selectedMember = null;
                                        _memberPhoneUpdated = false;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _selectedMember = null;
                                      _memberPhoneUpdated = false;
                                    });
                                  }
                                } else {
                                  setState(() {
                                    _selectedMember = null;
                                    _memberPhoneUpdated = false;
                                  });
                                }
                              },
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please enter member number or search term';
                                }
                                if (_selectedMember == null) {
                                  return 'Member not found - please check the number or name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Show search results if multiple matches
                      if (_memberNumberController.text.isNotEmpty &&
                          _selectedMember == null) ...[
                        const SizedBox(height: 8.0),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: _isMemberSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Searching members...'),
                                      ],
                                    ),
                                  ),
                                )
                              : Builder(
                                  builder: (context) {
                                    List<Member> searchResults = [];

                                    if (_memberController.members.isNotEmpty &&
                                        _memberNumberController.text.isNotEmpty) {
                                      final query = _memberNumberController.text
                                          .toLowerCase();
                                      searchResults = _memberController.members
                                          .where(
                                            (member) =>
                                                member.memberNumber
                                                    .toLowerCase()
                                                    .contains(query) ||
                                                member.fullName
                                                    .toLowerCase()
                                                    .contains(query),
                                          )
                                          .take(5)
                                          .toList();
                                    }

                                    if (searchResults.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'No members found matching your search',
                                          style: TextStyle(color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }

                                    return _buildMemberSearchResults(searchResults);
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // Member information
              if (_selectedMember != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.brown),
                            const SizedBox(width: 8.0),
                            Text(
                              'Member Information',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Text('Member Number: ${_selectedMember!.memberNumber}'),
                        Text('Name: ${_selectedMember!.fullName}'),
                        Text('ID Number: ${_selectedMember!.idNumber ?? 'N/A'}'),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Phone: ${_selectedMember!.phoneNumber ?? 'Not set'}',
                                style: TextStyle(
                                  color: _memberPhoneUpdated ? Colors.blue : null,
                                  fontWeight:
                                      _memberPhoneUpdated ? FontWeight.w500 : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _editMemberPhone(),
                              tooltip: 'Edit member phone number',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Text(
                              'Status:',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedMember!.isActive
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedMember!.isActive ? 'Active' : 'Inactive',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16.0),

              // Weight Entry
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Mode header row ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Coffee Weight Details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _collectionMode == 'auto'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _collectionMode == 'auto'
                                      ? Colors.green
                                      : Colors.blue,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _collectionMode == 'auto'
                                        ? Icons.bluetooth_connected
                                        : Icons.edit,
                                    size: 14,
                                    color: _collectionMode == 'auto'
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      _collectionMode == 'auto'
                                          ? 'AUTO'
                                          : 'MANUAL',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _collectionMode == 'auto'
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Mode toggle buttons ───────────────────────────────
                      // Shown only when Bluetooth scale is enabled in settings.
                      // For CLERKS: the Manual button is hidden; only the Auto
                      // button is shown.
                      if (_isAutoModeAvailable) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // ── Manual button: hidden for clerks ─────────────
                            if (_allowManualMode) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (_collectionMode != 'manual') {
                                      await _switchToManualMode();
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Manual'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _collectionMode == 'manual'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    foregroundColor:
                                        _collectionMode == 'manual'
                                            ? Colors.white
                                            : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // ── Auto button: always shown ─────────────────────
                            Expanded(
                              child: Obx(() {
                                bool isAnyScaleConnected =
                                    _gapScaleService.isConnected.value ||
                                    _bluetoothService.isScaleConnected.value;

                                return ElevatedButton.icon(
                                  onPressed: _isConnectingToScale
                                      ? null
                                      : () {
                                          if (_collectionMode != 'auto') {
                                            if (isAnyScaleConnected) {
                                              _switchToAutoMode();
                                            } else {
                                              _connectToScaleAndEnableAutoMode();
                                            }
                                          }
                                        },
                                  icon: Icon(
                                    _isConnectingToScale
                                        ? Icons.hourglass_empty
                                        : isAnyScaleConnected
                                            ? Icons.bluetooth_connected
                                            : Icons.bluetooth,
                                  ),
                                  label: Text(
                                    _isConnectingToScale
                                        ? 'Connecting...'
                                        : 'Auto',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _collectionMode == 'auto'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    foregroundColor:
                                        _collectionMode == 'auto'
                                            ? Colors.white
                                            : null,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),

                        // ── Clerk-only banner below the Auto button ───────────
                        if (_isClerk) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Bluetooth scale mode only. '
                                    'Contact an admin to enable manual entry.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16.0),

                      // ── Gross weight ──────────────────────────────────────
                      // Clerks: always read-only (filled by scale).
                      // Others: editable only in manual mode.
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _grossWeightController,
                              decoration: InputDecoration(
                                labelText: _isClerk
                                    ? 'Gross Weight (kg)  •  from scale'
                                    : 'Gross Weight (kg)',
                                hintText: 'Enter gross weight',
                                border: const OutlineInputBorder(),
                                // Subtle lock icon to signal read-only to clerks
                                suffixIcon: _isClerk
                                    ? const Tooltip(
                                        message:
                                            'Filled automatically by the Bluetooth scale',
                                        child: Icon(Icons.lock_outline,
                                            size: 18, color: Colors.grey),
                                      )
                                    : null,
                                fillColor: _isClerk
                                    ? Colors.grey.withValues(alpha: 0.08)
                                    : null,
                                filled: _isClerk,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              // Disabled for clerks (always auto); disabled in
                              // auto mode for non-clerks too.
                              enabled: _isManualEntry && _allowManualMode,
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
                          ),
                        ],
                      ),

                      const SizedBox(height: 16.0),

                      // Number of bags and Tare Weight row
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _numberOfBagsController,
                              decoration: const InputDecoration(
                                labelText: 'Number of Bags',
                                hintText: '1',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                try {
                                  final bags = int.parse(value);
                                  if (bags < 0) {
                                    return 'Cannot be negative';
                                  }
                                } catch (e) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _tareWeightController,
                              decoration: const InputDecoration(
                                labelText: 'Tare Weight per Bag (kg)',
                                hintText: 'Weight per container',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter tare weight';
                                }
                                try {
                                  final weight = double.parse(value);
                                  if (weight < 0) {
                                    return 'Cannot be negative';
                                  }
                                } catch (e) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Total tare weight display
                      const SizedBox(height: 8.0),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _tareWeightController,
                          _numberOfBagsController,
                        ]),
                        builder: (context, child) {
                          if (_tareWeightController.text.isNotEmpty &&
                              _numberOfBagsController.text.isNotEmpty) {
                            final tarePerBag =
                                double.tryParse(_tareWeightController.text) ?? 0;
                            final numberOfBags =
                                int.tryParse(_numberOfBagsController.text) ?? 1;
                            final totalTareWeight = tarePerBag * numberOfBags;

                            return Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Total Tare Weight: ${totalTareWeight.toStringAsFixed(2)} kg',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // Net Weight (calculated, always read-only)
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _netWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Net Weight (kg)',
                          hintText: 'Calculated net weight',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        readOnly: true,
                        enabled: false,
                      ),

                      // Hold Feature Status
                      if (_isHoldEnabled) ...[
                        const SizedBox(height: 16.0),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.orange),
                                  const SizedBox(width: 8.0),
                                  const Expanded(
                                    child: Text(
                                      'Hold Mode Active',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.orange),
                                    onPressed: () {
                                      setState(() {
                                        _isHoldEnabled = false;
                                        _accumulatedWeight = 0.0;
                                      });
                                    },
                                    tooltip: 'Cancel Hold',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Accumulated Weight:',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${_accumulatedWeight.toStringAsFixed(2)} kg',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _selectedMember != null && !_selectedMember!.isActive
                              ? null
                              : _holdWeight,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Hold'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Obx(
                      () => ElevatedButton.icon(
                        onPressed:
                            _selectedMember != null &&
                                    !_selectedMember!.isActive
                                ? null
                                : (_coffeeCollectionController
                                        .isCollecting.value
                                    ? null
                                    : _saveCoffeeCollection),
                        icon: _coffeeCollectionController.isCollecting.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _coffeeCollectionController.isCollecting.value
                              ? 'Posting...'
                              : 'Post Value',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optimised member search item for coffee collection
class _CollectionMemberSearchItem extends StatelessWidget {
  final Member member;
  final Function(Member) onSelected;

  const _CollectionMemberSearchItem({
    required this.member,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: member.isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        child: Text(
          member.fullName.isNotEmpty ? member.fullName[0] : '?',
          style: TextStyle(
            fontSize: 12,
            color: member.isActive ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '${member.memberNumber} - ${member.fullName}',
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        member.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          color: member.isActive ? Colors.green : Colors.red,
        ),
      ),
      onTap: () => onSelected(member),
    );
  }
}