import 'dart:ui';
import 'dart:async'; 
import 'dart:convert'; 
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:http/http.dart' as http; 
import 'package:url_launcher/url_launcher.dart'; 
import 'login.dart'; 
import 'spotify_service.dart'; 

// ============================================================================
// THEME  
// ============================================================================
class BT {
  static const Color bg       = Color(0xFFFAFAFD); 
  static const Color card     = Color(0xFFFFFFFF);
  static const Color divider  = Color(0xFFF0F0F5);

  static const Color pastelBlue   = Color(0xFFADD4EC); 
  static const Color pastelPink   = Color(0xFFFFB3C8); 
  static const Color pastelYellow = Color(0xFFFFF0A0); 
  static const Color pastelPurple = Color(0xFFCFB8E8); 
  static const Color pastelMint   = Color(0xFFB8EDD6); 
  static const Color pastelCoral  = Color(0xFFFFBDAD); 

  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFFADB5BD);

  static const Color heartRed   = Color(0xFFFF6B8A);
  static const Color repostTeal = Color(0xFF4ECDC4);
  static const Color spotify    = Color(0xFF1DB954);

  static Color pastelAt(int index) {
    const list = [pastelBlue, pastelPink, pastelPurple, pastelMint, pastelYellow, pastelCoral];
    return list[index % list.length];
  }
}

// ============================================================================
// MUSIC TRACK
// ============================================================================
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final Color dominantColor;
  final String? previewUrl; 

  const MusicTrack({
    required this.id, required this.title, required this.artist,
    required this.albumArt, this.dominantColor = const Color(0xFFADD4EC),
    this.previewUrl
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'title': title, 'artist': artist,
      'albumArt': albumArt, 'dominantColor': dominantColor.value,
      'previewUrl': previewUrl,
    };
  }

  factory MusicTrack.fromMap(Map<String, dynamic> map) {
    return MusicTrack(
      id: map['id'] ?? '', title: map['title'] ?? '',
      artist: map['artist'] ?? '', albumArt: map['albumArt'] ?? '',
      dominantColor: map['dominantColor'] != null ? Color(map['dominantColor']) : BT.pastelBlue,
      previewUrl: map['previewUrl'],
    );
  }
}

// ============================================================================
// MOOD TAG
// ============================================================================
enum MoodTag { rant, vent, hotTake, none }

extension MoodTagX on MoodTag {
  String get label {
    switch (this) {
      case MoodTag.rant:    return '😤 Rant';
      case MoodTag.vent:    return '😭 Vent';
      case MoodTag.hotTake: return '🔥 Hot Take';
      case MoodTag.none:    return '';
    }
  }
  Color get fg {
    switch (this) {
      case MoodTag.rant:    return const Color(0xFFE05C6B);
      case MoodTag.vent:    return const Color(0xFF5B8FD5);
      case MoodTag.hotTake: return const Color(0xFFE07B3A);
      case MoodTag.none:    return Colors.transparent;
    }
  }
  Color get bg {
    switch (this) {
      case MoodTag.rant:    return const Color(0xFFFFE8EC);
      case MoodTag.vent:    return const Color(0xFFE5EFFF);
      case MoodTag.hotTake: return const Color(0xFFFFF3E5);
      case MoodTag.none:    return Colors.transparent;
    }
  }
  
  String get name => toString().split('.').last;
  static MoodTag fromString(String s) {
    return MoodTag.values.firstWhere((m) => m.name == s, orElse: () => MoodTag.none);
  }
}

// ============================================================================
// POST MODEL 
// ============================================================================
class Post {
  final String id;
  final String author;
  final String avatarSeed;
  final int avatarColorIndex;
  final String timestamp;
  final String text;
  final MoodTag mood;
  int likes;
  int commentCount; 
  int repostCount;
  final String? imageUrl;
  final MusicTrack? music;

  final bool isRepost;
  final String? repostedBy; 
  final String? originalAuthor;
  final String? originalAvatarSeed;
  final int originalAvatarColorIndex;
  final String? originalText;
  final String? originalTimestamp;
  final String? originalImageUrl;

