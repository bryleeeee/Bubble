import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

// ============================================================================
// SMOOTH NAVIGATION HELPER
// ============================================================================
void _smoothNavigate(BuildContext context, Widget screen, {bool replace = false}) {
  final route = PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
  
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

// ============================================================================
// SIGN IN SCREEN
// ============================================================================
class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);
  @override 
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;
  bool _loading       = false;

  // Card entrance
  late AnimationController _entryCtrl;
  late Animation<double>   _entrySlide, _entryOpacity;

  // Background bubble drift
  late AnimationController _bgCtrl;
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

    _bgCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entrySlide = Tween<double>(begin: 48.0, end: 0.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    WidgetsBinding.instance.addPostFrameCallback((_) => _entryCtrl.forward());
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _entryCtrl.dispose(); _bgCtrl.dispose(); _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      _smoothNavigate(context, const HomeScreen(), replace: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(e.message ?? 'Authentication failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D263B), // textPrimary
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: size.width, height: size.height,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.5),
            radius: 1.2,
            colors: [Color(0xFFF3E8FF), Color(0xFFF4F0FB), Colors.white],
            stops: [0.0, 0.5, 1.0])),
        child: Stack(
          children: [
            // ── Animated bg bubbles ───────────────────────────────────────
            _BgBubbles(bgCtrl: _bgCtrl, shimmerCtrl: _shimmerCtrl),

            // ── Scrollable body ───────────────────────────────────────────
            SafeArea(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _entrySlide.value),
                  child: Opacity(opacity: _entryOpacity.value, child: child),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo area ─────────────────────────────────────
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Image.asset('assets/images/Bubble_logo.png', height: 56,
                              errorBuilder: (_, __, ___) => const _LogoText()),
                            const SizedBox(height: 8),
                            const Text('welcome back ✦',
                              style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600,
                                color: Color(0xFF6B5F80), letterSpacing: 0.2)), // textSecondary
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Frosted glass card ────────────────────────────
                      _FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  width: 3.5, height: 28,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Color(0xFFD498B2), Color(0xFFA898D4)]), // pastelPink, pastelPurple
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    Text('Sign In',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                                        color: Color(0xFF2D263B), letterSpacing: -0.5)), // textPrimary
                                    Text('pick up where you left off',
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF6B5F80), // textSecondary
                                        fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            _AuthField(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next),
                            const SizedBox(height: 14),

                            _AuthField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _signIn(),
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF9B8EAD), size: 20))), // textTertiary
                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {},
                                child: const Text('Forgot password?',
                                  style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700,
                                    color: Color(0xFFA898D4))))), // pastelPurple

                            const SizedBox(height: 22),

                            _AuthButton(
                              label: 'Sign In',
                              loading: _loading,
                              onTap: _signIn),

                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Color(0xFFE8E4EE), thickness: 1)), // divider
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('or', style: TextStyle(
                                    color: Color(0xFF9B8EAD), // textTertiary
                                    fontSize: 12, fontWeight: FontWeight.w600))),
                                const Expanded(child: Divider(color: Color(0xFFE8E4EE), thickness: 1)), // divider
                              ],
                            ),

                            const SizedBox(height: 16),

                            _AuthButton(
                              label: 'Create Account',
                              outlined: true,
                              onTap: () => _smoothNavigate(context, const SignUpScreen())),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Skip link
                      Center(
                        child: GestureDetector(
                          onTap: () => _smoothNavigate(context, const HomeScreen(), replace: true),
                          child: const Text('continue without signing in',
                            style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF9B8EAD), // textTertiary
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF9B8EAD))))), // textTertiary

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ), // <-- Properly closed SafeArea
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIGN UP SCREEN
// ============================================================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);
  @override 
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscure   = true;
  bool _obscureC  = true;
  bool _loading   = false;

  late AnimationController _entryCtrl;
  late Animation<double>   _entrySlide, _entryOpacity;
  late AnimationController _bgCtrl, _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

    _bgCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entrySlide = Tween<double>(begin: 48.0, end: 0.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    WidgetsBinding.instance.addPostFrameCallback((_) => _entryCtrl.forward());
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    _entryCtrl.dispose(); _bgCtrl.dispose(); _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm  = _confirmCtrl.text.trim();

    if ([name, email, password, confirm].any((s) => s.isEmpty)) {
      _showSnack('Please fill in all fields'); return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match'); return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters'); return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
      if (!mounted) return;
      _smoothNavigate(context, const HomeScreen(), replace: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(e.message ?? 'Registration failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2D263B), // textPrimary
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: size.width, height: size.height,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.5),
            radius: 1.2,
            colors: [Color(0xFFF3E8FF), Color(0xFFF4F0FB), Colors.white],
            stops: [0.0, 0.5, 1.0])),
        child: Stack(
          children: [
            _BgBubbles(bgCtrl: _bgCtrl, shimmerCtrl: _shimmerCtrl),

            SafeArea(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _entrySlide.value),
                  child: Opacity(opacity: _entryOpacity.value, child: child),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back button ───────────────────────────────────
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE8E4EE), width: 1.2), // divider
                            boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF2D263B), size: 15), // textPrimary
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Logo ──────────────────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            Image.asset('assets/images/Bubble_logo.png', height: 48,
                              errorBuilder: (_, __, ___) => const _LogoText()),
                            const SizedBox(height: 8),
                            const Text("let's get you set up ✦",
                              style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600,
                                color: Color(0xFF6B5F80), letterSpacing: 0.2)), // textSecondary
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Frosted card ──────────────────────────────────
                      _FrostedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3.5, height: 28,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Color(0xFF98C4D4), Color(0xFFA898D4)]), // pastelBlue, pastelPurple
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    Text('Create Account',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                        color: Color(0xFF2D263B), letterSpacing: -0.5)), // textPrimary
                                    Text('just a few things and you\'re in',
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF6B5F80), // textSecondary
                                        fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            _AuthField(
                              controller: _nameCtrl,
                              label: 'Display Name',
                              hint: 'what should we call you?',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next),
                            const SizedBox(height: 12),

                            _AuthField(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next),
                            const SizedBox(height: 12),

                            _AuthField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.next,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF9B8EAD), size: 20))), // textTertiary
                            const SizedBox(height: 12),

                            _AuthField(
                              controller: _confirmCtrl,
                              label: 'Confirm Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureC,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _signUp(),
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscureC = !_obscureC),
                                child: Icon(
                                  _obscureC ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF9B8EAD), size: 20))), // textTertiary

                            const SizedBox(height: 24),

                            _AuthButton(
                              label: 'Create Account',
                              loading: _loading,
                              onTap: _signUp),

                            const SizedBox(height: 16),
                            
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(fontSize: 13, color: Color(0xFF6B5F80), fontWeight: FontWeight.w500), // textSecondary
                                    children: [
                                      TextSpan(text: 'Already have an account?  '),
                                      TextSpan(text: 'Sign In',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFA898D4), // pastelPurple
                                          decoration: TextDecoration.underline)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ), // <-- Properly closed SafeArea
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED AUTH WIDGETS
// ============================================================================

