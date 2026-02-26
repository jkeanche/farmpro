class Member {
  final String id;
  final String memberNumber;
  final String fullName;
  final String? idNumber;
  final String? phoneNumber;
  final String? email;
  final DateTime registrationDate;
  final String? gender;
  final String? zone;
  final double? acreage;
  final int? noTrees;
  final bool isActive;
  final String? searchText;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Member({
    required this.id,
    required this.memberNumber,
    required this.fullName,
    this.idNumber,
    this.phoneNumber,
    this.email,
    required this.registrationDate,
    this.gender,
    this.zone,
    this.acreage,
    this.noTrees,
    this.isActive = true,
    this.searchText,
    this.createdAt,
    this.updatedAt,
  });

  String get optimizedSearchText {
    final parts = [
      fullName.toLowerCase(),
      memberNumber.toLowerCase(),
    ];
    return parts.where((part) => part.isNotEmpty).join(' ');
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      memberNumber: json['memberNumber'],
      fullName: json['fullName'],
      idNumber: json['idNumber'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      registrationDate: DateTime.parse(json['registrationDate']),
      gender: json['gender'],
      zone: json['zone'],
      acreage: json['acreage']?.toDouble(),
      noTrees: json['noTrees']?.toInt(),
      isActive: json['isActive'] == 1,
      searchText: json['searchText'],
      createdAt: json['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] * 1000) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] * 1000) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final now = DateTime.now();
    return {
      'id': id,
      'memberNumber': memberNumber,
      'fullName': fullName,
      'idNumber': idNumber,
      'phoneNumber': phoneNumber,
      'email': email,
      'registrationDate': registrationDate.toIso8601String(),
      'gender': gender,
      'zone': zone,
      'acreage': acreage,
      'noTrees': noTrees,
      'isActive': isActive ? 1 : 0,
      'searchText': optimizedSearchText,
      'createdAt': (createdAt ?? now).millisecondsSinceEpoch ~/ 1000,
      'updatedAt': now.millisecondsSinceEpoch ~/ 1000,
    };
  }
  
  Member copyWith({
    String? id,
    String? memberNumber,
    String? fullName,
    String? idNumber,
    String? phoneNumber,
    String? email,
    DateTime? registrationDate,
    String? gender,
    String? zone,
    double? acreage,
    int? noTrees,
    bool? isActive,
    String? searchText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      memberNumber: memberNumber ?? this.memberNumber,
      fullName: fullName ?? this.fullName,
      idNumber: idNumber ?? this.idNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      registrationDate: registrationDate ?? this.registrationDate,
      gender: gender ?? this.gender,
      zone: zone ?? this.zone,
      acreage: acreage ?? this.acreage,
      noTrees: noTrees ?? this.noTrees,
      isActive: isActive ?? this.isActive,
      searchText: searchText ?? this.searchText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  Member activate() {
    return copyWith(isActive: true, updatedAt: DateTime.now());
  }
  
  Member deactivate() {
    return copyWith(isActive: false, updatedAt: DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