  Post({
    required this.id, required this.author, required this.avatarSeed,
    this.avatarColorIndex = 0, required this.timestamp, required this.text,
    required this.mood, required this.likes, required this.commentCount,
    this.repostCount = 0, this.imageUrl, this.music, 
    this.isRepost = false, this.repostedBy, this.originalAuthor,
    this.originalAvatarSeed, this.originalAvatarColorIndex = 0,
    this.originalText, this.originalTimestamp, this.originalImageUrl,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      author: data['author'] ?? 'Unknown',
      avatarSeed: data['avatarSeed'] ?? 'X',
      avatarColorIndex: data['avatarColorIndex'] ?? 0,
      timestamp: data['displayTime'] ?? 'Just now',
      text: data['text'] ?? '',
      mood: MoodTagX.fromString(data['mood'] ?? 'none'),
      likes: data['likes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
      imageUrl: data['imageUrl'],
      music: data['music'] != null ? MusicTrack.fromMap(data['music']) : null,
      isRepost: data['isRepost'] ?? false,
      repostedBy: data['repostedBy'],
      originalAuthor: data['originalAuthor'],
      originalAvatarSeed: data['originalAvatarSeed'],
      originalAvatarColorIndex: data['originalAvatarColorIndex'] ?? 0,
      originalText: data['originalText'],
      originalTimestamp: data['originalTimestamp'],
      originalImageUrl: data['originalImageUrl'],
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late TabController _tab;
  String _circle = 'Nom';
  final String _bubbleAsset = 'assets/images/image_0.png';

  final Set<String> _poppedPostIds = {}; 

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myDisplayName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';

    return Scaffold(
      backgroundColor: BT.bg,
      extendBody: true,
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(),
          _buildCircleSelector(),
          _buildTabBar(),
          Expanded(child: TabBarView(
            controller: _tab,
            children: [
              _buildLiveFeed(authorFilter: null), 
              _buildLiveFeed(authorFilter: myDisplayName), 
            ],
          )),
        ]),
      ),
      bottomNavigationBar: _buildPillNav(),
    );
  }

  Widget _buildLiveFeed({String? authorFilter}) {
    Query query = FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true);
    
    if (authorFilter != null) {
      query = query.where('author', isEqualTo: authorFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading feed.', style: TextStyle(color: BT.textTertiary)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: BT.pastelPurple));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('💬', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('Nothing here yet.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BT.textPrimary)),
            const SizedBox(height: 6),
            const Text('Be the first to pop off.', style: TextStyle(color: BT.textSecondary, fontSize: 14)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 130, left: 14, right: 14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final post = Post.fromFirestore(docs[i]);
            final isPopped = _poppedPostIds.contains(post.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RantCard(
                post: post,
                isPopped: isPopped,
                bubbleAsset: _bubbleAsset,
                onPopAction: () => setState(() => _poppedPostIds.add(post.id)),
                onCardTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadScreen(post: post)));
                },
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final initial = user?.displayName?.isNotEmpty == true ? user!.displayName![0].toUpperCase() : '✦';

    return Container(
      color: BT.card,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text('Are you sure you want to leave the bubble?'),
                backgroundColor: BT.card,
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: BT.textSecondary))),
                  TextButton(onPressed: () { Navigator.pop(context); _logout(); }, child: const Text('Log Out', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.bold))),
                ],
              )
            );
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: BT.pastelPurple,
              shape: BoxShape.circle,
              border: Border.all(color: BT.pastelPink, width: 2),
            ),
            child: Center(child: Text(initial,
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900))),
          ),
        ),
        const Spacer(),
        Image.asset('assets/images/Bubble_logo.png', height: 38,
          errorBuilder: (_, __, ___) => RichText(text: TextSpan(
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'B', style: TextStyle(color: BT.pastelPink.withOpacity(1.0), shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
              TextSpan(text: 'ubbl', style: TextStyle(color: BT.textPrimary, shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
              TextSpan(text: 'e', style: TextStyle(color: BT.pastelBlue.withOpacity(1.0), shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
              TextSpan(text: '!', style: TextStyle(color: BT.pastelYellow.withOpacity(1.0), shadows: [Shadow(color: Colors.black.withOpacity(0.15), blurRadius: 2, offset: const Offset(1, 1))])),
            ],
          ))),
        const Spacer(),
        Stack(children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BT.divider.withOpacity(0.6),
                shape: BoxShape.circle),
              child: const Icon(Icons.notifications_outlined, color: BT.textPrimary, size: 20)),
          ),
          Positioned(right: 2, top: 2, child: Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: BT.heartRed, shape: BoxShape.circle,
              border: Border.all(color: BT.card, width: 1.5)))),
        ]),
      ]),
    );
  }

  Widget _buildCircleSelector() {
    return Container(
      color: BT.card,
      padding: const EdgeInsets.only(bottom: 13, top: 2),
      child: Center(
        child: GestureDetector(
          onTap: _showCircleSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: BT.pastelBlue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(_circle, style: const TextStyle(
                fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5)),
              const SizedBox(width: 5),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 17),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: BT.card,
      child: TabBar(
        controller: _tab,
        indicatorColor: BT.pastelPurple,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: BT.divider,
        labelColor: BT.textPrimary,
        unselectedLabelColor: BT.textTertiary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        tabs: const [Tab(text: 'Feed'), Tab(text: 'My Posts')],
      ),
    );
  }

  Widget _buildPillNav() {
    final items = [
      {'icon': Icons.home_rounded,   'off': Icons.home_outlined,  'label': 'Home'},
      {'icon': Icons.search_rounded, 'off': Icons.search_rounded, 'label': 'Search'},
      {'icon': Icons.person_rounded, 'off': Icons.person_outlined, 'label': 'Profile'},
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 48, bottom: 28),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: BT.card,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(color: BT.pastelBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            final active = _navIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _navIndex = i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(width: 70,
                child: Center(child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active ? BT.pastelBlue.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle),
                  child: Icon(
                    active ? items[i]['icon'] as IconData : items[i]['off'] as IconData,
                    color: active ? const Color(0xFF6AAED6) : BT.textTertiary, size: 24),
                ))),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [BT.pastelPink, BT.pastelPurple]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: BT.pastelPurple.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          onPressed: _showComposeSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22)),
      ),
    );
  }

  void _showCircleSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CircleSheet(current: _circle, onSelect: (c) => setState(() => _circle = c)));
  }

  void _showComposeSheet() async {
    final success = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _ComposeSheet()
    );

    if (success == true) {
      _tab.animateTo(0); 
    }
  }
}

