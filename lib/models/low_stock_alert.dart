class LowStockAlert {
  final String id;
  final String productId;
  final String productName;
  final String categoryId;
  final String categoryName;
  final double currentQuantity;
  final double minimumLevel;
  final double shortfall;
  final DateTime alertDate;
  final String severity; // 'low', 'critical', 'out_of_stock'
  final bool isAcknowledged;
  final DateTime? acknowledgedDate;
  final String? acknowledgedBy;

  LowStockAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.categoryName,
    required this.currentQuantity,
    required this.minimumLevel,
    required this.shortfall,
    required this.alertDate,
    required this.severity,
    this.isAcknowledged = false,
    this.acknowledgedDate,
    this.acknowledgedBy,
  });

  factory LowStockAlert.fromJson(Map<String, dynamic> json) {
    return LowStockAlert(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      currentQuantity: (json['currentQuantity'] as num).toDouble(),
      minimumLevel: (json['minimumLevel'] as num).toDouble(),
      shortfall: (json['shortfall'] as num).toDouble(),
      alertDate: DateTime.parse(json['alertDate'] as String),
      severity: json['severity'] as String,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      acknowledgedDate: json['acknowledgedDate'] != null
          ? DateTime.parse(json['acknowledgedDate'] as String)
          : null,
      acknowledgedBy: json['acknowledgedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'currentQuantity': currentQuantity,
      'minimumLevel': minimumLevel,
      'shortfall': shortfall,
      'alertDate': alertDate.toIso8601String(),
      'severity': severity,
      'isAcknowledged': isAcknowledged,
      'acknowledgedDate': acknowledgedDate?.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
    };
  }

  LowStockAlert copyWith({
    String? id,
    String? productId,
    String? productName,
    String? categoryId,
    String? categoryName,
    double? currentQuantity,
    double? minimumLevel,
    double? shortfall,
    DateTime? alertDate,
    String? severity,
    bool? isAcknowledged,
    DateTime? acknowledgedDate,
    String? acknowledgedBy,
  }) {
    return LowStockAlert(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minimumLevel: minimumLevel ?? this.minimumLevel,
      shortfall: shortfall ?? this.shortfall,
      alertDate: alertDate ?? this.alertDate,
      severity: severity ?? this.severity,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedDate: acknowledgedDate ?? this.acknowledgedDate,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }

  @override
  String toString() {
    return 'LowStockAlert(id: $id, productName: $productName, currentQuantity: $currentQuantity, minimumLevel: $minimumLevel, severity: $severity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LowStockAlert &&
        other.id == id &&
        other.productId == productId &&
        other.currentQuantity == currentQuantity &&
        other.minimumLevel == minimumLevel &&
        other.severity == severity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        productId.hashCode ^
        currentQuantity.hashCode ^
        minimumLevel.hashCode ^
        severity.hashCode;
  }
}