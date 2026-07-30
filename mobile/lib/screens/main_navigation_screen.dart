import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'employees_screen.dart';
import 'inbox_screen.dart';
import 'account_screen.dart';
import 'leave_request_screen.dart';
import 'attendance_correction_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _currentSavedPhoto;

  final List<Widget> _screens = const [
    HomeScreen(),
    EmployeesScreen(),
    SizedBox.shrink(), // Center tab placeholder for modal popup trigger
    InboxScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
    ApiService.refreshInboxCount();
  }

  Future<void> _loadSavedPhoto() async {
    try {
      final profile = await ApiService.getMe();
      final userEmail = profile['email'] ?? '';
      final photo = await ApiService.getProfilePhoto(userEmail);
      if (mounted) {
        setState(() {
          _currentSavedPhoto = photo;
        });
      }
    } catch (_) {
      final photo = await ApiService.getProfilePhoto();
      if (mounted) {
        setState(() {
          _currentSavedPhoto = photo;
        });
      }
    }
  }

  Widget _buildBadgeIcon({required Widget child, required int count}) {
    if (count <= 0) return child;

    final badgeText = count > 99 ? '99+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountAvatarIcon(String? photoStr, {required bool isSelected}) {
    if (photoStr != null && photoStr.isNotEmpty) {
      ImageProvider? imageProvider;
      if (photoStr.startsWith('data:image')) {
        final base64Str = photoStr.split(',').last;
        imageProvider = MemoryImage(base64Decode(base64Str));
      } else if (kIsWeb || photoStr.startsWith('http') || photoStr.startsWith('blob:')) {
        imageProvider = NetworkImage(photoStr);
      } else {
        imageProvider = FileImage(File(photoStr));
      }

      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
            width: 2,
          ),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Icon(
      Icons.person_rounded,
      color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
    );
  }

  void _showRequestModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Submit Application & Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the type of request you would like to submit:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),

                  // Request Leave Option Card
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.beach_access_rounded, color: Color(0xFFDC2626), size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request Leave',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Apply for annual leave, sick leave, or special leave',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pending Attendance / Correction Request Option Card
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceCorrectionScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFFD97706), size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Attendance',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Correction for forgotten check-in or signal issue',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex == 2 ? 0 : _currentIndex),
          index: _currentIndex == 2 ? 0 : _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
              _showRequestModal(context);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFDC2626),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: 'Employees',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
              label: 'Request',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<int>(
                valueListenable: ApiService.inboxBadgeNotifier,
                builder: (context, count, _) {
                  return _buildBadgeIcon(
                    child: const Icon(Icons.inbox_rounded),
                    count: count,
                  );
                },
              ),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<String?>(
                valueListenable: ApiService.profilePhotoNotifier,
                builder: (context, notifierPhoto, _) {
                  final photo = (notifierPhoto != null && notifierPhoto.isNotEmpty)
                      ? notifierPhoto
                      : _currentSavedPhoto;
                  return _buildAccountAvatarIcon(photo, isSelected: _currentIndex == 4);
                },
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
