class UnitOfMeasure {
  final String id;
  final String name;
  final String abbreviation;
  final String? description;
  final bool isBaseUnit;
  final String? baseUnitId;
  final double? conversionFactor; // Factor to convert to base unit
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UnitOfMeasure({
    required this.id,
    required this.name,
    required this.abbreviation,
    this.description,
    required this.isBaseUnit,
    this.baseUnitId,
    this.conversionFactor,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasure(
      id: json['id'],
      name: json['name'],
      abbreviation: json['abbreviation'],
      description: json['description'],
      isBaseUnit: json['isBaseUnit'] == 1,
      baseUnitId: json['baseUnitId'],
      conversionFactor: json['conversionFactor']?.toDouble(),
      isActive: json['isActive'] == 1,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'description': description,
      'isBaseUnit': isBaseUnit ? 1 : 0,
      'baseUnitId': baseUnitId,
      'conversionFactor': conversionFactor,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      // 'updatedAt' column removed from DB, omit from insert/update
    };
  }

  UnitOfMeasure copyWith({
    String? id,
    String? name,
    String? abbreviation,
    String? description,
    bool? isBaseUnit,
    String? baseUnitId,
    double? conversionFactor,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitOfMeasure(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      description: description ?? this.description,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
      baseUnitId: baseUnitId ?? this.baseUnitId,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 