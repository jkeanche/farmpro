class SystemSettings {
  final String id;
  final bool enablePrinting;
  final bool enableSms;
  final bool enableSmsForCashSales;
  final bool enableSmsForCreditSales;
  final bool enableManualWeightEntry;
  final bool enableBluetoothScale;
  final String? defaultPrinterAddress;
  final String? defaultScaleAddress;
  final double coffeePrice;
  final String currency;
  final double defaultTareWeight; // Default tare weight for coffee containers
  final String printMethod; // 'bluetooth' or 'standard'
  final String coffeeProduct; // 'CHERRY' or 'MBUNI'
  final bool allowProductChange; // Can change product after collection starts
  final String? currentSeasonId;
  final bool enableInventory;
  final bool enableCreditSales;
  final int receiptDuplicates; // Number of receipt copies to print
  final bool
  autoDisconnectScale; // Automatically disconnect scale when leaving screen
  final String
  deliveryRestrictionMode; // 'single' or 'multiple' - controls daily delivery limit per member

  // SMS Gateway Configuration
  final bool smsGatewayEnabled; // Enable/disable SMS gateway usage
  final String smsGatewayUrl; // SMS gateway API endpoint URL
  final String smsGatewayUsername; // Gateway username/userid
  final String smsGatewayPassword; // Gateway password
  final String smsGatewaySenderId; // Sender ID for SMS messages
  final String smsGatewayApiKey; // API key for authentication
  final bool smsGatewayFallbackToSim; // Enable SIM fallback on gateway failure

  // Bulk SMS Settings
  final bool enableBulkSms; // Enable/disable bulk SMS functionality
  final String bulkSmsDefaultMessage; // Default message template for bulk SMS
  final bool bulkSmsIncludeBalance; // Include member balance in bulk SMS
  final bool bulkSmsIncludeName; // Include member name in bulk SMS
  final int bulkSmsMaxRecipients; // Maximum recipients per bulk SMS batch
  final int bulkSmsBatchDelay; // Delay between batches in seconds
  final bool bulkSmsConfirmBeforeSend; // Require confirmation before sending
  final String bulkSmsFilterType; // Filter type: 'all', 'credit', 'active'
  final bool bulkSmsLogActivity; // Log bulk SMS activity

  SystemSettings({
    required this.id,
    required this.enablePrinting,
    required this.enableSms,
    this.enableSmsForCashSales = false,
    this.enableSmsForCreditSales = true,
    required this.enableManualWeightEntry,
    required this.enableBluetoothScale,
    this.defaultPrinterAddress,
    this.defaultScaleAddress,
    this.coffeePrice = 80.0,
    this.currency = 'KES',
    this.defaultTareWeight = 0.5, // Default to 0.5 kg
    this.printMethod = 'bluetooth', // Default to bluetooth printing
    this.coffeeProduct = 'CHERRY', // Default to cherry
    this.allowProductChange = true,
    this.currentSeasonId,
    this.enableInventory = true,
    this.enableCreditSales = true,
    this.receiptDuplicates = 1,
    this.autoDisconnectScale = false,
    this.deliveryRestrictionMode =
        'multiple', // Default to multiple deliveries per day
    // SMS Gateway Configuration defaults
    this.smsGatewayEnabled = true, // Default to enabled for new installations
    this.smsGatewayUrl =
        'https://portal.zettatel.com/SMSApi/send', // Default Zettatel URL
    this.smsGatewayUsername = '', // Must be configured by user
    this.smsGatewayPassword = '', // Must be configured by user
    this.smsGatewaySenderId = 'FARMPRO', // Default sender ID
    this.smsGatewayApiKey = '', // Must be configured by user
    this.smsGatewayFallbackToSim = true, // Default to fallback enabled
    // Bulk SMS Settings defaults
    this.enableBulkSms = true, // Default to enabled
    this.bulkSmsDefaultMessage =
        'Dear {name}, your current balance is KSh {balance}. Thank you for your business.', // Default template
    this.bulkSmsIncludeBalance = true, // Default to include balance
    this.bulkSmsIncludeName = true, // Default to include name
    this.bulkSmsMaxRecipients = 50, // Default batch size
    this.bulkSmsBatchDelay = 2, // Default 2 seconds between batches
    this.bulkSmsConfirmBeforeSend = true, // Default to require confirmation
    this.bulkSmsFilterType = 'all', // Default to all members
    this.bulkSmsLogActivity = true, // Default to log activity
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    // Helper function to convert int to bool safely
    bool intToBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        final lowerValue = value.toLowerCase();
        return lowerValue == 'true' || lowerValue == '1';
      }
      return false; // Default value for any other type
    }

    // Helper function to safely get string values
    String safeString(dynamic value, String defaultValue) {
      if (value is String) return value;
      return defaultValue;
    }

    // Helper function to safely get numeric values
    double safeDouble(dynamic value, double defaultValue) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    // Helper function to safely get integer values
    int safeInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    return SystemSettings(
      id: safeString(json['id'], 'default'),
      enablePrinting: intToBool(json['enablePrinting']),
      enableSms: intToBool(json['enableSms']),
      enableSmsForCashSales: intToBool(json['enableSmsForCashSales'] ?? false),
      enableSmsForCreditSales: intToBool(
        json['enableSmsForCreditSales'] ?? true,
      ),
      enableManualWeightEntry: intToBool(json['enableManualWeightEntry']),
      enableBluetoothScale: intToBool(json['enableBluetoothScale']),
      defaultPrinterAddress: json['defaultPrinterAddress'] as String?,
      defaultScaleAddress: json['defaultScaleAddress'] as String?,
      coffeePrice: safeDouble(json['coffeePrice'], 80.0),
      currency: safeString(json['currency'], 'KES'),
      defaultTareWeight: safeDouble(json['defaultTareWeight'], 0.5),
      printMethod: safeString(json['printMethod'], 'bluetooth'),
      coffeeProduct: safeString(json['coffeeProduct'], 'CHERRY'),
      allowProductChange: intToBool(json['allowProductChange'] ?? true),
      currentSeasonId: json['currentSeasonId'] as String?,
      enableInventory: intToBool(json['enableInventory'] ?? true),
      enableCreditSales: intToBool(json['enableCreditSales'] ?? true),
      receiptDuplicates: safeInt(json['receiptDuplicates'], 1),
      autoDisconnectScale: intToBool(json['autoDisconnectScale'] ?? false),
      deliveryRestrictionMode: safeString(
        json['deliveryRestrictionMode'],
        'multiple',
      ),

      // SMS Gateway Configuration
      smsGatewayEnabled: intToBool(json['smsGatewayEnabled'] ?? true),
      smsGatewayUrl: safeString(
        json['smsGatewayUrl'],
        'https://portal.zettatel.com/SMSApi/send',
      ),
      smsGatewayUsername: safeString(json['smsGatewayUsername'], ''),
      smsGatewayPassword: safeString(json['smsGatewayPassword'], ''),
      smsGatewaySenderId: safeString(json['smsGatewaySenderId'], 'FARMPRO'),
      smsGatewayApiKey: safeString(json['smsGatewayApiKey'], ''),
      smsGatewayFallbackToSim: intToBool(
        json['smsGatewayFallbackToSim'] ?? true,
      ),

      // Bulk SMS Settings
      enableBulkSms: intToBool(json['enableBulkSms'] ?? true),
      bulkSmsDefaultMessage: safeString(
        json['bulkSmsDefaultMessage'],
        'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
      ),
      bulkSmsIncludeBalance: intToBool(json['bulkSmsIncludeBalance'] ?? true),
      bulkSmsIncludeName: intToBool(json['bulkSmsIncludeName'] ?? true),
      bulkSmsMaxRecipients: safeInt(json['bulkSmsMaxRecipients'], 50),
      bulkSmsBatchDelay: safeInt(json['bulkSmsBatchDelay'], 2),
      bulkSmsConfirmBeforeSend: intToBool(
        json['bulkSmsConfirmBeforeSend'] ?? true,
      ),
      bulkSmsFilterType: safeString(json['bulkSmsFilterType'], 'all'),
      bulkSmsLogActivity: intToBool(json['bulkSmsLogActivity'] ?? true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enablePrinting': enablePrinting,
      'enableSms': enableSms,
      'enableSmsForCashSales': enableSmsForCashSales,
      'enableSmsForCreditSales': enableSmsForCreditSales,
      'enableManualWeightEntry': enableManualWeightEntry,
      'enableBluetoothScale': enableBluetoothScale,
      'defaultPrinterAddress': defaultPrinterAddress,
      'defaultScaleAddress': defaultScaleAddress,
      'coffeePrice': coffeePrice,
      'currency': currency,
      'defaultTareWeight': defaultTareWeight,
      'printMethod': printMethod,
      'coffeeProduct': coffeeProduct,
      'allowProductChange': allowProductChange,
      'currentSeasonId': currentSeasonId,
      'enableInventory': enableInventory,
      'enableCreditSales': enableCreditSales,
      'receiptDuplicates': receiptDuplicates,
      'autoDisconnectScale': autoDisconnectScale,
      'deliveryRestrictionMode': deliveryRestrictionMode,

      // SMS Gateway Configuration
      'smsGatewayEnabled': smsGatewayEnabled,
      'smsGatewayUrl': smsGatewayUrl,
      'smsGatewayUsername': smsGatewayUsername,
      'smsGatewayPassword': smsGatewayPassword,
      'smsGatewaySenderId': smsGatewaySenderId,
      'smsGatewayApiKey': smsGatewayApiKey,
      'smsGatewayFallbackToSim': smsGatewayFallbackToSim,

      // Bulk SMS Settings
      'enableBulkSms': enableBulkSms,
      'bulkSmsDefaultMessage': bulkSmsDefaultMessage,
      'bulkSmsIncludeBalance': bulkSmsIncludeBalance,
      'bulkSmsIncludeName': bulkSmsIncludeName,
      'bulkSmsMaxRecipients': bulkSmsMaxRecipients,
      'bulkSmsBatchDelay': bulkSmsBatchDelay,
      'bulkSmsConfirmBeforeSend': bulkSmsConfirmBeforeSend,
      'bulkSmsFilterType': bulkSmsFilterType,
      'bulkSmsLogActivity': bulkSmsLogActivity,
    };
  }

  // Copy with method
  SystemSettings copyWith({
    String? id,
    bool? enablePrinting,
    bool? enableSms,
    bool? enableSmsForCashSales,
    bool? enableSmsForCreditSales,
    bool? enableManualWeightEntry,
    bool? enableBluetoothScale,
    String? defaultPrinterAddress,
    String? defaultScaleAddress,
    double? coffeePrice,
    String? currency,
    double? defaultTareWeight,
    String? printMethod,
    String? coffeeProduct,
    bool? allowProductChange,
    String? currentSeasonId,
    bool? enableInventory,
    bool? enableCreditSales,
    int? receiptDuplicates,
    bool? autoDisconnectScale,
    String? deliveryRestrictionMode,

    // SMS Gateway Configuration parameters
    bool? smsGatewayEnabled,
    String? smsGatewayUrl,
    String? smsGatewayUsername,
    String? smsGatewayPassword,
    String? smsGatewaySenderId,
    String? smsGatewayApiKey,
    bool? smsGatewayFallbackToSim,

    // Bulk SMS Settings parameters
    bool? enableBulkSms,
    String? bulkSmsDefaultMessage,
    bool? bulkSmsIncludeBalance,
    bool? bulkSmsIncludeName,
    int? bulkSmsMaxRecipients,
    int? bulkSmsBatchDelay,
    bool? bulkSmsConfirmBeforeSend,
    String? bulkSmsFilterType,
    bool? bulkSmsLogActivity,
  }) {
    return SystemSettings(
      id: id ?? this.id,
      enablePrinting: enablePrinting ?? this.enablePrinting,
      enableSms: enableSms ?? this.enableSms,
      enableSmsForCashSales:
          enableSmsForCashSales ?? this.enableSmsForCashSales,
      enableSmsForCreditSales:
          enableSmsForCreditSales ?? this.enableSmsForCreditSales,
      enableManualWeightEntry:
          enableManualWeightEntry ?? this.enableManualWeightEntry,
      enableBluetoothScale: enableBluetoothScale ?? this.enableBluetoothScale,
      defaultPrinterAddress:
          defaultPrinterAddress ?? this.defaultPrinterAddress,
      defaultScaleAddress: defaultScaleAddress ?? this.defaultScaleAddress,
      coffeePrice: coffeePrice ?? this.coffeePrice,
      currency: currency ?? this.currency,
      defaultTareWeight: defaultTareWeight ?? this.defaultTareWeight,
      printMethod: printMethod ?? this.printMethod,
      coffeeProduct: coffeeProduct ?? this.coffeeProduct,
      allowProductChange: allowProductChange ?? this.allowProductChange,
      currentSeasonId: currentSeasonId ?? this.currentSeasonId,
      enableInventory: enableInventory ?? this.enableInventory,
      enableCreditSales: enableCreditSales ?? this.enableCreditSales,
      receiptDuplicates: receiptDuplicates ?? this.receiptDuplicates,
      autoDisconnectScale: autoDisconnectScale ?? this.autoDisconnectScale,
      deliveryRestrictionMode:
          deliveryRestrictionMode ?? this.deliveryRestrictionMode,

      // SMS Gateway Configuration
      smsGatewayEnabled: smsGatewayEnabled ?? this.smsGatewayEnabled,
      smsGatewayUrl: smsGatewayUrl ?? this.smsGatewayUrl,
      smsGatewayUsername: smsGatewayUsername ?? this.smsGatewayUsername,
      smsGatewayPassword: smsGatewayPassword ?? this.smsGatewayPassword,
      smsGatewaySenderId: smsGatewaySenderId ?? this.smsGatewaySenderId,
      smsGatewayApiKey: smsGatewayApiKey ?? this.smsGatewayApiKey,
      smsGatewayFallbackToSim:
          smsGatewayFallbackToSim ?? this.smsGatewayFallbackToSim,

      // Bulk SMS Settings
      enableBulkSms: enableBulkSms ?? this.enableBulkSms,
      bulkSmsDefaultMessage:
          bulkSmsDefaultMessage ?? this.bulkSmsDefaultMessage,
      bulkSmsIncludeBalance:
          bulkSmsIncludeBalance ?? this.bulkSmsIncludeBalance,
      bulkSmsIncludeName: bulkSmsIncludeName ?? this.bulkSmsIncludeName,
      bulkSmsMaxRecipients: bulkSmsMaxRecipients ?? this.bulkSmsMaxRecipients,
      bulkSmsBatchDelay: bulkSmsBatchDelay ?? this.bulkSmsBatchDelay,
      bulkSmsConfirmBeforeSend:
          bulkSmsConfirmBeforeSend ?? this.bulkSmsConfirmBeforeSend,
      bulkSmsFilterType: bulkSmsFilterType ?? this.bulkSmsFilterType,
      bulkSmsLogActivity: bulkSmsLogActivity ?? this.bulkSmsLogActivity,
    );
  }
}
