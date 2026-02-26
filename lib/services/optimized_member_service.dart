import 'dart:io';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'database_helper.dart';

class OptimizedMemberService extends GetxService {
  static OptimizedMemberService get to => Get.find();

  final DatabaseHelper _dbHelper = Get.find<DatabaseHelper>();

  // Pagination constants
  static const int _pageSize = 50;
  static const int _maxCacheSize = 500;

  // Cache management
  final Map<String, Member> _memberCache = {};
  final Map<String, List<Member>> _pageCache = {};
  final RxList<Member> _currentPageMembers = <Member>[].obs;

  // Search and filtering state
  final RxString _currentSearchQuery = ''.obs;
  final RxString _currentZoneFilter = ''.obs;
  final RxBool _showActiveOnly = true.obs;

  // Pagination state
  final RxInt _currentPage = 0.obs;
  final RxInt _totalMembers = 0.obs;
  final RxBool _hasMorePages = true.obs;
  final RxBool _isLoading = false.obs;

  // Reactive getters
  List<Member> get currentPageMembers => _currentPageMembers;
  String get currentSearchQuery => _currentSearchQuery.value;
  String get currentZoneFilter => _currentZoneFilter.value;
  bool get showActiveOnly => _showActiveOnly.value;
  int get currentPage => _currentPage.value;
  int get totalMembers => _totalMembers.value;
  bool get hasMorePages => _hasMorePages.value;
  bool get isLoading => _isLoading.value;
  int get totalPages => (_totalMembers.value / _pageSize).ceil();

  Future<OptimizedMemberService> init() async {
    await _updateTotalCount();
    await loadMembersPage(0, refresh: true);
    return this;
  }

  Future<void> loadMembersPage(int page, {bool refresh = false}) async {
    if (_isLoading.value && !refresh) return;

    _isLoading.value = true;

    try {
      final cacheKey = _generateCacheKey(page);

      if (!refresh && _pageCache.containsKey(cacheKey)) {
        _currentPageMembers.value = _pageCache[cacheKey]!;
        _currentPage.value = page;
        return;
      }

      final db = await _dbHelper.database;
      final offset = page * _pageSize;

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

      final List<Map<String, dynamic>> memberMaps = await db.rawQuery(
        query,
        whereArgs,
      );
      final members = memberMaps.map((map) => Member.fromJson(map)).toList();

      if (_pageCache.length >= _maxCacheSize ~/ _pageSize) {
        _pageCache.clear();
      }
      _pageCache[cacheKey] = members;

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

  Future<void> goToPage(int page) async {
    if (page >= 0 && page < totalPages && !_isLoading.value) {
      await loadMembersPage(page);
    }
  }

  Future<void> refreshCurrentPage() async {
    await loadMembersPage(_currentPage.value, refresh: true);
    await _updateTotalCount();
  }

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

  Future<Member?> getMemberById(String id) async {
    if (_memberCache.containsKey(id)) {
      return _memberCache[id];
    }

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
    final validation = await validateMemberData(
      memberNumber: memberNumber,
      idNumber: idNumber,
    );

    if (!(validation['isValid'] as bool)) {
      final errors = validation['errors'] as List<String>;
      throw Exception(errors.join(', '));
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
      throw Exception(errors.join(', '));
    }

    final updatedMember = member.copyWith(updatedAt: DateTime.now());

    final db = await _dbHelper.database;
    await db.update(
      'members',
      updatedMember.toJson(),
      where: 'id = ?',
      whereArgs: [member.id],
    );

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
          seasonText =
              ' across ${seasons.length} seasons: ${seasons.join(', ')}';
        }
      }

      throw Exception(
        '''Cannot delete member "$memberName":
      
Member has $collectionCount coffee collection${collectionCount > 1 ? 's' : ''}$seasonText.

To delete this member:
1. First remove all their collections from the collection history
2. Or contact the system administrator
3. Alternatively, you can deactivate the member instead of deleting

Note: Deleting a member with collections could affect financial records and reports.''',
      );
    }

    final db = await _dbHelper.database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);

    _memberCache.remove(id);
    _clearPageCache();
    await refreshCurrentPage();
  }

  Future<Map<String, dynamic>> _getMemberCollectionInfo(String memberId) async {
    try {
      final db = await _dbHelper.database;

      // Get collection count and seasons
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as count,
          GROUP_CONCAT(DISTINCT seasonId) as seasons
        FROM coffee_collections 
        WHERE memberId = ?
      ''',
        [memberId],
      );

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
              whereArgs: [seasonId.trim()],
            );
            if (seasonResult.isNotEmpty) {
              seasons.add(seasonResult.first['name'] as String);
            }
          } catch (e) {
            print('Error getting season name for ID $seasonId: $e');
          }
        }
      }

      return {'hasCollections': count > 0, 'count': count, 'seasons': seasons};
    } catch (e) {
      print('Error checking member collections: $e');
      // In case of error, assume member has collections to be safe
      return {'hasCollections': true, 'count': 0, 'seasons': <String>[]};
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

    final db = await _dbHelper.database;

    // Check member number duplicates
    final memberNumberQuery =
        excludeMemberId != null
            ? 'SELECT id FROM members WHERE memberNumber = ? AND id != ?'
            : 'SELECT id FROM members WHERE memberNumber = ?';
    final memberNumberArgs =
        excludeMemberId != null
            ? [memberNumber, excludeMemberId]
            : [memberNumber];

    final memberNumberResult = await db.rawQuery(
      memberNumberQuery,
      memberNumberArgs,
    );
    if (memberNumberResult.isNotEmpty) {
      validationResult['isValid'] = false;
      (validationResult['errors'] as List<String>).add(
        'Member number $memberNumber already exists',
      );
    }

    // Check ID number duplicates if provided
    if (idNumber != null && idNumber.isNotEmpty) {
      final idNumberQuery =
          excludeMemberId != null
              ? 'SELECT id FROM members WHERE idNumber = ? AND id != ?'
              : 'SELECT id FROM members WHERE idNumber = ?';
      final idNumberArgs =
          excludeMemberId != null ? [idNumber, excludeMemberId] : [idNumber];

      final idNumberResult = await db.rawQuery(idNumberQuery, idNumberArgs);
      if (idNumberResult.isNotEmpty) {
        validationResult['isValid'] = false;
        (validationResult['errors'] as List<String>).add(
          'ID number $idNumber already exists',
        );
      }
    }

    return validationResult;
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

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM members $whereClause',
      whereArgs,
    );
    _totalMembers.value = result.first['count'] as int;
  }

  Future<File?> exportMembersToCsv() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/members_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      );

      List<List<String>> csvData = [
        [
          'Member Number',
          'Full Name',
          'ID Number',
          'Phone Number',
          'Email',
          'Gender',
          'Zone',
          'Acreage',
          'Number of Trees',
          'Status',
          'Registration Date',
        ],
      ];

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
}
