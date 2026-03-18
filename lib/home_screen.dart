import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import '../widgets/bubble_components.dart';
import '../widgets/compose_sheet.dart';
import '../widgets/rant_card.dart';
import '../widgets/circle_sheet.dart';
import 'login.dart';
import 'screens/profile_screen.dart';
import 'screens/thread_screen.dart';

const Color appBgTint = Color(0xFFF6F0FA);

// ============================================================================
// HOME SCREEN
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  
  // ── Dynamic Circle State ──
  String? _circle; 
  bool _isLoadingCircles = true;
  StreamSubscription<QuerySnapshot>? _circleSub;

  final String _bubbleAsset = 'assets/images/image_0.png';
  final Set<String> _poppedPostIds = {};

  final StreamController<void> _refreshTrigger = StreamController<void>.broadcast();

  int _lastSeenCount = 0;
  int _currentFeedCount = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // ── Live Circle Listener (The Gatekeeper) ──
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _circleSub = FirebaseFirestore.instance
          .collection('circles')
          .where('members', arrayContains: uid)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        
        if (snap.docs.isEmpty) {
          setState(() { _circle = null; _isLoadingCircles = false; });
        } else {
          final validNames = snap.docs.map((d) => d['name'] as String).toList();
          if (_circle == null || !validNames.contains(_circle)) {
            setState(() { _circle = validNames.first; _isLoadingCircles = false; });
          } else {
            setState(() => _isLoadingCircles = false);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _circleSub?.cancel();
    _refreshTrigger.close();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SignInScreen()));
  }

  Future<void> _handleRefresh() async {
    if (_circle == null) return; 
    HapticFeedback.mediumImpact();
    _refreshTrigger.add(null);
    setState(() => _lastSeenCount = _currentFeedCount);
    await Future.delayed(const Duration(milliseconds: 900));
    HapticFeedback.lightImpact();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5)  return 'Still up,';
    if (hour < 12) return 'Good morning!,';
    if (hour < 17) return 'Good afternoon!,';
    if (hour < 23) return 'Good evening!,';
    return 'Good evening!,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.55),
            radius: 1.1,
            colors: [
              Color(0xFFF0E9FA),
              Color(0xFFF6F0FA),
              Color(0xFFF9F5FC),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _navIndex,
            children: [
              Column(children: [
                _buildFrostedHeader(),
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        BT.pastelBlue.withOpacity(0.0),
                        BT.pastelPurple.withOpacity(0.35),
                        BT.pastelPink.withOpacity(0.20),
                        BT.pastelBlue.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0])),
                ),
                _buildMainContent(),
              ]),
              ProfileScreen(targetCircle: _circle ?? ''),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildPillNav(),
    );
  }

  Widget _buildMainContent() {
    if (_isLoadingCircles) {
      return const Expanded(child: Center(child: CircularProgressIndicator(color: BT.pastelPurple)));
    }
    
    if (_circle == null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🫧', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('Welcome to Bubble!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: BT.textPrimary)),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Bubble is a private space.\nYou need to join or create a Circle to start posting.', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: BT.textSecondary, fontSize: 14, height: 1.5)
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  builder: (_) => CircleSheet(current: '', onSelect: (c) {}) 
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BT.pastelPurple, 
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                ),
                child: const Text('Join or Create a Circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              )
            ],
          ),
        ),
      );
    }

    // ── DYNAMIC BADGE LOGIC ──
    final unreadCount = (_currentFeedCount - _lastSeenCount).clamp(0, 999);
    final hasUnread = unreadCount > 0;

    return Expanded(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Feed now knows if it needs to make room for the badge!
          _buildLiveFeed(authorFilter: null, hasUnread: hasUnread),
          
          _UnreadBadge(
            unreadCount: unreadCount,
            onTap: () {
              setState(() => _lastSeenCount = _currentFeedCount);
            },
          ),
        ],
      )
    );
  }

  Widget _buildFrostedHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final fallbackInitial = user?.displayName?.isNotEmpty == true
        ? user!.displayName![0].toUpperCase()
        : '✦';
    final defaultDisplayName = user?.displayName ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: BT.pastelPurple.withOpacity(0.15), 
              blurRadius: 24, 
              offset: const Offset(0, 8)
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String profileUrl = '';
                String initial = fallbackInitial;
                String displayName = defaultDisplayName;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  profileUrl = data['profileUrl'] ?? '';
                  final name = data['name'] ?? '';
                  if (name.isNotEmpty) {
                    displayName = name;
                    initial = name[0].toUpperCase();
                  }
                }

                return Stack(
                  children: [
                    const Positioned.fill(child: _FloatingBubbleStrip()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 48,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: const Text('Are you sure you want to leave the bubble?'),
                                        backgroundColor: BT.card,
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel', style: TextStyle(color: BT.textSecondary))),
                                          TextButton(
                                            onPressed: () { Navigator.pop(context); _logout(); },
                                            child: const Text('Log Out', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.bold))),
                                        ])),
                                    child: _HeaderAvatar(profileUrl: profileUrl, initial: initial),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset('assets/images/Bubble_logo.png', height: 26,
                                      errorBuilder: (_, __, ___) => RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                          children: [
                                            TextSpan(text: 'B', style: TextStyle(color: BT.pastelPink, shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
                                            TextSpan(text: 'ubbl', style: TextStyle(color: BT.textPrimary, shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
                                            TextSpan(text: 'e', style: TextStyle(color: BT.pastelBlue, shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
                                            TextSpan(text: '!', style: TextStyle(color: BT.pastelYellow, shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
                                          ]))),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayName.isNotEmpty
                                          ? '$_greeting ${displayName.split(' ').first}'
                                          : _greeting.replaceAll(',', ''),
                                      style: const TextStyle(
                                        fontSize: 13.5, 
                                        fontWeight: FontWeight.w700, 
                                        color: BT.textSecondary, 
                                        letterSpacing: 0.1
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCircleButton(),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 48,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: AnimatedBell(hasNotification: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton() {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => CircleSheet(
            current: _circle ?? '',
            onSelect: (c) => setState(() => _circle = c))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: BT.pastelBlue.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_circle != null) const _PulsingDot(),
          if (_circle != null) const SizedBox(width: 6),
          Text(_circle ?? 'Start Here', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
        ])),
    );
  }

  // ── PASS THE UNREAD STATE DOWN TO THE FEED ──
  Widget _buildLiveFeed({String? authorFilter, required bool hasUnread}) {
    return _RefreshableFeed(
      targetCircle: _circle!, 
      authorFilter: authorFilter,
      hasUnreadBadge: hasUnread, // Tells the feed to make room!
      bubbleAsset: _bubbleAsset,
      poppedPostIds: _poppedPostIds,
      onPop: (id) => setState(() => _poppedPostIds.add(id)),
      onRefresh: _handleRefresh,
      refreshTrigger: _refreshTrigger.stream,
      onCardTap: (post) => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ThreadScreen(post: post))),
      onCountChanged: (count) {
        if (count != _currentFeedCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentFeedCount = count);
          });
        }
      },
    );
  }

  Widget _buildPillNav() {
    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 40, bottom: 28),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: BT.card,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(color: BT.pastelBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
                  ]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 0),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(width: 70, child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _navIndex == 0 ? BT.pastelBlue.withOpacity(0.2) : Colors.transparent,
                            shape: BoxShape.circle),
                          child: Icon(
                            _navIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                            color: _navIndex == 0 ? const Color(0xFF6AAED6) : BT.textTertiary,
                            size: 24))))),

                    const SizedBox(width: 70),

                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 1),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(width: 70, child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _navIndex == 1 ? BT.pastelBlue.withOpacity(0.2) : Colors.transparent,
                            shape: BoxShape.circle),
                          child: Icon(
                            _navIndex == 1 ? Icons.person_rounded : Icons.person_outlined,
                            color: _navIndex == 1 ? const Color(0xFF6AAED6) : BT.textTertiary,
                            size: 24))))),
                  ]),
              ))),
              
          if (_circle != null)
            Positioned(
              bottom: 24,
              child: _ComposeButton(onTap: _showComposeSheet)),
        ],
      ),
    );
  }

  void _showComposeSheet() async {
    if (_circle == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => ComposeSheet(targetCircle: _circle!));
  }
}

