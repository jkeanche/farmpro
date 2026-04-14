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
  final double defaultTareWeight;
  final String printMethod;
  final String coffeeProduct;
  final bool allowProductChange;
  final String? currentSeasonId;
  final bool enableInventory;
  final bool enableCreditSales;
  final int receiptDuplicates;
  final bool autoDisconnectScale;
  final String deliveryRestrictionMode;

  // SMS Mode: 'sim' = SIM card direct, 'gateway' = SMS gateway/bulk
  final String smsMode;

  // SMS Gateway Configuration
  final bool smsGatewayEnabled;
  final String smsGatewayUrl;
  final String smsGatewayUsername;
  final String smsGatewayPassword;
  final String smsGatewaySenderId;
  final String smsGatewayApiKey;
  final bool smsGatewayFallbackToSim;

  // Bulk SMS Settings
  final bool enableBulkSms;
  final String bulkSmsDefaultMessage;
  final bool bulkSmsIncludeBalance;
  final bool bulkSmsIncludeName;
  final int bulkSmsMaxRecipients;
  final int bulkSmsBatchDelay;
  final bool bulkSmsConfirmBeforeSend;
  final String bulkSmsFilterType;
  final bool bulkSmsLogActivity;

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
    this.defaultTareWeight = 0.5,
    this.printMethod = 'bluetooth',
    this.coffeeProduct = 'CHERRY',
    this.allowProductChange = true,
    this.currentSeasonId,
    this.enableInventory = true,
    this.enableCreditSales = true,
    this.receiptDuplicates = 1,
    this.autoDisconnectScale = false,
    this.deliveryRestrictionMode = 'multiple',
    // SMS mode defaults to 'sim' for backward compatibility
    this.smsMode = 'sim',
    // SMS Gateway Configuration defaults
    this.smsGatewayEnabled = false,
    this.smsGatewayUrl = 'https://portal.zettatel.com/SMSApi/send',
    this.smsGatewayUsername = '',
    this.smsGatewayPassword = '',
    this.smsGatewaySenderId = 'FARMPRO',
    this.smsGatewayApiKey = '',
    this.smsGatewayFallbackToSim = true,
    // Bulk SMS Settings defaults
    this.enableBulkSms = true,
    this.bulkSmsDefaultMessage =
        'Dear {name}, your current balance is KSh {balance}. Thank you for your business.',
    this.bulkSmsIncludeBalance = true,
    this.bulkSmsIncludeName = true,
    this.bulkSmsMaxRecipients = 50,
    this.bulkSmsBatchDelay = 2,
    this.bulkSmsConfirmBeforeSend = true,
    this.bulkSmsFilterType = 'all',
    this.bulkSmsLogActivity = true,
  });

  /// True when the user has selected Gateway as the SMS mode
  bool get isGatewayMode => smsMode == 'gateway';

  /// True when the gateway is properly configured for use
  bool get isGatewayConfigured =>
      smsGatewayUrl.isNotEmpty &&
      smsGatewayUsername.isNotEmpty &&
      smsGatewayPassword.isNotEmpty &&
      smsGatewaySenderId.isNotEmpty;

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    bool intToBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        final lowerValue = value.toLowerCase();
        return lowerValue == 'true' || lowerValue == '1';
      }
      return false;
    }

    String safeString(dynamic value, String defaultValue) {
      if (value is String) return value;
      return defaultValue;
    }

    double safeDouble(dynamic value, double defaultValue) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    int safeInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    // Derive smsMode from stored value or from legacy smsGatewayEnabled
    final rawSmsMode = safeString(json['smsMode'], '');
    final legacyGatewayEnabled = intToBool(json['smsGatewayEnabled'] ?? false);
    final resolvedSmsMode =
        rawSmsMode.isNotEmpty
            ? rawSmsMode
            : (legacyGatewayEnabled ? 'gateway' : 'sim');

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
      smsMode: resolvedSmsMode,
      smsGatewayEnabled: resolvedSmsMode == 'gateway',
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
      'smsMode': smsMode,
      'smsGatewayEnabled': isGatewayMode,
      'smsGatewayUrl': smsGatewayUrl,
      'smsGatewayUsername': smsGatewayUsername,
      'smsGatewayPassword': smsGatewayPassword,
      'smsGatewaySenderId': smsGatewaySenderId,
      'smsGatewayApiKey': smsGatewayApiKey,
      'smsGatewayFallbackToSim': smsGatewayFallbackToSim,
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
    String? smsMode,
    bool? smsGatewayEnabled,
    String? smsGatewayUrl,
    String? smsGatewayUsername,
    String? smsGatewayPassword,
    String? smsGatewaySenderId,
    String? smsGatewayApiKey,
    bool? smsGatewayFallbackToSim,
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
      smsMode: smsMode ?? this.smsMode,
      smsGatewayEnabled: smsGatewayEnabled ?? this.smsGatewayEnabled,
      smsGatewayUrl: smsGatewayUrl ?? this.smsGatewayUrl,
      smsGatewayUsername: smsGatewayUsername ?? this.smsGatewayUsername,
      smsGatewayPassword: smsGatewayPassword ?? this.smsGatewayPassword,
      smsGatewaySenderId: smsGatewaySenderId ?? this.smsGatewaySenderId,
      smsGatewayApiKey: smsGatewayApiKey ?? this.smsGatewayApiKey,
      smsGatewayFallbackToSim:
          smsGatewayFallbackToSim ?? this.smsGatewayFallbackToSim,
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