// ============================================================================
// RANT CARD
// ============================================================================
class RantCard extends StatefulWidget {
  final Post post;
  final String bubbleAsset;
  final bool isPopped; 
  final VoidCallback onPopAction; 
  final VoidCallback onCardTap;

  const RantCard({
    Key? key, required this.post, required this.bubbleAsset, 
    required this.isPopped, required this.onPopAction, required this.onCardTap
  }) : super(key: key);

  @override
  State<RantCard> createState() => _RantCardState();
}

class _RantCardState extends State<RantCard> with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _reposted = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _heartScale = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _heartCtrl.dispose(); super.dispose(); }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
    _heartCtrl.forward().then((_) => _heartCtrl.reverse());
  }

  void _toggleRepost() async {
    if (_reposted) return; 

    TextEditingController quoteCtrl = TextEditingController();
    
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BT.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Repost", style: TextStyle(fontWeight: FontWeight.w900, color: BT.textPrimary)),
        content: TextField(
          controller: quoteCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: BT.textPrimary),
          decoration: InputDecoration(
            hintText: "Add a comment (optional)...",
            hintStyle: const TextStyle(color: BT.textTertiary, fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BT.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BT.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BT.pastelPurple)),
            filled: true,
            fillColor: BT.bg,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: BT.textSecondary, fontWeight: FontWeight.bold))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Repost", style: TextStyle(color: BT.repostTeal, fontWeight: FontWeight.w900))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    HapticFeedback.lightImpact();
    setState(() => _reposted = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';
    final myInitial = myName.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'repostCount': FieldValue.increment(1),
      });

      final origAuthor = widget.post.isRepost ? widget.post.originalAuthor : widget.post.author;
      final origSeed = widget.post.isRepost ? widget.post.originalAvatarSeed : widget.post.avatarSeed;
      final origColor = widget.post.isRepost ? widget.post.originalAvatarColorIndex : widget.post.avatarColorIndex;
      final origText = widget.post.isRepost ? widget.post.originalText : widget.post.text;
      final origTime = widget.post.isRepost ? widget.post.originalTimestamp : widget.post.timestamp;
      final origImage = widget.post.isRepost ? widget.post.originalImageUrl : widget.post.imageUrl;
      final origMusic = widget.post.music?.toMap(); 

      await FirebaseFirestore.instance.collection('posts').add({
        'author': myName,
        'avatarSeed': myInitial,
        'avatarColorIndex': math.Random().nextInt(6),
        'text': quoteCtrl.text.trim(), 
        'mood': 'none',
        'likes': 0,
        'commentCount': 0,
        'repostCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'displayTime': 'Just now',
        'music': origMusic, 
        'isRepost': true,
        'repostedBy': myName,
        'originalAuthor': origAuthor,
        'originalAvatarSeed': origSeed,
        'originalAvatarColorIndex': origColor,
        'originalText': origText,
        'originalTimestamp': origTime,
        'originalImageUrl': origImage,
      });

    } catch (e) {
      setState(() => _reposted = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to repost: $e')));
    }
  }

  void _showEditSheet() {
    final editCtrl = TextEditingController(text: widget.post.text);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(width: 3.5, height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text('Edit Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
                ]),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
                    borderRadius: BorderRadius.circular(30)),
                  child: TextButton(
                    onPressed: isSaving ? null : () async {
                      if (editCtrl.text.trim().isEmpty) return;
                      setModalState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
                          'text': editCtrl.text.trim(),
                        });
                        if (!mounted) return;
                        Navigator.pop(context); 
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
                      }
                    }, 
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    child: isSaving 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
              ]),
              const SizedBox(height: 16),
              TextField(controller: editCtrl, autofocus: true, maxLines: 4, maxLength: 280,
                style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterStyle: TextStyle(color: BT.textTertiary, fontSize: 11))),
            ]),
          ),
        ),
      )
    );
  }

  void _showOptionsSheet() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';

    if (widget.post.author != myName) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: BT.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: BT.pastelBlue.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF6AAED6), size: 22)
                ),
                title: const Text('Edit this rant', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context); 
                  _showEditSheet();       
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: BT.heartRed.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: BT.heartRed, size: 22)
                ),
                title: const Text('Delete this rant', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () async {
                  Navigator.pop(context); 
                  HapticFeedback.mediumImpact();
                  try {
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).delete();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.isRepost) return _buildRepostCard();

    return GestureDetector(
      onTap: () {
        if (!widget.isPopped) { 
          HapticFeedback.mediumImpact(); 
          widget.onPopAction(); 
        } else { 
          widget.onCardTap(); 
        }
      },
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 320),
        crossFadeState: widget.isPopped ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: _buildBubble(),
        secondChild: _buildNormalCard(),
      ),
    );
  }

  Widget _buildBubble() {
    final pastel = BT.pastelAt(widget.post.avatarColorIndex);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity, height: 130,
        child: Stack(fit: StackFit.expand, children: [
          Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [pastel.withOpacity(0.5), BT.pastelBlue.withOpacity(0.3)]))),
          Image.asset(widget.bubbleAsset, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox()),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.white.withOpacity(0.3))),
          const Positioned(top: 16, left: 20, child: _Sparkle()),
          const Positioned(bottom: 18, right: 24, child: _Sparkle()),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: pastel.withOpacity(0.4), blurRadius: 16)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Tap to pop!', style: TextStyle(
                color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildNormalCard() {
    final p = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: BT.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BT.divider, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
        _buildCardText(p.text),
        if (p.imageUrl != null) _buildCardImage(p.imageUrl!),
        if (p.music != null) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: MusicAttachmentCard(track: p.music!)),
        const Divider(height: 1, color: BT.divider),
        _buildActions(),
      ]),
    );
  }

  Widget _buildRepostCard() {
    final p = widget.post;
    final hasComment = p.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: BT.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BT.divider, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            const Icon(Icons.repeat_rounded, size: 13, color: BT.repostTeal),
            const SizedBox(width: 5),
            Text('${p.repostedBy} reposted',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BT.repostTeal)),
            const Spacer(),
            GestureDetector(
              onTap: _showOptionsSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.transparent, 
                child: const Icon(Icons.more_horiz_rounded, color: BT.textTertiary, size: 20),
              ),
            ),
          ]),
        ),
        if (hasComment) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BubbleAvatar(seed: p.avatarSeed, colorIndex: p.avatarColorIndex, radius: 17),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(p.author, style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13)),
                  const SizedBox(width: 5),
                  const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 5),
                  Text(p.timestamp, style: const TextStyle(color: BT.textTertiary, fontSize: 11.5)),
                ]),
                const SizedBox(height: 3),
                Text(p.text, style: const TextStyle(fontSize: 14, color: BT.textPrimary, height: 1.4)),
              ])),
            ]),
          ),
        ] else
          const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: GestureDetector(
            onTap: widget.onCardTap,
            child: Container(
              decoration: BoxDecoration(
                color: BT.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BT.divider, width: 1),
              ),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: BT.pastelAt(p.originalAvatarColorIndex),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _BubbleAvatar(seed: p.originalAvatarSeed ?? 'X',
                            colorIndex: p.originalAvatarColorIndex, radius: 14),
                          const SizedBox(width: 7),
                          Text(p.originalAuthor ?? '', style: const TextStyle(
                            fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 12.5)),
                          const SizedBox(width: 4),
                          const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(p.originalTimestamp ?? '', style: const TextStyle(
                            color: BT.textTertiary, fontSize: 11)),
                        ]),
                        const SizedBox(height: 6),
                        Text(p.originalText ?? '', style: const TextStyle(
                          fontSize: 13.5, color: BT.textPrimary, height: 1.4)),
                        if (p.originalImageUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: Image.network(p.originalImageUrl!, width: double.infinity,
                              height: 140, fit: BoxFit.cover)),
                        ],
                        if (p.music != null) ...[
                          const SizedBox(height: 10),
                          MusicAttachmentCard(track: p.music!),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: BT.divider),
        _buildActions(),
      ]),
    );
  }

  Widget _buildCardHeader(String author, String seed, int colorIdx, String time, MoodTag mood) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(children: [
        _BubbleAvatar(seed: seed, colorIndex: colorIdx, radius: 18),
        const SizedBox(width: 10),
        Expanded(child: Row(children: [
          Text(author, style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5)),
          const SizedBox(width: 5),
          const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Text(time, style: const TextStyle(color: BT.textTertiary, fontSize: 12)),
        ])),
        if (mood != MoodTag.none) ...[_MoodPill(mood: mood), const SizedBox(width: 6)],
        GestureDetector(
          onTap: _showOptionsSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: Colors.transparent, 
            child: const Icon(Icons.more_horiz_rounded, color: BT.textTertiary, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildCardText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Text(text, style: const TextStyle(fontSize: 14.5, color: BT.textPrimary, height: 1.45)));
  }

  Widget _buildCardImage(String url) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(url, width: double.infinity, height: 220, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(height: 220,
            decoration: BoxDecoration(color: BT.pastelBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.image_outlined, color: BT.textTertiary, size: 36))))));
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleLike,
          child: Row(children: [
            ScaleTransition(scale: _heartScale,
              child: Icon(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _liked ? BT.heartRed : BT.textTertiary, size: 19)),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                color: _liked ? BT.heartRed : BT.textTertiary,
                fontWeight: FontWeight.w600, fontSize: 13),
              child: Text('${widget.post.likes + (_liked ? 1 : 0)}')),
          ]),
        ),
        const SizedBox(width: 20),
        GestureDetector(onTap: widget.onCardTap,
          child: Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: BT.textTertiary, size: 18),
            const SizedBox(width: 5),
            Text('${widget.post.commentCount}',
              style: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _toggleRepost,
          child: Row(children: [
            Icon(Icons.repeat_rounded,
              color: _reposted ? BT.repostTeal : BT.textTertiary, size: 20),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                color: _reposted ? BT.repostTeal : BT.textTertiary,
                fontWeight: FontWeight.w600, fontSize: 13),
              child: Text('${widget.post.repostCount + (_reposted ? 1 : 0)}')),
          ]),
        ),
        const Spacer(),
        const Icon(Icons.bookmark_border_rounded, color: BT.textTertiary, size: 19),
      ]),
    );
  }
}

