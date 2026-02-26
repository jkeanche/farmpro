import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/sms_service.dart';
import '../../widgets/custom_app_bar.dart';

class SmsManagementScreen extends StatefulWidget {
  const SmsManagementScreen({super.key});

  @override
  State<SmsManagementScreen> createState() => _SmsManagementScreenState();
}

class _SmsManagementScreenState extends State<SmsManagementScreen> {
  final SmsService _smsService = Get.find<SmsService>();
  final TextEditingController _testPhoneController = TextEditingController();
  bool _isRunningDiagnostic = false;
  Map<String, dynamic>? _diagnosticResults;

  @override
  void dispose() {
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostic() async {
    if (_testPhoneController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a phone number for testing',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isRunningDiagnostic = true;
      _diagnosticResults = null;
    });

    try {
      final results = await _smsService.runSmsDiagnostic(
        _testPhoneController.text.trim(),
      );
      setState(() {
        _diagnosticResults = results;
      });
    } catch (e) {
      Get.snackbar(
        'Diagnostic Error',
        'Failed to run diagnostic: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isRunningDiagnostic = false;
      });
    }
  }

  void _clearQueue() {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear SMS Queue'),
        content: const Text(
          'Are you sure you want to clear any remaining queued SMS messages?\n\n'
          'Note: SMS are now sent immediately, but this will clear any legacy queue items.\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _smsService.clearSmsQueue();
              Get.back();
              Get.snackbar(
                'Queue Cleared',
                'Any remaining queue items have been cleared',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
              setState(() {}); // Refresh the UI
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Queue'),
          ),
        ],
      ),
    );
  }

  void _resetStatistics() {
    Get.dialog(
      AlertDialog(
        title: const Text('Reset Statistics'),
        content: const Text('Are you sure you want to reset SMS statistics?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _smsService.resetSmsStatistics();
              Get.back();
              Get.snackbar(
                'Statistics Reset',
                'SMS statistics have been reset',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
              setState(() {}); // Refresh the UI
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool status) {
    return status ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'SMS Management'),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Refresh the statistics
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SMS Statistics Card
              _buildStatisticsCard(),
              const SizedBox(height: 16.0),

              // SMS Status Card
              _buildStatusCard(),
              const SizedBox(height: 16.0),

              // SMS Test Card
              _buildTestCard(),
              const SizedBox(height: 16.0),

              // Diagnostic Results
              if (_diagnosticResults != null) _buildDiagnosticResults(),

              // Management Actions
              _buildManagementActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Obx(() {
      final stats = _smsService.getSmsStatistics();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: Colors.blue),
                  const SizedBox(width: 8.0),
                  Text(
                    'SMS Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Sent',
                      '${stats['totalSent']}',
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Total Failed',
                      '${stats['totalFailed']}',
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Queue Size (Legacy)',
                      '${stats['queueSize']}',
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Success Rate',
                      '${stats['successRate']}%',
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4.0),
                  Text(
                    'Processing: ${stats['isProcessing'] ? 'Active' : 'Idle'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Obx(() {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.green),
                  const SizedBox(width: 8.0),
                  Text(
                    'SMS Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              _buildStatusRow(
                'SMS Available',
                _smsService.isSmsAvailable.value,
              ),
              const SizedBox(height: 8.0),
              _buildStatusRow(
                'Legacy Queue Processing',
                _smsService.getSmsStatistics()['isProcessing'],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: _getStatusColor(status)),
          ),
          child: Text(
            status ? 'Active' : 'Inactive',
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.purple),
                const SizedBox(width: 8.0),
                Text(
                  'SMS Test & Diagnostic',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              'Test SMS gateway connectivity and fallback functionality',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _testPhoneController,
              decoration: const InputDecoration(
                labelText: 'Test Phone Number',
                hintText: 'Enter Kenyan phone number (e.g., 0712345678)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunningDiagnostic ? null : _runDiagnostic,
                icon:
                    _isRunningDiagnostic
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.play_arrow),
                label: Text(
                  _isRunningDiagnostic
                      ? 'Running Gateway Test...'
                      : 'Run Gateway Test',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticResults() {
    if (_diagnosticResults == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.indigo),
                const SizedBox(width: 8.0),
                Text(
                  'Diagnostic Results',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ..._diagnosticResults!.entries.map((entry) {
              if (entry.key == 'error' && entry.value.toString().isEmpty) {
                return const SizedBox.shrink();
              }

              Color color = Colors.grey;
              if (entry.key == 'permissions' ||
                  entry.key == 'phoneValidation' ||
                  entry.key == 'sendSuccess') {
                color = entry.value == true ? Colors.green : Colors.red;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${entry.key}:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(color: color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.orange),
                const SizedBox(width: 8.0),
                Text(
                  'Management Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearQueue,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Queue'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetStatistics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Stats'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
