import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'controllers.dart';

class CoffeeCollectionController extends GetxController {
  CoffeeCollectionService? get _collectionService {
    try {
      return Get.find<CoffeeCollectionService>();
    } catch (e) {
      print('CoffeeCollectionService not found in controller: $e');
      return null;
    }
  }

  SeasonService? get _seasonService {
    try {
      return Get.find<SeasonService>();
    } catch (e) {
      print('SeasonService not found in controller: $e');
      return null;
    }
  }

  AuthService get _authService => Get.find<AuthService>();

  final RxBool isLoading = false.obs;
  final RxBool isCollecting = false.obs;
  final RxString error = ''.obs;

  // Form controllers
  final grossWeightController = TextEditingController();
  final tareWeightController = TextEditingController();
  final numberOfBagsController = TextEditingController();
  final Rx<Member?> selectedMember = Rx<Member?>(null);
  final RxDouble netWeight = 0.0.obs;
  final RxBool isManualEntry = false.obs;

  // Make collections reactive for real-time updates
  List<CoffeeCollection> get collections =>
      _collectionService?.collections ?? [];

  List<CoffeeCollection> get todaysCollections =>
      _collectionService?.todaysCollections ?? [];

  double get todaysTotalWeight => _collectionService?.todaysTotalWeight ?? 0.0;

  int get todaysTotalCollections =>
      _collectionService?.todaysTotalCollections ?? 0;

  // Flag to prevent duplicate SMS during operations
  bool _isSendingSMS = false;

  @override
  void onInit() {
    super.onInit();
    _setupWeightCalculation();
  }

  @override
  void onClose() {
    grossWeightController.dispose();
    tareWeightController.dispose();
    numberOfBagsController.dispose();
    super.onClose();
  }

  void _setupWeightCalculation() {
    // Auto-calculate net weight when gross or tare weight changes
    grossWeightController.addListener(_calculateNetWeight);
    tareWeightController.addListener(_calculateNetWeight);
  }

  void _calculateNetWeight() {
    final gross = double.tryParse(grossWeightController.text) ?? 0.0;
    final tare = double.tryParse(tareWeightController.text) ?? 0.0;
    netWeight.value = gross - tare;
  }

  // Get reactive collections list
  RxList<CoffeeCollection> get reactiveCollections {
    final service = _collectionService;
    if (service != null) {
      return service.reactiveCollections;
    }
    return <CoffeeCollection>[].obs;
  }

