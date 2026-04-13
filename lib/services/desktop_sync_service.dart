import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../services/services.dart';

/// A [_SyncedIds] snapshot returned by [DesktopSyncService.getSyncedIds].
/// Contains the sets of record IDs that the desktop app already holds so
/// the mobile app can compute the difference without a local DB service.
class _SyncedIds {
  final Set<String> collectionIds;
  final Set<String> saleIds;

  const _SyncedIds({required this.collectionIds, required this.saleIds});
}

class DesktopSyncService {
  // ── Base URL ────────────────────────────────────────────────────────────────
  String baseUrl;

  // ── API endpoints ───────────────────────────────────────────────────────────
  static const String _authEndpoint = '/api/auth/login';
  static const String _collectionsEndpoint = '/api/collections';
  static const String _salesEndpoint = '/api/sales';
  static const String _membersEndpoint = '/api/members';
  static const String _testConnectionEndpoint = '/api/test';
  static const String _syncStatusEndpoint = '/api/sync/status';
  static const String _syncedIdsEndpoint = '/api/sync/synced-ids';

  // ── Internal state ──────────────────────────────────────────────────────────
  final _secureStorage = const FlutterSecureStorage();
  final http.Client _httpClient;
  String? _authToken;

  // ── Constructor ─────────────────────────────────────────────────────────────
  DesktopSyncService({
    this.baseUrl = 'http://192.168.1.100:8080',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ── SettingsService accessor ─────────────────────────────────────────────────
  // Resolved lazily via GetX so we never take a hard constructor dependency.
  SettingsService get _settingsService => Get.find<SettingsService>();

  /// Returns the factory name stored in [OrganizationSettings], or an empty
  /// string when no settings have been saved yet.
  Future<String> _getFactory() async {
    try {
      final orgSettings = _settingsService.organizationSettings.value;
      final factory = orgSettings.factory ?? '';
      if (factory.isEmpty) {
        print('DesktopSyncService: factory not set in OrganizationSettings');
      }
      return factory;
    } catch (e) {
      print('DesktopSyncService: could not read factory from settings — $e');
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Settings persistence
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> saveConnectionSettings({
    required String serverAddress,
    required String port,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(
      key: 'desktop_server_address',
      value: serverAddress,
    );
    await _secureStorage.write(key: 'desktop_port', value: port);
    await _secureStorage.write(key: 'desktop_username', value: username);
    await _secureStorage.write(key: 'desktop_password', value: password);
    baseUrl = 'http://$serverAddress:$port';
  }

  Future<Map<String, String?>> getConnectionSettings() async {
    final serverAddress = await _secureStorage.read(
      key: 'desktop_server_address',
    );
    final port = await _secureStorage.read(key: 'desktop_port');
    final username = await _secureStorage.read(key: 'desktop_username');
    final password = await _secureStorage.read(key: 'desktop_password');

    if (serverAddress != null && port != null) {
      baseUrl = 'http://$serverAddress:$port';
    }

    return {
      'serverAddress': serverAddress,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Auth
  // ══════════════════════════════════════════════════════════════════════════════

  Future<bool> authenticate() async {
    try {
      final credentials = await getConnectionSettings();
      final username = credentials['username'];
      final password = credentials['password'];

      if (username == null || password == null) {
        throw Exception('Desktop app credentials not found');
      }

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$_authEndpoint'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _authToken = jsonData['token'];
        await _secureStorage.write(
          key: 'desktop_auth_token',
          value: _authToken,
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    _authToken ??= await _secureStorage.read(key: 'desktop_auth_token');
    if (_authToken == null) {
      final authenticated = await authenticate();
      if (!authenticated) {
        throw Exception('Failed to authenticate with desktop application');
      }
    }
    return {
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Connectivity
  // ══════════════════════════════════════════════════════════════════════════════

  Future<bool> testConnection() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl$_testConnectionEndpoint'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Sync-ID diffing
  // ══════════════════════════════════════════════════════════════════════════════

  /// Fetches the full set of collection and sale IDs already stored on the
  /// desktop app in a single HTTP call.
  ///
  /// The Java server endpoint (`GET /api/sync/synced-ids`) returns:
  /// ```json
  /// {
  ///   "collectionIds": ["id1", "id2", ...],
  ///   "saleIds":       ["id3", "id4", ...]
  /// }
  /// ```
  Future<_SyncedIds> getSyncedIds() async {
    final headers = await _getAuthHeaders();

    final response = await _httpClient
        .get(Uri.parse('$baseUrl$_syncedIdsEndpoint'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      _authToken = null;
      await authenticate();
      return getSyncedIds(); // retry once after re-auth
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch synced IDs: HTTP ${response.statusCode}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;

    return _SyncedIds(
      collectionIds: Set<String>.from(
        (body['collectionIds'] as List<dynamic>? ?? []).cast<String>(),
      ),
      saleIds: Set<String>.from(
        (body['saleIds'] as List<dynamic>? ?? []).cast<String>(),
      ),
    );
  }

  /// Returns those [allLocalCollections] whose IDs are **not** yet present on
  /// the desktop app, i.e. the records that still need to be pushed.
  Future<List<CoffeeCollection>> getUnsyncedCollections(
    List<CoffeeCollection> allLocalCollections,
  ) async {
    if (allLocalCollections.isEmpty) return const [];
    final synced = await getSyncedIds();
    return allLocalCollections
        .where((c) => !synced.collectionIds.contains(c.id))
        .toList();
  }

  /// Returns those [allLocalSales] whose IDs are **not** yet present on the
  /// desktop app, i.e. the records that still need to be pushed.
  Future<List<Sale>> getUnsyncedSales(List<Sale> allLocalSales) async {
    if (allLocalSales.isEmpty) return const [];
    final synced = await getSyncedIds();
    return allLocalSales.where((s) => !synced.saleIds.contains(s.id)).toList();
  }

  /// Convenience method that fetches synced IDs **once** and returns both
  /// unsynced collections and unsynced sales in a single round-trip.
  Future<({List<CoffeeCollection> collections, List<Sale> sales})>
  getUnsyncedRecords({
    required List<CoffeeCollection> allLocalCollections,
    required List<Sale> allLocalSales,
  }) async {
    final synced = await getSyncedIds();

    return (
      collections:
          allLocalCollections
              .where((c) => !synced.collectionIds.contains(c.id))
              .toList(),
      sales:
          allLocalSales.where((s) => !synced.saleIds.contains(s.id)).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Push records
  // ══════════════════════════════════════════════════════════════════════════════

  Future<bool> sendCoffeeCollection(CoffeeCollection collection) async {
    try {
      final headers = await _getAuthHeaders();

      // Resolve factory from OrganizationSettings stored in SQLite.
      // Falls back to an empty string if settings have not been saved yet.
      final String factory = await _getFactory();

      final Map<String, dynamic> collectionData = {
        'id': collection.id,
        'factory': factory, // ← NEW
        'memberId': collection.memberId,
        'memberNumber': collection.memberNumber,
        'memberName': collection.memberName,
        'collectionDate': collection.collectionDate.toIso8601String(),
        'seasonId': collection.seasonId,
        'seasonName': collection.seasonName,
        'productType': collection.productType,
        'grossWeight': collection.grossWeight,
        'tareWeight': collection.tareWeight,
        'netWeight': collection.netWeight,
        'numberOfBags': collection.numberOfBags,
        'pricePerKg': collection.pricePerKg,
        'totalValue': collection.totalValue,
        'receiptNumber': collection.receiptNumber,
        'isManualEntry': collection.isManualEntry,
        'collectedBy': collection.userName ?? 'App User',
        'userId': collection.userId,
      };

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$_collectionsEndpoint'),
            headers: headers,
            body: json.encode(collectionData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        _authToken = null;
        await authenticate();
        return await sendCoffeeCollection(collection);
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error sending coffee collection: $e');
      return false;
    }
  }

  Future<bool> sendSale(Sale sale) async {
    try {
      final headers = await _getAuthHeaders();

      // Resolve factory from OrganizationSettings stored in SQLite.
      // Falls back to an empty string if settings have not been saved yet.
      final String factory = await _getFactory();

      final Map<String, dynamic> saleData = {
        'id': sale.id,
        'factory': factory, // ← NEW
        'memberId': sale.memberId,
        'memberNumber': sale.memberNumber,
        'memberName': sale.memberName,
        'saleType': sale.saleType,
        'totalAmount': sale.totalAmount,
        'paidAmount': sale.paidAmount,
        'balanceAmount': sale.balanceAmount,
        'saleDate': sale.saleDate.toIso8601String(),
        'receiptNumber': sale.receiptNumber,
        'notes': sale.notes,
        'userId': sale.userId,
        'userName': sale.userName,
        'seasonId': sale.seasonId,
        'seasonName': sale.seasonName,
        'items':
            sale.items
                .map(
                  (item) => {
                    'id': item.id,
                    'productId': item.productId,
                    'productName': item.productName,
                    'quantity': item.quantity,
                    'unitPrice': item.unitPrice,
                    'totalPrice': item.totalPrice,
                    'packSizeSold': item.packSizeSold,
                    'notes': item.notes,
                  },
                )
                .toList(),
      };

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$_salesEndpoint'),
            headers: headers,
            body: json.encode(saleData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        _authToken = null;
        await authenticate();
        return await sendSale(sale);
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error sending sale: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Bulk sync helpers
  // ══════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> syncPendingCollections(
    List<CoffeeCollection> pendingCollections,
  ) async {
    final Map<String, dynamic> results = {
      'success': 0,
      'failed': 0,
      'errors': <String>[],
    };

    for (final collection in pendingCollections) {
      try {
        final success = await sendCoffeeCollection(collection);
        if (success) {
          results['success'] = (results['success'] as int) + 1;
        } else {
          results['failed'] = (results['failed'] as int) + 1;
          (results['errors'] as List<String>).add(
            'Failed to sync collection: ${collection.receiptNumber ?? collection.id}',
          );
        }
      } catch (e) {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add(
          'Error syncing collection ${collection.receiptNumber ?? collection.id}: $e',
        );
      }
    }

    return results;
  }

  Future<Map<String, dynamic>> syncPendingSales(List<Sale> pendingSales) async {
    final Map<String, dynamic> results = {
      'success': 0,
      'failed': 0,
      'errors': <String>[],
    };

    for (final sale in pendingSales) {
      try {
        final success = await sendSale(sale);
        if (success) {
          results['success'] = (results['success'] as int) + 1;
        } else {
          results['failed'] = (results['failed'] as int) + 1;
          (results['errors'] as List<String>).add(
            'Failed to sync sale: ${sale.receiptNumber ?? sale.id}',
          );
        }
      } catch (e) {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add(
          'Error syncing sale ${sale.receiptNumber ?? sale.id}: $e',
        );
      }
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Pull helpers
  // ══════════════════════════════════════════════════════════════════════════════

  Future<List<Farmer>> pullMembers() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _httpClient
          .get(Uri.parse('$baseUrl$_membersEndpoint'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        _authToken = null;
        await authenticate();
        return await pullMembers();
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> membersData = jsonData['data'];

        return membersData.map((memberData) {
          return Farmer(
            id: memberData['id'] ?? '',
            farmerNumber: memberData['memberNumber'] ?? '',
            fullName: memberData['fullName'] ?? '',
            idNumber: memberData['idNumber'] ?? '',
            phoneNumber: memberData['phoneNumber'],
            email: memberData['email'],
            registrationDate: DateTime.parse(
              memberData['registrationDate'] ??
                  DateTime.now().toIso8601String(),
            ),
            gender: memberData['gender'] ?? 'Unknown',
            route: memberData['zone'] ?? 'Default',
            isActive: memberData['isActive'] ?? true,
          );
        }).toList();
      } else {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
    } catch (e) {
      print('Error pulling members: $e');
      throw Exception('Error pulling members: $e');
    }
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _httpClient
          .get(Uri.parse('$baseUrl$_syncStatusEndpoint'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      return {'status': 'error', 'message': 'Failed to get sync status'};
    } catch (e) {
      print('Error getting sync status: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
