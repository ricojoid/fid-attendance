import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<dynamic> _allEmployees = [];
  List<dynamic> _filteredEmployees = [];
  bool _isLoading = true;
  String? _currentSavedPhoto;
  Map<String, dynamic>? _currentUserProfile;
  Map<String, String> _localPhotosMap = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ApiService.profilePhotoNotifier.addListener(_onPhotoChanged);
    _fetchEmployees();
  }

  @override
  void dispose() {
    ApiService.profilePhotoNotifier.removeListener(_onPhotoChanged);
    super.dispose();
  }

  void _onPhotoChanged() {
    if (mounted) {
      setState(() {
        _currentSavedPhoto = ApiService.profilePhotoNotifier.value;
      });
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllUsers();
      String? photo;
      try {
        final me = await ApiService.getMe();
        _currentUserProfile = me;
        photo = await ApiService.getProfilePhoto(me['email']);
      } catch (_) {
        photo = await ApiService.getProfilePhoto();
      }

      Map<String, String> localMap = {};
      try {
        final prefs = await SharedPreferences.getInstance();
        if (data is List) {
          for (var emp in data) {
            if (emp is Map) {
              final email = (emp['email'] ?? '').toString().toLowerCase().trim();
              if (email.isNotEmpty) {
                final p = prefs.getString('profile_photo_$email');
                if (p != null && p.isNotEmpty) {
                  localMap[email] = p;
                }
              }
            }
          }
        }
      } catch (_) {}

      setState(() {
        _allEmployees = data;
        _filteredEmployees = data;
        _currentSavedPhoto = photo;
        _localPhotosMap = localMap;
      });
    } catch (e) {
      final photo = await ApiService.getProfilePhoto();
      try {
        final me = await ApiService.getMe();
        _currentUserProfile = me;
      } catch (_) {}

      // Fallback mock employees if non-admin token
      setState(() {
        _currentSavedPhoto = photo;
        _allEmployees = [
          {
            'id': 1,
            'nip': 'ADM001',
            'name': 'Super Administrator',
            'email': 'admin@office.com',
            'department': 'IT & Systems',
            'role': 'SUPER_ADMIN',
          },
          {
            'id': 2,
            'nip': 'DIR001',
            'name': 'Bambang Sudiro',
            'email': 'bambang@office.com',
            'department': 'Executive Management',
            'role': 'COUNTRY_HEAD',
          },
          {
            'id': 3,
            'nip': 'MGR001',
            'name': 'Siti Rahma',
            'email': 'siti@office.com',
            'department': 'Finance & Operations',
            'role': 'MANAGER',
          },
          {
            'id': 4,
            'nip': 'DHD001',
            'name': 'Ahmad Fauzi',
            'email': 'ahmad@office.com',
            'department': 'Plant 2 Production',
            'role': 'DEPARTMENT_HEAD',
          },
          {
            'id': 5,
            'nip': 'EMP001',
            'name': 'Budi Santoso',
            'email': 'employee@office.com',
            'department': 'Human Resources',
            'role': 'EMPLOYEE',
          },
          {
            'id': 6,
            'nip': 'EMP002',
            'name': 'Dewi Lestari',
            'email': 'dewi@office.com',
            'department': 'Engineering & IT',
            'role': 'EMPLOYEE',
          },
        ];
        _filteredEmployees = _allEmployees;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterEmployees(String query) {
    if (query.isEmpty) {
      setState(() => _filteredEmployees = _allEmployees);
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredEmployees = _allEmployees.where((emp) {
          final name = (emp['name'] ?? '').toString().toLowerCase();
          final nip = (emp['nip'] ?? '').toString().toLowerCase();
          final dept = (emp['department'] ?? '').toString().toLowerCase();
          return name.contains(q) || nip.contains(q) || dept.contains(q);
        }).toList();
      });
    }
  }

  ImageProvider? _getEmployeeAvatar(dynamic emp, String? savedPhoto) {
    if (emp is! Map) return null;

    String? photoStr;
    for (var k in ['avatar_url', 'photo', 'avatar']) {
      final val = emp[k]?.toString().trim();
      if (val != null && val.isNotEmpty) {
        photoStr = val;
        break;
      }
    }

    final empEmail = (emp['email'] ?? '').toString().toLowerCase().trim();
    final currentEmail = (_currentUserProfile?['email'] ?? '').toString().toLowerCase().trim();

    if ((photoStr == null || photoStr.isEmpty) && empEmail.isNotEmpty) {
      if (empEmail == currentEmail && savedPhoto != null && savedPhoto.isNotEmpty) {
        photoStr = savedPhoto;
      } else if (_localPhotosMap[empEmail] != null && _localPhotosMap[empEmail]!.isNotEmpty) {
        photoStr = _localPhotosMap[empEmail];
      }
    }

    if (photoStr == null || photoStr.isEmpty) {
      return null;
    }

    try {
      if (photoStr.startsWith('data:image')) {
        final base64Str = photoStr.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } else if (kIsWeb || photoStr.startsWith('http') || photoStr.startsWith('blob:')) {
        return NetworkImage(photoStr);
      } else {
        return FileImage(File(photoStr));
      }
    } catch (e) {
      debugPrint('Error decoding avatar: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Employees Directory', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: _filterEmployees,
                decoration: InputDecoration(
                  hintText: 'Search by name, NIP, or department...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Employee List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEmployees.isEmpty
                        ? const Center(
                            child: Text(
                              'No employees found',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ValueListenableBuilder<String?>(
                            valueListenable: ApiService.profilePhotoNotifier,
                            builder: (context, latestPhoto, _) {
                              final effectiveSavedPhoto = (latestPhoto != null && latestPhoto.isNotEmpty)
                                  ? latestPhoto
                                  : _currentSavedPhoto;
                              return RefreshIndicator(
                                onRefresh: _fetchEmployees,
                                child: ListView.separated(
                                  itemCount: _filteredEmployees.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = _filteredEmployees[index];
                                    if (item is! Map) return const SizedBox.shrink();
                                    final emp = item;
                                    final name = (emp['name'] ?? 'Unknown').toString();
                                    final nip = (emp['nip'] ?? '-').toString();
                                    final email = (emp['email'] ?? '-').toString();
                                    final dept = (emp['department'] ?? 'General').toString();
                                    final role = (emp['role'] ?? 'EMPLOYEE').toString();

                                    final isSuperAdmin = role == 'SUPER_ADMIN';
                                    final avatarImg = _getEmployeeAvatar(emp, effectiveSavedPhoto);

                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: isSuperAdmin ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                                            backgroundImage: avatarImg,
                                            child: avatarImg == null
                                                ? Text(
                                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                     _buildRoleChip(role),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'NIP: $nip  •  $dept',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  email,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    String label = 'Staff';
    Color bg = const Color(0xFFEFF6FF);
    Color text = const Color(0xFF2563EB);

    if (role == 'DEPARTMENT_HEAD') {
      label = 'Dept Head';
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF2563EB);
    } else if (role == 'MANAGER') {
      label = 'Manager';
      bg = const Color(0xFFF3E8FF);
      text = const Color(0xFF7C3AED);
    } else if (role == 'COUNTRY_HEAD') {
      label = 'Country Head';
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
    } else if (role == 'SUPER_ADMIN') {
      label = 'Admin';
      bg = const Color(0xFFFCE7F3);
      text = const Color(0xFFDB2777);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
