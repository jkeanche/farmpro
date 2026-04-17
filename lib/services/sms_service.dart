import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'coffee_collection_service.dart';
import 'inventory_service.dart';
import 'member_service.dart';
import 'permission_service.dart';
import 'settings_service.dart';

class SmsService extends GetxService {
  SettingsService get _settingsService => Get.find<SettingsService>();
  static SmsService get to => Get.find();

  PermissionService? _permissionService;
  final FlutterBackgroundMessenger messenger = FlutterBackgroundMessenger();
  final RxBool isSmsAvailable = false.obs;

  // SMS statistics
  final RxInt totalSmsSent = 0.obs;
  final RxInt totalSmsFailed = 0.obs;
  final RxInt smsQueueSize = 0.obs;

  // Legacy queue (kept for compatibility)
  final List<SmsQueueItem> _smsQueue = [];
  Timer? _queueProcessor;
  bool _isProcessingQueue = false;

  // ── Current mode (reactive so UI can observe) ──────────────────────────────
  final RxString currentSmsMode = 'sim'.obs;

  Future<SmsService> init() async {
    print('📱 [SMS] Initializing SMS Service...');

    try {
      _permissionService = Get.find<PermissionService>();
    } catch (e) {
      print('⚠️  [SMS] PermissionService not found: $e');
    }

    // ── Read persisted SMS mode from settings ──────────────────────────────
    final settings = _settingsService.systemSettings.value;
    currentSmsMode.value = _resolveMode(settings);
    print('📱 [SMS] Loaded SMS mode from settings: ${currentSmsMode.value}');

    // ── Request SIM permissions if mode is SIM ─────────────────────────────
    if (currentSmsMode.value == 'sim') {
      await _initSimPermissions();
    }

    // ── React to future settings changes (immediate propagation) ───────────
    ever(_settingsService.systemSettings, _onSettingsChanged);

    _startQueueProcessor();
    _startHealthMonitor();

    print('✅ [SMS] SMS Service ready (mode: ${currentSmsMode.value})');
    return this;
  }

  // ── Settings change handler ────────────────────────────────────────────────
  void _onSettingsChanged(SystemSettings settings) {
    final newMode = _resolveMode(settings);
    if (newMode != currentSmsMode.value) {
      print('🔄 [SMS] Mode changed: ${currentSmsMode.value} → $newMode');
      currentSmsMode.value = newMode;

      if (newMode == 'sim') {
        // Re-init SIM permissions when switching to SIM
        _initSimPermissions();
      }
    }
  }

  /// Determine effective SMS mode. Gateway mode requires credentials.
  String _resolveMode(SystemSettings settings) {
    final raw = (settings.smsMode).toLowerCase().trim();
    if (raw == 'gateway') {
      // Validate gateway is actually usable
      if (settings.isGatewayConfigured) return 'gateway';
      // Fall back to SIM if gateway is selected but not configured
      print(
        '⚠️  [SMS] Gateway selected but not configured — falling back to SIM mode',
      );
      return 'sim';
    }
    return 'sim';
  }

  // ── SIM permission initialisation ─────────────────────────────────────────
  Future<void> _initSimPermissions() async {
    if (!Platform.isAndroid) {
      isSmsAvailable.value = false;
      return;
    }
    try {
      bool granted = false;
      if (_permissionService != null) {
        granted = await _permissionService!.checkSmsPermission();
        if (!granted) {
          granted = await _permissionService!.requestSmsPermission();
        }
      }
      isSmsAvailable.value = granted;
      print(
        '📱 [SMS] SIM permission status: ${granted ? "GRANTED" : "DENIED"}',
      );
    } catch (e) {
      print('❌ [SMS] Error initialising SIM permissions: $e');
    }
  }

