import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/bluetooth_service.dart';
import '../services/gap_scale_service.dart';

class WeightMonitoringWidget extends StatefulWidget {
  final Function(double)? onWeightUpdate;
  final bool isActive;
  final double tareWeight;

  const WeightMonitoringWidget({
    super.key,
    this.onWeightUpdate,
    this.isActive = false,
    this.tareWeight = 0.0,
  });

  @override
  State<WeightMonitoringWidget> createState() => _WeightMonitoringWidgetState();
}

class _WeightMonitoringWidgetState extends State<WeightMonitoringWidget>
    with TickerProviderStateMixin {
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();
  final GapScaleService _gapScaleService = Get.find<GapScaleService>();

  late AnimationController _pulseController;
  late AnimationController _chartController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _chartAnimation;

  // Weight monitoring data
  final List<double> _weightReadings = [];
  double _currentWeight = 0.0;
  double _netWeight = 0.0;
  double _minWeight = 0.0;
  double _maxWeight = 0.0;
  double _averageWeight = 0.0;

  Timer? _weightTimer;
  bool _isMonitoring = false;
  StreamSubscription<double>? _weightStreamSubscription;
  Worker? _gapWeightWorker;

  // Connection status
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  int _dataReceived = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _chartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _chartController, curve: Curves.easeOut));

    _startMonitoring();
  }

  @override
  void dispose() {
    _stopMonitoring();
    _gapWeightWorker?.dispose();
    _pulseController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WeightMonitoringWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      print('WeightMonitoringWidget: isActive changed to ${widget.isActive}');
      if (widget.isActive) {
        print('WeightMonitoringWidget: Resuming monitoring...');
        _startMonitoring();
        // Immediately check connection and start streams if connected
        _checkConnectionAndStartStream();
      } else {
        print('WeightMonitoringWidget: Pausing monitoring...');
        _stopWeightStream(); // Only stop streams, keep monitoring setup
      }
    }
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _pulseController.repeat(reverse: true);

    // Monitor connection status using reactive observers
    ever(_bluetoothService.isScaleConnected, (connected) {
      setState(() {
        _isConnected = connected;
        _connectionStatus = connected ? 'Connected' : 'Disconnected';

        // Start or stop stream based on connection status
        if (connected && widget.isActive) {
          _startWeightStream();
        } else {
          _stopWeightStream();
        }
      });
    });

    ever(_gapScaleService.isConnected, (connected) {
      setState(() {
        _isConnected = connected || _bluetoothService.isScaleConnected.value;
        if (connected) _connectionStatus = 'GAP Scale Connected';

        // Handle GAP scale weight updates
        if (connected && widget.isActive) {
          _startGapScaleMonitoring();
        } else if (!_bluetoothService.isScaleConnected.value) {
          _stopWeightStream();
        }
      });
    });

    // If already connected and active, start monitoring
    if (widget.isActive) {
      _checkConnectionAndStartStream();
    }
  }

  void _stopMonitoring() {
    _isMonitoring = false;
    _weightTimer?.cancel();
    _stopWeightStream();
    _pulseController.stop();
  }

  void _checkConnectionAndStartStream() {
    bool isBluetoothConnected = _bluetoothService.isScaleConnected.value;
    bool isGapConnected = _gapScaleService.isConnected.value;

    print(
      'WeightMonitoringWidget: Checking connections - Bluetooth: $isBluetoothConnected, GAP: $isGapConnected, isActive: ${widget.isActive}',
    );

    setState(() {
      _isConnected = isBluetoothConnected || isGapConnected;
      if (isGapConnected) {
        _connectionStatus = 'GAP Scale Connected';
      } else if (isBluetoothConnected) {
        _connectionStatus = 'Bluetooth Connected';
      } else {
        _connectionStatus = 'Disconnected';
      }
    });

    if (_isConnected && widget.isActive) {
      print('WeightMonitoringWidget: Starting data streams...');
      if (isGapConnected) {
        _startGapScaleMonitoring();
      } else if (isBluetoothConnected) {
        _startWeightStream();
      }
    } else {
      print(
        'WeightMonitoringWidget: Not starting streams - Connected: $_isConnected, Active: ${widget.isActive}',
      );
    }
  }

  void _startWeightStream() {
    if (_bluetoothService.isScaleConnected.value && widget.isActive) {
      print(
        'WeightMonitoringWidget: Starting continuous weight stream monitoring...',
      );
      _stopWeightStream(); // Stop any existing stream

      try {
        print('WeightMonitoringWidget: Creating new stream subscription...');
        _weightStreamSubscription = _bluetoothService
            .getContinuousWeightStream()
            .listen(
              (double weight) {
                print(
                  'WeightMonitoringWidget: 🎯 RECEIVED weight data: $weight kg (isActive: ${widget.isActive})',
                );
                if (widget.isActive) {
                  print(
                    'WeightMonitoringWidget: ✅ Processing weight: $weight kg',
                  );
                  _updateWeight(weight);
                } else {
                  print(
                    'WeightMonitoringWidget: ⏸️ Ignoring weight - widget not active',
                  );
                }
              },
              onError: (error) {
                print('WeightMonitoringWidget: ❌ Weight stream error: $error');
              },
              onDone: () {
                print('WeightMonitoringWidget: ✅ Weight stream completed');
              },
            );
        print(
          'WeightMonitoringWidget: ✅ Weight stream subscription created successfully',
        );
      } catch (e) {
        print('WeightMonitoringWidget: ❌ Error starting weight stream: $e');
      }
    } else {
      print(
        'WeightMonitoringWidget: ❌ Cannot start weight stream - Connected: ${_bluetoothService.isScaleConnected.value}, Active: ${widget.isActive}',
      );
    }
  }

  void _startGapScaleMonitoring() {
    if (_gapScaleService.isConnected.value && widget.isActive) {
      print('WeightMonitoringWidget: Starting GAP scale weight monitoring...');
      _stopWeightStream(); // Stop any existing stream

      // Dispose any existing worker
      _gapWeightWorker?.dispose();

      // Monitor GAP scale weight changes using a worker
      _gapWeightWorker = ever(_gapScaleService.currentWeight, (weight) {
        if (widget.isActive && _gapScaleService.isConnected.value) {
          print(
            'WeightMonitoringWidget: GAP scale weight update: $weight kg (isActive: ${widget.isActive})',
          );
          _updateWeight(weight);
        }
      });
      print(
        'WeightMonitoringWidget: GAP scale monitoring worker created successfully',
      );
    } else {
      print(
        'WeightMonitoringWidget: Cannot start GAP scale monitoring - Connected: ${_gapScaleService.isConnected.value}, Active: ${widget.isActive}',
      );
    }
  }

  void _stopWeightStream() {
    print('WeightMonitoringWidget: 🛑 Stopping weight streams...');
    if (_weightStreamSubscription != null) {
      print('WeightMonitoringWidget: 🗑️ Canceling weight stream subscription');
      _weightStreamSubscription?.cancel();
      _weightStreamSubscription = null;
    }
    if (_gapWeightWorker != null) {
      print('WeightMonitoringWidget: 🗑️ Disposing GAP weight worker');
      _gapWeightWorker?.dispose();
      _gapWeightWorker = null;
    }
    print('WeightMonitoringWidget: ✅ Weight streams stopped');
  }

  void _updateWeight(double weight) {
    print(
      'WeightMonitoringWidget: 🔄 _updateWeight called with $weight kg (isActive: ${widget.isActive}, weight > 0: ${weight > 0})',
    );

    if (!widget.isActive) {
      print(
        'WeightMonitoringWidget: ⏸️ Rejecting weight update - widget not active',
      );
      return;
    }

    if (weight < 0) {
      print(
        'WeightMonitoringWidget: ⚠️ Rejecting weight update - invalid weight: $weight',
      );
      return;
    }

    print('WeightMonitoringWidget: ✅ Processing weight update: $weight kg');

    setState(() {
      _currentWeight = weight;
      _netWeight = _currentWeight - widget.tareWeight;
      _dataReceived++;

      // Add to readings list (keep last 20 readings for chart)
      _weightReadings.add(_currentWeight);
      if (_weightReadings.length > 20) {
        _weightReadings.removeAt(0);
      }

      // Calculate statistics
      _calculateStatistics();
    });

    print(
      'WeightMonitoringWidget: 📊 UI updated - Current: ${_currentWeight.toStringAsFixed(2)} kg, Net: ${_netWeight.toStringAsFixed(2)} kg, Data count: $_dataReceived',
    );

    // Trigger chart animation
    _chartController.forward().then((_) {
      _chartController.reverse();
    });

    // Notify parent widget
    widget.onWeightUpdate?.call(_currentWeight);
    print(
      'WeightMonitoringWidget: 📤 Notified parent widget with weight: $_currentWeight kg',
    );
  }

  void _calculateStatistics() {
    if (_weightReadings.isEmpty) return;

    _minWeight = _weightReadings.reduce((a, b) => a < b ? a : b);
    _maxWeight = _weightReadings.reduce((a, b) => a > b ? a : b);
    _averageWeight =
        _weightReadings.reduce((a, b) => a + b) / _weightReadings.length;
  }

  void _clearData() {
    setState(() {
      _weightReadings.clear();
      _currentWeight = 0.0;
      _netWeight = 0.0;
      _minWeight = 0.0;
      _maxWeight = 0.0;
      _averageWeight = 0.0;
      _dataReceived = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with connection status
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isConnected
                                ? Colors.green.withOpacity(
                                  _pulseAnimation.value,
                                )
                                : Colors.red,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Weight Monitor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Current weight display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Weight',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currentWeight.toStringAsFixed(2)} kg',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  if (_netWeight > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Net: ${_netWeight.toStringAsFixed(2)} kg',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Weight trend chart
            if (_weightReadings.isNotEmpty) ...[
              Text(
                'Weight Trend',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 80,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WeightChartPainter(
                        readings: _weightReadings,
                        animation: _chartAnimation.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Statistics row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Min',
                    '${_minWeight.toStringAsFixed(2)} kg',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Max',
                    '${_maxWeight.toStringAsFixed(2)} kg',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Avg',
                    '${_averageWeight.toStringAsFixed(2)} kg',
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data received counter and controls
            Row(
              children: [
                Icon(Icons.data_usage, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Data: $_dataReceived readings',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearData,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class WeightChartPainter extends CustomPainter {
  final List<double> readings;
  final double animation;

  WeightChartPainter({required this.readings, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final fillPaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final maxWeight = readings.reduce((a, b) => a > b ? a : b);
    final minWeight = readings.reduce((a, b) => a < b ? a : b);
    final range = maxWeight - minWeight;

    if (range == 0) return;

    final stepX = size.width / (readings.length - 1);

    for (int i = 0; i < readings.length; i++) {
      final x = i * stepX;
      final normalizedWeight = (readings[i] - minWeight) / range;
      final y = size.height - (normalizedWeight * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Apply animation
    final animatedPath = Path();
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extractedPath = metric.extractPath(0, metric.length * animation);
      animatedPath.addPath(extractedPath, Offset.zero);
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(animatedPath, paint);

    // Draw points
    final pointPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

    for (int i = 0; i < readings.length; i++) {
      if (i / readings.length <= animation) {
        final x = i * stepX;
        final normalizedWeight = (readings[i] - minWeight) / range;
        final y = size.height - (normalizedWeight * size.height);
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(WeightChartPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.animation != animation;
  }
}
