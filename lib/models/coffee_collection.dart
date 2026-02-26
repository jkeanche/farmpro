class CoffeeCollection {
  final String id;
  final String memberId;
  final String memberNumber;
  final String memberName;
  final String seasonId;
  final String seasonName;
  final String productType; // 'CHERRY' or 'MBUNI'
  final double grossWeight;
  final double tareWeight;
  final double netWeight;
  final int numberOfBags; // Number of bags used in the collection
  final DateTime collectionDate;
  final bool isManualEntry;
  final String? receiptNumber;
  final String? userId;
  final String? userName;
  final double? pricePerKg;
  final double? totalValue;

  CoffeeCollection({
    required this.id,
    required this.memberId,
    required this.memberNumber,
    required this.memberName,
    required this.seasonId,
    required this.seasonName,
    required this.productType,
    required this.grossWeight,
    this.tareWeight = 0.0,
    required this.netWeight,
    this.numberOfBags = 1,
    required this.collectionDate,
    required this.isManualEntry,
    this.receiptNumber,
    this.userId,
    this.userName,
    this.pricePerKg,
    this.totalValue,
  });

  factory CoffeeCollection.fromJson(Map<String, dynamic> json) {
    return CoffeeCollection(
      id: json['id'],
      memberId: json['memberId'],
      memberNumber: json['memberNumber'],
      memberName: json['memberName'],
      seasonId: json['seasonId'],
      seasonName: json['seasonName'],
      productType: json['productType'],
      grossWeight: json['grossWeight'].toDouble(),
      tareWeight: json['tareWeight']?.toDouble() ?? 0.0,
      netWeight: json['netWeight'].toDouble(),
      numberOfBags: json['numberOfBags']?.toInt() ?? 1,
      collectionDate: DateTime.parse(json['collectionDate']),
      isManualEntry: json['isManualEntry'] == 1,
      receiptNumber: json['receiptNumber'],
      userId: json['userId'],
      userName: json['userName'],
      pricePerKg: json['pricePerKg']?.toDouble(),
      totalValue: json['totalValue']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'memberNumber': memberNumber,
      'memberName': memberName,
      'seasonId': seasonId,
      'seasonName': seasonName,
      'productType': productType,
      'grossWeight': grossWeight,
      'tareWeight': tareWeight,
      'netWeight': netWeight,
      'numberOfBags': numberOfBags,
      'collectionDate': collectionDate.toIso8601String(),
      'isManualEntry': isManualEntry ? 1 : 0,
      'receiptNumber': receiptNumber,
      'userId': userId,
      'userName': userName,
      'pricePerKg': pricePerKg,
      'totalValue': totalValue,
    };
  }
  
  CoffeeCollection copyWith({
    String? id,
    String? memberId,
    String? memberNumber,
    String? memberName,
    String? seasonId,
    String? seasonName,
    String? productType,
    double? grossWeight,
    double? tareWeight,
    double? netWeight,
    int? numberOfBags,
    DateTime? collectionDate,
    bool? isManualEntry,
    String? receiptNumber,
    String? userId,
    String? userName,
    double? pricePerKg,
    double? totalValue,
  }) {
    return CoffeeCollection(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberNumber: memberNumber ?? this.memberNumber,
      memberName: memberName ?? this.memberName,
      seasonId: seasonId ?? this.seasonId,
      seasonName: seasonName ?? this.seasonName,
      productType: productType ?? this.productType,
      grossWeight: grossWeight ?? this.grossWeight,
      tareWeight: tareWeight ?? this.tareWeight,
      netWeight: netWeight ?? this.netWeight,
      numberOfBags: numberOfBags ?? this.numberOfBags,
      collectionDate: collectionDate ?? this.collectionDate,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      totalValue: totalValue ?? this.totalValue,
    );
  }
} 