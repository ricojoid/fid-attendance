import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/live_events.dart';
import 'widgets/splash_overlay.dart';
import 'widgets/theme_decor.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the last used theme before the first frame (no flash of wrong colours).
  final results = await Future.wait([ApiService.getToken(), ApiService.loadSavedTheme()]);
  final token = results[0];
  AppColors.palette = AppPalette.of(results[1]);
  runApp(MyApp(isLoggedIn: token != null));
  // Slide the 30-day session forward without blocking start-up.
  if (token != null) ApiService.refreshSession(force: true);
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveEvents.navigatorKey = rootNavigatorKey;
    ApiService.sessionExpiredNotifier.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiService.sessionExpiredNotifier.removeListener(_onSessionExpired);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      LiveEvents.stop(); // no open connection while in the background
    }
    if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away >= _splashAfter) _splashTrigger.value++;
      ApiService.refreshSession();
      // Pick up profile changes made on the web dashboard (e.g. new photo).
      ApiService.getToken().then((t) {
        if (t != null) {
          ApiService.getMe(forceRefresh: true);
          LiveEvents.start();
        }
      });
    }
  }

  void _onSessionExpired() {
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _themeCode = ApiService.themeNotifier.value;

  // Splash replays when returning after a while in the background.
  final _splashTrigger = ValueNotifier<int>(0);
  DateTime? _pausedAt;
  static const _splashAfter = Duration(seconds: 10);

  /// Theme colours are read through AppColors getters, so after a switch we
  /// mark the whole element tree dirty once to repaint everything.
  void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.isLoggedIn;
    return ValueListenableBuilder<String>(
      valueListenable: ApiService.themeNotifier,
      builder: (context, code, _) {
        final palette = AppPalette.of(code);
        AppColors.palette = palette;
        if (code != _themeCode) {
          _themeCode = code;
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
        }
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'FID-A',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(palette),
          themeAnimationDuration: const Duration(milliseconds: 450),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: Stack(
              children: [
                if (child != null) child,
                Positioned.fill(child: ThemeDecorLayer(decor: palette.decor)),
                Positioned.fill(child: SplashOverlay(trigger: _splashTrigger)),
              ],
            ),
          ),
          home: isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
        );
      },
    );
  }
}