// ── Background bubbles ────────────────────────────────────────────────────────
class _BgBubbles extends StatelessWidget {
  final AnimationController bgCtrl, shimmerCtrl;
  const _BgBubbles({required this.bgCtrl, required this.shimmerCtrl});

  static const _bubbles = [
    (color: Color(0xFFFF8FA3), size: 220.0, xFrac: -0.22, yFrac: -0.04, phase: 0.00),
    (color: Color(0xFF82C3FF), size: 280.0, xFrac:  0.75, yFrac: -0.06, phase: 0.30),
    (color: Color(0xFFB388FF), size: 240.0, xFrac: -0.15, yFrac:  0.62, phase: 0.55),
    (color: Color(0xFFFFE57F), size: 170.0, xFrac:  0.80, yFrac:  0.58, phase: 0.45),
    (color: Color(0xFF69F0AE), size: 140.0, xFrac:  0.50, yFrac:  0.80, phase: 0.70),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) => Stack(
        children: _bubbles.map((b) {
          final t  = (bgCtrl.value * 0.15 + b.phase) % 1.0;
          final dy = math.sin(t * math.pi * 2) * 16.0;
          final st = (shimmerCtrl.value + b.phase) % 1.0;
          return Positioned(
            left: size.width  * b.xFrac,
            top:  size.height * b.yFrac + dy,
            child: _AuthBubble(size: b.size, color: b.color, shimmerT: st));
        }).toList()));
  }
}

