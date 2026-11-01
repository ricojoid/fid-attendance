import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/badge.dart';
import 'motion.dart';

/// Vector medal artwork for achievement badges, drawn entirely with
/// CustomPainter: crisp at any size, zero image decoding, tiny memory.
///
///  * STREAK badges are hexagonal medals with a flame emblem.
///  * OVERTIME badges are rosette medals with a moon & stars emblem.
///  * Tier decides the metal: bronze → silver → gold → legendary prism.
///  * Locked badges render desaturated with a lock and a progress arc.
class BadgeMedal extends StatefulWidget {
  final AppBadge badge;
  final double size;

  /// Animated specular shine + gentle float. Keep false inside dense grids.
  final bool animate;
  final bool showProgress;

  const BadgeMedal({
    super.key,
    required this.badge,
    this.size = 96,
    this.animate = false,
    this.showProgress = true,
  });

  @override
  State<BadgeMedal> createState() => _BadgeMedalState();
}

class _BadgeMedalState extends State<BadgeMedal> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  bool get _shouldAnimate => widget.animate && widget.badge.earned;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BadgeMedal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldAnimate && !reduceMotion(context)) {
      _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    } else {
      _c?.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final medal = CustomPaint(
      size: Size.square(widget.size),
      painter: _MedalPainter(
        badge: b,
        shine: _c,
        showProgress: widget.showProgress,
      ),
    );

    Widget child = medal;
    if (!b.earned) {
      child = ColorFiltered(colorFilter: _greyscale, child: Opacity(opacity: 0.55, child: medal));
      child = Stack(
        alignment: Alignment.center,
        children: [
          child,
          if (widget.showProgress)
            CustomPaint(size: Size.square(widget.size), painter: _ProgressArcPainter(b.percent, _accent(b))),
          Positioned(
            bottom: widget.size * 0.30,
            child: Container(
              padding: EdgeInsets.all(widget.size * 0.05),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.78),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.2),
              ),
              child: Icon(Icons.lock_rounded, color: Colors.white, size: widget.size * 0.13),
            ),
          ),
        ],
      );
    }

    if (_c != null) {
      final ctrl = _c!;
      child = AnimatedBuilder(
        animation: ctrl,
        child: child,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, math.sin(ctrl.value * 2 * math.pi) * widget.size * 0.025),
          child: c,
        ),
      );
    }

    return RepaintBoundary(child: SizedBox.square(dimension: widget.size, child: child));
  }
}

const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

Color _accent(AppBadge b) => b.isStreak ? const Color(0xFFFF7A1A) : const Color(0xFF8B5CF6);

/// Metal palettes by tier: [highlight, mid, shadow].
List<Color> metalFor(int tier) {
  switch (tier) {
    case 1:
      return const [Color(0xFFFFD2A6), Color(0xFFD4803F), Color(0xFF7A3B12)];
    case 2:
      return const [Color(0xFFFFFFFF), Color(0xFFB9C3D1), Color(0xFF586577)];
    case 3:
      return const [Color(0xFFFFF4B0), Color(0xFFF5B70A), Color(0xFF8F5A00)];
    default:
      return const [Color(0xFFFFE3F1), Color(0xFFB57BFF), Color(0xFF3B1F7A)];
  }
}

class _MedalPainter extends CustomPainter {
  final AppBadge badge;
  final Animation<double>? shine;
  final bool showProgress;

