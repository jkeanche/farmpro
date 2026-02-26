class StockAdjustmentHistory {
  final String id;
  final String productId;
  final String productName;
  final String categoryId;
  final String categoryName;
  final double quantityAdjusted;
  final double previousQuantity;
  final double newQuantity;
  final String adjustmentType; // 'increase', 'decrease', 'correction'
  final String reason;
  final DateTime adjustmentDate;
  final String userId;
  final String userName;
  final String? notes;

  StockAdjustmentHistory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.categoryName,
    required this.quantityAdjusted,
    required this.previousQuantity,
    required this.newQuantity,
    required this.adjustmentType,
    required this.reason,
    required this.adjustmentDate,
    required this.userId,
    required this.userName,
    this.notes,
  });

  factory StockAdjustmentHistory.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentHistory(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
      quantityAdjusted: json['quantityAdjusted'].toDouble(),
      previousQuantity: json['previousQuantity'].toDouble(),
      newQuantity: json['newQuantity'].toDouble(),
      adjustmentType: json['adjustmentType'],
      reason: json['reason'],
      adjustmentDate: DateTime.parse(json['adjustmentDate']),
      userId: json['userId'],
      userName: json['userName'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'quantityAdjusted': quantityAdjusted,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'adjustmentType': adjustmentType,
      'reason': reason,
      'adjustmentDate': adjustmentDate.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'notes': notes,
    };
  }

  StockAdjustmentHistory copyWith({
    String? id,
    String? productId,
    String? productName,
    String? categoryId,
    String? categoryName,
    double? quantityAdjusted,
    double? previousQuantity,
    double? newQuantity,
    String? adjustmentType,
    String? reason,
    DateTime? adjustmentDate,
    String? userId,
    String? userName,
    String? notes,
  }) {
    return StockAdjustmentHistory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      quantityAdjusted: quantityAdjusted ?? this.quantityAdjusted,
      previousQuantity: previousQuantity ?? this.previousQuantity,
      newQuantity: newQuantity ?? this.newQuantity,
      adjustmentType: adjustmentType ?? this.adjustmentType,
      reason: reason ?? this.reason,
      adjustmentDate: adjustmentDate ?? this.adjustmentDate,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      notes: notes ?? this.notes,
    );
  }

  // Helper methods for display
  String get adjustmentTypeDisplay {
    switch (adjustmentType) {
      case 'increase':
        return 'Stock Increase';
      case 'decrease':
        return 'Stock Decrease';
      case 'correction':
        return 'Stock Correction';
      default:
        return adjustmentType;
    }
  }

  String get quantityAdjustedDisplay {
    switch (adjustmentType) {
      case 'increase':
        return '+${quantityAdjusted.toStringAsFixed(2)}';
      case 'decrease':
        return '-${quantityAdjusted.abs().toStringAsFixed(2)}';
      case 'correction':
        return quantityAdjusted.toStringAsFixed(2);
      default:
        return quantityAdjusted.toStringAsFixed(2);
    }
  }

  // Validation methods
  bool get isValidAdjustmentType {
    return ['increase', 'decrease', 'correction'].contains(adjustmentType);
  }

  bool get isValidQuantities {
    return previousQuantity >= 0 && 
           newQuantity >= 0 && 
           quantityAdjusted != 0;
  }

  // Calculate the actual adjustment amount based on type
  double get calculatedAdjustment {
    switch (adjustmentType) {
      case 'increase':
        return newQuantity - previousQuantity;
      case 'decrease':
        return previousQuantity - newQuantity;
      case 'correction':
        return newQuantity - previousQuantity;
      default:
        return quantityAdjusted;
    }
  }

  // Verify the adjustment calculation is correct
  bool get isCalculationValid {
    final expectedNew = adjustmentType == 'correction' 
        ? quantityAdjusted 
        : adjustmentType == 'increase'
            ? previousQuantity + quantityAdjusted
            : previousQuantity - quantityAdjusted;
    
    return (newQuantity - expectedNew).abs() < 0.001; // Allow for floating point precision
  }
}