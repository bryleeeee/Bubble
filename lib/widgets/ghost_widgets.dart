import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/post.dart';

// ============================================================================
// GHOST CARD WRAPPER
// Wraps any revealed card and gradually fades it as expiry approaches.
// At 80% of 24h elapsed → starts fading.
// At expiry → fully transparent (Cloud Function handles actual deletion).
// ============================================================================
class GhostCardWrapper extends StatefulWidget {
  final Post post;
  final Widget child;
  const GhostCardWrapper({Key? key, required this.post, required this.child})
      : super(key: key);
  @override State<GhostCardWrapper> createState() => _GhostCardWrapperState();
}

class _GhostCardWrapperState extends State<GhostCardWrapper> {
  late Timer _timer;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _updateOpacity();
    // Recompute every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _updateOpacity();
    });
  }

  @override void dispose() { _timer.cancel(); super.dispose(); }

  void _updateOpacity() {
    final expiresAt = widget.post.expiresAt;
    if (expiresAt == null) { setState(() => _opacity = 1.0); return; }

    final now         = DateTime.now();
    final remaining   = expiresAt.difference(now);
    final totalLife   = const Duration(hours: 24);
    final elapsed     = totalLife - remaining;
    final progress    = (elapsed.inSeconds / totalLife.inSeconds).clamp(0.0, 1.0);

    // Start fading at 80% of 24h, fully transparent at 100%
    const fadeStart = 0.80;
    double opacity;
    if (progress < fadeStart) {
      opacity = 1.0;
    } else {
      opacity = 1.0 - ((progress - fadeStart) / (1.0 - fadeStart));
    }
    setState(() => _opacity = opacity.clamp(0.05, 1.0));
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 600),
    opacity: _opacity,
    child: widget.child);
}

// ============================================================================
// GHOST ANIMATED BUBBLE
// ============================================================================
class GhostAnimatedBubble extends StatefulWidget {
  final Post post;
  final String bubbleAsset;
  const GhostAnimatedBubble({Key? key, required this.post, required this.bubbleAsset})
      : super(key: key);
  @override State<GhostAnimatedBubble> createState() => _GhostAnimatedBubbleState();
}