// ============================================================================
// MUSIC ATTACHMENT CARD (THE APPLE MUSIC HACK)
// ============================================================================
class MusicAttachmentCard extends StatefulWidget {
  final MusicTrack track;
  const MusicAttachmentCard({Key? key, required this.track}) : super(key: key);

  @override
  State<MusicAttachmentCard> createState() => _MusicAttachmentCardState();
}

class _MusicAttachmentCardState extends State<MusicAttachmentCard>
    with SingleTickerProviderStateMixin {
  bool _playing = false;
  bool _loadingAudio = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _streamUrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() { 
    _pulseCtrl.dispose(); 
    _audioPlayer.dispose(); 
    super.dispose(); 
  }

  Future<void> _togglePlay() async {
    HapticFeedback.lightImpact();
    
    if (_playing) {
      await _audioPlayer.pause();
      setState(() => _playing = false);
      return;
    } 
    
    if (_streamUrl != null) {
      await _audioPlayer.play(UrlSource(_streamUrl!));
      setState(() => _playing = true);
      return;
    }

    setState(() => _loadingAudio = true);
    
    try {
      if (widget.track.previewUrl != null && widget.track.previewUrl!.isNotEmpty) {
        _streamUrl = widget.track.previewUrl!;
      } else {
        final query = Uri.encodeComponent('${widget.track.title} ${widget.track.artist}');
        final url = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1');
        
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            _streamUrl = data['results'][0]['previewUrl'];
          }
        }
      }

      if (_streamUrl != null) {
        await _audioPlayer.play(UrlSource(_streamUrl!));
        if (mounted) {
          setState(() {
            _playing = true;
            _loadingAudio = false;
          });
        }
      } else {
        throw Exception('No snippet found');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio snippet available for this track.'))
        );
      }
    }
  }

  Future<void> _openSpotify() async {
    final url = Uri.parse('https://open.spotify.com/track/${widget.track.id}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.dominantColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dominantColor.withOpacity(0.2), width: 1)),
      child: Row(children: [
        
        GestureDetector(
          onTap: _togglePlay,
          child: AnimatedBuilder(animation: _pulse,
            builder: (_, child) => Transform.scale(scale: _playing ? _pulse.value : 1.0, child: child),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.network(t.albumArt, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 44, height: 44,
                  color: t.dominantColor.withOpacity(0.3),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20))))),
        ),
        const SizedBox(width: 10),
        
        Expanded(child: GestureDetector(
          onTap: _togglePlay,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: BT.textPrimary, fontSize: 13)),
            Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: BT.textSecondary, fontSize: 11.5)),
          ]),
        )),
        
        const SizedBox(width: 8),
        
        GestureDetector(
          onTap: _openSpotify,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(color: BT.spotify, borderRadius: BorderRadius.circular(20)),
            child: const Text('↗ Spotify', style: TextStyle(color: Colors.white, fontSize: 9.5,
              fontWeight: FontWeight.w700))),
        ),
        
        const SizedBox(width: 8),
        
        GestureDetector(
          onTap: _loadingAudio ? null : _togglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _playing ? t.dominantColor : t.dominantColor.withOpacity(0.15),
              shape: BoxShape.circle),
            child: _loadingAudio 
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(t.dominantColor)),
                )
              : Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _playing ? Colors.white : t.dominantColor, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ============================================================================
