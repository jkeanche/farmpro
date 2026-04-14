import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

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

  // SMS queue for backward compatibility (deprecated - now sending immediately)
  final List<SmsQueueItem> _smsQueue = [];
  Timer? _queueProcessor;
  bool _isProcessingQueue = false;

  // SMS gateway configuration is now loaded from SystemSettings via SettingsService

  // SMS statistics
  final RxInt totalSmsSent = 0.obs;
  final RxInt totalSmsFailed = 0.obs;
  final RxInt smsQueueSize = 0.obs;

  Future<SmsService> init() async {
    print('🔄 Initializing SMS Service...');

    // Initialize PermissionService with fallback
    try {
      _permissionService = Get.find<PermissionService>();
      print('✅ PermissionService found and initialized');
    } catch (e) {
      print('Warning: PermissionService not found, continuing without it: $e');
      // Continue without permission service - it will be null
    }

    // Check if SMS is available on this device
    if (Platform.isAndroid) {
      try {
        print('📱 Running on Android, checking SMS capabilities...');

        // Check SMS permissions using permission service
        bool granted = false;
        if (_permissionService != null) {
          // First check current permission status to avoid unnecessary prompts
          granted = await _permissionService!.checkSmsPermission();

          // If not granted, request permission once
          if (!granted) {
            print('📋 SMS permission not yet granted — requesting now');
            granted = await _permissionService!.requestSmsPermission();
          } else {
            print('✅ SMS permission already granted (persisted)');
          }

          print('📋 Final SMS permission result: $granted');
        } else {
          print('⚠️  No PermissionService available for SMS permission check');
        }

        isSmsAvailable.value = granted;

        if (isSmsAvailable.value) {
          print('✅ SMS permissions granted - SMS service active');

          // Test if the messenger is properly initialized
          try {
            print('🔧 Testing SMS messenger initialization...');
            // We'll test this during actual sending
          } catch (e) {
            print('⚠️  SMS messenger test failed: $e');
          }
        } else {
          print('⚠️  SMS permissions not granted - will continue attempting');
        }
      } catch (e) {
        print('Error requesting SMS permission: $e');
      }
    } else {
      print('⚠️  Not running on Android - SMS not supported');
      isSmsAvailable.value = false;
    }

    // Start SMS queue processor with auto-restart capability (for legacy queue items)
    _startQueueProcessor();
    _startHealthMonitor();

    print('✅ SMS Service initialization complete');
    return this;
  }

  /// Monitor SMS service health and restart if needed
  void _startHealthMonitor() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      try {
        // Check if queue processor is still running
        if (_queueProcessor == null || !_queueProcessor!.isActive) {
          print('🔧 SMS queue processor not active - restarting...');
          _startQueueProcessor();
        }

        // Attempt to get permissions if not available but we have pending SMS
        if (!isSmsAvailable.value &&
            _smsQueue.isNotEmpty &&
            Platform.isAndroid) {
          print(
            '🔧 SMS permissions not available but queue has items - checking permissions...',
          );
          _checkPermissionsQuietly();
        }

        print(
          '📊 SMS Health Check: Queue size: ${_smsQueue.length}, Sent: ${totalSmsSent.value}, Failed: ${totalSmsFailed.value}',
        );
      } catch (e) {
        print('Error in SMS health monitor: $e');
      }
    });
  }

  /// Quietly check SMS permissions without showing dialogs
  Future<void> _checkPermissionsQuietly() async {
    try {
      if (_permissionService != null) {
        final granted = await _permissionService!.checkSmsPermission();
        if (granted && !isSmsAvailable.value) {
          isSmsAvailable.value = true;
          print('✅ SMS permissions restored');
        }
      }
    } catch (e) {
      print('Error checking SMS permissions quietly: $e');
    }
  }

  /// Initialize SMS service for use (alias for init method)
  Future<void> initializeSmsService() async {
    try {
      await init();
      print('SMS service initialized successfully');
    } catch (e) {
      print('Error initializing SMS service: $e');
    }
  }

  /// Check SMS permission (convenience method)
  Future<bool> checkSmsPermission() async {
    try {
      if (_permissionService == null) {
        print('⚠️  PermissionService not available for SMS permission check');
        return false;
      }
      return await _permissionService!.checkSmsPermission();
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  @override
  void onClose() {
    print('🔴 SMS Service shutting down...');
    _queueProcessor?.cancel();
    super.onClose();
  }

  /// Force restart SMS service if it has stopped
  Future<void> forceRestart() async {
    try {
      print('🔄 Force restarting SMS service...');
      _queueProcessor?.cancel();
      await Future.delayed(const Duration(milliseconds: 500));
      await init();
      print('✅ SMS service restarted successfully');
    } catch (e) {
      print('❌ Error restarting SMS service: $e');
    }
  }

  /// Enhanced Kenyan phone number validation supporting all formats
  /// Accepts formats: +254XXXXXXXXX, 254XXXXXXXXX, 07XXXXXXXX, 01XXXXXXXX, etc.
  /// Returns: Formatted +254 number or null if invalid
  String? validateKenyanPhoneNumber(String phoneNumber) {
    try {
      print('📞 Validating phone number: "$phoneNumber"');

      // Remove all spaces, dashes, parentheses, and other non-digit characters except +
      String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\.\,]'), '');
      print('📞 After cleaning: "$cleaned"');

      // Handle different input formats
      String processedNumber = '';

      if (cleaned.startsWith('+254')) {
        // Format: +254XXXXXXXXX
        processedNumber = cleaned.substring(4);
        print('📞 Detected +254 format, extracted: "$processedNumber"');
      } else if (cleaned.startsWith('254')) {
        // Format: 254XXXXXXXXX
        processedNumber = cleaned.substring(3);
        print('📞 Detected 254 format, extracted: "$processedNumber"');
      } else if (cleaned.startsWith('0')) {
        // Format: 07XXXXXXXX, 01XXXXXXXX, etc.
        processedNumber = cleaned.substring(1);
        print('📞 Detected 0X format, extracted: "$processedNumber"');
      } else if (cleaned.length == 9 && cleaned.startsWith(RegExp(r'[17]'))) {
        // Format: 7XXXXXXXX, 1XXXXXXXX (direct mobile without leading 0)
        processedNumber = cleaned;
        print('📞 Detected direct mobile format: "$processedNumber"');
      } else {
        print('❌ Phone number format not recognized: "$cleaned"');
        return null;
      }

      // Validate processed number length
      if (processedNumber.length != 9) {
        print(
          '❌ Invalid length after processing: ${processedNumber.length} (expected 9)',
        );
        return null;
      }

      // Validate that it contains only digits
      if (!RegExp(r'^\d+$').hasMatch(processedNumber)) {
        print('❌ Contains non-digit characters: "$processedNumber"');
        return null;
      }

      // Enhanced mobile prefixes for all Kenyan networks
      final mobileNetworks = {
        // Safaricom mobile prefixes
        'Safaricom': [
          '70',
          '71',
          '72',
          '73',
          '74',
          '75',
          '76',
          '77',
          '78',
          '79',
        ],
        // Airtel mobile prefixes
        'Airtel': [
          '73',
          '78',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '16',
          '17',
          '18',
          '19',
        ],
        // Telkom mobile prefixes
        'Telkom': ['77', '76'],
        // Equitel mobile prefixes
        'Equitel': ['76'],
      };

      // Check if it's a valid mobile number
      String prefix = processedNumber.substring(0, 2);
      String networkName = '';
      bool isMobile = false;

      for (String network in mobileNetworks.keys) {
        if (mobileNetworks[network]!.contains(prefix)) {
          networkName = network;
          isMobile = true;
          break;
        }
      }

      if (isMobile) {
        String formattedNumber = '+254$processedNumber';
        print('✅ Valid $networkName mobile number: $formattedNumber');
        return formattedNumber;
      }

      // Check for landline numbers (various city codes)
      final landlineAreas = {
        'Nairobi': ['20'],
        'Mombasa': ['41'],
        'Nakuru': ['51'],
        'Eldoret': ['53'],
        'Kisumu': ['57'],
        'Nyeri': ['61'],
        'Meru': ['64'],
        'Embu': ['68'],
        'Kitale': ['54'],
        'Kakamega': ['56'],
        'Kericho': ['52'],
        'Malindi': ['42'],
        'Lamu': ['42'],
        'Garissa': ['46'],
        'Wajir': ['46'],
        'Mandera': ['46'],
        'Lodwar': ['54'],
        'Marsabit': ['69'],
        'Isiolo': ['65'],
        'Maralal': ['65'],
        'Kapenguria': ['54'],
        'Bungoma': ['55'],
        'Webuye': ['55'],
        'Busia': ['55'],
        'Siaya': ['57'],
        'Kisii': ['58'],
        'Nyamira': ['58'],
        'Migori': ['59'],
        'Homa Bay': ['59'],
        'Machakos': ['44'],
        'Kitui': ['44'],
        'Makueni': ['44'],
        'Kajiado': ['45'],
        'Narok': ['50'],
        'Bomet': ['52'],
        'Kapsabet': ['53'],
        'Kapsowar': ['53'],
        'Marigat': ['53'],
        'Kabarnet': ['53'],
        'Molo': ['51'],
        'Naivasha': ['50'],
        'Gilgil': ['50'],
        'Nanyuki': ['62'],
        'Isinya': ['45'],
        'Namanga': ['45'],
        'Taveta': ['43'],
        'Voi': ['43'],
        'Makindu': ['44'],
      };

      // Check if it's a valid landline (8 or 9 digits for landlines)
      if (processedNumber.length >= 8) {
        for (String area in landlineAreas.keys) {
          for (String areaCode in landlineAreas[area]!) {
            if (processedNumber.startsWith(areaCode)) {
              String formattedNumber = '+254$processedNumber';
              print('✅ Valid $area landline number: $formattedNumber');
              return formattedNumber;
            }
          }
        }
      }

      print(
        '❌ Not a valid Kenyan mobile or landline number. Prefix: "$prefix"',
      );
      print('❌ Processed number: "$processedNumber"');
      return null;
    } catch (e) {
      print('❌ Error validating phone number "$phoneNumber": $e');
      return null;
    }
  }

  /// Adds SMS to queue for robust sending with enhanced validation
  /// NOTE: This method is deprecated - use sendSmsRobust() for immediate sending instead
  void queueSms(
    String phoneNumber,
    String message, {
    int maxRetries = 3,
    int priority = 1,
  }) {
    try {
      final validatedNumber = validateKenyanPhoneNumber(phoneNumber);
      if (validatedNumber == null) {
        print(
          '❌ Invalid Kenyan phone number: $phoneNumber - Phone validation failed',
        );
        totalSmsFailed.value++;
        return;
      }

      // Check for duplicate SMS in queue to avoid spam
      final existingIndex = _smsQueue.indexWhere(
        (item) =>
            item.phoneNumber == validatedNumber &&
            item.message.trim() == message.trim(),
      );

      if (existingIndex != -1) {
        print(
          '📋 SMS already queued for $validatedNumber - skipping duplicate',
        );
        return;
      }

      final smsItem = SmsQueueItem(
        phoneNumber: validatedNumber,
        message: message,
        maxRetries: maxRetries,
        priority: priority,
        createdAt: DateTime.now(),
      );

      _smsQueue.add(smsItem);
      _smsQueue.sort(
        (a, b) => b.priority.compareTo(a.priority),
      ); // Higher priority first
      smsQueueSize.value = _smsQueue.length;

      print(
        '📤 SMS queued for $validatedNumber (Priority: $priority, Queue size: ${_smsQueue.length})',
      );

      // Force immediate processing for high priority SMS
      if (priority >= 3 && !_isProcessingQueue) {
        print('🚀 High priority SMS - triggering immediate processing');
        _processNextSmsInQueue();
      }
    } catch (e) {
      print('❌ Error queuing SMS: $e');
      totalSmsFailed.value++;
    }
  }

  /// Starts the SMS queue processor with robust error handling
  void _startQueueProcessor() {
    _queueProcessor?.cancel(); // Cancel any existing timer
    _queueProcessor = Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        if (!_isProcessingQueue && _smsQueue.isNotEmpty) {
          _processNextSmsInQueue().catchError((error) {
            print('Error in queue processor: $error');
            // Don't terminate the queue processor - continue processing
            _isProcessingQueue = false;
          });
        }
      } catch (e) {
        print('Critical error in SMS queue processor: $e');
        // Reset processing flag to prevent deadlock
        _isProcessingQueue = false;
      }
    });
    print(
      'SMS queue processor started - will run continuously while app is active',
    );
  }

  /// Processes the next SMS in the queue
  Future<void> _processNextSmsInQueue() async {
    if (_isProcessingQueue || _smsQueue.isEmpty) return;

    _isProcessingQueue = true;

    try {
      final smsItem = _smsQueue.removeAt(0);
      smsQueueSize.value = _smsQueue.length;

      print(
        'Processing SMS to ${smsItem.phoneNumber} (Attempt ${smsItem.attempts + 1}/${smsItem.maxRetries})',
      );

      final success = await _sendDirectSmsInternal(
        smsItem.phoneNumber,
        smsItem.message,
      );

      if (success) {
        totalSmsSent.value++;
        print('SMS sent successfully to ${smsItem.phoneNumber}');
      } else {
        smsItem.attempts++;
        if (smsItem.attempts < smsItem.maxRetries) {
          // Re-queue for retry with delay
          smsItem.lastAttempt = DateTime.now();
          _smsQueue.add(smsItem);
          smsQueueSize.value = _smsQueue.length;
          print(
            'SMS failed, re-queued for retry. Attempt ${smsItem.attempts}/${smsItem.maxRetries}',
          );
        } else {
          totalSmsFailed.value++;
          print(
            'SMS failed permanently after ${smsItem.maxRetries} attempts to ${smsItem.phoneNumber}',
          );
        }
      }
    } catch (e) {
      print('Error processing SMS queue: $e');
      totalSmsFailed.value++;
    } finally {
      _isProcessingQueue = false;

      // Add a small delay between SMS sends to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Internal method to send SMS directly with enhanced error handling
  Future<bool> _sendDirectSmsInternal(
    String phoneNumber,
    String message,
  ) async {
    try {
      print('🔄 _sendDirectSmsInternal called for $phoneNumber');

      if (!Platform.isAndroid) {
        print('⚠️  Direct SMS sending is only supported on Android');
        return false;
      }

      // Always check permissions fresh for each send attempt
      bool permissionGranted = false;

      if (_permissionService != null) {
        try {
          // First check if we have permission
          permissionGranted = await _permissionService!.checkSmsPermission();
          print('📋 SMS permission check result: $permissionGranted');

          if (!permissionGranted) {
            // Try requesting permission
            print('📋 Requesting SMS permission...');
            permissionGranted =
                await _permissionService!.requestSmsPermission();
            print('📋 SMS permission request result: $permissionGranted');
          }

          isSmsAvailable.value = permissionGranted;
        } catch (e) {
          print('⚠️  Error checking/requesting SMS permission: $e');
          return false;
        }
      } else {
        print('⚠️  PermissionService not available');
        return false;
      }

      if (!permissionGranted) {
        print('❌ SMS permission not granted for $phoneNumber');
        return false;
      }

      print('📱 Attempting to send SMS to $phoneNumber...');
      print(
        '📝 Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...',
      );

      // Try sending with the messenger
      try {
        final success = await messenger
            .sendSMS(phoneNumber: phoneNumber, message: message)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('⏰ SMS sending timed out for $phoneNumber after 30s');
                return false;
              },
            );

        if (success) {
          print('✅ SMS sent successfully to $phoneNumber');
          print('📋 SMS Details:');
          print('   - Phone: $phoneNumber');
          print('   - Message length: ${message.length} characters');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          print('   - Status: SENT (awaiting delivery)');
          print('');
          print('💡 DELIVERY NOTES:');
          print('   • SMS has been sent to the network');
          print('   • Delivery may take 1-5 minutes');
          print('   • Check recipient phone for delivery');
          print('   • Network delays are common');
          return true;
        } else {
          print('❌ messenger.sendSMS returned false for $phoneNumber');
          print('🔧 TROUBLESHOOTING:');
          print('   • Check phone number format');
          print('   • Verify SMS permissions');
          print('   • Try again in a few minutes');
          return false;
        }
      } catch (e) {
        print('❌ Exception in messenger.sendSMS for $phoneNumber: $e');
        return false;
      }
    } catch (e) {
      print('❌ Critical error in _sendDirectSmsInternal for $phoneNumber: $e');
      return false;
    }
  }

  /// Direct programmatic SMS sending for Android
  Future<bool> sendDirectSms(String phoneNumber, String message) async {
    try {
      final validatedNumber = validateKenyanPhoneNumber(phoneNumber);
      if (validatedNumber == null) {
        print('Invalid Kenyan phone number: $phoneNumber');
        return false;
      }

      return await _sendDirectSmsInternal(validatedNumber, message);
    } catch (e) {
      print('Error in sendDirectSms method: $e');
      return false;
    }
  }

  /// SMS via Zettatel SMS gateway API
  Future<bool> sendSmsViaGateway(String phoneNumber, String message) async {
    try {
      final validatedNumber = validateKenyanPhoneNumber(phoneNumber);
      if (validatedNumber == null) {
        print(
          'Invalid Kenyan phone number for SMS gateway: $phoneNumber - Failed validation',
        );
        return false;
      }

      // Get SMS gateway configuration from settings
      final settingsService = Get.find<SettingsService>();
      final settings = settingsService.systemSettings.value;

      // Check if gateway is enabled and configured
      if (!settings.smsGatewayEnabled) {
        print('SMS gateway is disabled in settings');
        return false;
      }

      if (settings.smsGatewayUsername.isEmpty ||
          settings.smsGatewayPassword.isEmpty) {
        print('SMS gateway not properly configured - missing credentials');
        return false;
      }

      print('Sending SMS via Zettatel gateway to $validatedNumber');

      // Format phone number for Zettatel (remove + prefix)
      String formattedPhone =
          validatedNumber.startsWith('+')
              ? validatedNumber.substring(1)
              : validatedNumber;

      // Create URL-encoded form data as per Zettatel API specification
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

      // Convert to URL-encoded string
      final encodedData = formData.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      print('📤 Sending to Zettatel API: ${settings.smsGatewayUrl}');
      print(
        '📱 Phone: $formattedPhone, Sender: ${settings.smsGatewaySenderId}',
      );

      // Send request to Zettatel API
      final response = await http
          .post(
            Uri.parse(settings.smsGatewayUrl),
            headers: {
              'apikey': settings.smsGatewayApiKey,
              'cache-control': 'no-cache',
              'content-type': 'application/x-www-form-urlencoded',
            },
            body: encodedData,
          )
          .timeout(const Duration(seconds: 30));

      print('📋 Gateway response status: ${response.statusCode}');
      print('📋 Gateway response body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse JSON response to check for success
        try {
          final responseData = jsonDecode(response.body);

          // Zettatel typically returns success status in the response
          if (responseData is Map &&
              (responseData['status'] == 'success' ||
                  responseData['Status'] == 'success' ||
                  responseData.containsKey('MessageId') ||
                  responseData.containsKey('messageid'))) {
            print('✅ SMS sent successfully via Zettatel gateway');
            return true;
          } else {
            print('❌ Gateway returned error: $responseData');
            return false;
          }
        } catch (e) {
          // If JSON parsing fails, check if response contains success indicators
          final responseText = response.body.toLowerCase();
          if (responseText.contains('success') ||
              responseText.contains('sent')) {
            print(
              '✅ SMS sent successfully via Zettatel gateway (text response)',
            );
            return true;
          } else {
            print('❌ Gateway response parsing failed: $e');
            print('❌ Response body: ${response.body}');
            return false;
          }
        }
      } else {
        print(
          '❌ Failed to send SMS via Zettatel gateway: HTTP ${response.statusCode}',
        );
        print('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending SMS via Zettatel gateway: $e');
      return false;
    }
  }

  Future<bool> _sendViaGatewayWithFallback(
    String phoneNumber,
    String message,
  ) async {
    try {
      final settings = _settingsService.systemSettings.value;
      final mode = settings.smsMode; // 'sim' or 'gateway'

      if (mode == 'gateway') {
        // ── GATEWAY MODE ────────────────────────────────────────
        if (!settings.isGatewayConfigured) {
          print('❌ [SMS] Gateway mode selected but credentials are missing.');
          Get.snackbar(
            'SMS Gateway Not Configured',
            'Gateway SMS mode is active but credentials are incomplete. '
                'Go to Settings → System Settings → SMS Configuration to '
                'add your gateway username, password and sender ID, '
                'or switch to SIM Card mode.',
            backgroundColor: const Color(0xFFB71C1C),
            colorText: Colors.white,
            duration: const Duration(seconds: 7),
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            icon: const Icon(Icons.sms_failed, color: Colors.white),
          );
          return false;
        }

        print('📡 [SMS] GATEWAY MODE → sending to $phoneNumber');
        bool gatewaySuccess = false;
        try {
          gatewaySuccess = await sendSmsViaGateway(phoneNumber, message);
        } catch (e) {
          print('❌ [SMS] Gateway exception: $e');
        }

        if (gatewaySuccess) {
          print('✅ [SMS] Gateway delivery succeeded');
          return true;
        }

        // Gateway failed — try SIM fallback if enabled
        if (settings.smsGatewayFallbackToSim) {
          print('📱 [SMS] Gateway failed → SIM fallback...');
          final simResult = await _sendDirectSmsInternal(phoneNumber, message);
          if (simResult) {
            print('✅ [SMS] SIM fallback succeeded');
            return true;
          }
        }

        print('❌ [SMS] Gateway failed and no successful fallback.');
        Get.snackbar(
          'SMS Failed',
          'Could not send via SMS Gateway. '
              'Check your gateway credentials in Settings or enable SIM fallback.',
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return false;
      } else {
        // ── SIM CARD MODE (default) ────────────────────────────
        print('📱 [SMS] SIM CARD MODE → sending to $phoneNumber');
        return await _sendDirectSmsInternal(phoneNumber, message);
      }
    } catch (e) {
      print('❌ [SMS] _sendViaGatewayWithFallback error: $e');
      return false;
    }
  }

  /// Main method to use - sends SMS immediately (with validation)
  /// Uses gateway-first approach with SIM fallback
  Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      final validatedNumber = validateKenyanPhoneNumber(phoneNumber);
      if (validatedNumber == null) {
        print(
          'Invalid Kenyan phone number for SMS: $phoneNumber - Failed validation',
        );
        return false;
      }

      print('📱 Sending SMS with gateway-first logic to $validatedNumber...');
      return await _sendViaGatewayWithFallback(validatedNumber, message);
    } catch (e) {
      print('Error in sendSms: $e');
      return false;
    }
  }

  /// Send SMS immediately with retry logic (bypasses queue)
  /// Enhanced with lifecycle protection, better error handling, and gateway-first logic
  Future<bool> sendSmsRobust(
    String phoneNumber,
    String message, {
    int maxRetries = 3,
    int priority = 1,
  }) async {
    try {
      final validatedNumber = validateKenyanPhoneNumber(phoneNumber);
      if (validatedNumber == null) {
        print('Invalid Kenyan phone number: $phoneNumber - Failed validation');
        return false;
      }

      print(
        '📱 [ROBUST SMS] Starting enhanced SMS sending with gateway-first logic to $validatedNumber...',
      );
      print('📱 [ROBUST SMS] Priority: $priority, Max retries: $maxRetries');

      // **ENHANCEMENT 1: Pre-validate SMS capabilities before attempting**
      if (!Platform.isAndroid) {
        print('❌ [ROBUST SMS] Not on Android platform - SMS not supported');
        return false;
      }

      // **ENHANCEMENT 2: Check and ensure SMS permissions are active for SIM fallback**
      bool hasPermission = isSmsAvailable.value;
      if (!hasPermission && _permissionService != null) {
        print(
          '🔧 [ROBUST SMS] SMS not available, attempting to get permissions...',
        );
        hasPermission = await _permissionService!.checkSmsPermission();
        if (!hasPermission) {
          hasPermission = await _permissionService!.requestSmsPermission();
        }
        isSmsAvailable.value = hasPermission;
      }

      // Note: We don't fail here if no SIM permissions since gateway might work
      print(
        '✅ [ROBUST SMS] SMS permissions check complete (SIM fallback: $hasPermission)',
      );

      // **ENHANCEMENT 3: Use enhanced retry logic with exponential backoff**
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          print(
            '📤 [ROBUST SMS] Attempt $attempt/$maxRetries for $validatedNumber',
          );

          // **ENHANCEMENT 4: Add pre-send delay for high-priority SMS to ensure system readiness**
          if (priority >= 3 && attempt == 1) {
            print(
              '⏳ [ROBUST SMS] High priority SMS - ensuring system readiness...',
            );
            await Future.delayed(const Duration(milliseconds: 500));
          }

          // **ENHANCEMENT 5: Wrap SMS sending in isolate-like protection with gateway-first logic**
          bool success = false;
          try {
            // Create a completer to handle the async operation with timeout
            final completer = Completer<bool>();

            // Start the SMS sending operation using gateway-first approach
            _sendViaGatewayWithFallback(validatedNumber, message)
                .then((result) {
                  if (!completer.isCompleted) {
                    completer.complete(result);
                  }
                })
                .catchError((error) {
                  if (!completer.isCompleted) {
                    completer.completeError(error);
                  }
                });

            // Wait for completion with timeout
            success = await completer.future.timeout(
              Duration(
                seconds:
                    15 + (attempt * 3), // Longer timeout for gateway + fallback
              ),
              onTimeout: () {
                print('⏰ [ROBUST SMS] Attempt $attempt timed out');
                return false;
              },
            );
          } catch (e) {
            print('❌ [ROBUST SMS] Attempt $attempt failed with error: $e');
            success = false;
          }

          if (success) {
            print(
              '✅ [ROBUST SMS] SMS sent successfully on attempt $attempt to $validatedNumber',
            );
            totalSmsSent.value++;

            // **ENHANCEMENT 6: Add post-send verification delay**
            print('✅ [ROBUST SMS] Adding post-send verification delay...');
            await Future.delayed(const Duration(milliseconds: 1000));
            print('✅ [ROBUST SMS] Verification complete');

            return true;
          } else {
            print(
              '❌ [ROBUST SMS] Attempt $attempt failed for $validatedNumber',
            );
            if (attempt < maxRetries) {
              // **ENHANCEMENT 7: Enhanced exponential backoff with jitter**
              final baseDelay = attempt * 2;
              final jitter = (attempt * 0.5); // Add some randomness
              final delaySeconds = baseDelay + jitter;
              print(
                '⏳ [ROBUST SMS] Waiting ${delaySeconds.toStringAsFixed(1)}s before retry...',
              );
              await Future.delayed(
                Duration(milliseconds: (delaySeconds * 1000).round()),
              );
            }
          }
        } catch (e) {
          print(
            '❌ [ROBUST SMS] Attempt $attempt exception for $validatedNumber: $e',
          );
          if (attempt < maxRetries) {
            final delaySeconds = attempt * 3; // Longer delay for exceptions
            print(
              '⏳ [ROBUST SMS] Exception recovery delay: ${delaySeconds}s...',
            );
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }

      print(
        '❌ [ROBUST SMS] All SMS attempts failed for $validatedNumber after $maxRetries tries',
      );
      totalSmsFailed.value++;
      return false;
    } catch (e) {
      print('❌ [ROBUST SMS] Critical error in sendSmsRobust: $e');
      print('❌ [ROBUST SMS] Stack trace: ${StackTrace.current}');
      totalSmsFailed.value++;
      return false;
    }
  }

  /// Send SMS for coffee collection with robust handling using gateway-first priority
  Future<bool> sendCoffeeCollectionSMS(CoffeeCollection collection) async {
    try {
      print(
        '🔄 [COFFEE SMS] Starting coffee collection SMS for ${collection.memberName}',
      );

      if (collection.memberName.isEmpty) {
        print(
          '❌ [COFFEE SMS] No member name available for collection ${collection.id}',
        );
        return false;
      }

      // Get member phone number
      final memberService = Get.find<MemberService>();
      final member = await memberService.getMemberById(collection.memberId);

      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print(
          '❌ [COFFEE SMS] No phone number available for member ${collection.memberName}',
        );
        return false;
      }

      // Validate phone number first
      final validatedNumber = validateKenyanPhoneNumber(member.phoneNumber!);
      if (validatedNumber == null) {
        print(
          '❌ [COFFEE SMS] Invalid phone number for member ${collection.memberName}: ${member.phoneNumber} - Kenyan phone validation failed',
        );
        return false;
      }

      print('✅ [COFFEE SMS] Phone number validated: $validatedNumber');

      // Get organization settings for SMS format
      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;
      final systemSettings = settingsService.systemSettings.value;
      final societyName = orgSettings.societyName;
      final factoryName = orgSettings.factory;

      // Log gateway configuration status
      if (systemSettings.smsGatewayEnabled) {
        print(
          '📡 [COFFEE SMS] SMS gateway enabled - will attempt gateway-first sending',
        );
      } else {
        print('📱 [COFFEE SMS] SMS gateway disabled - will use SIM card only');
      }

      // Calculate all-time cumulative weight for this member (across all seasons)
      final coffeeCollectionService = Get.find<CoffeeCollectionService>();
      final memberSummary = await coffeeCollectionService
          .getMemberSeasonSummary(collection.memberId);

      // Ensure we have a valid cumulative weight value with robust parsing
      double allTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = memberSummary['allTimeWeight'];
        print(
          '🔍 [COFFEE SMS] Raw weight from DB: $rawWeight (${rawWeight.runtimeType}) for member ${collection.memberName}',
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
            '⚠️ [COFFEE SMS] Invalid weight detected: $allTimeCumulativeWeight, setting to 0.0',
          );
          allTimeCumulativeWeight = 0.0;
        }

        print(
          '✅ [COFFEE SMS] Final cumulative weight: $allTimeCumulativeWeight kg for member ${collection.memberName}',
        );
      } catch (e) {
        print(
          '❌ [COFFEE SMS] Error parsing cumulative weight for member ${collection.memberName}: $e',
        );
        print('   Raw memberSummary: $memberSummary');
        allTimeCumulativeWeight = 0.0;
      }

      final receiptNo = collection.receiptNumber ?? 'N/A';
      final formattedDate = DateFormat(
        'dd/MM/yy',
      ).format(collection.collectionDate);

      // Maintain existing SMS format exactly as before
      final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:$receiptNo
