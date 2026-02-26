class Stock {
  final String id;
  final String productId;
  final String? productName;
  final double currentStock;
  final double availableStock; // Current stock minus reserved stock
  final double reservedStock; // Stock reserved for pending orders
  final DateTime lastUpdated;
  final String? lastUpdatedBy;

  Stock({
    required this.id,
    required this.productId,
    this.productName,
    required this.currentStock,
    required this.availableStock,
    required this.reservedStock,
    required this.lastUpdated,
    this.lastUpdatedBy,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      currentStock: json['currentStock'].toDouble(),
      availableStock: json['availableStock'].toDouble(),
      reservedStock: json['reservedStock'].toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      lastUpdatedBy: json['lastUpdatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'availableStock': availableStock,
      'reservedStock': reservedStock,
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  Stock copyWith({
    String? id,
    String? productId,
    String? productName,
    double? currentStock,
    double? availableStock,
    double? reservedStock,
    DateTime? lastUpdated,
    String? lastUpdatedBy,
  }) {
    return Stock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentStock: currentStock ?? this.currentStock,
      availableStock: availableStock ?? this.availableStock,
      reservedStock: reservedStock ?? this.reservedStock,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }
}

class StockMovement {
  final String id;
  final String productId;
  final String movementType; // 'IN', 'OUT', 'ADJUSTMENT'
  final double quantity;
  final double balanceBefore;
  final double balanceAfter;
  final String? reference; // Sale ID, Purchase ID, etc.
  final String? notes;
  final DateTime movementDate;
  final String? userId;
  final String? userName;

  StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.balanceBefore,
    required this.balanceAfter,
    this.reference,
    this.notes,
    required this.movementDate,
    this.userId,
    this.userName,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'],
      productId: json['productId'],
      movementType: json['movementType'],
      quantity: json['quantity'].toDouble(),
      balanceBefore: json['balanceBefore'].toDouble(),
      balanceAfter: json['balanceAfter'].toDouble(),
      reference: json['reference'],
      notes: json['notes'],
      movementDate: DateTime.parse(json['movementDate']),
      userId: json['userId'],
      userName: json['userName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'movementType': movementType,
      'quantity': quantity,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'reference': reference,
      'notes': notes,
      'movementDate': movementDate.toIso8601String(),
      'userId': userId,
      'userName': userName,
    };
  }
} 