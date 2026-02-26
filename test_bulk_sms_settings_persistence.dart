import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'lib/models/models.dart';
import 'lib/services/services.dart';

/// Test script to verify bulk SMS settings persistence
/// Ensures settings are saved and loaded correctly across app restarts
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Testing Bulk SMS Settings Persistence');
  print('=' * 60);

  try {
    // Initialize services
    await Get.putAsync(() => DatabaseHelper().init());
    await Get.putAsync(() => SettingsService().init());

    final settingsService = Get.find<SettingsService>();

    // Test 1: Verify default bulk SMS settings
    print('\n📋 Test 1: Default Bulk SMS Settings');
    print('-' * 50);

    final defaultSettings = settingsService.systemSettings.value;

    print('Default Bulk SMS Settings:');
    print('   - Enable Bulk SMS: ${defaultSettings.enableBulkSms}');
    print('   - Default Message: ${defaultSettings.bulkSmsDefaultMessage}');
    print('   - Include Balance: ${defaultSettings.bulkSmsIncludeBalance}');
    print('   - Include Name: ${defaultSettings.bulkSmsIncludeName}');
    print('   - Max Recipients: ${defaultSettings.bulkSmsMaxRecipients}');
    print('   - Batch Delay: ${defaultSettings.bulkSmsBatchDelay} seconds');
    print(
      '   - Confirm Before Send: ${defaultSettings.bulkSmsConfirmBeforeSend}',
    );
    print('   - Filter Type: ${defaultSettings.bulkSmsFilterType}');
    print('   - Log Activity: ${defaultSettings.bulkSmsLogActivity}');

    // Verify defaults are correct
    assert(
      defaultSettings.enableBulkSms == true,
      'enableBulkSms should default to true',
    );
    assert(
      defaultSettings.bulkSmsIncludeBalance == true,
      'bulkSmsIncludeBalance should default to true',
    );
    assert(
      defaultSettings.bulkSmsIncludeName == true,
      'bulkSmsIncludeName should default to true',
    );
    assert(
      defaultSettings.bulkSmsMaxRecipients == 50,
      'bulkSmsMaxRecipients should default to 50',
    );
    assert(
      defaultSettings.bulkSmsBatchDelay == 2,
      'bulkSmsBatchDelay should default to 2',
    );
    assert(
      defaultSettings.bulkSmsConfirmBeforeSend == true,
      'bulkSmsConfirmBeforeSend should default to true',
    );
    assert(
      defaultSettings.bulkSmsFilterType == 'all',
      'bulkSmsFilterType should default to "all"',
    );
    assert(
      defaultSettings.bulkSmsLogActivity == true,
      'bulkSmsLogActivity should default to true',
    );

    print('✅ All default settings are correct');

    // Test 2: Update bulk SMS settings
    print('\n📋 Test 2: Update Bulk SMS Settings');
    print('-' * 50);

    final customMessage =
        'Hello {name}, your balance is KSh {balance}. Visit us soon!';
    final updatedSettings = defaultSettings.copyWith(
      enableBulkSms: false,
      bulkSmsDefaultMessage: customMessage,
      bulkSmsIncludeBalance: false,
      bulkSmsIncludeName: true,
      bulkSmsMaxRecipients: 25,
      bulkSmsBatchDelay: 5,
      bulkSmsConfirmBeforeSend: false,
      bulkSmsFilterType: 'credit',
      bulkSmsLogActivity: false,
    );

    await settingsService.updateSystemSettings(updatedSettings);

    print('Updated Bulk SMS Settings:');
    print('   - Enable Bulk SMS: ${updatedSettings.enableBulkSms}');
    print('   - Default Message: ${updatedSettings.bulkSmsDefaultMessage}');
    print('   - Include Balance: ${updatedSettings.bulkSmsIncludeBalance}');
    print('   - Include Name: ${updatedSettings.bulkSmsIncludeName}');
    print('   - Max Recipients: ${updatedSettings.bulkSmsMaxRecipients}');
    print('   - Batch Delay: ${updatedSettings.bulkSmsBatchDelay} seconds');
    print(
      '   - Confirm Before Send: ${updatedSettings.bulkSmsConfirmBeforeSend}',
    );
    print('   - Filter Type: ${updatedSettings.bulkSmsFilterType}');
    print('   - Log Activity: ${updatedSettings.bulkSmsLogActivity}');

    print('✅ Settings updated successfully');

    // Test 3: Verify settings are persisted in database
    print('\n📋 Test 3: Database Persistence Verification');
    print('-' * 50);

    // Simulate app restart by creating a new settings service instance
    final newSettingsService = SettingsService();
    await newSettingsService.init();

    final loadedSettings = newSettingsService.systemSettings.value;

    print('Loaded Bulk SMS Settings after restart:');
    print('   - Enable Bulk SMS: ${loadedSettings.enableBulkSms}');
    print('   - Default Message: ${loadedSettings.bulkSmsDefaultMessage}');
    print('   - Include Balance: ${loadedSettings.bulkSmsIncludeBalance}');
    print('   - Include Name: ${loadedSettings.bulkSmsIncludeName}');
    print('   - Max Recipients: ${loadedSettings.bulkSmsMaxRecipients}');
    print('   - Batch Delay: ${loadedSettings.bulkSmsBatchDelay} seconds');
    print(
      '   - Confirm Before Send: ${loadedSettings.bulkSmsConfirmBeforeSend}',
    );
    print('   - Filter Type: ${loadedSettings.bulkSmsFilterType}');
    print('   - Log Activity: ${loadedSettings.bulkSmsLogActivity}');

    // Verify persistence
    assert(
      loadedSettings.enableBulkSms == false,
      'enableBulkSms should be persisted as false',
    );
    assert(
      loadedSettings.bulkSmsDefaultMessage == customMessage,
      'bulkSmsDefaultMessage should be persisted',
    );
    assert(
      loadedSettings.bulkSmsIncludeBalance == false,
      'bulkSmsIncludeBalance should be persisted as false',
    );
    assert(
      loadedSettings.bulkSmsIncludeName == true,
      'bulkSmsIncludeName should be persisted as true',
    );
    assert(
      loadedSettings.bulkSmsMaxRecipients == 25,
      'bulkSmsMaxRecipients should be persisted as 25',
    );
    assert(
      loadedSettings.bulkSmsBatchDelay == 5,
      'bulkSmsBatchDelay should be persisted as 5',
    );
    assert(
      loadedSettings.bulkSmsConfirmBeforeSend == false,
      'bulkSmsConfirmBeforeSend should be persisted as false',
    );
    assert(
      loadedSettings.bulkSmsFilterType == 'credit',
      'bulkSmsFilterType should be persisted as "credit"',
    );
    assert(
      loadedSettings.bulkSmsLogActivity == false,
      'bulkSmsLogActivity should be persisted as false',
    );

    print('✅ All settings persisted correctly');

    // Test 4: Test different message templates
    print('\n📋 Test 4: Message Template Variations');
    print('-' * 50);

    final messageTemplates = [
      'Dear {name}, thank you for your business!',
      'Hello {name}, your balance is KSh {balance}.',
      'Hi {name}, visit us for great deals!',
      'Dear valued customer, your current balance is KSh {balance}. Thank you!',
    ];

    for (int i = 0; i < messageTemplates.length; i++) {
      final template = messageTemplates[i];
      final testSettings = loadedSettings.copyWith(
        bulkSmsDefaultMessage: template,
      );

      await settingsService.updateSystemSettings(testSettings);

      // Reload to verify
      final reloadedService = SettingsService();
      await reloadedService.init();
      final reloadedSettings = reloadedService.systemSettings.value;

      assert(
        reloadedSettings.bulkSmsDefaultMessage == template,
        'Message template $i should be persisted correctly',
      );

      print('✅ Template ${i + 1} persisted: ${template.substring(0, 30)}...');
    }

    // Test 5: Test edge cases
    print('\n📋 Test 5: Edge Cases');
    print('-' * 50);

    // Test with very long message
    final longMessage =
        'Dear {name}, ${'A' * 500} Your balance is KSh {balance}.';
    final longMessageSettings = loadedSettings.copyWith(
      bulkSmsDefaultMessage: longMessage,
      bulkSmsMaxRecipients: 1000, // Large number
      bulkSmsBatchDelay: 0, // Minimum delay
    );

    await settingsService.updateSystemSettings(longMessageSettings);

    // Reload to verify
    final edgeCaseService = SettingsService();
    await edgeCaseService.init();
    final edgeCaseSettings = edgeCaseService.systemSettings.value;

    assert(
      edgeCaseSettings.bulkSmsDefaultMessage == longMessage,
      'Long message should be persisted',
    );
    assert(
      edgeCaseSettings.bulkSmsMaxRecipients == 1000,
      'Large recipient count should be persisted',
    );
    assert(
      edgeCaseSettings.bulkSmsBatchDelay == 0,
      'Zero delay should be persisted',
    );

    print('✅ Edge cases handled correctly');

    // Test 6: Test all boolean combinations
    print('\n📋 Test 6: Boolean Combinations');
    print('-' * 50);

    final booleanCombinations = [
      [true, true, true, true, true],
      [false, false, false, false, false],
      [true, false, true, false, true],
      [false, true, false, true, false],
    ];

    for (int i = 0; i < booleanCombinations.length; i++) {
      final combo = booleanCombinations[i];
      final boolSettings = loadedSettings.copyWith(
        enableBulkSms: combo[0],
        bulkSmsIncludeBalance: combo[1],
        bulkSmsIncludeName: combo[2],
        bulkSmsConfirmBeforeSend: combo[3],
        bulkSmsLogActivity: combo[4],
      );

      await settingsService.updateSystemSettings(boolSettings);

      // Reload to verify
      final boolService = SettingsService();
      await boolService.init();
      final boolLoadedSettings = boolService.systemSettings.value;

      assert(
        boolLoadedSettings.enableBulkSms == combo[0],
        'Boolean combo $i enableBulkSms failed',
      );
      assert(
        boolLoadedSettings.bulkSmsIncludeBalance == combo[1],
        'Boolean combo $i bulkSmsIncludeBalance failed',
      );
      assert(
        boolLoadedSettings.bulkSmsIncludeName == combo[2],
        'Boolean combo $i bulkSmsIncludeName failed',
      );
      assert(
        boolLoadedSettings.bulkSmsConfirmBeforeSend == combo[3],
        'Boolean combo $i bulkSmsConfirmBeforeSend failed',
      );
      assert(
        boolLoadedSettings.bulkSmsLogActivity == combo[4],
        'Boolean combo $i bulkSmsLogActivity failed',
      );

      print('✅ Boolean combination ${i + 1} persisted correctly');
    }

    print('\n🎉 Bulk SMS Settings Persistence Test Complete!');
    print('=' * 60);

    print('\n📋 Summary:');
    print('✅ Default settings loaded correctly');
    print('✅ Settings updates saved to database');
    print('✅ Settings persist across app restarts');
    print('✅ Message templates handled correctly');
    print('✅ Edge cases (long messages, large numbers) work');
    print('✅ Boolean combinations persist correctly');
    print('✅ Database schema supports all bulk SMS fields');

    print('\n📋 Bulk SMS Settings Features:');
    print('✅ Enable/disable bulk SMS functionality');
    print('✅ Customizable message templates with placeholders');
    print('✅ Configurable recipient batch sizes');
    print('✅ Adjustable delays between batches');
    print('✅ Optional confirmation before sending');
    print('✅ Flexible member filtering options');
    print('✅ Activity logging controls');
    print('✅ Include/exclude balance and name options');
  } catch (e, stackTrace) {
    print('❌ Test failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}
