import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import '../../services/sms_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/widgets.dart';
import 'package:intl/intl.dart';

class SmsTestScreen extends StatefulWidget {
  const SmsTestScreen({super.key});

  @override
  State<SmsTestScreen> createState() => _SmsTestScreenState();
}

class _SmsTestScreenState extends State<SmsTestScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  final SmsService _smsService = Get.find<SmsService>();
  final PermissionService _permissionService = Get.find<PermissionService>();

  Map<String, dynamic> _diagnosticResults = {};
  String _status = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messageController.text = 'This is a test message from Farm Fresh app.';
    _checkPermissions();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking permissions...';
    });

    final hasPermission = await _permissionService.checkSmsPermission();

    setState(() {
      _isLoading = false;
      _status =
          hasPermission
              ? 'SMS permission granted'
              : 'SMS permission NOT granted';
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting permissions...';
    });

    final granted = await _permissionService.requestSmsPermission();

    setState(() {
      _isLoading = false;
      _status =
          granted ? 'SMS permission granted' : 'Failed to get SMS permission';
    });
  }

  Future<void> _sendTestSms() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _status = 'Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Sending test SMS...';
    });

    try {
      // First validate the phone number
      final validatedNumber = _smsService.validateKenyanPhoneNumber(
        _phoneController.text,
      );
      if (validatedNumber == null) {
        setState(() {
          _isLoading = false;
          _status =
              'Invalid Kenyan phone number format. Phone: ${_phoneController.text} - Please check format (e.g., 0701234567, +254701234567)';
        });
        return;
      }

      // Send SMS immediately with robust retry logic
      final success = await _smsService.sendSmsRobust(
        validatedNumber,
        _messageController.text,
        maxRetries: 3,
        priority: 3, // High priority for test messages
      );

      setState(() {
        _isLoading = false;
        _status =
            success
                ? 'Test SMS sent successfully to $validatedNumber'
                : 'Test SMS failed to send to $validatedNumber\nCheck SMS statistics for details.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error sending SMS: $e';
      });
    }
  }

  Future<void> _runDiagnostic() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _status = 'Please enter a phone number for diagnostic';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Running comprehensive SMS diagnostic...';
      _diagnosticResults = {};
    });

    try {
      print('🔬 Starting comprehensive SMS diagnostic...');

      // **ENHANCED DIAGNOSTIC 1: System Environment Check**
      _diagnosticResults['platform'] = Platform.isAndroid ? 'Android' : 'Other';
      _diagnosticResults['timestamp'] = DateTime.now().toIso8601String();

      // **ENHANCED DIAGNOSTIC 2: Service Availability Check**
      try {
        final smsService = Get.find<SmsService>();
        _diagnosticResults['smsServiceFound'] = true;
        _diagnosticResults['smsServiceType'] =
            smsService.runtimeType.toString();
      } catch (e) {
        _diagnosticResults['smsServiceFound'] = false;
        _diagnosticResults['smsServiceError'] = e.toString();
      }

      // **ENHANCED DIAGNOSTIC 3: Permission Deep Check**
      _diagnosticResults['permissionServiceAvailable'] =
          true; // Service is directly available
      final hasPermission = await _permissionService.checkSmsPermission();
      _diagnosticResults['smsPermissionGranted'] = hasPermission;

      if (!hasPermission) {
        final requested = await _permissionService.requestSmsPermission();
        _diagnosticResults['permissionRequestResult'] = requested;
      }

      // **ENHANCED DIAGNOSTIC 4: Phone Number Validation**
      final validatedNumber = _smsService.validateKenyanPhoneNumber(
        _phoneController.text,
      );
      _diagnosticResults['phoneValidation'] = validatedNumber != null;
      _diagnosticResults['validatedPhone'] = validatedNumber ?? 'Invalid';

      // **ENHANCED DIAGNOSTIC 5: SMS Service Statistics**
      final stats = _smsService.getSmsStatistics();
      _diagnosticResults['smsStats'] = stats;

      // **ENHANCED DIAGNOSTIC 6: Lifecycle Simulation Test**
      setState(() {
        _status = 'Testing SMS under simulated lifecycle stress...';
      });

      if (validatedNumber != null &&
          _diagnosticResults['smsPermissionGranted'] == true) {
        // Simulate background processes that might interfere
        final testMessage =
            'LIFECYCLE TEST: Farm Pro SMS diagnostic at ${DateFormat('HH:mm:ss').format(DateTime.now())}';

        print('🧪 Starting lifecycle simulation test...');

        // Create multiple competing async operations to simulate real app conditions
        final futures = <Future>[];

        // Simulate weight monitoring interference
        futures.add(
          Future.delayed(const Duration(milliseconds: 100), () {
            print('🔄 Simulating weight monitoring...');
            return 'weight_simulation';
          }),
        );

        // Simulate bluetooth operations
        futures.add(
          Future.delayed(const Duration(milliseconds: 200), () {
            print('📡 Simulating bluetooth operations...');
            return 'bluetooth_simulation';
          }),
        );

        // Simulate printing preparation
        futures.add(
          Future.delayed(const Duration(milliseconds: 300), () {
            print('🖨️ Simulating printing operations...');
            return 'print_simulation';
          }),
        );

        // The actual SMS sending with high priority
        final smsResult = _smsService.sendSmsRobust(
          validatedNumber,
          testMessage,
          maxRetries: 3,
          priority: 3,
        );

        futures.add(smsResult);

        // Wait for all operations to complete
        final results = await Future.wait(futures);
        final smsSuccess = results.last as bool;

        _diagnosticResults['lifecycleTestResult'] = smsSuccess;
        _diagnosticResults['testMessage'] = testMessage;
        _diagnosticResults['simulatedInterferences'] = results.take(3).toList();

        print('🧪 Lifecycle simulation test completed: $smsSuccess');
      }

      // **ENHANCED DIAGNOSTIC 7: Background Service Health Check**
      setState(() {
        _status = 'Checking background service health...';
      });

      await Future.delayed(const Duration(seconds: 1));

      // Check if SMS service is still responsive after lifecycle test
      try {
        final healthCheck = await _smsService.testSmsSending().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
        _diagnosticResults['serviceHealthCheck'] = healthCheck;
      } catch (e) {
        _diagnosticResults['serviceHealthCheck'] = false;
        _diagnosticResults['healthCheckError'] = e.toString();
      }

      // **ENHANCED DIAGNOSTIC 8: Generate Comprehensive Report**
      final report = _generateDiagnosticReport();
      _diagnosticResults['comprehensiveReport'] = report;

      setState(() {
        _isLoading = false;
        _status =
            _diagnosticResults['lifecycleTestResult'] == true
                ? 'Diagnostic completed successfully - SMS should work reliably'
                : 'Diagnostic completed with issues - check report for details';
      });

      print('🔬 Comprehensive SMS diagnostic completed');
      print('📋 Report: $report');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Diagnostic failed: $e';
        _diagnosticResults['criticalError'] = e.toString();
      });
      print('❌ SMS diagnostic failed: $e');
    }
  }

  String _generateDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== SMS DIAGNOSTIC REPORT ===');
    buffer.writeln('Timestamp: ${_diagnosticResults['timestamp']}');
    buffer.writeln('Platform: ${_diagnosticResults['platform']}');
    buffer.writeln('');

    buffer.writeln('SERVICE STATUS:');
    buffer.writeln(
      '- SMS Service Found: ${_diagnosticResults['smsServiceFound']}',
    );
    buffer.writeln(
      '- Permission Service Available: ${_diagnosticResults['permissionServiceAvailable']}',
    );
    buffer.writeln(
      '- SMS Permission Granted: ${_diagnosticResults['smsPermissionGranted']}',
    );
    buffer.writeln('');

    buffer.writeln('PHONE VALIDATION:');
    buffer.writeln('- Input: ${_phoneController.text}');
    buffer.writeln('- Valid: ${_diagnosticResults['phoneValidation']}');
    buffer.writeln('- Formatted: ${_diagnosticResults['validatedPhone']}');
    buffer.writeln('');

    if (_diagnosticResults['smsStats'] != null) {
      final stats = _diagnosticResults['smsStats'] as Map<String, dynamic>;
      buffer.writeln('SMS STATISTICS:');
      buffer.writeln('- Total Sent: ${stats['totalSent']}');
      buffer.writeln('- Total Failed: ${stats['totalFailed']}');
      buffer.writeln('- Success Rate: ${stats['successRate']}%');
      buffer.writeln('- Queue Size: ${stats['queueSize']}');
      buffer.writeln('');
    }

    buffer.writeln('LIFECYCLE TEST:');
    buffer.writeln(
      '- Test Result: ${_diagnosticResults['lifecycleTestResult']}',
    );
    buffer.writeln(
      '- Service Health: ${_diagnosticResults['serviceHealthCheck']}',
    );
    buffer.writeln('');

    if (_diagnosticResults['criticalError'] != null) {
      buffer.writeln('CRITICAL ERROR:');
      buffer.writeln('- ${_diagnosticResults['criticalError']}');
    }

    buffer.writeln('=== END REPORT ===');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'SMS Test'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter phone number (e.g., +254712345678)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16.0),
            CustomTextField(
              controller: _messageController,
              label: 'Message',
              hint: 'Enter test message',
              maxLines: 3,
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Request Permission',
                    onPressed: _requestPermissions,
                    buttonType: ButtonType.outline,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: CustomButton(
                    text: 'Test SMS',
                    onPressed: _sendTestSms,
                    buttonType: ButtonType.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            CustomButton(
              text: 'Run Diagnostic',
              onPressed: _runDiagnostic,
              buttonType: ButtonType.secondary,
            ),

            const SizedBox(height: 24.0),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.grey.shade100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8.0),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Text(_status),
                ],
              ),
            ),
            if (_diagnosticResults.isNotEmpty) ...[
              const SizedBox(height: 16.0),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                    color: Colors.grey.shade50,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnostic Results:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8.0),
                        ..._diagnosticResults.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  TextSpan(
                                    text: '${entry.key}: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: '${entry.value}'),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