// THREAD SCREEN
// ============================================================================
class ThreadScreen extends StatefulWidget {
  final Post post;
  const ThreadScreen({Key? key, required this.post}) : super(key: key);
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _replies = [];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BT.bg,
      appBar: AppBar(
        backgroundColor: BT.card, elevation: 0, surfaceTintColor: Colors.transparent,
        foregroundColor: BT.textPrimary,
        title: const Text('Thread', style: TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: BT.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
          child: const Divider(height: 1, color: BT.divider))),
      body: Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          children: [
            _buildOrigPost(),
            const SizedBox(height: 14),
            const Divider(height: 1, color: BT.divider),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Replies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BT.textSecondary))),
            ..._replies.map((r) => _buildReply(r)),
            if (_replies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("No replies yet. Be the first!", style: TextStyle(color: BT.textTertiary))),
              )
          ])),
        _buildReplyBar(),
      ]),
    );
  }

  Widget _buildOrigPost() {
    final p = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: BT.card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BT.pastelPurple.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: BT.pastelPurple.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            _BubbleAvatar(seed: p.avatarSeed, colorIndex: p.avatarColorIndex, radius: 18),
            const SizedBox(width: 10),
            Expanded(child: Row(children: [
              Text(p.author, style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5)),
              const SizedBox(width: 5),
              const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 14)),
              const SizedBox(width: 5),
              Text(p.timestamp, style: const TextStyle(color: BT.textTertiary, fontSize: 12)),
            ])),
            if (p.mood != MoodTag.none) _MoodPill(mood: p.mood),
          ])),
        if (p.imageUrl != null)
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.network(p.imageUrl!, width: double.infinity, height: 200, fit: BoxFit.cover))),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text(p.text, style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5))),
        if (p.music != null)
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: MusicAttachmentCard(track: p.music!)),
        const Divider(height: 1, color: BT.divider),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.favorite_border_rounded, color: BT.textTertiary, size: 18),
            const SizedBox(width: 4),
            Text('${p.likes}', style: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 18),
            const Icon(Icons.chat_bubble_outline_rounded, color: BT.textTertiary, size: 17),
            const SizedBox(width: 4),
            Text('${p.commentCount}', style: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 18),
            const Icon(Icons.repeat_rounded, color: BT.textTertiary, size: 18),
            const SizedBox(width: 4),
            Text('${p.repostCount}', style: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
      ]),
    );
  }

  Widget _buildReply(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: BT.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BT.divider, width: 1)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BubbleAvatar(seed: r['seed'] as String, colorIndex: r['ci'] as int, radius: 17),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(r['author'] as String, style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13)),
            const SizedBox(width: 5),
            const Text('·', style: TextStyle(color: BT.textTertiary)),
            const SizedBox(width: 5),
            Text(r['time'] as String, style: const TextStyle(color: BT.textTertiary, fontSize: 11.5)),
          ]),
          const SizedBox(height: 5),
          Text(r['text'] as String, style: const TextStyle(fontSize: 13.5, color: BT.textPrimary, height: 1.4)),
        ])),
        const Icon(Icons.favorite_border_rounded, color: BT.divider, size: 16),
      ]),
    );
  }

  Widget _buildReplyBar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final initial = currentUser?.displayName?.isNotEmpty == true ? currentUser!.displayName![0].toUpperCase() : '✦';
    final name = currentUser?.displayName != null ? '@${currentUser!.displayName}' : '@Me';

    return Container(
      padding: EdgeInsets.only(left: 14, right: 14, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      decoration: const BoxDecoration(color: BT.card,
        border: Border(top: BorderSide(color: BT.divider, width: 1))),
      child: Row(children: [
        _BubbleAvatar(seed: initial, colorIndex: 4, radius: 17),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _ctrl,
          decoration: const InputDecoration(
            hintText: 'Post your reply...',
            hintStyle: TextStyle(color: BT.textTertiary, fontSize: 14),
            border: InputBorder.none, isDense: true))),
        GestureDetector(
          onTap: () {
            if (_ctrl.text.trim().isNotEmpty) {
              setState(() {
                _replies.add({'seed': initial, 'ci': 4, 'author': name,
                  'text': _ctrl.text.trim(), 'time': 'Just now'});
                _ctrl.clear();
              });
            }
          },
          child: Container(padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
              shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 17))),
      ]),
    );
  }
}

