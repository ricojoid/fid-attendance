import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// Slowly drifting colour blobs ("aurora") behind hero surfaces.
///
/// Performance notes:
///  * Blobs are radial-gradient circles (a single shader each), never
///    MaskFilter blurs, so each frame is a handful of cheap draw calls.
///  * Wrapped in a RepaintBoundary so only this layer repaints per frame.
///  * The ticker obeys TickerMode, so it stops on hidden tabs, and it idles
///    entirely when the OS requests reduced motion.
class AuroraBackground extends StatefulWidget {
  final List<Color>? colors; // defaults to the theme's aurora
  final Color? base; // defaults to the theme's ink
  final Widget? child;
  final BorderRadius borderRadius;
  final Duration period;

  const AuroraBackground({
    super.key,
    this.colors,
    this.base,
    this.child,
    this.borderRadius = BorderRadius.zero,
    this.period = const Duration(seconds: 14),
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AuroraPainter(animation: _c, colors: widget.colors ?? AppColors.palette.aurora, base: widget.base ?? AppColors.ink),
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Color> colors;
  final Color base;

  const _AuroraPainter({required this.animation, required this.colors, required this.base}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);

    final t = animation.value * 2 * math.pi;
    final w = size.width, h = size.height;
    final r = math.max(w, h) * 0.62;

    // Each blob follows its own Lissajous path so the motion never looks looped.
    final centers = [
      Offset(w * (0.18 + 0.12 * math.sin(t)), h * (0.20 + 0.18 * math.cos(t * 1.3))),
      Offset(w * (0.86 + 0.10 * math.cos(t * 0.8)), h * (0.30 + 0.22 * math.sin(t * 1.1))),
      Offset(w * (0.50 + 0.22 * math.sin(t * 0.6 + 1.2)), h * (0.98 + 0.12 * math.cos(t * 0.9))),
    ];

    for (var i = 0; i < centers.length && i < colors.length; i++) {
      final c = centers[i];
      final radius = r * (0.75 + 0.1 * math.sin(t + i));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [colors[i].withValues(alpha: 0.55), colors[i].withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, paint);
    }

    // Subtle diagonal sheen for depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent, Colors.black.withValues(alpha: 0.18)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.colors != colors || old.base != base;
}

/// Static decorative dot grid used as texture on hero cards.
class DotGridPainter extends CustomPainter {
  final Color color;
  final double gap;

  const DotGridPainter({this.color = const Color(0x14FFFFFF), this.gap = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter old) => old.color != color || old.gap != gap;
}
