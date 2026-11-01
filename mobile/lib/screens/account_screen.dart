import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../models/badge.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_medal.dart';
import '../widgets/motion.dart';
import '../widgets/streak_flame.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/frame_picker.dart';
import 'badges_screen.dart';
import 'settings_screen.dart';
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

  @override
  void initState() {
    super.initState();
    ApiService.profilePhotoNotifier.addListener(_onPhoto);
    _fetchProfile();
  }

  @override
  void dispose() {
    ApiService.profilePhotoNotifier.removeListener(_onPhoto);
    super.dispose();
  }

  void _onPhoto() {
    final v = ApiService.profilePhotoNotifier.value;
    if (mounted && v != null && v.isNotEmpty && v != _profilePhotoPath) setState(() => _profilePhotoPath = v);
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([ApiService.getMe(), ApiService.getMyBadges()]);
      final profile = results[0] as Map<String, dynamic>;
      final userEmail = (profile['email'] ?? '').toString();
      final serverPhoto = (profile['avatar_url'] ?? '').toString();
      final savedPhoto = serverPhoto.isNotEmpty ? serverPhoto : await ApiService.getProfilePhoto(userEmail);

      await _loadApprovalMapping(profile);

      setState(() {
        _userProfile = profile;
        _profilePhotoPath = savedPhoto;
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApprovalMapping(Map<String, dynamic>? profile) async {
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
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'approver_name': approverName}),
        );
        debugPrint('Synced approver_name "$approverName" to DB.');
      }
    } catch (e) {
      debugPrint('Failed to sync approver_name to DB: $e');
    }
  }



  Future<void> _pickProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            Text('Change Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: AppColors.red),
              title: const Text('Take a Photo / Selfie'),
              onTap: () async {
                Navigator.pop(ctx);
                await _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppColors.red),
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
      final XFile? image = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 400, maxHeight: 400);
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        final userEmail = _userProfile?['email'] ?? '';
        try {
          await ApiService.saveProfilePhoto(base64String, userEmail);
          if (!mounted) return;
          setState(() => _profilePhotoPath = base64String);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated for everyone ✨'), backgroundColor: Color(0xFF10B981)),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not upload the photo. Check your connection and try again.'),
              backgroundColor: AppColors.red,
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('My Account', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Settings & themes',
            icon: Icon(Icons.palette_rounded, color: AppColors.red),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(photo: _profilePhotoPath, name: (_userProfile?['name'] ?? '').toString()),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Top Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        // Avatar with Camera Edit Badge
                        GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: Stack(
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: ApiService.frameNotifier,
                                builder: (context, frame, _) => SizedBox(
                                  width: 112,
                                  height: 112,
                                  child: Center(child: FramedAvatar(frame: frame, photo: _profilePhotoPath, name: name, size: 84)),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.red,
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
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        _buildRoleBadge(role),
                        const SizedBox(height: 14),
                        Pressable(
                          onTap: () => showFramePicker(context, photo: _profilePhotoPath, name: name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFD34D), Color(0xFFFF7A1A)]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppShadows.glow(const Color(0xFFFF7A1A), strength: 0.3),
                            ),
                            child: const Text('✨ Avatar frames', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(delay: const Duration(milliseconds: 80), child: _BadgeShowcase()),
                  const SizedBox(height: 16),

                  // Personal Info List Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                        const SizedBox(height: 16),

                        _buildInfoRow(Icons.badge_rounded, 'Employee NIP', nip),
                        Divider(height: 24, color: AppColors.line),

                        _buildInfoRow(Icons.person_rounded, 'Full Name', name),
                        Divider(height: 24, color: AppColors.line),

                        _buildInfoRow(Icons.email_rounded, 'Email Address', email),
                        Divider(height: 24, color: AppColors.line),

                        _buildInfoRow(Icons.cake_rounded, 'Date of Birth', birthDate.isNotEmpty ? birthDate : 'Not Set'),
                        Divider(height: 24, color: AppColors.line),

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
                        backgroundColor: AppColors.red,
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
    Color bg = AppColors.redSoft;
    Color text = AppColors.red;

    if (roleStr == 'DEPARTMENT_HEAD') {
      label = 'Department Head';
      bg = AppColors.redSoft;
      text = AppColors.red;
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textFaint, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BadgeSummary>(
      valueListenable: ApiService.badgesNotifier,
      builder: (context, s, _) {
        final earned = s.badges.where((b) => b.earned).toList();
        return Pressable(
          pressedScale: 0.98,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: AppGradients.ink,
              boxShadow: AppShadows.glow(AppColors.ink, strength: 0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('My Badges', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    StreakFlame(size: 18, lit: s.stats.currentStreak > 0 && s.stats.streakAliveToday),
                    const SizedBox(width: 4),
                    Text('${s.stats.currentStreak} day streak',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                if (earned.isEmpty)
                  Text(
                    'No badges yet — check in 7 weekdays in a row to unlock Week Warrior.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
                  )
                else
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: earned.map((b) => BadgeMedal(badge: b, size: 64, showProgress: false)).toList(),
                  ),
                const SizedBox(height: 10),
                Text('${s.earnedCount} of ${s.badges.isEmpty ? 8 : s.badges.length} unlocked · tap to view all',
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}
