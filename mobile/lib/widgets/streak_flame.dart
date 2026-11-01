import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'motion.dart';

/// Animated flame icon for streaks. Flickers while [lit]; grey & still when
/// the streak is at risk (today not checked in yet) or zero.
class StreakFlame extends StatefulWidget {
  final double size;
  final bool lit;

  const StreakFlame({super.key, this.size = 28, this.lit = true});

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.lit && !reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size * 0.8, widget.size),
        painter: FlamePainter(animation: _c, lit: widget.lit),
      ),
    );
  }
}

class FlamePainter extends CustomPainter {
  final Animation<double> animation;
  final bool lit;

  const FlamePainter({required this.animation, required this.lit}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;
    final w = size.width, h = size.height;
    // Flicker: sway tip and breathe height with two incommensurate sines.
    final sway = lit ? math.sin(t) * 0.05 + math.sin(t * 2.7) * 0.025 : 0.0;
    final breathe = lit ? 1 + math.sin(t * 1.9) * 0.04 : 1.0;

    Offset u(double x, double y) => Offset(x * w + sway * w * (1 - y), h - (1 - y) * h * breathe);

    Path flame(double inset) {
      final a = inset, b = 1 - inset;
      Offset p(double x, double y) => u(a + (b - a) * x, y < 0.5 ? y + inset * 0.6 : y);
      return Path()
        ..moveTo(p(0.5, 0).dx, p(0.5, 0).dy)
        ..cubicTo(p(0.64, 0.22).dx, p(0.64, 0.22).dy, p(0.95, 0.38).dx, p(0.95, 0.38).dy, p(0.95, 0.64).dx, p(0.95, 0.64).dy)
        ..cubicTo(p(0.95, 0.87).dx, p(0.95, 0.87).dy, p(0.74, 1).dx, p(0.74, 1).dy, p(0.5, 1).dx, p(0.5, 1).dy)
        ..cubicTo(p(0.26, 1).dx, p(0.26, 1).dy, p(0.05, 0.87).dx, p(0.05, 0.87).dy, p(0.05, 0.64).dx, p(0.05, 0.64).dy)
        ..cubicTo(p(0.05, 0.46).dx, p(0.05, 0.46).dy, p(0.2, 0.36).dx, p(0.2, 0.36).dy, p(0.28, 0.24).dx, p(0.28, 0.24).dy)
        ..cubicTo(p(0.32, 0.4).dx, p(0.32, 0.4).dy, p(0.4, 0.47).dx, p(0.4, 0.47).dy, p(0.47, 0.5).dx, p(0.47, 0.5).dy)
        ..cubicTo(p(0.41, 0.3).dx, p(0.41, 0.3).dy, p(0.44, 0.13).dx, p(0.44, 0.13).dy, p(0.5, 0).dx, p(0.5, 0).dy)
        ..close();
    }

    final rect = Offset.zero & size;
    final outer = flame(0);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: lit
              ? const [Color(0xFFFFD34D), Color(0xFFFF7A1A), Color(0xFFE11D2E)]
              : const [Color(0xFFCBD5E1), Color(0xFF94A3B8), Color(0xFF64748B)],
        ).createShader(rect),
    );

    final innerPath = Path()
      ..addOval(Rect.fromCenter(center: u(0.5, 0.78), width: w * 0.42, height: h * 0.4 * breathe));
    canvas.drawPath(
      innerPath,
      Paint()
        ..shader = RadialGradient(
          colors: lit
              ? const [Color(0xFFFFFBEB), Color(0xFFFFE08A), Color(0x00FFE08A)]
              : const [Color(0xFFF1F5F9), Color(0x00F1F5F9)],
        ).createShader(innerPath.getBounds()),
    );
  }

  @override
  bool shouldRepaint(covariant FlamePainter old) => old.lit != lit;
}
