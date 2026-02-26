class OrganizationSettings {
  final String id;
  final String societyName;
  final String? logoPath;
  final String factory;
  final String address;
  final String? email;
  final String? phoneNumber;
  final String? website;
  final String? slogan;

  OrganizationSettings({
    required this.id,
    required this.societyName,
    this.logoPath,
    required this.factory,
    required this.address,
    this.email,
    this.phoneNumber,
    this.website,
    this.slogan,
  });

  factory OrganizationSettings.fromJson(Map<String, dynamic> json) {
    return OrganizationSettings(
      id: json['id'],
      societyName: json['societyName'],
      logoPath: json['logoPath'],
      factory: json['factory'] ?? '',
      address: json['address'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      website: json['website'],
      slogan: json['slogan'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'societyName': societyName,
      'logoPath': logoPath,
      'factory': factory,
      'address': address,
      'email': email,
      'phoneNumber': phoneNumber,
      'website': website,
      'slogan': slogan,
    };
  }

  // Copy with method
  OrganizationSettings copyWith({
    String? id,
    String? societyName,
    String? logoPath,
    String? factory,
    String? address,
    String? email,
    String? phoneNumber,
    String? website,
    String? slogan,
  }) {
    return OrganizationSettings(
      id: id ?? this.id,
      societyName: societyName ?? this.societyName,
      logoPath: logoPath ?? this.logoPath,
      factory: factory ?? this.factory,
      address: address ?? this.address,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      slogan: slogan ?? this.slogan,
    );
  }
}
