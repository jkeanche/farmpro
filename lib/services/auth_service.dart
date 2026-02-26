import 'package:get/get.dart';
import '../models/models.dart';
import 'database_helper.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();
  
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoggedIn = false.obs;
  final RxList<User> users = <User>[].obs;
  
  Future<AuthService> init() async {
    // Load users from database
    await _loadUsers();
    
    // Check if there's a logged in user
    await _checkPreviousLogin();
    
    return this;
  }
  
  Future<void> _loadUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> userMaps = await db.query('users');
    
    final usersList = userMaps.map((userMap) {
      return User.fromJson(userMap);
    }).toList();
    
    users.value = usersList;
  }
  
  Future<void> _checkPreviousLogin() async {
    final db = await _dbHelper.database;
    
    // Get the previously logged in user ID
    final List<Map<String, dynamic>> loginResults = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['logged_in_user_id'],
    );
    
    if (loginResults.isNotEmpty && loginResults.first['value'] != null && loginResults.first['value'].toString().isNotEmpty) {
      final String userId = loginResults.first['value'] as String;
      
      // Get the user with this ID
      final List<Map<String, dynamic>> userResults = await db.query(
        'users',
        where: 'id = ? AND isActive = ?',
        whereArgs: [userId, 1],
      );
      
      if (userResults.isNotEmpty) {
        // Auto-login the user
        currentUser.value = User.fromJson(userResults.first);
        isLoggedIn.value = true;
        print('Auto-logged in user: ${currentUser.value!.username}');
      }
    }
  }
  
  Future<bool> login(String username, String password) async {
    // Find the user with the given username
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ? AND isActive = ?',
      whereArgs: [username, 1],
    );
    
    if (results.isNotEmpty) {
      // In a real app, check the password hash
      // For this demo, we're assuming the password is correct if the user exists
      
      // Set the current user
      currentUser.value = User.fromJson(results.first);
      isLoggedIn.value = true;
      
      // Store login status in DB or local storage if needed
      await _saveSetting('last_login_timestamp', DateTime.now().toIso8601String());
      await _saveSetting('logged_in_user_id', currentUser.value!.id);
      
      return true;
    }
    
    return false;
  }
  
  Future<void> logout() async {
    // Clear current user data
    currentUser.value = null;
    isLoggedIn.value = false;
    
    // Clear any stored login status
    await _saveSetting('logged_in_user_id', '');
    
    // Log the logout timestamp
    await _saveSetting('last_logout_timestamp', DateTime.now().toIso8601String());
    
    // You could also clear any sensitive cached data here
    print('User logged out successfully');
  }
  
  // Helper method to save settings
  Future<void> _saveSetting(String key, String value) async {
    try {
      final db = await _dbHelper.database;
      
      // Check if the setting already exists
      final List<Map<String, dynamic>> result = await db.query(
        'app_settings',
        columns: ['id'],
        where: 'key = ?',
        whereArgs: [key],
      );
      
      if (result.isNotEmpty) {
        // Update existing setting
        await db.update(
          'app_settings',
          {'value': value},
          where: 'key = ?',
          whereArgs: [key],
        );
      } else {
        // Insert new setting
        await db.insert(
          'app_settings',
          {'key': key, 'value': value},
        );
      }
    } catch (e) {
      print('Error saving setting $key: $e');
    }
  }
  
  Future<User> createUser({
    required String username,
    required String fullName,
    required UserRole role,
    required String email,
    String? phoneNumber,
    required String password,
  }) async {
    // Check if username already exists
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    
    if (results.isNotEmpty) {
      throw Exception('Username already exists');
    }
    
    // Generate a unique ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final user = User(
      id: id,
      username: username,
      fullName: fullName,
      role: role,
      email: email,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    // Insert the user into the database
    await db.insert('users', {
      ...user.toJson(),
      'password': password, // In a real app, this would be hashed
      'role': role.index,
      'isActive': 1,
    });
    
    // Add the user to the list
    users.add(user);
    
    return user;
  }
  
  Future<void> updateUser(User user) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'users',
      {
        ...user.toJson(),
        'role': user.role.index,
        'isActive': _dbHelper.boolToInt(user.isActive),
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
    
    // Update the user in the list
    final index = users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      users[index] = user;
    }
  }
  
  Future<void> deactivateUser(String id) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'users',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Update the user in the list
    final index = users.indexWhere((u) => u.id == id);
    if (index != -1) {
      users[index] = users[index].copyWith(isActive: false);
    }
  }
  
  bool hasPermission(List<UserRole> allowedRoles) {
    if (!isLoggedIn.value || currentUser.value == null) {
      return false;
    }
    
    return allowedRoles.contains(currentUser.value!.role);
  }
}
