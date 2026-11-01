import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum TikiMood { idle, happy, sad }

/// "Tiki" — the FID-A mascot: a little alarm clock with feelings.
///
/// Inputs are *targets*; a single Ticker eases the drawn state toward them
/// every frame and only repaints (no widget rebuilds). The ticker obeys
/// TickerMode, so it sleeps when the screen is not visible.
class TikiMascot extends StatefulWidget {
  final Offset look; // -1..1 in both axes
  final bool cover; // hands over the eyes
  final bool peek; // one hand lowered
  final TikiMood mood;
  final double size;

  const TikiMascot({
    super.key,
    this.look = Offset.zero,
    this.cover = false,
    this.peek = false,
    this.mood = TikiMood.idle,
    this.size = 150,
  });

  @override
  State<TikiMascot> createState() => _TikiMascotState();
}

class _TikiState extends ChangeNotifier {
  double t = 0; // seconds since start
  Offset look = Offset.zero;
  double coverL = 0, coverR = 0; // 0 = arm down, 1 = over the eye
  double happy = 0, sad = 0;
  double blink = 0; // 0 open, 1 closed
  double shake = 0; // decays after an error
  double jump = 0; // happy hop phase
  void tick() => notifyListeners();
}

class _TikiMascotState extends State<TikiMascot> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _s = _TikiState();
  Duration _last = Duration.zero;
  double _nextBlink = 2.5;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant TikiMascot old) {
    super.didUpdateWidget(old);
    if (widget.mood == TikiMood.sad && old.mood != TikiMood.sad) _s.shake = 1;
  }

  double _approach(double v, double target, double dt, double speed) => v + (target - v) * math.min(1, dt * speed);

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final s = _s;
    s.t += dt;

    s.look = Offset(_approach(s.look.dx, widget.look.dx, dt, 10), _approach(s.look.dy, widget.look.dy, dt, 10));
    final sad = widget.mood == TikiMood.sad;
    final cover = widget.cover && !sad;
    s.coverL = _approach(s.coverL, cover ? 1 : 0, dt, 9);
    s.coverR = _approach(s.coverR, cover ? (widget.peek ? 0.55 : 1) : 0, dt, 9);
    s.happy = _approach(s.happy, widget.mood == TikiMood.happy ? 1 : 0, dt, 8);
    s.sad = _approach(s.sad, sad ? 1 : 0, dt, 8);
    s.shake = math.max(0, s.shake - dt * 1.6);
    s.jump = widget.mood == TikiMood.happy ? s.jump + dt : 0;

    // Natural blinking at random intervals.
    if (s.t > _nextBlink) {
      final p = (s.t - _nextBlink) / 0.16;
      s.blink = p < 1 ? math.sin(p * math.pi) : 0;
      if (p >= 1) _nextBlink = s.t + 2.2 + _rnd.nextDouble() * 3;
    }
    s.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size * 1.05),
        painter: _TikiPainter(_s),
      ),
    );
  }
}

class _TikiPainter extends CustomPainter {
  final _TikiState s;
  const _TikiPainter(this.s) : super(repaint: s);

  static const _ink = Color(0xFF1F1A24);
  static const _red = Color(0xFFE11D2E);
  static const _redDeep = Color(0xFF9E0D1C);
  static const _armRed = Color(0xFFB3121F);

