import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../widgets/widgets.dart';
import '../../constants/app_constants.dart';
import '../coffee_collection/coffee_collection_screen.dart';
import '../members/members_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/reports_screen.dart';
import '../inventory/inventory_dashboard_screen.dart';
import '../season/season_management_screen.dart';

class CoffeeHomeScreen extends StatefulWidget {
  const CoffeeHomeScreen({super.key});

  @override
  State<CoffeeHomeScreen> createState() => _CoffeeHomeScreenState();
}

class _CoffeeHomeScreenState extends State<CoffeeHomeScreen> {
  final _authController = Get.find<AuthController>();
  final _memberController = Get.find<MemberController>();
  final _coffeeCollectionController = Get.find<CoffeeCollectionController>();
  final _seasonController = Get.find<SeasonController>();
  final _inventoryController = Get.find<InventoryController>();
  
  int _currentIndex = 0;
  
  final List<String> _titles = [
    'Coffee Pro Dashboard',
    'Coffee Collection',
    'Members',
    'Inventory',
    'Reports',
    'Settings',
  ];
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex == 0) {
          return false;
        }
        setState(() {
          _currentIndex = 0;
        });
        return false;
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: _titles[_currentIndex],
          showBackButton: _currentIndex != 0,
          onBackPressed: () {
            setState(() {
              _currentIndex = 0;
            });
          },
          actions: [
            // Season indicator
            Obx(() => Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                _seasonController.currentSeasonDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                _showLogoutDialog();
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(),
            const CoffeeCollectionScreen(),
            const MembersScreen(),
            const InventoryDashboardScreen(),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Members',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'Inventory',
            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Obx(() {
            final user = _authController.currentUser.value;
            return Text(
              'Welcome to Coffee Pro, ${user?.fullName ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            );
          }),
          const SizedBox(height: 8.0),
          Obx(() => Text(
            'Current Season: ${_seasonController.currentSeasonDisplay}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          )),
          const SizedBox(height: 24.0),
          
          // Season status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Season Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () {
                          Get.to(() => const SeasonManagementScreen());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Obx(() {
                    final canCollect = _seasonController.canStartCollection();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: canCollect ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        canCollect ? 'Collection Active' : 'Season Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          
          // Quick stats
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                  title: 'Total Members',
                  value: _memberController.members.length.toString(),
                  icon: Icons.people,
                  color: const Color(0xFF8B4513),
                )),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Obx(() => _buildStatCard(
                  title: 'Today\'s Collections',
                  value: _coffeeCollectionController.todaysTotalCollections.toString(),
                  icon: Icons.coffee,
                  color: const Color(0xFFD2691E),
                )),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                  title: 'Today\'s Weight (kg)',
                  value: _coffeeCollectionController.todaysTotalWeight.toStringAsFixed(1),
                  icon: Icons.scale,
                  color: const Color(0xFFCD853F),
                )),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Obx(() => _buildStatCard(
                  title: 'Credit Sales',
                  value: _inventoryController.creditSales.length.toString(),
                  icon: Icons.credit_card,
                  color: const Color(0xFF6F4E37),
                )),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          
          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16.0),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            children: [
              _buildActionCard(
                title: 'Record Coffee',
                icon: Icons.coffee,
                color: const Color(0xFF8B4513),
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              _buildActionCard(
                title: 'Add Member',
                icon: Icons.person_add,
                color: const Color(0xFFD2691E),
                onTap: () {
                  Get.toNamed(AppConstants.addMemberRoute);
                },
              ),
              _buildActionCard(
                title: 'Inventory',
                icon: Icons.shopping_cart,
                color: const Color(0xFFCD853F),
                onTap: () {
                  setState(() {
                    _currentIndex = 3; // Inventory tab
                  });
                },
              ),
              _buildActionCard(
                title: 'Manage Season',
                icon: Icons.calendar_today,
                color: const Color(0xFF6F4E37),
                onTap: () {
                  Get.to(() => const SeasonManagementScreen());
                },
              ),
            ],
          ),
       
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36.0,
                color: color,
              ),
              const SizedBox(height: 8.0),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _authController.logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
} 