import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login.dart';

// ============================================================================
// SPLASH SCREEN
// ============================================================================

// A structured type for our bubbles to easily control exact placement
typedef BubbleData = ({Color color, double size, double xFrac, double yFrac, double phase, double speed});

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Logo entrance
  late AnimationController _logoCtrl;
  late Animation<double>   _logoScale, _logoOpacity, _logoSlide;

  // Tagline entrance
  late AnimationController _tagCtrl;
  late Animation<double>   _tagOpacity, _tagSlide;

  // Floating bubbles
  late AnimationController _bubbleCtrl;

  // Shimmer sweep on logo
  late AnimationController _shimmerCtrl;

  // Tap hint pulse
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  bool _autoProceed = false;

  // ── FULLY CUSTOMIZED BUBBLE LAYOUT (No Dead Space) ──
  static const List<BubbleData> _kBubbles = [
    (color: Color(0xFFFF8FA3), size: 190.0, xFrac: -0.15, yFrac: 0.05, phase: 0.00, speed: 0.22), // Top Left (Pink)
    (color: Color(0xFF82C3FF), size: 240.0, xFrac:  0.75, yFrac: -0.05, phase: 0.25, speed: 0.18), // Top Right (Blue)
    (color: Color(0xFFB388FF), size: 220.0, xFrac: -0.15, yFrac: 0.55, phase: 0.55, speed: 0.20), // Mid Left (Purple)
    (color: Color(0xFFFFE57F), size: 180.0, xFrac:  0.80, yFrac: 0.50, phase: 0.40, speed: 0.25), // Mid Right (Yellow)
    (color: Color(0xFF69F0AE), size: 130.0, xFrac:  0.60, yFrac: 0.65, phase: 0.70, speed: 0.28), // Lower Right (Mint)
    (color: Color(0xFFFFBCAA), size: 150.0, xFrac:  0.15, yFrac: 0.85, phase: 0.85, speed: 0.30), // Bottom Left (Warm Coral)
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark));

    // ── Logo: scale up + fade in ────────────────────────────────────────────
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.72, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _logoSlide = Tween<double>(begin: 24.0, end: 0.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    // ── Tagline: delayed ───────────────────────────────────────────────────
    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    _tagSlide = Tween<double>(begin: 10.0, end: 0.0)
        .animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));

    // ── Bubbles: continuous drift ───────────────────────────────────────────
    _bubbleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    // ── Shimmer sweep ───────────────────────────────────────────────────────
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    // ── Pulse (tap hint) ────────────────────────────────────────────────────
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Sequence & Auto-Redirect Logic ──────────────────────────────────────
    _logoCtrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _tagCtrl.forward();
      
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _navigateToNext(isAutoRedirect: true);
      } else {
        setState(() => _autoProceed = true);
      }
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _tagCtrl.dispose();
    _bubbleCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── BUTTERY SMOOTH PAGE TRANSITION ──
  void _navigateToNext({required bool isAutoRedirect}) {
    if (!isAutoRedirect) {
      HapticFeedback.lightImpact(); 
    }
    
    final user = FirebaseAuth.instance.currentUser;
    final nextScreen = user != null ? const HomeScreen() : const SignInScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800), // Smooth 0.8s transition
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => _navigateToNext(isAutoRedirect: false),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.2,
              colors: [
                Color(0xFFF3E8FF), 
                Color(0xFFF4F0FB), 
                Color(0xFFFFFFFF), 
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // ── Floating Interactive Bubbles ──────────────────────────────
              AnimatedBuilder(
                animation: _bubbleCtrl,
                builder: (_, __) {
                  return Stack(
                    children: _kBubbles.map((b) {
                      final t = (_bubbleCtrl.value * b.speed * 6 + b.phase) % 1.0;
                      final dy = math.sin(t * math.pi * 2) * 35.0;
                      final dx = math.cos(t * math.pi * 2) * 15.0; 
                      
                      return Positioned(
                        left: (size.width * b.xFrac) + dx,
                        top: (size.height * b.yFrac) + dy, // Uses the new yFrac for exact placement!
                        child: _PoppableBubble(
                          size: b.size,
                          color: b.color,
                          shimmerT: (_shimmerCtrl.value + b.phase) % 1.0,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // ── Center content ────────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _logoSlide.value),
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: _buildLogo(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tagline
                    AnimatedBuilder(
                      animation: _tagCtrl,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _tagSlide.value),
                        child: Opacity(
                          opacity: _tagOpacity.value,
                          child: Column(
                            children: [
                              const Text(
                                'pop off. rant freely.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7E6FA3),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _dot(const Color(0xFFFF8FA3)), 
                                  _dot(const Color(0xFFB388FF)), 
                                  _dot(const Color(0xFF82C3FF)), 
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tap to continue hint ──────────────────────────────────────
              if (_autoProceed)
                Positioned(
                  bottom: 54 + MediaQuery.of(context).padding.bottom,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Opacity(
                      opacity: _pulse.value,
                      child: Column(
                        children: [
                          const Text(
                            'tap anywhere to continue',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFADB5BD),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFFCFB8E8).withOpacity(0.9),
                            size: 22,
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
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, child) {
        final t = _shimmerCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow halo
            Container(
              width: 180,
              height: 120,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB388FF).withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
            // Shimmer sweep
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-2.0 + t * 4.0, -0.5),
                end:   Alignment(-1.4 + t * 4.0,  0.5),
                colors: [Colors.white, Colors.white.withOpacity(0.6), Colors.white],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: child!,
            ),
          ],
        );
      },
      child: Image.asset(
        'assets/images/Bubble_logo.png',
        width: 220,
        errorBuilder: (_, __, ___) => RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -1),
            children: [
              TextSpan(text: 'B', style: TextStyle(color: Color(0xFFFF8FA3))),
              TextSpan(text: 'ubbl', style: TextStyle(color: Color(0xFF1A1A2E))),
              TextSpan(text: 'e', style: TextStyle(color: Color(0xFF82C3FF))),
              TextSpan(text: '!', style: TextStyle(color: Color(0xFFFFE57F))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ============================================================================
// POPPABLE BUBBLE WIDGET (Handles the tap-to-pop animation)
// ============================================================================
class _PoppableBubble extends StatefulWidget {
  final double size, shimmerT;
  final Color color;

  const _PoppableBubble({
    required this.size,
    required this.color,
    required this.shimmerT,
  });

  @override
  State<_PoppableBubble> createState() => _PoppableBubbleState();
}

class _PoppableBubbleState extends State<_PoppableBubble> with SingleTickerProviderStateMixin {
  bool _isPopped = false;
  late AnimationController _popCtrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    
    _scale = Tween<double>(begin: 1.0, end: 1.45)
        .animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  void _triggerPop() {
    if (_isPopped) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _isPopped = true);
    
    _popCtrl.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _popCtrl.reverse().then((_) {
            if (mounted) setState(() => _isPopped = false);
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerPop,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _popCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: child,
            ),
          );
        },
        child: _IridescentBubble(
          size: widget.size,
          color: widget.color,
          shimmerT: widget.shimmerT,
        ),
      ),
    );
  }
}

// ── Original Iridescent bubble decoration ───────────────────────────────────
class _IridescentBubble extends StatelessWidget {
  final double size, shimmerT;
  final Color color;
  const _IridescentBubble({required this.size, required this.color, required this.shimmerT});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.75),
            color.withOpacity(0.60),
            color.withOpacity(0.30),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.25), blurRadius: size * 0.3)
        ],
      ),
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-2.0 + shimmerT * 4.0, -0.5),
              end:   Alignment(-1.4 + shimmerT * 4.0,  0.5),
              colors: [Colors.transparent, Colors.white.withOpacity(0.40), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}