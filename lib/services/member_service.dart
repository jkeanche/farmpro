import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/member_controller.dart';
import '../models/models.dart';
import 'database_helper.dart';

class MemberService extends GetxService {
  static MemberService get to => Get.find();
  
  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();
  
  // Pagination and caching
  static const int _pageSize = 50;
  static const int _maxCacheSize = 500;
  
  // Cache management
  final Map<String, Member> _memberCache = {};
  final Map<String, List<Member>> _pageCache = {};
  final RxList<Member> _currentPageMembers = <Member>[].obs;
  
  // Search and filtering
  final RxString _currentSearchQuery = ''.obs;
  final RxString _currentZoneFilter = ''.obs;
  final RxBool _showActiveOnly = true.obs;
  
  // Pagination state
  final RxInt _currentPage = 0.obs;
  final RxInt _totalMembers = 0.obs;
  final RxBool _hasMorePages = true.obs;
  final RxBool _isLoading = false.obs;
  
  // Getters for reactive state
  List<Member> get currentPageMembers => _currentPageMembers;
  String get currentSearchQuery => _currentSearchQuery.value;
  String get currentZoneFilter => _currentZoneFilter.value;
  bool get showActiveOnly => _showActiveOnly.value;
  int get currentPage => _currentPage.value;
  int get totalMembers => _totalMembers.value;
  bool get hasMorePages => _hasMorePages.value;
  bool get isLoading => _isLoading.value;
  
  Future<MemberService> init() async {
    await _updateTotalCount();
    await loadMembersPage(0, refresh: true);
    await _updateMembersList();
    await _createIndexes();
    return this;
  }
  
  // Create indexes to speed up searches on large data sets
  Future<void> _createIndexes() async {
    try {
      final db = await _dbHelper.database;
      await db.execute('CREATE INDEX IF NOT EXISTS idx_members_memberNumber ON members(memberNumber);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_members_fullName ON members(fullName COLLATE NOCASE);');
      print('✅ Member indexes ensured');
    } catch (e) {
      print('Error creating member indexes: $e');
    }
  }
  
  /// Fast database search that returns a limited number of results (default 20)
  Future<List<Member>> quickSearchMembers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final db = await _dbHelper.database;
    final trimmedQuery = query.trim();
    
    // Check if the query looks like a member number (exact match)
    // First try exact member number match
    final exactResult = await db.query(
      'members',
      where: 'LOWER(memberNumber) = ?',
      whereArgs: [trimmedQuery.toLowerCase()],
      limit: 1,
      orderBy: 'memberNumber ASC',
    );
    
    // If exact match found, return it
    if (exactResult.isNotEmpty) {
      return exactResult.map((m) => Member.fromJson(m)).toList();
    }
    
