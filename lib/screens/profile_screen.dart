import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/post.dart';
import '../widgets/bubble_components.dart';
import '../widgets/rant_card.dart';
import 'thread_screen.dart';

// ============================================================================
// PROFILE SCREEN
// ============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tab;
  final String _bubbleAsset = 'assets/images/image_0.png';
  final Set<String> _poppedPostIds = {};

  late AnimationController _entryCtrl;
  late Animation<double> _entryOpacity;
  late Animation<Offset> _entrySlide;

  String _queryHandle = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();
    _loadUserHandle();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadUserHandle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String handle = '';
      if (doc.exists && doc.data() != null) handle = doc.data()!['username'] ?? '';
      if (handle.isEmpty) handle = user.displayName ?? 'user';
      handle = handle.replaceAll('@', '');
      if (mounted) setState(() => _queryHandle = '@$handle');
    } catch (e) {
      if (mounted) setState(() => _queryHandle = '@${user.displayName?.replaceAll('@', '') ?? 'user'}');
    }
  }

  void _openEditProfile(Map<String, dynamic> currentData) async {
    HapticFeedback.lightImpact();
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => EditProfileScreen(currentData: currentData)));
    _loadUserHandle();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: BT.bg,
        body: FadeTransition(
          opacity: _entryOpacity,
          child: SlideTransition(
            position: _entrySlide,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // ── PROFILE HEADER (Banner now starts at the very top edge) ──
                SliverToBoxAdapter(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                    builder: (context, snapshot) {
                      Map<String, dynamic> userData = {};
                      if (snapshot.hasData && snapshot.data!.exists) {
                        userData = snapshot.data!.data() as Map<String, dynamic>;
                      }
                      String streamUsername = (userData['username'] ?? user.displayName ?? 'user').replaceAll('@', '');
                      final displayName  = userData['name']       ?? streamUsername;
                      final initial      = displayName.isNotEmpty  ? displayName[0].toUpperCase() : '✦';
                      final bio          = userData['bio']         ?? 'Living in the Bubble 🫧\nJust popping rants and sharing vibes.';
                      final profileUrl   = userData['profileUrl']  ?? '';
                      final bannerUrl    = userData['bannerUrl']   ?? '';
                      final creationTime = user.metadata.creationTime;
                      final joinedDate   = creationTime != null
                          ? DateFormat('MMMM yyyy').format(creationTime) : 'March 2026';

                      final lastActiveRaw = userData['lastActiveAt'];
                      _ActivityStatus activityStatus = _ActivityStatus.none;
                      if (lastActiveRaw != null) {
                        final lastActive = (lastActiveRaw as Timestamp).toDate();
                        final diff = DateTime.now().difference(lastActive);
                        if (diff.inHours < 1) activityStatus = _ActivityStatus.active;
                        else if (diff.inHours < 24) activityStatus = _ActivityStatus.recently;
                      }

                      final circleCount = userData['circleCount']?.toString() ?? '—';
                      final streak      = userData['streak'] != null ? '${userData['streak']} 🔥' : '—';
                      final topMood     = userData['topMood'] ?? '✨ Vibing';

                      return _ProfileHeader(
                        displayName: displayName,
                        username: streamUsername,
                        initial: initial,
                        bio: bio,
                        profileUrl: profileUrl,
                        bannerUrl: bannerUrl,
                        joinedDate: joinedDate,
                        topMood: topMood,
                        circleCount: circleCount,
                        streak: streak,
                        activityStatus: activityStatus,
                        queryHandle: _queryHandle,
                        userData: userData,
                        onEditTap: () => _openEditProfile(userData),
                      );
                    },
                  ),
                ),

                // ── STICKY TAB BAR ─────────────────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tab,
                      indicatorColor: BT.pastelPurple,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: BT.textPrimary,
                      unselectedLabelColor: BT.textTertiary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      dividerColor: BT.divider,
                      tabs: const [Tab(text: 'Rants'), Tab(text: 'Replies')],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tab,
                children: [
                  _queryHandle.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: BT.pastelPurple))
                      : _buildMyFeed(_queryHandle),
                  _queryHandle.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: BT.pastelPurple))
                      : _buildMyRepliesFeed(_queryHandle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── RANTS FEED ──────────────────────────────────────────────────────────────
  Widget _buildMyFeed(String queryHandle) {
    final query = FirebaseFirestore.instance
        .collection('posts')
        .where('author', isEqualTo: queryHandle)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error:\n${snapshot.error}',
            style: const TextStyle(color: BT.textSecondary, fontSize: 12),
            textAlign: TextAlign.center)));
        if (snapshot.connectionState == ConnectionState.waiting)
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 130, left: 14, right: 14),
            itemCount: 3, itemBuilder: (_, __) => const SkeletonBubble());

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('📭', style: TextStyle(fontSize: 44)),
            SizedBox(height: 14),
            Text('No rants yet.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BT.textPrimary)),
            SizedBox(height: 6),
            Text('Your bubble pop-offs will show here.', style: TextStyle(color: BT.textSecondary, fontSize: 14)),
          ]));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 130, left: 14, right: 14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final post = Post.fromFirestore(docs[i]);
            final isPopped = _poppedPostIds.contains(post.id);
            return FeedItemAnimator(
              key: ValueKey(post.id), index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RantCard(
                  post: post, isPopped: isPopped, bubbleAsset: _bubbleAsset,
                  onPopAction: () => setState(() => _poppedPostIds.add(post.id)),
                  onCardTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ThreadScreen(post: post))),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── REPLIES FEED WITH CONTEXT BOX ────────────────────────────────────────────
  Widget _buildMyRepliesFeed(String queryHandle) {
    final query = FirebaseFirestore.instance
        .collectionGroup('comments')
        .where('author', isEqualTo: queryHandle)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
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
                    ? 'This tab needs a Firestore index.\nOpen your debug console, tap the link in the error, and create the index.'
                    : 'Something went wrong loading replies.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BT.textSecondary, fontSize: 13, height: 1.5)),
            ])));
        }
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator(color: BT.pastelPurple));

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('💬', style: TextStyle(fontSize: 44)),
            SizedBox(height: 14),
            Text('No replies yet.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BT.textPrimary)),
            SizedBox(height: 6),
            Text('When you reply to others, they show up here.', style: TextStyle(color: BT.textSecondary, fontSize: 14)),
          ]));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 130, left: 14, right: 14),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildReplyCard(docs[i]),
        );
      },
    );
  }

  Widget _buildReplyCard(QueryDocumentSnapshot commentDoc) {
    final data = commentDoc.data() as Map<String, dynamic>;
    String formattedTime = 'Just now';
    if (data['createdAt'] != null)
      formattedTime = DateFormat('MMM d, h:mm a').format((data['createdAt'] as Timestamp).toDate());

    final parentRef = commentDoc.reference.parent.parent;

    return FutureBuilder<DocumentSnapshot>(
      future: parentRef?.get(),
      builder: (context, snapshot) {
        Post? parentPost;
        String parentAuthor = 'someone';
        String parentText = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          parentPost = Post.fromFirestore(snapshot.data!);
          parentAuthor = parentPost.author;
          parentText = parentPost.text;
        }

        return GestureDetector(
          onTap: () {
            if (parentPost != null)
              Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadScreen(post: parentPost!)));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(bottom: 16),
            decoration: ShapeDecoration(
              color: BT.card,
              shape: const BubbleTailShape(borderRadius: 24, side: BorderSide(color: BT.divider, width: 1))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              
              if (parentPost != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BT.bg.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BT.divider, width: 1)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.reply_rounded, size: 14, color: BT.textTertiary),
                        const SizedBox(width: 6),
                        Text('Replying to $parentAuthor',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BT.textTertiary)),
                      ]),
                      if (parentText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(parentText, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: BT.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                    ]))),
                const Divider(height: 1, color: BT.divider),
              ],
              
              Padding(
                padding: EdgeInsets.fromLTRB(14, parentPost != null ? 12 : 12, 14, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BubbleAvatar(
                    author: data['author'] ?? '',
                    seed: data['avatarSeed'] ?? 'X',
                    colorIndex: data['avatarColorIndex'] ?? 0,
                    radius: 17),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(data['author'] ?? 'Unknown',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13))),
                      const SizedBox(width: 4),
                      const Text('·', style: TextStyle(color: BT.textTertiary)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(formattedTime,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: BT.textTertiary, fontSize: 11.5))),
                    ]),
                    const SizedBox(height: 5),
                    Text(data['text'] ?? '',
                      style: const TextStyle(fontSize: 13.5, color: BT.textPrimary, height: 1.4)),
                  ])),
                ])),
            ])));
      });
  }
}

