import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_cache.dart';

/// Visual + motion spec for each avatar frame (mirrors the web dashboard).
class FrameStyle {
  final List<Color>? colors; // null = follow the active theme
  final double spin; // ring rotation period in seconds (0 = still)
  final String ornament;
  final Color? glow; // null = theme primary
  final String orbit; // particle kind ('' = none)
  final int orbitCount;
  final double orbitSecs;
  final Set<String> fx; // pulse, rays, zap, neon

  const FrameStyle({
    this.colors,
    this.spin = 8,
    this.ornament = '',
    this.glow,
    this.orbit = '',
    this.orbitCount = 0,
    this.orbitSecs = 8,
    this.fx = const {'pulse'},
  });
}

const Map<String, FrameStyle> kFrameStyles = {
  // Free starters
  'GLOW': FrameStyle(spin: 0),
  'BUBBLES': FrameStyle(
      colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF7DD3FC), Color(0xFFE0F2FE)],
      spin: 14, glow: Color(0xFF38BDF8), orbit: 'bubble', orbitCount: 6, orbitSecs: 9),
  'SUNNY': FrameStyle(
      colors: [Color(0xFFFEF08A), Color(0xFFFACC15), Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFFEF08A)],
      spin: 10, glow: Color(0xFFFACC15), fx: {'pulse', 'rays'}),
  // Achievements
  'EMBER': FrameStyle(
      colors: [Color(0xFFFFD34D), Color(0xFFFF7A1A), Color(0xFFE11D2E), Color(0xFFFF7A1A), Color(0xFFFFD34D)],
      spin: 12, ornament: 'flame', glow: Color(0xFFFF7A1A), orbit: 'ember', orbitCount: 3, orbitSecs: 7),
  'BLAZE': FrameStyle(
      colors: [Color(0xFFFFE08A), Color(0xFFFF7A1A), Color(0xFFE11D2E), Color(0xFF7A0010), Color(0xFFE11D2E), Color(0xFFFF7A1A), Color(0xFFFFE08A)],
      spin: 4, ornament: 'flames', glow: Color(0xFFFF5A1A), orbit: 'ember', orbitCount: 6, orbitSecs: 4),
  'INFERNO_CROWN': FrameStyle(
      colors: [Color(0xFFFFF1A8), Color(0xFFF5B70A), Color(0xFFFF7A1A), Color(0xFFE11D2E), Color(0xFFF5B70A), Color(0xFFFFF1A8)],
      spin: 6, ornament: 'crown', glow: Color(0xFFF5B70A), orbit: 'ember', orbitCount: 5, orbitSecs: 5),
  'PHOENIX': FrameStyle(
      colors: [Color(0xFFFF5A4E), Color(0xFFFFB020), Color(0xFFFFE08A), Color(0xFFFF7A1A), Color(0xFFD9268A), Color(0xFFFF5A4E)],
      spin: 4, ornament: 'wings', glow: Color(0xFFFF7A1A), orbit: 'spark', orbitCount: 8, orbitSecs: 5),
  'MOONLIGHT': FrameStyle(
      colors: [Color(0xFFF8FAFC), Color(0xFF93C5FD), Color(0xFF64748B), Color(0xFF93C5FD), Color(0xFFF8FAFC)],
      spin: 18, ornament: 'moon', glow: Color(0xFF93C5FD), orbit: 'spark', orbitCount: 3, orbitSecs: 10),
  'NIGHT_OWL': FrameStyle(
      colors: [Color(0xFFC4B5FD), Color(0xFF7C3AED), Color(0xFF1E1B4B), Color(0xFF7C3AED), Color(0xFFC4B5FD)],
      spin: 14, ornament: 'stars', glow: Color(0xFF7C3AED), orbit: 'star', orbitCount: 4, orbitSecs: 9),
  'GALAXY': FrameStyle(
      colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6), Color(0xFFD946EF), Color(0xFF1E1B4B), Color(0xFF38BDF8)],
      spin: 5, ornament: 'stars', glow: Color(0xFF8B5CF6), orbit: 'spark', orbitCount: 7, orbitSecs: 6),
  'ECLIPSE': FrameStyle(
      colors: [Color(0xFF111827), Color(0xFFFDE68A), Color(0xFF111827), Color(0xFFF59E0B), Color(0xFF111827)],
      spin: 5, ornament: 'corona', glow: Color(0xFFF59E0B), orbit: 'spark', orbitCount: 4, orbitSecs: 7),
  // Admin gifts
  'EMPLOYEE_OF_MONTH': FrameStyle(
      colors: [Color(0xFFFFF4B0), Color(0xFFF5B70A), Color(0xFF8F5A00), Color(0xFFF5B70A), Color(0xFFFFF4B0)],
      spin: 10, ornament: 'laurel', glow: Color(0xFFF5B70A), orbit: 'spark', orbitCount: 4, orbitSecs: 8),
  'RISING_STAR': FrameStyle(
      colors: [Color(0xFFFFD1E8), Color(0xFFFF6BB5), Color(0xFFFFD34D), Color(0xFFFF6BB5), Color(0xFFFFD1E8)],
      spin: 9, ornament: 'star', glow: Color(0xFFFF6BB5), orbit: 'star', orbitCount: 5, orbitSecs: 7),
  'TEAM_HERO': FrameStyle(
      colors: [Color(0xFFBFDBFE), Color(0xFF2563EB), Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFFBFDBFE)],
      spin: 10, ornament: 'shield', glow: Color(0xFF2563EB), orbit: 'spark', orbitCount: 3, orbitSecs: 8),
  'BIRTHDAY': FrameStyle(
      colors: [Color(0xFFF43F5E), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFA855F7), Color(0xFFF43F5E)],
      spin: 5, ornament: 'hat', glow: Color(0xFFF59E0B), orbit: 'confetti', orbitCount: 8, orbitSecs: 6),
  'FOUNDERS_CIRCLE': FrameStyle(
      colors: [Color(0xFFFFE08A), Color(0xFFE11D2E), Color(0xFF7A0010), Color(0xFFF5B70A), Color(0xFFE11D2E), Color(0xFFFFE08A)],
      spin: 5, ornament: 'crown', glow: Color(0xFFE11D2E), orbit: 'gem', orbitCount: 6, orbitSecs: 7),
  'CHERRY_BLOSSOM': FrameStyle(
      colors: [Color(0xFFFFE4EF), Color(0xFFF9A8D4), Color(0xFFEC4899), Color(0xFFF9A8D4), Color(0xFFFFE4EF)],
      spin: 12, glow: Color(0xFFF472B6), orbit: 'petal', orbitCount: 7, orbitSecs: 8),
  'NEON_PULSE': FrameStyle(
      colors: [Color(0xFF22D3EE), Color(0xFFA855F7), Color(0xFFF0ABFC), Color(0xFF22D3EE)], spin: 3, glow: Color(0xFF22D3EE), fx: {'pulse', 'neon'}),
  'SNOWFALL': FrameStyle(
      colors: [Color(0xFFF0F9FF), Color(0xFFBAE6FD), Color(0xFF7DD3FC), Color(0xFFBAE6FD), Color(0xFFF0F9FF)],
      spin: 16, glow: Color(0xFF7DD3FC), orbit: 'snow', orbitCount: 7, orbitSecs: 11),
  'LIGHTNING': FrameStyle(
      colors: [Color(0xFFFDE047), Color(0xFF38BDF8), Color(0xFF1E3A8A), Color(0xFF38BDF8), Color(0xFFFDE047)],
      spin: 3, glow: Color(0xFF38BDF8), fx: {'pulse', 'zap'}),
  'HEARTBEAT': FrameStyle(
      colors: [Color(0xFFFECDD3), Color(0xFFF43F5E), Color(0xFFBE123C), Color(0xFFF43F5E), Color(0xFFFECDD3)],
      spin: 10, ornament: 'heart', glow: Color(0xFFF43F5E), orbit: 'heart', orbitCount: 4, orbitSecs: 7),
  'DIAMOND': FrameStyle(
      colors: [Color(0xFF22D3EE), Color(0xFFFFFFFF), Color(0xFFA78BFA), Color(0xFFF472B6), Color(0xFFFFFFFF), Color(0xFFFACC15), Color(0xFF22D3EE)],
      spin: 4, ornament: 'gem', glow: Color(0xFFA5F3FC), orbit: 'spark', orbitCount: 8, orbitSecs: 5),
};

