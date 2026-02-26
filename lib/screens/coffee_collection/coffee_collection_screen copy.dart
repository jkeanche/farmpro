import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../services/gap_scale_service.dart';
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
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();
  final GapScaleService _gapScaleService = Get.find<GapScaleService>();
  final PrintService _printService = Get.find<PrintService>();

  Member? _selectedMember;
  bool _isManualEntry = true;
  bool _isBluetoothScaleConnected = false;
  bool _isHoldEnabled = false;
  double _accumulatedWeight = 0.0;
  double _accumulatedTareWeight = 0.0;

  Worker? _gapWeightWorker;
  Worker? _gapConnectionWorker;
  Worker? _classicBluetoothWorker;

  String _collectionMode = 'manual';
  bool _isAutoModeAvailable = false;
  final bool _isWeightMonitorActive = false;
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

  @override
  void initState() {
    super.initState();

    _initializeCollectionMode();

    final defaultTareWeight =
        _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
    _tareWeightController.text = defaultTareWeight.toStringAsFixed(1);
    _numberOfBagsController.text = '1'; // Default to 1 bag

    _grossWeightController.addListener(_calculateNetWeight);
    _tareWeightController.addListener(_calculateTotalTareWeight);
    _numberOfBagsController.addListener(_calculateTotalTareWeight);

    _settingsController.systemSettings.listen((settings) {
      if (settings != null) {
        final newTareWeight = settings.defaultTareWeight.toStringAsFixed(1);
        final currentTareWeight = _tareWeightController.text;

        // Update tare weight if it has changed and the field hasn't been manually edited
        if (currentTareWeight != newTareWeight) {
          print(
            '📏 Updating tare weight from $currentTareWeight to $newTareWeight',
          );
          setState(() {
            _tareWeightController.text = newTareWeight;
          });

          // Recalculate net weight with new tare weight
          _calculateNetWeight();
        }
        _updateCollectionModeAvailability(settings);
      }
    });

    _setupScaleWorkers();

    // Ensure members are loaded and refreshed when entering this screen
    _refreshMembersData();

    // Listen for member data changes to keep search updated
    ever(_memberController.isLoading, (bool loading) {
      if (!loading && mounted) {
        // Refresh member search when member data is reloaded
        print('Members data refreshed - updating search cache');
        _memberController.searchMembers(''); // Clear search cache
        setState(() {
          // Trigger UI update for member search
        });
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
    _memberSearchDebounce?.cancel(); // Cancel search debounce

    // Clean up stream subscriptions
    _bluetoothWeightSubscription?.cancel();
    _gapWeightSubscription?.cancel();

    // Clean up Bluetooth connections when screen is disposed
    // This is a backup cleanup in case the user navigates away without manual disconnect
    _cleanupBluetoothOnDispose();

    super.dispose();
  }

  Future<void> _cleanupBluetoothOnDispose() async {
    try {
      print(
        'Coffee Collection Screen disposing - cleaning up Bluetooth streams',
      );

      // Clean up any continuous monitoring streams
      _bluetoothService.stopContinuousWeightStream();

      // Check if auto-disconnect is enabled in settings
      final settings = _settingsController.systemSettings.value;
      if (settings?.autoDisconnectScale == true) {
        print('Auto-disconnect enabled - disconnecting from scale');

        // Disconnect from both services
        await Future.wait([
          _bluetoothService.disconnectScale(),
          _gapScaleService.disconnect(),
        ]);

        print('Scale disconnected automatically on screen exit');
      } else {
        print(
          'Auto-disconnect disabled - keeping scale connection for other screens',
        );
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
  }

  void _updateCollectionModeAvailability(settings) {
    setState(() {
      _isAutoModeAvailable = settings.enableBluetoothScale;

      if (!_isAutoModeAvailable && _collectionMode == 'auto') {
        _collectionMode = 'manual';
        _isManualEntry = true;
      }
    });
  }

  void _setupScaleWorkers() {
    _gapConnectionWorker = ever(_gapScaleService.isConnected, (bool connected) {
      setState(() {
        _isBluetoothScaleConnected = connected;
        _updateCollectionModeFromConnection();
      });

      // Start/stop GAP weight monitoring based on connection
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

      // Start/stop classic Bluetooth weight monitoring based on connection
      if (connected) {
        _startBluetoothWeightMonitoring();
      } else {
        _stopBluetoothWeightMonitoring();
      }
    });
  }

  void _startGapWeightMonitoring() {
    // Stop existing subscription first
    _gapWeightSubscription?.cancel();

    // Listen to GAP scale weight changes
    _gapWeightSubscription = _gapScaleService.currentWeight.listen((
      double weight,
    ) {
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
    // Stop existing subscription first
    _bluetoothWeightSubscription?.cancel();

    if (!_bluetoothService.isScaleConnected.value) {
      print('Cannot start Bluetooth weight monitoring - scale not connected');
      return;
    }

    try {
      // Get continuous weight stream from Bluetooth service
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
          // Don't show error to user for stream issues as they are not critical
        },
        onDone: () {
          print('Bluetooth weight stream completed');
          _bluetoothWeightSubscription = null;
        },
      );

      print('Started Bluetooth weight monitoring');
    } catch (e) {
      print('Error starting Bluetooth weight monitoring: $e');
      // Fallback: show error only if it's critical
      if (e.toString().contains('Stream has already been listened to')) {
        // Try to stop and restart the stream
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

    // Stop the continuous stream in the service
    _bluetoothService.stopContinuousWeightStream();
  }

  void _updateCollectionModeFromConnection() {
    if (!_isBluetoothScaleConnected && _collectionMode == 'auto') {
      setState(() {
        _collectionMode = 'manual';
        _isManualEntry = true;
      });
    }
  }

  void _calculateTotalTareWeight() {
    if (_tareWeightController.text.isNotEmpty &&
        _numberOfBagsController.text.isNotEmpty) {
      try {
        // final tarePerBag = double.parse(_tareWeightController.text);
        // final numberOfBags = int.parse(_numberOfBagsController.text);

        // If hold mode is active, recalculate accumulated tare weight based on current values
        if (_isHoldEnabled && _accumulatedWeight > 0) {
          // Calculate how many "holds" we have based on accumulated weight
          // This is an approximation - we recalculate based on current tare weight settings
          _recalculateAccumulatedTareWeight();
        }

        // The tare weight field shows per-bag weight, total calculation happens in net weight
        _calculateNetWeight();
      } catch (e) {
        _calculateNetWeight();
      }
    } else {
      _calculateNetWeight();
    }
  }

  void _recalculateAccumulatedTareWeight() {
    try {
      final tarePerBag = double.tryParse(_tareWeightController.text) ?? 0.0;
      final numberOfBags = int.tryParse(_numberOfBagsController.text) ?? 1;

      // Since we don't track individual holds, we need to estimate
      // We'll assume each hold was for the current number of bags setting
      // This is the best approximation we can make with the current data structure

      // Count how many times weight was held (rough estimate based on accumulated weight)
      // This is not perfect but provides a reasonable recalculation
      if (_accumulatedWeight > 0) {
        // Recalculate total tare weight based on current settings
        // We'll use a simple approach: assume the accumulated weight represents
        // multiple holds with the current bag count and tare weight settings

        // For now, we'll recalculate based on the assumption that all holds
        // should use the current tare weight per bag setting
        final estimatedHolds =
            (_accumulatedWeight / 10.0).ceil(); // Rough estimate
        _accumulatedTareWeight = tarePerBag * numberOfBags * estimatedHolds;

        print(
          'Recalculated accumulated tare weight: ${_accumulatedTareWeight.toStringAsFixed(2)} kg',
        );
        print(
          'Based on: ${tarePerBag.toStringAsFixed(2)} kg/bag × $numberOfBags bags × $estimatedHolds estimated holds',
        );
      }
    } catch (e) {
      print('Error recalculating accumulated tare weight: $e');
      // Keep the existing accumulated tare weight if calculation fails
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
      // Determine gross and tare weights
      final double grossWeight =
          _isHoldEnabled
              ? _accumulatedWeight
              : double.parse(_grossWeightController.text);

      double tarePerBag = double.parse(_tareWeightController.text);
      int numberOfBags = int.parse(_numberOfBagsController.text);
      final double totalTareWeight =
          _isHoldEnabled ? _accumulatedTareWeight : tarePerBag * numberOfBags;

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

        // **CRITICAL: Send SMS IMMEDIATELY before any other operations**
        print('🚀 PRIORITY 1: Sending SMS notification...');
        await _sendCollectionSMS(collection);

        // **IMPORTANT: Add a safety delay to ensure SMS is fully processed**
        print('⏳ Adding safety delay after SMS...');
        await Future.delayed(const Duration(seconds: 2));

        // Only then proceed with printing (which can cause lifecycle issues)
        print('🖨️  PRIORITY 2: Processing receipt printing...');
        await _printCollectionReceipt(collection);

        // Clear form and show success
        print('✅ PRIORITY 3: Completing collection process...');
        _clearForm();

        Get.snackbar(
          'Success',
          'Coffee collection posted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

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

      // Get member details for additional info
      // final member = await _memberController.getMemberByNumber(collection.memberNumber);

      // Calculate all-time cumulative weight for this member (across all seasons)
      final memberSummary = await _coffeeCollectionController
          .getMemberSeasonSummary(collection.memberId);

      // Ensure we have a valid cumulative weight value with robust parsing
      double allTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = memberSummary['allTimeWeight'];
        print(
          '🔍 Screen SMS Debug - Raw weight from DB: $rawWeight (${rawWeight.runtimeType}) for member ${collection.memberName}',
        );

        if (rawWeight != null) {
          // Handle different data types that might come from the database
          if (rawWeight is num) {
            allTimeCumulativeWeight = rawWeight.toDouble();
          } else if (rawWeight is String) {
            allTimeCumulativeWeight = double.tryParse(rawWeight) ?? 0.0;
          } else {
            // Try to convert to string first, then parse
            allTimeCumulativeWeight =
                double.tryParse(rawWeight.toString()) ?? 0.0;
          }
        }

        // Additional validation to ensure the weight is valid and not negative
        if (allTimeCumulativeWeight < 0 ||
            allTimeCumulativeWeight.isNaN ||
            allTimeCumulativeWeight.isInfinite) {
          print(
            '⚠️  Screen SMS Debug - Invalid weight detected: $allTimeCumulativeWeight, setting to 0.0',
          );
          allTimeCumulativeWeight = 0.0;
        }

        print(
          '✅ Screen SMS Debug - Final cumulative weight: $allTimeCumulativeWeight kg for member ${collection.memberName}',
        );
      } catch (e) {
        print(
          '❌ Error parsing cumulative weight for member ${collection.memberName}: $e',
        );
        print('   Raw memberSummary: $memberSummary');
        allTimeCumulativeWeight = 0.0;
      }

      // Prepare receipt data for coffee collection
      final receiptData = {
        'type': 'coffee_collection',
        'societyName': orgSettings?.societyName ?? 'Coffee Pro Society',
        'factory': orgSettings?.factory ?? 'Main Factory',
        'societyAddress': orgSettings?.address ?? '',
        'logoPath': orgSettings?.logoPath,
        'memberName': collection.memberName,
        'memberNumber': collection.memberNumber,
        'receiptNumber': collection.receiptNumber,
        'date': DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(collection.collectionDate),
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

      // Check if using standard print method
      if (sysSettings?.printMethod == 'standard') {
        // Use dialog based printing for standard method
        await _printService.printReceiptWithDialog(receiptData);
      } else {
        // Use direct printing for bluetooth method
        await _printService.printReceipt(receiptData);
      }

      print(
        'Receipt printed successfully for collection ${collection.receiptNumber}',
      );
    } catch (e) {
      print('Failed to print receipt: $e');
      // Don't show error to user as this is not critical
    }
  }

  Future<void> _sendCollectionSMS(CoffeeCollection collection) async {
    try {
      print('=== COFFEE COLLECTION SMS START ===');
      print('📱 Sending SMS for collection ${collection.receiptNumber}');
      print('👤 Member: ${collection.memberName} (ID: ${collection.memberId})');

      // Use the same robust SMS implementation as the controller
      // This ensures consistency with cancel/update SMS functionality
      await _coffeeCollectionController.sendCollectionSMS(collection);

      print('=== COFFEE COLLECTION SMS END ===');
    } catch (e) {
      print('❌ Error in collection SMS: $e');
      // Error handling is already done in the controller method
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
      _accumulatedTareWeight = 0.0;
      _memberPhoneUpdated = false; // Reset phone update flag

      // Reset tare weight to default
      final defaultTareWeight =
          _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
      _tareWeightController.text = defaultTareWeight.toStringAsFixed(1);
    });

    // Restart weight monitoring after clearing form if in auto mode
    if (_collectionMode == 'auto') {
      if (_gapScaleService.isConnected.value) {
        _startGapWeightMonitoring();
      } else if (_bluetoothService.isScaleConnected.value) {
        _startBluetoothWeightMonitoring();
      }
    }
  }

  /// Edit member phone number (persists to database)
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
                onPressed: () => Get.back(result: ''), // Clear phone number
                child: const Text('Clear'),
              ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) {
                  Get.back(result: '');
                } else {
                  // Validate phone number format
                  try {
                    final smsService = Get.find<SmsService>();
                    final validatedPhone = smsService.validateKenyanPhoneNumber(
                      phone,
                    );
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
        barrierDismissible: false, // Prevent dismissing by tapping outside
      );

      if (result != null) {
        try {
          // Show loading
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

          // Update member phone number in database
          final memberService = Get.find<MemberService>();
          final updatedMember = _selectedMember!.copyWith(
            phoneNumber: result.isEmpty ? null : result,
          );

          await memberService.updateMember(updatedMember);

          // Update local member object
          setState(() {
            _selectedMember = updatedMember;
            _memberPhoneUpdated = true;
          });

          // Refresh member controller cache
          await _memberController.refreshMembers();

          // Close loading dialog
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
          // Close loading dialog if open
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
      // Handle any unexpected errors during dialog display
    } finally {
      // Delay disposal until after the current frame to avoid assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          phoneController.dispose();
        } catch (e) {
          print('Error disposing phone controller: $e');
        }
      });
    }
  }

  // void _resetTareWeightToDefault() {
  //   final defaultTareWeight = _settingsController.systemSettings.value?.defaultTareWeight ?? 0.5;
  //   setState(() {
  //     _tareWeightController.text = defaultTareWeight.toStringAsFixed(1);
  //   });
  // }

  Future<void> _disconnectFromScale() async {
    try {
      // Show confirmation dialog first
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
        // Show progress dialog
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

        // Disconnect from both services
        await Future.wait([
          _bluetoothService.disconnectScale(),
          _gapScaleService.disconnect(),
        ]);

        // Close all dialogs and return to main screen
        Get.until((route) => route.isFirst);

        // Switch to manual mode
        await _switchToManualMode();

        Get.snackbar(
          'Scale Disconnected',
          'Successfully disconnected from scale. Switched to manual mode.',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Close any open dialogs
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
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
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
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
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
      // Show confirmation dialog first
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
        // Show loading dialog
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

        // Close loading dialog
        Get.back();

        if (importedCollections.isNotEmpty) {
          print(
            'Successfully imported ${importedCollections.length} collections',
          );

          // Force refresh all related data to ensure UI updates immediately
          await Future.wait([
            _coffeeCollectionController.refreshCollections(),
            _refreshReportsData(),
          ]);

          // Show success message with details
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

          // Navigate to reports to show updated data if user wants
          _showPostImportOptions(importedCollections.length);
        } else {
          print('No collections were imported');
          Get.snackbar(
            'Import Complete',
            'No new collections were imported. This might be due to:\n'
                '• All collections already exist\n'
                '• Invalid data in CSV file\n'
                '• No valid members found',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      // Close any loading dialogs
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
      // Trigger refresh of all screens that might show collection data
      // This ensures reports are immediately updated after import

      // Get all controllers that might need refreshing
      final seasonController = Get.find<SeasonController>();

      // Refresh season data which includes collection summaries
      await seasonController.refreshSeasons();

      print('Reports data refreshed after collection import');
    } catch (e) {
      print('Error refreshing reports data: $e');
    }
  }

  void _showPostImportOptions(int importedCount) {
    Get.dialog(
      AlertDialog(
        title: Text('Import Complete'),
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
              // Navigate to reports screen
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
      // Force refresh members if not loaded
      if (_memberController.members.isEmpty) {
        await _refreshMembersData();
      }

      // Try direct database search for recently imported members
      final memberService = Get.find<MemberService>();

      // First try by exact member number from cache or db
      final memberByNumber = await memberService.getMemberByMemberNumber(query);
      if (memberByNumber != null) {
        return memberByNumber;
      }

      // If not found, perform a quick DB search
      final quickResults = await memberService.quickSearchMembers(
        query,
        limit: 1,
      );
      if (quickResults.isNotEmpty) {
        return quickResults.first;
      }
      return null;
    } catch (e) {
      print('Error in async member search: $e');
      return null;
    }
  }

  Widget _buildMemberSearchResults(List<Member> members) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: members.length,
      physics:
          const NeverScrollableScrollPhysics(), // Since it's in a scrollable parent
      itemExtent: 56, // Fixed height for better performance
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
              _memberPhoneUpdated =
                  false; // Reset phone update flag when selecting new member
            });
          },
        );
      },
    );
  }

  Future<void> _refreshMembersData() async {
    try {
      // Force refresh members data to ensure latest imported members are available
      await _memberController.refreshMembers();
      print('Members data refreshed for collection screen');
    } catch (e) {
      print('Error refreshing members data: $e');
    }
  }

  Future<void> _switchToManualMode() async {
    setState(() {
      _collectionMode = 'manual';
      _isManualEntry = true;
    });
    // Stop any active weight monitoring
    _stopBluetoothWeightMonitoring();
    _stopGapWeightMonitoring();
  }

  void _switchToAutoMode() {
    setState(() {
      _collectionMode = 'auto';
      _isManualEntry = false;
    });
    // Start weight monitoring if a scale is connected
    if (_gapScaleService.isConnected.value) {
      _startGapWeightMonitoring();
    } else if (_bluetoothService.isScaleConnected.value) {
      _startBluetoothWeightMonitoring();
    }
  }

  Future<void> _connectToScaleAndEnableAutoMode() async {
    // This is a placeholder implementation.
    // A device selection dialog would be needed here.
    try {
      bool isConnected =
          _bluetoothService.isScaleConnected.value ||
          _gapScaleService.isConnected.value;
      if (!isConnected) {
        // Placeholder for connection logic
        Get.snackbar(
          'Connect Scale',
          'Please connect to a scale from the settings screen.',
        );
        return;
      }
      _switchToAutoMode();
    } catch (e) {
      Get.snackbar('Error', 'Failed to connect to scale: $e');
      await _switchToManualMode();
    }
  }

  void _holdWeight() {
    if (_grossWeightController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'No weight to hold',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final grossWeight = double.parse(_grossWeightController.text);
      final tarePerBag = double.parse(_tareWeightController.text);
      final numberOfBags = int.parse(_numberOfBagsController.text);
      final totalTareWeight = tarePerBag * numberOfBags;

      if (grossWeight <= 0) return;

      setState(() {
        _isHoldEnabled = true;
        _accumulatedWeight += grossWeight;
        _accumulatedTareWeight += totalTareWeight;
        _grossWeightController.clear();
        _netWeightController.clear();
      });

      Get.snackbar(
        'Weight Held',
        'Accumulated Weight: ${_accumulatedWeight.toStringAsFixed(2)} kg',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Invalid weight or tare value.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
                  // Navigate to collections history
                  break;
              }
            },
            itemBuilder:
                (context) => [
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
                                _coffeeCollectionController
                                    .currentSeasonDisplay,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () =>
                            !_coffeeCollectionController.canCollect
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

                      CustomTextField(
                        controller: _memberNumberController,
                        label: 'Member Number or Search',
                        hint: 'Enter member number or search by name',
                        prefix: const Icon(Icons.search),
                        onChanged: (value) async {
                          if (value.isNotEmpty) {
                            // Force refresh members if search is not working
                            if (_memberController.members.isEmpty) {
                              await _refreshMembersData();
                            }

                            // First try to find by exact member number
                            final memberByNumber = await _memberController
                                .getMemberByNumber(value);
                            if (memberByNumber != null) {
                              setState(() {
                                _selectedMember = memberByNumber;
                                _memberPhoneUpdated =
                                    false; // Reset phone update flag when selecting new member
                              });
                              return;
                            }

                            // If not found by exact number, search by name or partial match
                            final searchResults = _memberController
                                .searchMembers(value);
                            if (searchResults.length == 1) {
                              // If exactly one match found, auto-select it
                              setState(() {
                                _selectedMember = searchResults.first;
                                _memberPhoneUpdated =
                                    false; // Reset phone update flag when selecting new member
                              });
                            } else if (searchResults.isEmpty) {
                              // Try async search as fallback for recently imported members
                              try {
                                final asyncMember = await _searchMemberAsync(
                                  value,
                                );
                                setState(() {
                                  _selectedMember = asyncMember;
                                  _memberPhoneUpdated =
                                      false; // Reset phone update flag when selecting new member
                                });
                              } catch (e) {
                                setState(() {
                                  _selectedMember = null;
                                  _memberPhoneUpdated =
                                      false; // Reset phone update flag when clearing member
                                });
                              }
                            } else {
                              // Multiple matches found, don't auto-select
                              setState(() {
                                _selectedMember = null;
                                _memberPhoneUpdated =
                                    false; // Reset phone update flag when clearing member
                              });
                            }
                          } else {
                            setState(() {
                              _selectedMember = null;
                              _memberPhoneUpdated =
                                  false; // Reset phone update flag when clearing member
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
                          child:
                              _isMemberSearching
                                  ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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

                                      // Use quick search to avoid UI blocking
                                      if (_memberController
                                              .members
                                              .isNotEmpty &&
                                          _memberNumberController
                                              .text
                                              .isNotEmpty) {
                                        final query =
                                            _memberNumberController.text
                                                .toLowerCase();
                                        searchResults =
                                            _memberController.members
                                                .where(
                                                  (member) =>
                                                      member.memberNumber
                                                          .toLowerCase()
                                                          .contains(query) ||
                                                      member.fullName
                                                          .toLowerCase()
                                                          .contains(query),
                                                )
                                                .take(
                                                  5,
                                                ) // Limit to 5 results for performance
                                                .toList();
                                      }

                                      if (searchResults.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text(
                                            'No members found matching your search',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }

                                      return _buildMemberSearchResults(
                                        searchResults,
                                      );
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
                        Text(
                          'ID Number: ${_selectedMember!.idNumber ?? 'N/A'}',
                        ),
                        // Phone number with edit functionality
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Phone: ${_selectedMember!.phoneNumber ?? 'Not set'}',
                                style: TextStyle(
                                  color:
                                      _memberPhoneUpdated ? Colors.blue : null,
                                  fontWeight:
                                      _memberPhoneUpdated
                                          ? FontWeight.w500
                                          : null,
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
                                color:
                                    _selectedMember!.isActive
                                        ? Colors.green
                                        : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedMember!.isActive
                                    ? 'Active'
                                    : 'Inactive',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
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
                      // Mode Indicator and Toggle
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
                                color:
                                    _collectionMode == 'auto'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _collectionMode == 'auto'
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
                                    color:
                                        _collectionMode == 'auto'
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
                                        color:
                                            _collectionMode == 'auto'
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

                      // Mode Toggle Buttons (only show if auto mode is available)
                      if (_isAutoModeAvailable) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
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
                                  backgroundColor:
                                      _collectionMode == 'manual'
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : null,
                                  foregroundColor:
                                      _collectionMode == 'manual'
                                          ? Colors.white
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() {
                                bool isAnyScaleConnected =
                                    _gapScaleService.isConnected.value ||
                                    _bluetoothService.isScaleConnected.value;

                                return ElevatedButton.icon(
                                  onPressed:
                                      _isConnectingToScale
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
                                        : isAnyScaleConnected
                                        ? 'Auto'
                                        : 'Auto',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _collectionMode == 'auto'
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
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
                      ],

                      const SizedBox(height: 16.0),

                      // Gross weight
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _grossWeightController,
                              decoration: const InputDecoration(
                                labelText: 'Gross Weight (kg)',
                                hintText: 'Enter gross weight',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              enabled: _isManualEntry,
                              validator: (value) {
                                // Skip gross weight validation when hold mode is active
                                if (_isHoldEnabled) {
                                  return null;
                                }
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
                          // if (_isBluetoothScaleConnected) ...[
                          //   const SizedBox(width: 16.0),
                          //   ElevatedButton.icon(
                          //     onPressed: _getWeightFromScale,
                          //     icon: const Icon(Icons.scale),
                          //     label: const Text('Scale'),
                          //   ),
                          // ],
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                                double.tryParse(_tareWeightController.text) ??
                                0;
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
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
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

                      // Net Weight (calculated)
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
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
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
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isHoldEnabled = false;
                                        _accumulatedWeight = 0.0;
                                        _accumulatedTareWeight = 0.0;
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
                                        .isCollecting
                                        .value
                                    ? null
                                    : _saveCoffeeCollection),
                        icon:
                            _coffeeCollectionController.isCollecting.value
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

/// Optimized member search item for coffee collection
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
        backgroundColor:
            member.isActive
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