// ============================================================================
// ACTIVITY STATUS
// ============================================================================
enum _ActivityStatus { active, recently, none }

extension _ActivityStatusX on _ActivityStatus {
  Color get dotColor {
    switch (this) {
      case _ActivityStatus.active:   return BT.pastelMint;
      case _ActivityStatus.recently: return BT.pastelYellow;
      case _ActivityStatus.none:     return Colors.transparent;
    }
  }
  String get label {
    switch (this) {
      case _ActivityStatus.active:   return 'Active now';
      case _ActivityStatus.recently: return 'Active today';
      case _ActivityStatus.none:     return '';
    }
  }
}

// ============================================================================
// PROFILE HEADER
// ============================================================================
class _ProfileHeader extends StatefulWidget {
  final String displayName, username, initial, bio, profileUrl, bannerUrl;
  final String joinedDate, topMood, circleCount, streak, queryHandle;
  final _ActivityStatus activityStatus;
  final Map<String, dynamic> userData;
  final VoidCallback onEditTap;

  const _ProfileHeader({
    required this.displayName, required this.username, required this.initial,
    required this.bio, required this.profileUrl, required this.bannerUrl,
    required this.joinedDate, required this.topMood,
    required this.circleCount, required this.streak,
    required this.activityStatus, required this.queryHandle,
    required this.userData, required this.onEditTap,
  });

