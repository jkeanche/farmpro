import 'dart:math';
import 'package:get/get.dart';
import '../services/optimized_member_service.dart';
import '../models/member.dart';

class PerformanceTest {
  static final OptimizedMemberService _memberService = Get.find<OptimizedMemberService>();
  
  /// Generate test data for performance testing
  static Future<List<Member>> generateTestMembers(int count) async {
    final List<Member> testMembers = [];
    final random = Random();
    
    for (int i = 0; i < count; i++) {
      final member = Member(
        id: 'test_$i',
        memberNumber: 'MB${1000 + i}',
        fullName: _generateRandomName(),
        idNumber: '${20000000 + random.nextInt(10000000)}',
        phoneNumber: '+254${700000000 + random.nextInt(99999999)}',
        email: 'member$i@test.com',
        registrationDate: DateTime.now().subtract(Duration(days: random.nextInt(365))),
        gender: random.nextBool() ? 'Male' : 'Female',
        zone: _getRandomZone(),
        acreage: 0.5 + random.nextDouble() * 4.5,
        noTrees: 50 + random.nextInt(450),
        isActive: random.nextBool(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testMembers.add(member);
    }
    
    return testMembers;
  }
  
  /// Benchmark pagination performance
  static Future<Map<String, dynamic>> benchmarkPagination(int totalMembers) async {
    final stopwatch = Stopwatch()..start();
    
    // Test first page load
    final firstPageStart = stopwatch.elapsedMilliseconds;
    await _memberService.loadMembersPage(0, refresh: true);
    final firstPageTime = stopwatch.elapsedMilliseconds - firstPageStart;
    
    // Test subsequent page loads
    final subsequentPageTimes = <int>[];
    for (int page = 1; page < 5 && page < (totalMembers / 50).ceil(); page++) {
      final pageStart = stopwatch.elapsedMilliseconds;
      await _memberService.loadMembersPage(page);
      subsequentPageTimes.add(stopwatch.elapsedMilliseconds - pageStart);
    }
    
    stopwatch.stop();
    
    return {
      'totalMembers': totalMembers,
      'firstPageLoadTime': firstPageTime,
      'subsequentPageLoadTimes': subsequentPageTimes,
      'averageSubsequentTime': subsequentPageTimes.isNotEmpty 
          ? subsequentPageTimes.reduce((a, b) => a + b) / subsequentPageTimes.length 
          : 0,
      'totalTestTime': stopwatch.elapsedMilliseconds,
    };
  }
  
  /// Benchmark search performance
  static Future<Map<String, dynamic>> benchmarkSearch() async {
    final searchQueries = ['John', 'Smith', 'MB1001', '254', 'Nakuru'];
    final searchTimes = <String, int>{};
    
    for (final query in searchQueries) {
      final stopwatch = Stopwatch()..start();
      await _memberService.searchMembers(query);
      stopwatch.stop();
      searchTimes[query] = stopwatch.elapsedMilliseconds;
    }
    
    return {
      'searchTimes': searchTimes,
      'averageSearchTime': searchTimes.values.reduce((a, b) => a + b) / searchTimes.length,
    };
  }
  
  /// Benchmark memory usage simulation
  static Future<Map<String, dynamic>> benchmarkMemoryUsage() async {
    final results = <String, dynamic>{};
    
    // Test cache management
    final cacheTestStart = DateTime.now();
    
    // Load multiple pages to test cache limits
    for (int page = 0; page < 20; page++) {
      await _memberService.loadMembersPage(page);
    }
    
    final cacheTestEnd = DateTime.now();
    results['cacheStressTestTime'] = cacheTestEnd.difference(cacheTestStart).inMilliseconds;
    
    // Test rapid searches to stress cache
    final searchStressStart = DateTime.now();
    final searches = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    
    for (final search in searches) {
      await _memberService.searchMembers(search);
      await Future.delayed(const Duration(milliseconds: 10)); // Simulate user typing
    }
    
    final searchStressEnd = DateTime.now();
    results['searchStressTestTime'] = searchStressEnd.difference(searchStressStart).inMilliseconds;
    
    return results;
  }
  
  /// Run comprehensive performance test suite
  static Future<Map<String, dynamic>> runFullBenchmark(int memberCount) async {
    print('Starting performance benchmark with $memberCount members...');
    
    final results = <String, dynamic>{};
    
    // Test pagination performance
    print('Testing pagination performance...');
    results['pagination'] = await benchmarkPagination(memberCount);
    
    // Test search performance
    print('Testing search performance...');
    results['search'] = await benchmarkSearch();
    
    // Test memory management
    print('Testing memory management...');
    results['memory'] = await benchmarkMemoryUsage();
    
    // Add system info
    results['systemInfo'] = {
      'testTimestamp': DateTime.now().toIso8601String(),
      'memberCount': memberCount,
      'pageSize': 50,
      'cacheSize': 500,
    };
    
    print('Performance benchmark completed!');
    return results;
  }
  
  /// Generate a random name for testing
  static String _generateRandomName() {
    final firstNames = [
      'John', 'Jane', 'Michael', 'Sarah', 'David', 'Emma', 'James', 'Olivia',
      'Robert', 'Sophia', 'William', 'Isabella', 'Charles', 'Mia', 'Joseph',
      'Charlotte', 'Thomas', 'Amelia', 'Christopher', 'Harper', 'Daniel',
      'Evelyn', 'Matthew', 'Abigail', 'Anthony', 'Emily', 'Mark', 'Elizabeth'
    ];
    
    final lastNames = [
      'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
      'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
      'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
      'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark'
    ];
    
    final random = Random();
    final firstName = firstNames[random.nextInt(firstNames.length)];
    final lastName = lastNames[random.nextInt(lastNames.length)];
    
    return '$firstName $lastName';
  }
  
  /// Get a random zone for testing
  static String _getRandomZone() {
    final zones = ['North', 'South', 'East', 'West', 'Central', 'Nakuru', 'Eldoret', 'Mombasa'];
    return zones[Random().nextInt(zones.length)];
  }
  
  /// Print formatted benchmark results
  static void printBenchmarkResults(Map<String, dynamic> results) {
    print('\n=== PERFORMANCE BENCHMARK RESULTS ===');
    print('Test Date: ${results['systemInfo']['testTimestamp']}');
    print('Total Members: ${results['systemInfo']['memberCount']}');
    print('Page Size: ${results['systemInfo']['pageSize']}');
    print('Cache Size: ${results['systemInfo']['cacheSize']}');
    
    print('\n--- PAGINATION PERFORMANCE ---');
    final pagination = results['pagination'];
    print('First Page Load: ${pagination['firstPageLoadTime']}ms');
    print('Average Subsequent Page Load: ${pagination['averageSubsequentTime'].toStringAsFixed(1)}ms');
    
    print('\n--- SEARCH PERFORMANCE ---');
    final search = results['search'];
    print('Average Search Time: ${search['averageSearchTime'].toStringAsFixed(1)}ms');
    print('Search Times by Query:');
    search['searchTimes'].forEach((query, time) {
      print('  "$query": ${time}ms');
    });
    
    print('\n--- MEMORY MANAGEMENT ---');
    final memory = results['memory'];
    print('Cache Stress Test: ${memory['cacheStressTestTime']}ms');
    print('Search Stress Test: ${memory['searchStressTestTime']}ms');
    
    print('\n=== END BENCHMARK RESULTS ===\n');
  }
} 