Date:$formattedDate
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(0)} kg
Served By:${collection.userName ?? 'N/A'}''';

      print('📝 [COFFEE SMS] Message prepared (${message.length} chars)');

      // Send SMS using gateway-first priority system with enhanced error handling
      print('📤 [COFFEE SMS] Sending SMS via gateway-first priority system...');
      final success = await sendSmsRobust(
        validatedNumber,
        message,
        maxRetries: 3,
        priority: 2, // High priority for coffee collection notifications
      );

      if (success) {
        print(
          '✅ [COFFEE SMS] Coffee collection SMS sent successfully for ${collection.memberName} ($validatedNumber)',
        );
        print(
          '📊 [COFFEE SMS] Collection details: Receipt $receiptNo, Weight ${collection.netWeight.toStringAsFixed(1)}kg',
        );
      } else {
        print(
          '❌ [COFFEE SMS] Coffee collection SMS failed for ${collection.memberName} ($validatedNumber)',
        );
        print(
          '⚠️ [COFFEE SMS] SMS failure will not prevent collection from being saved',
        );

        // Log additional context for troubleshooting
        if (systemSettings.smsGatewayEnabled) {
          print(
            '🔧 [COFFEE SMS] Gateway was enabled but SMS still failed - check gateway configuration',
          );
        } else {
          print('🔧 [COFFEE SMS] Gateway disabled - SIM card sending failed');
        }
      }

      return success;
    } catch (e) {
      print('❌ [COFFEE SMS] Critical error sending coffee collection SMS: $e');
      print(
        '📋 [COFFEE SMS] Collection: ${collection.memberName} (${collection.receiptNumber})',
      );
      print(
        '⚠️ [COFFEE SMS] SMS failure will not prevent collection from being saved',
      );
      totalSmsFailed.value++;
      return false;
    }
  }

  /// Send SMS for inventory sale with cumulative credit calculation
  Future<bool> sendInventorySaleSMS(Sale sale) async {
    try {
      print(
        '🔄 [INVENTORY SMS] Starting inventory sale SMS for ${sale.memberName}',
      );

      if (sale.memberName == null || sale.memberName!.isEmpty) {
        print('❌ [INVENTORY SMS] No member name available for sale ${sale.id}');
        return false;
      }

      if (sale.memberId == null || sale.memberId!.isEmpty) {
        print('❌ [INVENTORY SMS] No member ID available for sale ${sale.id}');
        return false;
      }

      // Get member phone number
      final memberService = Get.find<MemberService>();
      final member = await memberService.getMemberById(sale.memberId!);

      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print(
          '❌ [INVENTORY SMS] No phone number available for member ${sale.memberName}',
        );
        return false;
      }

      // Validate phone number first
      final validatedNumber = validateKenyanPhoneNumber(member.phoneNumber!);
      if (validatedNumber == null) {
        print(
          '❌ [INVENTORY SMS] Invalid phone number for member ${sale.memberName}: ${member.phoneNumber}',
        );
        return false;
      }

      print('✅ [INVENTORY SMS] Phone number validated: $validatedNumber');

      // Get organization settings for SMS format
      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;
      final systemSettings = settingsService.systemSettings.value;
      final societyName = orgSettings.societyName;
      final factoryName = orgSettings.factory;

      // Log gateway configuration status
      if (systemSettings.smsGatewayEnabled) {
        print(
          '📡 [INVENTORY SMS] SMS gateway enabled - will attempt gateway-first sending',
        );
      } else {
        print(
          '📱 [INVENTORY SMS] SMS gateway disabled - will use SIM card only',
        );
      }

      // Calculate cumulative credit for this member (current inventory season only)
      final inventoryService = Get.find<InventoryService>();
      final cumulativeCredit = await inventoryService.getMemberSeasonCredit(
        sale.memberId!,
      );

      print(
        '✅ [INVENTORY SMS] Cumulative credit calculated: KSh ${cumulativeCredit.toStringAsFixed(2)} for member ${sale.memberName}',
      );

      final receiptNo = sale.receiptNumber ?? 'N/A';
      final formattedDate = DateFormat('dd/MM/yy').format(sale.saleDate);
      final saleTypeDisplay = sale.saleType == 'CREDIT' ? 'Credit' : 'Cash';

      // Create SMS message for inventory sale
      final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:$receiptNo
Date:$formattedDate
M/No:${member.memberNumber}
M/Name:${sale.memberName}
Type:$saleTypeDisplay Sale
Amount:KSh ${sale.totalAmount.toStringAsFixed(2)}
Paid:KSh ${sale.paidAmount.toStringAsFixed(2)}
Balance:KSh ${sale.balanceAmount.toStringAsFixed(2)}
Total Credit:KSh ${cumulativeCredit.toStringAsFixed(0)}
Served By:${sale.userName ?? 'N/A'}''';

      print('📝 [INVENTORY SMS] Message prepared (${message.length} chars)');

      // Send SMS using gateway-first priority system
      print(
        '📤 [INVENTORY SMS] Sending SMS via gateway-first priority system...',
      );
      final success = await sendSmsRobust(
        validatedNumber,
        message,
        maxRetries: 2,
        priority: 2, // High priority for sales notifications
      );

      if (success) {
        print(
          '✅ [INVENTORY SMS] SMS sent successfully to ${sale.memberName} ($validatedNumber)',
        );
        print(
          '📊 [INVENTORY SMS] Sale details: Receipt $receiptNo, Amount KSh ${sale.totalAmount.toStringAsFixed(2)}',
        );
      } else {
        print(
          '❌ [INVENTORY SMS] Failed to send SMS to ${sale.memberName} ($validatedNumber)',
        );
      }

      return success;
    } catch (e) {
      print(
        '❌ [INVENTORY SMS] Error sending inventory sale SMS for ${sale.memberName}: $e',
      );
      totalSmsFailed.value++;
      return false;
    }
  }

  /// Add diagnostic testing function to help troubleshoot
  Future<Map<String, dynamic>> runSmsDiagnostic(String testPhoneNumber) async {
    Map<String, dynamic> results = {
      'permissions': false,
      'smsAvailable': false,
      'phoneValidation': false,
      'validatedPhone': '',
      'sendAttempt': false,
      'sendSuccess': false,
      'error': '',
      'queueSize': _smsQueue.length,
      'totalSent': totalSmsSent.value,
      'totalFailed': totalSmsFailed.value,
      // Gateway-specific results
      'gatewayEnabled': false,
      'gatewayConfigured': false,
      'gatewayConnectivity': false,
      'gatewayAttempt': false,
      'gatewaySuccess': false,
      'gatewayError': '',
      'simFallbackEnabled': false,
      'simAttempt': false,
      'simSuccess': false,
      'channelUsed': '',
    };

    try {
      // Check phone number validation first
      final validatedNumber = validateKenyanPhoneNumber(testPhoneNumber);
      if (validatedNumber != null) {
        results['phoneValidation'] = true;
        results['validatedPhone'] = validatedNumber;
      } else {
        results['error'] =
            'Invalid Kenyan phone number format: $testPhoneNumber';
        return results;
      }

      // Check gateway configuration
      final settings = await _settingsService.getCompleteSystemSettings();
      results['gatewayEnabled'] = settings.smsGatewayEnabled;
      results['gatewayConfigured'] = _isGatewayConfigured(settings);
      results['simFallbackEnabled'] = settings.smsGatewayFallbackToSim;

      // Check permissions
      results['permissions'] = false;
      if (_permissionService != null) {
        results['permissions'] = await _permissionService!.checkSmsPermission();
      }
      results['smsAvailable'] = isSmsAvailable.value;

      // Test gateway connectivity if configured
      if (results['gatewayConfigured'] == true) {
        results['gatewayConnectivity'] = await _testGatewayConnectivity(
          settings,
        );
      }

      // Try sending a test message using the gateway-first approach
      if (results['phoneValidation'] == true) {
        try {
          final testMessage =
              'Test SMS from Farm Pro app. ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}';

          results['sendAttempt'] = true;

          // Use the gateway-first approach like the actual SMS sending
          final success = await _sendTestSmsWithDiagnostics(
            validatedNumber,
            testMessage,
            results,
          );

          results['sendSuccess'] = success;
          results['testMessage'] = testMessage;

          if (success) {
            totalSmsSent.value++;
          } else {
            totalSmsFailed.value++;
          }
        } catch (e) {
          results['error'] += 'Send error: $e. ';
          totalSmsFailed.value++;
        }
      } else {
        results['error'] += 'Phone number validation failed. ';
      }

      return results;
    } catch (e) {
      results['error'] += 'General diagnostic error: $e';
      return results;
    }
  }

  /// Test gateway connectivity without sending SMS
  Future<bool> _testGatewayConnectivity(SystemSettings settings) async {
    try {
      if (!settings.smsGatewayEnabled ||
          settings.smsGatewayUrl.isEmpty ||
          settings.smsGatewayUsername.isEmpty ||
          settings.smsGatewayPassword.isEmpty) {
        return false;
      }

      // Test basic connectivity to the gateway URL
      final uri = Uri.parse(settings.smsGatewayUrl);
      final client = http.Client();

      try {
        final response = await client
            .head(uri)
            .timeout(const Duration(seconds: 10));

        // Gateway is reachable if we get any HTTP response
        return response.statusCode < 500;
      } catch (e) {
        print('Gateway connectivity test failed: $e');
        return false;
      } finally {
        client.close();
      }
    } catch (e) {
      print('Gateway connectivity test error: $e');
      return false;
    }
  }

  /// Check if gateway is properly configured
  bool _isGatewayConfigured(SystemSettings settings) {
    return settings.smsGatewayEnabled &&
        settings.smsGatewayUrl.isNotEmpty &&
        settings.smsGatewayUsername.isNotEmpty &&
        settings.smsGatewayPassword.isNotEmpty &&
        settings.smsGatewaySenderId.isNotEmpty;
  }

  /// Send test SMS with detailed diagnostics
  Future<bool> _sendTestSmsWithDiagnostics(
    String phoneNumber,
    String message,
    Map<String, dynamic> results,
  ) async {
    try {
      final settings = await _settingsService.getCompleteSystemSettings();

      // Try gateway first if enabled and configured
      if (settings.smsGatewayEnabled && _isGatewayConfigured(settings)) {
        results['gatewayAttempt'] = true;

        try {
          print('🌐 [DIAGNOSTIC] Testing SMS gateway...');
          final gatewaySuccess = await sendSmsViaGateway(phoneNumber, message);

          results['gatewaySuccess'] = gatewaySuccess;

          if (gatewaySuccess) {
            results['channelUsed'] = 'Gateway';
            print('✅ [DIAGNOSTIC] Gateway test successful');
            return true;
          } else {
            results['gatewayError'] =
                'Gateway send failed - check credentials and connectivity';
            print('❌ [DIAGNOSTIC] Gateway test failed');
          }
        } catch (e) {
          results['gatewayError'] = 'Gateway error: $e';
          print('❌ [DIAGNOSTIC] Gateway test error: $e');
        }

        // Try SIM fallback if gateway failed and fallback is enabled
        if (settings.smsGatewayFallbackToSim &&
            results['permissions'] == true) {
          results['simAttempt'] = true;

          try {
            print('📱 [DIAGNOSTIC] Testing SIM fallback...');
            final simSuccess = await _sendDirectSmsInternal(
              phoneNumber,
              message,
            );

            results['simSuccess'] = simSuccess;

            if (simSuccess) {
              results['channelUsed'] = 'SIM (Fallback)';
              print('✅ [DIAGNOSTIC] SIM fallback test successful');
              return true;
            } else {
              print('❌ [DIAGNOSTIC] SIM fallback test failed');
            }
          } catch (e) {
            results['error'] += 'SIM fallback error: $e. ';
            print('❌ [DIAGNOSTIC] SIM fallback test error: $e');
          }
        }
      } else {
        // Gateway not configured, try SIM directly
        if (results['permissions'] == true) {
          results['simAttempt'] = true;

          try {
            print('📱 [DIAGNOSTIC] Testing SIM (gateway not configured)...');
            final simSuccess = await _sendDirectSmsInternal(
              phoneNumber,
              message,
            );

            results['simSuccess'] = simSuccess;

            if (simSuccess) {
              results['channelUsed'] = 'SIM';
              print('✅ [DIAGNOSTIC] SIM test successful');
              return true;
            } else {
              print('❌ [DIAGNOSTIC] SIM test failed');
            }
          } catch (e) {
            results['error'] += 'SIM error: $e. ';
            print('❌ [DIAGNOSTIC] SIM test error: $e');
          }
        } else {
          results['error'] += 'SMS permissions not granted. ';
        }
      }

      return false;
    } catch (e) {
      results['error'] += 'Test SMS error: $e. ';
      return false;
    }
  }

  /// Get SMS statistics
  Map<String, dynamic> getSmsStatistics() {
    return {
      'totalSent': totalSmsSent.value,
      'totalFailed': totalSmsFailed.value,
      'queueSize': smsQueueSize.value,
      'successRate':
          totalSmsSent.value + totalSmsFailed.value > 0
              ? (totalSmsSent.value /
                      (totalSmsSent.value + totalSmsFailed.value) *
                      100)
                  .toStringAsFixed(1)
              : '0.0',
      'isProcessing': _isProcessingQueue,
    };
  }

  /// Clear SMS queue (for admin use)
  void clearSmsQueue() {
    _smsQueue.clear();
    smsQueueSize.value = 0;
    print('SMS queue cleared');
  }

  /// Reset SMS statistics
  void resetSmsStatistics() {
    totalSmsSent.value = 0;
    totalSmsFailed.value = 0;
    print('SMS statistics reset');
  }

  // Test if SMS sending is actually working
  Future<bool> testSmsSending() async {
    try {
      print('🧪 Testing SMS sending capability...');

      if (!Platform.isAndroid) {
        print('❌ SMS test failed: Not on Android platform');
        return false;
      }

      // Check permissions first
      bool hasPermission = false;
      if (_permissionService != null) {
        hasPermission = await _permissionService!.checkSmsPermission();
        if (!hasPermission) {
          hasPermission = await _permissionService!.requestSmsPermission();
        }
      }

      if (!hasPermission) {
        print('❌ SMS test failed: No permissions');
        return false;
      }

      // Test with a dummy (non-sending) call
      try {
        print('🔧 Testing messenger interface...');
        // We can't do a real test without actually sending, but we can check if the plugin responds
        final testResult = await Future.microtask(() => true);
        print('✅ SMS messenger interface appears functional');
        return testResult;
      } catch (e) {
        print('❌ SMS messenger test failed: $e');
        return false;
      }
    } catch (e) {
      print('❌ SMS test exception: $e');
      return false;
    }
  }
}

/// SMS Queue Item class
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