  @override
  void onClose() {
    _queueProcessor?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHONE VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  String? validateKenyanPhoneNumber(String phoneNumber) {
    try {
      String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\.\,]'), '');
      String processedNumber = '';

      if (cleaned.startsWith('+254')) {
        processedNumber = cleaned.substring(4);
      } else if (cleaned.startsWith('254')) {
        processedNumber = cleaned.substring(3);
      } else if (cleaned.startsWith('0')) {
        processedNumber = cleaned.substring(1);
      } else if (cleaned.length == 9 && cleaned.startsWith(RegExp(r'[17]'))) {
        processedNumber = cleaned;
      } else {
        return null;
      }

      if (processedNumber.length != 9) return null;
      if (!RegExp(r'^\d+$').hasMatch(processedNumber)) return null;

      // Valid Kenyan mobile prefixes
      final validPrefixes = [
        '70', '71', '72', '73', '74', '75', '76', '77', '78', '79',
        '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
        '20', // Nairobi landline (optional)
      ];

      final prefix = processedNumber.substring(0, 2);
      if (validPrefixes.any((p) => prefix.startsWith(p[0]) || prefix == p)) {
        return '+254$processedNumber';
      }

      // Accept any 9-digit number starting with valid Kenyan digits
      if (RegExp(r'^[0-9]{9}$').hasMatch(processedNumber)) {
        return '+254$processedNumber';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN SEND ENTRY POINT
  // Always use this — it reads the current mode and routes accordingly.
  // ─────────────────────────────────────────────────────────────────────────

  /// Send SMS using the currently configured mode.
  /// Returns true on success, false on failure.
  Future<bool> sendSms(String phoneNumber, String message) async {
    final validated = validateKenyanPhoneNumber(phoneNumber);
    if (validated == null) {
      print('❌ [SMS] Invalid phone number: $phoneNumber');
      return false;
    }

    // Re-read live settings so we always use the latest mode
    final settings = _settingsService.systemSettings.value;
    final mode = _resolveMode(settings);

    print('📱 [SMS] Sending to $validated — mode: $mode');

    if (mode == 'gateway') {
      return await _sendGateway(validated, message, settings);
    } else {
      return await _sendSim(validated, message);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GATEWAY SEND
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _sendGateway(
    String phone,
    String message,
    SystemSettings settings,
  ) async {
    if (!settings.isGatewayConfigured) {
      _showGatewayNotConfiguredError();
      return false;
    }

    print('📡 [SMS] Attempting gateway send to $phone');

    try {
      final success = await sendSmsViaGateway(phone, message);
      if (success) {
        print('✅ [SMS] Gateway send succeeded');
        return true;
      }

      // Fallback to SIM if enabled
      if (settings.smsGatewayFallbackToSim) {
        print('📱 [SMS] Gateway failed — trying SIM fallback');
        return await _sendSim(phone, message);
      }

      print('❌ [SMS] Gateway failed, no fallback configured');
      return false;
    } catch (e) {
      print('❌ [SMS] Gateway exception: $e');
      if (settings.smsGatewayFallbackToSim) {
        return await _sendSim(phone, message);
      }
      return false;
    }
  }

  void _showGatewayNotConfiguredError() {
    Get.snackbar(
      'SMS Gateway Not Configured',
      'Gateway mode is selected but credentials are incomplete.\n'
          'Go to Settings → System Settings → SMS Configuration to add credentials,\n'
          'or switch to SIM Card mode.',
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      icon: const Icon(Icons.sms_failed, color: Colors.white),
    );
  }

  Future<bool> sendSmsViaGateway(String phoneNumber, String message) async {
    try {
      final settings = _settingsService.systemSettings.value;
      if (!settings.isGatewayConfigured) return false;

      // Strip leading + for Zettatel
      final formattedPhone =
          phoneNumber.startsWith('+') ? phoneNumber.substring(1) : phoneNumber;

      final formData = {
        'userid': settings.smsGatewayUsername,
        'password': settings.smsGatewayPassword,
        'sendMethod': 'quick',
        'mobile': formattedPhone,
        'msg': message,
        'senderid': settings.smsGatewaySenderId,
        'msgType': 'text',
        'duplicatecheck': 'true',
        'output': 'json',
      };

      final body = formData.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final response = await http
          .post(
            Uri.parse(settings.smsGatewayUrl),
            headers: {
              'apikey': settings.smsGatewayApiKey,
              'cache-control': 'no-cache',
              'content-type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      print(
        '📋 [SMS] Gateway response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final status =
                (data['status'] ?? data['Status'] ?? '')
                    .toString()
                    .toLowerCase();
            if (status == 'success' ||
                data.containsKey('MessageId') ||
                data.containsKey('messageid')) {
              return true;
            }
            // Show gateway error details to the user
            final errorMsg =
                data['reason'] ??
                data['message'] ??
                data['error'] ??
                response.body;
            Get.snackbar(
              'Gateway Error',
              'SMS gateway returned: $errorMsg',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
            return false;
          }
        } catch (_) {
          final body = response.body.toLowerCase();
          return body.contains('success') || body.contains('sent');
        }
      }

      Get.snackbar(
        'Gateway HTTP Error',
        'SMS gateway returned HTTP ${response.statusCode}. Check your gateway URL.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      print('❌ [SMS] Gateway exception: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIM SEND
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _sendSim(String phone, String message) async {
    if (!Platform.isAndroid) {
      print('⚠️  [SMS] SIM send only supported on Android');
      return false;
    }

    // Ensure permissions are granted
    if (!isSmsAvailable.value) {
      await _initSimPermissions();
    }

    if (!isSmsAvailable.value) {
      print('❌ [SMS] SIM send failed — permissions not granted');
      Get.snackbar(
        'SMS Permission Required',
        'SMS sending requires permission to send messages. '
            'Please grant SMS permission in app settings.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    print('📱 [SMS] SIM sending to $phone');

    try {
      final success = await messenger
          .sendSMS(phoneNumber: phone, message: message)
          .timeout(const Duration(seconds: 45), onTimeout: () => false);

      if (success) {
        print('✅ [SMS] SIM send succeeded to $phone');
        totalSmsSent.value++;
      } else {
        print('❌ [SMS] SIM send failed to $phone');
        totalSmsFailed.value++;
      }
      return success;
    } catch (e) {
      print('❌ [SMS] SIM send exception: $e');
      totalSmsFailed.value++;
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROBUST SEND (with retries) — used by controllers
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> sendSmsRobust(
    String phoneNumber,
    String message, {
    int maxRetries = 3,
    int priority = 1,
  }) async {
    final validated = validateKenyanPhoneNumber(phoneNumber);
    if (validated == null) {
      print('❌ [SMS-ROBUST] Invalid phone: $phoneNumber');
      return false;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('📤 [SMS-ROBUST] Attempt $attempt/$maxRetries → $validated');
      try {
        final success = await sendSms(
          validated,
          message,
        ).timeout(const Duration(seconds: 60), onTimeout: () => false);

        if (success) {
          print('✅ [SMS-ROBUST] Sent on attempt $attempt');
          return true;
        }

        if (attempt < maxRetries) {
          final delay = attempt * 2;
          print('⏳ [SMS-ROBUST] Retrying in ${delay}s...');
          await Future.delayed(Duration(seconds: delay));
        }
      } catch (e) {
        print('❌ [SMS-ROBUST] Attempt $attempt exception: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }
    }

    print('❌ [SMS-ROBUST] All $maxRetries attempts failed for $validated');
    totalSmsFailed.value++;
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOMAIN-SPECIFIC HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> sendCoffeeCollectionSMS(CoffeeCollection collection) async {
    print(
      '🔄 [COFFEE-SMS] Sending for ${collection.memberName} (${collection.receiptNumber})',
    );

    final memberService = Get.find<MemberService>();
    final member = await memberService.getMemberById(collection.memberId);

    if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
      print('❌ [COFFEE-SMS] No phone for ${collection.memberName}');
      return false;
    }

    final validated = validateKenyanPhoneNumber(member.phoneNumber!);
    if (validated == null) {
      print('❌ [COFFEE-SMS] Invalid phone: ${member.phoneNumber}');
      Get.snackbar(
        'SMS Warning',
        'Invalid phone number for ${collection.memberName}. Please update.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // Build message
    final settingsService = Get.find<SettingsService>();
    final org = settingsService.organizationSettings.value;

    final coffeeService = Get.find<CoffeeCollectionService>();
    final summary = await coffeeService.getMemberSeasonSummary(
      collection.memberId,
    );
    final cumulative = _parseDouble(summary['allTimeWeight']);

    final msg = '''${org.societyName.toUpperCase()}
Fac:${org.factory}
T/No:${collection.receiptNumber ?? 'N/A'}
Date:${DateFormat('dd/MM/yy').format(collection.collectionDate)}
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${cumulative.toStringAsFixed(0)} kg
Served By:${collection.userName ?? 'N/A'}''';

    return await sendSms(validated, msg);
  }

  Future<bool> sendInventorySaleSMS(Sale sale) async {
    print(
      '🔄 [SALE-SMS] Sending for ${sale.memberName} (${sale.receiptNumber})',
    );

    if (sale.memberId == null || sale.memberId!.isEmpty) return false;

    final memberService = Get.find<MemberService>();
    final member = await memberService.getMemberById(sale.memberId!);

    if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
      print('❌ [SALE-SMS] No phone for ${sale.memberName}');
      return false;
    }

    final validated = validateKenyanPhoneNumber(member.phoneNumber!);
    if (validated == null) {
      print('❌ [SALE-SMS] Invalid phone: ${member.phoneNumber}');
      return false;
    }

    final settingsService = Get.find<SettingsService>();
    final org = settingsService.organizationSettings.value;
    final inventoryService = Get.find<InventoryService>();
    final credit = await inventoryService.getMemberSeasonCredit(sale.memberId!);

    final msg = '''${org.societyName.toUpperCase()}
Fac:${org.factory}
T/No:${sale.receiptNumber ?? 'N/A'}
Date:${DateFormat('dd/MM/yy').format(sale.saleDate)}
M/No:${member.memberNumber}
M/Name:${sale.memberName}
Type:${sale.saleType == 'CREDIT' ? 'Credit' : 'Cash'} Sale
Amount:KSh ${sale.totalAmount.toStringAsFixed(2)}
Paid:KSh ${sale.paidAmount.toStringAsFixed(2)}
Balance:KSh ${sale.balanceAmount.toStringAsFixed(2)}
Total Credit:KSh ${credit.toStringAsFixed(0)}
Served By:${sale.userName ?? 'N/A'}''';

    return await sendSms(validated, msg);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> runSmsDiagnostic(String testPhone) async {
    final results = <String, dynamic>{
      'permissions': false,
      'phoneValidation': false,
      'validatedPhone': '',
      'sendSuccess': false,
      'error': '',
      'currentMode': currentSmsMode.value,
      'gatewayConfigured': false,
      'channelUsed': '',
      'totalSent': totalSmsSent.value,
      'totalFailed': totalSmsFailed.value,
    };

    final validated = validateKenyanPhoneNumber(testPhone);
    if (validated == null) {
      results['error'] = 'Invalid phone number format: $testPhone';
      return results;
    }
    results['phoneValidation'] = true;
    results['validatedPhone'] = validated;

    final settings = _settingsService.systemSettings.value;
    results['gatewayConfigured'] = settings.isGatewayConfigured;

    if (_permissionService != null) {
      results['permissions'] = await _permissionService!.checkSmsPermission();
    }

    final testMsg =
        'Farm Pro SMS test — ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}';

    final success = await sendSms(validated, testMsg);
    results['sendSuccess'] = success;
    results['channelUsed'] = currentSmsMode.value;

    if (success)
      totalSmsSent.value++;
    else
      totalSmsFailed.value++;

    return results;
  }

  Map<String, dynamic> getSmsStatistics() => {
    'totalSent': totalSmsSent.value,
    'totalFailed': totalSmsFailed.value,
    'queueSize': _smsQueue.length,
    'successRate':
        (totalSmsSent.value + totalSmsFailed.value) > 0
            ? (totalSmsSent.value /
                    (totalSmsSent.value + totalSmsFailed.value) *
                    100)
                .toStringAsFixed(1)
            : '0.0',
    'isProcessing': _isProcessingQueue,
    'currentMode': currentSmsMode.value,
  };

  void clearSmsQueue() {
    _smsQueue.clear();
    smsQueueSize.value = 0;
  }

  void resetSmsStatistics() {
    totalSmsSent.value = 0;
    totalSmsFailed.value = 0;
  }

  Future<bool> testSmsSending() async =>
      Platform.isAndroid && isSmsAvailable.value;

  Future<bool> checkSmsPermission() async {
    if (_permissionService == null) return false;
    return await _permissionService!.checkSmsPermission();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY QUEUE (kept for backward-compat)
  // ─────────────────────────────────────────────────────────────────────────

  void queueSms(
    String phone,
    String message, {
    int maxRetries = 3,
    int priority = 1,
  }) {
    // Immediately send instead of queueing
    sendSmsRobust(phone, message, maxRetries: maxRetries, priority: priority);
  }

  void _startQueueProcessor() {
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isProcessingQueue && _smsQueue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _smsQueue.isEmpty) return;
    _isProcessingQueue = true;
    try {
      final item = _smsQueue.removeAt(0);
      smsQueueSize.value = _smsQueue.length;
      await sendSms(item.phoneNumber, item.message);
    } finally {
      _isProcessingQueue = false;
    }
  }

  void _startHealthMonitor() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_queueProcessor == null || !_queueProcessor!.isActive) {
        _startQueueProcessor();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

class SmsQueueItem {
  final String phoneNumber;
  final String message;
  final int maxRetries;
  final int priority;
  final DateTime createdAt;
  int attempts;
  DateTime? lastAttempt;

  SmsQueueItem({
    required this.phoneNumber,
    required this.message,
    required this.maxRetries,
    required this.priority,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttempt,
  });
}
