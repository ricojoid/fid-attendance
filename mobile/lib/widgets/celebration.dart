import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'avatar_frame.dart';
import 'badge_medal.dart';
import 'motion.dart';

/// One-shot confetti burst. Particles are precomputed once; each frame is a
/// single CustomPaint pass inside its own RepaintBoundary.
class ConfettiBurst extends StatefulWidget {
  final int count;
  final Duration duration;
  final List<Color>? colors;

  const ConfettiBurst({
    super.key,
    this.count = 90,
    this.duration = const Duration(milliseconds: 2600),
    this.colors,
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  final double angle, speed, spin, size, drift;
  final Color color;
  final bool ribbon;
  _Particle(this.angle, this.speed, this.spin, this.size, this.drift, this.color, this.ribbon);
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Particle> _particles;
  late final List<Color> _palette;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _palette = widget.colors ??
        [AppColors.red, AppColors.amber, const Color(0xFF34D399), const Color(0xFF38BDF8), AppColors.overtime, AppColors.magenta];
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.25,
        0.55 + rnd.nextDouble() * 0.75,
        (rnd.nextDouble() - 0.5) * 14,
        4 + rnd.nextDouble() * 6,
        (rnd.nextDouble() - 0.5) * 0.3,
        _palette[i % _palette.length],
        rnd.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ConfettiPainter(_c, _particles), size: Size.infinite),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> a;
  final List<_Particle> ps;
  const _ConfettiPainter(this.a, this.ps) : super(repaint: a);

  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value;
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final reach = size.height * 0.75;
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    final paint = Paint();
    for (final p in ps) {
      final d = reach * p.speed * Curves.easeOutCubic.transform(t);
      final gravity = size.height * 0.55 * t * t;
      final pos = origin +
          Offset(math.cos(p.angle) * d + p.drift * size.width * t, math.sin(p.angle) * d + gravity);
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.ribbon) {
        // Flip to fake 3D tumbling.
        final w = p.size * (0.4 + 0.6 * math.cos(p.spin * t * 2).abs());
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: p.size * 1.8), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

/// Full-screen celebration for newly unlocked badges. Shows them one by one.
Future<void> showBadgeUnlocked(BuildContext context, List<AppBadge> badges) async {
  if (badges.isEmpty) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Badge unlocked',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => _UnlockSequence(badges: badges),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: AppMotion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _UnlockSequence extends StatefulWidget {
  final List<AppBadge> badges;
  const _UnlockSequence({required this.badges});

  @override
  State<_UnlockSequence> createState() => _UnlockSequenceState();
}

class _UnlockSequenceState extends State<_UnlockSequence> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < widget.badges.length - 1) {
      setState(() => _index++);
      _pop.forward(from: 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badges[_index];
    final accent = b.isStreak ? const Color(0xFFFF7A1A) : AppColors.overtime;
    final scale = CurvedAnimation(parent: _pop, curve: const Interval(0, 0.7, curve: Curves.elasticOut));
    final rays = CurvedAnimation(parent: _pop, curve: const Interval(0.1, 1, curve: Curves.easeOut));
    final isLast = _index == widget.badges.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(child: ConfettiBurst(key: ValueKey(_index))),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.badges.length > 1 ? 'BADGE UNLOCKED  ${_index + 1}/${widget.badges.length}' : 'BADGE UNLOCKED',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: rays,
                            builder: (context, _) => Transform.rotate(
                              angle: rays.value * math.pi / 3,
                              child: Opacity(
                                opacity: rays.value,
                                child: CustomPaint(size: const Size.square(260), painter: _RaysPainter(accent)),
                              ),
                            ),
                          ),
                        ),
                        ScaleTransition(scale: scale, child: BadgeMedal(badge: b, size: 170, animate: true, showProgress: false)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    key: ValueKey('t$_index'),
                    delay: const Duration(milliseconds: 250),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '${b.tierName.toUpperCase()} · ${b.isStreak ? 'STREAK' : 'OVERTIME'}',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          b.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
                        ),
                        if (kFrameStyles.containsKey(b.rewardFrame)) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FramedAvatar(frame: b.rewardFrame, photo: ApiService.profilePhotoNotifier.value, name: '★', size: 34),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('REWARD UNLOCKED',
                                        style: TextStyle(color: Color(0xFFFFD34D), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                    Text('${b.rewardFrame.replaceAll('_', ' ')} avatar frame',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                      child: Text(isLast ? 'Awesome!' : 'Next badge'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Color color;
  const _RaysPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ray = Paint()..color = Colors.white.withValues(alpha: 0.08);
    const n = 12;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.09), c.dy + r * math.sin(a - 0.09))
        ..lineTo(c.dx + r * math.cos(a + 0.09), c.dy + r * math.sin(a + 0.09))
        ..close();
      canvas.drawPath(p, ray);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.color != color;
}