// ============================================================================
// COMPOSE SHEET
// ============================================================================
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();
  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  MoodTag _mood = MoodTag.none;
  MusicTrack? _music;
  final _ctrl = TextEditingController();
  bool _isPosting = false; 

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submitPost() async {
    if (_ctrl.text.isEmpty && _music == null) return;

    setState(() => _isPosting = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final name = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';
    final initial = name.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'author': name,
        'avatarSeed': initial,
        'avatarColorIndex': math.Random().nextInt(6),
        'text': _ctrl.text.trim(),
        'mood': _mood.name,
        'likes': 0,
        'commentCount': 0,
        'repostCount': 0,
        'createdAt': FieldValue.serverTimestamp(), 
        'displayTime': 'Just now',
        'music': _music?.toMap(),
      });

      if (!mounted) return;
      Navigator.pop(context, true); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 3.5, height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('New Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
            ]),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                borderRadius: BorderRadius.circular(30)),
              child: TextButton(
                onPressed: _isPosting ? null : _submitPost, 
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: _isPosting 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _ctrl, autofocus: true, maxLines: 4, maxLength: 280,
            style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
            decoration: InputDecoration(
              hintText: "what's going on?? ✦",
              hintStyle: TextStyle(color: BT.textTertiary.withOpacity(0.8), fontSize: 15),
              border: InputBorder.none,
              counterStyle: const TextStyle(color: BT.textTertiary, fontSize: 11))),
          if (_music != null) ...[
            MusicAttachmentCard(track: _music!),
            const SizedBox(height: 6),
            GestureDetector(onTap: () => setState(() => _music = null),
              child: const Text('Remove', style: TextStyle(color: BT.textTertiary, fontSize: 11.5,
                decoration: TextDecoration.underline))),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('MOOD  ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11,
                  color: BT.textTertiary, letterSpacing: 0.8)),
                ...MoodTag.values.where((m) => m != MoodTag.none).map((m) {
                  final active = _mood == m;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = active ? MoodTag.none : m),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? m.bg : BT.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? m.fg.withOpacity(0.5) : BT.divider, width: 1.5)),
                      child: Text(m.label, style: TextStyle(fontSize: 11.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? m.fg : BT.textSecondary))));
                }),
              ]))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(context: context, isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  builder: (_) => _MusicPickerSheet(onSelect: (t) { setState(() => _music = t); Navigator.pop(context); }));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _music != null ? BT.spotify.withOpacity(0.1) : BT.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _music != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.music_note_rounded,
                    color: _music != null ? BT.spotify : BT.textTertiary, size: 15),
                  const SizedBox(width: 5),
                  Text(_music != null ? 'Music ✓' : 'Music',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: _music != null ? BT.spotify : BT.textTertiary)),
                ]))),
          ]),
        ]),
      ),
    );
  }
}

