import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/services.dart';
import '../../services/desktop_sync_service.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../controllers/controllers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight result model so the UI can show per-type breakdowns.
// ─────────────────────────────────────────────────────────────────────────────
class _SyncResult {
  final int collectionsSuccess;
  final int collectionsFailed;
  final int salesSuccess;
  final int salesFailed;
  final List<String> errors;
  final DateTime completedAt;

  const _SyncResult({
    required this.collectionsSuccess,
    required this.collectionsFailed,
    required this.salesSuccess,
    required this.salesFailed,
    required this.errors,
    required this.completedAt,
  });

  int get totalSuccess => collectionsSuccess + salesSuccess;
  int get totalFailed => collectionsFailed + salesFailed;
  bool get hasErrors => errors.isNotEmpty;
  bool get allSucceeded => totalFailed == 0 && totalSuccess > 0;
  bool get nothingToSync => totalSuccess == 0 && totalFailed == 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class NavisionSettingsScreen extends StatefulWidget {
  static const String routeName = '/navision-settings';

  const NavisionSettingsScreen({super.key});

  @override
  State<NavisionSettingsScreen> createState() => _NavisionSettingsScreenState();
}

class _NavisionSettingsScreenState extends State<NavisionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverAddressController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool _isSyncing = false;
  bool _obscurePassword = true;

  // Connection-test feedback
  String? _connectionStatus;
  bool? _connectionSuccess;

  // Sync feedback
  String _syncProgressMessage = '';
  double? _syncProgress; // null = indeterminate, 0.0-1.0 = determinate
  _SyncResult? _lastSyncResult;

  DesktopSyncService? _desktopSyncService;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Settings persistence ───────────────────────────────────────────────────

