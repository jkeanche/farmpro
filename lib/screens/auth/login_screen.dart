import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../controllers/controllers.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();
  final _permissionService = Get.find<PermissionService>();
  bool _obscurePassword = true;
  bool _permissionsInitialized = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // Initialize permissions after UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePermissions();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializePermissions() async {
    try {
      print('Initializing permissions from LoginScreen...');

      // Wait a bit to ensure UI is fully ready for dialogs
      await Future.delayed(const Duration(milliseconds: 500));

      // Only check on Android
      if (Platform.isAndroid && !_permissionsInitialized) {
        _permissionsInitialized = true;

        // Check if permissions are already granted
        final permissionsGranted =
            await _permissionService.checkAllRequiredPermissions();

        if (!permissionsGranted) {
          print('Permissions not granted, asking user...');

          // Show permission request dialog
          final userResponse = await _showInitialPermissionDialog();

          if (userResponse == true) {
            print('User agreed to grant permissions, requesting...');
            await _permissionService.requestAllRequiredPermissions();
            print('Permission request completed');
          } else {
            print('User declined permissions');
            // Show message about limited functionality
            Get.snackbar(
              'Permissions Required',
              'Some features may not work properly without required permissions. You can grant permissions later in settings.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 6),
            );
          }
        } else {
          print('All permissions already granted');
        }
      }

      // Permission handling complete, show login screen
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('Error initializing permissions: $e');
      // Continue even if permissions fail
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<bool?> _showInitialPermissionDialog() {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('App Permissions'),
        content: const Text(
          'Farm Fresh needs the following permissions to work properly:\n\n'
          '• Location: For Bluetooth device scanning\n'
          '• Bluetooth: For printer connection\n'
          '• Storage: For saving reports and receipts\n\n'
          'Would you like to grant these permissions now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
      barrierDismissible: false, // Prevent dismissing by tapping outside
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // Proceed with login - permissions are handled in initState
      final success = await _authController.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        Get.offAllNamed(AppConstants.homeRoute);
      } else {
        // Show error message
        Get.snackbar(
          'Login Failed',
          _authController.errorMessage.value.isNotEmpty
              ? _authController.errorMessage.value
              : 'Invalid username or password',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            _isInitializing
                ? _buildLoadingScreen()
                : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Coffee Icon
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.05),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_cafe,
                              size: 60,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // App Name
                          Text(
                            'Coffee Pro',
                            style: Theme.of(
                              context,
                            ).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Tagline
                          Text(
                            'Coffee Society Management System',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          // Username Field
                          CustomTextField(
                            label: 'Username',
                            hint: 'Enter your username',
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.none,
                            prefix: const Icon(Icons.person),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          CustomTextField(
                            label: 'Password',
                            hint: 'Enter your password',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefix: const Icon(Icons.lock),
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          Obx(
                            () => CustomButton(
                              text: 'Login',
                              onPressed: _login,
                              isLoading: _authController.isLoading.value,
                              isFullWidth: true,
                              height: 50,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Forgot Password
                          TextButton(
                            onPressed: () {
                              // Handle forgot password
                              Get.snackbar(
                                'Forgot Password',
                                'Please contact your administrator to reset your password.',
                                snackPosition: SnackPosition.BOTTOM,
                                margin: const EdgeInsets.all(16),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Footer
                          Text(
                            'Developed by Inuka Technologies',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Coffee Icon
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.local_cafe,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          // App Name
          Text(
            'Coffee Pro',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Tagline
          Text(
            'Coffee Society Management System',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Loading Indicator
          const CircularProgressIndicator(),
          const SizedBox(height: 24),

          // Loading Text
          Text(
            'Initializing app...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
