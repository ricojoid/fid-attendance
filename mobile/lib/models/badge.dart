/// Mirrors the backend `/badges/me` payload.
class AppBadge {
  final String code;
  final String name;
  final String description;
  final String category; // STREAK, OVERTIME
  final int tier; // 1..4
  final int target;
  final String unit;
  final bool earned;
  final DateTime? earnedAt;
  final int progress;
  final double percent;
  final bool isNew;
  final String rewardFrame;

  const AppBadge({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    required this.target,
    required this.unit,
    required this.earned,
    required this.earnedAt,
    required this.progress,
    required this.percent,
    required this.isNew,
    this.rewardFrame = '',
  });

  bool get isStreak => category == 'STREAK';

  /// Short label stamped on the medal ("7D", "1M", "20"...).
  String get shortLabel {
    switch (code) {
      case 'STREAK_7D':
        return '7D';
      case 'STREAK_1M':
        return '1M';
      case 'STREAK_6M':
        return '6M';
      case 'STREAK_1Y':
        return '1Y';
    }
    return '$target';
  }

  String get tierName => const ['Bronze', 'Silver', 'Gold', 'Legendary'][(tier - 1).clamp(0, 3)];

  int get remaining => (target - progress).clamp(0, target);

  /// Builds a display-only badge from the compact `top_badge` list payload.
  static AppBadge? fromTop(dynamic j) {
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    if ((m['code'] ?? '').toString().isEmpty) return null;
    return AppBadge(
      code: m['code'].toString(),
      name: (m['name'] ?? '').toString(),
      description: '',
      category: (m['category'] ?? '').toString(),
      tier: (m['tier'] as num?)?.toInt() ?? 1,
      target: (m['target'] as num?)?.toInt() ?? 1,
      unit: '',
      earned: true,
      earnedAt: null,
      progress: 1,
      percent: 1,
      isNew: false,
    );
  }

  factory AppBadge.fromJson(Map<String, dynamic> j) => AppBadge(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        tier: (j['tier'] as num?)?.toInt() ?? 1,
        target: (j['target'] as num?)?.toInt() ?? 1,
        unit: (j['unit'] ?? '').toString(),
        earned: j['earned'] == true,
        earnedAt: DateTime.tryParse((j['earned_at'] ?? '').toString())?.toLocal(),
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        percent: ((j['percent'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        isNew: j['is_new'] == true,
        rewardFrame: (j['reward_frame'] ?? '').toString(),
      );
}

class BadgeStats {
  final int currentStreak;
  final int longestStreak;
  final bool streakAliveToday;
  final int totalPresentDays;
  final int overtimeDays;
  final int overtimeMinutes;
  final int overtimeDaysThisMonth;
  final int effectiveWorkMinutes;

  const BadgeStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.streakAliveToday = true,
    this.totalPresentDays = 0,
    this.overtimeDays = 0,
    this.overtimeMinutes = 0,
    this.overtimeDaysThisMonth = 0,
    this.effectiveWorkMinutes = 0,
  });

  factory BadgeStats.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return BadgeStats(
      currentStreak: i('current_streak'),
      longestStreak: i('longest_streak'),
      streakAliveToday: j['streak_alive_today'] != false,
      totalPresentDays: i('total_present_days'),
      overtimeDays: i('overtime_days'),
      overtimeMinutes: i('overtime_minutes'),
      overtimeDaysThisMonth: i('overtime_days_this_month'),
      effectiveWorkMinutes: i('effective_work_minutes'),
    );
  }
}

class BadgeSummary {
  final BadgeStats stats;
  final List<AppBadge> badges;
  final List<AppBadge> newlyUnlocked;
  final int earnedCount;
  final String featured; // badge code chosen to show next to the name ('' = auto)

  const BadgeSummary({
    this.stats = const BadgeStats(),
    this.badges = const [],
    this.newlyUnlocked = const [],
    this.earnedCount = 0,
    this.featured = '',
  });

  static const empty = BadgeSummary();

  bool get isEmpty => badges.isEmpty;

  List<AppBadge> byCategory(String c) => badges.where((b) => b.category == c).toList();

  AppBadge? nextFor(String c) {
    for (final b in badges) {
      if (b.category == c && !b.earned) return b;
    }
    return null;
  }

  factory BadgeSummary.fromJson(Map<String, dynamic> j) {
    List<AppBadge> list(dynamic v) =>
        (v is List ? v : const []).whereType<Map>().map((e) => AppBadge.fromJson(e.cast<String, dynamic>())).toList();
    final badges = list(j['badges']);
    return BadgeSummary(
      stats: j['stats'] is Map ? BadgeStats.fromJson((j['stats'] as Map).cast<String, dynamic>()) : const BadgeStats(),
      badges: badges,
      newlyUnlocked: list(j['newly_unlocked']),
      earnedCount: (j['earned_count'] as num?)?.toInt() ?? badges.where((b) => b.earned).length,
      featured: (j['featured'] ?? '').toString(),
    );
  }
}