  @override State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  @override void dispose() { _shimmerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── BANNER ──────────────────────────────────────────────────────────────
      _AnimatedBanner(bannerUrl: widget.bannerUrl, shimmerCtrl: _shimmerCtrl),

      // ── FROSTED GLASS INFO CARD ──────────────────────────────────────────
      Transform.translate(
        offset: const Offset(0, -44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              color: BT.card.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: BT.divider, width: 1),
              boxShadow: [
                BoxShadow(color: BT.pastelPurple.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── AVATAR + EDIT ROW ──────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ShimmerAvatar(
                          username: widget.username,
                          profileUrl: widget.profileUrl,
                          initial: widget.initial,
                          shimmerCtrl: _shimmerCtrl),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, top: 12),
                          child: GestureDetector(
                            onTap: widget.onEditTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              decoration: BoxDecoration(
                                color: BT.bg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: BT.divider, width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                              child: const Text('Edit profile',
                                style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5))))),
                      ]),

                    const SizedBox(height: 10),

                    // ── NAME + HANDLE + ACTIVE DOT ─────────────────────────
                    Text(widget.displayName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                        color: BT.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('@${widget.username}',
                        style: const TextStyle(fontSize: 14.5, color: BT.textSecondary)),
                      if (widget.activityStatus != _ActivityStatus.none) ...[
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: widget.activityStatus.dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: widget.activityStatus.dotColor.withOpacity(0.65),
                              blurRadius: 6)])),
                        const SizedBox(width: 5),
                        Text(widget.activityStatus.label,
                          style: const TextStyle(fontSize: 12, color: BT.textTertiary, fontWeight: FontWeight.w500)),
                      ],
                    ]),

                    const SizedBox(height: 14),

                    // ── EXPANDABLE BIO ──────────────────────────────────────
                    _ExpandableBio(bio: widget.bio),

                    const SizedBox(height: 14),

                    // ── JOINED DATE ─────────────────────────────────────────
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🫧', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('Joined ${widget.joinedDate}',
                        style: const TextStyle(color: BT.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),

                    const SizedBox(height: 16),

                    // ── REAL STAT PILLS ────────────────────────────────────
                    widget.queryHandle.isNotEmpty
                        ? _LiveStatRow(
                            queryHandle: widget.queryHandle,
                            circleCount: widget.circleCount,
                            streak: widget.streak,
                            topMood: widget.topMood)
                        : const SizedBox(height: 36),

                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 0),
    ]);
  }
}

