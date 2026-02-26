import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_constants.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'add_member_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _memberController = Get.find<MemberController>();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  List<Member> _searchResults = [];
  bool _isSearching = false;
  bool _useButtonSearch = false; // Toggle between live search and button search

  void _onSearchChanged(String value) {
    if (_useButtonSearch) return; // Skip live search if button mode is enabled

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      // Increased debounce time
      if (!mounted) return;

      final query = value.trim();
      if (query == _searchQuery) return; // Skip if same query

      setState(() {
        _searchQuery = query;
        _isSearching = query.isNotEmpty;
      });

      if (query.isNotEmpty && query.length >= 2) {
        // Minimum 2 characters
        try {
          final results = await _memberController.quickSearchMembers(
            query,
            limit: 20,
          ); // Reduced limit
          if (mounted && query == _searchController.text.trim()) {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isSearching = false;
            });
          }
        }
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _memberController.quickSearchMembers(
        query,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToAddMember() {
    Get.to(() => const AddMemberScreen());
  }

  void _importMembersFromExcel() async {
    try {
      final importedMembers = await _memberController.importMembersFromExcel();

      // Force refresh the screen
      if (mounted) {
        setState(() {});
      }

      if (importedMembers.isNotEmpty) {
        Get.snackbar(
          'Import Successful',
          'Imported ${importedMembers.length} members',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'Import Failed',
          'No members were imported',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Import Failed',
        'Error importing members: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _importMembersFromCsv() async {
    try {
      final importedMembers = await _memberController.importMembersFromCsv();

      // Force refresh the screen
      if (mounted) {
        setState(() {});
      }

      if (importedMembers.isNotEmpty) {
        Get.snackbar(
          'CSV Import Successful',
          'Imported ${importedMembers.length} members from CSV',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'CSV Import Failed',
          'No members were imported from CSV',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'CSV Import Failed',
        'Error importing members from CSV: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  void _downloadImportTemplate() async {
    try {
      await _memberController.downloadImportTemplate();
    } catch (e) {
      print('Error downloading template: $e');
      Get.snackbar(
        'Error',
        'Failed to download import template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _downloadCsvTemplate() async {
    try {
      await _memberController.downloadCsvTemplate();
    } catch (e) {
      print('Error downloading CSV template: $e');
      Get.snackbar(
        'Error',
        'Failed to download CSV template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Import Members',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.recommend, color: Colors.green[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CSV format is recommended for better compatibility and easier editing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                CustomButton(
                  text: 'Download CSV Template',
                  onPressed: () {
                    Navigator.pop(context);
                    _downloadCsvTemplate();
                  },
                  buttonType: ButtonType.primary,
                  icon: Icons.download,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Import from CSV (Recommended)',
                  onPressed: () {
                    Navigator.pop(context);
                    _importMembersFromCsv();
                  },
                  buttonType: ButtonType.outline,
                  icon: Icons.upload_file,
                ),
                const SizedBox(height: 24.0),
                Divider(color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 8.0),
                Text(
                  'Legacy Excel Support',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Download Excel Template',
                  onPressed: () {
                    Navigator.pop(context);
                    _downloadImportTemplate();
                  },
                  buttonType: ButtonType.text,
                  icon: Icons.download,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Import from Excel',
                  onPressed: () {
                    Navigator.pop(context);
                    _importMembersFromExcel();
                  },
                  buttonType: ButtonType.text,
                  icon: Icons.upload_file,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  buttonType: ButtonType.text,
                ),
              ],
            ),
          ),
    );
  }

  void _exportMembersToExcel() async {
    try {
      await _memberController.exportMembersToExcel();
    } catch (e) {
      print('Error exporting members: $e');
      Get.snackbar(
        'Error',
        'Failed to export members: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _exportMembersToCsv() async {
    try {
      await _memberController.exportMembersToCsv();
    } catch (e) {
      print('Error exporting members to CSV: $e');
      Get.snackbar(
        'Error',
        'Failed to export members to CSV: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Export Members',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.recommend, color: Colors.green[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CSV format is recommended for better compatibility',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                CustomButton(
                  text: 'Export to CSV (Recommended)',
                  onPressed: () {
                    Navigator.pop(context);
                    _exportMembersToCsv();
                  },
                  buttonType: ButtonType.primary,
                  icon: Icons.file_download,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Export to Excel',
                  onPressed: () {
                    Navigator.pop(context);
                    _exportMembersToExcel();
                  },
                  buttonType: ButtonType.outline,
                  icon: Icons.file_download,
                ),
                const SizedBox(height: 16.0),
                CustomButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  buttonType: ButtonType.text,
                ),
              ],
            ),
          ),
    );
  }

  void _showMemberDetails(Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildMemberDetailsSheet(member),
    );
  }

  Widget _buildMemberDetailsSheet(Member member) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Member Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildDetailRow('Member Number', member.memberNumber),
          _buildDetailRow('Full Name', member.fullName),
          if (member.idNumber != null)
            _buildDetailRow('ID Number', member.idNumber!),
          if (member.phoneNumber != null)
            _buildDetailRow('Phone Number', member.phoneNumber!),
          if (member.email != null) _buildDetailRow('Email', member.email!),
          if (member.gender != null) _buildDetailRow('Gender', member.gender!),
          if (member.zone != null) _buildDetailRow('Zone', member.zone!),
          if (member.acreage != null)
            _buildDetailRow(
              'Acreage',
              '${member.acreage!.toStringAsFixed(2)} acres',
            ),
          if (member.noTrees != null)
            _buildDetailRow('No. Trees', member.noTrees!.toString()),
          _buildStatusRow('Status', member.isActive),
          _buildDetailRow(
            'Registration Date',
            _formatDate(member.registrationDate),
          ),
          const SizedBox(height: 24.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              CustomButton(
                text: 'Edit',
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToEditMember(member);
                },
                buttonType: ButtonType.outline,
                icon: Icons.edit,
              ),
              CustomButton(
                text: 'Collections',
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.toNamed(
                    AppConstants.memberCollectionReportRoute,
                    arguments: member,
                  );
                },
                buttonType: ButtonType.outline,
                icon: Icons.receipt_long,
              ),
              CustomButton(
                text: member.isActive ? 'Deactivate' : 'Activate',
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleMemberStatus(member);
                },
                buttonType: ButtonType.outline,
                icon: member.isActive ? Icons.person_off : Icons.person,
              ),
              // CustomButton(
              //   text: 'Delete',
              //   onPressed: () {
              //     Navigator.of(context).pop();
              //     _showDeleteConfirmation(member);
              //   },
              //   buttonType: ButtonType.outline,
              //   icon: Icons.delete,
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.0,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.0,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _navigateToEditMember(Member member) {
    // Navigate to edit member screen
    Get.to(() => AddMemberScreen(member: member));
  }

  void _toggleMemberStatus(Member member) async {
    try {
      if (member.isActive) {
        // Deactivate member
        await _memberController.deactivateMember(member.id);

        Get.snackbar(
          'Success',
          'Member deactivated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } else {
        // Activate member
        await _memberController.activateMember(member.id);

        Get.snackbar(
          'Success',
          'Member activated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Theme.of(context).colorScheme.primary,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update member status: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Members',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showExportOptions,
            tooltip: 'Export Members Data',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showImportOptions(),
            tooltip: 'Import Members',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddMember,
            tooltip: 'Add Member',
          ),
        ],
        showBackButton: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              _useButtonSearch
                                  ? 'Enter member number (exact) or name and tap Search'
                                  : 'Search by member number (exact) or name',
                          prefixIcon:
                              _isSearching
                                  ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.search),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted:
                            _useButtonSearch ? (_) => _performSearch() : null,
                      ),
                    ),
                    if (_useButtonSearch) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : _performSearch,
                        child: const Text('Search'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Search mode toggle
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _useButtonSearch
                            ? 'Button search mode (better for large datasets)'
                            : 'Live search mode (searches as you type)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: _useButtonSearch,
                      onChanged: (value) {
                        setState(() {
                          _useButtonSearch = value;
                          if (value) {
                            _clearSearch(); // Clear search when switching to button mode
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Members List
          Expanded(
            child: Obx(() {
              final members = _memberController.members;

              if (members.isEmpty) {
                return EmptyState(
                  title: 'No Members Found',
                  message: 'Add your first member to get started',
                  icon: Icons.people,
                  buttonText: 'Add Member',
                  onButtonPressed: _navigateToAddMember,
                );
              }

              final filteredMembers =
                  _searchQuery.isEmpty
                      ? members
                      : _searchResults.isNotEmpty
                      ? _searchResults
                      : members.where((member) {
                        final query = _searchQuery.toLowerCase();
                        // Exact match for member number, partial match for name
                        return member.memberNumber.toLowerCase() == query ||
                            member.fullName.toLowerCase().contains(query);
                      }).toList();

              if (filteredMembers.isEmpty) {
                return const EmptyState(
                  title: 'No Matching Members',
                  message: 'Try a different search term',
                  icon: Icons.search_off,
                );
              }

              return ListView.builder(
                itemCount: filteredMembers.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                cacheExtent: 300,
                itemExtent: 80,
                physics: const AlwaysScrollableScrollPhysics(),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                controller: ScrollController(keepScrollOffset: false),
                itemBuilder: (context, index) {
                  if (index >= 100) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Showing first 100 results. Use search to refine your results.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final member = filteredMembers[index];
                  return _MemberListItem(
                    member: member,
                    key: ValueKey(member.id),
                    onTap: () => _showMemberDetails(member),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMember,
        tooltip: 'Add Member',
        heroTag: "add_member_fab",
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Optimized member list item with proper vertical alignment
class _MemberListItem extends StatelessWidget {
  final Member member;
  final VoidCallback? onTap;

  const _MemberListItem({super.key, required this.member, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor:
              member.isActive
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          child: Text(
            member.fullName.isNotEmpty ? member.fullName[0] : '?',
            style: TextStyle(
              color:
                  member.isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.fullName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        member.isActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    member.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: member.isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Member #: ${member.memberNumber}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 13),
              ),
              if (member.zone != null)
                Text(
                  'Zone: ${member.zone}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