  @override
  void paint(Canvas canvas, Size size) {
    // Design space is 200 x 210, scaled to the widget.
    final k = size.width / 200;
    canvas.scale(k);

    final bob = math.sin(s.t * 2.1) * 3 * (1 - s.happy);
    final hop = s.happy > 0.01 ? -math.max(0, math.sin(s.jump * math.pi * 2.2)) * 26 * s.happy : 0.0;
    final shakeX = math.sin(s.t * 40) * 10 * s.shake;
    final tilt = math.sin(s.t * 2.1) * 0.025 + math.sin(s.t * 40) * 0.08 * s.shake;

    // Ground shadow (shrinks as Tiki rises).
    final lift = (-hop - bob) / 30;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 198), width: 104 * (1 - lift * 0.3), height: 14),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.12 * (1 - lift * 0.4)),
    );

    canvas.save();
    canvas.translate(100 + shakeX, 120 + bob + hop);
    canvas.rotate(tilt);
    canvas.translate(-100, -120);

    // Feet.
    final feet = Paint()..color = _redDeep;
    canvas.drawOval(Rect.fromCenter(center: const Offset(74, 184), width: 26, height: 16), feet);
    canvas.drawOval(Rect.fromCenter(center: const Offset(126, 184), width: 26, height: 16), feet);

    // Bells (ring when happy).
    canvas.save();
    canvas.translate(100, 70);
    canvas.rotate(math.sin(s.t * 30) * 0.15 * s.happy);
    canvas.translate(-100, -70);
    const bellGrad = LinearGradient(colors: [Color(0xFFFFE9A8), Color(0xFFFFC23D), Color(0xFFD98A00)]);
    canvas.drawLine(const Offset(100, 40), const Offset(100, 54),
        Paint()
          ..color = const Color(0xFFD98A00)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(100, 38), 6, Paint()..shader = bellGrad.createShader(const Rect.fromLTWH(94, 32, 12, 12)));
    for (final left in [true, false]) {
      final bellPath = Path()
        ..moveTo(left ? 44 : 156, 62)
        ..arcToPoint(Offset(left ? 82 : 118, 30), radius: const Radius.circular(26), clockwise: left)
        ..close();
      canvas.drawPath(bellPath, Paint()..shader = bellGrad.createShader(bellPath.getBounds()));
      canvas.drawPath(
          bellPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFC47A00));
    }
    canvas.restore();

    // Body.
    const center = Offset(100, 112);
    canvas.drawCircle(
      center,
      66,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [Color(0xFFFF7A6E), _red, _redDeep],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: 66)),
    );
    canvas.save();
    canvas.translate(78, 70);
    canvas.rotate(-0.49);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 36, height: 18), Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.restore();
    canvas.drawCircle(center, 51, Paint()..color = const Color(0xFFFFFAF8));

    // Clock ticks.
    final tick = Paint()
      ..color = const Color(0xFFF3B6B0)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final r2 = i % 3 == 0 ? 39.0 : 42.0;
      tick.strokeWidth = i % 3 == 0 ? 3 : 2;
      canvas.drawLine(Offset(100 + 45 * math.sin(a), 112 - 45 * math.cos(a)),
          Offset(100 + r2 * math.sin(a), 112 - r2 * math.cos(a)), tick);
    }

    // Eyes.
    final eo = Offset(s.look.dx * 5, s.look.dy * 3.5);
    final ink = Paint()..color = _ink;
    if (s.happy > 0.5) {
      final arc = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      for (final x in [80.0, 120.0]) {
        final p = Path()
          ..moveTo(x - 10, 106)
          ..quadraticBezierTo(x, 94, x + 10, 106);
        canvas.drawPath(p.shift(eo), arc);
      }
    } else {
      final h = (22 - 4 * s.sad) * (1 - s.blink * 0.9);
      for (final x in [80.0, 120.0]) {
        final c = Offset(x, 104) + eo;
        canvas.drawOval(Rect.fromCenter(center: c, width: 17, height: h), ink);
        if (s.blink < 0.5) {
          canvas.drawCircle(c + const Offset(3, -5), 3.2, Paint()..color = Colors.white);
          canvas.drawCircle(c + const Offset(-3, 4), 1.5, Paint()..color = Colors.white.withValues(alpha: 0.8));
        }
      }
      if (s.sad > 0.05) {
        final brow = Paint()
          ..color = _ink.withValues(alpha: s.sad)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(70, 88) + eo, const Offset(88, 92) + eo, brow);
        canvas.drawLine(const Offset(130, 88) + eo, const Offset(112, 92) + eo, brow);
      }
    }

    // Cheeks.
    final cheek = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55 + 0.3 * s.happy);
    canvas.drawOval(Rect.fromCenter(center: const Offset(68, 124), width: 18, height: 11), cheek);
    canvas.drawOval(Rect.fromCenter(center: const Offset(132, 124), width: 18, height: 11), cheek);

    // Mouth.
    if (s.happy > 0.5) {
      final m = Path()
        ..moveTo(86, 126)
        ..quadraticBezierTo(100, 146, 114, 126)
        ..close();
      canvas.drawPath(m, Paint()..color = const Color(0xFF7A1020));
      canvas.drawOval(Rect.fromCenter(center: const Offset(100, 136.5), width: 13, height: 6), Paint()..color = const Color(0xFFFF6B81));
    } else {
      final cover = math.max(s.coverL, s.coverR);
      if (cover > 0.6 && s.sad < 0.5) {
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 132), width: 10, height: 12), Paint()..color = const Color(0xFF7A1020));
      } else {
        // Smile morphs into a frown with sadness.
        final y = 128 + 10 * s.sad;
        final ctrl = 140 - 22 * s.sad;
        final m = Path()
          ..moveTo(88, y)
          ..quadraticBezierTo(100, ctrl, 112, y);
        canvas.drawPath(
            m,
            Paint()
              ..color = _ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
      }
    }

    // Arms: rotate around the shoulders from rest to covering the eyes.
    _arm(canvas, const Offset(46, 132), _lerpDeg(28, -131, s.coverL) + 122 * s.happy);
    _arm(canvas, const Offset(154, 132), _lerpDeg(-28, 131, s.coverR) - 122 * s.happy);

    canvas.restore();
  }

  double _lerpDeg(double a, double b, double t) => (a + (b - a) * t) * math.pi / 180;

  void _arm(Canvas canvas, Offset shoulder, double angle) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    canvas.drawLine(
        Offset.zero,
        const Offset(0, 40),
        Paint()
          ..color = _armRed
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(0, 44), 11, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(0, 44),
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _armRed);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TikiPainter old) => old.s != s;
}