  Future<void> _loadSavedSettings() async {
    setState(() => _isLoading = true);

    try {
      _desktopSyncService = DesktopSyncService();
      final settings = await _desktopSyncService!.getConnectionSettings();

      setState(() {
        _serverAddressController.text = settings['serverAddress'] ?? '';
        _portController.text = settings['port'] ?? '8080';
        _usernameController.text = settings['username'] ?? '';
        _passwordController.text = settings['password'] ?? '';
      });
    } catch (e) {
      _showSnackbar('Error', 'Error loading settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _desktopSyncService!.saveConnectionSettings(
        serverAddress: _serverAddressController.text.trim(),
        port: _portController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      _showSnackbar(
        'Success',
        'Desktop sync settings saved successfully',
        isError: false,
      );
    } catch (e) {
      _showSnackbar('Error', 'Error saving settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Connection test ────────────────────────────────────────────────────────

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection…';
      _connectionSuccess = null;
    });

    try {
      final tempService = DesktopSyncService(
        baseUrl:
            'http://${_serverAddressController.text.trim()}:${_portController.text.trim()}',
      );

      await tempService.saveConnectionSettings(
        serverAddress: _serverAddressController.text.trim(),
        port: _portController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final reachable = await tempService.testConnection();
      if (!reachable) {
        setState(() {
          _connectionSuccess = false;
          _connectionStatus =
              'Could not reach the desktop application. '
              'Make sure it is running and the address/port are correct.';
        });
        return;
      }

      final authenticated = await tempService.authenticate();

      setState(() {
        _connectionSuccess = authenticated;
        _connectionStatus = authenticated
            ? 'Connection successful! Desktop app is reachable and credentials are valid.'
            : 'Desktop app is reachable but authentication failed. '
                'Please check your username and password.';
      });
    } catch (e) {
      setState(() {
        _connectionSuccess = false;
        _connectionStatus = 'Error testing connection: $e';
      });
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  /// Main sync entry-point.  Fetches pending local records, pushes them to the
  /// desktop app, then marks successfully sent records as synced.
  Future<void> _performSync() async {
    if (_desktopSyncService == null) return;

    // Make sure we have saved credentials before syncing
    if (!_formKey.currentState!.validate()) {
      _showSnackbar(
        'Validation',
        'Please fill in all connection fields before syncing.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _lastSyncResult = null;
      _syncProgressMessage = 'Authenticating with desktop app…';
      _syncProgress = null; // indeterminate spinner
    });

    try {
      // ── 1. Ensure credentials are saved & service is configured ────────────
      await _desktopSyncService!.saveConnectionSettings(
        serverAddress: _serverAddressController.text.trim(),
        port: _portController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      // ── 2. Quick reachability check ────────────────────────────────────────
      _updateSyncProgress('Checking connection to desktop app…', null);
      final reachable = await _desktopSyncService!.testConnection();
      if (!reachable) {
        _showSnackbar(
          'Connection Failed',
          'Cannot reach the desktop app. Check the IP / port and try again.',
          isError: true,
        );
        return;
      }

      // ── 3. Load pending local records ──────────────────────────────────────
      _updateSyncProgress('Loading pending records from device…', 0.0);

      final List<CoffeeCollection> pendingCollections =
          await _fetchPendingCollections();
      final List<Sale> pendingSales = await _fetchPendingSales();

      final int totalRecords = pendingCollections.length + pendingSales.length;

      if (totalRecords == 0) {
        setState(() {
          _lastSyncResult = _SyncResult(
            collectionsSuccess: 0,
            collectionsFailed: 0,
            salesSuccess: 0,
            salesFailed: 0,
            errors: [],
            completedAt: DateTime.now(),
          );
        });
        return; // shows "Nothing to sync" result card
      }

      // ── 4. Sync collections ────────────────────────────────────────────────
      int collectionsSuccess = 0;
      int collectionsFailed = 0;
      final List<String> errors = [];

      if (pendingCollections.isNotEmpty) {
        _updateSyncProgress(
          'Syncing ${pendingCollections.length} coffee collection(s)…',
          0.1,
        );

        final collResults = await _desktopSyncService!
            .syncPendingCollections(pendingCollections);

        collectionsSuccess = collResults['success'] as int;
        collectionsFailed = collResults['failed'] as int;
        errors.addAll((collResults['errors'] as List).cast<String>());

        // No local mark-as-synced step needed: the server's /synced-ids
        // response acts as the source of truth on the next run.
      }

      // ── 5. Sync sales ──────────────────────────────────────────────────────
      int salesSuccess = 0;
      int salesFailed = 0;

      if (pendingSales.isNotEmpty) {
        _updateSyncProgress(
          'Syncing ${pendingSales.length} sale(s)…',
          pendingCollections.isNotEmpty ? 0.6 : 0.1,
        );

        final saleResults =
            await _desktopSyncService!.syncPendingSales(pendingSales);

        salesSuccess = saleResults['success'] as int;
        salesFailed = saleResults['failed'] as int;
        errors.addAll((saleResults['errors'] as List).cast<String>());

        // Server-side ID set is the source of truth; no local flag needed.
      }

      // ── 6. Surface result ──────────────────────────────────────────────────
      _updateSyncProgress('Finishing up…', 0.95);
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _lastSyncResult = _SyncResult(
          collectionsSuccess: collectionsSuccess,
          collectionsFailed: collectionsFailed,
          salesSuccess: salesSuccess,
          salesFailed: salesFailed,
          errors: errors,
          completedAt: DateTime.now(),
        );
      });

      // Brief success / partial snackbar
      final int totalSuccess = collectionsSuccess + salesSuccess;
      final int totalFailed = collectionsFailed + salesFailed;

      if (totalFailed == 0) {
        _showSnackbar(
          'Sync Complete',
          '$totalSuccess record(s) synced successfully.',
          isError: false,
        );
      } else {
        _showSnackbar(
          'Sync Partial',
          '$totalSuccess synced, $totalFailed failed. See details below.',
          isWarning: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Sync Error',
        'An unexpected error occurred during sync: $e',
        isError: true,
      );
    } finally {
      setState(() {
        _isSyncing = false;
        _syncProgress = null;
        _syncProgressMessage = '';
      });
    }
  }

  // ── Helpers: resolve unsynced records ─────────────────────────────────────
  //
  // Strategy (no LocalDatabaseService required):
  //   1. Pull the full in-memory lists from the real GetX controllers.
  //   2. Ask the desktop app which IDs it already has via GET /api/sync/synced-ids.
  //   3. DesktopSyncService computes the diff and returns only what still needs pushing.
  //
  // If the controllers have not yet finished their background loads we trigger
  // a refresh so the lists are as complete as possible before diffing.

  /// Returns coffee collections that have not yet been pushed to the desktop app.
  Future<List<CoffeeCollection>> _fetchPendingCollections() async {
    try {
      final controller = Get.find<CoffeeCollectionController>();

      // If the service hasn't loaded all collections yet (it defers to background),
      // wait for a full load now so we don't miss records.
      if (controller.collections.isEmpty) {
        await controller.refreshCollections();
      }

      final allLocal = List<CoffeeCollection>.from(controller.collections);
      if (allLocal.isEmpty) return const [];

      return await _desktopSyncService!.getUnsyncedCollections(allLocal);
    } catch (e) {
      debugPrint('[DesktopSync] _fetchPendingCollections error: $e');
      return [];
    }
  }

  /// Returns sales that have not yet been pushed to the desktop app.
  Future<List<Sale>> _fetchPendingSales() async {
    try {
      // InventoryController exposes sales via the InventoryService.
      // InventoryService loads sales in the background on init; if the list is
      // still empty we force a full load before diffing.
      final controller = Get.find<InventoryController>();

      if (controller.sales.isEmpty) {
        await controller.loadAllInventoryData();
      }

      final allLocal = List<Sale>.from(controller.sales);
      if (allLocal.isEmpty) return const [];

      return await _desktopSyncService!.getUnsyncedSales(allLocal);
    } catch (e) {
      debugPrint('[DesktopSync] _fetchPendingSales error: $e');
      return [];
    }
  }

  // NOTE: No _markSynced helpers are needed.
  // The server's /api/sync/synced-ids response is the source of truth;
  // once a record is accepted it appears in that set and is automatically
  // excluded from every subsequent sync run.

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _updateSyncProgress(String message, double? progress) {
    setState(() {
      _syncProgressMessage = message;
      _syncProgress = progress;
    });
  }

  void _showSnackbar(
    String title,
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    Color? bg;
    Color? fg;
    if (isError) {
      bg = Colors.red;
      fg = Colors.white;
    } else if (isWarning) {
      bg = Colors.orange;
      fg = Colors.white;
    } else {
      bg = Colors.green;
      fg = Colors.white;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: bg,
      colorText: fg,
      duration: const Duration(seconds: 4),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Desktop Sync Settings',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    const Text(
                      'Desktop Application (LAN) Sync Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure the connection to the Inuka Admin desktop '
                      'application running on your local network.',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // ── Server Address ───────────────────────────────────────
                    TextFormField(
                      controller: _serverAddressController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                        helperText:
                            'The local IP address of the PC running Inuka Admin',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter the server IP address'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Port ─────────────────────────────────────────────────
                    TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '8080',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet),
                        helperText: 'Default port is 8080',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter the port number';
                        }
                        final port = int.tryParse(v.trim());
                        if (port == null || port < 1 || port > 65535) {
                          return 'Please enter a valid port (1–65535)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Username ─────────────────────────────────────────────
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        helperText:
                            'Same credentials used to log in to Inuka Admin',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your username'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your password'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Save / Test buttons ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading || _isSyncing ? null : _saveSettings,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Settings'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ||
                                    _isTestingConnection ||
                                    _isSyncing
                                ? null
                                : _testConnection,
                            icon: _isTestingConnection
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: const Text('Test Connection'),
                          ),
                        ),
                      ],
                    ),

                    // ── Connection status banner ─────────────────────────────
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 16),
                      _StatusBanner(
                        message: _connectionStatus!,
                        success: _connectionSuccess,
                      ),
                    ],

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // ── Sync section header ───────────────────────────────────
                    const Text(
                      'Data Synchronisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Push coffee collections and sales recorded on this '
                      'device to the Inuka Admin desktop application over '
                      'your local network.',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // ── Sync Now button ───────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _isLoading || _isSyncing || _isTestingConnection
                          ? null
                          : _performSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_isSyncing ? 'Syncing…' : 'Sync Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    // ── Sync progress indicator ───────────────────────────────
                    if (_isSyncing) ...[
                      const SizedBox(height: 12),
                      _SyncProgressCard(
                        message: _syncProgressMessage,
                        progress: _syncProgress,
                      ),
                    ],

                    // ── Sync result card ──────────────────────────────────────
                    if (_lastSyncResult != null && !_isSyncing) ...[
                      const SizedBox(height: 12),
                      _SyncResultCard(result: _lastSyncResult!),
                    ],

                    const SizedBox(height: 12),

                    // ── How-to info card ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'How to find your server IP address',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            '1. Open Inuka Admin on the desktop PC.\n'
                            '2. The IP address is shown in the status bar at '
                            'the bottom of the window.\n'
                            '3. Make sure both devices are on the same Wi-Fi '
                            'or LAN network.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small extracted widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable coloured banner for connection / info feedback.
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool? success; // null = neutral/loading

  const _StatusBanner({required this.message, this.success});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;

    if (success == true) {
      bg = Colors.green.shade50;
      border = Colors.green.shade300;
      fg = Colors.green.shade800;
      icon = Icons.check_circle;
    } else if (success == false) {
      bg = Colors.red.shade50;
      border = Colors.red.shade300;
      fg = Colors.red.shade800;
      icon = Icons.error;
    } else {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
      fg = Colors.grey.shade800;
      icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}

/// Animated card shown while a sync is in progress.
class _SyncProgressCard extends StatelessWidget {
  final String message;
  final double? progress; // null = indeterminate

  const _SyncProgressCard({required this.message, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        border: Border.all(color: Colors.teal.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: progress != null
                ? LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.teal.shade100,
                    color: Colors.teal,
                  )
                : LinearProgressIndicator(
                    backgroundColor: Colors.teal.shade100,
                    color: Colors.teal,
                  ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress! * 100).toStringAsFixed(0)} %',
                style:
                    TextStyle(fontSize: 11, color: Colors.teal.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card shown after sync completes, summarising successes, failures, and errors.
class _SyncResultCard extends StatefulWidget {
  final _SyncResult result;

  const _SyncResultCard({required this.result});

  @override
  State<_SyncResultCard> createState() => _SyncResultCardState();
}

class _SyncResultCardState extends State<_SyncResultCard> {
  bool _showErrors = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final timeStr =
        '${result.completedAt.hour.toString().padLeft(2, '0')}:'
        '${result.completedAt.minute.toString().padLeft(2, '0')}:'
        '${result.completedAt.second.toString().padLeft(2, '0')}';

    final Color headerBg;
    final Color headerFg;
    final Color borderColor;
    final IconData headerIcon;
    final String headline;

    if (result.nothingToSync) {
      headerBg = Colors.blue.shade50;
      headerFg = Colors.blue.shade800;
      borderColor = Colors.blue.shade200;
      headerIcon = Icons.check_circle_outline;
      headline = 'Nothing to sync — device is up to date.';
    } else if (result.allSucceeded) {
      headerBg = Colors.green.shade50;
      headerFg = Colors.green.shade800;
      borderColor = Colors.green.shade300;
      headerIcon = Icons.check_circle;
      headline = '${result.totalSuccess} record(s) synced successfully.';
    } else if (result.totalSuccess == 0) {
      headerBg = Colors.red.shade50;
      headerFg = Colors.red.shade800;
      borderColor = Colors.red.shade300;
      headerIcon = Icons.error;
      headline = 'Sync failed — ${result.totalFailed} record(s) not sent.';
    } else {
      headerBg = Colors.orange.shade50;
      headerFg = Colors.orange.shade800;
      borderColor = Colors.orange.shade300;
      headerIcon = Icons.warning_amber_rounded;
      headline =
          '${result.totalSuccess} synced, ${result.totalFailed} failed.';
    }

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(headerIcon, color: headerFg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: TextStyle(
                        color: headerFg, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: headerFg),
                ),
              ],
            ),
          ),

          // ── Breakdown ────────────────────────────────────────────────────
          if (!result.nothingToSync) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Collections',
                    success: result.collectionsSuccess,
                    failed: result.collectionsFailed,
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Sales',
                    success: result.salesSuccess,
                    failed: result.salesFailed,
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ),
          ],

          // ── Error list (collapsible) ──────────────────────────────────────
          if (result.hasErrors) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => setState(() => _showErrors = !_showErrors),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showErrors
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: headerFg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${result.errors.length} error(s) — tap to '
                      '${_showErrors ? 'hide' : 'view'}',
                      style: TextStyle(
                          fontSize: 13,
                          color: headerFg,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            if (_showErrors)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.errors.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Small pill showing success / failed count for one record type.
class _StatChip extends StatelessWidget {
  final String label;
  final int success;
  final int failed;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.success,
    required this.failed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _dot(Colors.green, '$success ✓'),
                      const SizedBox(width: 6),
                      if (failed > 0) _dot(Colors.red, '$failed ✗'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}