// ============================================================================
// EXPANDABLE BIO  (3-line clamp with more/less toggle)
// ============================================================================
class _ExpandableBio extends StatefulWidget {
  final String bio;
  const _ExpandableBio({required this.bio});
  @override State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(
        text: TextSpan(
          text: widget.bio,
          style: const TextStyle(fontSize: 14.5, height: 1.45, color: BT.textPrimary)),
        maxLines: 3,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);

      final overflows = tp.didExceedMaxLines;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Text(widget.bio,
            maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, color: BT.textPrimary, height: 1.45)),
          secondChild: Text(widget.bio,
            style: const TextStyle(fontSize: 14.5, color: BT.textPrimary, height: 1.45)),
        ),
        if (overflows) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'less' : 'more',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: BT.pastelPurple.withOpacity(0.85)))),
        ],
      ]);
    });
  }
}

// ============================================================================
// LIVE STAT ROW  (real post count from Firestore)
// ============================================================================
class _LiveStatRow extends StatelessWidget {
  final String queryHandle, circleCount, streak, topMood;
  const _LiveStatRow({
    required this.queryHandle, required this.circleCount,
    required this.streak, required this.topMood,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .where('author', isEqualTo: queryHandle)
          .count()
          .get(),
      builder: (context, snapshot) {
        final postCount = snapshot.hasData
            ? snapshot.data!.count.toString()
            : '—';

        return Wrap(spacing: 10, runSpacing: 10, children: [
          _StatPill(count: postCount,   label: 'Popped',  color: BT.pastelPurple),
          _StatPill(count: circleCount, label: 'Circles', color: BT.pastelBlue),
          _StatPill(count: streak,      label: 'Streak',  color: BT.pastelYellow),
          _StatPill(count: topMood,     label: 'Mood',    color: BT.pastelMint),
        ]);
      },
    );
  }
}

// ============================================================================
// STAT PILL
// ============================================================================
class _StatPill extends StatelessWidget {
  final String count, label;
  final Color color;
  const _StatPill({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withOpacity(0.28), width: 1.2)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(count, style: TextStyle(
        fontWeight: FontWeight.w900, fontSize: 14.5, color: color)),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
          fontSize: 13, color: BT.textSecondary, fontWeight: FontWeight.w500)),
      ],
    ]));
}

// ============================================================================
// ANIMATED BANNER
// ============================================================================
class _AnimatedBanner extends StatefulWidget {
  final String bannerUrl;
  final AnimationController shimmerCtrl;
  const _AnimatedBanner({required this.bannerUrl, required this.shimmerCtrl});
  @override State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner> with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _float = Tween<double>(begin: -4, end: 4)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _floatCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // INCREASED HEIGHT HERE TO PUSH BANNER UP
    return SizedBox(height: 175,
      child: Stack(fit: StackFit.expand, children: [
        if (widget.bannerUrl.isNotEmpty)
          Image.network(widget.bannerUrl, fit: BoxFit.cover)
        else
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [BT.pastelBlue, BT.pastelPurple, BT.pastelPink]))),

