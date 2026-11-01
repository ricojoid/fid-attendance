import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';

/// Live updates pushed by the server over Server-Sent Events.
///
///  * One long-lived connection while the app is in the foreground; it is
///    closed when the app goes to the background (no battery drain) and
///    reopened on resume.
///  * Reconnects with backoff if the network drops.
///  * A slow fallback poll keeps data fresh where streaming is unavailable
///    (e.g. the Flutter web build).
class LiveEvents {
  LiveEvents._();

  static final ValueNotifier<List<Map<String, dynamic>>> announcements = ValueNotifier(const []);
  static final ValueNotifier<bool> connected = ValueNotifier(false);

  static GlobalKey<NavigatorState>? navigatorKey;

  static http.Client? _client;
  static StreamSubscription<String>? _sub;
  static Timer? _retry;
  static Timer? _poll;
  static int _attempt = 0;
  static bool _running = false;

  /// Begin listening (idempotent). Call after login / on app start.
  static Future<void> start() async {
    if (_running) return;
    _running = true;
    await refreshAnnouncements();
    _connect();
    _poll ??= Timer.periodic(const Duration(seconds: 60), (_) {
      if (!connected.value) refreshAnnouncements();
    });
  }

  /// Stop everything (logout or app in background).
  static void stop() {
    _running = false;
    _retry?.cancel();
    _retry = null;
    _poll?.cancel();
    _poll = null;
    _disconnect();
  }

  static void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    connected.value = false;
  }

  static Future<void> refreshAnnouncements() async {
    final list = await ApiService.getAnnouncements();
    announcements.value = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static Future<void> _connect() async {
    if (!_running || kIsWeb) return; // browsers: fallback poll only
    final token = await ApiService.getToken();
    if (token == null) return;
    _disconnect();
    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse('${ApiConfig.baseUrl}/events'))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream';
      final res = await client.send(req);
      if (res.statusCode != 200) throw Exception('events ${res.statusCode}');
      connected.value = true;
      _attempt = 0;

      String event = 'message';
      final data = StringBuffer();
      _sub = res.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.isEmpty) {
            if (data.isNotEmpty) _dispatch(event, data.toString());
            event = 'message';
            data.clear();
          } else if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            if (data.isNotEmpty) data.write('\n');
            data.write(line.substring(5).trimLeft());
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      // Catch up on anything published while we were disconnected.
      refreshAnnouncements();
    } catch (e) {
      debugPrint('LiveEvents connect failed: $e');
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    connected.value = false;
    if (!_running) return;
    _retry?.cancel();
    final secs = [2, 4, 8, 15, 30][_attempt.clamp(0, 4)];
    _attempt++;
    _retry = Timer(Duration(seconds: secs), _connect);
  }

  static void _dispatch(String event, String raw) {
    if (event != 'announcement') return;
    Map<String, dynamic> msg;
    try {
      msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final action = msg['action'];
    final list = [...announcements.value];
    if (action == 'deleted') {
      list.removeWhere((a) => '${a['id']}' == '${msg['id']}');
      announcements.value = list;
      return;
    }
    final ann = (msg['announcement'] as Map?)?.cast<String, dynamic>();
    if (ann == null) return;
    list.removeWhere((a) => a['id'] == ann['id']);
    if (ann['is_active'] == false) {
      announcements.value = list;
      return;
    }
    list.insert(0, ann);
    announcements.value = list;
    if (action == 'created') {
      ApiService.refreshInboxCount();
      _showBanner(ann);
    }
  }

  // ------------------------------------------------------------ in-app banner
  static OverlayEntry? _banner;

  static void _showBanner(Map<String, dynamic> ann) {
    final overlay = navigatorKey?.currentState?.overlay;
    if (overlay == null) return;
    _banner?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _LiveBanner(
        title: (ann['title'] ?? 'New announcement').toString(),
        category: (ann['category'] ?? 'GENERAL').toString(),
        onDone: () {
          if (_banner == entry) _banner = null;
          entry.remove();
        },
      ),
    );
    _banner = entry;
    overlay.insert(entry);
  }
}

class _LiveBanner extends StatefulWidget {
  final String title;
  final String category;
  final VoidCallback onDone;
  const _LiveBanner({required this.title, required this.category, required this.onDone});

  @override
  State<_LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends State<_LiveBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 5), _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    final important = widget.category == 'IMPORTANT';
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -120 * (1 - curve.value)),
          child: Opacity(opacity: _c.value.clamp(0.0, 1.0), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _hide,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _hide();
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: AppGradients.ink,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(important ? '❗' : '📢', style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('NEW ANNOUNCEMENT · LIVE',
                              style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ]),
                        const SizedBox(height: 3),
                        Text(widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