class _GhostAnimatedBubbleState extends State<GhostAnimatedBubble>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _smokeCtrl;
  late AnimationController _particleCtrl;
  late math.Random _rng;
  late List<_SmokeParticle> _particles;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(widget.hashCode);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _smokeCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    _particles = List.generate(6, (i) => _SmokeParticle(
      x:     _rng.nextDouble(),
      phase: _rng.nextDouble(),
      size:  8.0 + _rng.nextDouble() * 12.0,
      speed: 0.3 + _rng.nextDouble() * 0.4,
    ));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _smokeCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 146,
      child: Stack(fit: StackFit.expand, children: [

        // ── Dark base gradient (smoky purple-black) ───────────────────────
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1830), // deep purple-black
              Color(0xFF2D2547), // dark violet
              Color(0xFF1A1628), // near black
            ]))),

        // ── Misty inner glow (pulsing) ────────────────────────────────────
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) {
            final pulse = math.sin(_shimmerCtrl.value * math.pi * 2) * 0.5 + 0.5;
            return Container(decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 0.7,
                colors: [
                  const Color(0xFF6B5FA0).withOpacity(0.25 + pulse * 0.15),
                  const Color(0xFF4A3D78).withOpacity(0.10 + pulse * 0.08),
                  Colors.transparent,
                ])));
          }),

        // ── Iridescent shimmer sweep ──────────────────────────────────────
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) {
            final t = _shimmerCtrl.value;
            return Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-2.0 + t * 4.0, -0.6),
                end:   Alignment(-1.4 + t * 4.0,  0.6),
                colors: [
                  Colors.transparent,
                  const Color(0xFF9B8FBF).withOpacity(0.12),
                  const Color(0xFF7B6EA8).withOpacity(0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.55, 1.0])));
          }),

        // ── Smoke particles ───────────────────────────────────────────────
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => Stack(
            children: _particles.map((p) {
              final t = (_particleCtrl.value * p.speed + p.phase) % 1.0;
              final y = (1.0 - t) * 146.0;
              final opacity = math.sin(t * math.pi).clamp(0.0, 1.0) * 0.18;
              return Positioned(
                left: MediaQuery.of(context).size.width * p.x - p.size / 2,
                top: y,
                child: Container(
                  width: p.size, height: p.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF9B8FBF).withOpacity(opacity))));
            }).toList()),
        ),

        // ── Gloss highlight ───────────────────────────────────────────────
        Positioned(top: 8, left: 20,
          child: Container(
            width: 36, height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)))),

        // ── Backdrop blur for depth ───────────────────────────────────────
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
          child: Container(color: Colors.transparent)),

        // ── Sparkles ─────────────────────────────────────────────────────
        Positioned(top: 14, left: 22,  child: _GhostSparkle(ctrl: _shimmerCtrl, phase: 0.0)),
        Positioned(top: 12, right: 52, child: _GhostSparkle(ctrl: _shimmerCtrl, phase: 0.33)),
        Positioned(bottom: 36, right: 26, child: _GhostSparkle(ctrl: _shimmerCtrl, phase: 0.66)),

        // ── "Tap to pop!" chip ────────────────────────────────────────────
        Positioned(top: 0, bottom: 20, left: 0, right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, child) {
                final pulse = math.sin(_shimmerCtrl.value * math.pi * 2) * 0.06 + 0.88;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(pulse.clamp(0.10, 0.16)),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF9B8FBF).withOpacity(0.35), width: 1),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6B5FA0).withOpacity(0.40), blurRadius: 16 + pulse * 6),
                    ]),
                  child: child);
              },
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('👻', style: TextStyle(fontSize: 15)),
                SizedBox(width: 8),
                Text('Tap to pop!', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ])))),

        // ── Author peek strip ─────────────────────────────────────────────
        Positioned(bottom: 0, left: 0, right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                // ── INCREASED BOTTOM PADDING TO 18 TO CLEAR THE TAIL! ──
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                color: Colors.white.withOpacity(0.06),
                child: Row(children: [
                  CircleAvatar(radius: 9,
                    backgroundColor: const Color(0xFF6B5FA0).withOpacity(0.7),
                    child: Text(
                      widget.post.avatarSeed.isNotEmpty
                          ? widget.post.avatarSeed[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 6),
                  Text(widget.post.author, style: const TextStyle(
                    fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // ── Live countdown ────────────────────────────────────
                  if (widget.post.expiresAt != null)
                    _GhostCountdown(expiresAt: widget.post.expiresAt!),
                ]))))),
      ]));
  }
}

// ── Ghost sparkle (fades in/out with shimmer timing) ──────────────────────────
class _GhostSparkle extends StatelessWidget {
  final AnimationController ctrl;
  final double phase;
  const _GhostSparkle({required this.ctrl, required this.phase});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, __) {
      final t = (ctrl.value + phase) % 1.0;
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      return Opacity(
        opacity: opacity * 0.5,
        child: const Text('✦', style: TextStyle(fontSize: 11, color: Colors.white70)));
    });
}

// ============================================================================
// GHOST COUNTDOWN  (e.g. "23h 42m" or "47m" as expiry approaches)
// ============================================================================
class _GhostCountdown extends StatefulWidget {
  final DateTime expiresAt;
  const _GhostCountdown({required this.expiresAt});
  @override State<_GhostCountdown> createState() => _GhostCountdownState();
}

class _GhostCountdownState extends State<_GhostCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) _update(); });
  }

  @override void dispose() { _timer.cancel(); super.dispose(); }

  void _update() {
    final r = widget.expiresAt.difference(DateTime.now());
    setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  String get _label {
    if (_remaining.inSeconds <= 0) return 'expired';
    if (_remaining.inHours >= 1) {
      final h = _remaining.inHours;
      final m = _remaining.inMinutes.remainder(60);
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    final m = _remaining.inMinutes;
    if (m > 0) return '${m}m';
    return '< 1m';
  }

  // Gets more red/urgent as time runs out
  Color get _color {
    final pct = _remaining.inSeconds / const Duration(hours: 24).inSeconds;
    if (pct > 0.5) return Colors.white54;
    if (pct > 0.2) return const Color(0xFFFFB3C8).withOpacity(0.85); // pastel pink
    return const Color(0xFFFF6B8A).withOpacity(0.9);                  // heartRed
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 10, color: _color),
        const SizedBox(width: 3),
        Text(_label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800, color: _color)),
      ]));
  }
}

class _SmokeParticle {
  final double x, phase, size, speed;
  _SmokeParticle({required this.x, required this.phase, required this.size, required this.speed});
}