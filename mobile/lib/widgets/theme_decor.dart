import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// Ambient animated layer drawn above the whole app for decorated themes
/// (petals, leaves, bubbles, monsters…). Kept deliberately sparse and
/// translucent so it never gets in the way of content.
///
/// Performance: one Ticker, one CustomPainter on its own layer, particles
/// pre-generated; it pauses with TickerMode and when reduced motion is on.
class ThemeDecorLayer extends StatefulWidget {
  final ThemeDecor decor;
  const ThemeDecorLayer({super.key, required this.decor});

  @override
  State<ThemeDecorLayer> createState() => _ThemeDecorLayerState();
}

class _Particle {
  double x, y; // 0..1
  final double speed, size, sway, phase, spin;
  final int variant;
  _Particle(this.x, this.y, this.speed, this.size, this.sway, this.phase, this.spin, this.variant);
}

class _DecorState extends ChangeNotifier {
  double t = 0;
  void tick() => notifyListeners();
}

class _ThemeDecorLayerState extends State<ThemeDecorLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _state = _DecorState();
  Duration _last = Duration.zero;
  List<_Particle> _ps = [];

  int get _count => switch (widget.decor) {
        ThemeDecor.monsters => 4,
        ThemeDecor.clouds => 4,
        ThemeDecor.stars || ThemeDecor.goldDust => 26,
        _ => 12,
      };

  @override
  void initState() {
    super.initState();
    _seed();
  }

  void _seed() {
    final r = math.Random(widget.decor.index * 7 + 3);
    _ps = List.generate(_count, (i) {
      return _Particle(r.nextDouble(), r.nextDouble(), 0.012 + r.nextDouble() * 0.02, 0.7 + r.nextDouble() * 0.6,
          0.02 + r.nextDouble() * 0.04, r.nextDouble() * 6.28, (r.nextDouble() - 0.5) * 2, i % 4);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ThemeDecorLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decor != widget.decor) _seed();
    _syncTicker();
  }

  void _syncTicker() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final want = widget.decor != ThemeDecor.none && !reduce;
    if (want && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!want && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _state.t += dt;
    final rising = widget.decor == ThemeDecor.bubbles;
    final drifting = widget.decor == ThemeDecor.monsters || widget.decor == ThemeDecor.clouds;
    final twinkle = widget.decor == ThemeDecor.stars || widget.decor == ThemeDecor.goldDust;
    for (final p in _ps) {
      if (twinkle) continue;
      if (drifting) {
        p.x += p.speed * dt * 0.6;
        if (p.x > 1.25) p.x = -0.25;
      } else {
        p.y += (rising ? -1 : 1) * p.speed * dt;
        if (!rising && p.y > 1.08) p.y = -0.08;
        if (rising && p.y < -0.08) p.y = 1.08;
      }
    }
    _state.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decor == ThemeDecor.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _DecorPainter(widget.decor, _ps, _state)),
      ),
    );
  }
}

class _DecorPainter extends CustomPainter {
  final ThemeDecor decor;
  final List<_Particle> ps;
  final _DecorState s;
  _DecorPainter(this.decor, this.ps, this.s) : super(repaint: s);

  @override
  void paint(Canvas canvas, Size size) {
    final t = s.t;
    for (final p in ps) {
      final x = (p.x + math.sin(t * 0.8 + p.phase) * p.sway) * size.width;
      final y = p.y * size.height;
      canvas.save();
      canvas.translate(x, y);
      switch (decor) {
        case ThemeDecor.petals:
          canvas.rotate(t * p.spin + p.phase);
          _petal(canvas, 7 * p.size, p.variant);
          break;
        case ThemeDecor.leaves:
          canvas.rotate(math.sin(t * 1.3 + p.phase) * 0.9 + p.phase);
          _leaf(canvas, 9 * p.size, p.variant);
          break;
        case ThemeDecor.bubbles:
          _bubble(canvas, 6 * p.size + p.variant * 1.5);
          break;
        case ThemeDecor.stars:
          _twinkle(canvas, 2.4 * p.size, (0.5 + 0.5 * math.sin(t * 2 + p.phase * 3)), Colors.white);
          break;
        case ThemeDecor.goldDust:
          _twinkle(canvas, 2.2 * p.size, (0.5 + 0.5 * math.sin(t * 1.6 + p.phase * 3)), const Color(0xFFFCD34D));
          break;
        case ThemeDecor.candy:
          canvas.rotate(t * p.spin * 0.6);
          _candy(canvas, 7 * p.size, p.variant);
          break;
        case ThemeDecor.clouds:
          _cloud(canvas, 18 * p.size);
          break;
        case ThemeDecor.monsters:
          canvas.translate(0, math.sin(t * 1.6 + p.phase) * 10);
          _monster(canvas, 16 * p.size, p.variant, t, p.phase);
          break;
        case ThemeDecor.none:
          break;
      }
      canvas.restore();
    }
  }

  void _petal(Canvas c, double r, int v) {
    final colors = [const Color(0xFFF9A8D4), const Color(0xFFFBCFE8), const Color(0xFFF472B6), const Color(0xFFFDE2EE)];
    final p = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r, -r * 0.4, 0, r)
      ..quadraticBezierTo(-r, -r * 0.4, 0, -r)
      ..close();
    c.drawPath(p, Paint()..color = colors[v].withValues(alpha: 0.75));
    c.drawLine(Offset(0, -r * 0.6), Offset(0, r * 0.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 0.8);
  }