        if (widget.bannerUrl.isEmpty)
          AnimatedBuilder(animation: widget.shimmerCtrl, builder: (_, __) => Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment(-2.0 + widget.shimmerCtrl.value * 4.0, -0.5),
              end:   Alignment(-1.4 + widget.shimmerCtrl.value * 4.0,  0.5),
              colors: [Colors.transparent, Colors.white.withOpacity(0.16), Colors.transparent],
              stops: const [0.0, 0.5, 1.0])))),

        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(height: 50,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, BT.bg.withOpacity(0.6)])))),

        if (widget.bannerUrl.isEmpty) ...[
          AnimatedBuilder(animation: _float, builder: (_, __) => Stack(children: [
            Positioned(top: 20 + _float.value * 0.6, right: 32,  child: const _BannerSparkle(size: 16)),
            Positioned(top: 55 + _float.value * 0.9, left: 48,   child: const _BannerSparkle(size: 13)),
            Positioned(bottom: 38 + _float.value * 0.4, right: 80, child: const _BannerSparkle(size: 10)),
            Positioned(top: 28 + _float.value * 1.1, left: 22,   child: const _BannerSparkle(size: 8)),
          ])),
          Positioned(bottom: 18, right: 18,
            child: Text('Bubble!', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.35), letterSpacing: 0.5))),
        ],
      ]));
  }
}

class _BannerSparkle extends StatelessWidget {
  final double size;
  const _BannerSparkle({required this.size});
  @override Widget build(BuildContext context) =>
      Text('✦', style: TextStyle(fontSize: size, color: Colors.white.withOpacity(0.65)));
}

// ============================================================================
// SHIMMER AVATAR
// ============================================================================
class _ShimmerAvatar extends StatelessWidget {
  final String username, profileUrl, initial;
  final AnimationController shimmerCtrl;
  const _ShimmerAvatar({
    required this.username, required this.profileUrl,
    required this.initial, required this.shimmerCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerCtrl,
      builder: (_, child) => Container(
        width: 92, height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            startAngle: 0, endAngle: math.pi * 2,
            transform: GradientRotation(shimmerCtrl.value * math.pi * 2),
            colors: const [
              BT.pastelPink, BT.pastelPurple, BT.pastelBlue,
              BT.pastelMint, BT.pastelYellow, BT.pastelPink,
            ]),
          boxShadow: [BoxShadow(
            color: BT.pastelPurple.withOpacity(0.35),
            blurRadius: 14, spreadRadius: 1)]),
        child: Padding(padding: const EdgeInsets.all(3.5), child: child)),
      child: Container(
        decoration: const BoxDecoration(color: BT.bg, shape: BoxShape.circle),
        child: ClipOval(
          child: profileUrl.isNotEmpty
              ? Image.network(profileUrl, width: 85, height: 85, fit: BoxFit.cover)
              : BubbleAvatar(author: '@$username', seed: initial, colorIndex: 4, radius: 42.5))),
    );
  }
}

// ============================================================================
// TAB BAR DELEGATE
// ============================================================================
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  const _TabBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ClipRect(child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(color: BT.bg.withOpacity(0.88), child: _tabBar)));
  @override bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ============================================================================