const kRarityNames = {1: 'Common', 2: 'Rare', 3: 'Epic', 4: 'Legendary'};
const kRarityColors = {1: Color(0xFF64748B), 2: Color(0xFF2563EB), 3: Color(0xFF9333EA), 4: Color(0xFFF59E0B)};

/// Avatar with an optional, animated reward frame.
///
/// [size] is the photo diameter; the frame adds ~16% on each side.
/// With [animate] = false (long lists) the frame rests, and comes alive while
/// the user presses and holds it.
class FramedAvatar extends StatefulWidget {
  final String? frame;
  final String? photo;
  final String name;
  final double size;
  final bool animate;
  final Color? fallbackColor;

  const FramedAvatar({
    super.key,
    required this.frame,
    required this.photo,
    required this.name,
    this.size = 44,
    this.animate = true,
    this.fallbackColor,
  });

  static double outerSize(String? frame, double size) => kFrameStyles.containsKey(frame) ? size * 1.32 : size;

  @override
  State<FramedAvatar> createState() => _FramedAvatarState();
}

class _Clock extends ChangeNotifier {
  double t = 0;
  void tick() => notifyListeners();
}

class _FramedAvatarState extends State<FramedAvatar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _clock = _Clock();
  Duration _last = Duration.zero;
  bool _held = false;

  FrameStyle? get _style => kFrameStyles[widget.frame];

  bool get _shouldRun {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return _style != null && !reduce && (widget.animate || _held);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FramedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldRun && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _clock.t += dt;
    _clock.tick();
  }

  void _hold(bool v) {
    if (widget.animate || _held == v) return;
    _held = v;
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = AvatarCache.provider(widget.photo, cacheWidth: (widget.size * 3).round());
    final avatar = CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: widget.fallbackColor ?? AppColors.red,
      backgroundImage: img,
      child: img == null
          ? Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: widget.size * 0.4))
          : null,
    );
    final style = _style;
    if (style == null) return avatar;

    final outer = widget.size * 1.32;
    final colors = style.colors ?? [AppColors.coral, AppColors.red, AppColors.redDeep, AppColors.red, AppColors.coral];
    final glow = style.glow ?? AppColors.red;

    Widget framed = RepaintBoundary(
      child: SizedBox.square(
        dimension: outer,
        child: CustomPaint(
          painter: _RingPainter(style, colors, glow, _clock),
          foregroundPainter: _OrnamentPainter(style, _clock),
          child: Center(child: avatar),
        ),
      ),
    );
    if (!widget.animate) {
      // Press & hold (~0.2s) to bring a resting frame to life.
      framed = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _pressing = true;
          Future.delayed(const Duration(milliseconds: 180), () {
            if (mounted && _pressing) _hold(true);
          });
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: framed,
      );
    }
    return framed;
  }

  bool _pressing = false;
  void _release() {
    _pressing = false;
    _hold(false);
  }
}

