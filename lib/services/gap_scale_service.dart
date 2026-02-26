import 'dart:async';
import 'package:get/get.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'bluetooth_service.dart';

/// Service for managing GAP Digital Scale connection and weight readings
/// This service now works with classic Bluetooth instead of BLE
class GapScaleService extends GetxService {
  static GapScaleService get to => Get.find();
  
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();
  
  // Observable states
  final RxBool isConnected = false.obs;
  final RxDouble currentWeight = 0.0.obs;
  
  Device? connectedDevice;
  StreamSubscription<double>? _weightSubscription;
  Timer? _weightPollingTimer;
  
  @override
  void onInit() {
    super.onInit();
    print('GAP Scale Service initialized for Classic Bluetooth');
  }
  
  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
  
  /// Connect to a GAP Digital Scale using classic Bluetooth
  Future<bool> connectToScale(Device device) async {
    try {
      print('Connecting to GAP Digital Scale via Classic Bluetooth: ${device.name} (${device.address})');
      
      // Use the Bluetooth service to connect
      if (!await _bluetoothService.connectToDevice(device)) {
        print('Failed to connect to device');
        return false;
      }
      
      connectedDevice = device;
      isConnected.value = true;
      
      // Start continuous weight monitoring
      _startContinuousWeightMonitoring();
      
      print('Successfully connected to GAP Digital Scale');
      return true;
      
    } catch (e) {
      print('Error connecting to GAP Digital Scale: $e');
      isConnected.value = false;
      return false;
    }
  }
  
  /// Start continuous weight monitoring
  void _startContinuousWeightMonitoring() {
    // Stop any existing monitoring
    _stopContinuousWeightMonitoring();
    
    // Try to use Bluetooth service stream first
    try {
      if (_bluetoothService.isScaleConnected.value) {
        _weightSubscription = _bluetoothService.getContinuousWeightStream().listen(
          (double weight) {
            currentWeight.value = weight;
            print('GAP Service received weight: ${weight.toStringAsFixed(2)} kg');
          },
          onError: (error) {
            print('GAP Service weight stream error: $error');
            // Fallback to polling if stream fails
            _startWeightPolling();
          },
        );
        print('GAP Service: Started weight stream monitoring');
        return;
      }
    } catch (e) {
      print('GAP Service: Failed to start weight stream, using polling: $e');
    }
    
    // Fallback to polling method
    _startWeightPolling();
  }
  
  /// Start weight polling as fallback
  void _startWeightPolling() {
    _weightPollingTimer?.cancel();
    _weightPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (isConnected.value) {
        try {
          double? weight = await _bluetoothService.readWeightFromScale();
          if (weight != null && weight >= 0) {
            currentWeight.value = weight;
          }
        } catch (e) {
          print('GAP Service polling error: $e');
        }
      } else {
        timer.cancel();
      }
    });
    print('GAP Service: Started weight polling');
  }
  
  /// Stop continuous weight monitoring
  void _stopContinuousWeightMonitoring() {
    _weightSubscription?.cancel();
    _weightSubscription = null;
    _weightPollingTimer?.cancel();
    _weightPollingTimer = null;
    print('GAP Service: Stopped weight monitoring');
  }
  
  /// Disconnect from the scale
  Future<void> disconnect() async {
    try {
      // Stop weight monitoring first
      _stopContinuousWeightMonitoring();
      
      if (connectedDevice != null) {
        await _bluetoothService.disconnectScale();
        connectedDevice = null;
        isConnected.value = false;
        currentWeight.value = 0.0;
        print('Disconnected from GAP Digital Scale');
      }
    } catch (e) {
      print('Error disconnecting from GAP Digital Scale: $e');
    }
  }
  
  /// Get stable weight reading from the scale
  Future<double?> getStableWeight({Duration timeout = const Duration(seconds: 10)}) async {
    if (!isConnected.value) {
      throw Exception('Scale not connected');
    }
    
    try {
      print('Requesting stable weight from GAP Digital Scale...');
      
      // Use the Bluetooth service to read weight
      double? weight = await _bluetoothService.getWeightFromScale();
      
      if (weight != null) {
        currentWeight.value = weight;
        print('Received stable weight: ${weight.toStringAsFixed(2)} kg');
        return weight;
      } else {
        print('No weight data received from scale');
        return null;
      }
      
    } catch (e) {
      print('Error getting stable weight: $e');
      return null;
    }
  }
  
  /// Read current weight (non-blocking)
  Future<double?> readCurrentWeight() async {
    return await getStableWeight(timeout: const Duration(seconds: 5));
  }
  
  /// Connect to scale by address
  Future<bool> connectToScaleByAddress(String address) async {
    try {
      Device? device = await _bluetoothService.findDeviceByAddress(address);
      if (device != null) {
        return await connectToScale(device);
      } else {
        print('Device not found with address: $address');
        return false;
      }
    } catch (e) {
      print('Error connecting to scale by address: $e');
      return false;
    }
  }
  
  /// Check if a specific device address matches the connected scale
  bool isDeviceConnected(String address) {
    return isConnected.value && 
           connectedDevice != null && 
           connectedDevice!.address.toUpperCase() == address.toUpperCase();
  }
  
  /// Auto-connect to scale if previously connected
  Future<void> autoConnectToScale(String? scaleAddress) async {
    if (scaleAddress != null && scaleAddress.isNotEmpty) {
      try {
        print('Auto-connecting to scale: $scaleAddress');
        await connectToScaleByAddress(scaleAddress);
      } catch (e) {
        print('Auto-connect failed: $e');
      }
    }
  }
} 