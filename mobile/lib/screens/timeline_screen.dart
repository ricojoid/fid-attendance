import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/badge.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/badge_medal.dart';
import '../widgets/motion.dart';
import '../widgets/tiki_mascot.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}/${t.year}';
}

/// Timeline: share what you did today — text, a photo, or both.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final List<Map<String, dynamic>> _posts = [];
  final Map<String, Map<String, dynamic>> _authors = {};
  int? _nextBefore;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final _scroll = ScrollController();
  bool _wasVisible = false;
  DateTime? _lastLoad;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
    });
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible && _lastLoad != null && DateTime.now().difference(_lastLoad!) > const Duration(seconds: 45)) {
      _refresh();
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _merge(Map<String, dynamic> data, {bool replace = false}) {
    final posts = (data['posts'] as List? ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final authors = (data['authors'] as Map? ?? {}).cast<String, dynamic>();
    authors.forEach((k, v) => _authors[k] = (v as Map).cast<String, dynamic>());
    if (replace) _posts.clear();
    _posts.addAll(posts);
    _nextBefore = (data['next_before'] as num?)?.toInt();
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiService.getTimeline();
      if (!mounted) return;
      setState(() {
        _merge(data, replace: true);
        _error = null;
        _loading = false;
        _lastLoad = DateTime.now();
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

  Future<void> _loadMore() async {
    if (_loadingMore || _nextBefore == null) return;
    _loadingMore = true;
    try {
      final data = await ApiService.getTimeline(before: _nextBefore);
      if (mounted) setState(() => _merge(data));
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _compose() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComposeSheet(),
    );
    if (created != null && mounted) {
      setState(() {
        (created['authors'] as Map? ?? {}).forEach((k, v) => _authors['$k'] = (v as Map).cast<String, dynamic>());
        _posts.insert(0, (created['post'] as Map).cast<String, dynamic>());
      });
      _scroll.animateTo(0, duration: AppMotion.slow, curve: AppMotion.emphasized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Timeline', style: TextStyle(color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                      Text("What's everyone up to today?", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 14),
                      _ComposerBar(onTap: _compose),
                    ],
                  ),
                ),
              ),
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, __) => const Shimmer(height: 260, radius: 24),
                  ),
                )
              else if (_posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TikiMascot(size: 120, mood: TikiMood.idle),
                      const SizedBox(height: 10),
                      Text(_error ?? 'No posts yet', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Be the first to share your day!', style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 120),
                    ],
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final p = _posts[i];
                      return FadeSlideIn.stagger(
                        math.min(i, 6),
                        stepMs: 50,
                        child: _PostCard(
                          key: ValueKey(p['id']),
                          post: p,
                          authors: _authors,
                          onDeleted: () => setState(() => _posts.removeWhere((x) => x['id'] == p['id'])),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposerBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: ApiService.profilePhotoNotifier,
              builder: (context, photo, _) => ValueListenableBuilder<String>(
                valueListenable: ApiService.frameNotifier,
                builder: (context, frame, _) => FramedAvatar(frame: frame, photo: photo, name: '★', size: 36, animate: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Share your day…', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.add_photo_alternate_rounded, color: AppColors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, Map<String, dynamic>> authors;
  final VoidCallback onDeleted;
  const _PostCard({super.key, required this.post, required this.authors, required this.onDeleted});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late bool _liked = widget.post['liked_by_me'] == true;
  late int _likes = (widget.post['like_count'] as num?)?.toInt() ?? 0;
  late int _comments = (widget.post['comment_count'] as num?)?.toInt() ?? 0;
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _toggleLike({bool fromDoubleTap = false}) async {
    if (fromDoubleTap) {
      _burst.forward(from: 0);
      if (_liked) return; // double-tap only likes, never unlikes
    }
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final r = await ApiService.toggleLike((widget.post['id'] as num).toInt());
      if (mounted) {
        setState(() {
          _liked = r['liked'] == true;
          _likes = (r['like_count'] as num?)?.toInt() ?? _likes;
        });
      }
    } catch (_) {}
  }

  Future<void> _openComments() async {
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(postId: (widget.post['id'] as num).toInt()),
    );
    if (added != null && added > 0 && mounted) setState(() => _comments += added);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes the post, its likes and comments.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletePost((widget.post['id'] as num).toInt());
      widget.onDeleted();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final author = widget.authors['${p['user_id']}'] ?? const {};
    final name = (author['name'] ?? 'Someone').toString();
    final top = AppBadge.fromTop(author['top_badge']);
    final text = (p['text'] ?? '').toString();
    final image = (p['image_url'] ?? '').toString();
    final created = DateTime.tryParse((p['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now();
    final w = (p['image_w'] as num?)?.toDouble() ?? 0, h = (p['image_h'] as num?)?.toDouble() ?? 0;
    final ratio = (w > 0 && h > 0) ? (w / h).clamp(0.6, 1.9) : 4 / 3;
    final preview = (p['comments'] as List? ?? []).whereType<Map>().toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(
              children: [
                FramedAvatar(frame: (author['avatar_frame'] ?? '').toString(), photo: (author['avatar_url'] ?? '').toString(), name: name, size: 38, animate: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
                        ),
                        if (top != null) ...[const SizedBox(width: 4), BadgeMedal(badge: top, size: 22, showProgress: false)],
                      ]),
                      Text('${author['department'] ?? ''} · ${timeAgo(created)}', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (p['can_delete'] == true)
                  IconButton(icon: Icon(Icons.more_horiz_rounded, color: AppColors.textFaint), onPressed: _delete),
              ],
            ),
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(text, style: TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.45)),
            ),
          if (image.isNotEmpty)
            GestureDetector(
              onDoubleTap: () => _toggleLike(fromDoubleTap: true),
              onTap: () => Navigator.push(context, PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black,
                pageBuilder: (_, __, ___) => _PhotoViewer(url: ApiConfig.mediaUrl(image), tag: 'post_${p['id']}'),
                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              )),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: ratio.toDouble(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'post_${p['id']}',
                          child: Image.network(
                            ApiConfig.mediaUrl(image),
                            fit: BoxFit.cover,
                            cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                            frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: AppMotion.medium,
                              child: child,
                            ),
                            loadingBuilder: (context, child, progress) => progress == null ? child : const Shimmer(height: 400, radius: 0),
                            errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: Icon(Icons.broken_image_rounded, color: AppColors.textFaint)),
                          ),
                        ),
                        // Heart burst on double tap.
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _burst,
                            builder: (context, _) {
                              final v = _burst.value;
                              if (v == 0 || v == 1) return const SizedBox.shrink();
                              final scale = Curves.elasticOut.transform((v / 0.6).clamp(0.0, 1.0));
                              return Center(
                                child: Opacity(
                                  opacity: (1 - ((v - 0.6) / 0.4).clamp(0.0, 1.0)),
                                  child: Transform.scale(
                                    scale: scale * 1.2,
                                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 96, shadows: [Shadow(blurRadius: 24, color: Colors.black38)]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _liked ? const Color(0xFFF43F5E) : AppColors.textMuted,
                  label: '$_likes',
                  bounce: _liked,
                  onTap: () => _toggleLike(),
                ),
                _ActionButton(icon: Icons.chat_bubble_outline_rounded, color: AppColors.textMuted, label: '$_comments', onTap: _openComments),
              ],
            ),
          ),
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GestureDetector(
                onTap: _openComments,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${widget.authors['${c['user_id']}']?['name'] ?? ''}  ', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                            TextSpan(text: (c['text'] ?? '').toString(), style: TextStyle(color: AppColors.textMuted)),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (_comments > preview.length)
                      Text('View all $_comments comments', style: TextStyle(color: AppColors.textFaint, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool bounce;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.label, required this.onTap, this.bounce = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.85,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
              child: Icon(icon, key: ValueKey('$icon$bounce'), color: color, size: 24),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String url;
  final String tag;
  const _PhotoViewer({required this.url, required this.tag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      onVerticalDragEnd: (_) => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: Hero(tag: tag, child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- compose

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _text = TextEditingController();
  Uint8List? _bytes;
  String? _filename;
  int? _w, _h;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final img = await decodeImageFromList(bytes);
      setState(() {
        _bytes = bytes;
        _filename = f.name;
        _w = img.width;
        _h = img.height;
      });
      img.dispose();
    } catch (e) {
      setState(() => _error = 'Could not open the photo');
    }
  }

  Future<void> _post() async {
    if (_text.text.trim().isEmpty && _bytes == null) {
      setState(() => _error = 'Write something or add a photo');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final res = await ApiService.createPost(text: _text.text.trim(), imageBytes: _bytes, filename: _filename, w: _w, h: _h);
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _posting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = !_posting && (_text.text.trim().isNotEmpty || _bytes != null);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('New post', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Pressable(
                    onTap: canPost ? _post : null,
                    child: AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: canPost ? 1 : 0.45,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(14)),
                        child: _posting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                maxLength: 2000,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'What did you do today? 🚀', counterText: ''),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                child: _bytes == null
                    ? const SizedBox(width: double.infinity)
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: Image.memory(_bytes!, fit: BoxFit.cover, width: double.infinity),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Pressable(
                              onTap: () => setState(() => _bytes = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AttachChip(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: () => _pick(ImageSource.gallery)),
                  const SizedBox(width: 10),
                  _AttachChip(icon: Icons.photo_camera_rounded, label: 'Camera', onTap: () => _pick(ImageSource.camera)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: AppColors.red, size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- comments

class _CommentsSheet extends StatefulWidget {
  final int postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic> _authors = {};
  bool _loading = true;
  bool _sending = false;
  int _added = 0;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    ApiService.getComments(widget.postId).then((d) {
      if (!mounted) return;
      setState(() {
        _list = (d['comments'] as List? ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _authors = (d['authors'] as Map? ?? {}).cast<String, dynamic>();
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = await ApiService.addComment(widget.postId, text);
      final me = await ApiService.getMe();
      if (!mounted) return;
      setState(() {
        _list.add((r['comment'] as Map).cast<String, dynamic>());
        _authors['${me['id']}'] ??= {'name': me['name'], 'avatar_url': me['avatar_url'], 'avatar_frame': me['avatar_frame']};
        _input.clear();
        _added++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _added);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Comments', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              Flexible(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())
                    : _list.isEmpty
                        ? Padding(padding: const EdgeInsets.all(30), child: Text('No comments yet — say something nice!', style: TextStyle(color: AppColors.textMuted)))
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final c = _list[i];
                              final a = (_authors['${c['user_id']}'] as Map?)?.cast<String, dynamic>() ?? {};
                              final at = DateTime.tryParse((c['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FramedAvatar(frame: (a['avatar_frame'] ?? '').toString(), photo: (a['avatar_url'] ?? '').toString(), name: (a['name'] ?? '?').toString(), size: 30, animate: false),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${a['name'] ?? ''} · ${timeAgo(at)}', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                            const SizedBox(height: 2),
                                            Text((c['text'] ?? '').toString(), style: TextStyle(color: AppColors.text, fontSize: 13.5)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.paddingOf(context).bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: 'Add a comment…', counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(gradient: AppGradients.brand, shape: BoxShape.circle),
                        child: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
