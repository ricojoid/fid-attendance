import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _userProfile;
  String? _profilePhotoPath;
  bool _isLoading = true;

  String _assignedApprover = '';
  List<Map<String, dynamic>> _registeredUsersFromDb = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ApiService.getMe();
      final userEmail = profile['email'] ?? '';
      final savedPhoto = await ApiService.getProfilePhoto(userEmail);

      // Fetch real registered users from backend DB
      final usersList = await ApiService.getAllUsers();
      List<Map<String, dynamic>> parsedUsers = [];

      if (usersList is List && usersList.isNotEmpty) {
        for (var u in usersList) {
          if (u is Map && u['email'] != userEmail) {
            parsedUsers.add({
              'id': u['id']?.toString() ?? '',
              'name': (u['name'] ?? 'User').toString(),
              'email': (u['email'] ?? '').toString(),
              'role': (u['role'] ?? 'EMPLOYEE').toString(),
              'dept': (u['department'] ?? 'General').toString(),
            });
          }
        }
      }

      await _loadApprovalMapping(profile, parsedUsers);

      setState(() {
        _userProfile = profile;
        _profilePhotoPath = savedPhoto;
        _registeredUsersFromDb = parsedUsers;
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApprovalMapping(Map<String, dynamic>? profile, List<Map<String, dynamic>> usersFromDb) async {
    // 1. DB is the source of truth — read approver_name from backend profile
    if (profile != null && profile['approver_name'] != null && profile['approver_name'].toString().isNotEmpty) {
      _assignedApprover = profile['approver_name'].toString();
      return;
    }

    // 2. Fallback: check SharedPreferences for locally saved approver
    final prefs = await SharedPreferences.getInstance();
    final email = (profile?['email'] ?? '').toString().toLowerCase().trim();
    final rawEmail = (profile?['email'] ?? '').toString();
    final nip = (profile?['nip'] ?? '').toString().toLowerCase().trim();
    final id = profile?['id']?.toString() ?? '';

    String? savedApprover;

    for (var k in [email, rawEmail, nip, id]) {
      if (k.isNotEmpty) {
        savedApprover ??= prefs.getString('assigned_approver_$k');
        if (savedApprover == null || savedApprover.isEmpty) {
          final mappingStr = prefs.getString('approval_mapping_$k');
          if (mappingStr != null && mappingStr.isNotEmpty) {
            try {
              final decoded = jsonDecode(mappingStr);
              if (decoded['approverName'] != null) {
                savedApprover = decoded['approverName'].toString();
              }
            } catch (_) {}
          }
        }
      }
    }

    if (savedApprover != null && savedApprover.isNotEmpty) {
      _assignedApprover = savedApprover;
      // DB was empty but SharedPrefs had a value — sync it to DB now
      await _syncApproverNameToDb(savedApprover);
    }
    // If still empty, leave _assignedApprover as-is (empty string)
    // — do NOT auto-assign; let the user pick via the mapping dialog
  }

  /// Syncs the approver_name value up to the backend DB (PUT /profile)
  Future<void> _syncApproverNameToDb(String approverName) async {
    try {
      final token = await ApiService.getToken();
      if (token != null && approverName.isNotEmpty) {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer \$token',
          },
          body: jsonEncode({'approver_name': approverName}),
        );
        debugPrint('Synced approver_name "$approverName" to DB.');
      }
    } catch (e) {
      debugPrint('Failed to sync approver_name to DB: \$e');
    }
  }



  Future<void> _pickProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            const Text('Change Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFDC2626)),
              title: const Text('Take a Photo / Selfie'),
              onTap: () async {
                Navigator.pop(ctx);
                await _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFDC2626)),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _getImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 500, maxHeight: 500);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
        final userEmail = _userProfile?['email'] ?? '';
        await ApiService.saveProfilePhoto(base64String, userEmail);
        setState(() {
          _profilePhotoPath = base64String;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated and saved permanently!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to pick profile photo: $e');
    }
  }

  void _handleLogout() async {
    await ApiService.removeToken();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile?['name'] ?? 'Employee User';
    final email = _userProfile?['email'] ?? 'employee@office.com';
    final nip = _userProfile?['nip'] ?? 'EMP001';
    final dept = _userProfile?['department'] ?? 'General';
    final role = _userProfile?['role'] ?? 'EMPLOYEE';
    final birthDate = (_userProfile?['birth_date'] ?? _userProfile?['birthDate'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Top Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Avatar with Camera Edit Badge
                        GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFFDC2626),
                                backgroundImage: _getProfileImageProvider(),
                                child: (_profilePhotoPath == null || _profilePhotoPath!.isEmpty)
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        _buildRoleBadge(role),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Info List Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 16),

                        _buildInfoRow(Icons.badge_rounded, 'Employee NIP', nip),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                        _buildInfoRow(Icons.person_rounded, 'Full Name', name),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                        _buildInfoRow(Icons.email_rounded, 'Email Address', email),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                        _buildInfoRow(Icons.cake_rounded, 'Date of Birth', birthDate.isNotEmpty ? birthDate : 'Not Set'),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                        _buildInfoRow(Icons.business_rounded, 'Department', dept),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      label: const Text(
                        'Sign Out / Logout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleBadge(String roleStr) {
    String label = roleStr;
    Color bg = const Color(0xFFFEE2E2);
    Color text = const Color(0xFFDC2626);

    if (roleStr == 'DEPARTMENT_HEAD') {
      label = 'Department Head';
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFDC2626);
    } else if (roleStr == 'MANAGER') {
      label = 'Manager';
      bg = const Color(0xFFF3E8FF);
      text = const Color(0xFF7C3AED);
    } else if (roleStr == 'COUNTRY_HEAD') {
      label = 'Country Head';
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
    } else if (roleStr == 'SUPER_ADMIN') {
      label = 'Super Admin';
      bg = const Color(0xFFFCE7F3);
      text = const Color(0xFFDB2777);
    } else {
      label = 'Employee';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  ImageProvider? _getProfileImageProvider() {
    if (_profilePhotoPath == null || _profilePhotoPath!.isEmpty) {
      return null;
    }
    if (_profilePhotoPath!.startsWith('data:image')) {
      final base64Str = _profilePhotoPath!.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    } else if (kIsWeb || _profilePhotoPath!.startsWith('http') || _profilePhotoPath!.startsWith('blob:')) {
      return NetworkImage(_profilePhotoPath!);
    } else {
      return FileImage(File(_profilePhotoPath!));
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
