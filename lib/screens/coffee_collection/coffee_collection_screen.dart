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

  Worker? _gapConnectionWorker;
  Worker? _classicBluetoothWorker;

  // 'manual' | 'auto'
  String _collectionMode = 'manual';
  bool _isAutoModeAvailable = false;
  bool _isWeightMonitorActive = false;
  bool _isConnectingToScale = false;

  bool _memberPhoneUpdated = false;

  StreamSubscription<double>? _bluetoothWeightSubscription;
  StreamSubscription<double>? _gapWeightSubscription;

  Timer? _memberSearchDebounce;
  final bool _isMemberSearching = false;

  // ── Role helpers ──────────────────────────────────────────────────────────
  bool get _isClerk =>
      _authController.currentUser.value?.role == UserRole.clerk;
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
    _tareWeightController.addListener(_calculateNetWeight);
    _numberOfBagsController.addListener(_calculateNetWeight);

    _settingsController.systemSettings.listen((settings) {
      if (settings != null && mounted) {
        final newTare = settings.defaultTareWeight.toStringAsFixed(2);
        if (_tareWeightController.text != newTare) {
          setState(() => _tareWeightController.text = newTare);
        }
        _updateCollectionModeAvailability(settings);
      }
    });

    _setupScaleWorkers();
    _refreshMembersData();

    ever(_memberController.isLoading, (bool loading) {
      if (!loading && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _memberNumberController.dispose();
    _grossWeightController.dispose();
    _tareWeightController.dispose();
    _netWeightController.dispose();
    _numberOfBagsController.dispose();
    _gapConnectionWorker?.dispose();
    _classicBluetoothWorker?.dispose();
    _memberSearchDebounce?.cancel();
    _bluetoothWeightSubscription?.cancel();
    _gapWeightSubscription?.cancel();
    _cleanupBluetoothOnDispose();
    super.dispose();
  }

  Future<void> _cleanupBluetoothOnDispose() async {
    try {
      _bluetoothService.stopContinuousWeightStream();
      final settings = _settingsController.systemSettings.value;
      if (settings?.autoDisconnectScale == true) {
        await Future.wait([
          _bluetoothService.disconnectScale(),
          _gapScaleService.disconnect(),
        ]);
      }
    } catch (e) {
      print('Error during BT cleanup: $e');
    }
  }

  void _initializeCollectionMode() {
    final settings = _settingsController.systemSettings.value;
    if (settings != null) {
      _updateCollectionModeAvailability(settings);
    }
    if (_isClerk) {
      _collectionMode = 'auto';
      _isManualEntry = false;
    }
  }

  void _updateCollectionModeAvailability(settings) {
    if (!mounted) return;
    setState(() {
      _isAutoModeAvailable = settings.enableBluetoothScale;
      if (!_isAutoModeAvailable && _collectionMode == 'auto' && _allowManualMode) {
        _collectionMode = 'manual';
        _isManualEntry = true;
      }
      if (_isClerk) {
        _collectionMode = 'auto';
        _isManualEntry = false;
      }
    });
  }

  void _setupScaleWorkers() {
    // GAP (BLE) scale connection
    _gapConnectionWorker = ever(_gapScaleService.isConnected, (bool connected) {
      if (!mounted) return;
      setState(() {
        _isBluetoothScaleConnected =
            connected || _bluetoothService.isScaleConnected.value;
        _updateCollectionModeFromConnection();
      });
      if (connected) {
        _startGapWeightMonitoring();
      } else {
        _stopGapWeightMonitoring();
      }
    });

    // Classic Bluetooth scale connection
    _classicBluetoothWorker =
        ever(_bluetoothService.isScaleConnected, (bool connected) {
      if (!mounted) return;
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

  // ── Weight monitoring ─────────────────────────────────────────────────────

  void _startGapWeightMonitoring() {
    _gapWeightSubscription?.cancel();
    _gapWeightSubscription =
        _gapScaleService.currentWeight.listen((double weight) {
      if (!mounted) return;
      if (_gapScaleService.isConnected.value &&
          (_collectionMode == 'auto' || _isWeightMonitorActive)) {
        setState(() => _grossWeightController.text = weight.toStringAsFixed(2));
      }
    });
    print('✅ [BT] GAP weight monitoring started');
  }

  void _stopGapWeightMonitoring() {
    _gapWeightSubscription?.cancel();
    _gapWeightSubscription = null;
  }

  void _startBluetoothWeightMonitoring() {
    _bluetoothWeightSubscription?.cancel();

    if (!_bluetoothService.isScaleConnected.value) return;

    try {
      final stream = _bluetoothService.getContinuousWeightStream();
      _bluetoothWeightSubscription = stream.listen(
        (double weight) {
          if (!mounted) return;
          if (_bluetoothService.isScaleConnected.value &&
              (_collectionMode == 'auto' || _isWeightMonitorActive)) {
            setState(
                () => _grossWeightController.text = weight.toStringAsFixed(2));
          }
        },
        onError: (e) => print('❌ [BT] Weight stream error: $e'),
        onDone: () => _bluetoothWeightSubscription = null,
      );
      print('✅ [BT] Classic weight monitoring started');
    } catch (e) {
      print('❌ [BT] Error starting monitoring: $e');
      if (e.toString().contains('already been listened to')) {
        _bluetoothService.stopContinuousWeightStream();
        Future.delayed(const Duration(milliseconds: 500),
            _startBluetoothWeightMonitoring);
      }
    }
  }

  void _stopBluetoothWeightMonitoring() {
    _bluetoothWeightSubscription?.cancel();
    _bluetoothWeightSubscription = null;
    _bluetoothService.stopContinuousWeightStream();
  }

  void _updateCollectionModeFromConnection() {
    if (!_isBluetoothScaleConnected &&
        _collectionMode == 'auto' &&
        _allowManualMode) {
      setState(() {
        _collectionMode = 'manual';
        _isManualEntry = true;
      });
    }
    // Clerks stay in auto even when disconnected
  }

  // ── Weight calculation ────────────────────────────────────────────────────

  void _calculateNetWeight() {
    if (!mounted) return;
    try {
      final gross = double.tryParse(_grossWeightController.text) ?? 0.0;
      final tare = double.tryParse(_tareWeightController.text) ?? 0.0;
      final bags = int.tryParse(_numberOfBagsController.text) ?? 1;
      final net = gross - (tare * bags);
      _netWeightController.text = net >= 0 ? net.toStringAsFixed(2) : '0.00';
    } catch (_) {
      _netWeightController.text = '0.00';
    }
  }

  // ── Mode switching ────────────────────────────────────────────────────────

  Future<void> _switchToManualMode() async {
    if (!_allowManualMode) return;
    _stopBluetoothWeightMonitoring();
    _stopGapWeightMonitoring();
    if (!mounted) return;
    setState(() {
      _collectionMode = 'manual';
      _isManualEntry = true;
      _isWeightMonitorActive = false;
    });
    _resetTareWeightToDefault();
    Get.snackbar('Manual Mode', 'Enter weight manually.',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
  }

  void _switchToAutoMode() {
    if (!mounted) return;
    setState(() {
      _collectionMode = 'auto';
      _isManualEntry = false;
      _isWeightMonitorActive = true;
    });
    // Start whichever scale is connected
    if (_gapScaleService.isConnected.value) {
      _startGapWeightMonitoring();
    } else if (_bluetoothService.isScaleConnected.value) {
      _startBluetoothWeightMonitoring();
    }
    _resetTareWeightToDefault();
    Get.snackbar('Auto Mode', 'Weight read from Bluetooth scale.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _connectToScaleAndEnableAutoMode() async {
    if (_isConnectingToScale) return;
    if (!mounted) return;
    setState(() => _isConnectingToScale = true);

    try {
      // Check Bluetooth
      final btEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!btEnabled) {
        Get.snackbar('Bluetooth Off',
            'Please enable Bluetooth and try again.',
            backgroundColor: Colors.orange,
            colorText: Colors.white);
        return;
      }

      // Try to connect to saved scale
      final settings = _settingsController.systemSettings.value;
      final savedAddress = settings?.defaultScaleAddress;

      if (savedAddress != null && savedAddress.isNotEmpty) {
        Get.dialog(
          const AlertDialog(
            content: Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Connecting to scale...'),
            ]),
          ),
          barrierDismissible: false,
        );

        final connected =
            await _bluetoothService.connectToScaleByAddress(savedAddress);
        Get.until((r) => r.isFirst);

        if (connected) {
          _switchToAutoMode();
          return;
        }
      }

      // Scan and let user pick
      await _showScaleSelectionDialog();
    } catch (e) {
      Get.until((r) => r.isFirst);
      Get.snackbar('Connection Error', 'Failed to connect: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isConnectingToScale = false);
    }
  }

  Future<void> _showScaleSelectionDialog() async {
    try {
      await _bluetoothService.startScan();
      await Future.delayed(const Duration(seconds: 3));
      await _bluetoothService.stopScan();

      if (_bluetoothService.devices.isEmpty) {
        _bluetoothService.showClassicBluetoothPairingInstructions();
        return;
      }

      await Get.dialog(
        AlertDialog(
          title: const Text('Select Scale'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Select your Bluetooth scale:'),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _bluetoothService.devices.length,
                  itemBuilder: (ctx, i) {
                    final device = _bluetoothService.devices[i];
                    return ListTile(
                      leading: const Icon(Icons.scale),
                      title: Text(device.name?.isNotEmpty == true
                          ? device.name!
                          : 'Unknown Device'),
                      subtitle: Text(device.address),
                      onTap: () async {
                        Get.back();
                        await _connectToSelectedScale(device.address);
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
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
      Get.snackbar('Scan Error', 'Failed to scan: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _connectToSelectedScale(String address) async {
    Get.dialog(
      const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Connecting...'),
        ]),
      ),
      barrierDismissible: false,
    );

    try {
      final connected =
          await _bluetoothService.connectToScaleByAddress(address);
      Get.until((r) => r.isFirst);

      if (connected) {
        _switchToAutoMode();
        Get.snackbar('Connected', 'Scale connected. Auto mode active.',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Failed', 'Could not connect to scale.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.until((r) => r.isFirst);
      Get.snackbar('Error', '$e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _disconnectFromScale() async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      title: const Text('Disconnect Scale'),
      content: const Text(
          'Disconnect from scale? You will need to reconnect for auto mode.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Disconnect',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));

    if (confirm != true) return;

    Get.dialog(
      const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Disconnecting...'),
        ]),
      ),
      barrierDismissible: false,
    );

    await Future.wait([
      _bluetoothService.disconnectScale(),
      _gapScaleService.disconnect(),
    ]);
    Get.until((r) => r.isFirst);

    if (_allowManualMode) {
      await _switchToManualMode();
    } else {
      if (mounted) setState(() => _isBluetoothScaleConnected = false);
      Get.snackbar('Disconnected',
          'Scale disconnected. Please reconnect to continue.',
          backgroundColor: Colors.orange, colorText: Colors.white);
    }
  }

  void _holdWeight() {
    final weight = double.tryParse(_grossWeightController.text) ?? 0.0;
    if (weight <= 0) {
      Get.snackbar('No Weight', 'Enter a gross weight first.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isHoldEnabled = true;
      _accumulatedWeight += weight;
      _grossWeightController.clear();
      _netWeightController.clear();
    });
    Get.snackbar(
        'Held', 'Accumulated: ${_accumulatedWeight.toStringAsFixed(2)} kg',
        backgroundColor: Colors.orange, colorText: Colors.white);
  }

  void _resetTareWeightToDefault() {
    final tare = _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
    if (mounted) setState(() => _tareWeightController.text = tare.toStringAsFixed(2));
  }

  // ── Save collection ───────────────────────────────────────────────────────

  Future<void> _saveCoffeeCollection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMember == null) {
      Get.snackbar('Error', 'Please select a member.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (!_selectedMember!.isActive) {
      Get.snackbar('Error', 'Cannot collect from inactive member.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      final gross = _isHoldEnabled
          ? _accumulatedWeight
          : double.parse(_grossWeightController.text);
      final tare = double.parse(_tareWeightController.text);
      final bags = int.parse(_numberOfBagsController.text);
      final totalTare = tare * bags;

      if (gross <= totalTare) {
        Get.snackbar('Error', 'Gross weight must exceed total tare.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      _coffeeCollectionController.setSelectedMember(_selectedMember!);
      _coffeeCollectionController.setGrossWeight(gross);
      _coffeeCollectionController.setTareWeight(totalTare);
      _coffeeCollectionController.numberOfBagsController.text = bags.toString();
      _coffeeCollectionController.setManualEntry(_isManualEntry);

      final collection = await _coffeeCollectionController.addCollection();

      if (collection != null) {
        // 1. Send SMS immediately
        await _sendCollectionSMS(collection);
        // 2. Small delay for SMS to process
        await Future.delayed(const Duration(seconds: 1));
        // 3. Print receipt
        await _printCollectionReceipt(collection);
        // 4. Clear form
        _clearForm();

        Get.snackbar('Success', 'Coffee collection recorded.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
      } else {
        Get.snackbar(
          'Error',
          _coffeeCollectionController.error.value.isNotEmpty
              ? _coffeeCollectionController.error.value
              : 'Failed to save collection.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _sendCollectionSMS(CoffeeCollection collection) async {
    try {
      final settingsService = Get.find<SettingsService>();
      if (settingsService.systemSettings.value.enableSms != true) {
        print('ℹ️  [SMS] SMS disabled in settings, skipping');
        return;
      }
      final smsService = Get.find<SmsService>();
      await smsService.sendCoffeeCollectionSMS(collection);
    } catch (e) {
      print('❌ [SMS] Failed to send collection SMS: $e');
    }
  }

  Future<void> _printCollectionReceipt(CoffeeCollection collection) async {
    try {
      final settings = _settingsController.systemSettings.value;
      if (settings?.enablePrinting != true) return;

      final orgSettings = _settingsController.organizationSettings.value;
      final sysSettings = _settingsController.systemSettings.value;

      final memberSummary = await _coffeeCollectionController
          .getMemberSeasonSummary(collection.memberId);
      final cumWeight = _parseDouble(memberSummary['allTimeWeight']);

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
        'tareWeightPerBag': collection.numberOfBags > 0
            ? (collection.tareWeight / collection.numberOfBags).toStringAsFixed(2)
            : '0.00',
        'totalTareWeight': collection.tareWeight.toStringAsFixed(2),
        'netWeight': collection.netWeight.toStringAsFixed(2),
        'allTimeCumulativeWeight': cumWeight.toStringAsFixed(2),
        'entryType': collection.isManualEntry ? 'Manual Entry' : 'Scale Reading',
        'servedBy': collection.userName ?? 'Unknown',
        'slogan': orgSettings?.slogan ?? 'Premium Coffee, Premium Returns',
      };

      if (sysSettings?.printMethod == 'standard') {
        await _printService.printReceiptWithDialog(receiptData);
      } else {
        await _printService.printReceipt(receiptData);
      }
    } catch (e) {
      print('❌ [PRINT] Failed: $e');
    }
  }

  void _clearForm() {
    if (!mounted) return;
    setState(() {
      _selectedMember = null;
      _memberNumberController.clear();
      _grossWeightController.clear();
      _netWeightController.clear();
      _numberOfBagsController.text = '1';
      _isHoldEnabled = false;
      _accumulatedWeight = 0.0;
      _memberPhoneUpdated = false;
      _resetTareWeightToDefault();
    });
    // Restart weight monitoring if in auto mode
    if (_collectionMode == 'auto') {
      if (_gapScaleService.isConnected.value) {
        _startGapWeightMonitoring();
      } else if (_bluetoothService.isScaleConnected.value) {
        _startBluetoothWeightMonitoring();
      }
    }
  }

  // ── Member search helpers ─────────────────────────────────────────────────

  Future<void> _refreshMembersData() async {
    try {
      await _memberController.refreshMembers();
    } catch (e) {
      print('Error refreshing members: $e');
    }
  }

  Future<Member?> _searchMemberAsync(String query) async {
    try {
      if (_memberController.members.isEmpty) await _refreshMembersData();
      final memberService = Get.find<MemberService>();
      final byNumber = await memberService.getMemberByMemberNumber(query);
      if (byNumber != null) return byNumber;
      final results = await memberService.quickSearchMembers(query, limit: 1);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      return null;
    }
  }

  // ── Phone editing ─────────────────────────────────────────────────────────

  Future<void> _editMemberPhone() async {
    if (_selectedMember == null) return;
    final ctrl = TextEditingController(text: _selectedMember!.phoneNumber ?? '');

    try {
      final result = await Get.dialog<String>(
        AlertDialog(
          title: const Text('Edit Phone Number'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_selectedMember!.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '0712345678',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              autofocus: true,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final phone = ctrl.text.trim();
                if (phone.isEmpty) {
                  Get.back(result: '');
                  return;
                }
                final smsService = Get.find<SmsService>();
                final validated = smsService.validateKenyanPhoneNumber(phone);
                if (validated != null) {
                  Get.back(result: validated);
                } else {
                  Get.snackbar('Invalid', 'Enter a valid Kenyan number.',
                      backgroundColor: Colors.red, colorText: Colors.white);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (result != null && mounted) {
        final memberService = Get.find<MemberService>();
        final updated = _selectedMember!
            .copyWith(phoneNumber: result.isEmpty ? null : result);
        await memberService.updateMember(updated);
        setState(() {
          _selectedMember = updated;
          _memberPhoneUpdated = true;
        });
        await _memberController.refreshMembers();
        Get.snackbar(
          result.isEmpty ? 'Phone Cleared' : 'Phone Updated',
          result.isEmpty
              ? 'Phone cleared.'
              : 'Updated to $result',
          backgroundColor: result.isEmpty ? Colors.orange : Colors.green,
          colorText: Colors.white,
        );
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try { ctrl.dispose(); } catch (_) {}
      });
    }
  }

  // ── Import helpers (unchanged) ────────────────────────────────────────────

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Import Collections',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadImportTemplate();
            },
            icon: const Icon(Icons.download),
            label: const Text('Download CSV Template'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _importCollectionsFromCsv();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Import from CSV'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ]),
      ),
    );
  }

  Future<void> _downloadImportTemplate() async {
    try {
      await _coffeeCollectionController.downloadCollectionImportTemplate();
    } catch (e) {
      Get.snackbar('Error', 'Failed to download template: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _importCollectionsFromCsv() async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      title: const Text('Import Collections'),
      content: const Text(
          'Import from CSV? Required columns: Member Number, Net Weight (kg), Date.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Import')),
      ],
    ));

    if (confirm != true) return;

    Get.dialog(
      const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Importing...'),
        ]),
      ),
      barrierDismissible: false,
    );

    final imported =
        await _coffeeCollectionController.importCollectionsFromCsv();
    Get.back();

    if (imported.isNotEmpty) {
      await _coffeeCollectionController.refreshCollections();
      Get.snackbar('Imported',
          'Successfully imported ${imported.length} collections.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Collection'),
        backgroundColor: Colors.brown[50],
        foregroundColor: Colors.brown[800],
        actions: [
          // Disconnect button shown only when a scale is connected
          Obx(() {
            final connected = _gapScaleService.isConnected.value ||
                _bluetoothService.isScaleConnected.value;
            if (connected) {
              return IconButton(
                icon: const Icon(Icons.bluetooth_disabled),
                tooltip: 'Disconnect Scale',
                onPressed: _disconnectFromScale,
              );
            }
            return const SizedBox.shrink();
          }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'import') _showImportOptions();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'import',
                  child: Row(children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Import Collections')
                  ])),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Season card ───────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.eco, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Season',
                              style: Theme.of(context).textTheme.bodySmall),
                          Obx(() => Text(
                                _coffeeCollectionController.currentSeasonDisplay,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              )),
                        ],
                      ),
                    ),
                    Obx(() => !_coffeeCollectionController.canCollect
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text('CLOSED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          )
                        : const SizedBox.shrink()),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── Member selection ──────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Member Selection',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _memberNumberController,
                        label: 'Member Number or Name',
                        hint: 'Search by member number or name',
                        prefix: const Icon(Icons.search),
                        onChanged: (value) async {
                          if (value.isEmpty) {
                            setState(() {
                              _selectedMember = null;
                              _memberPhoneUpdated = false;
                            });
                            return;
                          }
                          if (_memberController.members.isEmpty) {
                            await _refreshMembersData();
                          }
                          final byNumber =
                              await _memberController.getMemberByNumber(value);
                          if (byNumber != null && mounted) {
                            setState(() {
                              _selectedMember = byNumber;
                              _memberPhoneUpdated = false;
                            });
                            return;
                          }
                          final results =
                              _memberController.searchMembers(value);
                          if (results.length == 1 && mounted) {
                            setState(() {
                              _selectedMember = results.first;
                              _memberPhoneUpdated = false;
                            });
                          } else if (results.isEmpty && mounted) {
                            final found = await _searchMemberAsync(value);
                            setState(() {
                              _selectedMember = found;
                              _memberPhoneUpdated = false;
                            });
                          } else if (mounted) {
                            setState(() {
                              _selectedMember = null;
                              _memberPhoneUpdated = false;
                            });
                          }
                        },
                        validator: (v) {
                          if (v?.isEmpty ?? true) {
                            return 'Enter member number or name';
                          }
                          if (_selectedMember == null) {
                            return 'Member not found';
                          }
                          return null;
                        },
                      ),
                      // Search results dropdown
                      if (_memberNumberController.text.isNotEmpty &&
                          _selectedMember == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Builder(builder: (_) {
                            final q =
                                _memberNumberController.text.toLowerCase();
                            final results = _memberController.members
                                .where((m) =>
                                    m.memberNumber.toLowerCase().contains(q) ||
                                    m.fullName.toLowerCase().contains(q))
                                .take(5)
                                .toList();
                            if (results.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No members found',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: results.length,
                              itemExtent: 56,
                              itemBuilder: (_, i) => _CollectionMemberItem(
                                member: results[i],
                                onSelected: (m) => setState(() {
                                  _selectedMember = m;
                                  _memberNumberController.text = m.memberNumber;
                                  _memberPhoneUpdated = false;
                                }),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Member info ───────────────────────────────────────────────
              if (_selectedMember != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.person, color: Colors.brown),
                          const SizedBox(width: 8),
                          Text('Member Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 12),
                        Text('Member #: ${_selectedMember!.memberNumber}'),
                        Text('Name: ${_selectedMember!.fullName}'),
                        Text('ID: ${_selectedMember!.idNumber ?? 'N/A'}'),
                        Row(children: [
                          Expanded(
                            child: Text(
                              'Phone: ${_selectedMember!.phoneNumber ?? 'Not set'}',
                              style: TextStyle(
                                color: _memberPhoneUpdated
                                    ? Colors.blue
                                    : null,
                                fontWeight: _memberPhoneUpdated
                                    ? FontWeight.w500
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit,
                                size: 20,
                                color:
                                    Theme.of(context).colorScheme.primary),
                            onPressed: _editMemberPhone,
                            tooltip: 'Edit phone',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text('Status:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: _selectedMember!.isActive
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              _selectedMember!.isActive ? 'Active' : 'Inactive',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ── Weight entry ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode header
                      Row(children: [
                        Expanded(
                            child: Text('Coffee Weight Details',
                                style: Theme.of(context).textTheme.titleLarge)),
                        const SizedBox(width: 8),
                        _ModeBadge(mode: _collectionMode),
                      ]),

                      // Mode toggle buttons
                      if (_isAutoModeAvailable) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          // Manual — hidden for clerks
                          if (_allowManualMode) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _collectionMode != 'manual'
                                    ? _switchToManualMode
                                    : null,
                                icon: const Icon(Icons.edit),
                                label: const Text('Manual'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _collectionMode == 'manual'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
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
                          // Auto
                          Expanded(
                            child: Obx(() {
                              final connected =
                                  _gapScaleService.isConnected.value ||
                                      _bluetoothService.isScaleConnected.value;
                              return ElevatedButton.icon(
                                onPressed: _isConnectingToScale
                                    ? null
                                    : () {
                                        if (_collectionMode == 'auto') return;
                                        if (connected) {
                                          _switchToAutoMode();
                                        } else {
                                          _connectToScaleAndEnableAutoMode();
                                        }
                                      },
                                icon: Icon(_isConnectingToScale
                                    ? Icons.hourglass_empty
                                    : connected
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth),
                                label: Text(_isConnectingToScale
                                    ? 'Connecting...'
                                    : 'Auto'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _collectionMode == 'auto'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                  foregroundColor:
                                      _collectionMode == 'auto'
                                          ? Colors.white
                                          : null,
                                ),
                              );
                            }),
                          ),
                        ]),
                        // Clerk info banner
                        if (_isClerk) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bluetooth scale required. Contact admin to enable manual entry.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),

                      // Gross weight field
                      TextFormField(
                        controller: _grossWeightController,
                        decoration: InputDecoration(
                          labelText: _isClerk
                              ? 'Gross Weight (kg) • from scale'
                              : 'Gross Weight (kg)',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isClerk
                              ? const Tooltip(
                                  message: 'Filled by Bluetooth scale',
                                  child: Icon(Icons.lock_outline,
                                      size: 18, color: Colors.grey),
                                )
                              : null,
                          filled: _isClerk,
                          fillColor: _isClerk
                              ? Colors.grey.withValues(alpha: 0.08)
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        enabled: _isManualEntry && _allowManualMode,
                        validator: (v) {
                          if (_isHoldEnabled) return null;
                          if (v == null || v.isEmpty) {
                            return 'Enter gross weight';
                          }
                          final w = double.tryParse(v);
                          if (w == null || w <= 0) {
                            return 'Enter valid weight > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Bags + Tare row
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _numberOfBagsController,
                            decoration: const InputDecoration(
                                labelText: 'Bags',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final b = int.tryParse(v);
                              if (b == null || b < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _tareWeightController,
                            decoration: const InputDecoration(
                                labelText: 'Tare / Bag (kg)',
                                border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter tare weight';
                              }
                              final w = double.tryParse(v);
                              if (w == null || w < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ]),

                      // Total tare display
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _tareWeightController,
                          _numberOfBagsController
                        ]),
                        builder: (_, __) {
                          final tare =
                              double.tryParse(_tareWeightController.text) ?? 0;
                          final bags =
                              int.tryParse(_numberOfBagsController.text) ?? 1;
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Row(children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                'Total Tare: ${(tare * bags).toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ]),
                          );
                        },
                      ),

                      // Net weight (read-only)
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _netWeightController,
                        decoration: const InputDecoration(
                            labelText: 'Net Weight (kg)',
                            border: OutlineInputBorder()),
                        readOnly: true,
                        enabled: false,
                      ),

                      // Hold mode status
                      if (_isHoldEnabled) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange)),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hold Mode Active — ${_accumulatedWeight.toStringAsFixed(2)} kg accumulated',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.orange),
                              onPressed: () => setState(() {
                                _isHoldEnabled = false;
                                _accumulatedWeight = 0.0;
                              }),
                              tooltip: 'Cancel Hold',
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Action buttons ────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_selectedMember != null &&
                            !_selectedMember!.isActive)
                        ? null
                        : _holdWeight,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Hold'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(
                    () => ElevatedButton.icon(
                      onPressed: (_selectedMember != null &&
                                  !_selectedMember!.isActive) ||
                              _coffeeCollectionController.isCollecting.value
                          ? null
                          : _saveCoffeeCollection,
                      icon: _coffeeCollectionController.isCollecting.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white)),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                          _coffeeCollectionController.isCollecting.value
                              ? 'Posting...'
                              : 'Post Value'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final String mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isAuto = mode == 'auto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isAuto ? Colors.green : Colors.blue).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAuto ? Colors.green : Colors.blue),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isAuto ? Icons.bluetooth_connected : Icons.edit,
            size: 14, color: isAuto ? Colors.green : Colors.blue),
        const SizedBox(width: 3),
        Text(isAuto ? 'AUTO' : 'MANUAL',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAuto ? Colors.green : Colors.blue)),
      ]),
    );
  }
}

class _CollectionMemberItem extends StatelessWidget {
  final Member member;
  final ValueChanged<Member> onSelected;
  const _CollectionMemberItem(
      {required this.member, required this.onSelected});

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
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text('${member.memberNumber} - ${member.fullName}',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(member.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
              fontSize: 12,
              color: member.isActive ? Colors.green : Colors.red)),
      onTap: () => onSelected(member),
    );
  }
}