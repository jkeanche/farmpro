import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'package:share_plus/share_plus.dart';

class MemberController extends GetxController {
  MemberService get _memberService => Get.find<MemberService>();

  // Optimization: Use computed properties with caching
  final RxList<Member> _members = <Member>[].obs;

  RxList<Member> get members {
    // Avoid frequent synchronization - only sync when really needed
    return _members;
  }

  // Cache active members to avoid recomputation
  List<Member>? _cachedActiveMembers;
  DateTime? _activeMembersCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<Member> get activeMembers {
    final now = DateTime.now();
    if (_cachedActiveMembers == null ||
        _activeMembersCacheTime == null ||
        now.difference(_activeMembersCacheTime!) > _cacheValidDuration) {
      _cachedActiveMembers =
          _members.where((member) => member.isActive).toList();
      _activeMembersCacheTime = now;
    }
    return _cachedActiveMembers!;
  }

  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;

  // Performance tracking
  final RxInt _totalOperations = 0.obs;
  final RxInt _successfulOperations = 0.obs;

  int get totalOperations => _totalOperations.value;
  int get successfulOperations => _successfulOperations.value;
  double get successRate =>
      totalOperations > 0 ? successfulOperations / totalOperations : 0.0;

  String getPerformanceStats() {
    return 'Ops: $_totalOperations | Success: ${(successRate * 100).toStringAsFixed(1)}% | '
        'Active: ${activeMembers.length}/${_members.length} | Cache: ${_searchCache.length}';
  }

  // Prevent rapid successive operations that could block UI
  bool _isOperationInProgress = false;

  Future<void> addMember({
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
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      isLoading.value = true;
      errorMessage.value = '';
      _totalOperations.value++;

      final member = await _memberService.addMember(
        memberNumber: memberNumber,
        fullName: fullName,
        idNumber: idNumber,
        phoneNumber: phoneNumber,
        email: email,
        gender: gender,
        zone: zone,
        acreage: acreage,
        noTrees: noTrees,
        isActive: isActive,
      );

      // Add to local list immediately for better UX
      _members.add(member);
      _clearActiveCache();

      // **FORCE IMMEDIATE REACTIVE UPDATE**
      _members.refresh(); // This triggers all Obx widgets to rebuild
      update(); // This triggers all GetBuilder widgets to rebuild

      // Refresh in background without blocking UI
      _refreshInBackground();

      _successfulOperations.value++;
      isLoading.value = false;

      print('✅ Member added successfully - UI should update immediately');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to add member: $e';
      print(errorMessage.value);
      rethrow; // Re-throw so UI can handle the error
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<void> updateMember(Member member) async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _memberService.updateMember(member);

      // Update local list immediately
      final index = _members.indexWhere((m) => m.id == member.id);
      if (index != -1) {
        _members[index] = member;
      }
      _clearActiveCache();

      // **FORCE IMMEDIATE REACTIVE UPDATE**
      _members.refresh(); // This triggers all Obx widgets to rebuild
      update(); // This triggers all GetBuilder widgets to rebuild

      // Background refresh
      _refreshInBackground();

      isLoading.value = false;

      print('✅ Member updated successfully - UI should update immediately');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to update member: $e';
      print(errorMessage.value);
      rethrow; // Re-throw so UI can handle the error
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<void> activateMember(String memberId) async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _memberService.activateMember(memberId);

      // Update local member status immediately
      final index = _members.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        _members[index] = _members[index].copyWith(isActive: true);
      }
      _clearActiveCache();

      // **FORCE IMMEDIATE REACTIVE UPDATE**
      _members.refresh(); // This triggers all Obx widgets to rebuild
      update(); // This triggers all GetBuilder widgets to rebuild

      // Background refresh
      _refreshInBackground();

      isLoading.value = false;

      print('✅ Member activated successfully - UI should update immediately');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to activate member: $e';
      print(errorMessage.value);
      rethrow; // Re-throw so UI can handle the error
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<void> deactivateMember(String memberId) async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _memberService.deactivateMember(memberId);

      // Update local member status immediately
      final index = _members.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        _members[index] = _members[index].copyWith(isActive: false);
      }
      _clearActiveCache();

