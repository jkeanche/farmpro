import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'constants/app_constants.dart';
import 'controllers/controllers.dart';
import 'routes/app_routes.dart';
import 'services/database_helper.dart';
import 'services/gap_scale_service.dart';
import 'services/services.dart';
import 'themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('Starting Coffee Pro app initialization...');

    // Initialize SQLite for all platforms
    if (!kIsWeb) {
      print('Initializing SQLite...');
      // Initialize FFI for all platforms
      sqfliteFfiInit();

      // Set database factory based on platform
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use FFI
        databaseFactory = databaseFactoryFfi;
      }
    }

    print('Initializing critical services...');
    // Initialize only critical services for app launch
    await _initCriticalServices();

    print('Initializing controllers...');
    // Initialize Controllers
    _initControllers();

    print('Starting app...');
    runApp(const CoffeeProApp());

    // Initialize non-critical services in background after app starts
    _initNonCriticalServicesInBackground();
  } catch (e, stackTrace) {
    print('Error during initialization: $e');
    print('Stack trace: $stackTrace');
    runApp(DebugApp(error: e.toString()));
  }
}

class DebugApp extends StatelessWidget {
  final String error;

  const DebugApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Debug Mode'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'An error occurred during initialization:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(error, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _initCriticalServices() async {
  print('Initializing DatabaseHelper...');
  // Initialize DatabaseHelper first
  Get.put(DatabaseHelper());

  print('Initializing PermissionService...');
  // Initialize PermissionService early since other services depend on it
  await Get.putAsync(() => PermissionService().init()).timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      print('PermissionService initialization timed out');
      Get.put(PermissionService()); // Put a basic instance
      return PermissionService();
    },
  );

  print('Initializing SettingsService...');
  // Initialize SettingsService early since other services depend on it
  await Get.putAsync(() => SettingsService().init()).timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      print('SettingsService initialization timed out');
      throw Exception('SettingsService initialization timed out');
    },
  );

  print('Initializing AuthService...');
  // Initialize AuthService for login functionality
  await Get.putAsync(() => AuthService().init()).timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      print('AuthService initialization timed out');
      throw Exception('AuthService initialization timed out');
    },
  );

  print('Critical services initialized successfully');
}

void _initNonCriticalServicesInBackground() {
  // Initialize non-critical services using lazy loading like farm_fresh
  print('Setting up lazy services...');

  // Initialize services that depend on critical services first
  Get.lazyPut(() => MemberService()..init(), fenix: true);
  Get.lazyPut(() => SeasonService()..init(), fenix: true);

  // Initialize services that depend on the above
  Get.lazyPut(() => CoffeeCollectionService()..init(), fenix: true);

  Get.lazyPut(() => InventoryService()..init(), fenix: true);

  // Initialize optional services
  Get.lazyPut(() => BluetoothService()..init(), fenix: true);
  Get.lazyPut(() => PrintService()..init(), fenix: true);
  Get.lazyPut(() => SmsService()..init(), fenix: true);
  Get.lazyPut(() => GapScaleService(), fenix: true);

  // Initialize NavisionService with base URL from settings
  Get.lazyPut(() {
    try {
      // This will be resolved when the service is first accessed
      return NavisionService(
        baseUrl: 'https://api.businesscentral.dynamics.com',
      );
    } catch (e) {
      print('Warning: Could not initialize NavisionService: $e');
      return NavisionService(
        baseUrl: 'https://api.businesscentral.dynamics.com',
      );
    }
  }, fenix: true);

  print('All lazy services registered successfully');
}

void _initControllers() {
  // Initialize critical Controllers immediately
  Get.put(AuthController());
  Get.put(SettingsController());

  // Initialize other controllers lazily when needed (like farm_fresh)
  Get.lazyPut(() => MemberController(), fenix: true);
  Get.lazyPut(() => CoffeeCollectionController(), fenix: true);
  Get.lazyPut(() => SeasonController(), fenix: true);
  Get.lazyPut(() => InventoryController(), fenix: true);
}

class CoffeeProApp extends StatefulWidget {
  const CoffeeProApp({super.key});

  @override
  State<CoffeeProApp> createState() => _CoffeeProAppState();
}

class _CoffeeProAppState extends State<CoffeeProApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    print('CoffeeProApp widget initialized');
    // Add app lifecycle observer to handle app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Ensure Bluetooth disconnection on app exit
    _handleAppExit();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App is paused but not necessarily closed
        print('App paused - maintaining Bluetooth connections');
        break;
      case AppLifecycleState.resumed:
        // App is resumed
        print('App resumed');
        break;
      case AppLifecycleState.detached:
        // App is about to be terminated
        print('App detached - disconnecting from Bluetooth devices');
        _handleAppExit();
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., during phone call)
        print('App inactive');
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        print('App hidden');
        break;
    }
  }

  Future<void> _handleAppExit() async {
    try {
      print('Handling app exit - disconnecting Bluetooth devices...');

      // Try to disconnect from Bluetooth devices
      if (Get.isRegistered<BluetoothService>()) {
        final bluetoothService = Get.find<BluetoothService>();
        await bluetoothService.disconnectScale();
        print('Bluetooth scale disconnected on app exit');
      }

      // Try to disconnect from GAP scale
      if (Get.isRegistered<GapScaleService>()) {
        final gapScaleService = Get.find<GapScaleService>();
        await gapScaleService.disconnect();
        print('GAP scale disconnected on app exit');
      }
    } catch (e) {
      print('Error during app exit cleanup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building CoffeeProApp widget');
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      builder: (_, child) {
        print('ScreenUtilInit builder called');
        return GetMaterialApp(
          title: AppConstants.appName,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          initialRoute:
              AppConstants
                  .loginRoute, // Start with login, will handle navigation in AuthController
          getPages: AppRoutes.routes,
          defaultTransition: Transition.fadeIn,
        );
      },
    );
  }
}