    // Otherwise, search by name only (partial match)
    final nameQuery = '%${trimmedQuery.toLowerCase()}%';
    final result = await db.query(
      'members',
      where: 'LOWER(fullName) LIKE ?',
      whereArgs: [nameQuery],
      limit: limit,
      orderBy: 'fullName ASC',
    );
    return result.map((m) => Member.fromJson(m)).toList();
  }
  
  // OPTIMIZED PAGINATION METHODS
  
  Future<void> loadMembersPage(int page, {bool refresh = false}) async {
    if (_isLoading.value && !refresh) return;
    
    _isLoading.value = true;
    
    try {
      final cacheKey = _generateCacheKey(page);
      
      // Check cache first (unless refreshing)
      if (!refresh && _pageCache.containsKey(cacheKey)) {
        _currentPageMembers.value = _pageCache[cacheKey]!;
        _currentPage.value = page;
        return;
      }
      
    final db = await _dbHelper.database;
      final offset = page * _pageSize;
      
      // Build optimized query
      String whereClause = 'WHERE 1=1';
      List<dynamic> whereArgs = [];
      
      if (_showActiveOnly.value) {
        whereClause += ' AND isActive = ?';
        whereArgs.add(1);
      }
      
      if (_currentZoneFilter.value.isNotEmpty) {
        whereClause += ' AND zone = ?';
        whereArgs.add(_currentZoneFilter.value);
      }
      
      if (_currentSearchQuery.value.isNotEmpty) {
        whereClause += ' AND searchText LIKE ?';
        whereArgs.add('%${_currentSearchQuery.value.toLowerCase()}%');
      }
      
      final query = '''
        SELECT * FROM members 
        $whereClause 
        ORDER BY fullName ASC 
        LIMIT $_pageSize OFFSET $offset
      ''';
      
      final List<Map<String, dynamic>> memberMaps = await db.rawQuery(query, whereArgs);
      final members = memberMaps.map((map) => Member.fromJson(map)).toList();
      
      // Update cache (with size limit)
      if (_pageCache.length >= _maxCacheSize ~/ _pageSize) {
        _pageCache.clear(); // Simple cache eviction
      }
      _pageCache[cacheKey] = members;
      
      // Update member cache
      for (final member in members) {
        _memberCache[member.id] = member;
      }
      
      _currentPageMembers.value = members;
      _currentPage.value = page;
      _hasMorePages.value = members.length == _pageSize;
      
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> loadNextPage() async {
    if (_hasMorePages.value && !_isLoading.value) {
      await loadMembersPage(_currentPage.value + 1);
    }
  }
  
  Future<void> loadPreviousPage() async {
    if (_currentPage.value > 0 && !_isLoading.value) {
      await loadMembersPage(_currentPage.value - 1);
    }
  }
  
  Future<void> refreshCurrentPage() async {
    await loadMembersPage(_currentPage.value, refresh: true);
    await _updateTotalCount();
  }
  
  // OPTIMIZED SEARCH METHODS
  
  Future<void> searchMembers(String query) async {
    _currentSearchQuery.value = query.toLowerCase();
    _clearCache();
    await loadMembersPage(0, refresh: true);
    await _updateTotalCount();
  }
  
  Future<void> filterByZone(String zone) async {
    _currentZoneFilter.value = zone;
    _clearCache();
    await loadMembersPage(0, refresh: true);
    await _updateTotalCount();
  }
  
  Future<void> toggleActiveFilter() async {
    _showActiveOnly.value = !_showActiveOnly.value;
    _clearCache();
    await loadMembersPage(0, refresh: true);
    await _updateTotalCount();
  }
  
  Future<void> clearAllFilters() async {
    _currentSearchQuery.value = '';
    _currentZoneFilter.value = '';
    _showActiveOnly.value = true;
    _clearCache();
    await loadMembersPage(0, refresh: true);
    await _updateTotalCount();
  }
  
  // EFFICIENT MEMBER LOOKUP METHODS
  
  Future<Member?> getMemberById(String id) async {
    // Check cache first
    if (_memberCache.containsKey(id)) {
      return _memberCache[id];
    }
    
    // Query database
    final db = await _dbHelper.database;
    final result = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final member = Member.fromJson(result.first);
      _memberCache[id] = member;
      return member;
    }
    
    return null;
  }
  
  Future<Member?> getMemberByMemberNumber(String memberNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'members',
      where: 'memberNumber = ?',
      whereArgs: [memberNumber],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final member = Member.fromJson(result.first);
      _memberCache[member.id] = member;
      return member;
    }
    
    return null;
  }
  
  Future<List<Member>> getMembersByMemberNumber(String memberNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'members',
      where: 'memberNumber = ?',
      whereArgs: [memberNumber],
    );
    
    return result.map((map) => Member.fromJson(map)).toList();
  }
  
  Future<Member?> getMemberByIdNumber(String idNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'members',
      where: 'idNumber = ?',
      whereArgs: [idNumber],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final member = Member.fromJson(result.first);
      _memberCache[member.id] = member;
      return member;
    }
    
    return null;
  }
  
  Future<List<Member>> getMembersByIdNumber(String idNumber) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'members',
      where: 'idNumber = ?',
      whereArgs: [idNumber],
    );
    
    return result.map((map) => Member.fromJson(map)).toList();
  }
  
  // OPTIMIZED CRUD OPERATIONS
  
  Future<Member> addMember({
    required String memberNumber,
    required String fullName,
    String? idNumber,
    String? phoneNumber,
    String? email,
    String? gender,
    String? zone,
    double? acreage,
    int? noTrees,
    bool isActive = true,
  }) async {
    // Validation
    final validation = await validateMemberData(
      memberNumber: memberNumber,
      idNumber: idNumber,
    );
    
    if (!(validation['isValid'] as bool)) {
      final errors = validation['errors'] as List<String>;
      final warnings = validation['warnings'] as List<String>;
      
      String errorMessage = errors.join(', ');
      if (warnings.isNotEmpty) {
        errorMessage += '\nDetails: ${warnings.join(', ')}';
      }
      
      throw Exception(errorMessage);
    }
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    
    final member = Member(
      id: id,
      memberNumber: memberNumber,
      fullName: fullName,
      idNumber: idNumber,
      phoneNumber: phoneNumber,
      email: email,
      registrationDate: now,
      gender: gender,
      zone: zone,
      acreage: acreage,
      noTrees: noTrees,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
    
    final db = await _dbHelper.database;
    await db.insert('members', member.toJson());
    
    // Update cache and refresh
    _memberCache[id] = member;
    _clearPageCache();
    await refreshCurrentPage();
    
    return member;
  }
  
  Future<void> updateMember(Member member) async {
    final validation = await validateMemberData(
      memberNumber: member.memberNumber,
      idNumber: member.idNumber,
      excludeMemberId: member.id,
    );
    
    if (!(validation['isValid'] as bool)) {
      final errors = validation['errors'] as List<String>;
      final warnings = validation['warnings'] as List<String>;
      
      String errorMessage = errors.join(', ');
      if (warnings.isNotEmpty) {
        errorMessage += '\nDetails: ${warnings.join(', ')}';
      }
      
      throw Exception(errorMessage);
    }
    
    final updatedMember = member.copyWith(updatedAt: DateTime.now());
    
    final db = await _dbHelper.database;
    await db.update(
      'members',
      updatedMember.toJson(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
    
    // Update cache and refresh
    _memberCache[member.id] = updatedMember;
    _clearPageCache();
    await refreshCurrentPage();
  }
  
  Future<void> deleteMember(String id) async {
    // Check if member has any collections before allowing deletion
    final collectionInfo = await _getMemberCollectionInfo(id);
    if (collectionInfo['hasCollections']) {
      final member = await getMemberById(id);
      final memberName = member?.fullName ?? 'Unknown Member';
      final collectionCount = collectionInfo['count'];
      final seasons = collectionInfo['seasons'] as List<String>;
      
      String seasonText = '';
      if (seasons.isNotEmpty) {
        if (seasons.length == 1) {
          seasonText = ' in season ${seasons.first}';
        } else {
          seasonText = ' across ${seasons.length} seasons: ${seasons.join(', ')}';
        }
      }
      
      throw Exception('''Cannot delete member "$memberName":
      
Member has $collectionCount coffee collection${collectionCount > 1 ? 's' : ''}$seasonText.

To delete this member:
1. First remove all their collections from the collection history
2. Or contact the system administrator
3. Alternatively, you can deactivate the member instead of deleting

Note: Deleting a member with collections could affect financial records and reports.''');
    }

    final db = await _dbHelper.database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
    
    // Update cache and refresh
    _memberCache.remove(id);
    _clearPageCache();
    await refreshCurrentPage();
  }
  
  Future<Map<String, dynamic>> _getMemberCollectionInfo(String memberId) async {
    try {
      final db = await _dbHelper.database;
      
      // Get collection count and seasons
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          GROUP_CONCAT(DISTINCT seasonId) as seasons
        FROM coffee_collections 
        WHERE memberId = ?
      ''', [memberId]);
      
      final count = result.first['count'] as int;
      final seasonsString = result.first['seasons'] as String?;
      
      List<String> seasons = [];
      if (seasonsString != null && seasonsString.isNotEmpty) {
        // Get season names
        final seasonIds = seasonsString.split(',');
        for (String seasonId in seasonIds) {
          try {
            final seasonResult = await db.query(
              'seasons', 
              columns: ['name'],
              where: 'id = ?', 
              whereArgs: [seasonId.trim()]
            );
            if (seasonResult.isNotEmpty) {
              seasons.add(seasonResult.first['name'] as String);
            }
          } catch (e) {
            print('Error getting season name for ID $seasonId: $e');
          }
        }
      }
      
      return {
        'hasCollections': count > 0,
        'count': count,
        'seasons': seasons,
      };
    } catch (e) {
      print('Error checking member collections: $e');
      // In case of error, assume member has collections to be safe
      return {
        'hasCollections': true,
        'count': 0,
        'seasons': <String>[],
      };
    }
  }
  
  Future<void> activateMember(String id) async {
    final member = await getMemberById(id);
    if (member != null) {
      await updateMember(member.activate());
    }
  }
  
  Future<void> deactivateMember(String id) async {
    final member = await getMemberById(id);
    if (member != null) {
      await updateMember(member.deactivate());
    }
  }
  
  // VALIDATION AND UTILITY METHODS
  
  Future<Map<String, dynamic>> validateMemberData({
    required String memberNumber,
    String? idNumber,
    String? excludeMemberId,
  }) async {
    final validationResult = {
      'isValid': true,
      'errors': <String>[],
      'warnings': <String>[],
    };

    // Check for duplicate member number
    final membersWithSameNumber = await getMembersByMemberNumber(memberNumber);
    if (excludeMemberId != null) {
      membersWithSameNumber.removeWhere((m) => m.id == excludeMemberId);
    }
    
    if (membersWithSameNumber.isNotEmpty) {
      validationResult['isValid'] = false;
      (validationResult['errors'] as List<String>).add('Member number $memberNumber already exists');
      
      for (var member in membersWithSameNumber) {
        (validationResult['warnings'] as List<String>).add(
          'Existing member: ${member.fullName} (ID: ${member.id})'
        );
      }
    }

    // Check for duplicate ID number if provided
    if (idNumber != null && idNumber.isNotEmpty) {
      final membersWithSameId = await getMembersByIdNumber(idNumber);
      if (excludeMemberId != null) {
        membersWithSameId.removeWhere((m) => m.id == excludeMemberId);
      }
      
      if (membersWithSameId.isNotEmpty) {
        validationResult['isValid'] = false;
        (validationResult['errors'] as List<String>).add('ID number $idNumber already exists');
        
        for (var member in membersWithSameId) {
          (validationResult['warnings'] as List<String>).add(
            'Existing member: ${member.fullName} (Member #: ${member.memberNumber})'
          );
        }
      }
    }

    return validationResult;
  }
  
  Future<Map<String, dynamic>> findAllDuplicates() async {
    final db = await _dbHelper.database;
    
    // Find duplicate member numbers
    final memberNumberDuplicates = await db.rawQuery('''
      SELECT memberNumber, COUNT(*) as count 
      FROM members 
      GROUP BY memberNumber 
      HAVING count > 1
    ''');
    
    // Find duplicate ID numbers
    final idNumberDuplicates = await db.rawQuery('''
      SELECT idNumber, COUNT(*) as count 
      FROM members 
      WHERE idNumber IS NOT NULL AND idNumber != ''
      GROUP BY idNumber 
      HAVING count > 1
    ''');
    
    return {
      'memberNumberDuplicates': memberNumberDuplicates,
      'idNumberDuplicates': idNumberDuplicates,
    };
  }
  
  Future<List<String>> getZones() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT zone 
      FROM members 
      WHERE zone IS NOT NULL AND zone != '' 
      ORDER BY zone
    ''');
    
    return result.map((row) => row['zone'] as String).toList();
  }
  
  // CACHE MANAGEMENT
  
  void _clearCache() {
    _clearPageCache();
    _clearMemberCache();
  }
  
  void _clearPageCache() {
    _pageCache.clear();
  }
  
  void _clearMemberCache() {
    if (_memberCache.length > _maxCacheSize) {
      _memberCache.clear();
    }
  }
  
  String _generateCacheKey(int page) {
    return 'page_${page}_search_${_currentSearchQuery.value}_zone_${_currentZoneFilter.value}_active_${_showActiveOnly.value}';
  }
  
  Future<void> _updateTotalCount() async {
    final db = await _dbHelper.database;
    
    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];
    
    if (_showActiveOnly.value) {
      whereClause += ' AND isActive = ?';
      whereArgs.add(1);
    }
    
    if (_currentZoneFilter.value.isNotEmpty) {
      whereClause += ' AND zone = ?';
      whereArgs.add(_currentZoneFilter.value);
    }
    
    if (_currentSearchQuery.value.isNotEmpty) {
      whereClause += ' AND searchText LIKE ?';
      whereArgs.add('%${_currentSearchQuery.value.toLowerCase()}%');
    }
    
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM members $whereClause', whereArgs);
    _totalMembers.value = result.first['count'] as int;
  }

  // IMPORT/EXPORT METHODS (optimized for large datasets)
  
  Future<List<Member>> importMembersFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result != null) {
      File file = File(result.files.single.path!);
      String csvContent = await file.readAsString();
      
        List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvContent);
      
        if (csvTable.isEmpty) {
        throw Exception('CSV file is empty');
      }
      
        List<String> headers = csvTable[0].map((header) => header.toString().toLowerCase()).toList();
      List<Member> importedMembers = [];
      List<String> errors = [];
        
        // Remove header row
        final dataRows = csvTable.skip(1).toList();
        final totalRows = dataRows.length;
        
        if (totalRows == 0) {
          throw Exception('No data rows found in CSV file');
        }
        
        // Process in chunks of 50 records
        const chunkSize = 50;
        final totalChunks = (totalRows / chunkSize).ceil();
        
        // Show initial progress dialog
        Get.dialog(
          AlertDialog(
            title: const Text('Importing Members'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Preparing to import $totalRows members...'),
                const SizedBox(height: 8),
                Text('Processing in chunks of $chunkSize records'),
              ],
            ),
          ),
          barrierDismissible: false,
        );
        
        final db = await _dbHelper.database;
        
        // Process each chunk
        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final startIndex = chunkIndex * chunkSize;
          final endIndex = (startIndex + chunkSize).clamp(0, totalRows);
          final chunk = dataRows.sublist(startIndex, endIndex);
          final chunkNumber = chunkIndex + 1;
          
          // Update progress dialog
          Get.back(); // Close previous dialog
          Get.dialog(
            AlertDialog(
              title: const Text('Importing Members'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: chunkIndex / totalChunks,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text('Processing chunk $chunkNumber of $totalChunks'),
                  const SizedBox(height: 8),
                  Text('Records ${startIndex + 1} to $endIndex of $totalRows'),
                  const SizedBox(height: 8),
                  Text('Successfully imported: ${importedMembers.length}'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Errors: ${errors.length}', style: TextStyle(color: Colors.red[600])),
                  ],
                ],
              ),
            ),
            barrierDismissible: false,
          );
          
          // Process chunk in a transaction with timeout
          try {
            int chunkSuccessCount = 0;
            await db.transaction((txn) async {
              for (int i = 0; i < chunk.length; i++) {
                final rowIndex = startIndex + i;
                final actualRowNumber = rowIndex + 2; // +2 because we skipped header and arrays are 0-based
                
                try {
                  List<dynamic> row = chunk[i];
                  
                  // Map CSV columns to member fields
                  String memberNumber = _getCsvValue(row, headers, ['member_number', 'membernumber', 'member number']) ?? '';
                  String fullName = _getCsvValue(row, headers, ['full_name', 'fullname', 'name', 'full name']) ?? '';
                  String? idNumber = _getCsvValue(row, headers, ['id_number', 'idnumber', 'id number']);
                  String? phoneNumber = _getCsvValue(row, headers, ['phone_number', 'phonenumber', 'phone', 'phone number']);
                  
                  // Preserve phone numbers with country codes as-is, especially the + sign
                  if (phoneNumber != null && phoneNumber.isNotEmpty) {
                    // Trim whitespace but preserve the original format including country codes
                    phoneNumber = phoneNumber.trim();
                    
                    // Special handling to preserve + sign that might be lost during CSV parsing
                    // If the phone number starts with 254 but not +254, and it's 12 digits, add the + back
                    if (phoneNumber.startsWith('254') && !phoneNumber.startsWith('+254') && phoneNumber.length == 12) {
                      phoneNumber = '+$phoneNumber';
                      print('📱 Restored + sign for phone number: "$phoneNumber" for member: $memberNumber');
                    }
                    
                    // Log phone number format for debugging
                    print('📱 Importing phone number: "$phoneNumber" for member: $memberNumber');
                    
                    // Optional: Validate phone number format but don't modify it
                    // This helps identify invalid numbers during import without changing valid ones
                    if (!_isValidPhoneNumberFormat(phoneNumber)) {
                      print('⚠️ Warning: Phone number "$phoneNumber" for member $memberNumber may have invalid format');
                      // Still save it as-is, but log the warning
                    }
                  }
                  String? email = _getCsvValue(row, headers, ['email']);
                  String? gender = _getCsvValue(row, headers, ['gender']);
                  String? zone = _getCsvValue(row, headers, ['zone']);
                  double? acreage = _getCsvDouble(row, headers, ['acreage']);
                  int? noTrees = _getCsvInt(row, headers, ['no_trees', 'notrees', 'trees', 'number_of_trees']);
          
          if (memberNumber.isEmpty || fullName.isEmpty) {
                    errors.add('Row $actualRowNumber: Member number and full name are required');
            continue;
          }
          
                  // Check for duplicates within the transaction to avoid database locking
                  final existingMemberNumber = await txn.query(
                    'members',
                    where: 'memberNumber = ?',
                    whereArgs: [memberNumber],
                    limit: 1,
                  );
                  
                  if (existingMemberNumber.isNotEmpty) {
                    errors.add('Row $actualRowNumber: Member number $memberNumber already exists');
                continue;
                  }
                  
                  // Check for duplicate ID number if provided
                  if (idNumber != null && idNumber.isNotEmpty) {
                    final existingIdNumber = await txn.query(
                      'members',
                      where: 'idNumber = ?',
                      whereArgs: [idNumber],
                      limit: 1,
                    );
                    
                    if (existingIdNumber.isNotEmpty) {
                      errors.add('Row $actualRowNumber: ID number $idNumber already exists');
              continue;
            }
          }
          
                  final id = '${DateTime.now().millisecondsSinceEpoch}_$rowIndex';
                  final now = DateTime.now();
                  
                  final member = Member(
                    id: id,
            memberNumber: memberNumber,
            fullName: fullName,
                    idNumber: idNumber,
                    phoneNumber: phoneNumber,
                    email: email,
                    registrationDate: now,
                    gender: gender,
            zone: zone,
            acreage: acreage,
            noTrees: noTrees,
                    isActive: true,
                    createdAt: now,
                    updatedAt: now,
          );
          
                  await txn.insert('members', member.toJson());
          importedMembers.add(member);
                  chunkSuccessCount++;
          
        } catch (e) {
                  errors.add('Row $actualRowNumber: $e');
                  print('❌ Error processing row $actualRowNumber: $e');
                }
              }
            });
            
            print('✅ Completed chunk $chunkNumber: $chunkSuccessCount/${chunk.length} records imported successfully, ${importedMembers.length} total imported so far');
            
            // Small delay to allow UI to update and prevent database overwhelming
            await Future.delayed(const Duration(milliseconds: 300));
            
    } catch (e) {
            print('❌ Error processing chunk $chunkNumber: $e');
            errors.add('Chunk $chunkNumber failed: $e');
            // Continue with next chunk instead of failing completely
          }
        }
        
        // Close progress dialog
        Get.back();
        
        // Show completion summary
        final successCount = importedMembers.length;
        final errorCount = errors.length;
        final totalProcessed = dataRows.length; // Use actual data rows count
        
        String summaryTitle;
        String summaryMessage;
        Color backgroundColor;
        
        if (successCount > 0 && errorCount == 0) {
          summaryTitle = 'Import Successful';
          summaryMessage = 'Successfully imported all $successCount members!';
          backgroundColor = Colors.green;
        } else if (successCount > 0 && errorCount > 0) {
          summaryTitle = 'Import Partially Successful';
          summaryMessage = 'Imported $successCount of $totalProcessed members successfully.\n$errorCount records had validation errors and were skipped.';
          backgroundColor = Colors.orange;
        } else if (successCount == 0 && errorCount > 0) {
          summaryTitle = 'Import Failed';
          summaryMessage = 'No members were imported.\nAll $errorCount records had validation errors.';
          backgroundColor = Colors.red;
              } else {
          summaryTitle = 'Import Complete';
          summaryMessage = 'No data found to import.';
          backgroundColor = Colors.grey;
        }
        
        print('📊 Import Summary: $successCount imported, $errorCount errors, $totalProcessed total records');
        
        // Show detailed results dialog
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(
                  successCount > 0 ? Icons.check_circle : Icons.error,
                  color: backgroundColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(summaryTitle)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summaryMessage),
                if (successCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '✅ $successCount members imported successfully',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                if (errorCount > 0) ...[
                  const SizedBox(height: 16),
                  const Text('Sample Validation Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          errors.take(10).join('\n'), // Show first 10 errors
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                  if (errors.length > 10) ...[
                    const SizedBox(height: 4),
                    Text('... and ${errors.length - 10} more validation errors', 
                         style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        if (errors.isNotEmpty) {
          print('Import completed with ${errors.length} errors:');
          for (String error in errors.take(20)) { // Log first 20 errors
            print('  $error');
          }
        }
        
        // Clear cache and refresh member list
        _clearCache();
        await _updateMembersList(); // Update the legacy members list
        await refreshCurrentPage();
        
        // Force refresh of any controllers using this service
        try {
          final memberController = Get.find<MemberController>();
          memberController.update(); // Force controller update
          } catch (e) {
          print('Could not find MemberController to update: $e');
      }
      
      return importedMembers;
      }
    } catch (e) {
      // Close any open dialogs
      try {
        Get.back();
      } catch (_) {}
      
      Get.snackbar(
        'Import Error',
        'Failed to import CSV: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      
      throw Exception('Failed to import CSV: $e');
    }
    
    return [];
  }
  
  String? _getCsvValue(List<dynamic> row, List<String> headers, List<String> possibleHeaders) {
    for (String header in possibleHeaders) {
      int index = headers.indexOf(header);
      if (index != -1 && index < row.length) {
        // Preserve the original value as much as possible, especially for phone numbers
        var rawValue = row[index];
        String value;
        
        // Handle different data types that might come from CSV parsing
        if (rawValue is String) {
          value = rawValue.trim();
        } else if (rawValue is num) {
          // For numbers, convert to string but preserve format
          value = rawValue.toString().trim();
        } else {
          value = rawValue.toString().trim();
        }
        
        return value.isEmpty ? null : value;
      }
    }
      return null;
  }
  
  /// Basic phone number format validation (doesn't modify the number)
  /// This is used to identify potentially invalid numbers during import
  bool _isValidPhoneNumberFormat(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    
    // Remove common separators for validation
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\.\,]'), '');
    
    // Check for valid Kenyan phone number patterns
    // Supports: +254XXXXXXXXX, 254XXXXXXXXX, 07XXXXXXXX, 01XXXXXXXX, 7XXXXXXXX, 1XXXXXXXX
    final validPatterns = [
      RegExp(r'^\+254[17]\d{8}$'),     // +254XXXXXXXXX
      RegExp(r'^254[17]\d{8}$'),       // 254XXXXXXXXX  
      RegExp(r'^0[17]\d{8}$'),         // 07XXXXXXXX, 01XXXXXXXX
      RegExp(r'^[17]\d{8}$'),          // 7XXXXXXXX, 1XXXXXXXX
    ];
    
    return validPatterns.any((pattern) => pattern.hasMatch(cleaned));
  }
  
  double? _getCsvDouble(List<dynamic> row, List<String> headers, List<String> possibleHeaders) {
    String? value = _getCsvValue(row, headers, possibleHeaders);
    return value != null ? double.tryParse(value) : null;
  }
  
  int? _getCsvInt(List<dynamic> row, List<String> headers, List<String> possibleHeaders) {
    String? value = _getCsvValue(row, headers, possibleHeaders);
    return value != null ? int.tryParse(value) : null;
  }
  
  Future<File?> exportMembersToCsv() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/members_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      
      // Prepare CSV headers
      List<List<String>> csvData = [
        ['Member Number', 'Full Name', 'ID Number', 'Phone Number', 'Email', 'Gender', 'Zone', 'Acreage', 'Number of Trees', 'Status', 'Registration Date']
      ];
      
      // Export all members (not just current page)
      final db = await _dbHelper.database;
      final allMembers = await db.query('members', orderBy: 'fullName ASC');
      
      for (var memberMap in allMembers) {
        final member = Member.fromJson(memberMap);
        csvData.add([
          member.memberNumber,
          member.fullName,
          member.idNumber ?? '',
          member.phoneNumber ?? '',
          member.email ?? '',
          member.gender ?? '',
          member.zone ?? '',
          member.acreage?.toString() ?? '',
          member.noTrees?.toString() ?? '',
          member.isActive ? 'Active' : 'Inactive',
          _formatDate(member.registrationDate),
        ]);
      }
      
      String csvContent = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csvContent);
      
      return file;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // Excel import/export methods (placeholder implementations)
  Future<List<Member>> importMembersFromExcel() async {
    // For now, redirect to CSV import
    return await importMembersFromCsv();
  }
  
  Future<File?> exportMembersToExcel() async {
    // For now, redirect to CSV export
    return await exportMembersToCsv();
  }
  
  Future<File?> downloadMemberCsvTemplate() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/member_template.csv');
      
      const csvContent = '''Member Number,Full Name,ID Number,Phone Number,Email,Gender,Zone,Acreage,Number of Trees
MB001,John Doe,12345678,+254700000000,john@example.com,Male,North Zone,2.5,150
MB002,Jane Smith,87654321,+254700000001,jane@example.com,Female,South Zone,3.0,200''';
      
      await file.writeAsString(csvContent);
      return file;
    } catch (e) {
      throw Exception('Failed to create CSV template: $e');
    }
  }
  
  Future<File?> downloadMemberImportTemplate() async {
    // For now, use the same as CSV template
    return await downloadMemberCsvTemplate();
  }
  
  // Legacy search method for compatibility
  List<Member> searchMembersLegacy(String query) {
    final normalizedQuery = query.toLowerCase();
    return members.where((member) =>
      member.fullName.toLowerCase().contains(normalizedQuery) ||
      member.memberNumber.toLowerCase().contains(normalizedQuery) ||
      (member.idNumber != null && member.idNumber!.toLowerCase().contains(normalizedQuery))
    ).toList();
  }
  
  // Legacy methods for backward compatibility
  List<Member> get members {
    // Ensure members list is initialized
    if (_membersList == null) {
      _updateMembersList();
    }
    return _membersList ?? [];
  }
  
  // Add a simple list to store members for compatibility
  List<Member>? _membersList;
  
  // Initialize the service and load members
  Future<void> initialize() async {
    await _updateMembersList();
  }
  
  Future<void> _updateMembersList() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> memberMaps = await db.query('members', orderBy: 'fullName ASC');
    _membersList = memberMaps.map((memberMap) => Member.fromJson(memberMap)).toList();
    print('📊 Updated members list: ${_membersList?.length ?? 0} members loaded');
  }

  // Method to force refresh all data after import
  Future<void> forceRefreshAfterImport() async {
    try {
      // Clear all caches
      _clearCache();
      _clearPageCache();
      
      // Force reload from database
      await _updateMembersList();
      await loadMembersPage(0, refresh: true);
      
      print('Force refresh completed after import - Total members: ${members.length}');
    } catch (e) {
      print('Error in force refresh after import: $e');
    }
  }
}
