import 'package:get/get.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/coffee_home_screen.dart';
import '../screens/coffee_collection/coffee_collection_form.dart';
import '../screens/season/season_management_screen.dart';
import '../screens/inventory/inventory_dashboard_screen.dart';
import '../screens/inventory/products_screen.dart';
import '../screens/inventory/categories_screen.dart';
import '../screens/inventory/stock_screen.dart';
import '../screens/inventory/stock_adjustment_screen.dart';
import '../screens/inventory/stock_management_screen.dart';
import '../screens/inventory/units_screen.dart';
import '../screens/inventory/sales_screen.dart';
import '../screens/inventory/sales_report_screen.dart';
import '../screens/inventory/credit_sales_screen.dart';
import '../screens/inventory/repayments_screen.dart';
import '../screens/inventory/inventory_reports_screen.dart';
import '../screens/members/members_screen.dart';
import '../screens/members/add_member_screen.dart';
import '../screens/members/member_collection_report_screen.dart';
import '../screens/members/duplicate_members_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/crop_search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/settings/system_settings_screen.dart';
import '../screens/settings/organization_settings_screen.dart';
import '../screens/settings/sms_management_screen.dart';
import '../screens/settings/sms_test_screen.dart';
import '../screens/settings/bluetooth_debug_screen.dart';
import '../screens/settings/navision_settings_screen.dart';
import '../constants/app_constants.dart';

class AppRoutes {
  static final routes = [
    GetPage(
      name: AppConstants.loginRoute,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppConstants.homeRoute,
      page: () => const CoffeeHomeScreen(),
    ),
    GetPage(
      name: AppConstants.coffeeCollectionFormRoute,
      page: () => const CoffeeCollectionForm(),
    ),
    GetPage(
      name: AppConstants.seasonManagementRoute,
      page: () => const SeasonManagementScreen(),
    ),
    GetPage(
      name: AppConstants.inventoryDashboardRoute,
      page: () => const InventoryDashboardScreen(),
    ),
    GetPage(
      name: AppConstants.productsRoute,
      page: () => const ProductsScreen(),
    ),
    GetPage(
      name: AppConstants.categoriesRoute,
      page: () => const CategoriesScreen(),
    ),
    GetPage(
      name: AppConstants.stockRoute,
      page: () => const StockScreen(),
    ),
    GetPage(
      name: AppConstants.stockAdjustmentRoute,
      page: () => const StockAdjustmentScreen(),
    ),
    GetPage(
      name: AppConstants.stockManagementRoute,
      page: () => const StockManagementScreen(),
    ),
    GetPage(
      name: AppConstants.unitsRoute,
      page: () => const UnitsScreen(),
    ),
    GetPage(
      name: AppConstants.salesRoute,
      page: () => const SalesScreen(),
    ),
    GetPage(
      name: AppConstants.salesReportRoute,
      page: () => const SalesReportScreen(),
    ),
    GetPage(
      name: AppConstants.creditSalesRoute,
      page: () => const CreditSalesScreen(),
    ),
    GetPage(
      name: AppConstants.repaymentsRoute,
      page: () => const RepaymentsScreen(),
    ),
    GetPage(
      name: AppConstants.inventoryReportsRoute,
      page: () => const InventoryReportsScreen(),
    ),
    GetPage(
      name: AppConstants.membersRoute,
      page: () => const MembersScreen(),
    ),
    GetPage(
      name: AppConstants.addMemberRoute,
      page: () => const AddMemberScreen(),
    ),
    GetPage(
      name: AppConstants.duplicateMembersRoute,
      page: () => const DuplicateMembersScreen(),
    ),
    GetPage(
      name: AppConstants.memberCollectionReportRoute,
      page: () => const MemberCollectionReportScreen(),
    ),
    GetPage(
      name: AppConstants.reportsRoute,
      page: () => const ReportsScreen(),
    ),
    GetPage(
      name: AppConstants.cropSearchRoute,
      page: () => const CropSearchScreen(),
    ),
    GetPage(
      name: AppConstants.settingsRoute,
      page: () => const SettingsScreen(),
    ),
    GetPage(
      name: AppConstants.userManagementRoute,
      page: () => const UserManagementScreen(),
    ),
    GetPage(
      name: AppConstants.systemSettingsRoute,
      page: () => const SystemSettingsScreen(),
    ),
    GetPage(
      name: AppConstants.organizationSettingsRoute,
      page: () => const OrganizationSettingsScreen(),
    ),
    GetPage(
      name: AppConstants.smsManagementRoute,
      page: () => const SmsManagementScreen(),
    ),
    GetPage(
      name: AppConstants.smsTestRoute,
      page: () => const SmsTestScreen(),
    ),
    GetPage(
      name: AppConstants.bluetoothDebugRoute,
      page: () => const BluetoothDebugScreen(),
    ),
    GetPage(
      name: AppConstants.navisionIntegrationRoute,
      page: () => const NavisionSettingsScreen(),
    ),
  ];
}
