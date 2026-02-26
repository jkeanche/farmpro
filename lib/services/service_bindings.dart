import 'package:get/get.dart';
import 'bluetooth_service.dart';
import 'gap_scale_service.dart';
import 'database_helper.dart';
import 'auth_service.dart';
import 'member_service.dart';
import 'optimized_member_service.dart';

import 'coffee_collection_service.dart';
import 'inventory_service.dart';
import 'season_service.dart';
import 'settings_service.dart';
import 'print_service.dart';
import 'sms_service.dart';
import 'permission_service.dart';
import 'navision_service.dart';

import '../controllers/controllers.dart';

class ServiceBindings extends Bindings {
  @override
  void dependencies() {
    // Register the GapScaleService
    Get.lazyPut<GapScaleService>(() => GapScaleService(), fenix: true);
    
    // Make sure the BluetoothService is available
    if (!Get.isRegistered<BluetoothService>()) {
      Get.lazyPut<BluetoothService>(() => BluetoothService(), fenix: true);
    }

    // Database
    Get.put(DatabaseHelper(), permanent: true);
    
    // Services
    Get.put(AuthService(), permanent: true);
    Get.put(MemberService(), permanent: true);
    Get.put(OptimizedMemberService(), permanent: true);

    Get.put(CoffeeCollectionService(), permanent: true);
    Get.put(InventoryService(), permanent: true);
    Get.put(SeasonService(), permanent: true);
    Get.put(SettingsService(), permanent: true);
    Get.put(BluetoothService(), permanent: true);
    Get.put(PrintService(), permanent: true);
    Get.put(SmsService(), permanent: true);
    Get.put(PermissionService(), permanent: true);
    Get.put(GapScaleService(), permanent: true);
    Get.put(NavisionService(baseUrl: ''), permanent: true);
    
    // Controllers
    Get.put(AuthController(), permanent: true);
    Get.put(MemberController(), permanent: true);
    Get.put(CoffeeCollectionController(), permanent: true);
    Get.put(SeasonController(), permanent: true);
    Get.put(InventoryController(), permanent: true);
    Get.put(SettingsController(), permanent: true);
    
    // Initialize services that have init methods
    _initializeServices();
  }
  
  void _initializeServices() async {
    try {
      await Get.find<AuthService>().init();
      await Get.find<MemberService>().init();
      await Get.find<OptimizedMemberService>().init();

      await Get.find<CoffeeCollectionService>().init();
      await Get.find<InventoryService>().init();
      await Get.find<SeasonService>().init();
      await Get.find<SettingsService>().init();
      await Get.find<BluetoothService>().init();
      await Get.find<PrintService>().init();
      await Get.find<SmsService>().init();
      await Get.find<PermissionService>().init();
      // Note: GapScaleService and NavisionService don't have init methods
    } catch (e) {
      print('Error initializing services: $e');
    }
  }
} 