      // **FORCE IMMEDIATE REACTIVE UPDATE**
      _members.refresh(); // This triggers all Obx widgets to rebuild
      update(); // This triggers all GetBuilder widgets to rebuild

      // Background refresh
      _refreshInBackground();

      isLoading.value = false;

      print('✅ Member deactivated successfully - UI should update immediately');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to deactivate member: $e';
      print(errorMessage.value);
      rethrow; // Re-throw so UI can handle the error
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<void> deleteMember(String id) async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _memberService.deleteMember(id);

      // Remove from local list immediately
      _members.removeWhere((m) => m.id == id);
      _clearActiveCache();

      // **FORCE IMMEDIATE REACTIVE UPDATE**
      _members.refresh(); // This triggers all Obx widgets to rebuild
      update(); // This triggers all GetBuilder widgets to rebuild

      // Background refresh
      _refreshInBackground();

      isLoading.value = false;

      print('✅ Member deleted successfully - UI should update immediately');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to delete member: $e';
      print(errorMessage.value);

      // Re-throw the exception so the UI can handle it properly
      rethrow;
    } finally {
      _isOperationInProgress = false;
    }
  }

  // Non-blocking background refresh
  void _refreshInBackground() {
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        await _memberService.refreshCurrentPage();
        final serviceMembers = _memberService.members;
        if (serviceMembers.isNotEmpty) {
          _members.assignAll(serviceMembers);
          clearAllCaches();

          // **FORCE REACTIVE UPDATE IN BACKGROUND**
          _members.refresh(); // This triggers all Obx widgets to rebuild
          update(); // This triggers all GetBuilder widgets to rebuild

          print('✅ Background refresh completed - Total: ${_members.length}');
        }
      } catch (e) {
        print('Background refresh failed: $e');
      }
    });
  }

  Future<Member?> getMemberByNumber(String memberNumber) async {
    return await _memberService.getMemberByMemberNumber(memberNumber);
  }

  Future<List<Member>> getMembersByNumber(String memberNumber) async {
    return await _memberService.getMembersByMemberNumber(memberNumber);
  }

  Future<Member?> getMemberByIdNumber(String idNumber) async {
    return await _memberService.getMemberByIdNumber(idNumber);
  }

  Future<List<Member>> getMembersByIdNumber(String idNumber) async {
    return await _memberService.getMembersByIdNumber(idNumber);
  }

  Future<Map<String, dynamic>> validateMemberData({
    required String memberNumber,
    String? idNumber,
    String? excludeMemberId,
  }) async {
    return await _memberService.validateMemberData(
      memberNumber: memberNumber,
      idNumber: idNumber,
      excludeMemberId: excludeMemberId,
    );
  }

  Future<Map<String, dynamic>> findAllDuplicates() async {
    return await _memberService.findAllDuplicates();
  }

  // Optimized search with caching and debouncing
  final Map<String, List<Member>> _searchCache = {};
  final Map<String, DateTime> _searchCacheTime = {};
  static const Duration _searchCacheValidDuration = Duration(minutes: 2);

  List<Member> searchMembers(String query) {
    // Use cache for repeated searches
    final normalizedQuery = query.toLowerCase().trim();
    final now = DateTime.now();

    if (_searchCache.containsKey(normalizedQuery) &&
        _searchCacheTime[normalizedQuery] != null &&
        now.difference(_searchCacheTime[normalizedQuery]!) <
            _searchCacheValidDuration) {
      return _searchCache[normalizedQuery]!;
    }

    // Perform search and cache result - limit results for performance
    final membersList = _members.toList();
    final results =
        membersList
            .where(
              (member) =>
                  member.fullName.toLowerCase().contains(normalizedQuery) ||
                  member.memberNumber.toLowerCase().contains(normalizedQuery) ||
                  (member.idNumber != null &&
                      member.idNumber!.toLowerCase().contains(normalizedQuery)),
            )
            .take(30)
            .toList(); // Increased limit slightly but still manageable

    _searchCache[normalizedQuery] = results;
    _searchCacheTime[normalizedQuery] = now;

    // Cleanup old cache entries
    _cleanupSearchCache();

    return results;
  }

  /// Fast database level search for large datasets (limits to 20 results by default)
  Future<List<Member>> quickSearchMembers(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      return await _memberService.quickSearchMembers(query, limit: limit);
    } catch (e) {
      print('Quick search error: $e');
      // Fallback to in-memory search with smaller limit
      return searchMembers(query).take(limit).toList();
    }
  }

  void _cleanupSearchCache() {
    if (_searchCache.length > 10) {
      // Reduced cache size for better memory management
      final oldestKey =
          _searchCacheTime.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
      _searchCache.remove(oldestKey);
      _searchCacheTime.remove(oldestKey);
    }
  }

  Future<List<Member>> importMembersFromExcel() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final importedMembers = await _memberService.importMembersFromExcel();

      // Clear all caches and trigger UI refresh
      clearAllCaches();
      await _forceRefreshMembers(); // Use force refresh for imports

      isLoading.value = false;
      print(
        '✅ ${importedMembers.length} members imported from Excel - UI should update immediately',
      );
      return importedMembers;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to import members: $e';
      print(errorMessage.value);
      return [];
    }
  }

  Future<List<Member>> importMembersFromCsv() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final importedMembers = await _memberService.importMembersFromCsv();

      // Clear all caches and trigger UI refresh
      clearAllCaches();
      await _forceRefreshMembers(); // Use force refresh for imports

      isLoading.value = false;
      print(
        '✅ ${importedMembers.length} members imported from CSV - UI should update immediately',
      );
      return importedMembers;
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'Failed to import members: $e';
      print(errorMessage.value);
      return [];
    }
  }

  Future<void> exportMembersToExcel() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final file = await _memberService.exportMembersToExcel();

      if (file != null) {
        // Share the file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Farm Fresh Members Data');

        isLoading.value = false;
        Get.snackbar(
          'Success',
          'Members exported to Excel',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        isLoading.value = false;
        errorMessage.value = 'Failed to export members to Excel';
        Get.snackbar(
          'Error',
          'Failed to export members to Excel',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to export members to Excel: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> exportMembersToCsv() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final file = await _memberService.exportMembersToCsv();

      if (file != null) {
        // Share the file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Farm Fresh Members Data (CSV)');

        isLoading.value = false;
        Get.snackbar(
          'Success',
          'Members exported to CSV and ready to share',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        isLoading.value = false;
        errorMessage.value = 'Failed to export members to CSV';
        Get.snackbar(
          'Error',
          'Failed to export members to CSV',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to export members to CSV: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> downloadCsvTemplate() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final file = await _memberService.downloadMemberCsvTemplate();

      if (file != null) {
        // Share the file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Member Import Template (CSV Format)');

        isLoading.value = false;
        Get.snackbar(
          'Success',
          'CSV template downloaded and ready to share',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        isLoading.value = false;
        errorMessage.value = 'Failed to create CSV template';
        Get.snackbar(
          'Error',
          'Failed to create CSV template',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to create CSV template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> downloadImportTemplate() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final file = await _memberService.downloadMemberImportTemplate();

      if (file != null) {
        // Share the template file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Farm Fresh Member Import Template');

        isLoading.value = false;
        Get.snackbar(
          'Success',
          'Import template downloaded',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        isLoading.value = false;
        errorMessage.value = 'Failed to create import template';
        Get.snackbar(
          'Error',
          'Failed to create import template',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to download template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Cache management methods
  void _clearActiveCache() {
    _cachedActiveMembers = null;
    _activeMembersCacheTime = null;
  }

  void clearAllCaches() {
    _clearActiveCache();
    _searchCache.clear();
    _searchCacheTime.clear();
  }

  // Safe method to refresh members without blocking UI
  Future<void> safeRefreshMembers() async {
    try {
      // Use background refresh to avoid blocking
      await _memberService.refreshCurrentPage();
      final serviceMembers = _memberService.members;

      if (serviceMembers.isNotEmpty) {
        _members.assignAll(serviceMembers);
        clearAllCaches();
        update();
        print('Safe refresh completed - Total: ${_members.length}');
      }
    } catch (e) {
      print('Safe refresh error: $e');
      // Don't throw error, just log it
    }
  }

  // Method to force refresh members from database (use sparingly)
  Future<void> refreshMembers() async {
    if (_isOperationInProgress) {
      print('Operation in progress, skipping refresh');
      return;
    }

    try {
      _isOperationInProgress = true;

      // Simple refresh without heavy operations
      await _memberService.refreshCurrentPage();
      final serviceMembers = _memberService.members;

      if (serviceMembers.isNotEmpty) {
        _members.assignAll(serviceMembers);
        clearAllCaches();

        // **FORCE IMMEDIATE REACTIVE UPDATE**
        _members.refresh(); // This triggers all Obx widgets to rebuild
        update(); // This triggers all GetBuilder widgets to rebuild

        print(
          '✅ Members refreshed - Total: ${_members.length} - UI should update immediately',
        );
      }
    } catch (e) {
      print('Error refreshing members: $e');
    } finally {
      _isOperationInProgress = false;
    }
  }

  // Force refresh for critical operations like imports
  Future<void> _forceRefreshMembers() async {
    try {
      // Always refresh from database for critical operations
      await _memberService.refreshCurrentPage();
      final serviceMembers = _memberService.members;

      if (serviceMembers.isNotEmpty) {
        _members.assignAll(serviceMembers);
        clearAllCaches();

        // **MULTIPLE REACTIVE UPDATE TRIGGERS**
        _members.refresh(); // Force RxList to notify all listeners
        update(); // Force GetxController to notify all GetBuilder widgets

        // Additional notification for any missed observers
        ever(_members, (_) {}); // Trigger a one-time listener

        print(
          '✅ Force refresh completed - Total: ${_members.length} - All UI should update',
        );
      }
    } catch (e) {
      print('Error in force refresh: $e');
      // Don't throw error, just log it
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize member data in background
    _initializeMembers();
  }

  Future<void> _initializeMembers() async {
    try {
      print('🔄 Initializing member controller...');

      // Load initial data without blocking UI
      Future.delayed(const Duration(milliseconds: 100), () async {
        try {
          await _memberService.initialize();
          final serviceMembers = _memberService.members;
          if (serviceMembers.isNotEmpty) {
            _members.assignAll(serviceMembers);
            clearAllCaches();

            // **FORCE REACTIVE UPDATE AFTER INITIALIZATION**
            _members.refresh(); // This triggers all Obx widgets to rebuild
            update(); // This triggers all GetBuilder widgets to rebuild

            print(
              '✅ Member controller initialized - ${_members.length} members loaded',
            );
          } else {
            print('⚠️ No members found during initialization');
          }
        } catch (e) {
          print('❌ Error initializing members: $e');
        }
      });
    } catch (e) {
      print('❌ Error in member initialization: $e');
    }
  }

  /// Public method to force complete refresh of member data
  /// Use this when you need to ensure all screens are synchronized
  Future<void> forceCompleteRefresh() async {
    try {
      print('🔄 Force complete refresh requested...');
      isLoading.value = true;

      await _memberService.initialize(); // Re-initialize from database
      final serviceMembers = _memberService.members;

      _members.clear(); // Clear current list
      _members.assignAll(serviceMembers); // Load fresh data
      clearAllCaches(); // Clear all caches

      // **MAXIMUM REACTIVE UPDATE FORCE**
      _members.refresh(); // Force RxList update
      update(); // Force GetxController update

      isLoading.value = false;
      print(
        '✅ Force complete refresh completed - ${_members.length} members loaded',
      );
    } catch (e) {
      isLoading.value = false;
      print('❌ Error in force complete refresh: $e');
    }
  }

  @override
  void onClose() {
    clearAllCaches();
    super.onClose();
  }
}
