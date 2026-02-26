import 'package:get/get.dart';

import '../models/models.dart';
import '../services/services.dart';

class AuthController extends GetxController {
  AuthService get _authService => Get.find<AuthService>();

  Rx<User?> get currentUser => _authService.currentUser;
  RxBool get isLoggedIn => _authService.isLoggedIn;
  RxList<User> get users => _authService.users;

  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;

  @override
  void onReady() {
    super.onReady();
    // Check authentication status and navigate accordingly
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    if (isLoggedIn.value) {
      // User is already logged in, navigate to home
      Get.offAllNamed('/home');
    }
    // If not logged in, stay on login screen (already the initial route)
  }

  Future<bool> login(String username, String password) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final success = await _authService.login(username, password);

      isLoading.value = false;
      return success;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to login: $e';
      print(errorMessage.value);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _authService.logout();

      isLoading.value = false;

      // Redirect to login screen
      Get.offAllNamed('/login');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to logout: $e';
      print(errorMessage.value);

      // Even if there was an error, try to force navigation to login
      Get.offAllNamed('/login');
    }
  }

  Future<User?> createUser({
    required String username,
    required String fullName,
    required UserRole role,
    required String email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final user = await _authService.createUser(
        username: username,
        fullName: fullName,
        role: role,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      isLoading.value = false;
      return user;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to create user: $e';
      print(errorMessage.value);
      return null;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _authService.updateUser(user);

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to update user: $e';
      print(errorMessage.value);
    }
  }

  Future<void> deactivateUser(String id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _authService.deactivateUser(id);

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to deactivate user: $e';
      print(errorMessage.value);
    }
  }

  bool hasPermission(List<UserRole> allowedRoles) {
    return _authService.hasPermission(allowedRoles);
  }
}