class _RingPainter extends CustomPainter {
  final FrameStyle s;
  final List<Color> colors;
  final Color glow;
  final _Clock clock;
  _RingPainter(this.s, this.colors, this.glow, this.clock) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.t;
    final c = size.center(Offset.zero);
    final avatarR = size.width / 1.32 / 2;
    final ring = math.max(2.5, avatarR * 2 * 0.07);
    final r = avatarR + ring / 2 + 0.5;
    final pulse = s.fx.contains('pulse') ? 0.5 + 0.5 * math.sin(t * 2.6) : 0.6;
    final neon = s.fx.contains('neon');

    // Breathing glow.
    canvas.drawCircle(
      c,
      r + ring * (neon ? 3.2 : 2.2),
      Paint()
        ..shader = RadialGradient(
          colors: [glow.withValues(alpha: (neon ? 0.55 : 0.35) + 0.25 * pulse), glow.withValues(alpha: 0)],
          stops: const [0.72, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r + ring * (neon ? 3.2 : 2.2))),
    );

    // Sun rays.
    if (s.fx.contains('rays')) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * 2 * math.pi / 16);
      final ray = Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.75);
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8;
        final p = Path()
          ..moveTo((r + ring) * math.cos(a - 0.08), (r + ring) * math.sin(a - 0.08))
          ..lineTo((size.width / 2) * math.cos(a), (size.width / 2) * math.sin(a))
          ..lineTo((r + ring) * math.cos(a + 0.08), (r + ring) * math.sin(a + 0.08))
          ..close();
        canvas.drawPath(p, ray);
      }
      canvas.restore();
    }

    // Gradient ring.
    final angle = s.spin > 0 ? t * 2 * math.pi / s.spin : 0.0;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring * (neon ? 1 + 0.25 * pulse : 1)
        ..shader = SweepGradient(colors: colors, transform: GradientRotation(angle)).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.s != s || old.colors != colors || old.glow != glow;
}

