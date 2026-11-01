import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/celebration.dart';
import '../widgets/motion.dart';
import '../widgets/tiki_mascot.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Field { none, email, password }

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  _Field _field = _Field.none;
  TikiMood _mood = TikiMood.idle;
  int _shakeSeed = 0;

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    void sync() {
      final f = _passwordFocus.hasFocus
          ? _Field.password
          : _emailFocus.hasFocus
              ? _Field.email
              : _Field.none;
      if (f != _field) setState(() => _field = f);
    }

    _emailFocus.addListener(sync);
    _passwordFocus.addListener(sync);
    _emailController.addListener(() {
      if (_field == _Field.email) setState(() {});
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Offset get _look {
    switch (_field) {
      case _Field.email:
        // Eyes follow the caret as the user types.
        final p = math.min(_emailController.text.length / 26, 1.0);
        return Offset(-0.9 + p * 1.8, 1);
      case _Field.password:
        return const Offset(0, 0.6);
      case _Field.none:
        return Offset.zero;
    }
  }

  (String, String) get _bubble {
    if (_mood == TikiMood.happy) return ('Yay! Welcome back! 🎉', "Let's make today count!");
    if (_mood == TikiMood.sad) return ("Hmm, that didn't work 😢", 'Double-check and try again?');
    if (_field == _Field.password) {
      return _obscurePassword
          ? ("I'm not looking! 🙈", 'Your secret is safe.')
          : ('Just a tiny peek… 👀', 'Oops, I saw nothing!');
    }
    if (_field == _Field.email) return ('Ooh, who are you?', 'Let me read that…');
    final h = DateTime.now().hour;
    final hi = h < 11
        ? 'Good morning ☀️'
        : h < 15
            ? 'Good afternoon 🌤️'
            : h < 19
                ? 'Good evening 🌇'
                : 'Working late? 🌙';
    return (hi, "I'm Tiki, your attendance buddy!");
  }

  void _onEdit() {
    if (_mood == TikiMood.sad || _errorMessage != null) {
      setState(() {
        _mood = TikiMood.idle;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
        _mood = TikiMood.sad;
      });
      _shake.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.login(email, password);
      if (!mounted) return;
      setState(() => _mood = TikiMood.happy);
      // Let Tiki celebrate for a moment.
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale:
                  Tween<double>(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: animation, curve: AppMotion.emphasized)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _mood = TikiMood.sad;
        _isLoading = false;
        _shakeSeed++;
      });
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (line1, line2) = _bubble;
    final topPad = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Hero: aurora + floating doodles.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: const AuroraBackground(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
                Positioned.fill(child: FloatingDoodles()),
              ]),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(22, topPad + 18, 22, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    FadeSlideIn(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                            child: Image.asset('assets/fujitsu.png', width: 26, height: 26, cacheWidth: 96),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FID-A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                              Text('FUJITSU OFFICE ATTENDANCE',
                                  style: TextStyle(
                                      color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 9.5, letterSpacing: 1.4)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: AppMotion.medium,
                      curve: AppMotion.emphasized,
                      child: SizedBox(height: keyboard ? 8 : 34),
                    ),

                    // Mascot + speech bubble.
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TikiMascot(
                            size: keyboard ? 110 : 150,
                            look: _look,
                            cover: _field == _Field.password,
                            peek: !_obscurePassword,
                            mood: _mood,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: keyboard ? 50 : 76),
                              child: AnimatedSwitcher(
                                duration: AppMotion.medium,
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: ScaleTransition(
                                    scale: Tween(begin: 0.9, end: 1.0)
                                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                                    alignment: Alignment.bottomLeft,
                                    child: child,
                                  ),
                                ),
                                child: Container(
                                  key: ValueKey(line1),
                                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                                  decoration: BoxDecoration(color: AppColors.surface,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(line1, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(line2, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form card (shakes on error).
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          final v = _shake.value;
                          return Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * 10 * (1 - v), 0), child: child);
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          decoration: BoxDecoration(color: AppColors.surface,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.text.withValues(alpha: 0.12),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Welcome back',
                                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                              const SizedBox(height: 4),
                              Text('Sign in to check in, keep your streak and collect badges.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              AnimatedSize(
                                duration: AppMotion.medium,
                                curve: AppMotion.emphasized,
                                child: _errorMessage == null
                                    ? const SizedBox(width: double.infinity, height: 18)
                                    : Container(
                                        key: ValueKey(_shakeSeed),
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(top: 16, bottom: 4),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.redSoft,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(_errorMessage!,
                                                  style: TextStyle(
                                                      color: AppColors.redDeep, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Email address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                onChanged: (_) => _onEdit(),
                                onSubmitted: (_) => _passwordFocus.requestFocus(),
                                decoration: const InputDecoration(
                                  hintText: 'name@company.com',
                                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onChanged: (_) => _onEdit(),
                                onSubmitted: (_) => _handleLogin(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: AppMotion.fast,
                                      child: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        key: ValueKey(_obscurePassword),
                                        size: 20,
                                      ),
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Pressable(
                                pressedScale: 0.97,
                                onTap: _isLoading || _mood == TikiMood.happy ? null : _handleLogin,
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: _mood == TikiMood.happy ? AppGradients.checkout : AppGradients.brand,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: AppShadows.glow(_mood == TikiMood.happy ? AppColors.success : AppColors.red),
                                  ),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.fast,
                                      child: _mood == TikiMood.happy
                                          ? const Text("Let's go! 🎉",
                                              key: ValueKey('ok'),
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))
                                          : _isLoading
                                              ? const SizedBox(
                                                  key: ValueKey('l'),
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                                                )
                                              : const Row(
                                                  key: ValueKey('t'),
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Sign in',
                                                        style: TextStyle(
                                                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                                  ],
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Text('You stay signed in unless the app is unused for 30 days.',
                                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_mood == TikiMood.happy) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}
