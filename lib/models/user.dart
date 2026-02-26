enum UserRole { admin, manager, clerk }

class User {
  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String email;
  final String? phoneNumber;
  final DateTime createdAt;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.email,
    this.phoneNumber,
    required this.createdAt,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle role which could be an int index or a string
    UserRole parseRole(dynamic roleValue) {
      if (roleValue is int && roleValue >= 0 && roleValue < UserRole.values.length) {
        return UserRole.values[roleValue];
      } else if (roleValue is String) {
        try {
          return UserRole.values.firstWhere(
            (e) => e.toString() == 'UserRole.$roleValue' || e.toString().split('.').last == roleValue,
            orElse: () => UserRole.clerk,
          );
        } catch (e) {
          return UserRole.clerk; // Default fallback
        }
      }
      return UserRole.clerk; // Default fallback
    }

    // Convert isActive from int to bool if needed
    bool parseIsActive(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false; // Default value
    }
    
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['fullName'],
      role: parseRole(json['role']),
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: parseIsActive(json['isActive']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'email': email,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Copy with method
  User copyWith({
    String? id,
    String? username,
    String? fullName,
    UserRole? role,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