class _OrnamentPainter extends CustomPainter {
  final FrameStyle s;
  final _Clock clock;
  _OrnamentPainter(this.s, this.clock) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.t;
    canvas.save();
    canvas.scale(size.width / 100); // 100x100 design space, same as the web SVG

    // Orbiting particles.
    if (s.orbit.isNotEmpty && s.orbitCount > 0) {
      final base = t * 2 * math.pi / s.orbitSecs;
      for (var i = 0; i < s.orbitCount; i++) {
        final a = base + i / s.orbitCount * 2 * math.pi;
        final r = 47.0 + (i % 2) * 3;
        final tw = 0.65 + 0.35 * math.sin(t * 3.4 + i * 1.7);
        canvas.save();
        canvas.translate(50 + r * math.cos(a), 50 + r * math.sin(a));
        canvas.rotate(a + t);
        canvas.scale(tw);
        _particle(canvas, s.orbit, i);
        canvas.restore();
      }
    }

    // Lightning bolts flashing.
    if (s.fx.contains('zap')) {
      const spots = [
        [18.0, 14.0, -20.0],
        [86.0, 30.0, 15.0],
        [24.0, 86.0, 200.0],
        [82.0, 84.0, 160.0],
      ];
      for (var i = 0; i < spots.length; i++) {
        final phase = (t * 0.45 + i * 0.27) % 1.0;
        final on = phase < 0.05 || (phase > 0.08 && phase < 0.12);
        if (!on && clock.t > 0) continue;
        canvas.save();
        canvas.translate(spots[i][0], spots[i][1]);
        canvas.rotate(spots[i][2] * math.pi / 180);
        final bolt = Path()
          ..moveTo(-1, -8)
          ..lineTo(4, -8)
          ..lineTo(1, -1)
          ..lineTo(5, -1)
          ..lineTo(-3, 9)
          ..lineTo(-1, 2)
          ..lineTo(-5, 2)
          ..close();
        canvas.drawPath(bolt, Paint()..color = const Color(0xFFFDE047));
        canvas.restore();
      }
    }

