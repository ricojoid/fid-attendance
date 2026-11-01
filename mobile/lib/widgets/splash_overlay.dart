import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aurora_background.dart';
import 'tiki_mascot.dart';

/// Animated splash shown on cold start and when the user comes back to the
/// app after it was in the background for a while (e.g. after pressing Home).
///
/// It is an overlay above the app, so the real UI loads underneath and is
/// revealed with a smooth zoom-fade — no extra waiting for the user.
class SplashOverlay extends StatefulWidget {
  /// Bump to replay the splash (e.g. on resume).
  final ValueNotifier<int> trigger;
  const SplashOverlay({super.key, required this.trigger});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _visible = true;
  bool _short = false;

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_replay);
    _play(const Duration(milliseconds: 2100));
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_replay);
    _c.dispose();
    super.dispose();
  }

  void _replay() {
    _short = true;
    _play(const Duration(milliseconds: 1400));
  }

  Future<void> _play(Duration d) async {
    if (!mounted) return;
    setState(() => _visible = true);
    _c.duration = d;
    await _c.forward(from: 0);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Timeline: 0–0.25 mascot pops, 0.15–0.6 letters, 0.78–1 exit.
        final exit = Curves.easeInCubic.transform(((t - 0.78) / 0.22).clamp(0.0, 1.0));
        final pop = Curves.elasticOut.transform((t / (_short ? 0.4 : 0.32)).clamp(0.0, 1.0));
        final wave = math.sin(t * math.pi * 6) * (1 - exit);

        return IgnorePointer(
          ignoring: exit > 0.6,
          child: Opacity(
            opacity: 1 - exit,
            child: Transform.scale(
              scale: 1 + exit * 0.15,
              child: AuroraBackground(
                child: SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: reduce ? 1 : pop,
                        child: Transform.rotate(
                          angle: wave * 0.08,
                          child: TikiMascot(
                            size: 150,
                            mood: t > 0.45 ? TikiMood.happy : TikiMood.idle,
                            look: Offset(math.sin(t * 6) * 0.6, -0.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Wordmark(progress: ((t - 0.15) / 0.45).clamp(0.0, 1.0)),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: ((t - 0.4) / 0.2).clamp(0.0, 1.0),
                        child: Text(
                          _short ? 'Welcome back! 👋' : 'Show up · Stay consistent · Get recognised',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Loading bar.
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (t / 0.78).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(AppColors.coral),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "FID-A" with letters rising in one after another.
class _Wordmark extends StatelessWidget {
  final double progress;
  const _Wordmark({required this.progress});

  @override
  Widget build(BuildContext context) {
    const letters = ['F', 'I', 'D', '·', 'A'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          Builder(builder: (context) {
            final p = Curves.easeOutBack.transform(((progress - i * 0.12) / 0.5).clamp(0.0, 1.0));
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - p) * 24),
                child: Text(
                  letters[i],
                  style: TextStyle(
                    color: i == 4 ? AppColors.coral : Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
