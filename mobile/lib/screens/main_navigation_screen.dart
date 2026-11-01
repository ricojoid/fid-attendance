import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/live_events.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_cache.dart';
import '../widgets/motion.dart';
import 'home_screen.dart';
import 'employees_screen.dart';
import 'timeline_screen.dart';
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
    TimelineScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
    ApiService.refreshInboxCount();
    LiveEvents.start(); // live announcements while signed in
  }

  @override
  void dispose() {
    super.dispose();
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

  Widget _buildAccountAvatarIcon(String? photoStr, {required bool isSelected}) {
    final img = AvatarCache.provider(photoStr, cacheWidth: 96);
    if (img != null) {
      return AnimatedContainer(
        duration: AppMotion.medium,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? AppColors.red : Colors.transparent, width: 2),
          image: DecorationImage(image: img, fit: BoxFit.cover),
        ),
      );
    }
    return Icon(
      isSelected ? Icons.person_rounded : Icons.person_outline_rounded,
      color: isSelected ? AppColors.red : AppColors.textFaint,
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
            decoration: BoxDecoration(color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Submit Application & Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the type of request you would like to submit:',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.redSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.beach_access_rounded, color: AppColors.red, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Request Leave',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Apply for annual leave, sick leave, or special leave',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textFaint),
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
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Attendance',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Correction for forgotten check-in or signal issue',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textFaint),
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: false,
      body: AnimatedIndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset : 14),
        child: _FloatingNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
              _showRequestModal(context);
            } else if (index != _currentIndex) {
              setState(() => _currentIndex = index);
            }
          },
          inboxIcon: Icon(
            _currentIndex == 3 ? Icons.dynamic_feed_rounded : Icons.dynamic_feed_outlined,
            color: _currentIndex == 3 ? AppColors.red : AppColors.textFaint,
          ),
          accountIcon: ValueListenableBuilder<String?>(
            valueListenable: ApiService.profilePhotoNotifier,
            builder: (context, notifierPhoto, _) {
              final photo = (notifierPhoto != null && notifierPhoto.isNotEmpty) ? notifierPhoto : _currentSavedPhoto;
              return _buildAccountAvatarIcon(photo, isSelected: _currentIndex == 4);
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget inboxIcon;
  final Widget accountIcon;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.inboxIcon,
    required this.accountIcon,
  });

  static const _labels = ['Home', 'Team', '', 'Feed', 'Account'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: AppColors.text.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / 5;
          final showPill = currentIndex != 2;
          return Stack(
            children: [
              // Sliding selection pill.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: AppMotion.emphasized,
                left: slot * currentIndex + 8,
                top: 9,
                width: slot - 16,
                height: 52,
                child: AnimatedOpacity(
                  opacity: showPill ? 1 : 0,
                  duration: AppMotion.fast,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  if (i == 2) {
                    return SizedBox(
                      width: slot,
                      child: Center(
                        child: Pressable(
                          pressedScale: 0.88,
                          onTap: () => onTap(2),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppGradients.brand,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppShadows.glow(AppColors.red, strength: 0.4),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    );
                  }
                  final selected = currentIndex == i;
                  Widget icon;
                  if (i == 3) {
                    icon = inboxIcon;
                  } else if (i == 4) {
                    icon = accountIcon;
                  } else {
                    icon = Icon(
                      i == 0 ? (selected ? Icons.home_rounded : Icons.home_outlined) : (selected ? Icons.people_alt_rounded : Icons.people_alt_outlined),
                      color: selected ? AppColors.red : AppColors.textFaint,
                    );
                  }
                  return SizedBox(
                    width: slot,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.12 : 1.0,
                            duration: AppMotion.medium,
                            curve: Curves.easeOutBack,
                            child: icon,
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: AppMotion.medium,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                              color: selected ? AppColors.red : AppColors.textFaint,
                            ),
                            child: Text(_labels[i]),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// IndexedStack that keeps tab state, cross-fades on switch, and — crucially
/// for performance — disables tickers (animations, live clock) on hidden tabs.
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration, value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  Animation<Offset> _slide = const AlwaysStoppedAnimation(Offset.zero);
  late int _currentIndex = widget.index;
  // Tabs are built lazily the first time they are opened (faster start-up).
  late final Set<int> _visited = {widget.index};

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      final forward = widget.index > _currentIndex;
      _currentIndex = widget.index;
      _visited.add(_currentIndex);
      _slide = Tween<Offset>(begin: Offset(forward ? 0.04 : -0.04, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _controller, curve: AppMotion.emphasized));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              TickerMode(
                enabled: i == _currentIndex,
                child: _visited.contains(i) ? widget.children[i] : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