    _ornament(canvas, t);
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  Path _star5(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(rr * math.cos(a), rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _heart(double k) => Path()
    ..moveTo(0, 4 * k)
    ..cubicTo(-7 * k, -1 * k, -3 * k, -6 * k, 0, -3 * k)
    ..cubicTo(3 * k, -6 * k, 7 * k, -1 * k, 0, 4 * k)
    ..close();

  void _particle(Canvas c, String kind, int i) {
    switch (kind) {
      case 'petal':
        final p = Path()
          ..moveTo(0, -5)
          ..quadraticBezierTo(5, -2, 0, 5)
          ..quadraticBezierTo(-5, -2, 0, -5)
          ..close();
        c.drawPath(p, Paint()..color = const [Color(0xFFF9A8D4), Color(0xFFFBCFE8), Color(0xFFF472B6)][i % 3]);
        break;
      case 'heart':
        c.drawPath(_heart(1), Paint()..color = const Color(0xFFF43F5E));
        break;
      case 'snow':
        final sp = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 3; k++) {
          final a = k * math.pi / 3;
          c.drawLine(Offset(-4.5 * math.sin(a), -4.5 * math.cos(a)), Offset(4.5 * math.sin(a), 4.5 * math.cos(a)), sp);
        }
        break;
      case 'bubble':
        final r = 2.5 + (i % 3);
        c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF7DD3FC).withValues(alpha: 0.25));
        c.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..color = const Color(0xFF38BDF8));
        c.drawCircle(const Offset(-1, -1), 0.8, Paint()..color = Colors.white);
        break;
      case 'ember':
        c.drawCircle(Offset.zero, 1.6 + (i % 2), Paint()..color = const [Color(0xFFFFD34D), Color(0xFFFF7A1A), Color(0xFFFFE08A)][i % 3]);
        break;
      case 'star':
        _sparkle(c, Offset.zero, 3.4, const [Color(0xFFFFD34D), Colors.white, Color(0xFFE9D5FF)][i % 3]);
        break;
      case 'confetti':
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-1.4, -2.4, 2.8, 4.8), const Radius.circular(0.8)),
            Paint()..color = const [Color(0xFFF43F5E), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFA855F7)][i % 5]);
        break;
      case 'gem':
        final p = Path()
          ..moveTo(0, -3.6)
          ..lineTo(3, 0)
          ..lineTo(0, 3.6)
          ..lineTo(-3, 0)
          ..close();
        c.drawPath(p, Paint()..color = const [Color(0xFF38BDF8), Color(0xFFF43F5E), Color(0xFF22C55E)][i % 3]);
        break;
      default:
        _sparkle(c, Offset.zero, 2.8, Colors.white);
    }
  }

  void _flame(Canvas canvas, double angle, double t, int i) {
    final flick = math.sin(t * 9 + i * 2.1);
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(angle);
    canvas.translate(0, -37);
    canvas.scale(1 + flick * 0.08, 1 - flick * 0.12);
    final p = Path()
      ..moveTo(0, -8)
      ..cubicTo(3, -3, 6, -1, 6, 3)
      ..cubicTo(6, 7, 3, 9, 0, 9)
      ..cubicTo(-3, 9, -6, 7, -6, 3)
      ..cubicTo(-6, 0, -3, -2, -2, -5)
      ..cubicTo(-1, -2, 0, -1, 1, -1)
      ..cubicTo(0, -3, -1, -6, 0, -8)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD34D), Color(0xFFE11D2E)])
              .createShader(const Rect.fromLTWH(-6, -8, 12, 17)));
    canvas.restore();
  }

  void _ornament(Canvas canvas, double t) {
    const gold = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4B0), Color(0xFFF5B70A)]);
    final bob = math.sin(t * 2.4) * 2.5;
    final twinkle = 0.55 + 0.45 * math.sin(t * 3.5);
    switch (s.ornament) {
      case 'crown':
        canvas.save();
        canvas.translate(0, bob);
        final p = Path()
          ..moveTo(36, 12)
          ..lineTo(40, -2)
          ..lineTo(46, 7)
          ..lineTo(50, -5)
          ..lineTo(54, 7)
          ..lineTo(60, -2)
          ..lineTo(64, 12)
          ..close();
        canvas.drawPath(p, Paint()..shader = gold.createShader(const Rect.fromLTWH(36, -5, 28, 17)));
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = const Color(0xFF8F5A00));
        canvas.drawCircle(const Offset(50, -5), 2 * (0.7 + 0.3 * twinkle), Paint()..color = const Color(0xFFE11D2E));
        canvas.restore();
        break;
      case 'moon':
        canvas.save();
        canvas.translate(0, bob);
        final full = Path()..addOval(Rect.fromCircle(center: const Offset(84, 16), radius: 9));
        final bite = Path()..addOval(Rect.fromCircle(center: const Offset(88, 13), radius: 8));
        canvas.drawPath(Path.combine(PathOperation.difference, full, bite), Paint()..color = const Color(0xFFF8FAFC));
        canvas.restore();
        _sparkle(canvas, const Offset(72, 6), 2.4 * twinkle, Colors.white);
        break;
      case 'star':
        canvas.save();
        canvas.translate(0, bob);
        canvas.drawPath(_star5(const Offset(84, 15), 10), Paint()..color = const Color(0xFFFFD34D));
        canvas.restore();
        _sparkle(canvas, const Offset(14, 20), 4 * twinkle, const Color(0xFFFF6BB5));
        break;
      case 'stars':
        _sparkle(canvas, const Offset(84, 14), 6 * twinkle, Colors.white);
        _sparkle(canvas, const Offset(12, 24), 4 * (1.4 - twinkle), const Color(0xFFE9D5FF));
        _sparkle(canvas, const Offset(90, 70), 3.5 * twinkle, const Color(0xFFC4B5FD));
        _sparkle(canvas, const Offset(20, 86), 3 * (1.4 - twinkle), Colors.white);
        break;
      case 'laurel':
        final leaf = Paint()..color = const Color(0xFF2E9D5A);
        for (final d in [-1.0, 1.0]) {
          for (var i = 0; i < 5; i++) {
            final a = (110 + i * 16) * math.pi / 180;
            final x = 50 - d * 46 * math.cos(a);
            final y = 50 + 46 * math.sin(a);
            canvas.save();
            canvas.translate(x, y);
            canvas.rotate(d * (20 + i * 16) * math.pi / 180 + math.sin(t * 2 + i) * 0.06);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 6.8, height: 14), leaf);
            canvas.restore();
          }
        }
        canvas.save();
        canvas.translate(0, bob);
        canvas.drawPath(_star5(const Offset(50, 6), 7 * (0.85 + 0.15 * twinkle)), Paint()..color = const Color(0xFFFFD34D));
        canvas.restore();
        break;
      case 'shield':
        canvas.save();
        canvas.translate(0, bob);
        final p = Path()
          ..moveTo(50, 82)
          ..lineTo(60, 86)
          ..lineTo(58, 96)
          ..quadraticBezierTo(50, 104, 50, 104)
          ..quadraticBezierTo(50, 104, 42, 96)
          ..lineTo(40, 86)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF2563EB));
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = Colors.white);
        canvas.drawPath(_star5(const Offset(50, 92), 5), Paint()..color = const Color(0xFFFFD34D));
        canvas.restore();
        break;
      case 'hat':
        canvas.save();
        canvas.translate(74, 20);
        canvas.rotate(math.sin(t * 2.8) * 0.14);
        canvas.translate(0, -10);
        canvas.rotate(25 * math.pi / 180);
        final hat = Path()
          ..moveTo(-9, 10)
          ..lineTo(0, -12)
          ..lineTo(9, 10)
          ..close();
        canvas.drawPath(hat, Paint()..color = const Color(0xFFA855F7));
        canvas.drawLine(
            const Offset(-5, 0),
            const Offset(5, 0),
            Paint()
              ..color = const Color(0xFFFDE047)
              ..strokeWidth = 2);
        canvas.drawCircle(const Offset(0, -13), 3, Paint()..color = const Color(0xFFF43F5E));
        canvas.restore();
        break;
      case 'wings':
        final flap = 1 - 0.18 * (0.5 + 0.5 * math.sin(t * 4.5));
        for (final d in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(50 + d * 44, 46);
          canvas.scale(d * flap, 1);
          canvas.rotate(-0.1 * (1 - flap) * 5);
          final w = Path()
            ..moveTo(0, 0)
            ..cubicTo(8, -14, 20, -16, 24, -10)
            ..cubicTo(18, -10, 14, -6, 12, -2)
            ..cubicTo(18, -5, 22, -3, 22, 1)
            ..cubicTo(16, 0, 12, 2, 10, 5)
            ..cubicTo(14, 5, 16, 8, 14, 10)
            ..cubicTo(8, 8, 3, 6, 0, 4)
            ..close();
          canvas.drawPath(w, Paint()..shader = gold.createShader(const Rect.fromLTWH(0, -16, 24, 26)));
          canvas.restore();
        }
        break;
      case 'flame':
        _flame(canvas, 0, t, 0);
        break;
      case 'flames':
        for (var i = 0; i < 3; i++) {
          _flame(canvas, (-38.0 + i * 38) * math.pi / 180, t, i);
        }
        break;
      case 'corona':
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-t * 2 * math.pi / 12);
        final ray = Paint()
          ..color = const Color(0xFFFDE68A).withValues(alpha: 0.9)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi * 2 / 16;
          final r2 = i.isOdd ? 49.0 : 51.0;
          canvas.drawLine(Offset(46 * math.cos(a), 46 * math.sin(a)), Offset(r2 * math.cos(a), r2 * math.sin(a)), ray);
        }
        canvas.restore();
        break;
      case 'heart':
        final beatPhase = (t % 1.1) / 1.1;
        final beat = beatPhase < 0.15 ? 1 + beatPhase / 0.15 * 0.25 : (beatPhase < 0.3 ? 1.25 - (beatPhase - 0.15) / 0.15 * 0.2 : 1.05 - math.min(0.05, (beatPhase - 0.3)));
        canvas.save();
        canvas.translate(84, 15);
        canvas.scale(1.4 * beat);
        canvas.drawPath(_heart(1.2), Paint()..color = const Color(0xFFF43F5E));
        canvas.restore();
        break;
      case 'gem':
        canvas.save();
        canvas.translate(50, 5 + bob);
        final g = Path()
          ..moveTo(-8, -2)
          ..lineTo(-4, -7)
          ..lineTo(4, -7)
          ..lineTo(8, -2)
          ..lineTo(0, 8)
          ..close();
        canvas.drawPath(g, Paint()..color = const Color(0xFFA5F3FC));
        canvas.drawPath(
            g,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white);
        canvas.restore();
        _sparkle(canvas, const Offset(60, 0), 2.4 * twinkle, Colors.white);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _OrnamentPainter old) => old.s != s;
}
