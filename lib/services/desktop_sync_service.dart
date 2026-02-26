import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class DesktopSyncService {
  // Base URL for Desktop application API (configurable)
  String baseUrl;
  
  // API endpoints
  static const String _authEndpoint = '/api/auth/login';
  static const String _collectionsEndpoint = '/api/collections';
  static const String _salesEndpoint = '/api/sales';
  static const String _membersEndpoint = '/api/members';
  static const String _testConnectionEndpoint = '/api/test';
  static const String _syncStatusEndpoint = '/api/sync/status';
  
  // Secure storage for credentials
  final _secureStorage = const FlutterSecureStorage();
  
  // HTTP client for API requests
  final http.Client _httpClient;
  
  // Token for authentication
  String? _authToken;
  
  DesktopSyncService({
    this.baseUrl = 'http://192.168.1.100:8080', // Default LAN address
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  
  // Save desktop app connection settings
  Future<void> saveConnectionSettings({
    required String serverAddress,
    required String port,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: 'desktop_server_address', value: serverAddress);
    await _secureStorage.write(key: 'desktop_port', value: port);
    await _secureStorage.write(key: 'desktop_username', value: username);
    await _secureStorage.write(key: 'desktop_password', value: password);
    
    // Update base URL
    baseUrl = 'http://$serverAddress:$port';
  }
  
  // Get stored connection settings
  Future<Map<String, String?>> getConnectionSettings() async {
    final serverAddress = await _secureStorage.read(key: 'desktop_server_address');
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
  
  // Authenticate with desktop application
  Future<bool> authenticate() async {
    try {
      final credentials = await getConnectionSettings();
      final username = credentials['username'];
      final password = credentials['password'];
      
      if (username == null || password == null) {
        throw Exception('Desktop app credentials not found');
      }
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl$_authEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _authToken = jsonData['token'];
        await _secureStorage.write(key: 'desktop_auth_token', value: _authToken);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }
  
  // Generate authorization headers
  Future<Map<String, String>> _getAuthHeaders() async {
    if (_authToken == null) {
      _authToken = await _secureStorage.read(key: 'desktop_auth_token');
    }
    
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
  
  // Test connection to desktop application
  Future<bool> testConnection() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl$_testConnectionEndpoint'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test error: $e');
      return false;
    }
  }
  
  // Send coffee collection to desktop app
  Future<bool> sendCoffeeCollection(CoffeeCollection collection) async {
    try {
      final headers = await _getAuthHeaders();
      
      // Format data for desktop app
      final Map<String, dynamic> collectionData = {
        'id': collection.id,
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
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl$_collectionsEndpoint'),
        headers: headers,
        body: json.encode(collectionData),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 401) {
        // Token expired, re-authenticate
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
  
  // Send sale to desktop app
  Future<bool> sendSale(Sale sale) async {
    try {
      final headers = await _getAuthHeaders();
      
      // Format sale data
      final Map<String, dynamic> saleData = {
        'id': sale.id,
        'memberId': sale.memberId,
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
        'items': sale.items.map((item) => {
          'id': item.id,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
          'notes': item.notes,
        }).toList(),
      };
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl$_salesEndpoint'),
        headers: headers,
        body: json.encode(saleData),
      ).timeout(const Duration(seconds: 15));
      
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
  
  // Sync all pending coffee collections
  Future<Map<String, dynamic>> syncPendingCollections(List<CoffeeCollection> pendingCollections) async {
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
          (results['errors'] as List<String>).add('Failed to sync collection: ${collection.receiptNumber}');
        }
      } catch (e) {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add('Error syncing collection ${collection.receiptNumber}: $e');
      }
    }
    
    return results;
  }
  
  // Sync all pending sales
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
          (results['errors'] as List<String>).add('Failed to sync sale: ${sale.receiptNumber}');
        }
      } catch (e) {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add('Error syncing sale ${sale.receiptNumber}: $e');
      }
    }
    
    return results;
  }
  
  // Pull members from desktop app
  Future<List<Farmer>> pullMembers() async {
    try {
      final headers = await _getAuthHeaders();
      
      final response = await _httpClient.get(
        Uri.parse('$baseUrl$_membersEndpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
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
            registrationDate: DateTime.parse(memberData['registrationDate'] ?? DateTime.now().toIso8601String()),
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
  
  // Get sync status from desktop app
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final headers = await _getAuthHeaders();
      
      final response = await _httpClient.get(
        Uri.parse('$baseUrl$_syncStatusEndpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {'status': 'error', 'message': 'Failed to get sync status'};
    } catch (e) {
      print('Error getting sync status: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }
  
  // Dispose resources
  void dispose() {
    _httpClient.close();
  }
}