class Season {
  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final double totalSales;
  final int totalTransactions;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? createdByName;
  final String type;

  Season({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.totalSales = 0.0,
    this.totalTransactions = 0,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.createdByName,
    this.type = 'inventory',
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'] == 1,
      totalSales: json['totalSales']?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      createdBy: json['createdBy'],
      createdByName: json['createdByName'],
      type: json['type'] ?? 'inventory',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'totalSales': totalSales,
      'totalTransactions': totalTransactions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'type': type,
    };
  }

  Season copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    double? totalSales,
    int? totalTransactions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? type,
  }) {
    return Season(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      type: type ?? this.type,
    );
  }

  // Get duration of the season
  Duration get duration {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate);
  }

  // Check if season is currently running
  bool get isCurrentlyActive {
    final now = DateTime.now();
    if (!isActive) return false;
    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  // Get season status text
  String get statusText {
    if (!isActive) return 'Closed';
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 'Scheduled';
    if (endDate != null && now.isAfter(endDate!)) return 'Expired';
    return 'Active';
  }

  // Get formatted date range
  String get dateRangeText {
    final startFormatted = '${startDate.day}/${startDate.month}/${startDate.year}';
    if (endDate == null) {
      return '$startFormatted - Ongoing';
    }
    final endFormatted = '${endDate!.day}/${endDate!.month}/${endDate!.year}';
    return '$startFormatted - $endFormatted';
  }

  // Calculate average sale per transaction
  double get averageSaleAmount {
    if (totalTransactions == 0) return 0.0;
    return totalSales / totalTransactions;
  }
}

// Model for member seasonal summary
class MemberSeasonSummary {
  final String memberId;
  final String memberName;
  final String seasonId;
  final String seasonName;
  final double totalPurchases;
  final int totalTransactions;
  final DateTime? lastPurchaseDate;
  final double averagePurchase;

  MemberSeasonSummary({
    required this.memberId,
    required this.memberName,
    required this.seasonId,
    required this.seasonName,
    required this.totalPurchases,
    required this.totalTransactions,
    this.lastPurchaseDate,
    required this.averagePurchase,
  });

  factory MemberSeasonSummary.fromJson(Map<String, dynamic> json) {
    return MemberSeasonSummary(
      memberId: json['memberId'],
      memberName: json['memberName'],
      seasonId: json['seasonId'],
      seasonName: json['seasonName'],
      totalPurchases: json['totalPurchases']?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      lastPurchaseDate: json['lastPurchaseDate'] != null 
          ? DateTime.parse(json['lastPurchaseDate']) 
          : null,
      averagePurchase: json['averagePurchase']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'seasonId': seasonId,
      'seasonName': seasonName,
      'totalPurchases': totalPurchases,
      'totalTransactions': totalTransactions,
      'lastPurchaseDate': lastPurchaseDate?.toIso8601String(),
      'averagePurchase': averagePurchase,
    };
  }
} 