// ============================================================================
// SCATTERED FLOATING BUBBLES
// ============================================================================
class _FloatingBubbleStrip extends StatefulWidget {
  const _FloatingBubbleStrip();
  @override State<_FloatingBubbleStrip> createState() => _FloatingBubbleStripState();
}

class _FloatingBubbleStripState extends State<_FloatingBubbleStrip> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _bubbles = [
    (color: BT.pastelPink,   size: 42.0, phaseX: 0.00, phaseY: 0.00, x: 0.15, y: 0.25),
    (color: BT.pastelBlue,   size: 32.0, phaseX: 0.25, phaseY: 0.33, x: 0.55, y: 0.70),
    (color: BT.pastelPurple, size: 36.0, phaseX: 0.60, phaseY: 0.66, x: 0.85, y: 0.35),
    (color: BT.pastelMint,   size: 24.0, phaseX: 0.85, phaseY: 0.18, x: 0.35, y: 0.60),
    (color: BT.pastelYellow, size: 28.0, phaseX: 0.40, phaseY: 0.52, x: 0.75, y: 0.80),
    (color: BT.pastelCoral,  size: 20.0, phaseX: 0.15, phaseY: 0.80, x: 0.30, y: 0.15),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: _bubbles.map((b) {
                final t = _ctrl.value;
                final dy = math.sin((t + b.phaseY) * math.pi * 2) * 12.0;
                final dx = math.cos((t + b.phaseX) * math.pi * 2) * 8.0;

                return Positioned(
                  left: (w * b.x) + dx - (b.size / 2),
                  top: (h * b.y) + dy - (b.size / 2),
                  child: _InteractiveGlassBubble(size: b.size, color: b.color),
                );
              }).toList(),
            );
          });
      });
  }
}

