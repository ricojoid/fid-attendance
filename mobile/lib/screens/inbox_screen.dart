import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
      final announcements = await ApiService.getAnnouncements();

      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_notif_ids') ?? [];

      List<Map<String, dynamic>> combinedNotifications = [];

      // 1. Backend Notifications from DB
      for (var n in dbNotifications) {
        if (n is Map) {
          final idStr = n['id']?.toString() ?? '';
          final status = (n['status'] ?? 'INFO').toString();
          final isRead = n['is_read'] == true ||
              status == 'READ' ||
              readIds.contains(idStr) ||
              readIds.contains('db_notif_$idStr');

          final title = (n['title'] ?? 'Notification').toString();
          final message = (n['message'] ?? '').toString();
          final createdAt = (n['created_at'] ?? '').toString();
          final type = (n['type'] ?? 'INFO').toString();

          combinedNotifications.add({
            'id': 'db_notif_$idStr',
            'raw_id': n['id'],
            'title': title,
            'type': type,
            'status': status,
            'is_read': isRead,
            'message': message,
            'date': createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt,
            'icon': status == 'APPROVED'
                ? Icons.check_circle_rounded
                : (status == 'REJECTED'
                    ? Icons.cancel_rounded
                    : Icons.notifications_active_rounded),
            'color': status == 'APPROVED'
                ? const Color(0xFF10B981)
                : (status == 'REJECTED'
                    ? AppColors.red
                    : AppColors.red),
          });
        }
      }

      // 2. Announcements
      for (var a in announcements) {
        if (a is Map) {
          final aId = a['id']?.toString() ?? '';
          final isRead = readIds.contains('ann_$aId');
          final title = (a['title'] ?? 'Announcement').toString();
          final content = (a['content'] ?? '').toString();
          final cat = (a['category'] ?? 'GENERAL').toString();
          final createdAt = (a['created_at'] ?? '').toString();

          combinedNotifications.add({
            'id': 'ann_$aId',
            'raw_id': 'ann_$aId',
            'title': '📢 $title',
            'type': 'ANNOUNCEMENT',
            'status': cat,
            'is_read': isRead,
            'message': content,
            'date': createdAt.length >= 10 ? createdAt.substring(0, 10) : 'Recent',
            'icon': Icons.campaign_rounded,
            'color': const Color(0xFF2563EB),
          });
        }
      }

      if (mounted) {
        setState(() {
          _notifications = combinedNotifications;
          _approvalRequests = dbPendingApprovals;
        });
      }

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
        return AppColors.red;
      case 'READ':
        return AppColors.textMuted;
      case 'INFO':
        return AppColors.red;
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
        await ApiService.processApproval(category, reqId, newStatus);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request from $applicant has been ${newStatus.toLowerCase()} in Database! Applicant notified.'),
              backgroundColor: newStatus == 'APPROVED' ? const Color(0xFF10B981) : AppColors.red,
            ),
          );
        }

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
    final unreadNotifCount = _notifications.where((e) => e is Map && e['is_read'] != true).length;
    final pendingApprovalCount = _approvalRequests.where((e) => e is Map && e['status'] == 'PENDING').length;

    final notifTabTitle = unreadNotifCount > 0 ? 'Notifications ($unreadNotifCount)' : 'Notifications';
    final approvalTabTitle = pendingApprovalCount > 0 ? 'Need My Approval ($pendingApprovalCount)' : 'Need My Approval';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Inbox & Center', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.red,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorColor: AppColors.red,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(notifTabTitle),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(approvalTabTitle),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.red))
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
                                  Row(
                                    children: [
                                      Text(
                                        '${_notifications.length} Total',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                      ),
                                      if (unreadNotifCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.red.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$unreadNotifCount unread',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.red),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (unreadNotifCount > 0)
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          for (var item in _notifications) {
                                            if (item is Map) {
                                              item['is_read'] = true;
                                            }
                                          }
                                        });

                                        await ApiService.markAllNotificationsAsRead();

                                        final prefs = await SharedPreferences.getInstance();
                                        final existingReadIds = prefs.getStringList('read_notif_ids') ?? [];
                                        final readSet = Set<String>.from(existingReadIds);
                                        for (var n in _notifications) {
                                          if (n is Map && n['id'] != null) {
                                            readSet.add(n['id'].toString());
                                            if (n['raw_id'] != null) readSet.add(n['raw_id'].toString());
                                          }
                                        }
                                        await prefs.setStringList('read_notif_ids', readSet.toList());
                                        await ApiService.refreshInboxCount();

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('All notifications marked as read!'),
                                                ],
                                              ),
                                              backgroundColor: Color(0xFF10B981),
                                              behavior: SnackBarBehavior.floating,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.done_all_rounded, size: 16, color: AppColors.red),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Mark all as read',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    const Row(
                                      children: [
                                        Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text(
                                          'All read',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                        ),
                                      ],
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
                                  final isRead = item['is_read'] == true;
                                  final icon = (item['icon'] is IconData) ? (item['icon'] as IconData) : Icons.notifications_rounded;
                                  final iconColor = (item['color'] is Color) ? (item['color'] as Color) : AppColors.red;

                                  final statusColor = isRead ? AppColors.textFaint : _getStatusColor(status);

                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: Duration(milliseconds: 200 + index * 40),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) => Transform.translate(
                                      offset: Offset(0, 14 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        if (!isRead) {
                                          setState(() {
                                            item['is_read'] = true;
                                          });

                                          final rawId = item['raw_id']?.toString() ?? item['id']?.toString() ?? '';
                                          await ApiService.markSingleNotificationAsRead(rawId);

                                          final prefs = await SharedPreferences.getInstance();
                                          final existingReadIds = prefs.getStringList('read_notif_ids') ?? [];
                                          if (!existingReadIds.contains(item['id'].toString())) {
                                            existingReadIds.add(item['id'].toString());
                                            await prefs.setStringList('read_notif_ids', existingReadIds);
                                          }
                                          await ApiService.refreshInboxCount();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isRead ? const Color(0xFFFAFAFA) : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isRead ? AppColors.line : AppColors.red.withValues(alpha: 0.35),
                                            width: isRead ? 1.0 : 1.2,
                                          ),
                                          boxShadow: isRead
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: AppColors.red.withValues(alpha: 0.05),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isRead
                                                    ? AppColors.line
                                                    : iconColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                icon,
                                                color: isRead ? AppColors.textMuted : iconColor,
                                                size: 22,
                                              ),
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
                                                        child: Row(
                                                          children: [
                                                            if (!isRead) ...[
                                                              Container(
                                                                width: 7,
                                                                height: 7,
                                                                margin: const EdgeInsets.only(right: 6),
                                                                decoration: BoxDecoration(
                                                                  color: AppColors.red,
                                                                  shape: BoxShape.circle,
                                                                ),
                                                              ),
                                                            ],
                                                            Expanded(
                                                              child: Text(
                                                                title,
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                                  color: isRead ? AppColors.textMuted : AppColors.text,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withValues(alpha: isRead ? 0.08 : 0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          isRead ? 'READ' : status,
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    message,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isRead ? AppColors.textMuted : AppColors.text,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        date,
                                                        style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                                                      ),
                                                      if (!isRead)
                                                        Text(
                                                          'Tap to mark read',
                                                          style: TextStyle(fontSize: 10, color: AppColors.red, fontWeight: FontWeight.w600),
                                                        )
                                                      else
                                                        Row(
                                                          children: [
                                                            Icon(Icons.done_all_rounded, size: 12, color: AppColors.textFaint),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              'Read',
                                                              style: TextStyle(fontSize: 10, color: AppColors.textFaint, fontWeight: FontWeight.w500),
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
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
                    Divider(height: 1, color: AppColors.line),

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

                                  Color categoryColor = AppColors.red;
                                  IconData categoryIcon = Icons.assignment_rounded;

                                  if (category == 'OVERTIME') {
                                    categoryColor = const Color(0xFF7C3AED);
                                    categoryIcon = Icons.access_time_filled_rounded;
                                  } else if (category == 'ATTENDANCE') {
                                    categoryColor = const Color(0xFFD97706);
                                    categoryIcon = Icons.edit_calendar_rounded;
                                  } else if (category == 'LEAVE') {
                                    categoryColor = AppColors.red;
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
                                    decoration: BoxDecoration(color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.line),
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
                                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                                                  ),
                                                  Text(
                                                    dept,
                                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                                        Divider(height: 1, color: AppColors.line),
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
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason / Notes: $reason',
                                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                                                    foregroundColor: AppColors.red,
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
          color: isSelected ? Colors.white : AppColors.textMuted,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.red,
      backgroundColor: AppColors.line,
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
            Icon(iconData, size: 48, color: AppColors.line),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
