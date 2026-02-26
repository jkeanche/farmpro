import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../controllers/controllers.dart';
import '../../services/inventory_service.dart';
import '../../themes/app_theme.dart';
import 'low_stock_alerts_screen.dart';
import 'stock_adjustment_history_screen.dart';

class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final seasonController = Get.find<SeasonController>();
    final inventoryService = Get.find<InventoryService>();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          32.0,
        ), // Added extra bottom padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Season status card
            Obx(() {
              final activeSeason = seasonController.activeSeason;
              if (activeSeason != null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Season: ${activeSeason.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '${activeSeason.dateRangeText} • ${activeSeason.totalTransactions} sales',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => Get.toNamed(
                                  AppConstants.seasonManagementRoute,
                                ),
                            child: const Text('Manage'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    color: Colors.red.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Active Season',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  'Create a season to start recording sales',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                () => Get.toNamed(
                                  AppConstants.seasonManagementRoute,
                                ),
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            }),

            // Quick New Sale action (full width card)
            Card(
              color: AppTheme.accentColor,
              margin: const EdgeInsets.only(bottom: 24.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => Get.toNamed(AppConstants.salesRoute),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 40, color: Colors.white),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Sale',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quickly record a cash or credit sale',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Performance metrics section
            Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Inventory Overview',
                          style: Get.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Products',
                            '${inventoryService.products.length}',
                            Icons.inventory,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Categories',
                            '${inventoryService.categories.length}',
                            Icons.category,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Low Stock',
                            '${_getLowStockCount()}',
                            Icons.warning,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick actions grid
            Text('Inventory Management', style: Get.textTheme.titleLarge),
            const SizedBox(height: 16.0),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio:
                  1.2, // Adjusted for better proportions with more cards
              children: [
                _buildActionCard(
                  'Products',
                  'Manage inventory products',
                  Icons.inventory,
                  const Color(0xFF8B4513),
                  () => Get.toNamed('/inventory/products'),
                ),
                _buildActionCard(
                  'Categories',
                  'Organize product categories',
                  Icons.category,
                  const Color(0xFFD2691E),
                  () => Get.toNamed('/inventory/categories'),
                ),
                _buildActionCard(
                  'Stock Adjustment',
                  'Adjust stock levels',
                  Icons.tune,
                  const Color(0xFFCD853F),
                  () => Get.toNamed(AppConstants.stockAdjustmentRoute),
                ),
                _buildActionCard(
                  'Stock History',
                  'View adjustment history',
                  Icons.history,
                  const Color(0xFFA0522D),
                  () => Get.to(() => const StockAdjustmentHistoryScreen()),
                ),
                _buildActionCard(
                  'Low Stock Alerts',
                  'View stock level warnings',
                  Icons.warning,
                  Colors.red,
                  () => Get.to(() => const LowStockAlertsScreen()),
                ),
                _buildActionCard(
                  'Units of Measure',
                  'Manage measurement units',
                  Icons.straighten,
                  const Color(0xFF6F4E37),
                  () => Get.toNamed('/inventory/units'),
                ),
              ],
            ),
            const SizedBox(height: 24.0),

            // Sales section
            Text('Sales & Credit Management', style: Get.textTheme.titleLarge),
            const SizedBox(height: 16.0),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.4, // Increased for better proportions
              children: [
                _buildActionCard(
                  'Credit Sales',
                  'View outstanding credits',
                  Icons.credit_card,
                  Colors.orange,
                  () => Get.toNamed('/inventory/credit-sales'),
                ),
                _buildActionCard(
                  'Sales Reports',
                  'View sales analytics',
                  Icons.analytics,
                  Colors.purple,
                  () => Get.toNamed(AppConstants.salesReportRoute),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20.0, // Slightly smaller
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              title,
              style: Get.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(12.0), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32.0, color: color), // Slightly smaller icon
              const SizedBox(height: 6.0), // Reduced spacing
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                  ), // Smaller font
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2.0), // Reduced spacing
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Get.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  ), // Smaller font
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getLowStockCount() {
    final inventoryService = Get.find<InventoryService>();
    int lowStockCount = 0;

    for (final stock in inventoryService.stocks) {
      // Consider stock low if it's 10 or below, or if it's 0
      if (stock.currentStock <= 10) {
        lowStockCount++;
      }
    }

    return lowStockCount;
  }
}
