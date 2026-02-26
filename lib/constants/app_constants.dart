class AppConstants {
  // App Info
  static const String appName = 'Coffee Pro';
  static const String appVersion = '1.0.0';
  static const String appDeveloper = 'Inuka Technologies';
  static const String appWebsite = 'www.codejar.tech';

  // Routes
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String membersRoute = '/members';
  static const String addMemberRoute = '/add-member';
  static const String memberDetailsRoute = '/member-details';
  static const String coffeeCollectionRoute = '/coffee-collection';
  static const String coffeeCollectionFormRoute = '/coffee-collection-form';
  static const String collectionHistoryRoute = '/collection-history';
  static const String reportsRoute = '/reports';
  static const String cropSearchRoute = '/crop-search';
  static const String settingsRoute = '/settings';
  static const String usersRoute = '/users';
  static const String navisionSettingsRoute = '/navision-settings';
  static const String navisionIntegrationRoute = '/navision-settings';

  static const String memberCollectionReportRoute = '/member-collection-report';
  static const String duplicateMembersRoute = '/duplicate-members';
  static const String bluetoothDebugRoute = '/settings/bluetooth-debug';
  static const String seasonManagementRoute = '/settings/season-management';

  // Settings Routes
  static const String userManagementRoute = '/settings/user-management';
  static const String systemSettingsRoute = '/settings/system-settings';
  static const String organizationSettingsRoute =
      '/settings/organization-settings';
  static const String smsManagementRoute = '/settings/sms-management';
  static const String smsTestRoute = '/settings/sms-test';

  // New Inventory Routes
  static const String inventoryRoute = '/inventory';
  static const String inventoryDashboardRoute = '/inventory/dashboard';
  static const String unitsOfMeasureRoute = '/inventory/units';
  static const String unitsRoute = '/inventory/units';
  static const String categoriesRoute = '/inventory/categories';
  static const String productsRoute = '/inventory/products';
  static const String addProductRoute = '/inventory/add-product';
  static const String stockRoute = '/inventory/stock';
  static const String stockManagementRoute = '/inventory/stock';
  static const String stockAdjustmentRoute = '/stock-adjustment';
  static const String salesRoute = '/inventory/sales';
  static const String salesReportRoute = '/inventory/sales-report';
  static const String addSaleRoute = '/inventory/add-sale';
  static const String creditSalesRoute = '/inventory/credit-sales';
  static const String repaymentRoute = '/inventory/repayment';
  static const String repaymentsRoute = '/inventory/repayment';
  static const String inventoryReportsRoute = '/inventory/reports';

  // Hive Box Names
  static const String membersBox = 'members';
  static const String collectionsBox = 'coffee_collections';
  static const String settingsBox = 'settings';
  static const String usersBox = 'users';
  static const String seasonsBox = 'seasons';
  static const String unitsBox = 'units';
  static const String categoriesBox = 'categories';
  static const String productsBox = 'products';
  static const String stockBox = 'stock';
  static const String salesBox = 'sales';
  static const String creditSalesBox = 'credit_sales';
  static const String repaymentsBox = 'repayments';

  // Settings Keys
  static const String orgSettingsKey = 'organization_settings';
  static const String sysSettingsKey = 'system_settings';
  static const String currentSeasonKey = 'current_season';
  static const String coffeeProductKey = 'coffee_product';

  // Coffee Product Types
  static const String cherryProduct = 'CHERRY';
  static const String mbuniProduct = 'MBUNI';

  // Default Values
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double defaultIconSize = 24.0;

  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Error Messages
  static const String genericErrorMessage =
      'An error occurred. Please try again.';
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String authErrorMessage =
      'Authentication failed. Please check your credentials.';
  static const String permissionErrorMessage =
      'You do not have permission to perform this action.';
  static const String seasonClosedMessage =
      'Current season is closed. Cannot perform this operation.';
  static const String productNotSelectedMessage =
      'Please select a coffee product in system settings.';

  // Success Messages
  static const String saveSuccessMessage = 'Changes saved successfully.';
  static const String addSuccessMessage = 'Added successfully.';
  static const String updateSuccessMessage = 'Updated successfully.';
  static const String deleteSuccessMessage = 'Deleted successfully.';
  static const String seasonStartedMessage = 'New season started successfully.';
  static const String seasonClosedSuccessMessage =
      'Season closed successfully.';

  // Bluetooth Messages
  static const String bluetoothNotEnabledMessage =
      'Bluetooth is not enabled. Please enable Bluetooth to continue.';
  static const String bluetoothNotSupportedMessage =
      'Bluetooth is not supported on this device.';
  static const String bluetoothScanningMessage =
      'Scanning for Bluetooth devices...';
  static const String bluetoothConnectingMessage = 'Connecting to device...';
  static const String bluetoothConnectedMessage = 'Connected to device.';
  static const String bluetoothDisconnectedMessage =
      'Disconnected from device.';

  // SMS Templates
  static const String saleReceiptSms =
      'Coffee Society Sale Receipt\nDate: {date}\nItems: {items}\nTotal: {currency} {amount}\nBalance: {currency} {balance}\nThank you!';
  static const String creditReminderSms =
      'Coffee Society Credit Reminder\nDear {name},\nYour outstanding balance is {currency} {amount}.\nKindly settle at your earliest convenience.';
}