  const _MedalPainter({required this.badge, required this.shine, required this.showProgress}) : super(repaint: shine);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s * 0.44);
    final outerR = s * 0.36;
    final metal = metalFor(badge.tier);
    final legendary = badge.tier >= 4;

    _drawRibbon(canvas, s, center, outerR);

    // Drop shadow under the medal body.
    final bodyPath = badge.isStreak ? _hexagon(center, outerR) : _rosette(center, outerR, 14);
    canvas.drawPath(
      bodyPath.shift(Offset(0, s * 0.03)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // Metal rim.
    final rimRect = Rect.fromCircle(center: center, radius: outerR);
    final rimPaint = Paint()
      ..shader = (legendary
              ? SweepGradient(
                  colors: const [
                    Color(0xFFFF5A4E),
                    Color(0xFFFFB020),
                    Color(0xFF34D399),
                    Color(0xFF38BDF8),
                    Color(0xFF8B5CF6),
                    Color(0xFFD9268A),
                    Color(0xFFFF5A4E),
                  ],
                  transform: GradientRotation((shine?.value ?? 0) * 2 * math.pi),
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [metal[0], metal[1], metal[2], metal[1]],
                  stops: const [0.0, 0.45, 0.8, 1.0],
                ))
          .createShader(rimRect);
    canvas.drawPath(bodyPath, rimPaint);

    // Bevel highlight on the rim edge.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Inner face.
    final faceR = outerR * 0.76;
    final facePath = badge.isStreak ? _hexagon(center, faceR) : (Path()..addOval(Rect.fromCircle(center: center, radius: faceR)));
    final faceRect = Rect.fromCircle(center: center, radius: faceR);
    canvas.drawPath(
      facePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.0,
          colors: badge.isStreak
              ? const [Color(0xFF3A1420), Color(0xFF1A0B14)]
              : const [Color(0xFF2A1F4D), Color(0xFF110B26)],
        ).createShader(faceRect),
    );
    canvas.drawPath(
      facePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..color = metal[2].withValues(alpha: 0.9),
    );

    // Emblem glow.
    canvas.drawCircle(
      center,
      faceR * 0.8,
      Paint()
        ..shader = RadialGradient(colors: [
          _accent(badge).withValues(alpha: 0.45),
          _accent(badge).withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: faceR * 0.8)),
    );

    if (badge.isStreak) {
      _drawFlame(canvas, center.translate(0, -faceR * 0.12), faceR * 1.0, badge.tier);
    } else {
      _drawMoon(canvas, center.translate(0, -faceR * 0.12), faceR * 0.95);
    }

    _drawLabelPlate(canvas, s, center, faceR, metal);
    _drawTierPips(canvas, center, outerR, s, metal);

    // Specular sweep (only when animating).
    final sv = shine?.value;
    if (sv != null) {
      final x = -1.6 + sv * 3.2;
      canvas.save();
      canvas.clipPath(bodyPath);
      canvas.drawRect(
        rimRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(x - 0.35, -1),
            end: Alignment(x + 0.35, 1),
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)],
          ).createShader(rimRect),
      );
      canvas.restore();
    }
  }

  void _drawRibbon(Canvas canvas, double s, Offset center, double r) {
    final colors = badge.isStreak
        ? const [Color(0xFFFF7A1A), Color(0xFFC2410C)]
        : const [Color(0xFF8B5CF6), Color(0xFF5B21B6)];
    final top = center.dy + r * 0.55;
    final bottom = s * 0.98;
    for (final dir in [-1.0, 1.0]) {
      final x0 = center.dx + dir * r * 0.18;
      final x1 = center.dx + dir * r * 0.72;
      final path = Path()
        ..moveTo(x0, top)
        ..lineTo(x1, top)
        ..lineTo(x1 + dir * r * 0.04, bottom)
        ..lineTo((x0 + x1) / 2 + dir * r * 0.02, bottom - s * 0.07)
        ..lineTo(x0 - dir * r * 0.08, bottom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)
              .createShader(path.getBounds()),
      );
      // Stripe.
      canvas.drawLine(
        Offset((x0 + x1) / 2, top),
        Offset((x0 + x1) / 2 + dir * r * 0.0, bottom - s * 0.08),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = s * 0.018,
      );
    }
  }

  Path _hexagon(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _rosette(Offset c, double r, int petals) {
    final p = Path();
    final steps = petals * 2;
    for (var i = 0; i <= steps; i++) {
      final a = -math.pi / 2 + i * math.pi / petals;
      final rr = i.isEven ? r : r * 0.9;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  void _drawFlame(Canvas canvas, Offset c, double size, int tier) {
    final w = size * 0.62, h = size * 0.78;
    final o = Offset(c.dx - w / 2, c.dy - h / 2);
    Offset u(double x, double y) => Offset(o.dx + x * w, o.dy + y * h);

    final outer = Path()
      ..moveTo(u(0.5, 0).dx, u(0.5, 0).dy)
      ..cubicTo(u(0.62, 0.22).dx, u(0.62, 0.22).dy, u(0.9, 0.36).dx, u(0.9, 0.36).dy, u(0.9, 0.63).dx, u(0.9, 0.63).dy)
      ..cubicTo(u(0.9, 0.86).dx, u(0.9, 0.86).dy, u(0.72, 1).dx, u(0.72, 1).dy, u(0.5, 1).dx, u(0.5, 1).dy)
      ..cubicTo(u(0.28, 1).dx, u(0.28, 1).dy, u(0.1, 0.86).dx, u(0.1, 0.86).dy, u(0.1, 0.63).dx, u(0.1, 0.63).dy)
      ..cubicTo(u(0.1, 0.46).dx, u(0.1, 0.46).dy, u(0.22, 0.36).dx, u(0.22, 0.36).dy, u(0.3, 0.25).dx, u(0.3, 0.25).dy)
      ..cubicTo(u(0.33, 0.4).dx, u(0.33, 0.4).dy, u(0.4, 0.47).dx, u(0.4, 0.47).dy, u(0.47, 0.49).dx, u(0.47, 0.49).dy)
      ..cubicTo(u(0.42, 0.3).dx, u(0.42, 0.3).dy, u(0.45, 0.13).dx, u(0.45, 0.13).dy, u(0.5, 0).dx, u(0.5, 0).dy)
      ..close();
    final bounds = outer.getBounds();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD34D), Color(0xFFFF7A1A), Color(0xFFE11D2E)],
        ).createShader(bounds),
    );

    final inner = Path()
      ..moveTo(u(0.5, 0.48).dx, u(0.5, 0.48).dy)
      ..cubicTo(u(0.62, 0.6).dx, u(0.62, 0.6).dy, u(0.7, 0.72).dx, u(0.7, 0.72).dy, u(0.7, 0.82).dx, u(0.7, 0.82).dy)
      ..cubicTo(u(0.7, 0.93).dx, u(0.7, 0.93).dy, u(0.61, 1).dx, u(0.61, 1).dy, u(0.5, 1).dx, u(0.5, 1).dy)
      ..cubicTo(u(0.39, 1).dx, u(0.39, 1).dy, u(0.3, 0.93).dx, u(0.3, 0.93).dy, u(0.3, 0.82).dx, u(0.3, 0.82).dy)
      ..cubicTo(u(0.3, 0.7).dx, u(0.3, 0.7).dy, u(0.41, 0.6).dx, u(0.41, 0.6).dy, u(0.5, 0.48).dx, u(0.5, 0.48).dy)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFE08A)],
        ).createShader(inner.getBounds()),
    );
  }

  void _drawMoon(Canvas canvas, Offset c, double size) {
    final r = size * 0.32;
    final moonC = c.translate(-r * 0.12, 0);
    final full = Path()..addOval(Rect.fromCircle(center: moonC, radius: r));
    final bite = Path()..addOval(Rect.fromCircle(center: moonC.translate(r * 0.5, -r * 0.32), radius: r * 0.86));
    final crescent = Path.combine(PathOperation.difference, full, bite);
    canvas.drawPath(
      crescent,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7D6), Color(0xFFFFC94D)],
        ).createShader(Rect.fromCircle(center: moonC, radius: r)),
    );
    _star(canvas, c.translate(r * 0.75, -r * 0.55), r * 0.26, const Color(0xFFFFF7D6));
    _star(canvas, c.translate(r * 0.95, r * 0.25), r * 0.16, const Color(0xFFE9D5FF));
    _star(canvas, c.translate(r * 0.35, r * 0.05), r * 0.1, const Color(0xFFFFFFFF));
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    // Four-point sparkle.
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _drawLabelPlate(Canvas canvas, double s, Offset center, double faceR, List<Color> metal) {
    final tp = TextPainter(
      text: TextSpan(
        text: badge.shortLabel,
        style: TextStyle(
          color: const Color(0xFF1A1206),
          fontSize: s * 0.095,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final plateW = math.max(tp.width + s * 0.09, s * 0.26);
    final plateH = s * 0.14;
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, faceR * 0.62), width: plateW, height: plateH),
      Radius.circular(plateH / 2),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [metal[0], metal[1]])
            .createShader(plate.outerRect),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.008
        ..color = metal[2],
    );
    tp.paint(canvas, Offset(plate.center.dx - tp.width / 2, plate.center.dy - tp.height / 2));
  }

  void _drawTierPips(Canvas canvas, Offset center, double outerR, double s, List<Color> metal) {
    final n = badge.tier.clamp(1, 4);
    final gap = s * 0.06;
    final y = center.dy - outerR - s * 0.0;
    final startX = center.dx - (n - 1) * gap / 2;
    for (var i = 0; i < n; i++) {
      final c = Offset(startX + i * gap, y + s * 0.045);
      _star(canvas, c, s * 0.026, Colors.white.withValues(alpha: 0.95));
    }
  }

  @override
  bool shouldRepaint(covariant _MedalPainter old) =>
      old.badge.code != badge.code || old.badge.earned != badge.earned || old.shine != shine;
}

class _ProgressArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  const _ProgressArcPainter(this.percent, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Rect.fromCircle(center: Offset(s / 2, s * 0.44), radius: s * 0.43);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = const Color(0xFFE2E8F0),
    );
    if (percent > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * percent,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.03
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter old) => old.percent != percent || old.color != color;
}
