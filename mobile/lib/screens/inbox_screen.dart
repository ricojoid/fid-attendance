import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _notifications = [];
  List<dynamic> _approvalRequests = [];
  bool _isLoading = true;

  // Sub-menu category filter for "Need My Approval" tab
  String _selectedApprovalCategory = 'ALL'; // 'ALL', 'OVERTIME', 'ATTENDANCE', 'LEAVE'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInboxData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInboxData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch real notifications and real pending approvals directly from Backend API DB
      final dbNotifications = await ApiService.getNotifications();
      final dbPendingApprovals = await ApiService.getPendingApprovals();
      final leaves = await ApiService.getLeaveHistory();
      final corrections = await ApiService.getCorrectionHistory();

      List<Map<String, dynamic>> combinedNotifications = [];

      // 1. Backend Notifications from DB
      if (dbNotifications is List) {
        for (var n in dbNotifications) {
          if (n is Map) {
            final status = (n['status'] ?? 'INFO').toString();
            final title = (n['title'] ?? 'Notification').toString();
            final message = (n['message'] ?? '').toString();
            final createdAt = (n['created_at'] ?? '').toString();
            final type = (n['type'] ?? 'INFO').toString();

            combinedNotifications.add({
              'id': 'db_notif_${n['id']}',
              'raw_id': n['id'],
              'title': title,
              'type': type,
              'status': status,
              'message': message,
              'date': createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt,
              'icon': status == 'APPROVED' ? Icons.check_circle_rounded : (status == 'REJECTED' ? Icons.cancel_rounded : Icons.notifications_active_rounded),
              'color': status == 'APPROVED' ? const Color(0xFF10B981) : (status == 'REJECTED' ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
            });
          }
        }
      }

      // 2. Add User's submitted leaves & corrections
      if (leaves is List) {
        for (var l in leaves) {
          if (l is Map) {
            final status = (l['status'] ?? 'PENDING').toString();
            String leaveType = 'Leave Request';
            if (l['leave_type'] is Map) {
              leaveType = l['leave_type']['name'] ?? 'Leave Request';
            } else if (l['leave_type'] is String) {
              leaveType = l['leave_type'];
            }
            final startDate = l['start_date'] ?? '-';
            final endDate = l['end_date'] ?? '-';

            combinedNotifications.add({
              'id': 'leave_${l['id']}',
              'title': '$leaveType Status: $status',
              'type': 'LEAVE',
              'status': status,
              'message': 'Your $leaveType request for $startDate to $endDate is $status.',
              'date': startDate,
              'icon': Icons.beach_access_rounded,
              'color': status == 'APPROVED' ? const Color(0xFF10B981) : (status == 'REJECTED' ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
            });
          }
        }
      }

      if (corrections is List) {
        for (var c in corrections) {
          if (c is Map) {
            final status = (c['status'] ?? 'PENDING').toString();
            final attDate = c['attendance_date'] ?? '-';

            combinedNotifications.add({
              'id': 'corr_${c['id']}',
              'title': 'Attendance Correction: $status',
              'type': 'CORRECTION',
              'status': status,
              'message': 'Your correction request for date $attDate is marked as $status.',
              'date': attDate,
              'icon': Icons.edit_calendar_rounded,
              'color': status == 'APPROVED' ? const Color(0xFF10B981) : (status == 'REJECTED' ? const Color(0xFFEF4444) : const Color(0xFFD97706)),
            });
          }
        }
      }

      // System notification header
      combinedNotifications.add({
        'id': 'sys_1',
        'title': 'Database Connected Live',
        'type': 'SYSTEM',
        'status': 'INFO',
        'message': 'Notifications & approvals are synchronized with PostgreSQL/SQLite Backend DB.',
        'date': 'Today',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF10B981),
      });

      setState(() {
        _notifications = combinedNotifications;
        _approvalRequests = dbPendingApprovals;
      });

      await ApiService.refreshInboxCount();
    } catch (e) {
      debugPrint('Failed to load inbox data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredApprovalRequests {
    if (_selectedApprovalCategory == 'ALL') {
      return _approvalRequests;
    }
    return _approvalRequests
        .where((item) => (item['category'] ?? '').toString().toUpperCase() == _selectedApprovalCategory)
        .toList();
  }

  Color _getStatusColor(dynamic status) {
    final str = (status ?? 'PENDING').toString().toUpperCase();
    switch (str) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'INFO':
        return const Color(0xFF2563EB);
      case 'PENDING':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _handleApprovalAction(dynamic item, String newStatus) async {
    if (item is Map) {
      final category = (item['category'] ?? 'LEAVE').toString();
      final reqId = item['id'];
      final applicant = (item['applicant_name'] ?? 'Employee').toString();

      try {
        // Send approval action to Backend API (updates DB & creates applicant notification)
        await ApiService.processApproval(category, reqId, newStatus);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request from $applicant has been ${newStatus.toLowerCase()} in Database! Applicant notified.'),
              backgroundColor: newStatus == 'APPROVED' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          );
        }

        // Refresh inbox data live from DB
        await _fetchInboxData();
      } catch (e) {
        debugPrint('Failed to process approval: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingApprovalCount = _approvalRequests.where((e) => e is Map && e['status'] == 'PENDING').length;
    final approvalBadgeText = pendingApprovalCount > 99 ? '99+' : '$pendingApprovalCount';
    final notifBadgeText = _notifications.length > 99 ? '99+' : '${_notifications.length}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Inbox & Center', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Notifications ($notifBadgeText)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Need My Approval ($approvalBadgeText)'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Notifications List
                RefreshIndicator(
                  onRefresh: _fetchInboxData,
                  child: _notifications.isEmpty
                      ? _buildEmptyState('No notifications at this moment', Icons.notifications_off_rounded)
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_notifications.length} Notifications',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await ApiService.markAllNotificationsAsRead();
                                      await _fetchInboxData();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('All notifications marked as read!'), backgroundColor: Color(0xFF10B981)),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Mark all as read',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _notifications.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _notifications[index];
                                  if (item is! Map) return const SizedBox.shrink();

                                  final title = (item['title'] ?? 'Notification').toString();
                                  final message = (item['message'] ?? '').toString();
                                  final date = (item['date'] ?? '').toString();
                                  final status = (item['status'] ?? 'INFO').toString();
                                  final icon = (item['icon'] is IconData) ? (item['icon'] as IconData) : Icons.notifications_rounded;
                                  final iconColor = (item['color'] is Color) ? (item['color'] as Color) : const Color(0xFF2563EB);

                                  final statusColor = _getStatusColor(status);

                                  return InkWell(
                                    onTap: () async {
                                      final rawId = item['raw_id'] ?? item['id']?.toString().replaceAll('db_notif_', '');
                                      if (rawId != null) {
                                        await ApiService.markSingleNotificationAsRead(rawId.toString());
                                        await _fetchInboxData();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: iconColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(icon, color: iconColor, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  message,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      date,
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                    ),
                                                    const Text(
                                                      'Tap to mark read',
                                                      style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                // Tab 2: Need My Approval List with Sub-menu Category Filter
                Column(
                  children: [
                    // Sub-menu Category Bar (Overtime, Attendance, Leave)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildApprovalCategoryChip('ALL', 'All Pending'),
                            const SizedBox(width: 8),
                            _buildApprovalCategoryChip('OVERTIME', 'Overtime ⏰'),
                            const SizedBox(width: 8),
                            _buildApprovalCategoryChip('ATTENDANCE', 'Attendance ✏️'),
                            const SizedBox(width: 8),
                            _buildApprovalCategoryChip('LEAVE', 'Leave 🏖️'),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Approval List View
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchInboxData,
                        child: _filteredApprovalRequests.isEmpty
                            ? _buildEmptyState(
                                'No pending approval requests requiring your action.\nApprover mappings are synchronized with DB.',
                                Icons.check_circle_outline_rounded,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredApprovalRequests.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredApprovalRequests[index];
                                  if (item is! Map) return const SizedBox.shrink();
                                  final name = (item['applicant_name'] ?? 'Employee').toString();
                                  final dept = (item['department'] ?? 'General').toString();
                                  final reqType = (item['request_type'] ?? 'Application Request').toString();
                                  final period = (item['period'] ?? '-').toString();
                                  final reason = (item['reason'] ?? '-').toString();
                                  final status = (item['status'] ?? 'PENDING').toString();
                                  final category = (item['category'] ?? 'LEAVE').toString();
                                  final isPending = status == 'PENDING';

                                  Color categoryColor = const Color(0xFF2563EB);
                                  IconData categoryIcon = Icons.assignment_rounded;

                                  if (category == 'OVERTIME') {
                                    categoryColor = const Color(0xFF7C3AED);
                                    categoryIcon = Icons.access_time_filled_rounded;
                                  } else if (category == 'ATTENDANCE') {
                                    categoryColor = const Color(0xFFD97706);
                                    categoryIcon = Icons.edit_calendar_rounded;
                                  } else if (category == 'LEAVE') {
                                    categoryColor = const Color(0xFF2563EB);
                                    categoryIcon = Icons.beach_access_rounded;
                                  }

                                  final avatarUrl = (item['applicant_avatar'] ?? item['avatar_url'] ?? '').toString();
                                  ImageProvider? avatarProvider;
                                  if (avatarUrl.isNotEmpty) {
                                    if (avatarUrl.startsWith('data:image')) {
                                      avatarProvider = MemoryImage(base64Decode(avatarUrl.split(',').last));
                                    } else if (kIsWeb || avatarUrl.startsWith('http') || avatarUrl.startsWith('blob:')) {
                                      avatarProvider = NetworkImage(avatarUrl);
                                    } else {
                                      avatarProvider = FileImage(File(avatarUrl));
                                    }
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Applicant Info & Category Tag
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: categoryColor,
                                              backgroundImage: avatarProvider,
                                              child: avatarProvider == null
                                                  ? Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                  ),
                                                  Text(
                                                    dept,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 12),

                                        // Request Details
                                        Row(
                                          children: [
                                            Icon(categoryIcon, size: 16, color: categoryColor),
                                            const SizedBox(width: 6),
                                            Text(
                                              reqType,
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: categoryColor),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          period,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason / Notes: $reason',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),

                                        if (isPending) ...[
                                          const SizedBox(height: 14),
                                          // Action Buttons (Approve / Reject)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _handleApprovalAction(item, 'REJECTED'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFFEF4444),
                                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                  ),
                                                  icon: const Icon(Icons.close_rounded, size: 16),
                                                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _handleApprovalAction(item, 'APPROVED'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF10B981),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    elevation: 0,
                                                  ),
                                                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                                  label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildApprovalCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedApprovalCategory == categoryKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedApprovalCategory = categoryKey;
          });
        }
      },
    );
  }

  Widget _buildEmptyState(String message, IconData iconData) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
