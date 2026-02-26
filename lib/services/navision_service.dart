import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class NavisionService {
  // Base URL for Navision/Dynamics 365 Business Central API
  final String baseUrl;
  
  // API endpoints
  static const String _farmersEndpoint = '/api/v1.0/farmers';
  static const String _collectionsEndpoint = '/api/v1.0/coffeeCollections';
  
  // Secure storage for credentials
  final _secureStorage = const FlutterSecureStorage();
  
  // HTTP client for API requests
  final http.Client _httpClient;
  
  NavisionService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();
  
  // Store Navision credentials securely
  Future<void> saveCredentials({
    required String username,
    required String password,
    required String companyId,
  }) async {
    await _secureStorage.write(key: 'navision_username', value: username);
    await _secureStorage.write(key: 'navision_password', value: password);
    await _secureStorage.write(key: 'navision_company_id', value: companyId);
  }
  
  // Get stored credentials
  Future<Map<String, String?>> getCredentials() async {
    final username = await _secureStorage.read(key: 'navision_username');
    final password = await _secureStorage.read(key: 'navision_password');
    final companyId = await _secureStorage.read(key: 'navision_company_id');
    
    return {
      'username': username,
      'password': password,
      'companyId': companyId,
    };
  }
  
  // Generate authorization header
  Future<Map<String, String>> _getAuthHeaders() async {
    final credentials = await getCredentials();
    final username = credentials['username'];
    final password = credentials['password'];
    
    if (username == null || password == null) {
      throw Exception('Navision credentials not found');
    }
    
    final basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    
    return {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  // Test connection to Navision
  Future<bool> testConnection() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1.0/companies'),
        headers: headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Pull farmer data from Navision
  Future<List<Farmer>> pullFarmers() async {
    try {
      final headers = await _getAuthHeaders();
      final credentials = await getCredentials();
      final companyId = credentials['companyId'];
      
      if (companyId == null) {
        throw Exception('Company ID not found');
      }
      
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1.0/companies($companyId)$_farmersEndpoint'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> farmersData = jsonData['value'];
        
        return farmersData.map((farmerData) {
          // Map Navision fields to our Farmer model
          return Farmer(
            id: farmerData['id'] ?? '',
            farmerNumber: farmerData['farmerNumber'] ?? '',
            fullName: farmerData['displayName'] ?? '',
            idNumber: farmerData['idNumber'] ?? '',
            phoneNumber: farmerData['phoneNumber'],
            email: farmerData['email'],
            registrationDate: DateTime.parse(farmerData['registrationDate'] ?? DateTime.now().toIso8601String()),
            gender: farmerData['gender'] ?? 'Unknown',
            route: farmerData['route'] ?? 'Default',
            isActive: farmerData['status'] == 'Active',
          );
        }).toList();
      } else {
        throw Exception('Failed to load farmers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error pulling farmers: $e');
    }
  }
  
  // Send coffee collection details to Navision
  Future<bool> sendCoffeeCollection(CoffeeCollection collection) async {
    try {
      final headers = await _getAuthHeaders();
      final credentials = await getCredentials();
      final companyId = credentials['companyId'];
      
      if (companyId == null) {
        throw Exception('Company ID not found');
      }
      
      // Format data for Navision
      final Map<String, dynamic> collectionData = {
        'farmerId': collection.memberId,
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
        'receiptNumber': collection.receiptNumber,
        'isManualEntry': collection.isManualEntry,
        'collectedBy': collection.userName ?? 'App User',
        'notes': 'Coffee collection via mobile app',
      };
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1.0/companies($companyId)$_collectionsEndpoint'),
        headers: headers,
        body: json.encode(collectionData),
      );
      
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      throw Exception('Error sending coffee collection: $e');
    }
  }
  
  // Sync all pending coffee collections to Navision
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
          (results['errors'] as List<String>).add('Failed to sync collection ID: ${collection.id}');
        }
      } catch (e) {
        results['failed'] = (results['failed'] as int) + 1;
        (results['errors'] as List<String>).add('Error syncing collection ID ${collection.id}: $e');
      }
    }
    
    return results;
  }
  
  // Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