class _InteractiveGlassBubble extends StatefulWidget {
  final double size;
  final Color color;
  const _InteractiveGlassBubble({required this.size, required this.color});

  @override State<_InteractiveGlassBubble> createState() => _InteractiveGlassBubbleState();
}

class _InteractiveGlassBubbleState extends State<_InteractiveGlassBubble> {
  bool _popped = false;

  void _pop() {
    if (_popped) return;
    HapticFeedback.lightImpact();
    setState(() => _popped = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _popped = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _popped ? 0.0 : 1.0,
      duration: Duration(milliseconds: _popped ? 150 : 600),
      curve: _popped ? Curves.easeInBack : Curves.elasticOut,
      child: GestureDetector(
        onTap: _pop,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: widget.size, 
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.0),
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.4),
              radius: 1.0,
              colors: [
                Colors.white.withOpacity(0.4),
                widget.color.withOpacity(0.1),
                widget.color.withOpacity(0.45),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
            boxShadow: [
              BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 6, spreadRadius: 1),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: widget.size * 0.12,
                left: widget.size * 0.18,
                child: Transform.rotate(
                  angle: -math.pi / 5,
                  child: Container(
                    width: widget.size * 0.35,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(widget.size),
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
}

// ============================================================================
// UNREAD BADGE 
// ============================================================================
class _UnreadBadge extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _UnreadBadge({required this.unreadCount, required this.onTap});
  @override State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_UnreadBadge old) {
    super.didUpdateWidget(old);
    if (widget.unreadCount > 0 && old.unreadCount == 0) {
      _ctrl.forward(from: 0);
    } else if (widget.unreadCount == 0) {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unreadCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0), 
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BT.pastelPink.withOpacity(0.95),
                    BT.pastelPurple.withOpacity(0.90),
                  ]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: BT.pastelPurple.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 8), 
                Text(
                  widget.unreadCount == 1
                      ? '1 new rant'
                      : '${widget.unreadCount} new rants',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REFRESHABLE FEED WIDGET
// ============================================================================
class _RefreshableFeed extends StatefulWidget {
  final String targetCircle;
  final String? authorFilter;
  final bool hasUnreadBadge; // ── NEW: Accepts badge state! ──
  final String bubbleAsset;
  final Set<String> poppedPostIds;
  final void Function(String) onPop;
  final Future<void> Function() onRefresh;
  final Stream<void> refreshTrigger;
  final void Function(Post) onCardTap;
  final void Function(int)? onCountChanged;

  const _RefreshableFeed({
    Key? key,
    required this.targetCircle,
    required this.authorFilter,
    required this.hasUnreadBadge,
    required this.bubbleAsset,
    required this.poppedPostIds,
    required this.onPop,
    required this.onRefresh,
    required this.refreshTrigger,
    required this.onCardTap,
    this.onCountChanged,
  }) : super(key: key);

  @override State<_RefreshableFeed> createState() => _RefreshableFeedState();
}

class _RefreshableFeedState extends State<_RefreshableFeed>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  late Stream<QuerySnapshot> _feedStream;
  StreamSubscription<void>? _refreshSub;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    _buildStream();
    _refreshSub = widget.refreshTrigger.listen((_) {
      setState(() { _streamKey++; _buildStream(); });
    });
  }

  @override
  void didUpdateWidget(covariant _RefreshableFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetCircle != widget.targetCircle || oldWidget.authorFilter != widget.authorFilter) {
      setState(() {
        _streamKey++;
        _buildStream();
      });
    }
  }

