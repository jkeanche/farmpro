import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../widgets/widgets.dart';
import '../../constants/app_constants.dart';
import '../coffee_collection/coffee_collection_screen.dart';
import '../members/members_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authController = Get.find<AuthController>();
  final _memberController = Get.find<MemberController>();
  final _coffeeCollectionController = Get.find<CoffeeCollectionController>();

  int _currentIndex = 0;

  final List<Widget> _pages = [];
  final List<String> _titles = [
    'Dashboard',
    'Coffee Collection',
    'Members',
    'Reports',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize pages with placeholders
    _pages.addAll([
      Container(), // Placeholder for dashboard - will be built in build method
      const CoffeeCollectionScreen(),
      const MembersScreen(),
      Container(), // Placeholder for reports - will be built in build method
      const SettingsScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Modify the WillPopScope to only prevent back navigation on the Dashboard tab
    return WillPopScope(
      onWillPop: () async {
        // Only prevent back navigation when on the main dashboard (index 0)
        if (_currentIndex == 0) {
          return false;
        }
        // For other tabs, go back to dashboard instead of exiting
        setState(() {
          _currentIndex = 0;
        });
        return false;
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: _titles[_currentIndex],
          showBackButton:
              _currentIndex != 0, // Show back button except on Dashboard
          onBackPressed: () {
            // Go back to dashboard when back button is pressed
            setState(() {
              _currentIndex = 0;
            });
          },
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                // Show user profile or logout dialog
                _showLogoutDialog();
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(), // Build dashboard when needed
            const CoffeeCollectionScreen(),
            const MembersScreen(),
            const ReportsScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.coffee),
              label: 'Collection',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Builder(
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Obx(() {
                final user = _authController.currentUser.value;
                return Text(
                  'Welcome, ${user?.fullName ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              }),
              const SizedBox(height: 24.0),

              // Quick stats
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildStatCard(
                        title: 'Total Members',
                        value: _memberController.members.length.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Today',
                      value: _getTodayCollections(),
                      icon: Icons.coffee,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // Quick actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Record Coffee',
                      icon: Icons.coffee,
                      onTap: () {
                        setState(() {
                          _currentIndex = 1; // Switch to Coffee Collection tab
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildActionCard(
                      title: 'Add Member',
                      icon: Icons.person_add,
                      onTap: () {
                        Get.toNamed(AppConstants.addMemberRoute);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'View Reports',
                      icon: Icons.bar_chart,
                      onTap: () {
                        setState(() {
                          _currentIndex = 3; // Switch to Reports tab
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildActionCard(
                      title: 'Settings',
                      icon: Icons.settings,
                      onTap: () {
                        setState(() {
                          _currentIndex = 4; // Switch to Settings tab
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32.0),
                const SizedBox(height: 8.0),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32.0, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 8.0),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTodayCollections() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayCollections =
        _coffeeCollectionController.collections.where((collection) {
          final collectionDate = DateTime(
            collection.collectionDate.year,
            collection.collectionDate.month,
            collection.collectionDate.day,
          );
          return collectionDate.isAtSameMomentAs(today);
        }).toList();

    if (todayCollections.isEmpty) {
      return '0.0 kg';
    }

    final totalWeight = todayCollections.fold<double>(
      0.0,
      (sum, collection) => sum + collection.netWeight,
    );

    return '${totalWeight.toStringAsFixed(1)} kg';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  final user = _authController.currentUser.value;
                  return Text('Logged in as: ${user?.fullName ?? 'User'}');
                }),
                const SizedBox(height: 16.0),
                const Text('Are you sure you want to logout?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              Obx(
                () =>
                    _authController.isLoading.value
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _authController.logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Logout'),
                        ),
              ),
            ],
          ),
    );
  }
}