// ── UPDATED: New Music Picker UI with Debounce ───────────────────────────────
class _MusicPickerSheet extends StatefulWidget {
  final void Function(MusicTrack) onSelect;
  const _MusicPickerSheet({required this.onSelect});

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  final _ctrl     = TextEditingController();
  final _spotify  = SpotifyService();
  Timer? _debounce; 

  List<MusicTrack> _results = [];
  bool   _loading = false;
  String _error   = '';

  @override
  void dispose() { 
    _ctrl.dispose(); 
    _debounce?.cancel();
    super.dispose(); 
  }

  Future<void> _search(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() { _results = []; _error = ''; _loading = false; });
      return;
    }

    setState(() { _loading = true; _error = ''; });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _spotify.searchTracks(query);
        if (mounted) {
          setState(() { _results = results; _loading = false; });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error   = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize:     0.92,
      minChildSize:     0.4,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: BT.divider,
              borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(children: [
              Container(width: 3.5, height: 20,
                decoration: BoxDecoration(
                  color: BT.spotify,
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('Add Music',
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17,
                  color: BT.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BT.spotify,
                  borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.music_note_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Spotify',
                    style: TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w700)),
                ])),
            ])),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: BT.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BT.divider, width: 1)),
              child: TextField(
                controller: _ctrl,
                onChanged: _search,
                style: const TextStyle(
                  fontSize: 14, color: BT.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search songs, artists...',
                  hintStyle: TextStyle(color: BT.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                    color: BT.textTertiary, size: 20),
                  border: InputBorder.none, isDense: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 12))))),

          const SizedBox(height: 12),

          Expanded(child: _buildBody(sc)),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ]),
      ),
    );
  }

  Widget _buildBody(ScrollController sc) {
    if (_loading) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(BT.spotify))),
          const SizedBox(height: 14),
          const Text('Finding tracks...',
            style: TextStyle(color: BT.textTertiary, fontSize: 13)),
        ]));
    }

    if (_error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('😵', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(_error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BT.heartRed, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _search(_ctrl.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [BT.pastelPink, BT.pastelPurple]),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('Try again',
                style: TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700)))),
        ])));
    }

    if (_ctrl.text.isNotEmpty && _results.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎵', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text('No results for "${_ctrl.text}"',
            style: const TextStyle(
              color: BT.textSecondary, fontSize: 13,
              fontWeight: FontWeight.w500)),
        ]));
    }

    if (_results.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎧', style: TextStyle(fontSize: 44)),
          SizedBox(height: 12),
          Text('Search for a song',
            style: TextStyle(
              color: BT.textPrimary, fontWeight: FontWeight.w700,
              fontSize: 15)),
          SizedBox(height: 6),
          Text('Type above to find something to vibe to',
            style: TextStyle(color: BT.textTertiary, fontSize: 13)),
        ]));
    }

    return ListView.builder(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final t = _results[i];
        return GestureDetector(
          onTap: () => widget.onSelect(t),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BT.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BT.divider, width: 1)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.albumArt.isNotEmpty
                  ? Image.network(t.albumArt,
                      width: 46, height: 46, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artPlaceholder(t))
                  : _artPlaceholder(t)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: BT.textPrimary, fontSize: 13.5)),
                  Text(t.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BT.textSecondary, fontSize: 12)),
                ])),
              Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: t.dominantColor,
                  shape: BoxShape.circle)),
              const Icon(Icons.add_circle_outline_rounded,
                color: BT.pastelPurple, size: 22),
            ]))); 
      });
  }

  Widget _artPlaceholder(MusicTrack t) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: t.dominantColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.music_note_rounded,
        color: Colors.white, size: 22));
  }
}