class _AuthBubble extends StatelessWidget {
  final double size, shimmerT;
  final Color color;
  const _AuthBubble({required this.size, required this.color, required this.shimmerT});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        Colors.white.withOpacity(0.60),
        color.withOpacity(0.48),
        color.withOpacity(0.18),
      ], stops: const [0.0, 0.45, 1.0]),
      boxShadow: [BoxShadow(color: color.withOpacity(0.14), blurRadius: size * 0.22)]),
    child: ClipOval(child: Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment(-2.0 + shimmerT * 4.0, -0.5),
        end:   Alignment(-1.4 + shimmerT * 4.0,  0.5),
        colors: [Colors.transparent, Colors.white.withOpacity(0.28), Colors.transparent])))));
}

// ── Frosted glass card ────────────────────────────────────────────────────────
class _FrostedCard extends StatelessWidget {
  final Widget child;
  const _FrostedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85), // card
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.15), // pastelPurple
                blurRadius: 30, offset: const Offset(0, 8)),
              BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 2)),
            ]),
          child: child)));
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class _AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final Widget? suffix;

  const _AuthField({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    this.obscureText = false, this.keyboardType,
    this.textInputAction, this.onSubmitted, this.suffix,
  });

  @override State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3,
        color: _focused ? const Color(0xFFA898D4) : const Color(0xFF6B5F80))), // pastelPurple, textSecondary
      const SizedBox(height: 6),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _focused ? Colors.white : const Color(0xFFF7F5FA), // card, bg
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? const Color(0xFFA898D4) : const Color(0xFFE8E4EE), // pastelPurple, divider
            width: _focused ? 1.8 : 1.2),
          boxShadow: _focused
              ? [BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.20), blurRadius: 8)] // pastelPurple
              : []),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(widget.icon,
            color: _focused ? const Color(0xFFA898D4) : const Color(0xFF9B8EAD), // pastelPurple, textTertiary
            size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onFocusChange: (v) => setState(() => _focused = v),
              child: TextField(
                controller:  widget.controller,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                style: const TextStyle(
                  fontSize: 14.5, color: Color(0xFF2D263B), fontWeight: FontWeight.w600), // textPrimary
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: const Color(0xFF9B8EAD).withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500), // textTertiary
                  border: InputBorder.none, isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14))))),
          if (widget.suffix != null) ...[widget.suffix!, const SizedBox(width: 12)],
        ])),
    ]);
  }
}

// ── CTA button (Synced with RantCard Interactions) ────────────────────────────
class _AuthButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading, outlined;
  
  const _AuthButton({
    required this.label, required this.onTap,
    this.loading = false, this.outlined = false,
  });

  @override State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  // The official Bubble Theme gradient used in Compose/Rant screens
  static const List<Color> _brandGradient = [Color(0xFFD498B2), Color(0xFFA898D4)]; // pastelPink, pastelPurple

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    // Uses the same bouncy ease-out curve as the rant cards
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  
  @override 
  void dispose() { 
    _ctrl.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); if (!widget.loading) widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity, height: 52,
          decoration: widget.outlined
              ? BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFA898D4), width: 1.8)) // pastelPurple
              : BoxDecoration(
                  gradient: const LinearGradient(colors: _brandGradient),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(
                    color: _brandGradient.last.withOpacity(0.40),
                    blurRadius: 16, offset: const Offset(0, 5))]),
          child: Center(child: widget.loading
              ? SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(
                      widget.outlined ? const Color(0xFFA898D4) : Colors.white))) // pastelPurple
              : Text(widget.label, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2,
                  color: widget.outlined ? const Color(0xFFA898D4) : Colors.white)))))); // pastelPurple
  }
}

// ── Logo text fallback ────────────────────────────────────────────────────────
class _LogoText extends StatelessWidget {
  const _LogoText();
  
  @override
  Widget build(BuildContext context) => RichText(
    text: const TextSpan(
      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      children: [
        TextSpan(text: 'B', style: TextStyle(color: Color(0xFFFF8FA3))),
        TextSpan(text: 'ubbl', style: TextStyle(color: Color(0xFF2D263B))), // textPrimary
        TextSpan(text: 'e', style: TextStyle(color: Color(0xFF82C3FF))),
        TextSpan(text: '!', style: TextStyle(color: Color(0xFFFFE57F))),
      ]));
}