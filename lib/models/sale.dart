import 'dart:convert';

class Sale {
  final String id;
  final String? memberId;
  final String? memberName;
  final String? memberNumber;
  final String saleType; // 'CASH' or 'CREDIT'
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final DateTime saleDate;
  final String? receiptNumber;
  final String? notes;
  final String userId;
  final String? userName;
  final List<SaleItem> items;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Season fields
  final String? seasonId;
  final String? seasonName;

  Sale({
    required this.id,
    this.memberId,
    this.memberName,
    this.memberNumber,
    required this.saleType,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.saleDate,
    this.receiptNumber,
    this.notes,
    required this.userId,
    this.userName,
    required this.items,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.seasonId,
    this.seasonName,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<SaleItem> itemsList = [];

    // Handle items field - could be JSON string or List
    if (json['items'] != null) {
      if (json['items'] is String) {
        // If it's a JSON string, decode it first
        try {
          final decoded = jsonDecode(json['items']);
          if (decoded is List) {
            itemsList = decoded.map((item) => SaleItem.fromJson(item)).toList();
          }
        } catch (e) {
          print('Error decoding items JSON: $e');
        }
      } else if (json['items'] is List) {
        // If it's already a list, use it directly
        itemsList =
            (json['items'] as List)
                .map((item) => SaleItem.fromJson(item))
                .toList();
      }
    }

    return Sale(
      id: json['id'],
      memberId: json['memberId'],
      memberName: json['memberName'],
      memberNumber: json['memberNumber'],
      saleType: json['saleType'],
      totalAmount: json['totalAmount'].toDouble(),
      paidAmount: json['paidAmount'].toDouble(),
      balanceAmount: json['balanceAmount'].toDouble(),
      saleDate: DateTime.parse(json['saleDate']),
      receiptNumber: json['receiptNumber'],
      notes: json['notes'],
      userId: json['userId'],
      userName: json['userName'],
      items: itemsList,
      isActive: json['isActive'] == 1,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      seasonId: json['seasonId'],
      seasonName: json['seasonName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'memberNumber': memberNumber,
      'saleType': saleType,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'saleDate': saleDate.toIso8601String(),
      'receiptNumber': receiptNumber,
      if (notes != null) 'notes': notes,
      'userId': userId,
      'userName': userName,
      'items': jsonEncode(items.map((item) => item.toJson()).toList()),
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'seasonId': seasonId,
      'seasonName': seasonName,
    };
  }

  /// Returns JSON representation for API/in-memory use (items as List)
  Map<String, dynamic> toJsonForApi() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'memberNumber': memberNumber,
      'saleType': saleType,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'saleDate': saleDate.toIso8601String(),
      'receiptNumber': receiptNumber,
      'notes': notes,
      'userId': userId,
      'userName': userName,
      'items': items.map((item) => item.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'seasonId': seasonId,
      'seasonName': seasonName,
    };
  }

  Sale copyWith({
    String? id,
    String? memberId,
    String? memberName,
    String? memberNumber,
    String? saleType,
    double? totalAmount,
    double? paidAmount,
    double? balanceAmount,
    DateTime? saleDate,
    String? receiptNumber,
    String? notes,
    String? userId,
    String? userName,
    List<SaleItem>? items,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? seasonId,
    String? seasonName,
  }) {
    return Sale(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberNumber: memberNumber ?? this.memberNumber,
      saleType: saleType ?? this.saleType,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      saleDate: saleDate ?? this.saleDate,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      items: items ?? this.items,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      seasonId: seasonId ?? this.seasonId,
      seasonName: seasonName ?? this.seasonName,
    );
  }

  bool get isCreditSale => saleType == 'CREDIT';
  bool get hasBalance => balanceAmount > 0;
}

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double packSizeSold; // Pack size used for this sale item
  final String? notes;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.packSizeSold,
    this.notes,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      saleId: json['saleId'],
      productId: json['productId'],
      productName: json['productName'],
      quantity: json['quantity'].toDouble(),
      unitPrice: json['unitPrice'].toDouble(),
      totalPrice: json['totalPrice'].toDouble(),
      packSizeSold:
          json['packSizeSold'] != null
              ? json['packSizeSold'].toDouble()
              : json['quantity'].toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'packSizeSold': packSizeSold,
      if (notes != null) 'notes': notes,
    };
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    double? packSizeSold,
    String? notes,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      packSizeSold: packSizeSold ?? this.packSizeSold,
      notes: notes ?? this.notes,
    );
  }
}
