import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'organization_settings_screen.dart';
import 'sms_test_screen.dart';
import 'system_settings_screen.dart';
import 'user_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      // appBar: const CustomAppBar(
      //   title: 'Settings',
      //   showBackButton: true,
      // ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Organization Settings
          _buildSettingsCard(
            context,
            title: 'Organization Settings',
            description: 'Configure society name, logo, and address',
            icon: Icons.business,
            onTap: () => Get.to(() => const OrganizationSettingsScreen()),
          ),

          // System Settings
          _buildSettingsCard(
            context,
            title: 'System Settings',
            description: 'Configure Bluetooth devices, printing, and SMS',
            icon: Icons.settings,
            onTap: () => Get.to(() => const SystemSettingsScreen()),
          ),

          // Bluetooth Debug (for troubleshooting)

          // Server Sync
          _buildSettingsCard(
            context,
            title: 'Server Sync',
            description:
                'Configure & Sync data with backend server for data backup and reporting',
            icon: Icons.sync_alt,
            onTap: () => Get.toNamed(AppConstants.navisionSettingsRoute),
          ),

          // User Management (Admin only)
          Obx(() {
            final isAdmin =
                authController.currentUser.value?.role == UserRole.admin;
            return _buildSettingsCard(
              context,
              title: 'User Management',
              description: 'Manage users and permissions',
              icon: Icons.people,
              onTap:
                  isAdmin
                      ? () => Get.to(() => const UserManagementScreen())
                      : () => _showAdminOnlyMessage(context),
              enabled: isAdmin,
            );
          }),

          // About
          _buildSettingsCard(
            context,
            title: 'About',
            description: 'App information and version',
            icon: Icons.info,
            onTap: () => _showAboutDialog(context),
          ),

          // SMS Test (for diagnostics)
          _buildSettingsCard(
            context,
            title: 'SMS Test',
            description: 'Test SMS functionality',
            icon: Icons.sms,
            onTap: () => Get.to(() => const SmsTestScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.all(16.0),
        backgroundColor:
            enabled ? null : Theme.of(context).disabledColor.withOpacity(0.1),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color:
                    enabled
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).disabledColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(
                icon,
                color:
                    enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                size: 28.0,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: enabled ? null : Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          enabled
                              ? Theme.of(context).textTheme.bodySmall?.color
                              : Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color:
                  enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminOnlyMessage(BuildContext context) {
    Get.snackbar(
      'Admin Access Required',
      'Only administrators can access user management',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Theme.of(context).colorScheme.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AboutDialog(
            applicationName: 'Farm Fresh',
            applicationVersion: 'v1.0.0',
            applicationIcon: Icon(
              Icons.eco,
              color: Theme.of(context).colorScheme.primary,
              size: 48.0,
            ),
            applicationLegalese: ' 2025 Inuka Technologies',
            children: [
              const SizedBox(height: 16.0),
              const Text(
                'Farm Fresh is a modern, responsive Flutter app for managing members, coffee collection, and cooperative operations – built for dairy societies.',
              ),
              const SizedBox(height: 16.0),
              Text(
                'Developed by Inuka Technologies',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Text('Building Smart Agriculture & Cooperative Solutions'),
            ],
          ),
    );
  }
}