  void _buildStream() {
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('circle', isEqualTo: widget.targetCircle) 
        .orderBy('createdAt', descending: true);
        
    if (widget.authorFilter != null) {
      query = query.where('author', isEqualTo: widget.authorFilter);
    }
    _feedStream = query.snapshots();
  }

  @override void dispose() { _refreshSub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // ── DYNAMIC PADDING ──
    // Pushes the list down 64px if the badge is visible, snaps back to 16px if not!
    final dynamicTopPadding = widget.hasUnreadBadge ? 64.0 : 16.0;

    return RefreshIndicator(
      color: BT.pastelPurple,
      backgroundColor: BT.card,
      strokeWidth: 3,
      onRefresh: widget.onRefresh,
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey(_streamKey),
        stream: _feedStream,
        builder: (context, snapshot) {
          
          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            final needsIndex = err.contains('indexes') || err.contains('index');
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('⚙️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  needsIndex
                      ? 'Firestore Index needed for this Circle!\nCheck your debug console and click the link to build it.'
                      : 'Something went wrong loading feed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BT.textSecondary, fontSize: 13, height: 1.5)),
              ])));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: EdgeInsets.only(
                  top: dynamicTopPadding, bottom: 130, left: 14, right: 14),
              itemCount: 4,
              itemBuilder: (_, __) => const SkeletonBubble());
          }

          final docs = snapshot.data?.docs ?? [];

          if (widget.onCountChanged != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onCountChanged!(docs.length);
            });
          }

          if (docs.isEmpty) return ListView(
            padding: EdgeInsets.only(top: dynamicTopPadding),
            children: const [
              SizedBox(height: 150),
              Center(child: Text('💬', style: TextStyle(fontSize: 52))),
              SizedBox(height: 16),
              Center(child: Text('Nothing here yet.',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BT.textPrimary))),
              SizedBox(height: 6),
              Center(child: Text('Be the first to pop off.',
                  style: TextStyle(color: BT.textSecondary, fontSize: 14))),
          ]);

          return ListView.builder(
            padding: EdgeInsets.only(
                top: dynamicTopPadding, bottom: 130, left: 14, right: 14),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final post = Post.fromFirestore(docs[i]);
              final isPopped = widget.poppedPostIds.contains(post.id);
              return FeedItemAnimator(
                key: ValueKey(post.id),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RantCard(
                    post: post,
                    isPopped: isPopped,
                    bubbleAsset: widget.bubbleAsset,
                    onPopAction: () => widget.onPop(post.id),
                    onCardTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ThreadScreen(post: post))),
                  ),
                ),
              );
            });
        }),
    );
  }
}