// EDIT PROFILE SCREEN
// ============================================================================
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const EditProfileScreen({Key? key, required this.currentData}) : super(key: key);
  @override State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _nameCtrl, _usernameCtrl, _bioCtrl;
  Uint8List? _newAvatarBytes, _newBannerBytes;
  bool _isSaving = false, _hasChanges = false;
  int _bioLength = 0;

  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    final user = FirebaseAuth.instance.currentUser;
    final defaultUsername =
        (widget.currentData['username'] ?? user?.displayName ?? '').replaceAll('@', '');
    final defaultName = widget.currentData['name'] ?? defaultUsername;
    final defaultBio  = widget.currentData['bio']  ??
        'Living in the Bubble 🫧\nJust popping rants and sharing vibes.';

    _nameCtrl     = TextEditingController(text: defaultName);
    _usernameCtrl = TextEditingController(text: defaultUsername);
    _bioCtrl      = TextEditingController(text: defaultBio);
    _bioLength    = defaultBio.length;

    void markChanged() => setState(() => _hasChanges = true);
    _nameCtrl.addListener(markChanged);
    _usernameCtrl.addListener(markChanged);
    _bioCtrl.addListener(() {
      setState(() { _bioLength = _bioCtrl.text.length; _hasChanges = true; });
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _bioCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BT.card,
        title: const Text('Discard changes?',
          style: TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary)),
        content: const Text('You have unsaved changes. Leave without saving?',
          style: TextStyle(color: BT.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing', style: TextStyle(color: BT.pastelPurple, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.w700))),
        ]));
    return leave ?? false;
  }

  Future<void> _pickImage(bool isAvatar) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (isAvatar) _newAvatarBytes = bytes;
        else _newBannerBytes = bytes;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newUsername = _usernameCtrl.text.trim().replaceAll('@', '');
    if (_nameCtrl.text.trim().isEmpty || newUsername.isEmpty) return;
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final oldUsername =
        (widget.currentData['username'] ?? user.displayName ?? '').replaceAll('@', '');

    try {
      String? newAvatarUrl, newBannerUrl;
      if (_newAvatarBytes != null) {
        final ref = FirebaseStorage.instance.ref().child('profiles/${user.uid}_avatar.jpg');
        await ref.putData(_newAvatarBytes!);
        newAvatarUrl = await ref.getDownloadURL();
      }
      if (_newBannerBytes != null) {
        final ref = FirebaseStorage.instance.ref().child('profiles/${user.uid}_banner.jpg');
        await ref.putData(_newBannerBytes!);
        newBannerUrl = await ref.getDownloadURL();
      }

      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'username': newUsername,
        'bio': _bioCtrl.text.trim(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      };
      if (newAvatarUrl != null) updates['profileUrl'] = newAvatarUrl;
      if (newBannerUrl != null) updates['bannerUrl']  = newBannerUrl;

      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .set(updates, SetOptions(merge: true));

      if (oldUsername.isNotEmpty && oldUsername != newUsername) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in (await FirebaseFirestore.instance.collection('posts')
            .where('author', isEqualTo: '@$oldUsername').get()).docs)
          batch.update(doc.reference, {'author': '@$newUsername'});
        for (final doc in (await FirebaseFirestore.instance.collection('posts')
            .where('originalAuthor', isEqualTo: '@$oldUsername').get()).docs)
          batch.update(doc.reference, {'originalAuthor': '@$newUsername'});
        for (final doc in (await FirebaseFirestore.instance.collectionGroup('comments')
            .where('author', isEqualTo: '@$oldUsername').get()).docs)
          batch.update(doc.reference, {'author': '@$newUsername'});
        await batch.commit();
        await user.updateDisplayName(newUsername);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingBanner = widget.currentData['bannerUrl'] ?? '';
    final existingAvatar = widget.currentData['profileUrl'] ?? '';
    final fallbackInitial = _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'X';

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: BT.bg,
        appBar: AppBar(
          backgroundColor: BT.card, elevation: 0, surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: BT.textPrimary, size: 18),
            onPressed: () async { if (await _onWillPop()) Navigator.pop(context); }),
          title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 17)),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: BT.divider)),
          actions: [Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                borderRadius: BorderRadius.circular(20)),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, foregroundColor: Colors.white,
                  shadowColor: Colors.transparent, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: _isSaving
                    ? const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)))))]),

        body: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 195, child: Stack(children: [
              GestureDetector(
                onTap: () => _pickImage(false),
                child: SizedBox(
                  width: double.infinity, height: 145,
                  child: Stack(fit: StackFit.expand, children: [
                    if (_newBannerBytes != null)
                      Image.memory(_newBannerBytes!, fit: BoxFit.cover)
                    else if (existingBanner.isNotEmpty)
                      Image.network(existingBanner, fit: BoxFit.cover)
                    else
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [BT.pastelBlue, BT.pastelPurple, BT.pastelPink]))),
                    Container(
                      color: Colors.black.withOpacity(0.28),
                      child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 26),
                        SizedBox(height: 5),
                        Text('Change banner',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]))),
                  ])),
              ),

              Positioned(bottom: 0, left: 16,
                child: GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Stack(alignment: Alignment.center, children: [
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, child) => Container(
                        width: 92, height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            startAngle: 0, endAngle: math.pi * 2,
                            transform: GradientRotation(_ringCtrl.value * math.pi * 2),
                            colors: const [
                              BT.pastelPink, BT.pastelPurple, BT.pastelBlue,
                              BT.pastelMint, BT.pastelYellow, BT.pastelPink]),
                          boxShadow: [BoxShadow(
                            color: BT.pastelPurple.withOpacity(0.3), blurRadius: 12)]),
                        child: Padding(padding: const EdgeInsets.all(3.5), child: child)),
                      child: Container(
                        decoration: const BoxDecoration(color: BT.bg, shape: BoxShape.circle),
                        child: ClipOval(
                          child: _newAvatarBytes != null
                              ? Image.memory(_newAvatarBytes!, width: 85, height: 85, fit: BoxFit.cover)
                              : existingAvatar.isNotEmpty
                                  ? Image.network(existingAvatar, width: 85, height: 85, fit: BoxFit.cover)
                                  : BubbleAvatar(
                                      author: '@${_usernameCtrl.text}',
                                      seed: fallbackInitial, colorIndex: 4, radius: 42.5)))),
                    Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.25)),
                      child: const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 22)),
                  ])))
            ])),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _FieldLabel('Display Name'),
                const SizedBox(height: 7),
                _StyledField(controller: _nameCtrl, hint: 'Your display name'),
                const SizedBox(height: 20),

                const _FieldLabel('Username'),
                const SizedBox(height: 7),
                _StyledField(controller: _usernameCtrl, hint: 'yourhandle', prefixText: '@ '),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const _FieldLabel('Bio'),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _bioLength > 130
                          ? BT.heartRed.withOpacity(0.10)
                          : BT.divider.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('${160 - _bioLength}',
                      style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700,
                        color: _bioLength > 130 ? BT.heartRed : BT.textTertiary))),
                ]),
                const SizedBox(height: 7),
                Container(
                  decoration: BoxDecoration(
                    color: BT.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BT.divider, width: 1.5)),
                  child: TextField(
                    controller: _bioCtrl, maxLines: 4, maxLength: 160,
                    style: const TextStyle(fontSize: 14.5, color: BT.textPrimary, height: 1.45),
                    decoration: const InputDecoration(
                      hintText: "Tell everyone what you're about...",
                      hintStyle: TextStyle(color: BT.textTertiary, fontSize: 14.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      counterText: ''))),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BT.heartRed.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BT.heartRed.withOpacity(0.15), width: 1.2)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 3, height: 18,
                        decoration: BoxDecoration(
                          color: BT.heartRed, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      const Text('Account', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: BT.textPrimary)),
                    ]),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: BT.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BT.heartRed.withOpacity(0.22), width: 1.2)),
                        child: const Row(children: [
                          Icon(Icons.logout_rounded, color: BT.heartRed, size: 17),
                          SizedBox(width: 8),
                          Text('Log out', style: TextStyle(
                            color: BT.heartRed, fontWeight: FontWeight.w700, fontSize: 14)),
                        ]))),
                  ])),
              ])),
          ])),
      ),
    );
  }
}

// ── Small reusable form widgets ───────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);
  @override Widget build(BuildContext context) => Text(label,
    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
      color: BT.textSecondary, letterSpacing: 0.3));
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  const _StyledField({required this.controller, required this.hint, this.prefixText});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: BT.card, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BT.divider, width: 1.5)),
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15.5, color: BT.textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w400),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontSize: 15.5, color: BT.textTertiary, fontWeight: FontWeight.w600),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
}