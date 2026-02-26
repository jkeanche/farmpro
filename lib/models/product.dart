import 'dart:convert';

class Product {
  final String id;
  final String name;
  final String? description;
  final String categoryId;
  final String? categoryName;
  final String unitOfMeasureId;
  final String? unitOfMeasureName;
  final double packSize; // Default/master pack size (stocking unit)
  final List<double>
  packSizes; // Available pack sizes for sale (including packSize)
  final double salesPrice;
  final double? costPrice;
  final double? minimumStock;
  final double? maximumStock;
  final String? barcode;
  final String? sku;
  final bool isActive;
  final bool allowPartialSales; // Can be sold in smaller quantities
  final DateTime createdAt;
  final DateTime? updatedAt;

  // New fields for splitting functionality
  final bool canBeSplit; // Whether this product can be split
  final double?
  maxSplitSize; // Maximum size that can be split from this product
  final String?
  parentProductId; // If this is a split product, reference to parent
  final bool isSplitProduct; // Whether this is a split product
  final double? originalPackSize; // Original pack size for split products

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.categoryName,
    required this.unitOfMeasureId,
    this.unitOfMeasureName,
    required this.packSize,
    List<double>? packSizes,
    required this.salesPrice,
    this.costPrice,
    this.minimumStock,
    this.maximumStock,
    this.barcode,
    this.sku,
    required this.isActive,
    required this.allowPartialSales,
    required this.createdAt,
    this.updatedAt,
    this.canBeSplit = false,
    this.maxSplitSize,
    this.parentProductId,
    this.isSplitProduct = false,
    this.originalPackSize,
  }) : packSizes =
           packSizes == null || packSizes.isEmpty ? [packSize] : packSizes;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
      unitOfMeasureId: json['unitOfMeasureId'],
      unitOfMeasureName: json['unitOfMeasureName'],
      packSize: json['packSize'].toDouble(),
      packSizes:
          json['packSizes'] != null
              ? (jsonDecode(json['packSizes']) as List)
                  .map((e) => (e as num).toDouble())
                  .toList()
              : [(json['packSize'] as num).toDouble()],
      salesPrice: json['salesPrice'].toDouble(),
      costPrice: json['costPrice']?.toDouble(),
      minimumStock: json['minimumStock']?.toDouble(),
      maximumStock: json['maximumStock']?.toDouble(),
      barcode: json['barcode'],
      sku: json['sku'],
      isActive: json['isActive'] == 1,
      allowPartialSales: json['allowPartialSales'] == 1,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      canBeSplit: json['canBeSplit'] == 1,
      maxSplitSize: json['maxSplitSize']?.toDouble(),
      parentProductId: json['parentProductId'],
      isSplitProduct: json['isSplitProduct'] == 1,
      originalPackSize: json['originalPackSize']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'unitOfMeasureId': unitOfMeasureId,
      'unitOfMeasureName': unitOfMeasureName,
      'packSize': packSize,
      'packSizes': jsonEncode(packSizes),
      'salesPrice': salesPrice,
      'costPrice': costPrice,
      'minimumStock': minimumStock,
      'maximumStock': maximumStock,
      'barcode': barcode,
      'sku': sku,
      'isActive': isActive ? 1 : 0,
      'allowPartialSales': allowPartialSales ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'canBeSplit': canBeSplit ? 1 : 0,
      'maxSplitSize': maxSplitSize,
      'parentProductId': parentProductId,
      'isSplitProduct': isSplitProduct ? 1 : 0,
      'originalPackSize': originalPackSize,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    String? categoryName,
    String? unitOfMeasureId,
    String? unitOfMeasureName,
    double? packSize,
    List<double>? packSizes,
    double? salesPrice,
    double? costPrice,
    double? minimumStock,
    double? maximumStock,
    String? barcode,
    String? sku,
    bool? isActive,
    bool? allowPartialSales,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? canBeSplit,
    double? maxSplitSize,
    String? parentProductId,
    bool? isSplitProduct,
    double? originalPackSize,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unitOfMeasureId: unitOfMeasureId ?? this.unitOfMeasureId,
      unitOfMeasureName: unitOfMeasureName ?? this.unitOfMeasureName,
      packSize: packSize ?? this.packSize,
      packSizes: packSizes ?? this.packSizes,
      salesPrice: salesPrice ?? this.salesPrice,
      costPrice: costPrice ?? this.costPrice,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      isActive: isActive ?? this.isActive,
      allowPartialSales: allowPartialSales ?? this.allowPartialSales,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      canBeSplit: canBeSplit ?? this.canBeSplit,
      maxSplitSize: maxSplitSize ?? this.maxSplitSize,
      parentProductId: parentProductId ?? this.parentProductId,
      isSplitProduct: isSplitProduct ?? this.isSplitProduct,
      originalPackSize: originalPackSize ?? this.originalPackSize,
    );
  }

  // Calculate price per unit based on pack size
  double get pricePerUnit => salesPrice / packSize;

  // Calculate sale price for given quantity
  double calculateSalePrice(double quantity) {
    return pricePerUnit * quantity;
  }

  // Split product functionality
  bool canSplit(double splitSize) {
    return canBeSplit && splitSize > 0 && splitSize < packSize;
  }

  // Create a split product
  Product createSplitProduct(double splitSize, String newId) {
    if (!canSplit(splitSize)) {
      throw Exception(
        'Cannot split product: splitSize must be smaller than packSize',
      );
    }

    // Calculate proportional price
    final splitPrice = (salesPrice * splitSize) / packSize;

    return Product(
      id: newId,
      name:
          '$name (${splitSize.toStringAsFixed(1)} ${unitOfMeasureName ?? ''})',
      description: 'Split from $name',
      categoryId: categoryId,
      categoryName: categoryName,
      unitOfMeasureId: unitOfMeasureId,
      unitOfMeasureName: unitOfMeasureName,
      packSize: splitSize,
      salesPrice: splitPrice,
      costPrice: costPrice != null ? (costPrice! * splitSize) / packSize : null,
      minimumStock: null, // Split products don't have minimum stock
      maximumStock: null,
      barcode: null, // Split products don't have barcodes
      sku: null,
      isActive: true,
      allowPartialSales: allowPartialSales,
      createdAt: DateTime.now(),
      updatedAt: null,
      canBeSplit: false, // Split products cannot be split further
      maxSplitSize: null,
      parentProductId: id,
      isSplitProduct: true,
      originalPackSize: packSize,
    );
  }

  // Update parent product after split
  Product updateAfterSplit(double splitSize) {
    final remainingSize = packSize - splitSize;
    final remainingPrice = (salesPrice * remainingSize) / packSize;

    return copyWith(
      packSize: remainingSize,
      salesPrice: remainingPrice,
      costPrice:
          costPrice != null ? (costPrice! * remainingSize) / packSize : null,
      updatedAt: DateTime.now(),
    );
  }

  // Get display name for split products
  String get displayName {
    if (isSplitProduct) {
      return '$name (${packSize.toStringAsFixed(1)} ${unitOfMeasureName ?? ''})';
    }
    return name;
  }
}
