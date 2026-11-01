import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'avatar_frame.dart';
import 'motion.dart';

/// Bottom sheet listing every avatar frame: owned ones can be equipped,
/// locked ones explain how to unlock them.
Future<void> showFramePicker(BuildContext context, {required String? photo, required String name}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FramePickerSheet(photo: photo, name: name),
  );
}

class _FramePickerSheet extends StatefulWidget {
  final String? photo;
  final String name;
  const _FramePickerSheet({required this.photo, required this.name});

  @override
  State<_FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<_FramePickerSheet> {
  List<Map<String, dynamic>> _frames = [];
  String _equipped = ApiService.frameNotifier.value;
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
      final data = await ApiService.getMyFrames();
      if (!mounted) return;
      setState(() {
        _frames = (data['frames'] as List? ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _equipped = (data['equipped'] ?? '').toString();
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

  Future<void> _equip(String code) async {
    setState(() => _busy = code);
    try {
      await ApiService.equipFrame(code);
      if (mounted) setState(() => _equipped = code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = _frames.where((f) => f['owned'] == true).length;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: SizedBox(
                    key: ValueKey(_equipped),
                    width: 84,
                    height: 84,
                    child: Center(child: FramedAvatar(frame: _equipped, photo: widget.photo, name: widget.name, size: 62)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Avatar frames', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      Text('$owned of ${_frames.length} unlocked · earn badges or get one from a Super Admin',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(_error!, style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
            ),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                : GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(18, 10, 18, 24 + MediaQuery.paddingOf(context).bottom),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: _frames.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _tile(code: '', name: 'No frame', sub: 'Classic', owned: true, rarity: 0);
                      final f = _frames[i - 1];
                      return _tile(
                        code: f['code'].toString(),
                        name: (f['name'] ?? '').toString(),
                        sub: f['owned'] == true ? (f['granted_by'] != null ? 'from ${f['granted_by']}' : 'Unlocked') : (f['unlock_hint'] ?? '').toString(),
                        owned: f['owned'] == true,
                        rarity: (f['rarity'] as num?)?.toInt() ?? 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tile({required String code, required String name, required String sub, required bool owned, required int rarity}) {
    final active = _equipped == code;
    final rc = kRarityColors[rarity] ?? AppColors.textFaint;
    return Pressable(
      onTap: owned && !active && _busy == null ? () => _equip(code) : null,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: active ? AppColors.redSoft.withValues(alpha: 0.6) : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.red : AppColors.line, width: active ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: owned ? 1 : 0.35,
                      child: ColorFiltered(
                        colorFilter: owned
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                            : const ColorFilter.matrix([0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0, 0, 0, 1, 0]),
                        child: FramedAvatar(frame: code, photo: widget.photo, name: widget.name, size: 46, animate: owned),
                      ),
                    ),
                    if (!owned)
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: CircleAvatar(radius: 11, backgroundColor: AppColors.ink, child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
            Text(name, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, height: 1.15)),
            if (rarity > 0)
              Text((kRarityNames[rarity] ?? '').toUpperCase(),
                  style: TextStyle(color: rc, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textFaint, fontSize: 9.5, height: 1.2)),
            if (active)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('EQUIPPED', style: TextStyle(color: AppColors.red, fontSize: 9.5, fontWeight: FontWeight.w900)),
              )
            else if (_busy == code)
              const Padding(padding: EdgeInsets.only(top: 4), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ),
      ),
    );
  }
}
