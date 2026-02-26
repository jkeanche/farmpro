class Farmer {
  final String id;
  final String farmerNumber;
  final String fullName;
  final String idNumber;
  final String? phoneNumber;
  final String? email;
  final DateTime registrationDate;
  final String gender; // Added gender field
  final String route; // Added route field
  final bool isActive; // Added status field to track if farmer is active or not

  Farmer({
    required this.id,
    required this.farmerNumber,
    required this.fullName,
    required this.idNumber,
    this.phoneNumber,
    this.email,
    required this.registrationDate,
    required this.gender,
    required this.route,
    this.isActive = true, // Default to active
  });

  factory Farmer.fromJson(Map<String, dynamic> json) {
    return Farmer(
      id: json['id'],
      farmerNumber: json['farmerNumber'],
      fullName: json['fullName'],
      idNumber: json['idNumber'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      registrationDate: DateTime.parse(json['registrationDate']),
      gender: json['gender'],
      route: json['route'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmerNumber': farmerNumber,
      'fullName': fullName,
      'idNumber': idNumber,
      'phoneNumber': phoneNumber,
      'email': email,
      'registrationDate': registrationDate.toIso8601String(),
      'gender': gender,
      'route': route,
      'isActive': isActive,
    };
  }

  // Method to create a copy of the farmer with updated fields
  Farmer copyWith({
    String? id,
    String? farmerNumber,
    String? fullName,
    String? idNumber,
    String? phoneNumber,
    String? email,
    DateTime? registrationDate,
    String? gender,
    String? route,
    bool? isActive,
  }) {
    return Farmer(
      id: id ?? this.id,
      farmerNumber: farmerNumber ?? this.farmerNumber,
      fullName: fullName ?? this.fullName,
      idNumber: idNumber ?? this.idNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      registrationDate: registrationDate ?? this.registrationDate,
      gender: gender ?? this.gender,
      route: route ?? this.route,
      isActive: isActive ?? this.isActive,
    );
  }

  // Method to activate a farmer
  Farmer activate() {
    return copyWith(isActive: true);
  }

  // Method to deactivate a farmer
  Farmer deactivate() {
    return copyWith(isActive: false);
  }
}
