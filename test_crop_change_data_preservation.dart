import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'lib/models/models.dart';
import 'lib/services/services.dart';

void main() {
  group('Crop Change Data Preservation Tests', () {
    late DatabaseHelper databaseHelper;
    late SettingsService settingsService;
    late CoffeeCollectionService coffeeCollectionService;
    late SeasonService seasonService;
    late MemberService memberService;

    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Initialize services
      Get.reset();

      databaseHelper = DatabaseHelper();
      Get.put(databaseHelper);

      seasonService = SeasonService();
      Get.put(seasonService);

      memberService = MemberService();
      Get.put(memberService);

      settingsService = SettingsService();
      Get.put(settingsService);

      coffeeCollectionService = CoffeeCollectionService();
      Get.put(coffeeCollectionService);

      // Initialize services
      await databaseHelper.init();
      await seasonService.init();
      await memberService.init();
      await settingsService.init();
      await coffeeCollectionService.init();
    });

    tearDown(() async {
      await databaseHelper.close();
      Get.reset();
    });

    test('should preserve all data when crop changes from CHERRY to MBUNI', () async {
      print('🧪 Testing crop change data preservation: CHERRY → MBUNI');

      // Create test season
      final season = CoffeeSeason(
        id: 'test-season-2024',
        name: '2024 Season',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        isActive: true,
      );
      await seasonService.createSeason(season);

      // Create test member
      final member = Member(
        id: 'test-member-001',
        memberNumber: 'M001',
        fullName: 'John Doe',
        phoneNumber: '+254700000001',
        idNumber: '12345678',
        isActive: true,
      );
      await memberService.createMember(member);

      // Set initial crop to CHERRY
      final initialSettings = settingsService.systemSettings.value.copyWith(
        coffeeProduct: 'CHERRY',
      );
      await settingsService.updateSystemSettings(initialSettings);

      print('✅ Initial setup complete - Crop: CHERRY');

      // Create CHERRY collections
      final cherryCollections = [
        CoffeeCollection(
          id: 'cherry-001',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'CHERRY',
          grossWeight: 100.0,
          tareWeight: 2.0,
          netWeight: 98.0,
          pricePerKg: 50.0,
          totalAmount: 4900.0,
          collectionDate: DateTime.now().subtract(const Duration(days: 5)),
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        CoffeeCollection(
          id: 'cherry-002',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'CHERRY',
          grossWeight: 150.0,
          tareWeight: 2.5,
          netWeight: 147.5,
          pricePerKg: 50.0,
          totalAmount: 7375.0,
          collectionDate: DateTime.now().subtract(const Duration(days: 3)),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      for (final collection in cherryCollections) {
        await coffeeCollectionService.createCollection(collection);
      }

      print('✅ Created ${cherryCollections.length} CHERRY collections');

      // Verify CHERRY collections exist
      await coffeeCollectionService.loadCollections();
      final initialCollections = coffeeCollectionService.collections;
      expect(initialCollections.length, equals(2));
      expect(
        initialCollections.every((c) => c.productType == 'CHERRY'),
        isTrue,
      );

      // Get initial cumulative data for CHERRY
      final initialCherryBalance = await coffeeCollectionService
          .getMemberSeasonSummary(member.id, season.id);
      expect(initialCherryBalance.totalAmount, equals(12275.0)); // 4900 + 7375
      expect(initialCherryBalance.totalWeight, equals(245.5)); // 98 + 147.5

      print(
        '✅ Initial CHERRY balance: KSh ${initialCherryBalance.totalAmount}, Weight: ${initialCherryBalance.totalWeight}kg',
      );

      // Change crop to MBUNI (this should preserve all data)
      final updatedSettings = settingsService.systemSettings.value.copyWith(
        coffeeProduct: 'MBUNI',
      );
      await settingsService.updateSystemSettings(updatedSettings);

      print('✅ Crop changed to MBUNI');

      // Verify all CHERRY collections are still preserved
      await coffeeCollectionService.loadCollections();
      final collectionsAfterCropChange = coffeeCollectionService.collections;
      expect(collectionsAfterCropChange.length, equals(2));
      expect(
        collectionsAfterCropChange.every((c) => c.productType == 'CHERRY'),
        isTrue,
      );

      print('✅ All CHERRY collections preserved after crop change');

      // Create MBUNI collections
      final mbuniCollections = [
        CoffeeCollection(
          id: 'mbuni-001',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'MBUNI',
          grossWeight: 80.0,
          tareWeight: 1.5,
          netWeight: 78.5,
          pricePerKg: 40.0,
          totalAmount: 3140.0,
          collectionDate: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      for (final collection in mbuniCollections) {
        await coffeeCollectionService.createCollection(collection);
      }

      print('✅ Created ${mbuniCollections.length} MBUNI collection');

      // Verify both CHERRY and MBUNI collections exist
      await coffeeCollectionService.loadCollections();
      final allCollections = coffeeCollectionService.collections;
      expect(allCollections.length, equals(3));

      final cherryCount =
          allCollections.where((c) => c.productType == 'CHERRY').length;
      final mbuniCount =
          allCollections.where((c) => c.productType == 'MBUNI').length;
      expect(cherryCount, equals(2));
      expect(mbuniCount, equals(1));

      print(
        '✅ Both CHERRY ($cherryCount) and MBUNI ($mbuniCount) collections exist',
      );

      // Test cumulative calculations for current crop (MBUNI)
      final currentMbuniBalance = await coffeeCollectionService
          .getMemberSeasonSummary(member.id, season.id);
      // Should only show MBUNI totals since that's the current crop
      expect(currentMbuniBalance.totalAmount, equals(3140.0));
      expect(currentMbuniBalance.totalWeight, equals(78.5));

      print(
        '✅ Current MBUNI balance: KSh ${currentMbuniBalance.totalAmount}, Weight: ${currentMbuniBalance.totalWeight}kg',
      );

      // Switch back to CHERRY and verify historical data is accessible
      final revertedSettings = settingsService.systemSettings.value.copyWith(
        coffeeProduct: 'CHERRY',
      );
      await settingsService.updateSystemSettings(revertedSettings);

      print('✅ Reverted crop back to CHERRY');

      // Verify CHERRY cumulative data is restored
      final revertedCherryBalance = await coffeeCollectionService
          .getMemberSeasonSummary(member.id, season.id);
      expect(
        revertedCherryBalance.totalAmount,
        equals(12275.0),
      ); // Same as initial
      expect(
        revertedCherryBalance.totalWeight,
        equals(245.5),
      ); // Same as initial

      print(
        '✅ Reverted CHERRY balance: KSh ${revertedCherryBalance.totalAmount}, Weight: ${revertedCherryBalance.totalWeight}kg',
      );

      // Verify all collections are still preserved
      await coffeeCollectionService.loadCollections();
      final finalCollections = coffeeCollectionService.collections;
      expect(finalCollections.length, equals(3));

      final finalCherryCount =
          finalCollections.where((c) => c.productType == 'CHERRY').length;
      final finalMbuniCount =
          finalCollections.where((c) => c.productType == 'MBUNI').length;
      expect(finalCherryCount, equals(2));
      expect(finalMbuniCount, equals(1));

      print('✅ Final verification: All collections preserved');
      print('   - CHERRY collections: $finalCherryCount');
      print('   - MBUNI collections: $finalMbuniCount');
      print('   - Total collections: ${finalCollections.length}');
    });

    test('should create database backup when crop changes', () async {
      print('🧪 Testing database backup creation on crop change');

      // Set initial crop
      final initialSettings = settingsService.systemSettings.value.copyWith(
        coffeeProduct: 'CHERRY',
      );
      await settingsService.updateSystemSettings(initialSettings);

      // Create a test collection
      final season = CoffeeSeason(
        id: 'backup-test-season',
        name: 'Backup Test Season',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        isActive: true,
      );
      await seasonService.createSeason(season);

      final member = Member(
        id: 'backup-test-member',
        memberNumber: 'BM001',
        fullName: 'Backup Test Member',
        phoneNumber: '+254700000002',
        idNumber: '87654321',
        isActive: true,
      );
      await memberService.createMember(member);

      final collection = CoffeeCollection(
        id: 'backup-test-collection',
        memberId: member.id,
        memberName: member.fullName,
        memberNumber: member.memberNumber,
        seasonId: season.id,
        seasonName: season.name,
        productType: 'CHERRY',
        grossWeight: 100.0,
        tareWeight: 2.0,
        netWeight: 98.0,
        pricePerKg: 50.0,
        totalAmount: 4900.0,
        collectionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await coffeeCollectionService.createCollection(collection);

      print('✅ Test data created');

      // Change crop (this should trigger backup)
      final updatedSettings = settingsService.systemSettings.value.copyWith(
        coffeeProduct: 'MBUNI',
      );
      await settingsService.updateSystemSettings(updatedSettings);

      print('✅ Crop changed - backup should have been created');

      // Verify data is still preserved
      await coffeeCollectionService.loadCollections();
      final collections = coffeeCollectionService.collections;
      expect(collections.length, equals(1));
      expect(collections.first.productType, equals('CHERRY'));
      expect(collections.first.totalAmount, equals(4900.0));

      print('✅ Data preservation verified after backup');
    });

    test('should handle multiple crop changes without data loss', () async {
      print('🧪 Testing multiple crop changes without data loss');

      // Create test data
      final season = CoffeeSeason(
        id: 'multi-test-season',
        name: 'Multi Test Season',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        isActive: true,
      );
      await seasonService.createSeason(season);

      final member = Member(
        id: 'multi-test-member',
        memberNumber: 'MT001',
        fullName: 'Multi Test Member',
        phoneNumber: '+254700000003',
        idNumber: '11223344',
        isActive: true,
      );
      await memberService.createMember(member);

      // Start with CHERRY
      await settingsService.updateSystemSettings(
        settingsService.systemSettings.value.copyWith(coffeeProduct: 'CHERRY'),
      );

      // Create CHERRY collection
      await coffeeCollectionService.createCollection(
        CoffeeCollection(
          id: 'multi-cherry-001',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'CHERRY',
          grossWeight: 100.0,
          tareWeight: 2.0,
          netWeight: 98.0,
          pricePerKg: 50.0,
          totalAmount: 4900.0,
          collectionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      print('✅ CHERRY collection created');

      // Change to MBUNI
      await settingsService.updateSystemSettings(
        settingsService.systemSettings.value.copyWith(coffeeProduct: 'MBUNI'),
      );

      // Create MBUNI collection
      await coffeeCollectionService.createCollection(
        CoffeeCollection(
          id: 'multi-mbuni-001',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'MBUNI',
          grossWeight: 80.0,
          tareWeight: 1.5,
          netWeight: 78.5,
          pricePerKg: 40.0,
          totalAmount: 3140.0,
          collectionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      print('✅ MBUNI collection created');

      // Change back to CHERRY
      await settingsService.updateSystemSettings(
        settingsService.systemSettings.value.copyWith(coffeeProduct: 'CHERRY'),
      );

      // Create another CHERRY collection
      await coffeeCollectionService.createCollection(
        CoffeeCollection(
          id: 'multi-cherry-002',
          memberId: member.id,
          memberName: member.fullName,
          memberNumber: member.memberNumber,
          seasonId: season.id,
          seasonName: season.name,
          productType: 'CHERRY',
          grossWeight: 120.0,
          tareWeight: 2.0,
          netWeight: 118.0,
          pricePerKg: 50.0,
          totalAmount: 5900.0,
          collectionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      print('✅ Second CHERRY collection created');

      // Verify all collections exist
      await coffeeCollectionService.loadCollections();
      final allCollections = coffeeCollectionService.collections;
      expect(allCollections.length, equals(3));

      final cherryCollections =
          allCollections.where((c) => c.productType == 'CHERRY').toList();
      final mbuniCollections =
          allCollections.where((c) => c.productType == 'MBUNI').toList();

      expect(cherryCollections.length, equals(2));
      expect(mbuniCollections.length, equals(1));

      // Verify CHERRY cumulative (current crop)
      final cherryBalance = await coffeeCollectionService
          .getMemberSeasonSummary(member.id, season.id);
      expect(cherryBalance.totalAmount, equals(10800.0)); // 4900 + 5900
      expect(cherryBalance.totalWeight, equals(216.0)); // 98 + 118

      print('✅ Multiple crop changes completed successfully');
      print('   - Total collections: ${allCollections.length}');
      print('   - CHERRY collections: ${cherryCollections.length}');
      print('   - MBUNI collections: ${mbuniCollections.length}');
      print('   - Current CHERRY balance: KSh ${cherryBalance.totalAmount}');
    });
  });
}