  void _leaf(Canvas c, double r, int v) {
    final colors = [const Color(0xFF4ADE80), const Color(0xFF22C55E), const Color(0xFF84CC16), const Color(0xFFFACC15)];
    final p = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 0.8, 0, 0, r)
      ..quadraticBezierTo(-r * 0.8, 0, 0, -r)
      ..close();
    c.drawPath(p, Paint()..color = colors[v].withValues(alpha: 0.7));
    c.drawLine(Offset(0, -r), Offset(0, r * 1.2),
        Paint()
          ..color = const Color(0xFF166534).withValues(alpha: 0.5)
          ..strokeWidth = 1);
  }

  void _bubble(Canvas c, double r) {
    c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF7DD3FC).withValues(alpha: 0.18));
    c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.55));
    c.drawCircle(Offset(-r * 0.35, -r * 0.35), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.8));
  }

  void _twinkle(Canvas c, double r, double a, Color color) {
    final p = Path()
      ..moveTo(0, -r * 2)
      ..quadraticBezierTo(0, 0, r * 2, 0)
      ..quadraticBezierTo(0, 0, 0, r * 2)
      ..quadraticBezierTo(0, 0, -r * 2, 0)
      ..quadraticBezierTo(0, 0, 0, -r * 2)
      ..close();
    c.drawPath(p, Paint()..color = color.withValues(alpha: 0.25 + 0.6 * a));
  }

  void _candy(Canvas c, double r, int v) {
    final colors = [const Color(0xFFF472B6), const Color(0xFF60A5FA), const Color(0xFFFDE047), const Color(0xFFA78BFA)];
    final col = colors[v].withValues(alpha: 0.75);
    if (v.isEven) {
      // Wrapped sweet.
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.4), Paint()..color = col);
      for (final d in [-1.0, 1.0]) {
        final w = Path()
          ..moveTo(d * r, 0)
          ..lineTo(d * r * 1.7, -r * 0.6)
          ..lineTo(d * r * 1.7, r * 0.6)
          ..close();
        c.drawPath(w, Paint()..color = col);
      }
    } else {
      // Lollipop.
      c.drawLine(Offset(0, r), Offset(0, r * 2.6),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..strokeWidth = 2);
      c.drawCircle(Offset.zero, r, Paint()..color = col);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.55), 0, 4.5, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.8));
    }
  }

  void _cloud(Canvas c, double r) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    c.drawCircle(Offset(-r * 0.6, 0), r * 0.55, paint);
    c.drawCircle(Offset(0, -r * 0.25), r * 0.7, paint);
    c.drawCircle(Offset(r * 0.65, 0), r * 0.5, paint);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-r * 1.1, 0, r * 2.2, r * 0.5), Radius.circular(r * 0.25)), paint);
  }

  /// Cute round monster with big eyes that blink and a tiny smile.
  void _monster(Canvas c, double r, int v, double t, double phase) {
    final bodies = [const Color(0xFF8B5CF6), const Color(0xFF22C55E), const Color(0xFFF59E0B), const Color(0xFF38BDF8)];
    final body = bodies[v].withValues(alpha: 0.85);
    // Horns / antenna.
    final horn = Paint()..color = body;
    if (v.isEven) {
      c.drawPath(
          Path()
            ..moveTo(-r * 0.6, -r * 0.7)
            ..lineTo(-r * 0.35, -r * 1.25)
            ..lineTo(-r * 0.15, -r * 0.85)
            ..close(),
          horn);
      c.drawPath(
          Path()
            ..moveTo(r * 0.6, -r * 0.7)
            ..lineTo(r * 0.35, -r * 1.25)
            ..lineTo(r * 0.15, -r * 0.85)
            ..close(),
          horn);
    } else {
      c.drawLine(Offset(0, -r * 0.9), Offset(math.sin(t * 2 + phase) * r * 0.2, -r * 1.4),
          Paint()
            ..color = body
            ..strokeWidth = 2);
      c.drawCircle(Offset(math.sin(t * 2 + phase) * r * 0.2, -r * 1.45), r * 0.15, Paint()..color = const Color(0xFFFDE047));
    }
    // Body (slightly squishy).
    final squish = 1 + math.sin(t * 3 + phase) * 0.04;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2 * squish, height: r * 2 / squish), Paint()..color = body);
    // Feet / arms wiggle.
    final wig = math.sin(t * 4 + phase) * 0.3;
    c.drawCircle(Offset(-r * 1.0, r * 0.1 + wig * r * 0.3), r * 0.2, Paint()..color = body);
    c.drawCircle(Offset(r * 1.0, r * 0.1 - wig * r * 0.3), r * 0.2, Paint()..color = body);
    // Eyes (blink every ~4s).
    final blink = ((t + phase) % 4.0) < 0.15;
    final eyeW = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF1F1A24);
    final eyes = v == 2 ? [Offset.zero] : [Offset(-r * 0.35, -r * 0.15), Offset(r * 0.35, -r * 0.15)];
    final er = v == 2 ? r * 0.45 : r * 0.28;
    for (final e in eyes) {
      if (blink) {
        c.drawLine(e - Offset(er * 0.8, 0), e + Offset(er * 0.8, 0),
            Paint()
              ..color = const Color(0xFF1F1A24)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
      } else {
        c.drawCircle(e, er, eyeW);
        final look = Offset(math.sin(t * 0.7 + phase) * er * 0.35, math.cos(t * 0.5 + phase) * er * 0.2);
        c.drawCircle(e + look, er * 0.5, pupil);
        c.drawCircle(e + look + Offset(er * 0.15, -er * 0.18), er * 0.15, eyeW);
      }
    }
    // Smile with a fang.
    c.drawArc(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 0.7, height: r * 0.45), 0.2, 2.7, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF1F1A24));
    c.drawPath(
        Path()
          ..moveTo(r * 0.1, r * 0.55)
          ..lineTo(r * 0.2, r * 0.75)
          ..lineTo(r * 0.28, r * 0.52)
          ..close(),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DecorPainter old) => old.decor != decor;
}