/// Cute floating doodles (calendar, coffee, medal, sparkles) for hero areas.
class FloatingDoodles extends StatefulWidget {
  const FloatingDoodles({super.key});

  @override
  State<FloatingDoodles> createState() => _FloatingDoodlesState();
}

class _FloatingDoodlesState extends State<FloatingDoodles> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(child: CustomPaint(painter: _DoodlePainter(_c), size: Size.infinite)),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final Animation<double> a;
  const _DoodlePainter(this.a) : super(repaint: a);

  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value * 2 * math.pi;
    void at(double fx, double fy, double phase, double scale, void Function(Canvas) draw) {
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy + math.sin(t + phase) * 8);
      canvas.rotate(math.sin(t + phase) * 0.12);
      canvas.scale(scale);
      draw(canvas);
      canvas.restore();
    }

    at(0.14, 0.30, 0, 0.9, _calendar);
    at(0.84, 0.22, 1.8, 0.85, _coffee);
    at(0.86, 0.62, 3.6, 0.8, _medal);
    at(0.10, 0.70, 2.4, 0.5, (c) => _sparkle(c, const Color(0xFFFFD34D)));
    at(0.62, 0.10, 4.1, 0.4, (c) => _sparkle(c, const Color(0xFFFF8FA3)));
    at(0.36, 0.86, 5.0, 0.35, (c) => _sparkle(c, Colors.white));
  }

  void _calendar(Canvas c) {
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-26, -20, 52, 46), const Radius.circular(10));
    c.drawRRect(body.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.18));
    c.drawRRect(body, Paint()..color = Colors.white);
    c.save();
    c.clipRRect(body);
    c.drawRect(const Rect.fromLTWH(-26, -20, 52, 16), Paint()..color = const Color(0xFFE11D2E));
    c.restore();
    final ring = Paint()..color = const Color(0xFF1F2937);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -26, 5, 12), const Radius.circular(3)), ring);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, -26, 5, 12), const Radius.circular(3)), ring);
    final check = Path()
      ..moveTo(-10, 10)
      ..lineTo(-3, 17)
      ..lineTo(11, 3);
    c.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF10B981));
  }

  void _coffee(Canvas c) {
    final cup = Path()
      ..moveTo(-18, -10)
      ..lineTo(18, -10)
      ..lineTo(18, 8)
      ..arcToPoint(const Offset(4, 22), radius: const Radius.circular(14))
      ..lineTo(-4, 22)
      ..arcToPoint(const Offset(-18, 8), radius: const Radius.circular(14))
      ..close();
    c.drawPath(cup.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.18));
    c.drawPath(cup, Paint()..color = const Color(0xFFFFB020));
    c.drawArc(
        const Rect.fromLTWH(13, -5, 14, 14),
        -math.pi / 2,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFFFFB020));
    final face = Paint()..color = const Color(0xFF3B2410);
    c.drawCircle(const Offset(-6, 4), 2.2, face);
    c.drawCircle(const Offset(6, 4), 2.2, face);
    c.drawArc(
        const Rect.fromLTWH(-4, 6, 8, 6),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFF3B2410));
  }

  void _medal(Canvas c) {
    c.drawPath(Path()..addPolygon(const [Offset(-12, -28), Offset(-2, -28), Offset(4, -10), Offset(-6, -10)], true),
        Paint()..color = const Color(0xFF8B5CF6));
    c.drawPath(Path()..addPolygon(const [Offset(12, -28), Offset(2, -28), Offset(-4, -10), Offset(6, -10)], true),
        Paint()..color = const Color(0xFFFF7A1A));
    c.drawCircle(const Offset(0, 8), 19, Paint()..color = const Color(0xFFF5B70A));
    c.drawCircle(
        const Offset(0, 8),
        19,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF8F5A00));
    c.drawCircle(const Offset(0, 8), 11, Paint()..color = const Color(0xFFFFE27A));
    _sparkleAt(c, const Offset(0, 8), 7, const Color(0xFFE11D2E));
  }

  void _sparkle(Canvas c, Color color) => _sparkleAt(c, Offset.zero, 24, color);

  void _sparkleAt(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => false;
}
