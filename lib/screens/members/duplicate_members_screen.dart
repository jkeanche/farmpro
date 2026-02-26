import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class DuplicateMembersScreen extends StatefulWidget {
  const DuplicateMembersScreen({super.key});

  @override
  State<DuplicateMembersScreen> createState() => _DuplicateMembersScreenState();
}

class _DuplicateMembersScreenState extends State<DuplicateMembersScreen> {
  final MemberController _memberController = Get.find<MemberController>();
  Map<String, dynamic> duplicates = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  void _loadDuplicates() async {
    setState(() {
      isLoading = true;
    });

    duplicates = await _memberController.findAllDuplicates();

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Duplicate Members',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDuplicates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final memberNumberDuplicates = duplicates['memberNumbers'] as Map<String, List<Member>>;
    final idNumberDuplicates = duplicates['idNumbers'] as Map<String, List<Member>>;

    if (memberNumberDuplicates.isEmpty && idNumberDuplicates.isEmpty) {
      return const EmptyState(
        title: 'No Duplicates Found',
        message: 'All member numbers and ID numbers are unique',
        icon: Icons.check_circle,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(memberNumberDuplicates, idNumberDuplicates),
          
          const SizedBox(height: 16.0),
          
          // Member Number Duplicates
          if (memberNumberDuplicates.isNotEmpty) ...[
            _buildSectionHeader('Duplicate Member Numbers', memberNumberDuplicates.length),
            const SizedBox(height: 8.0),
            ...memberNumberDuplicates.entries.map((entry) => 
              _buildDuplicateGroup(
                title: 'Member Number: ${entry.key}',
                members: entry.value,
                isDuplicateByMemberNumber: true,
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          
          // ID Number Duplicates
          if (idNumberDuplicates.isNotEmpty) ...[
            _buildSectionHeader('Duplicate ID Numbers', idNumberDuplicates.length),
            const SizedBox(height: 8.0),
            ...idNumberDuplicates.entries.map((entry) => 
              _buildDuplicateGroup(
                title: 'ID Number: ${entry.key}',
                members: entry.value,
                isDuplicateByMemberNumber: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, List<Member>> memberNumberDuplicates, Map<String, List<Member>> idNumberDuplicates) {
    final totalMemberNumberDuplicates = memberNumberDuplicates.values.fold(0, (sum, list) => sum + list.length);
    final totalIdNumberDuplicates = idNumberDuplicates.values.fold(0, (sum, list) => sum + list.length);

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duplicate Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.numbers,
                    title: 'Member Numbers',
                    count: memberNumberDuplicates.length,
                    totalAffected: totalMemberNumberDuplicates,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.perm_identity,
                    title: 'ID Numbers',
                    count: idNumberDuplicates.length,
                    totalAffected: totalIdNumberDuplicates,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required int count,
    required int totalAffected,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            '$count duplicates',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$totalAffected members affected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Icon(
          Icons.warning,
          color: Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 8.0),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateGroup({
    required String title,
    required List<Member> members,
    required bool isDuplicateByMemberNumber,
  }) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDuplicateByMemberNumber ? Icons.numbers : Icons.perm_identity,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                Text(
                  '${members.length} members',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12.0),
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberTile(member, isDuplicateByMemberNumber);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Member member, bool isDuplicateByMemberNumber) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Text(
          member.fullName[0].toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      title: Text(
        member.fullName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Member #: ${member.memberNumber}'),
          if (member.idNumber != null) 
            Text('ID #: ${member.idNumber}'),
          if (member.phoneNumber != null) 
            Text('Phone: ${member.phoneNumber}'),
          Text(
            'Registered: ${_formatDate(member.registrationDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!member.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                'Inactive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          const SizedBox(width: 8.0),
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(value, member),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility),
                  title: Text('View Details'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit Member'),
                  dense: true,
                ),
              ),
              if (member.isActive)
                const PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading: Icon(Icons.block, color: Colors.orange),
                    title: Text('Deactivate'),
                    dense: true,
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, Member member) {
    switch (action) {
      case 'view':
        _showMemberDetails(member);
        break;
      case 'edit':
        Get.toNamed('/add-member', arguments: member)?.then((_) => _loadDuplicates());
        break;
      case 'deactivate':
        _deactivateMember(member);
        break;
      case 'delete':
        _deleteMember(member);
        break;
    }
  }

  void _showMemberDetails(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.fullName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Member Number', member.memberNumber),
              _buildDetailRow('ID Number', member.idNumber ?? 'Not provided'),
              _buildDetailRow('Phone Number', member.phoneNumber ?? 'Not provided'),
              _buildDetailRow('Email', member.email ?? 'Not provided'),
              _buildDetailRow('Gender', member.gender ?? 'Not specified'),
              _buildDetailRow('Zone', member.zone ?? 'Not specified'),
              if (member.acreage != null)
                _buildDetailRow('Acreage', '${member.acreage!.toStringAsFixed(2)} acres'),
              if (member.noTrees != null)
                _buildDetailRow('No. Trees', member.noTrees!.toString()),
              _buildDetailRow('Status', member.isActive ? 'Active' : 'Inactive'),
              _buildDetailRow('Registration Date', _formatDate(member.registrationDate)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _deactivateMember(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Member'),
        content: Text('Are you sure you want to deactivate ${member.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _memberController.deactivateMember(member.id);
              _loadDuplicates();
              Get.snackbar(
                'Success',
                'Member deactivated successfully',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _deleteMember(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete ${member.fullName}?'),
            const SizedBox(height: 8.0),
            const Text(
              'This action cannot be undone and will remove all associated data.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await _memberController.deleteMember(member.id);
                _loadDuplicates();
                Get.snackbar(
                  'Success',
                  'Member deleted successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                // Check if this is a collection restriction error and show a proper dialog
                String errorMessage = e.toString();
                if (errorMessage.contains('Cannot delete member') && errorMessage.contains('coffee collection')) {
                  // Show detailed dialog for member deletion restriction
                  Get.dialog(
                    AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Cannot Delete Member'),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              errorMessage.replaceAll('Exception: ', ''),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text(
                                        'Alternative Options:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '• Deactivate the member instead of deleting\n'
                                    '• Remove collections from Collection History\n'
                                    '• Contact system administrator for assistance',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Show regular snackbar for other errors
                  Get.snackbar(
                    'Error',
                    'Failed to delete member: $errorMessage',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 5),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 