// ============================================================================
// HEADER AVATAR
// ============================================================================
class _HeaderAvatar extends StatefulWidget {
  final String profileUrl, initial;
  const _HeaderAvatar({required this.profileUrl, required this.initial});
  @override State<_HeaderAvatar> createState() => _HeaderAvatarState();
}

class _HeaderAvatarState extends State<_HeaderAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            startAngle: 0, endAngle: math.pi * 2,
            transform: GradientRotation(_ctrl.value * math.pi * 2),
            colors: const [
              BT.pastelPink, BT.pastelPurple, BT.pastelBlue,
              BT.pastelMint, BT.pastelYellow, BT.pastelPink,
            ]),
          boxShadow: [
            BoxShadow(color: BT.pastelPurple.withOpacity(0.30), blurRadius: 8)
          ]),
        child: Padding(padding: const EdgeInsets.all(2.5), child: child)),
      child: Container(
        decoration: const BoxDecoration(color: BT.bg, shape: BoxShape.circle),
        child: ClipOval(
          child: widget.profileUrl.isNotEmpty
              ? Image.network(widget.profileUrl,
                  width: 35, height: 35, fit: BoxFit.cover)
              : Container(
                  width: 35, height: 35,
                  color: BT.pastelPurple,
                  child: Center(child: Text(widget.initial,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w900)))))),
    );
  }
}

// ============================================================================
// PULSING DOT
// ============================================================================
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.25)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.white.withOpacity(0.6 * _scale.value),
                  blurRadius: 4 * _scale.value,
                  spreadRadius: 1)
            ]))));
  }
}

// ============================================================================
// COMPOSE BUTTON
// ============================================================================
class _ComposeParticle {
  final double angle, distance, size;
  final Color color;
  _ComposeParticle({required this.angle, required this.distance, required this.color, required this.size});
}

class _ComposeParticlePainter extends CustomPainter {
  final List<_ComposeParticle> particles;
  final double progress;
  _ComposeParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final t = Curves.easeOut.transform(progress);
      final opacity = (1.0 - progress * 1.1).clamp(0.0, 1.0);
      final dx = math.cos(p.angle) * p.distance * t;
      final dy = math.sin(p.angle) * p.distance * t;
      canvas.drawCircle(
        center + Offset(dx, dy),
        (p.size * (1.0 - progress * 0.35)).clamp(1.0, 10.0),
        Paint()..color = p.color.withOpacity(opacity * 0.9));
    }
  }

  @override bool shouldRepaint(_ComposeParticlePainter old) => old.progress != progress;
}

class _ComposeButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ComposeButton({required this.onTap});
  @override State<_ComposeButton> createState() => _ComposeButtonState();
}

