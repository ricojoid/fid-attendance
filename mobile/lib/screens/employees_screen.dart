import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_cache.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/badge_medal.dart';
import '../widgets/motion.dart';
import '../widgets/streak_flame.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _all = [];
  String _query = '';
  bool _isLoading = true;
  String? _error;
  String _myEmail = '';
  DateTime? _lastFetch;
  bool _wasVisible = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ApiService.teamChangedNotifier.addListener(_fetchEmployees);
    _fetchEmployees();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab lives in an IndexedStack; TickerMode tells us when it becomes
    // visible again. Refetch then (throttled) so photos/badges are fresh.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      final stale = _lastFetch == null || DateTime.now().difference(_lastFetch!) > const Duration(seconds: 30);
      if (stale && !_isLoading) _fetchEmployees();
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    ApiService.teamChangedNotifier.removeListener(_fetchEmployees);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    if (_all.isEmpty && mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([ApiService.getAllUsers(), ApiService.getMe()]);
      final users = (results[0] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      final me = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _all = users;
        _myEmail = (me['email'] ?? '').toString().toLowerCase();
        _error = users.isEmpty ? 'No employees found' : null;
        _lastFetch = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the team. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((emp) {
      return [emp['name'], emp['nip'], emp['department']].any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  /// The signed-in user's own photo comes from the live notifier (instant
  /// after changing it); everyone else's from the server.
  String? _photoFor(Map<String, dynamic> emp, String? myLivePhoto) {
    final email = (emp['email'] ?? '').toString().toLowerCase();
    if (email.isNotEmpty && email == _myEmail && myLivePhoto != null && myLivePhoto.isNotEmpty) return myLivePhoto;
    final url = (emp['avatar_url'] ?? '').toString();
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.red,
          onRefresh: _fetchEmployees,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Team', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                          const SizedBox(width: 10),
                          if (!_isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(20)),
                              child: Text('${_all.length}',
                                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Your colleagues and the badges they earned',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search name, NIP or department',
                          prefixIcon: const Icon(Icons.search_rounded),
                          fillColor: AppColors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading && _all.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const Shimmer(height: 78, radius: 20),
                  ),
                )
              else if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_2_rounded, size: 48, color: AppColors.textFaint),
                        const SizedBox(height: 8),
                        Text(_error ?? 'No one matches "$_query"', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ValueListenableBuilder<String?>(
                  valueListenable: ApiService.profilePhotoNotifier,
                  builder: (context, myPhoto, _) => SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final emp = list[i];
                        return FadeSlideIn.stagger(
                          i.clamp(0, 10),
                          stepMs: 40,
                          child: _EmployeeTile(
                            emp: emp,
                            photo: _photoFor(emp, myPhoto),
                            isMe: (emp['email'] ?? '').toString().toLowerCase() == _myEmail,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Map<String, dynamic> emp;
  final String? photo;
  final bool isMe;
  const _EmployeeTile({required this.emp, required this.photo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = (emp['name'] ?? 'Unknown').toString();
    final dept = (emp['department'] ?? 'General').toString();
    final role = (emp['role'] ?? 'EMPLOYEE').toString();
    final top = AppBadge.fromTop(emp['top_badge']);
    final count = (emp['top_badge'] is Map ? (emp['top_badge']['count'] as num?)?.toInt() : 0) ?? 0;
    final img = AvatarCache.provider(photo, cacheWidth: 160);

    return Pressable(
      pressedScale: 0.98,
      onTap: () => _showProfile(context, img, top),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isMe ? AppColors.red.withValues(alpha: 0.3) : AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: Center(
                child: FramedAvatar(
                  frame: (emp['avatar_frame'] ?? '').toString(),
                  photo: photo,
                  name: name,
                  size: 50,
                  animate: false, // keep long lists cheap
                  fallbackColor: _roleColor(role),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      // The user's best badge sits right next to their name.
                      if (top != null) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: '${top.name}${count > 1 ? ' +${count - 1} more' : ''}',
                          child: BadgeMedal(badge: top, size: 26, showProgress: false),
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Text('You', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(dept,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            _RoleChip(role: role),
          ],
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, ImageProvider? img, AppBadge? top) {
    final name = (emp['name'] ?? 'Unknown').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            FramedAvatar(
              frame: (emp['avatar_frame'] ?? '').toString(),
              photo: photo,
              name: name,
              size: 88,
              fallbackColor: _roleColor((emp['role'] ?? '').toString()),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            Text('${emp['department'] ?? ''} · ${emp['nip'] ?? ''}', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 18),
            FutureBuilder<BadgeSummary?>(
              future: ApiService.getUserBadges(emp['id']),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Shimmer(height: 110, radius: 20);
                final s = snap.data;
                if (s == null) return const SizedBox.shrink();
                final earned = s.badges.where((b) => b.earned).toList();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: AppGradients.ink, borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StreakFlame(size: 22, lit: s.stats.currentStreak > 0),
                          const SizedBox(width: 6),
                          Text('${s.stats.currentStreak} day streak',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('${s.stats.overtimeDays} OT days',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (earned.isEmpty)
                        const Text('No badges yet', style: TextStyle(color: Colors.white60))
                      else
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: earned.map((b) => BadgeMedal(badge: b, size: 62, showProgress: false)).toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'SUPER_ADMIN':
      return const Color(0xFF7C3AED);
    case 'COUNTRY_HEAD':
      return const Color(0xFFD97706);
    case 'MANAGER':
      return const Color(0xFF4F46E5);
    case 'DEPARTMENT_HEAD':
      return const Color(0xFF0EA5E9);
    default:
      return AppColors.red;
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final label = const {
          'DEPARTMENT_HEAD': 'Dept Head',
          'MANAGER': 'Manager',
          'COUNTRY_HEAD': 'Country Head',
          'SUPER_ADMIN': 'Admin',
        }[role] ??
        'Staff';
    final c = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}
