import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/frame_picker.dart';
import '../widgets/motion.dart';

/// App settings: theme (appearance) and avatar frame.
class SettingsScreen extends StatefulWidget {
  final String? photo;
  final String name;
  const SettingsScreen({super.key, this.photo, this.name = ''});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const _decorEmoji = {
  ThemeDecor.none: '',
  ThemeDecor.leaves: '🍃',
  ThemeDecor.bubbles: '🫧',
  ThemeDecor.petals: '🌸',
  ThemeDecor.monsters: '👾',
  ThemeDecor.goldDust: '✨',
  ThemeDecor.stars: '🌌',
  ThemeDecor.candy: '🍬',
  ThemeDecor.clouds: '☁️',
};

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _themes = [];
  bool _loading = true;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getMyThemes();
      if (!mounted) return;
      setState(() {
        _themes = (data['themes'] as List? ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _apply(String code) async {
    setState(() => _busy = code);
    try {
      await ApiService.equipTheme(code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<String>(
        valueListenable: ApiService.themeNotifier,
        builder: (context, active, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            Text('APPEARANCE', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.4)),
            const SizedBox(height: 10),
            Text('App theme', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('Light and Dark are free. Unlock the others with badges, or receive one from a Super Admin.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 16),
            if (_loading)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: List.generate(4, (_) => const Shimmer(height: 200, radius: 22)),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: AppColors.red))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _themes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                itemBuilder: (context, i) {
                  final t = _themes[i];
                  final code = t['code'].toString();
                  return FadeSlideIn.stagger(
                    i,
                    stepMs: 40,
                    child: _ThemeCard(
                      data: t,
                      active: active == code,
                      busy: _busy == code,
                      onApply: t['owned'] == true && active != code && _busy == null ? () => _apply(code) : null,
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            Text('PROFILE', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.4)),
            const SizedBox(height: 10),
            Pressable(
              pressedScale: 0.98,
              onTap: () => showFramePicker(context, photo: widget.photo, name: widget.name),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avatar frame', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                          Text('Show off a frame around your photo', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool active;
  final bool busy;
  final VoidCallback? onApply;
  const _ThemeCard({required this.data, required this.active, required this.busy, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final code = data['code'].toString();
    final owned = data['owned'] == true;
    final p = AppPalette.of(code);
    final rarity = (data['rarity'] as num?)?.toInt() ?? 1;
    const rarityNames = {1: 'Common', 2: 'Rare', 3: 'Epic', 4: 'Legendary'};
    const rarityColors = {1: Color(0xFF64748B), 2: Color(0xFF2563EB), 3: Color(0xFF9333EA), 4: Color(0xFFF59E0B)};

    return Pressable(
      pressedScale: 0.97,
      onTap: onApply,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? AppColors.red : AppColors.line, width: active ? 2.2 : 1),
          boxShadow: active ? AppShadows.glow(AppColors.red, strength: 0.18) : AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini app preview drawn with the theme's own palette.
            Expanded(
              child: Stack(
                children: [
                  Opacity(opacity: owned ? 1 : 0.45, child: _Preview(p: p)),
                  if (!owned)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  if (_decorEmoji[p.decor]!.isNotEmpty)
                    Positioned(right: 6, top: 4, child: Text(_decorEmoji[p.decor]!, style: const TextStyle(fontSize: 16))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text((data['name'] ?? code).toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                if (active) Icon(Icons.check_circle_rounded, color: AppColors.red, size: 18),
                if (busy) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            Text((rarityNames[rarity] ?? '').toUpperCase(),
                style: TextStyle(color: rarityColors[rarity], fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(
              owned ? (data['description'] ?? '').toString() : (data['unlock_hint'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final AppPalette p;
  const _Preview({required this.p});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: p.bg,
        child: Column(
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.aurora[0], p.ink3, p.aurora[1]], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.bottomLeft,
              child: Container(width: 34, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4))),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [p.primaryLight, p.primary, p.primaryDeep]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < 2; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      height: 14,
                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: p.line)),
                      child: Row(children: [
                        const SizedBox(width: 5),
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Container(width: 30, height: 4, color: p.textFaint.withValues(alpha: 0.6)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
