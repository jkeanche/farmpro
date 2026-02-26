import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/services.dart';

class SeasonController extends GetxController {
  final SeasonService _seasonService = Get.find<SeasonService>();

  // Observable lists
  List<Season> get seasons => _seasonService.seasons;
  // Inventory active period
  Season? get activeInventorySeason => _seasonService.activeSeason;
  // Coffee active season
  Season? get activeCoffeeSeason => _seasonService.activeCoffeeSeason;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  final RxBool isUpdating = false.obs;
  final RxBool isClosing = false.obs;

  // Form states
  final RxString selectedSeasonId = ''.obs;
  final RxString seasonName = ''.obs;
  final RxString seasonDescription = ''.obs;
  final Rx<DateTime> startDate = DateTime.now().obs;
  final Rx<DateTime?> endDate = Rx<DateTime?>(null);

  final RxString error = ''.obs;

  // Form controllers
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  // Legacy compatibility properties
  // Keep activeSeason for backward-compat (inventory)
  Season? get activeSeason => activeInventorySeason;
  String get currentSeasonDisplay => _seasonService.currentSeasonDisplay;

  @override
  void onInit() {
    super.onInit();
    loadSeasons();
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  Future<void> loadSeasons() async {
    try {
      isLoading.value = true;
      await _seasonService.loadSeasons();
    } catch (e) {
      error.value = 'Failed to load seasons: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createSeason({
    required String name,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    String type = 'inventory',
  }) async {
    try {
      isCreating.value = true;

      // Validate inputs
      if (name.trim().isEmpty) {
        error.value = 'Season name is required';
        return;
      }

      if (endDate != null && endDate.isBefore(startDate)) {
        error.value = 'End date cannot be before start date';
        return;
      }

      // Get current user info
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      final success = await _seasonService.createSeason(
        name: name.trim(),
        description: description?.trim(),
        startDate: startDate,
        endDate: endDate,
        userId: currentUser?.id,
        userName: currentUser?.fullName,
        type: type,
      );

      if (success) {
        Get.snackbar(
          'Success',
          AppConstants.addSuccessMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        resetForm();
      } else {
        error.value = 'Failed to create season';
      }
    } catch (e) {
      error.value = 'Error creating season: $e';
    } finally {
      isCreating.value = false;
    }
  }

  Future<void> updateSeason(Season season) async {
    try {
      isUpdating.value = true;

      final success = await _seasonService.updateSeason(season);

      if (success) {
        Get.snackbar(
          'Success',
          AppConstants.updateSuccessMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        error.value = 'Failed to update season';
      }
    } catch (e) {
      error.value = 'Error updating season: $e';
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> closeSeason(String seasonId) async {
    try {
      isClosing.value = true;

      // Get current user info
      final authService = Get.find<AuthService>();
      final currentUser = authService.currentUser.value;

      final success = await _seasonService.closeSeason(
        seasonId,
        userId: currentUser?.id,
        userName: currentUser?.fullName,
      );

      if (success) {
        Get.snackbar(
          'Success',
          AppConstants.seasonClosedSuccessMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        error.value = 'Failed to close season';
      }
    } catch (e) {
      error.value = 'Error closing season: $e';
    } finally {
      isClosing.value = false;
    }
  }

  Future<void> activateSeason(String seasonId) async {
    try {
      isUpdating.value = true;

      final season = seasons.firstWhereOrNull((s) => s.id == seasonId);
      if (season == null) {
        error.value = 'Season not found';
        return;
      }

      final updatedSeason = season.copyWith(isActive: true);
      await updateSeason(updatedSeason);
    } catch (e) {
      error.value = 'Error activating season: $e';
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> deactivateSeason(String seasonId) async {
    try {
      isUpdating.value = true;

      final season = seasons.firstWhereOrNull((s) => s.id == seasonId);
      if (season == null) {
        error.value = 'Season not found';
        return;
      }

      final updatedSeason = season.copyWith(isActive: false);
      await updateSeason(updatedSeason);
    } catch (e) {
      error.value = 'Error deactivating season: $e';
    } finally {
      isUpdating.value = false;
    }
  }

  Future<List<MemberSeasonSummary>> getMemberSeasonSummaries(
    String seasonId,
  ) async {
    try {
      return await _seasonService.getMemberSeasonSummaries(seasonId);
    } catch (e) {
      error.value = 'Error loading member summaries: $e';
      return [];
    }
  }

  Future<Map<String, dynamic>> getSeasonStatistics(String seasonId) async {
    try {
      return await _seasonService.getSeasonStatistics(seasonId);
    } catch (e) {
      error.value = 'Error loading season statistics: $e';
      return {'sales': {}, 'topProducts': []};
    }
  }

  Future<double> getMemberSeasonTotal(String memberId, String seasonId) async {
    try {
      return await _seasonService.getMemberSeasonTotal(memberId, seasonId);
    } catch (e) {
      error.value = 'Error loading member season total: $e';
      return 0.0;
    }
  }

  Future<void> updateSeasonTotals(String seasonId) async {
    try {
      await _seasonService.updateSeasonTotals(seasonId);
    } catch (e) {
      error.value = 'Error updating season totals: $e';
    }
  }

  // Form management
  void resetForm() {
    seasonName.value = '';
    seasonDescription.value = '';
    startDate.value = DateTime.now();
    endDate.value = null;
    selectedSeasonId.value = '';
  }

  void setFormData(Season season) {
    seasonName.value = season.name;
    seasonDescription.value = season.description ?? '';
    startDate.value = season.startDate;
    endDate.value = season.endDate;
    selectedSeasonId.value = season.id;
  }

  // Validation
  bool get canCreateSale => _seasonService.canCreateSale();
  String? get saleBlockReason => _seasonService.getSaleBlockReason();

  // Computed properties
  List<Season> get activeSeasons => seasons.where((s) => s.isActive).toList();
  List<Season> get closedSeasons => seasons.where((s) => !s.isActive).toList();

  bool get hasActiveSeason => activeCoffeeSeason != null;

  String get activeSeasonName => activeCoffeeSeason?.name ?? 'No Active Season';

  String get activeSeasonStatus =>
      activeCoffeeSeason?.statusText ?? 'No Season';

  // Season validation helpers
  bool isSeasonActive(String seasonId) {
    return seasons.any((s) => s.id == seasonId && s.isActive);
  }

  Season? getSeasonById(String seasonId) {
    return seasons.firstWhereOrNull((s) => s.id == seasonId);
  }

  bool canCloseSeason(String seasonId) {
    final season = getSeasonById(seasonId);
    return season != null && season.isActive;
  }

  bool canActivateSeason(String seasonId) {
    final season = getSeasonById(seasonId);
    return season != null && !season.isActive;
  }

  // Generate season name suggestions
  List<String> generateSeasonNameSuggestions() {
    final currentYear = DateTime.now().year;
    return [
      'Season $currentYear',
      'Season $currentYear/${currentYear + 1}',
      'Quarter ${_getCurrentQuarter()} $currentYear',
      'Spring $currentYear',
      'Summer $currentYear',
      'Fall $currentYear',
      'Winter $currentYear',
    ];
  }

  String _getCurrentQuarter() {
    final month = DateTime.now().month;
    if (month <= 3) return '1';
    if (month <= 6) return '2';
    if (month <= 9) return '3';
    return '4';
  }

  // Refresh data
  Future<void> refreshData() async {
    await loadSeasons();
  }

  // Legacy methods for coffee collection compatibility
  Future<void> refreshSeasons() async {
    await refreshData();
  }

  bool canStartCollection() {
    return _seasonService.canStartCollection();
  }
}
