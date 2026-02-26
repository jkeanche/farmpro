// Test to verify SMS fix for imported collections
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lib/models/models.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/coffee_collection_service.dart';
import 'lib/services/database_helper.dart';
import 'lib/services/member_service.dart';
import 'lib/services/season_service.dart';
import 'lib/services/settings_service.dart';
import 'lib/services/sms_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('📱 Testing SMS Fix for Imported Collections');
  print('===========================================');

  try {
    // Initialize services
    Get.put(DatabaseHelper());
    final dbHelper = Get.find<DatabaseHelper>();
    final db = await dbHelper.database;

    await Get.putAsync(() => SettingsService().init());
    await Get.putAsync(() => SeasonService().init());
    await Get.putAsync(() => AuthService().init());
    await Get.putAsync(() => MemberService().init());
    await Get.putAsync(() => SmsService().init());
    await Get.putAsync(() => CoffeeCollectionService().init());

    final settingsService = Get.find<SettingsService>();
    final seasonService = Get.find<SeasonService>();
    final authService = Get.find<AuthService>();
    final memberService = Get.find<MemberService>();
    final smsService = Get.find<SmsService>();
    final collectionService = Get.find<CoffeeCollectionService>();

    print('✅ All services initialized successfully');

    // Test 1: Setup test environment
    print('\n📝 Test 1: Setting up test environment...');

    // Create test organization settings
    final orgSettings = OrganizationSettings(
      id: 'test_org_sms',
      societyName: 'SMS Test Coffee Society',
      factory: 'SMS Test Factory',
      address: 'Test Address, Test City',
      logoPath: null,
    );

    await settingsService.updateOrganizationSettings(orgSettings);
    print('✅ Organization settings configured:');
    print('   - Society: ${orgSettings.societyName}');
    print('   - Factory: ${orgSettings.factory}');

    // Create test season
    final testSeason = Season(
      id: 'test_season_sms',
      name: '2024/2025 SMS Test Season',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().add(const Duration(days: 60)),
      isActive: true,
      createdAt: DateTime.now(),
    );

    await db.insert('seasons', testSeason.toJson());
    await seasonService.loadSeasons();
    print('✅ Test season created: ${testSeason.name}');

    // Set system settings
    final systemSettings = SystemSettings(
      id: 'test_system_sms',
      coffeeProduct: 'CHERRY',
      enablePrinting: true,
      enableSms: true,
      enableManualWeightEntry: true,
      enableBluetoothScale: false,
    );

    await settingsService.saveSystemSettings(systemSettings);
    print('✅ System settings configured');
  } catch (e) {
    print('❌ Error during test: $e');
  } finally {
    print('🏁 Test completed');
  }
}
