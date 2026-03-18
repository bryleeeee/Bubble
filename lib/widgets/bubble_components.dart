import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import 'ghost_widgets.dart'; // ── NEW: Tells the file where to find the Ghost bubbles! ──


// ============================================================================
// BUBBLE TAIL SHAPE
// ============================================================================
class BubbleTailShape extends OutlinedBorder {
  final double borderRadius;
  final double tailWidth;
  final double tailHeight;

  const BubbleTailShape({
    BorderSide side = BorderSide.none,
    this.borderRadius = 28.0,
    this.tailWidth = 18.0,
    this.tailHeight = 16.0,
  }) : super(side: side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  OutlinedBorder copyWith({BorderSide? side}) => BubbleTailShape(
        side: side ?? this.side,
        borderRadius: borderRadius,
        tailWidth: tailWidth,
        tailHeight: tailHeight,
      );

  @override
  OutlinedBorder scale(double t) => BubbleTailShape(
        side: side.scale(t),
        borderRadius: borderRadius * t,
        tailWidth: tailWidth * t,
        tailHeight: tailHeight * t,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect);

  Path _getPath(Rect rect) {
    final double r = borderRadius, tW = tailWidth, tH = tailHeight;
    final path = Path();
    final double bottomY = rect.bottom - tH;

    path.moveTo(rect.left + r, rect.top);
    path.lineTo(rect.right - r, rect.top);
    path.arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r));
    path.lineTo(rect.right, bottomY - r);
    path.arcToPoint(Offset(rect.right - r, bottomY), radius: Radius.circular(r));
    path.lineTo(rect.left + tW, bottomY);
    path.quadraticBezierTo(rect.left + tW * 0.4, bottomY, rect.left, rect.bottom);
    path.quadraticBezierTo(rect.left + tW * 0.2, bottomY - tH * 0.2, rect.left, bottomY - r);
    path.lineTo(rect.left, rect.top + r);
    path.arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r));
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }
}

class BubbleTailClipper extends CustomClipper<Path> {
  final double borderRadius;
  BubbleTailClipper({this.borderRadius = 28.0});

  @override
  Path getClip(Size size) => BubbleTailShape(borderRadius: borderRadius).getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// PARTICLE SYSTEM
// ============================================================================
class Particle {
  final double angle;
  final double distance;
  final Color color;
  final double size;

  Particle({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
    for (final p in particles) {
      final t = Curves.easeOut.transform(progress);
      final opacity = (1.0 - progress * 1.1).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      final dx = math.cos(p.angle) * p.distance * t;
      final dy = math.sin(p.angle) * p.distance * t;
      final radius = p.size * (1.0 - progress * 0.4);

      canvas.drawCircle(center + Offset(dx, dy), radius.clamp(1.0, 12.0), paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => old.progress != progress;
}

// ============================================================================
// STAGGERED FEED ITEM ANIMATOR
// ============================================================================
class FeedItemAnimator extends StatefulWidget {
  final Widget child;
  final int index;

  const FeedItemAnimator({
    Key? key,
    required this.child,
    required this.index,
  }) : super(key: key);

  @override
  State<FeedItemAnimator> createState() => _FeedItemAnimatorState();
}

class _FeedItemAnimatorState extends State<FeedItemAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    final delay = Duration(milliseconds: math.min(widget.index, 6) * 55);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================
class SkeletonBubble extends StatefulWidget {
  const SkeletonBubble({Key? key}) : super(key: key);
  @override
  State<SkeletonBubble> createState() => _SkeletonBubbleState();
}

class _SkeletonBubbleState extends State<SkeletonBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipPath(
        clipper: BubbleTailClipper(borderRadius: 28),
        child: SizedBox(
          width: double.infinity,
          height: 146,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-2.0 + t * 4.0, -0.3),
                    end: Alignment(-1.0 + t * 4.0, 0.3),
                    colors: [
                      BT.divider.withOpacity(0.4),
                      BT.pastelBlue.withOpacity(0.15),
                      BT.pastelPurple.withOpacity(0.15),
                      BT.divider.withOpacity(0.4),
                    ],
                    stops: const [0.0, 0.4, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED NOTIFICATION BELL
// ============================================================================
class AnimatedBell extends StatefulWidget {
  final bool hasNotification;
  const AnimatedBell({Key? key, this.hasNotification = true}) : super(key: key);

  @override
  State<AnimatedBell> createState() => _AnimatedBellState();
}

class _AnimatedBellState extends State<AnimatedBell> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ring() {
    HapticFeedback.lightImpact();
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _ring,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BT.divider.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) {
                final angle = math.sin(_ctrl.value * math.pi * 4) * 0.3 * (1.0 - _ctrl.value);
                return Transform.rotate(angle: angle, child: child);
              },
              child: const Icon(Icons.notifications_outlined, color: BT.textPrimary, size: 20),
            ),
          ),
          if (widget.hasNotification)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: BT.heartRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: BT.card, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIMIT-PULSING CHARACTER COUNTER
// ============================================================================
class PulseCounter extends StatelessWidget {
  final int current;
  final int maxChars;

  const PulseCounter({
    Key? key,
    required this.current,
    this.maxChars = 280,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isNearingLimit = current > maxChars - 20;
    final isAtLimit = current >= maxChars;

    return TweenAnimationBuilder<double>(
      key: ValueKey(isAtLimit),
      tween: Tween(begin: isAtLimit ? 1.2 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          color: isAtLimit ? BT.heartRed : (isNearingLimit ? BT.textPrimary : BT.textTertiary),
          fontSize: 11,
          fontWeight: isAtLimit ? FontWeight.w800 : FontWeight.w500,
        ),
        child: Text('$current/$maxChars'),
      ),
    );
  }
}

// ============================================================================
// ANIMATED BUBBLE WIDGET
// ============================================================================
class AnimatedBubble extends StatefulWidget {
  final Post post;
  final String bubbleAsset;

  const AnimatedBubble({
    Key? key,
    required this.post,
    required this.bubbleAsset,
  }) : super(key: key);

  @override
  State<AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<AnimatedBubble> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pastel = BT.pastelAt(widget.post.avatarColorIndex);
    final pastel2 = BT.pastelAt(widget.post.avatarColorIndex + 1);
    final pastel3 = BT.pastelAt(widget.post.avatarColorIndex + 2);

    return SizedBox(
      width: double.infinity,
      height: 146,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  pastel.withOpacity(0.65),
                  pastel2.withOpacity(0.45),
                  pastel3.withOpacity(0.35),
                ],
              ),
            ),
          ),
          Image.asset(
            widget.bubbleAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) {
              final t = _shimmerCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-2.0 + t * 4.0, -0.6),
                    end: Alignment(-1.4 + t * 4.0, 0.6),
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.18),
                      pastel2.withOpacity(0.22),
                      pastel3.withOpacity(0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            left: 20,
            child: Container(
              width: 40,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: Container(color: Colors.white.withOpacity(0.22)),
          ),
          if (widget.post.seenBy.isNotEmpty)
            Positioned(
              top: 14,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('👀', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.seenBy.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          const Positioned(top: 14, left: 22, child: Sparkle()),
          const Positioned(bottom: 36, right: 26, child: Sparkle()),
          Positioned(
            top: 0,
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, child) {
                  final pulse = math.sin(_shimmerCtrl.value * math.pi * 2) * 0.12 + 0.88;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(pulse.clamp(0.82, 0.95)),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: pastel.withOpacity(0.55), blurRadius: 18 + pulse * 4, spreadRadius: 1),
                        BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 6),
                      ],
                    ),
                    child: child,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💬', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Tap to pop!', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 5, 14, 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.35),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // USING THE NEW SMART AVATAR HERE
                      BubbleAvatar(
                        author: widget.post.author,
                        seed: widget.post.avatarSeed,
                        colorIndex: widget.post.avatarColorIndex,
                        radius: 9,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.post.author,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black26, blurRadius: 6)]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAP BOUNCE WRAPPER
