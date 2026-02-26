import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../services/optimized_member_service.dart';
import 'package:share_plus/share_plus.dart';

class OptimizedMemberController extends GetxController {
  OptimizedMemberService get _memberService => Get.find<OptimizedMemberService>();
  
  // Reactive getters from service
  List<Member> get currentPageMembers => _memberService.currentPageMembers;
  String get currentSearchQuery => _memberService.currentSearchQuery;
  String get currentZoneFilter => _memberService.currentZoneFilter;
  bool get showActiveOnly => _memberService.showActiveOnly;
  int get currentPage => _memberService.currentPage;
  int get totalMembers => _memberService.totalMembers;
  bool get hasMorePages => _memberService.hasMorePages;
  bool get isLoading => _memberService.isLoading;
  int get totalPages => _memberService.totalPages;
  
  RxString errorMessage = ''.obs;
  
  // Pagination methods
  Future<void> loadNextPage() async {
    try {
      errorMessage.value = '';
      await _memberService.loadNextPage();
    } catch (e) {
      errorMessage.value = 'Failed to load next page: $e';
    }
  }
  
  Future<void> loadPreviousPage() async {
    try {
      errorMessage.value = '';
      await _memberService.loadPreviousPage();
    } catch (e) {
      errorMessage.value = 'Failed to load previous page: $e';
    }
  }
  
  Future<void> goToPage(int page) async {
    try {
      errorMessage.value = '';
      await _memberService.goToPage(page);
    } catch (e) {
      errorMessage.value = 'Failed to go to page: $e';
    }
  }
  
  Future<void> refreshCurrentPage() async {
    try {
      errorMessage.value = '';
      await _memberService.refreshCurrentPage();
    } catch (e) {
      errorMessage.value = 'Failed to refresh: $e';
    }
  }
  
  // Search and filtering methods
  Future<void> searchMembers(String query) async {
    try {
      errorMessage.value = '';
      await _memberService.searchMembers(query);
    } catch (e) {
      errorMessage.value = 'Failed to search members: $e';
    }
  }
  
  Future<void> filterByZone(String zone) async {
    try {
      errorMessage.value = '';
      await _memberService.filterByZone(zone);
    } catch (e) {
      errorMessage.value = 'Failed to filter by zone: $e';
    }
  }
  
  Future<void> toggleActiveFilter() async {
    try {
      errorMessage.value = '';
      await _memberService.toggleActiveFilter();
    } catch (e) {
      errorMessage.value = 'Failed to toggle active filter: $e';
    }
  }
  
  Future<void> clearAllFilters() async {
    try {
      errorMessage.value = '';
      await _memberService.clearAllFilters();
    } catch (e) {
      errorMessage.value = 'Failed to clear filters: $e';
    }
  }
  
  // CRUD operations
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
    try {
      errorMessage.value = '';
      
      await _memberService.addMember(
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
      
      Get.snackbar(
        'Success',
        'Member added successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to add member: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  Future<void> updateMember(Member member) async {
    try {
      errorMessage.value = '';
      
      await _memberService.updateMember(member);
      
      Get.snackbar(
        'Success',
        'Member updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to update member: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  Future<void> activateMember(String memberId) async {
    try {
      errorMessage.value = '';
      
      await _memberService.activateMember(memberId);
      
      Get.snackbar(
        'Success',
        'Member activated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to activate member: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  Future<void> deactivateMember(String memberId) async {
    try {
      errorMessage.value = '';
      
      await _memberService.deactivateMember(memberId);
      
      Get.snackbar(
        'Success',
        'Member deactivated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to deactivate member: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  Future<void> deleteMember(String id) async {
    try {
      errorMessage.value = '';
      
      await _memberService.deleteMember(id);
      
      Get.snackbar(
        'Success',
        'Member deleted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to delete member: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  // Lookup methods
  Member? getMemberByNumber(String memberNumber) {
    return currentPageMembers.firstWhereOrNull(
      (member) => member.memberNumber == memberNumber,
    );
  }
  
  Future<Member?> getMemberById(String id) async {
    try {
      return await _memberService.getMemberById(id);
    } catch (e) {
      errorMessage.value = 'Failed to get member: $e';
      return null;
    }
  }
  
  Future<Member?> getMemberByMemberNumber(String memberNumber) async {
    try {
      return await _memberService.getMemberByMemberNumber(memberNumber);
    } catch (e) {
      errorMessage.value = 'Failed to get member by number: $e';
      return null;
    }
  }
  
  // Validation
  Future<Map<String, dynamic>> validateMemberData({
    required String memberNumber,
    String? idNumber,
    String? excludeMemberId,
  }) async {
    try {
      return await _memberService.validateMemberData(
        memberNumber: memberNumber,
        idNumber: idNumber,
        excludeMemberId: excludeMemberId,
      );
    } catch (e) {
      return {
        'isValid': false,
        'errors': ['Validation failed: $e'],
        'warnings': <String>[],
      };
    }
  }
  
  // Utility methods
  Future<List<String>> getZones() async {
    try {
      return await _memberService.getZones();
    } catch (e) {
      errorMessage.value = 'Failed to get zones: $e';
      return [];
    }
  }
  
  // Export functionality
  Future<void> exportMembersToCsv() async {
    try {
      errorMessage.value = '';
      
      final file = await _memberService.exportMembersToCsv();
      
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Farm Members Data Export'
        );
        
        Get.snackbar(
          'Success',
          'Members exported successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      
    } catch (e) {
      errorMessage.value = 'Failed to export members: $e';
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  // Performance statistics
  String get performanceStats {
    return 'Page ${currentPage + 1} of $totalPages • '
           'Showing ${currentPageMembers.length} of $totalMembers members';
  }
  
  // Compatibility methods for existing code
  @Deprecated('Use currentPageMembers instead')
  List<Member> get members => currentPageMembers;
  
  @Deprecated('Use searchMembers() instead')
  List<Member> searchMembersLegacy(String query) {
    return currentPageMembers.where((member) =>
      member.fullName.toLowerCase().contains(query.toLowerCase()) ||
      member.memberNumber.toLowerCase().contains(query.toLowerCase()) ||
      (member.idNumber != null && member.idNumber!.toLowerCase().contains(query.toLowerCase()))
    ).toList();
  }
} 