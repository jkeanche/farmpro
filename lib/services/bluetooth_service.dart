import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class BluetoothService extends GetxService {
  static BluetoothService get to => Get.find();

  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();

  final RxBool isScanning = false.obs;
  final RxList<Device> devices = <Device>[].obs;
  final RxList<Device> pairedDevices = <Device>[].obs;

  // Reactive connection tracking
  final RxBool isScaleConnected = false.obs;
  final RxBool isPrinterConnected = false.obs;
  final RxString connectedScaleAddress = ''.obs;
  final RxString connectedPrinterAddress = ''.obs;

  // Connection tracking (for internal use)
  bool _isScaleConnected = false;
  bool _isPrinterConnected = false;
  String? _connectedScaleAddress;
  String? _connectedPrinterAddress;

  Device? get connectedScale =>
      _connectedScaleAddress != null
          ? devices.firstWhereOrNull((d) => d.address == _connectedScaleAddress)
          : null;

  Device? get connectedPrinter =>
      _connectedPrinterAddress != null
          ? devices.firstWhereOrNull(
            (d) => d.address == _connectedPrinterAddress,
          )
          : null;

  StreamSubscription? _deviceDataSubscription;

  // Stream for continuous weight monitoring
  StreamController<double>? _weightStreamController;
  StreamSubscription<Uint8List>? _continuousDataSubscription;

  Future<BluetoothService> init() async {
    try {
      print('Initializing Classic Bluetooth service...');

      // Initialize permissions
      await _bluetoothClassicPlugin.initPermissions();

      // Get initial paired devices
      await _refreshPairedDevices();

      print('Classic Bluetooth service initialized successfully');
    } catch (e) {
      print('Error initializing Classic Bluetooth: $e');
    }

    return this;
  }

  @override
  void onClose() {
    _deviceDataSubscription?.cancel();
    disconnectAndCleanupStreams(); // Use the new cleanup method
    if (_isScaleConnected) {
      _bluetoothClassicPlugin.disconnect();
    }
    super.onClose();
  }

  // Refresh paired devices list
  Future<void> _refreshPairedDevices() async {
    try {
      List<Device> paired = await _bluetoothClassicPlugin.getPairedDevices();
      pairedDevices.value = paired;
      devices.value = paired; // Use paired devices as main devices list

      print('Found ${paired.length} paired devices:');
      for (var device in paired) {
        print('- ${device.name} (${device.address})');
      }
    } catch (e) {
      print('Error getting paired devices: $e');
    }
  }

  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      // This is a basic check - bluetooth_classic doesn't have a direct method
      // but we can infer it from getting paired devices
      await _bluetoothClassicPlugin.getPairedDevices();
      return true;
    } catch (e) {
      print('Error checking Bluetooth state: $e');
      return false;
    }
  }

  // Request user to enable Bluetooth - not directly supported by bluetooth_classic
  Future<bool> requestBluetoothEnable() async {
    Get.snackbar(
      'Bluetooth Required',
      'Please enable Bluetooth in system settings',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
    return false;
  }

  // Start discovery scan
  Future<void> startScan() async {
    if (isScanning.value) {
      return;
    }

    try {
      isScanning.value = true;

      // First get paired devices
      await _refreshPairedDevices();

      // Start discovery
      print('Starting Bluetooth discovery...');

      // Listen for discovered devices
      _bluetoothClassicPlugin.onDeviceDiscovered().listen((Device device) {
        print('Discovered device: ${device.name} (${device.address})');

        // Add to devices list if not already there
        bool exists = devices.any((d) => d.address == device.address);
        if (!exists) {
          devices.add(device);
        }
      });

      // Start scan
      await _bluetoothClassicPlugin.startScan();

      Get.snackbar(
        'Scanning Started',
        'Scanning for Bluetooth devices...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );

      // Set timeout for discovery
      Timer(const Duration(seconds: 30), () {
        if (isScanning.value) {
          stopScan();
        }
      });
    } catch (e) {
      print('Error starting discovery: $e');
      isScanning.value = false;

      Get.snackbar(
        'Scan Error',
        'Failed to scan for devices: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Stop discovery scan
  Future<void> stopScan() async {
    try {
      await _bluetoothClassicPlugin.stopScan();
      isScanning.value = false;

      Get.snackbar(
        'Scan Complete',
        'Found ${devices.length} devices',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error stopping discovery: $e');
    }
  }

  // Connect to printer by address
  Future<bool> connectToPrinterByAddress(String address) async {
    try {
      print('Connecting to printer: $address');

      // Disconnect any existing connection
      if (_isPrinterConnected || _isScaleConnected) {
        await _bluetoothClassicPlugin.disconnect();
        _isPrinterConnected = false;
        _isScaleConnected = false;
        // Update reactive observables
        isPrinterConnected.value = false;
        isScaleConnected.value = false;
        connectedPrinterAddress.value = '';
        connectedScaleAddress.value = '';
      }

      // Connect to the device using the serial UUID
      await _bluetoothClassicPlugin.connect(
        address,
        "00001101-0000-1000-8000-00805f9b34fb",
      );

      _isPrinterConnected = true;
      _connectedPrinterAddress = address;

      // Update reactive observables
      isPrinterConnected.value = true;
      connectedPrinterAddress.value = address;

      Get.snackbar(
        'Printer Connected',
        'Successfully connected to printer',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      print('Error connecting to printer: $e');

      Get.snackbar(
        'Connection Failed',
        'Failed to connect to printer: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }
  }

  // Connect to scale by address
  Future<bool> connectToScaleByAddress(String address) async {
    try {
      print('Connecting to scale: $address');

      // Disconnect any existing connection
      if (_isPrinterConnected || _isScaleConnected) {
        await _bluetoothClassicPlugin.disconnect();
        _isPrinterConnected = false;
        _isScaleConnected = false;
        // Update reactive observables
        isPrinterConnected.value = false;
        isScaleConnected.value = false;
        connectedPrinterAddress.value = '';
        connectedScaleAddress.value = '';
      }

      // Connect to the device using the serial UUID
      await _bluetoothClassicPlugin.connect(
        address,
        "00001101-0000-1000-8000-00805f9b34fb",
      );

      _isScaleConnected = true;
      _connectedScaleAddress = address;

      // Update reactive observables
      isScaleConnected.value = true;
      connectedScaleAddress.value = address;

      Get.snackbar(
        'Scale Connected',
        'Successfully connected to scale',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      print('Error connecting to scale: $e');

      Get.snackbar(
        'Connection Failed',
        'Failed to connect to scale: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }
  }

  // Read weight from connected scale
  Future<double?> readWeightFromScale() async {
    if (!_isScaleConnected) {
      throw Exception('Scale not connected');
    }

    try {
      print('Reading weight from scale...');

      // Set up completer to wait for response
      final completer = Completer<double?>();

      // Listen for incoming data first (in case scale sends continuous data)
      _deviceDataSubscription?.cancel();
      _deviceDataSubscription = _bluetoothClassicPlugin
          .onDeviceDataReceived()
          .listen((Uint8List data) {
            try {
              // Convert data to hex for debugging
              String hexData = data
                  .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                  .join(' ');
              print('Raw data (hex): $hexData');

              // Convert to string
              String response = String.fromCharCodes(data).trim();
              print('Raw data (string): "$response"');

              // Also try ASCII conversion for non-printable characters
              String asciiResponse = '';
              for (int byte in data) {
                if (byte >= 32 && byte <= 126) {
                  asciiResponse += String.fromCharCode(byte);
                } else {
                  asciiResponse += '[${byte.toString()}]';
                }
              }
              print('ASCII interpretation: "$asciiResponse"');

              // Parse weight from response
              double? weight = _parseWeightResponse(response);
              print('Parsed weight: $weight');

              if (weight != null && !completer.isCompleted) {
                print('✅ Valid weight found: $weight kg');
                completer.complete(weight);
              }
            } catch (e) {
              print('Error parsing scale response: $e');
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
          });

      // Wait a bit to see if we get continuous data
      await Future.delayed(const Duration(milliseconds: 500));

      if (!completer.isCompleted) {
        // Send weight request command if no data received yet
        print('No continuous data detected, sending weight request command...');
        await _bluetoothClassicPlugin.write("W\r\n");

        // Also try alternative commands
        await Future.delayed(const Duration(milliseconds: 200));
        if (!completer.isCompleted) {
          print('Trying alternative command: SI\\r\\n');
          await _bluetoothClassicPlugin.write("SI\r\n");
        }

        await Future.delayed(const Duration(milliseconds: 200));
        if (!completer.isCompleted) {
          print('Trying alternative command: P\\r\\n');
          await _bluetoothClassicPlugin.write("P\r\n");
        }
      }

      // Wait for response with timeout
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⚠️ Timeout waiting for scale response');
          throw TimeoutException('Timeout waiting for scale response');
        },
      );
    } catch (e) {
      print('Error reading weight from scale: $e');
      rethrow;
    } finally {
      _deviceDataSubscription?.cancel();
    }
  }

  // Parse weight response from scale
  double? _parseWeightResponse(String response) {
    try {
      print('Parsing response: "$response" (length: ${response.length})');

      if (response.isEmpty) {
        print('Empty response, skipping');
        return null;
      }

      // Try different parsing approaches
      List<String> parseAttempts = [];

      // 1. Direct numeric parsing (for simple responses like "5.20")
      String directNumeric = response.replaceAll(RegExp(r'[^\d.-]'), '').trim();
      if (directNumeric.isNotEmpty) {
        parseAttempts.add('Direct: "$directNumeric"');
        double? weight = double.tryParse(directNumeric);
        if (weight != null && weight >= 0) {
          print('✅ Parsed as direct numeric: $weight');
          return weight;
        }
      }

      // 2. Common scale response formats with prefixes
      String cleaned =
          response
              .replaceAll(RegExp(r'ST,NT,\s*'), '') // "ST,NT, 5.20 kg"
              .replaceAll(RegExp(r'ST,GS,\s*'), '') // "ST,GS, 5.20 kg"
              .replaceAll(RegExp(r'ST,US,\s*'), '') // "ST,US, 5.20 kg"
              .replaceAll(RegExp(r'\s*kg\s*$'), '') // Remove trailing "kg"
              .replaceAll(RegExp(r'\s*g\s*$'), '') // Remove trailing "g"
              .replaceAll(RegExp(r'^W:\s*'), '') // Remove "W:" prefix
              .replaceAll(RegExp(r'^NET:\s*'), '') // Remove "NET:" prefix
              .replaceAll(RegExp(r'^WEIGHT:\s*'), '') // Remove "WEIGHT:" prefix
              .replaceAll(RegExp(r'^WT:\s*'), '') // Remove "WT:" prefix
              .trim();

      parseAttempts.add('Cleaned: "$cleaned"');

      // Extract numeric value
      String numericOnly = cleaned.replaceAll(RegExp(r'[^\d.-]'), '').trim();
      parseAttempts.add('Numeric only: "$numericOnly"');

      if (numericOnly.isNotEmpty) {
        double? weight = double.tryParse(numericOnly);
        if (weight != null && weight >= 0) {
          print('✅ Parsed after cleaning: $weight');
          return weight;
        }
      }

      // 3. Try to find any decimal number in the string
      RegExp decimalPattern = RegExp(r'(\d+\.?\d*)');
      Match? match = decimalPattern.firstMatch(response);
      if (match != null) {
        String matched = match.group(1)!;
        parseAttempts.add('Regex match: "$matched"');
        double? weight = double.tryParse(matched);
        if (weight != null && weight >= 0) {
          print('✅ Parsed with regex: $weight');
          return weight;
        }
      }

      // 4. Handle comma as decimal separator (European format)
      String commaAsDecimal = response.replaceAll(',', '.');
      String commaNumeric =
          commaAsDecimal.replaceAll(RegExp(r'[^\d.-]'), '').trim();
      if (commaNumeric.isNotEmpty) {
        parseAttempts.add('Comma as decimal: "$commaNumeric"');
        double? weight = double.tryParse(commaNumeric);
        if (weight != null && weight >= 0) {
          print('✅ Parsed with comma as decimal: $weight');
          return weight;
        }
      }

      print('❌ All parsing attempts failed:');
      for (String attempt in parseAttempts) {
        print('  - $attempt');
      }

      return null;
    } catch (e) {
      print('❌ Error parsing weight: $response, error: $e');
      return null;
    }
  }

  // Check if scale is connected
  bool getScaleConnectionStatus() {
    return isScaleConnected.value;
  }

  // Check if classic scale is connected (for compatibility)
  bool isClassicScaleConnected() {
    return isScaleConnected.value;
  }

  // Read weight from classic scale (for compatibility)
  Future<double?> readWeightFromClassicScale() async {
    return await readWeightFromScale();
  }

  // Disconnect scale
  Future<void> disconnectScale() async {
    try {
      if (_isScaleConnected) {
        // Clean up streams before disconnecting
        disconnectAndCleanupStreams();

        await _bluetoothClassicPlugin.disconnect();
        _isScaleConnected = false;
        _connectedScaleAddress = null;

        // Update reactive observables
        isScaleConnected.value = false;
        connectedScaleAddress.value = '';

        Get.snackbar(
          'Scale Disconnected',
          'Scale disconnected successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error disconnecting scale: $e');
    }
  }

  // Disconnect classic scale (for compatibility)
  Future<void> disconnectClassicScale() async {
    return await disconnectScale();
  }

  // Print receipt using connected printer
  Future<bool> printReceipt(Map<String, dynamic> receiptData) async {
    if (!_isPrinterConnected) {
      throw Exception('Printer not connected');
    }

    try {
      print('Printing receipt...');

      // Format receipt data into text format
      String receiptText = _formatReceiptText(receiptData);

      // Send commands to printer
      await _bluetoothClassicPlugin.write(receiptText);

      print('Receipt sent to printer successfully');
      return true;
    } catch (e) {
      print('Error printing receipt: $e');
      return false;
    }
  }

  // Format receipt data into text format
  String _formatReceiptText(Map<String, dynamic> receiptData) {
    StringBuffer receipt = StringBuffer();

    // Logo indicator (for Bluetooth printers that can't print images)
    if (receiptData['logoPath'] != null &&
        receiptData['logoPath'].toString().isNotEmpty) {
      receipt.writeln('');
      receipt.writeln('================================');
      receipt.writeln('    [ORGANIZATION LOGO]    ');
      receipt.writeln('================================');
      receipt.writeln('');
    }

    // Header
    receipt.writeln('${receiptData['societyName'] ?? 'Farm Fresh'}');
    if (receiptData['factory'] != null) {
      receipt.writeln('${receiptData['factory']}');
    }
    if (receiptData['societyAddress'] != null) {
      receipt.writeln('${receiptData['societyAddress']}');
    }

    // Current print time (when receipt was printed)
    final now = DateTime.now();
    final printDate = DateFormat('dd/MM/yyyy').format(now);
    final printTime = DateFormat('HH:mm').format(now);

    receipt.writeln('Printed: $printDate at $printTime');
    receipt.writeln('');

    // Divider
    receipt.writeln('--------------------------------');

    // Receipt number
    if (receiptData['receiptNumber'] != null) {
      receipt.writeln('Receipt #: ${receiptData['receiptNumber']}');
    }

    // Member information
    receipt.writeln('Member: ${receiptData['memberName'] ?? 'N/A'}');
    receipt.writeln('Member #: ${receiptData['memberNumber'] ?? 'N/A'}');

    // Collection/Delivery Date (the actual date when collection happened)
    String dateLabel =
        receiptData['type'] == 'coffee_collection'
            ? 'Collection Date'
            : 'Delivery Date';
    receipt.writeln('$dateLabel: ${receiptData['date'] ?? 'N/A'}');

    // Served by
    if (receiptData['servedBy'] != null) {
      receipt.writeln('Served By: ${receiptData['servedBy']}');
    }

    // Coffee Collection Details (if applicable)
    if (receiptData['type'] == 'coffee_collection') {
      receipt.writeln('');
      receipt.writeln('COFFEE COLLECTION DETAILS');
      receipt.writeln('================================');
      if (receiptData['productType'] != null) {
        receipt.writeln('** COFFEE TYPE: ${receiptData['productType']} **');
      }
      if (receiptData['seasonName'] != null) {
        receipt.writeln('Season: ${receiptData['seasonName']}');
      }
      if (receiptData['numberOfBags'] != null) {
        receipt.writeln('Number of Bags: ${receiptData['numberOfBags']}');
      }
      receipt.writeln('================================');
    }

    // Weight information
    if (receiptData['grossWeight'] != null) {
      receipt.writeln('Gross Weight: ${receiptData['grossWeight']} kg');
    }
    if (receiptData['tareWeightPerBag'] != null) {
      receipt.writeln('Tare per Bag: ${receiptData['tareWeightPerBag']} kg');
    }
    if (receiptData['totalTareWeight'] != null) {
      receipt.writeln(
        'Total Tare Weight: ${receiptData['totalTareWeight']} kg',
      );
    } else if (receiptData['tareWeight'] != null) {
      receipt.writeln('Tare Weight: ${receiptData['tareWeight']} kg');
    }
    if (receiptData['netWeight'] != null) {
      receipt.writeln('Net Weight: ${receiptData['netWeight']} kg');
    }

    // Current season cumulative weight for coffee collections
    if (receiptData['type'] == 'coffee_collection' &&
        receiptData['allTimeCumulativeWeight'] != null) {
      receipt.writeln('');
      receipt.writeln(
        '** SEASON TOTAL: ${receiptData['allTimeCumulativeWeight']} kg **',
      );
      receipt.writeln('');
    } else if (receiptData['cumulativeWeight'] != null) {
      // Monthly cumulative for coffee/generic deliveries
      receipt.writeln('');
      receipt.writeln(
        'Month-to-date Total: ${receiptData['cumulativeWeight']} kg',
      );
      receipt.writeln('');
    }

    // Sales Details (if applicable)
    if (receiptData['type'] == 'sale') {
      receipt.writeln('');
      receipt.writeln('SALE DETAILS');
      receipt.writeln('================================');

      // Items
      if (receiptData['items'] != null) {
        final items = receiptData['items'] as List;
        for (final item in items) {
          receipt.writeln('${item['productName']}');
          receipt.writeln(
            '  ${item['quantity']} x KSh ${item['unitPrice']} = KSh ${item['totalPrice']}',
          );
        }
        receipt.writeln('--------------------------------');
      }

      // Totals
      if (receiptData['totalAmount'] != null) {
        receipt.writeln('Total: KSh ${receiptData['totalAmount']}');
      }
      if (receiptData['paidAmount'] != null) {
        receipt.writeln('Paid: KSh ${receiptData['paidAmount']}');
      }
      if (receiptData['saleType'] == 'CREDIT' &&
          receiptData['balanceAmount'] != null) {
        final balance =
            double.tryParse(receiptData['balanceAmount'] ?? '0') ?? 0;
        if (balance > 0) {
          receipt.writeln(
            'This Sale Balance: KSh ${receiptData['balanceAmount']}',
          );
          if (receiptData['totalBalance'] != null) {
            receipt.writeln(
              'Total Balance: KSh ${receiptData['totalBalance']}',
            );
          }
        }
      }
      if (receiptData['saleType'] != null) {
        receipt.writeln('Sale Type: ${receiptData['saleType']}');
      }
      receipt.writeln('================================');
    }

    // Entry type
    if (receiptData['entryType'] != null) {
      receipt.writeln('Entry Type: ${receiptData['entryType']}');
    }

    // Divider
    receipt.writeln('--------------------------------');

    // Footer
    receipt.writeln('${receiptData['slogan'] ?? 'Thank you!'}');
    receipt.writeln('A product of Inuka Technologies');
    receipt.writeln('\n\n');

    return receipt.toString();
  }

  // Show pairing instructions for classic Bluetooth devices
  void showClassicBluetoothPairingInstructions() {
    Get.dialog(
      AlertDialog(
        title: const Text('Classic Bluetooth Pairing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To connect your classic Bluetooth device:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('1. Open Android Settings'),
              const Text('2. Go to Bluetooth settings'),
              const Text('3. Put your device in pairing mode'),
              const Text('4. Tap "Pair new device"'),
              const Text('5. Select your device from the list'),
              const Text('6. Enter PIN when prompted:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Common PINs:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• 1234 (most common)'),
                    Text('• 0000'),
                    Text('• 1111'),
                    Text('• Check device manual'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('7. Return to Farm Fresh app'),
              const Text('8. Refresh devices to see paired device'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Got it')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Refresh paired devices
              _refreshPairedDevices();
            },
            child: const Text('Refresh Devices'),
          ),
        ],
      ),
    );
  }

  // Compatibility methods for existing code
  Future<bool> connectToClassicDeviceByAddress(String address) async {
    return await connectToScaleByAddress(address);
  }

  Future<void> startDiscovery() async {
    await startScan();
  }

  // Additional compatibility methods
  Future<void> discoverAllDevices() async {
    await startScan();
  }

  // For compatibility with settings screen
  final RxList<Map<String, String>> classicDeviceInfo =
      <Map<String, String>>[].obs;

  void showAddPairedDeviceDialog() {
    // Implementation for adding paired devices manually
    _refreshPairedDevices();
  }

  // Additional compatibility methods for existing code
  List<Device> get connectedDevices =>
      devices
          .where(
            (d) =>
                (d.address == connectedScaleAddress.value &&
                    isScaleConnected.value) ||
                (d.address == connectedPrinterAddress.value &&
                    isPrinterConnected.value),
          )
          .toList();

  Future<bool> connectToDevice(Device device, {Duration? timeout}) async {
    // Determine if this is a printer or scale based on usage context
    // For now, assume it's a scale unless specified otherwise
    return await connectToScaleByAddress(device.address);
  }

  Future<bool> connectToPrinter(Device device) async {
    return await connectToPrinterByAddress(device.address);
  }

  Future<bool> connectToScale(Device device) async {
    return await connectToScaleByAddress(device.address);
  }

  Future<double?> getWeightFromScale() async {
    return await readWeightFromScale();
  }

  Future<Device?> findDeviceByAddress(String address) async {
    // Refresh paired devices first
    await _refreshPairedDevices();

    // Look for device in paired devices
    Device? device = devices.firstWhereOrNull(
      (d) => d.address.toUpperCase() == address.toUpperCase(),
    );

    return device;
  }

  Future<Map<String, dynamic>> runBluetoothDiagnostic() async {
    Map<String, dynamic> diagnosticResults = {
      'bluetoothOn': false,
      'bluetoothState': 'unknown',
      'permissions':
          true, // bluetooth_classic handles permissions automatically
      'locationPermission': true,
      'errors': [],
      'recommendations': [],
      'connectedDevices': {
        'count': connectedDevices.length,
        'devices':
            connectedDevices
                .map(
                  (device) => {
                    'name': device.name,
                    'address': device.address,
                    'type': 'classic_bluetooth',
                  },
                )
                .toList(),
      },
      'appDeviceList': {
        'count': devices.length,
        'connectedCount': connectedDevices.length,
        'devices':
            devices
                .map(
                  (device) => {
                    'name': device.name,
                    'address': device.address,
                    'connected': connectedDevices.any(
                      (d) => d.address == device.address,
                    ),
                  },
                )
                .toList(),
      },
    };

    try {
      // Check if Bluetooth is working by getting paired devices
      bool bluetoothWorking = await isBluetoothEnabled();
      diagnosticResults['bluetoothOn'] = bluetoothWorking;
      diagnosticResults['bluetoothState'] = bluetoothWorking ? 'on' : 'off';

      if (!bluetoothWorking) {
        diagnosticResults['errors'].add('Bluetooth appears to be disabled');
        diagnosticResults['recommendations'].add(
          'Enable Bluetooth in system settings',
        );
      }

      if (devices.isEmpty) {
        diagnosticResults['recommendations'].add(
          'No paired devices found. Pair your printer and scale in Android Settings first.',
        );
      }
    } catch (e) {
      diagnosticResults['errors'].add('Bluetooth diagnostic error: $e');
    }

    return diagnosticResults;
  }

  /// Get a stream of continuous weight readings for real-time monitoring
  Stream<double> getContinuousWeightStream() {
    print(
      '🔄 getContinuousWeightStream called - Scale connected: $_isScaleConnected',
    );

    if (!_isScaleConnected) {
      print('❌ Cannot start continuous stream - scale not connected');
      return Stream.error('Scale not connected');
    }

    // If we already have a working stream controller, return its stream
    if (_weightStreamController != null && !_weightStreamController!.isClosed) {
      print('✅ Reusing existing weight stream controller');
      return _weightStreamController!.stream;
    }

    // Create new broadcast stream controller to allow multiple listeners
    _weightStreamController = StreamController<double>.broadcast();
    print('🆕 Created new broadcast stream controller');

    // Only create a new subscription if we don't have one
    if (_continuousDataSubscription == null) {
      print('🚀 Starting continuous weight monitoring stream...');

      // Listen for incoming data continuously
      _continuousDataSubscription = _bluetoothClassicPlugin
          .onDeviceDataReceived()
          .listen(
            (Uint8List data) {
              try {
                // Convert to string
                String response = String.fromCharCodes(data).trim();
                print('📦 Continuous stream raw data: "$response"');

                // Parse weight from response
                double? weight = _parseWeightResponse(response);

                if (weight != null && weight >= 0) {
                  print('✅ Parsed continuous weight: $weight kg');
                  if (_weightStreamController != null &&
                      !_weightStreamController!.isClosed) {
                    _weightStreamController!.add(weight);
                    print('📤 Weight added to stream: $weight kg');
                  } else {
                    print('⚠️ Stream controller is null or closed');
                  }
                } else {
                  print('⚠️ Could not parse weight from: "$response"');
                }
              } catch (e) {
                print('❌ Error parsing continuous weight data: $e');
                if (_weightStreamController != null &&
                    !_weightStreamController!.isClosed) {
                  _weightStreamController!.addError(e);
                }
              }
            },
            onError: (error) {
              print('❌ Error in continuous weight stream: $error');
              if (_weightStreamController != null &&
                  !_weightStreamController!.isClosed) {
                _weightStreamController!.addError(error);
              }
            },
            onDone: () {
              print('🏁 Bluetooth data stream completed');
              _continuousDataSubscription = null;
            },
          );
      print('✅ Continuous weight stream subscription created');
    } else {
      print('🔄 Reusing existing Bluetooth data subscription');
    }

    print('✅ Returning weight stream');
    return _weightStreamController!.stream;
  }

  /// Stop continuous weight monitoring
  void stopContinuousWeightStream() {
    print('🛑 Stopping continuous weight monitoring stream...');

    // Close the stream controller but keep the Bluetooth subscription
    // This allows us to reuse the subscription when resuming
    if (_weightStreamController != null) {
      print('🗑️ Closing weight stream controller');
      _weightStreamController!.close();
      _weightStreamController = null;
    }

    print(
      '✅ Weight stream controller stopped (Bluetooth subscription kept for reuse)',
    );
  }

  /// Completely disconnect and clean up all Bluetooth subscriptions
  void disconnectAndCleanupStreams() {
    print('🧹 Cleaning up all Bluetooth streams and subscriptions...');

    // Close stream controller
    if (_weightStreamController != null) {
      _weightStreamController!.close();
      _weightStreamController = null;
    }

    // Cancel Bluetooth data subscription
    if (_continuousDataSubscription != null) {
      _continuousDataSubscription!.cancel();
      _continuousDataSubscription = null;
    }

    print('✅ All streams and subscriptions cleaned up');
  }
}