// ── Circle Sheet ─────────────────────────────────────────────────────────────
class _CircleSheet extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;
  const _CircleSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final circles = ['Nom', 'Heartstrings', 'The Void', 'Main Feed'];
    return Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3.5, height: 22, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
            borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          const Text('Switch Circle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...List.generate(circles.length, (i) {
          final c = circles[i]; final active = c == current;
          return GestureDetector(onTap: () { onSelect(c); Navigator.pop(context); },
            child: Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: active ? BT.pastelBlue.withOpacity(0.12) : BT.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? BT.pastelBlue.withOpacity(0.5) : BT.divider, width: 1)),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: active ? BT.pastelAt(i) : BT.divider, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Text(c, style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14, color: BT.textPrimary)),
                const Spacer(),
                if (active) const Icon(Icons.check_rounded, color: Color(0xFF6AAED6), size: 18),
              ])));
        }),
        const SizedBox(height: 8),
      ]));
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================
class _BubbleAvatar extends StatelessWidget {
  final String seed;
  final int colorIndex;
  final double radius;
  const _BubbleAvatar({required this.seed, required this.colorIndex, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: BT.pastelAt(colorIndex),
      child: Text(seed.isNotEmpty ? seed[0].toUpperCase() : 'X',
        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white,
          fontSize: radius * 0.78)));
  }
}

class _MoodPill extends StatelessWidget {
  final MoodTag mood;
  const _MoodPill({required this.mood});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: mood.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(mood.label, style: TextStyle(fontSize: 10.5, color: mood.fg, fontWeight: FontWeight.w700)));
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle();
  @override
  Widget build(BuildContext context) {
    return const Text('✦', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w400));
  }
}