// ============================================================================
class TapBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TapBounce({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.06).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class MoodPill extends StatelessWidget {
  final MoodTag mood;
  const MoodPill({Key? key, required this.mood}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: mood.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(mood.label, style: TextStyle(fontSize: 10.5, color: mood.fg, fontWeight: FontWeight.w700)),
    );
  }
}

class Sparkle extends StatelessWidget {
  const Sparkle({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Text('✦', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w400));
  }
}



// ============================================================================
// NEW: SMART CACHE AVATAR
// ============================================================================
class AvatarCache {
  static final Map<String, String> urls = {};
}

class BubbleAvatar extends StatefulWidget {
  final String author; // The handle (e.g. '@Zer0noz'). Made optional for backward compatibility.
  final String seed;
  final int colorIndex;
  final double radius;

  const BubbleAvatar({
    Key? key,
    this.author = '', 
    required this.seed,
    required this.colorIndex,
    this.radius = 18,
  }) : super(key: key);

  @override
  State<BubbleAvatar> createState() => _BubbleAvatarState();
}

class _BubbleAvatarState extends State<BubbleAvatar> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(covariant BubbleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.author != widget.author) _loadUrl();
  }

  void _loadUrl() async {
    final handle = widget.author;
    // If no author is passed, we just skip the DB read entirely
    if (handle.isEmpty || handle == '@Me' || handle == 'Unknown') return;

    // If we already looked up this person's picture, use memory instantly!
    if (AvatarCache.urls.containsKey(handle)) {
      if (mounted) setState(() => _url = AvatarCache.urls[handle]);
      return;
    }

    final cleanName = handle.replaceAll('@', '');
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: cleanName)
          .limit(1)
          .get();
          
      if (q.docs.isNotEmpty) {
        final url = q.docs.first.data()['profileUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          AvatarCache.urls[handle] = url; // Save to phone memory
          if (mounted) setState(() => _url = url);
        }
      }
    } catch (e) {
      // Silently fail and show the initial instead
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_url != null && _url!.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius, 
        backgroundImage: NetworkImage(_url!), 
        backgroundColor: BT.divider
      );
    }
    
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: BT.pastelAt(widget.colorIndex),
      child: Text(
        widget.seed.isNotEmpty ? widget.seed[0].toUpperCase() : 'X',
        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: widget.radius * 0.78),
      ),
    );
  }
}