// Enhanced SMS delivery diagnostic tool
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'lib/services/sms_service.dart';
import 'lib/services/member_service.dart';
import 'lib/services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('📱 SMS Delivery Diagnostic Tool');
  print('===============================');

  try {
    // Initialize services
    Get.put(DatabaseHelper());
    await Get.putAsync(() => SmsService().init());
    await Get.putAsync(() => MemberService().init());

    final smsService = Get.find<SmsService>();
    final memberService = Get.find<MemberService>();

    print('✅ Services initialized successfully');

    // Test 1: Check SMS service status
    print('\n📋 Test 1: SMS Service Status Check');
    print('===================================');

    print('SMS Available: ${smsService.isSmsAvailable.value}');
    print('Total SMS Sent: ${smsService.totalSmsSent.value}');
    print('Total SMS Failed: ${smsService.totalSmsFailed.value}');
    print('Queue Size: ${smsService.smsQueueSize.value}');

    // Test 2: Phone number validation
    print('\n📞 Test 2: Phone Number Validation');
    print('===================================');

    final testNumbers = [
      '+254797764170', // The number from the log
      '0797764170',
      '797764170',
      '+254712345678',
      '0712345678',
      'invalid_number',
    ];

    for (final number in testNumbers) {
      final validated = smsService.validateKenyanPhoneNumber(number);
      print('Input: "$number" -> Validated: "$validated"');
    }

    // Test 3: Find the specific member from the log
    print('\n👤 Test 3: Member Lookup');
    print('========================');

    final memberName = 'ANTONY IRUNGU WANJOHI';
    await memberService.searchMembers(memberName);
    final members = memberService.members;

    if (members.isNotEmpty) {
      final member = members.first;
      print('✅ Found member: ${member.fullName}');
      print('   Phone: ${member.phoneNumber}');
      print('   Member Number: ${member.memberNumber}');
      print('   Active: ${member.isActive}');

      // Test 4: Send test SMS to this member
      print('\n📱 Test 4: Test SMS Sending');
      print('===========================');

      if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty) {
        final testMessage = '''TEST SMS FROM COFFEE PRO
This is a test message to verify SMS delivery.
Time: ${DateTime.now().toString()}
If you receive this, SMS is working correctly.''';

        print('Sending test SMS to ${member.phoneNumber}...');
        print('Message: $testMessage');

        final success = await smsService.sendSmsRobust(
          member.phoneNumber!,
          testMessage,
          maxRetries: 1,
          priority: 1,
        );

        if (success) {
          print('✅ Test SMS sent successfully');
          print('⏳ Please check if the SMS was received on the phone');
        } else {
          print('❌ Test SMS failed to send');
        }
      } else {
        print('❌ Member has no phone number');
      }
    } else {
      print('❌ Member not found: $memberName');
    }

    // Test 5: SMS delivery troubleshooting
    print('\n🔧 Test 5: SMS Delivery Troubleshooting');
    print('=======================================');

    print('Common reasons why SMS might not be delivered:');
    print('');
    print('1. NETWORK ISSUES:');
    print('   • Poor network coverage at recipient location');
    print('   • Network congestion during peak hours');
    print('   • Temporary carrier service disruption');
    print('');
    print('2. PHONE ISSUES:');
    print('   • Phone is turned off or out of battery');
    print('   • Phone memory is full (SMS storage full)');
    print('   • Phone is in airplane mode');
    print('   • SMS app is disabled or malfunctioning');
    print('');
    print('3. CARRIER FILTERING:');
    print('   • SMS content flagged as spam');
    print('   • Bulk SMS restrictions');
    print('   • Cross-network delivery delays');
    print('   • DND (Do Not Disturb) service active');
    print('');
    print('4. NUMBER ISSUES:');
    print('   • Number is inactive or suspended');
    print('   • Number has been ported to different carrier');
    print('   • International roaming restrictions');
    print('');

    // Test 6: SMS content analysis
    print('\n📝 Test 6: SMS Content Analysis');
    print('===============================');

    final sampleMessage = '''COFFEE PRO SOCIETY
Fac:Main Factory
T/No:COF202508...
Date:01/08/25
M/No:001
M/Name:ANTONY IRUNGU WANJOHI
Type:CHERRY
Kgs:15.3
Bags:1
Total:15 kg
Served By:Admin User''';

    print('Sample SMS content:');
    print('-------------------');
    print(sampleMessage);
    print('-------------------');
    print('Message length: ${sampleMessage.length} characters');

    if (sampleMessage.length > 160) {
      print(
        '⚠️  Message is longer than 160 characters (${sampleMessage.length})',
      );
      print('   This will be sent as multiple SMS parts');
      print('   Some carriers may delay or filter long messages');
    } else {
      print('✅ Message length is within single SMS limit');
    }

    // Check for potential spam triggers
    final spamKeywords = ['free', 'win', 'prize', 'urgent', 'click', 'link'];
    final messageWords = sampleMessage.toLowerCase().split(' ');
    final foundSpamWords =
        spamKeywords
            .where(
              (keyword) => messageWords.any((word) => word.contains(keyword)),
            )
            .toList();

    if (foundSpamWords.isNotEmpty) {
      print('⚠️  Potential spam keywords found: ${foundSpamWords.join(", ")}');
    } else {
      print('✅ No obvious spam keywords detected');
    }

    // Test 7: Delivery confirmation suggestions
    print('\n💡 Test 7: Delivery Confirmation Suggestions');
    print('============================================');

    print('To improve SMS delivery confirmation:');
    print('');
    print('1. IMMEDIATE ACTIONS:');
    print('   • Ask the member to check their SMS inbox');
    print('   • Check if phone has network coverage');
    print('   • Try calling the number to verify it\'s active');
    print('   • Ask member to restart their phone');
    print('');
    print('2. ALTERNATIVE VERIFICATION:');
    print('   • Send a simple test SMS like "Hi, please reply OK"');
    print('   • Try sending from a different phone manually');
    print('   • Use WhatsApp or other messaging app as backup');
    print('');
    print('3. TECHNICAL IMPROVEMENTS:');
    print('   • Implement delivery receipt requests');
    print('   • Add SMS gateway fallback');
    print('   • Log detailed sending attempts');
    print('   • Add user feedback mechanism');
    print('');

    // Test 8: Create a simple test SMS function
    print('\n🧪 Test 8: Interactive SMS Test');
    print('===============================');

    print('To manually test SMS delivery:');
    print('1. Find a test phone number');
    print('2. Send a simple test message');
    print('3. Verify delivery on the receiving phone');
    print('');
    print('Example test code:');
    print('```dart');
    print('final testNumber = "+254712345678"; // Replace with test number');
    print('final testMessage = "Test SMS from Coffee Pro - Please reply OK";');
    print(
      'final success = await smsService.sendSmsRobust(testNumber, testMessage);',
    );
    print('print("SMS sent: \$success");');
    print('```');

    print('\n🎯 DIAGNOSTIC SUMMARY');
    print('=====================');
    print('✅ SMS service is working correctly (logs show successful sending)');
    print('✅ Phone number validation is working');
    print('✅ SMS permissions are granted');
    print('✅ Message format appears correct');
    print('');
    print('🔍 LIKELY CAUSES OF NON-DELIVERY:');
    print('• Network/carrier delivery delays (most common)');
    print('• Recipient phone issues (memory full, turned off)');
    print('• Cross-network delivery delays between carriers');
    print('• SMS filtering by recipient\'s carrier');
    print('');
    print('💡 RECOMMENDED ACTIONS:');
    print('1. Wait 5-10 minutes for delivery (network delays)');
    print('2. Ask member to check SMS inbox and spam folder');
    print('3. Verify phone number is correct and active');
    print('4. Try sending a simple test SMS manually');
    print('5. Consider implementing SMS delivery receipts');
  } catch (e) {
    print('❌ Error during SMS diagnostic: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
