import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/badge.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/badge_medal.dart';
import '../widgets/celebration.dart';
import '../widgets/motion.dart';
import '../widgets/streak_flame.dart';

/// Achievement hall: streak + overtime badges, progress and rules.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ApiService.badgesNotifier.value.isEmpty) setState(() => _loading = true);
    final summary = await ApiService.getMyBadges();
    if (!mounted) return;
    setState(() => _loading = false);
    if (summary.newlyUnlocked.isNotEmpty) {
      await showBadgeUnlocked(context, summary.newlyUnlocked);
      await ApiService.markBadgesSeen(summary.newlyUnlocked.map((b) => b.code).toList());
      ApiService.getMyBadges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ValueListenableBuilder<BadgeSummary>(
        valueListenable: ApiService.badgesNotifier,
        builder: (context, summary, _) {
          return RefreshIndicator(
            onRefresh: _load,
            edgeOffset: 120,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _Hero(summary: summary)),
                if (_loading && summary.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList.separated(
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, __) => const Shimmer(height: 120),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FadeSlideIn.stagger(0,
                                child: _NextGoalCard(badge: summary.nextFor('STREAK'), streak: true, stats: summary.stats)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeSlideIn.stagger(1,
                                child: _NextGoalCard(badge: summary.nextFor('OVERTIME'), streak: false, stats: summary.stats)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _section('Streak Badges', 'Every live check-in counts — weekends never break it', summary.byCategory('STREAK'), 2),
                  _section('Overtime Badges', 'On site more than 9h (8h work + 1h break)', summary.byCategory('OVERTIME'), 6),
                  const SliverToBoxAdapter(child: _RulesCard()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, String subtitle, List<AppBadge> badges, int baseIndex) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 14),
              ],
            ),
          ),
          SliverGrid.builder(
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, i) => FadeSlideIn.stagger(
              baseIndex + i,
              child: _BadgeTile(badge: badges[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final BadgeSummary summary;
  const _Hero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary.stats;
    final top = MediaQuery.paddingOf(context).top;
    final otHours = s.overtimeMinutes / 60;
    return AuroraBackground(
      colors: [const Color(0xFFFF7A1A), AppColors.red, AppColors.overtime],
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    '${summary.earnedCount}/${summary.badges.isEmpty ? 8 : summary.badges.length} unlocked',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Achievements',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Text('Consistency and extra effort, celebrated.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5)),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StreakFlame(size: 58, lit: s.currentStreak > 0 && s.streakAliveToday),
                const SizedBox(width: 12),
                AnimatedCount(
                  value: s.currentStreak,
                  style: const TextStyle(color: Colors.white, fontSize: 56, height: 0.95, fontWeight: FontWeight.w900, letterSpacing: -2),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('day streak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(
                        s.streakAliveToday ? 'Best: ${s.longestStreak} days' : 'Check in today to keep it!',
                        style: TextStyle(
                          color: s.streakAliveToday ? Colors.white70 : const Color(0xFFFFD34D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _HeroStat(label: 'Overtime days', value: '${s.overtimeDays}', icon: Icons.nightlight_round),
                _HeroStat(label: 'Overtime hours', value: otHours >= 10 ? otHours.toStringAsFixed(0) : otHours.toStringAsFixed(1), icon: Icons.timer_rounded),
                _HeroStat(label: 'Days present', value: '${s.totalPresentDays}', icon: Icons.event_available_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _NextGoalCard extends StatelessWidget {
  final AppBadge? badge;
  final bool streak;
  final BadgeStats stats;
  const _NextGoalCard({required this.badge, required this.streak, required this.stats});

  @override
  Widget build(BuildContext context) {
    final accent = streak ? const Color(0xFFFF7A1A) : AppColors.overtime;
    final b = badge;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(streak ? Icons.local_fire_department_rounded : Icons.nightlight_round, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(streak ? 'NEXT STREAK' : 'NEXT OVERTIME',
                  style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          Text(b?.name ?? 'All unlocked!',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(
            b == null ? 'You are a legend 🏆' : '${b.remaining} more ${streak ? 'weekdays' : 'overtime days'}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          _ProgressBar(value: b?.percent ?? 1, color: accent),
          const SizedBox(height: 6),
          Text(b == null ? '100%' : '${b.progress}/${b.target}',
              style: TextStyle(fontSize: 11, color: AppColors.textFaint, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: const Color(0xFFF1F3F8)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1100),
              curve: AppMotion.emphasized,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AppBadge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final b = badge;
    final accent = b.isStreak ? const Color(0xFFFF7A1A) : AppColors.overtime;
    return Pressable(
      onTap: () => showBadgeDetail(context, b),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: b.earned ? accent.withValues(alpha: 0.35) : AppColors.line),
          boxShadow: b.earned ? AppShadows.glow(accent, strength: 0.12) : AppShadows.soft,
          gradient: b.earned
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.withValues(alpha: 0.08), Colors.white],
                )
              : null,
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: Hero(tag: 'badge_${b.code}', child: BadgeMedal(badge: b, size: 100)))),
            const SizedBox(height: 8),
            Text(b.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 3),
            Text(
              b.earned
                  ? 'Earned ${b.earnedAt != null ? DateFormat('d MMM yyyy').format(b.earnedAt!) : ''}'
                  : '${b.progress}/${b.target} ${b.isStreak ? 'days' : 'OT days'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: b.earned ? accent : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showBadgeDetail(BuildContext context, AppBadge b) {
  final accent = b.isStreak ? const Color(0xFFFF7A1A) : AppColors.overtime;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 18),
          Hero(tag: 'badge_${b.code}', child: BadgeMedal(badge: b, size: 170, animate: true)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${b.tierName.toUpperCase()} · ${b.isStreak ? 'STREAK' : 'OVERTIME'}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          Text(b.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(b.description, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, height: 1.45)),
          const SizedBox(height: 20),
          if (b.earned) ...[
            _InfoPill(
              icon: Icons.verified_rounded,
              color: AppColors.success,
              text: b.earnedAt != null ? 'Unlocked on ${DateFormat('EEEE, d MMMM yyyy').format(b.earnedAt!)}' : 'Unlocked',
            ),
            const SizedBox(height: 12),
            _FeatureButton(badge: b),
          ]
          else ...[
            _ProgressBar(value: b.percent, color: accent),
            const SizedBox(height: 8),
            Text(
              '${b.progress} of ${b.target} ${b.unit} · ${b.remaining} to go',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted, fontSize: 12.5),
            ),
            if (b.isStreak) ...[
              const SizedBox(height: 12),
              const _InfoPill(
                icon: Icons.info_outline_rounded,
                color: AppColors.info,
                text: 'Missing a weekday (or covering it only with a correction request) resets the streak.',
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoPill({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, Color c, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(i, size: 16, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(body, style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How badges work', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 14),
            row(Icons.calendar_view_week_rounded, const Color(0xFFFF7A1A), 'Daily streaks',
                'Every live check-in adds 1 — even your very first day. Missing a weekday breaks the streak; weekends are optional (checking in adds, skipping never breaks). Days filled by a correction request do not count. 1 month = 22 days, 6 months = 130, 1 year = 260.'),
            row(Icons.schedule_rounded, AppColors.info, '9-hour working day',
                '8 hours of work + 1 hour break. Being on site 8h means 7h of actual work.'),
            row(Icons.nightlight_round, AppColors.overtime, 'Overtime',
                'A day counts as overtime when live check-out minus check-in is more than 9 hours. Times edited by a correction request are excluded.'),
          ],
        ),
      ),
    );
  }
}

/// "Show on my profile": the chosen badge appears next to your name in Team.
class _FeatureButton extends StatefulWidget {
  final AppBadge badge;
  const _FeatureButton({required this.badge});

  @override
  State<_FeatureButton> createState() => _FeatureButtonState();
}

class _FeatureButtonState extends State<_FeatureButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BadgeSummary>(
      valueListenable: ApiService.badgesNotifier,
      builder: (context, s, _) {
        final featured = s.featured == widget.badge.code;
        return SizedBox(
          width: double.infinity,
          child: Pressable(
            pressedScale: 0.97,
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ApiService.featureBadge(featured ? '' : widget.badge.code);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: AnimatedContainer(
              duration: AppMotion.medium,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: featured ? null : AppGradients.brand,
                color: featured ? AppColors.surfaceAlt : null,
                borderRadius: BorderRadius.circular(16),
                border: featured ? Border.all(color: AppColors.red) : null,
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        featured ? '✓ Shown next to your name · tap to unpin' : '📌 Show next to my name',
                        style: TextStyle(color: featured ? AppColors.red : Colors.white, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