class _ComposeButtonState extends State<_ComposeButton> with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _glowCtrl;
  late Animation<double>   _glow;
  late AnimationController _popCtrl;
  late Animation<double>   _bubbleScale;
  late Animation<double>   _bubbleOpacity;
  late Animation<double>   _particleProgress;
  late Animation<double>   _iconScale;
  late Animation<double>   _iconOpacity;

  List<_ComposeParticle> _particles = [];
  bool _animating = false;

  static const double _btnSize = 68.0;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 10.0, end: 24.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

    _bubbleScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),  weight: 32),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
    ]).animate(_popCtrl);

    _bubbleOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 22),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
    ]).animate(_popCtrl);

    _particleProgress = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 78),
    ]).animate(_popCtrl);

    _iconOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 48),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 22),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
    ]).animate(_popCtrl);

    _iconScale = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_popCtrl);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  List<_ComposeParticle> _generateParticles() {
    final rng = math.Random();
    const palette = [
      BT.pastelPink, BT.pastelPurple, BT.pastelBlue,
      BT.pastelMint, BT.pastelYellow, BT.pastelCoral, Colors.white
    ];
    return List.generate(22, (i) => _ComposeParticle(
      angle:    (i / 22) * math.pi * 2 + rng.nextDouble() * 0.35,
      distance: 44 + rng.nextDouble() * 44,
      color:    palette[rng.nextInt(palette.length)],
      size:     3.5 + rng.nextDouble() * 5.5,
    ));
  }

  void _handleTap() {
    if (_animating) return;
    HapticFeedback.mediumImpact();
    _particles = _generateParticles();
    setState(() => _animating = true);

    _popCtrl.forward(from: 0).then((_) {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => _animating = false);
      }
    });

    Future.delayed(const Duration(milliseconds: 120), widget.onTap);
  }

  @override
  Widget build(BuildContext context) {
    const double canvas = _btnSize + 56;

    return SizedBox(
      width: canvas, height: canvas,
      child: Stack(alignment: Alignment.center, children: [

        if (_animating)
          Positioned.fill(child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particleProgress,
              builder: (_, __) => CustomPaint(
                painter: _ComposeParticlePainter(
                  particles: _particles,
                  progress: _particleProgress.value))))),

        if (!_animating)
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: _btnSize, height: _btnSize,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: BT.pastelPink.withOpacity(0.40),   blurRadius: _glow.value, spreadRadius: 2),
                BoxShadow(color: BT.pastelPurple.withOpacity(0.28), blurRadius: _glow.value * 1.5),
              ]))),

        AnimatedBuilder(
          animation: _popCtrl,
          builder: (_, child) {
            final scale   = _animating ? _bubbleScale.value   : 1.0;
            final opacity = _animating ? _bubbleOpacity.value : 1.0;
            if (scale <= 0.01) return const SizedBox.shrink();
            return Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child));
          },
          child: GestureDetector(
            onTap: _handleTap,
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, child) {
                final t = _shimmerCtrl.value;
                return Container(
                  width: _btnSize, height: _btnSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        BT.pastelPink.withOpacity(0.90),
                        BT.pastelPurple.withOpacity(0.85),
                        BT.pastelBlue.withOpacity(0.70),
                      ]),
                    boxShadow: [
                      BoxShadow(color: BT.pastelPurple.withOpacity(0.5),
                          blurRadius: 12, offset: const Offset(0, 4)),
                    ]),
                  child: Stack(fit: StackFit.expand, children: [
                    ClipOval(child: Container(
                      decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment(-2.0 + t * 4.0, -0.6),
                        end:   Alignment(-1.4 + t * 4.0,  0.6),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.22),
                          BT.pastelMint.withOpacity(0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.65, 1.0])))),
                    Positioned(top: 6, left: 10,
                      child: Container(
                        width: 22, height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.52),
                          borderRadius: BorderRadius.circular(8)))),
                    const Positioned(top: 10, right: 12, child: _BtnSparkle(size: 8)),
                    const Positioned(bottom: 14, left: 10, child: _BtnSparkle(size: 6)),
                    Center(child: child),
                  ]));
              },
              child: _animating
                  ? AnimatedBuilder(
                      animation: _iconScale,
                      builder: (_, __) => Transform.scale(
                        scale: _iconScale.value,
                        child: Opacity(
                          opacity: _iconOpacity.value,
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 30))))
                  : const Icon(Icons.edit_rounded, color: Colors.white, size: 30),
            )),
        ),
      ]),
    );
  }
}

class _BtnSparkle extends StatelessWidget {
  final double size;
  const _BtnSparkle({required this.size});
  @override Widget build(BuildContext context) =>
      Text('✦', style: TextStyle(
          fontSize: size, color: Colors.white.withOpacity(0.70)));
}