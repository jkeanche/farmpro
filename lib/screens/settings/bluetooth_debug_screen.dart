import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bluetooth_classic/models/device.dart';
import '../../services/bluetooth_service.dart';

class BluetoothDebugScreen extends StatefulWidget {
  const BluetoothDebugScreen({super.key});

  @override
  State<BluetoothDebugScreen> createState() => _BluetoothDebugScreenState();
}

class _BluetoothDebugScreenState extends State<BluetoothDebugScreen> {
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();
  final List<String> _logs = [];
  bool _isRunningDiagnostic = false;
  
  @override
  void initState() {
    super.initState();
    _addLog('Bluetooth Debug Screen initialized');
  }
  
  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');
    });
    
    // Keep only the last 100 logs to avoid memory issues
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs cleared');
  }

  Future<void> _runFullDiagnostic() async {
    if (_isRunningDiagnostic) return;
    
    setState(() {
      _isRunningDiagnostic = true;
    });

    try {
      _addLog('=== Starting Bluetooth Diagnostic ===');
      
      // Check Bluetooth availability
      _addLog('Checking Bluetooth availability...');
      bool isEnabled = await _bluetoothService.isBluetoothEnabled();
      _addLog('Bluetooth enabled: $isEnabled');
      
      if (!isEnabled) {
        _addLog('Bluetooth is not enabled. Please enable it in system settings.');
      return;
    }
    
      // Get diagnostic results
      _addLog('Running comprehensive diagnostic...');
      final diagnosticResults = await _bluetoothService.runBluetoothDiagnostic();
      
      _addLog('Bluetooth state: ${diagnosticResults['bluetoothState']}');
      _addLog('Connected devices count: ${diagnosticResults['connectedDevices']['count']}');
      _addLog('Total discovered devices: ${diagnosticResults['appDeviceList']['count']}');
      
      // List errors
      final errors = diagnosticResults['errors'] as List;
      if (errors.isNotEmpty) {
        _addLog('=== ERRORS FOUND ===');
        for (String error in errors) {
          _addLog('ERROR: $error');
        }
      }
      
      // List recommendations
      final recommendations = diagnosticResults['recommendations'] as List;
      if (recommendations.isNotEmpty) {
        _addLog('=== RECOMMENDATIONS ===');
        for (String recommendation in recommendations) {
          _addLog('RECOMMENDATION: $recommendation');
        }
      }
      
      // List devices
      _addLog('=== DEVICE LIST ===');
      final devices = diagnosticResults['appDeviceList']['devices'] as List;
      if (devices.isEmpty) {
        _addLog('No devices found');
      } else {
        for (var device in devices) {
          _addLog('Device: ${device['name']} (${device['address']}) ${device['connected'] ? '[CONNECTED]' : ''}');
        }
      }
      
      _addLog('=== Diagnostic Complete ===');

    } catch (e) {
      _addLog('ERROR during diagnostic: $e');
    } finally {
      setState(() {
        _isRunningDiagnostic = false;
      });
    }
  }

  Future<void> _scanForDevices() async {
    try {
      _addLog('Starting device scan...');
      await _bluetoothService.startScan();
      _addLog('Device scan started successfully');
      
      // Stop scan after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _bluetoothService.stopScan();
        _addLog('Device scan stopped automatically after 30 seconds');
      });
    } catch (e) {
      _addLog('ERROR starting scan: $e');
    }
  }

  Future<void> _connectToDevice(Device device) async {
    try {
      _addLog('Attempting to connect to ${device.name} (${device.address})...');
      
      final connected = await _bluetoothService.connectToDevice(device);
      
      if (connected) {
        _addLog('✓ Successfully connected to ${device.name}');
      } else {
        _addLog('✗ Failed to connect to ${device.name}');
      }
    } catch (e) {
      _addLog('ERROR connecting to ${device.name}: $e');
    }
  }

  Future<void> _connectToDeviceByAddress(String address) async {
    try {
      _addLog('Attempting to connect to device with address: $address...');
      
      final connected = await _bluetoothService.connectToScaleByAddress(address);
      
      if (connected) {
        _addLog('✓ Successfully connected to device at $address');
      } else {
        _addLog('✗ Failed to connect to device at $address');
      }
    } catch (e) {
      _addLog('ERROR connecting to device at $address: $e');
    }
  }

  void _showDeviceInfo(Device device) {
    Get.dialog(
      AlertDialog(
        title: Text(device.name?.isNotEmpty == true ? device.name! : 'Unknown Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Address:', device.address),
            _buildInfoRow('Name:', device.name ?? 'N/A'),
            const SizedBox(height: 16),
            const Text(
              'Actions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      _connectToDevice(device);
                    },
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text('Connect as Scale'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Get.back();
                      try {
                        _addLog('Attempting to connect to ${device.name} as printer...');
                        final connected = await _bluetoothService.connectToPrinterByAddress(device.address);
                        if (connected) {
                          _addLog('✓ Successfully connected to ${device.name} as printer');
                        } else {
                          _addLog('✗ Failed to connect to ${device.name} as printer');
                        }
                      } catch (e) {
                        _addLog('ERROR connecting to ${device.name} as printer: $e');
                      }
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Connect as Printer'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return Obx(() {
      final devices = _bluetoothService.devices;
      final pairedDevices = _bluetoothService.pairedDevices;
      final connectedDevices = _bluetoothService.connectedDevices;
      final classicDeviceInfo = _bluetoothService.classicDeviceInfo;
      
      if (devices.isEmpty && pairedDevices.isEmpty && classicDeviceInfo.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('No devices found. Try scanning for devices.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _scanForDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Devices'),
                ),
              ],
            ),
          ),
        );
      }

      return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Connected Devices Section
            if (connectedDevices.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Connected Devices (${connectedDevices.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...connectedDevices.map((device) => ListTile(
                        leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
                        title: Text(device.name?.isNotEmpty == true ? device.name! : 'Unknown Device'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Address: ${device.address}'),
                            Text('Type: Classic Bluetooth', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Chip(
                              label: Text('Connected'),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showDeviceInfo(device),
                              tooltip: 'Device Info',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Classic Bluetooth Devices Section (from classicDeviceInfo)
            if (classicDeviceInfo.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classic Bluetooth Devices (${classicDeviceInfo.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                  const SizedBox(height: 8),
                      ...classicDeviceInfo.map((deviceInfo) {
                        final isConnected = connectedDevices.any((d) => d.address == deviceInfo['address']);
                        
                        return ListTile(
                          leading: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: isConnected ? Colors.green : Colors.blue,
                          ),
                          title: Text(deviceInfo['name'] ?? 'Unknown Device'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Address: ${deviceInfo['address']}'),
                              Text('Status: ${deviceInfo['pin']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          trailing: isConnected
                              ? const Chip(
                                  label: Text('Connected'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                                )
                              : ElevatedButton(
                                  onPressed: () => _connectToDeviceByAddress(deviceInfo['address']!),
                                  child: const Text('Connect'),
                                ),
                          isThreeLine: true,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Paired Devices Section
            if (pairedDevices.isNotEmpty) ...[
              Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paired Devices (${pairedDevices.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...pairedDevices.map((device) {
                        final isConnected = connectedDevices.any((d) => d.address == device.address);
                        
                        return ListTile(
                          leading: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: isConnected ? Colors.green : Colors.orange,
                          ),
                          title: Text(device.name?.isNotEmpty == true ? device.name! : 'Unknown Device'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Address: ${device.address}'),
                              Text('Type: Paired Device', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnected)
                                const Chip(
                                  label: Text('Connected'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () => _connectToDevice(device),
                                  child: const Text('Connect'),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () => _showDeviceInfo(device),
                                tooltip: 'Device Info',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Available/Discovered Devices Section (that aren't paired)
            if (devices.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Devices (${devices.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...devices.map((device) {
                        final isConnected = connectedDevices.any((d) => d.address == device.address);
                        final isPaired = pairedDevices.any((d) => d.address == device.address);
                            
                            return ListTile(
                          leading: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: isConnected ? Colors.green : Colors.purple,
                          ),
                          title: Text(device.name?.isNotEmpty == true ? device.name! : 'Unknown Device'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Address: ${device.address}'),
                              Text(
                                isPaired ? 'Type: Paired' : 'Type: Discovered', 
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])
                                    ),
                                ],
                              ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnected)
                                const Chip(
                                  label: Text('Connected'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                                )
                              else
                                ElevatedButton(
                                onPressed: () => _connectToDevice(device),
                                  child: const Text('Connect'),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () => _showDeviceInfo(device),
                                tooltip: 'Device Info',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      }),
                    ],
                        ),
                      ),
                ),
              ],
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanForDevices,
            tooltip: 'Scan for devices',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bluetooth Debug Tools',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: _isRunningDiagnostic
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.medical_services),
                        label: const Text('Run Diagnostic'),
                        onPressed: _isRunningDiagnostic ? null : _runFullDiagnostic,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Scan Devices'),
                        onPressed: _scanForDevices,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.info),
                        label: const Text('Pairing Help'),
                        onPressed: () => _bluetoothService.showClassicBluetoothPairingInstructions(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Devices List
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildDevicesList(),
            ),
          ),
          
          // Logs Panel
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Debug Logs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_logs.length} entries',
                          style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                  const Divider(height: 1),
                Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text('No logs yet. Run some commands to see debug output.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                              final log = _logs[index];
                              Color? textColor;
                              
                              if (log.contains('ERROR')) {
                                textColor = Colors.red;
                              } else if (log.contains('RECOMMENDATION')) {
                                textColor = Colors.orange;
                              } else if (log.contains('✓')) {
                                textColor = Colors.green;
                              } else if (log.contains('✗')) {
                                textColor = Colors.red;
                              }
                              
                      return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                                  log,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                        ),
                      );
                    },
                          ),
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 