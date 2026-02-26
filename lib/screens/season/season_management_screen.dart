import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class SeasonManagementScreen extends StatefulWidget {
  const SeasonManagementScreen({super.key});

  @override
  State<SeasonManagementScreen> createState() => _SeasonManagementScreenState();
}

class _SeasonManagementScreenState extends State<SeasonManagementScreen> {
  final _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxString _selectedFilter = 'all'.obs;
  final RxBool hasEndDate = false.obs;
  final Rx<DateTime> startDate = DateTime.now().obs;
  final Rx<DateTime> endDate =
      DateTime.now().add(const Duration(days: 365)).obs;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seasonController = Get.find<SeasonController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: const Text(
          'Season Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B4513),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => seasonController.refreshData(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildCreateButtons(),
          const SizedBox(height: 16),
          Expanded(child: _buildSeparatedSeasonsList()),
        ],
      ),
    );
  }

  Widget _buildSeasonStat(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8B4513), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search periods...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) => _searchQuery.value = value,
          ),
          const SizedBox(height: 12),
          Obx(
            () => DropdownButtonFormField<String>(
              value: _selectedFilter.value,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Periods')),
                DropdownMenuItem(value: 'active', child: Text('Active Only')),
                DropdownMenuItem(value: 'closed', child: Text('Closed Only')),
              ],
              onChanged: (value) => _selectedFilter.value = value ?? 'all',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showCreateSeasonDialog('coffee'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4423),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),

              label: const Text('Add Coffee Season'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showCreateSeasonDialog('inventory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: const Text('Add Inventory Period'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparatedSeasonsList() {
    final seasonController = Get.find<SeasonController>();

    return Obx(() {
      final coffeeSeasons = _getFilteredSeasons('coffee');
      final inventorySeasons = _getFilteredSeasons('inventory');

      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: const Color(0xFF8B4513),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF8B4513),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.agriculture),
                    text: 'Coffee Collection (${coffeeSeasons.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.inventory),
                    text: 'Inventory (${inventorySeasons.length})',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSeasonSection(
                    coffeeSeasons,
                    'coffee',
                    'Coffee Collection Seasons',
                  ),
                  _buildSeasonSection(
                    inventorySeasons,
                    'inventory',
                    'Inventory Periods',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSeasonSection(List<Season> seasons, String type, String title) {
    if (seasons.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: EmptyState(
            icon: type == 'coffee' ? Icons.agriculture : Icons.inventory,
            title: 'No $title Found',
            message:
                type == 'coffee'
                    ? 'Create your first coffee collection season to start managing coffee deliveries.'
                    : 'Create your first inventory period to start managing sales.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        return _buildSeasonCard(season);
      },
    );
  }

  List<Season> _getFilteredSeasons(String type) {
    final seasonController = Get.find<SeasonController>();
    var seasons =
        seasonController.seasons.where((s) => s.type == type).toList();

    if (_searchQuery.value.isNotEmpty) {
      seasons =
          seasons
              .where(
                (season) =>
                    season.name.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    ) ||
                    (season.description?.toLowerCase().contains(
                          _searchQuery.value.toLowerCase(),
                        ) ??
                        false),
              )
              .toList();
    }

    if (_selectedFilter.value != 'all') {
      seasons =
          seasons.where((season) {
            switch (_selectedFilter.value) {
              case 'active':
                return season.isActive;
              case 'closed':
                return !season.isActive;
              default:
                return true;
            }
          }).toList();
    }

    return seasons;
  }

  Widget _buildSeasonCard(Season season) {
    final seasonController = Get.find<SeasonController>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        season.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    season.isActive ? Icons.play_circle : Icons.pause_circle,
                    color: season.isActive ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (season.description?.isNotEmpty ?? false)
                        Text(
                          season.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        season.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    season.statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: season.isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSeasonInfo(
                  'Date Range',
                  season.dateRangeText,
                  Icons.calendar_today,
                ),
                _buildSeasonInfo(
                  'Total Sales',
                  'KSh ${season.totalSales.toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
                _buildSeasonInfo(
                  'Transactions',
                  '${season.totalTransactions}',
                  Icons.receipt,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!season.isActive) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                      onPressed: () => _confirmActivateSeason(season),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Activate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (season.isActive) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _confirmCloseSeason(season),
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B4513),
                      side: const BorderSide(color: Color(0xFF8B4513)),
                    ),
                    onPressed: () => _showSeasonStatsDialog(season),
                    icon: const Icon(Icons.analytics, size: 16),
                    label: const Text('Stats'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showEditSeasonDialog(season),
                  icon: const Icon(Icons.edit, color: Color(0xFF8B4513)),
                  tooltip: 'Edit Period',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonInfo(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showCreateSeasonDialog(String type) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      type == 'coffee' ? Icons.agriculture : Icons.inventory,
                      color: const Color(0xFF8B4513),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create New ${type == 'coffee' ? 'Coffee Season' : 'Inventory Period'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText:
                        '${type == 'coffee' ? 'Season' : 'Period'} Name *',
                    border: const OutlineInputBorder(),
                    hintText:
                        type == 'coffee'
                            ? 'e.g., 2024/2025'
                            : 'e.g., 2025 Sales Period',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Obx(
                  () => ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(startDate.value),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate.value,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 2),
                        ),
                      );
                      if (date != null) {
                        startDate.value = date;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => CheckboxListTile(
                    value: hasEndDate.value,
                    onChanged: (value) => hasEndDate.value = value ?? false,
                    title: const Text('Set End Date'),
                    subtitle: Text(
                      type == 'coffee'
                          ? 'Set end date for fixed collection period'
                          : 'Leave unchecked for ongoing period',
                    ),
                  ),
                ),
                Obx(
                  () =>
                      hasEndDate.value
                          ? ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('End Date'),
                            subtitle: Text(
                              DateFormat('dd/MM/yyyy').format(endDate.value),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate.value,
                                firstDate: startDate.value,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (date != null) {
                                endDate.value = date;
                              }
                            },
                          )
                          : const SizedBox(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        type == 'coffee'
                            ? const Color(0xFF6B4423).withOpacity(0.1)
                            : const Color(0xFF8B4513).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type == 'coffee' ? Icons.agriculture : Icons.inventory,
                        color:
                            type == 'coffee'
                                ? const Color(0xFF6B4423)
                                : const Color(0xFF8B4513),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Creating ${type == 'coffee' ? 'Coffee Collection Season' : 'Inventory Period'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              type == 'coffee'
                                  ? const Color(0xFF6B4423)
                                  : const Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            type == 'coffee'
                                ? const Color(0xFF6B4423)
                                : const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          () => _createSeason(
                            nameController.text,
                            descriptionController.text,
                            startDate.value,
                            hasEndDate.value ? endDate.value : null,
                            type,
                          ),
                      child: Text(
                        'Create ${type == 'coffee' ? 'Season' : 'Period'}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createSeason(
    String name,
    String description,
    DateTime startDate,
    DateTime? endDate,
    String type,
  ) async {
    // Ensure a non-empty name by generating a sensible default when none is provided
    final String effectiveName =
        name.trim().isEmpty
            ? '${type == 'coffee' ? 'Season' : 'Period'} ${DateFormat('yyyy-MM-dd').format(startDate)}'
            : name.trim();

    await Get.find<SeasonController>().createSeason(
      name: effectiveName,
      description: description.isEmpty ? null : description,
      startDate: startDate,
      endDate: endDate,
      type: type,
    );

    // Close dialog only if no error
    if (Get.find<SeasonController>().error.value.isEmpty) {
      Get.back();
    } else {
      Get.snackbar(
        'Error',
        Get.find<SeasonController>().error.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showEditSeasonDialog(Season season) {
    final nameController = TextEditingController(text: season.name);
    final descriptionController = TextEditingController(
      text: season.description ?? '',
    );
    final RxBool hasEndDate = (season.endDate != null).obs;
    final Rx<DateTime> startDate = season.startDate.obs;
    final Rx<DateTime> endDate =
        (season.endDate ?? DateTime.now().add(const Duration(days: 365))).obs;

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Period',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Period Name *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Obx(
                  () => ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(startDate.value),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate.value,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 2),
                        ),
                      );
                      if (date != null) {
                        startDate.value = date;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => CheckboxListTile(
                    value: hasEndDate.value,
                    onChanged: (value) => hasEndDate.value = value ?? false,
                    title: const Text('Set End Date'),
                    subtitle: const Text('Leave unchecked for ongoing period'),
                  ),
                ),
                Obx(
                  () =>
                      hasEndDate.value
                          ? ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('End Date'),
                            subtitle: Text(
                              DateFormat('dd/MM/yyyy').format(endDate.value),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate.value,
                                firstDate: startDate.value,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (date != null) {
                                endDate.value = date;
                              }
                            },
                          )
                          : const SizedBox(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          () => _updateSeason(
                            season,
                            nameController.text,
                            descriptionController.text,
                            startDate.value,
                            hasEndDate.value ? endDate.value : null,
                          ),
                      child: const Text('Update Period'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateSeason(
    Season season,
    String name,
    String description,
    DateTime startDate,
    DateTime? endDate,
  ) {
    final updatedSeason = season.copyWith(
      name: name,
      description: description.isEmpty ? null : description,
      startDate: startDate,
      endDate: endDate,
    );

    Get.find<SeasonController>().updateSeason(updatedSeason);
    Get.back();
  }

  void _confirmActivateSeason(Season season) {
    Get.dialog(
      AlertDialog(
        title: const Text('Activate Period'),
        content: Text(
          'Are you sure you want to activate "${season.name}"?\n\nThis will deactivate any other active period.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final seasonController = Get.find<SeasonController>();
              seasonController.activateSeason(season.id);
              Get.back();
            },
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  void _confirmCloseSeason(Season season) {
    Get.dialog(
      AlertDialog(
        title: const Text('Close Period'),
        content: Text(
          'Are you sure you want to close "${season.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final seasonController = Get.find<SeasonController>();
              seasonController.closeSeason(season.id);
              Get.back();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSeasonStatsDialog(Season season) async {
    final seasonController = Get.find<SeasonController>();
    final stats = await seasonController.getSeasonStatistics(season.id);
    final memberSummaries = await seasonController.getMemberSeasonSummaries(
      season.id,
    );

    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Period Statistics - ${season.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (stats['sales'] != null && stats['sales'].isNotEmpty) ...[
                const Text(
                  'Sales Overview:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatItem(
                  'Total Sales',
                  'KSh ${(stats['sales']['totalAmount'] ?? 0).toStringAsFixed(2)}',
                ),
                _buildStatItem(
                  'Total Transactions',
                  '${stats['sales']['totalSales'] ?? 0}',
                ),
                _buildStatItem(
                  'Unique Members',
                  '${stats['sales']['uniqueMembers'] ?? 0}',
                ),
                _buildStatItem(
                  'Average Sale',
                  'KSh ${(stats['sales']['averageSale'] ?? 0).toStringAsFixed(2)}',
                ),
                const SizedBox(height: 20),
              ],
              if (memberSummaries.isNotEmpty) ...[
                const Text(
                  'Top Members:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount:
                        memberSummaries.length > 10
                            ? 10
                            : memberSummaries.length,
                    itemBuilder: (context, index) {
                      final member = memberSummaries[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(member.memberName),
                        subtitle: Text(
                          '${member.totalTransactions} transactions',
                        ),
                        trailing: Text(
                          'KSh ${member.totalPurchases.toStringAsFixed(2)}',
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text('No sales data available for this period'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