  Future<void> refreshCollections() async {
    if (_collectionService == null) {
      error.value = 'CoffeeCollectionService not available';
      return;
    }

    isLoading.value = true;
    error.value = '';

    try {
      // Force reload all collections from database
      await _collectionService!.loadCollections();
      await _collectionService!.loadTodaysCollections();

      // Trigger reactive updates
      update();

      print(
        'Collections refreshed - Total: ${collections.length}, Today: ${todaysCollections.length}',
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<CoffeeCollection?> addCollection() async {
    if (_collectionService == null) {
      error.value = 'CoffeeCollectionService not available';
      return null;
    }

    if (!_validateCollectionForm()) return null;

    isCollecting.value = true;
    error.value = '';

    try {
      final member = selectedMember.value!;
      final gross = double.parse(grossWeightController.text);
      final tare = double.parse(tareWeightController.text);
      final bags = int.tryParse(numberOfBagsController.text) ?? 1;
      final user = _authService.currentUser.value;

      final collection = await _collectionService!.addCollection(
        memberId: member.id,
        memberNumber: member.memberNumber,
        memberName: member.fullName,
        grossWeight: gross,
        tareWeight: tare,
        numberOfBags: bags,
        isManualEntry: isManualEntry.value,
        userId: user?.id,
        userName: user?.fullName,
      );

      if (collection != null) {
        _clearCollectionForm();
      }

      return collection;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    } finally {
      isCollecting.value = false;
    }
  }

  Future<List<CoffeeCollection>> getMemberCollections(
    String memberId, {
    String? seasonId,
  }) async {
    if (_collectionService == null) return [];
    return await _collectionService!.getMemberCollections(
      memberId,
      seasonId: seasonId,
    );
  }

  Future<Map<String, dynamic>> getMemberSeasonSummary(
    String memberId, {
    String? seasonId,
  }) async {
    if (_collectionService == null) return {};
    return await _collectionService!.getMemberSeasonSummary(
      memberId,
      seasonId: seasonId,
    );
  }

  Future<Map<String, dynamic>> getSeasonSummary({String? seasonId}) async {
    if (_collectionService == null) return {};
    return await _collectionService!.getSeasonSummary(seasonId: seasonId);
  }

  Future<bool> updateCollection(CoffeeCollection collection) async {
    if (_collectionService == null) return false;

    try {
      final success = await _collectionService!.updateCollection(collection);
      if (success) {
        await refreshCollections();
      }
      return success;
    } catch (e) {
      error.value = e.toString();
      return false;
    }
  }

  Future<bool> deleteCollection(String collectionId) async {
    if (_collectionService == null) return false;

    try {
      // Get collection details before deletion for SMS
      final collections = _collectionService!.collections;
      final collection = collections.firstWhereOrNull(
        (c) => c.id == collectionId,
      );

      final success = await _collectionService!.deleteCollection(collectionId);
      if (success) {
        // Send deletion SMS notification
        if (collection != null) {
          await sendCollectionUpdateSMS(collection, isEdit: false);
        }

        await refreshCollections();
      }
      return success;
    } catch (e) {
      error.value = e.toString();
      return false;
    }
  }

  bool _validateCollectionForm() {
    if (selectedMember.value == null) {
      error.value = 'Please select a member';
      return false;
    }

    if (_seasonService == null || !_seasonService!.canStartCollection()) {
      error.value = AppConstants.seasonClosedMessage;
      return false;
    }

    if (grossWeightController.text.trim().isEmpty) {
      error.value = 'Gross weight is required';
      return false;
    }

    final gross = double.tryParse(grossWeightController.text);
    if (gross == null || gross <= 0) {
      error.value = 'Please enter a valid gross weight';
      return false;
    }

    final tare = double.tryParse(tareWeightController.text) ?? 0.0;
    if (tare < 0) {
      error.value = 'Tare weight cannot be negative';
      return false;
    }

    if (gross <= tare) {
      error.value = 'Gross weight must be greater than tare weight';
      return false;
    }

    return true;
  }

  void _clearCollectionForm() {
    selectedMember.value = null;
    grossWeightController.clear();
    tareWeightController.clear();
    numberOfBagsController.clear();
    netWeight.value = 0.0;
    isManualEntry.value = false;
    error.value = '';
  }

  void setSelectedMember(Member member) {
    selectedMember.value = member;
  }

  void setManualEntry(bool manual) {
    isManualEntry.value = manual;
  }

  void setGrossWeight(double weight) {
    grossWeightController.text = weight.toString();
    _calculateNetWeight();
  }

  void setTareWeight(double weight) {
    tareWeightController.text = weight.toString();
    _calculateNetWeight();
  }

  String get currentSeasonDisplay =>
      _seasonService?.currentSeasonDisplay ?? 'No Season';

  bool get canCollect =>
      _seasonService != null && _seasonService!.canStartCollection();

  void showCollectionForm() {
    _clearCollectionForm();
  }

  // Print receipt for collection
  Future<void> printCollectionReceipt(CoffeeCollection collection) async {
    try {
      final printService = Get.find<PrintService>();
      await printService.printCoffeeCollectionReceipt(collection);
    } catch (e) {
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: ${e.toString()}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  // Send SMS for collection using robust queue system
  Future<void> sendCollectionSMS(CoffeeCollection collection) async {
    // Prevent duplicate SMS sending
    if (_isSendingSMS) {
      print(
        'SMS sending already in progress for ${collection.memberName}, skipping duplicate',
      );
      return;
    }

    _isSendingSMS = true;

    try {
      final smsService = Get.find<SmsService>();
      final settingsService = Get.find<SettingsService>();
      final memberService = Get.find<MemberService>();

      // Check if SMS is enabled
      final sysSettings = settingsService.systemSettings.value;
      if (sysSettings.enableSms != true) {
        print('SMS is disabled in system settings');
        return;
      }

      print(
        'Attempting to send collection SMS for collection ${collection.receiptNumber}',
      );

      // Get member to validate phone number
      final member = await memberService.getMemberById(collection.memberId);
      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print('No phone number available for member ${collection.memberName}');
        return;
      }

      // Validate phone number before proceeding
      final validatedNumber = smsService.validateKenyanPhoneNumber(
        member.phoneNumber!,
      );
      if (validatedNumber == null) {
        print(
          'Invalid phone number for member ${collection.memberName}: ${member.phoneNumber} - Kenyan phone validation failed',
        );
        Get.snackbar(
          'SMS Warning',
          'Invalid phone number for ${collection.memberName}: ${member.phoneNumber}. Please update to valid Kenyan format.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final orgSettings = settingsService.organizationSettings.value;
      final societyName = orgSettings.societyName;
      final factoryName = orgSettings.factory;

      // Compute cumulative weight by summing netWeight of all season collections.
      // This guarantees tare weight is never included — netWeight is always
      // grossWeight − tareWeight as stored on each CoffeeCollection record.
      final seasonId = _seasonService?.currentSeason?.id;
      final memberCollections = await getMemberCollections(
        collection.memberId,
        seasonId: seasonId,
      );
      final allTimeCumulativeWeight = memberCollections.fold<double>(
        0.0,
        (sum, c) => sum + c.netWeight,
      );

      print(
        '[SMS] Cumulative net weight for ${collection.memberName}: '
        '$allTimeCumulativeWeight kg (${memberCollections.length} collections, '
        'season: ${seasonId ?? "all"})',
      );

      final receiptNo = collection.receiptNumber ?? 'N/A';
      final formattedDate = DateFormat(
        'dd/MM/yy',
      ).format(collection.collectionDate);

      final message = '''${societyName.toUpperCase()}
Fac:$factoryName
T/No:$receiptNo
Date:$formattedDate
M/No:${collection.memberNumber}
M/Name:${collection.memberName}
Type:${collection.productType}
Kgs:${collection.netWeight.toStringAsFixed(1)}
Bags:${collection.numberOfBags}
Total:${allTimeCumulativeWeight.toStringAsFixed(1)} kg
Served By:${collection.userName ?? 'N/A'}''';

      print('Sending SMS immediately to $validatedNumber for collection');

      // Send SMS immediately with robust retry logic
      final success = await smsService.sendSmsRobust(
        validatedNumber,
        message,
        maxRetries: 3,
        priority: 2,
      );

      if (!success) {
        print('❌ [SMS] Failed to deliver collection SMS to $validatedNumber');
      }
    } catch (e) {
      print('Failed to send collection SMS: $e');
      Get.snackbar(
        'SMS Error',
        'Error sending collection notification: ${e.toString()}',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isSendingSMS = false;
    }
  }

  // Send robust SMS for collection update/deletion notifications
  Future<void> sendCollectionUpdateSMS(
    CoffeeCollection collection, {
    required bool isEdit,
  }) async {
    // Prevent duplicate SMS sending
    if (_isSendingSMS) {
      print(
        'SMS sending already in progress for ${collection.memberName}, skipping duplicate',
      );
      return;
    }

    _isSendingSMS = true;

    try {
      final smsService = Get.find<SmsService>();
      final settingsService = Get.find<SettingsService>();
      final memberService = Get.find<MemberService>();

      print(
        'Attempting to send ${isEdit ? "update" : "deletion"} SMS for collection ${collection.receiptNumber}',
      );

      // Get member to validate phone number
      final member = await memberService.getMemberById(collection.memberId);
      if (member?.phoneNumber == null || member!.phoneNumber!.isEmpty) {
        print('No phone number available for member ${collection.memberName}');
        return;
      }

      // Validate phone number before proceeding
      final validatedNumber = smsService.validateKenyanPhoneNumber(
        member.phoneNumber!,
      );
      if (validatedNumber == null) {
        print(
          'Invalid phone number for member ${collection.memberName}: ${member.phoneNumber} - Kenyan phone validation failed',
        );
        Get.snackbar(
          'SMS Warning',
          'Invalid phone number for ${collection.memberName}: ${member.phoneNumber}. Please update to valid Kenyan format.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final orgSettings = settingsService.organizationSettings.value;
      final societyName = orgSettings.societyName;

      // Compute new cumulative weight by summing netWeight of all season
      // collections after the edit/deletion has already been applied to the DB.
      // Using netWeight ensures gross weight and tare weight are never mixed up.
      final seasonId = _seasonService?.currentSeason?.id;
      final memberCollections = await getMemberCollections(
        collection.memberId,
        seasonId: seasonId,
      );
      final newAllTimeCumulativeWeight = memberCollections.fold<double>(
        0.0,
        (sum, c) => sum + c.netWeight,
      );

      print(
        '✅ [SMS] Updated cumulative net weight for ${collection.memberName}: '
        '$newAllTimeCumulativeWeight kg (${memberCollections.length} collections)',
      );

      // Create SMS message
      String message;
      if (isEdit) {
        message = '''Your coffee collection has been updated:
Updated details:
Date: ${DateFormat('dd/MM/yy').format(collection.collectionDate)}
Weight: ${collection.netWeight.toStringAsFixed(1)} kg
Bags: ${collection.numberOfBags}
Receipt #: ${collection.receiptNumber ?? "N/A"}
Total: ${newAllTimeCumulativeWeight.toStringAsFixed(1)} kg
$societyName''';
      } else {
        message = '''Coffee collection record removed:
Removed details:
Date: ${DateFormat('dd/MM/yy').format(collection.collectionDate)}
Weight: ${collection.netWeight.toStringAsFixed(1)} kg
Bags: ${collection.numberOfBags}
Receipt #: ${collection.receiptNumber ?? "N/A"}
New total: ${newAllTimeCumulativeWeight.toStringAsFixed(1)} kg
$societyName''';
      }

      print(
        'Sending SMS immediately to $validatedNumber for collection ${isEdit ? "update" : "deletion"}',
      );

      // Send SMS immediately with robust retry logic
      final success = await smsService.sendSmsRobust(
        validatedNumber,
        message,
        maxRetries: 3,
        priority: 1,
      );

      if (!success) {
        print(
          '❌ [SMS] Failed to deliver ${isEdit ? "update" : "deletion"} SMS to $validatedNumber',
        );
      }
    } catch (e) {
      print(
        'Failed to send collection ${isEdit ? "update" : "deletion"} SMS: $e',
      );
      // Don't block the UI for SMS issues
    } finally {
      _isSendingSMS = false;
    }
  }

  // Import collections from CSV
  Future<List<CoffeeCollection>> importCollectionsFromCsv() async {
    if (_collectionService == null) {
      error.value = 'CoffeeCollectionService not available';
      return [];
    }

    isLoading.value = true;
    error.value = '';

    try {
      final importedCollections =
          await _collectionService!.importCollectionsFromCsv();

      // Force refresh all collections data to ensure imported data appears in filters
      await refreshCollections();

      // Also refresh today's collections if any were imported for today
      await _collectionService!.loadTodaysCollections();

      // Force refresh all related controllers to ensure UI updates
      try {
        // Refresh season data which is used in reports
        final seasonController = Get.find<SeasonController>();
        await seasonController.refreshSeasons();

        // Update all GetX controllers
        update();

        print('All related controllers refreshed after collection import');
      } catch (e) {
        print('Error refreshing related controllers: $e');
      }

      // Notify listeners that collections have been updated
      update();

      print(
        'Successfully imported ${importedCollections.length} collections and refreshed data',
      );

      return importedCollections;
    } catch (e) {
      error.value = e.toString();
      print('Error importing collections from CSV: $e');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  // Download CSV template for collection import
  Future<void> downloadCollectionImportTemplate() async {
    if (_collectionService == null) {
      error.value = 'CoffeeCollectionService not available';
      return;
    }

    isLoading.value = true;
    error.value = '';

    try {
      final file = await _collectionService!.downloadCollectionImportTemplate();

      if (file != null) {
        // Share the template file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Coffee Collection Import Template');

        Get.snackbar(
          'Success',
          'CSV template downloaded and ready to share',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        error.value = 'Failed to create CSV template';
        Get.snackbar(
          'Error',
          'Failed to create CSV template',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to create CSV template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
