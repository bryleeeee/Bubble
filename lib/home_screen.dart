import 'dart:ui';
import 'dart:async'; 
import 'dart:convert'; 
import 'dart:math' as math;
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:http/http.dart' as http; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:intl/intl.dart' hide TextDirection; 
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
  final List<String> imageUrls;
  final MusicTrack? music;

  final bool isRepost;
  final String? repostedBy; 
  final String? originalPostId; 
  final String? originalAuthor;
  final String? originalAvatarSeed;
  final int originalAvatarColorIndex;
  final String? originalText;
  final String? originalTimestamp;
  final List<String> originalImageUrls;

  Post({
    required this.id, required this.author, required this.avatarSeed,
    this.avatarColorIndex = 0, required this.timestamp, required this.text,
    required this.mood, required this.likes, required this.commentCount,
    this.repostCount = 0, this.imageUrls = const [], this.music, 
    this.isRepost = false, this.repostedBy, this.originalPostId,
    this.originalAuthor, this.originalAvatarSeed, this.originalAvatarColorIndex = 0,
    this.originalText, this.originalTimestamp, this.originalImageUrls = const [],
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    String formattedTime = 'Just now';
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      formattedTime = DateFormat('MMM d, yyyy • h:mm a').format(dt);
    }

    List<String> parsedUrls = [];
    if (data['imageUrls'] != null) {
      parsedUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null) {
      parsedUrls = [data['imageUrl'] as String];
    }

    List<String> originalParsedUrls = [];
    if (data['originalImageUrls'] != null) {
      originalParsedUrls = List<String>.from(data['originalImageUrls']);
    } else if (data['originalImageUrl'] != null) {
      originalParsedUrls = [data['originalImageUrl'] as String];
    }

    return Post(
      id: doc.id,
      author: data['author'] ?? 'Unknown',
      avatarSeed: data['avatarSeed'] ?? 'X',
      avatarColorIndex: data['avatarColorIndex'] ?? 0,
      timestamp: formattedTime, 
      text: data['text'] ?? '',
      mood: MoodTagX.fromString(data['mood'] ?? 'none'),
      likes: data['likes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
      imageUrls: parsedUrls, 
      music: data['music'] != null ? MusicTrack.fromMap(data['music']) : null,
      isRepost: data['isRepost'] ?? false,
      repostedBy: data['repostedBy'],
      originalPostId: data['originalPostId'],
      originalAuthor: data['originalAuthor'],
      originalAvatarSeed: data['originalAvatarSeed'],
      originalAvatarColorIndex: data['originalAvatarColorIndex'] ?? 0,
      originalText: data['originalText'],
      originalTimestamp: data['originalTimestamp'],
      originalImageUrls: originalParsedUrls, 
    );
  }
}

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
  OutlinedBorder copyWith({BorderSide? side}) {
    return BubbleTailShape(
      side: side ?? this.side,
      borderRadius: borderRadius,
      tailWidth: tailWidth,
      tailHeight: tailHeight,
    );
  }

  @override
  OutlinedBorder scale(double t) {
    return BubbleTailShape(
      side: side.scale(t),
      borderRadius: borderRadius * t,
      tailWidth: tailWidth * t,
      tailHeight: tailHeight * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect);
  }

  Path _getPath(Rect rect) {
    final double r = borderRadius;
    final double tW = tailWidth;
    final double tH = tailHeight;

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
    final paint = side.toPaint();
    canvas.drawPath(getOuterPath(rect), paint);
  }
}

class BubbleTailClipper extends CustomClipper<Path> {
  final double borderRadius;
  BubbleTailClipper({this.borderRadius = 28.0});
  
  @override
  Path getClip(Size size) {
    return BubbleTailShape(borderRadius: borderRadius).getOuterPath(Offset.zero & size);
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}


// ============================================================================
// NEW: INSTAGRAM-STYLE IMAGE CAROUSEL
// ============================================================================
class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final void Function(String) onImageTap;

  const ImageCarousel({
    Key? key,
    required this.imageUrls,
    this.height = 300, 
    required this.onImageTap,
  }) : super(key: key);

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            // --- FIX: ScrollConfiguration allows MOUSE DRAGGING on Web! ---
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,     // Enables clicking and dragging with a mouse!
                  PointerDeviceKind.trackpad,  // Enables two-finger swiping on laptops!
                },
              ),
              child: PageView.builder(
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => widget.onImageTap(widget.imageUrls[index]),
                    child: Container(
                      color: BT.bg, 
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: BT.textTertiary, size: 28)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // --- THE DYNAMIC PILL INDICATORS ---
        if (widget.imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) {
                final isActive = _currentIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  height: 6.0,
                  width: isActive ? 18.0 : 6.0, // Stretches into a pill when active
                  decoration: BoxDecoration(
                    color: isActive ? BT.pastelPurple : BT.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
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

  void _showRepostOptions() {
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
                  decoration: BoxDecoration(color: BT.repostTeal.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.repeat_rounded, color: BT.repostTeal, size: 22)
                ),
                title: const Text('Repost', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _executeRepost(isQuote: false); 
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: BT.pastelPurple.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: BT.pastelPurple, size: 22)
                ),
                title: const Text('Quote', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _openQuoteScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openQuoteScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuoteComposeScreen(post: widget.post))
    );
  }

  void _executeRepost({required bool isQuote}) async {
    if (_reposted) return; 

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

      final isStraightRepost = widget.post.isRepost && widget.post.text.isEmpty;
      final origAuthor = isStraightRepost ? widget.post.originalAuthor : widget.post.author;
      final origSeed = isStraightRepost ? widget.post.originalAvatarSeed : widget.post.avatarSeed;
      final origColor = isStraightRepost ? widget.post.originalAvatarColorIndex : widget.post.avatarColorIndex;
      final origText = isStraightRepost ? widget.post.originalText : widget.post.text;
      final origTime = isStraightRepost ? widget.post.originalTimestamp : widget.post.timestamp;
      
      final origImages = isStraightRepost ? widget.post.originalImageUrls : widget.post.imageUrls;
      final origMusic = widget.post.music?.toMap(); 

      await FirebaseFirestore.instance.collection('posts').add({
        'author': myName,
        'avatarSeed': myInitial,
        'avatarColorIndex': math.Random().nextInt(6),
        'text': '', 
        'mood': 'none',
        'likes': 0,
        'commentCount': 0,
        'repostCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'displayTime': 'Just now',
        'music': origMusic, 
        'isRepost': true,
        'originalPostId': isStraightRepost ? widget.post.originalPostId : widget.post.id, 
        'repostedBy': myName,
        'originalAuthor': origAuthor,
        'originalAvatarSeed': origSeed,
        'originalAvatarColorIndex': origColor,
        'originalText': origText,
        'originalTimestamp': origTime,
        'originalImageUrls': origImages, 
      });

    } catch (e) {
      setState(() => _reposted = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to repost: $e')));
    }
  }

  void _showEditSheet() {
    final editCtrl = TextEditingController(text: widget.post.text);
    bool isSaving = false;
    
    MusicTrack? editedMusic = widget.post.music;
    List<String> existingImageUrls = List.from(widget.post.imageUrls);
    List<Uint8List> newImageBytes = [];

    Future<void> pickEditImages(StateSetter setModalState) async {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      
      if (pickedFiles.isNotEmpty) {
        int currentTotal = existingImageUrls.length + newImageBytes.length;
        int remainingSlots = 4 - currentTotal;
        if (remainingSlots <= 0) return;

        int takeCount = math.min(pickedFiles.length, remainingSlots);
        List<Uint8List> bytesList = [];
        
        for (int i = 0; i < takeCount; i++) {
          final bytes = await pickedFiles[i].readAsBytes();
          bytesList.add(bytes);
        }

        setModalState(() {
          newImageBytes.addAll(bytesList);
        });
      }
    }

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
                      if (editCtrl.text.trim().isEmpty && editedMusic == null && existingImageUrls.isEmpty && newImageBytes.isEmpty) return;
                      
                      setModalState(() => isSaving = true);
                      try {
                        Map<String, dynamic> updates = {
                          'text': editCtrl.text.trim(),
                        };

                        List<String> finalUrls = List.from(existingImageUrls);

                        for (var bytes in newImageBytes) {
                          String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${newImageBytes.indexOf(bytes)}.jpg';
                          Reference ref = FirebaseStorage.instance.ref().child(fileName);
                          await ref.putData(bytes);
                          String url = await ref.getDownloadURL();
                          finalUrls.add(url);
                        }

                        updates['imageUrls'] = finalUrls;

                        if (editedMusic != null) {
                          updates['music'] = editedMusic!.toMap();
                        } else {
                          updates['music'] = FieldValue.delete();
                        }

                        await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update(updates);
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
              
              // --- LIVE MULTI-IMAGE PREVIEW IN EDIT ---
              if (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ...[
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...existingImageUrls.map((url) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 110, height: 110, fit: BoxFit.cover)),
                          Positioned(top: 6, right: 6, child: GestureDetector(
                            onTap: () => setModalState(() => existingImageUrls.remove(url)),
                            child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                        ]),
                      )),
                      ...newImageBytes.map((bytes) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, width: 110, height: 110, fit: BoxFit.cover)),
                          Positioned(top: 6, right: 6, child: GestureDetector(
                            onTap: () => setModalState(() => newImageBytes.remove(bytes)),
                            child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                        ]),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (editedMusic != null) ...[
                MusicAttachmentCard(track: editedMusic!),
                const SizedBox(height: 6),
                GestureDetector(onTap: () => setModalState(() => editedMusic = null),
                  child: const Text('Remove', style: TextStyle(color: BT.textTertiary, fontSize: 11.5, decoration: TextDecoration.underline))),
                const SizedBox(height: 10),
              ],

              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: BT.divider, width: 1))),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => pickEditImages(setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? BT.pastelBlue.withOpacity(0.1) : BT.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? BT.pastelBlue.withOpacity(0.4) : BT.divider, width: 1.5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.image_outlined,
                            color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary, size: 15),
                          const SizedBox(width: 5),
                          Text((existingImageUrls.isEmpty && newImageBytes.isEmpty) ? 'Image' : '${existingImageUrls.length + newImageBytes.length} / 4 ✓',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary)),
                        ]))),
                        
                    const SizedBox(width: 10),
                    
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                          builder: (_) => _MusicPickerSheet(onSelect: (t) { setModalState(() => editedMusic = t); Navigator.pop(context); }));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: editedMusic != null ? BT.spotify.withOpacity(0.1) : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: editedMusic != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.music_note_rounded, color: editedMusic != null ? BT.spotify : BT.textTertiary, size: 15),
                          const SizedBox(width: 5),
                          Text(editedMusic != null ? 'Music ✓' : 'Music', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: editedMusic != null ? BT.spotify : BT.textTertiary)),
                        ]))),
                  ],
                ),
              )

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
                    if (widget.post.isRepost && widget.post.originalPostId != null) {
                      await FirebaseFirestore.instance.collection('posts').doc(widget.post.originalPostId).update({
                        'repostCount': FieldValue.increment(-1),
                      });
                    }
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
        firstChild: ClipPath(
          clipper: BubbleTailClipper(borderRadius: 28),
          child: _buildBubble(),
        ),
        secondChild: widget.post.isRepost 
            ? (widget.post.text.isEmpty ? _buildStraightRepostCard() : _buildQuoteRepostCard()) 
            : _buildNormalCard(),
      ),
    );
  }

  Widget _buildBubble() {
    final pastel = BT.pastelAt(widget.post.avatarColorIndex);
    return SizedBox(
      width: double.infinity, height: 130 + 16, 
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
        const Positioned(bottom: 34, right: 24, child: _Sparkle()), 
        Positioned(
          top: 0, bottom: 16, left: 0, right: 0,
          child: Center(
            child: Container(
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
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildNormalCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(
          borderRadius: 28,
          side: BorderSide(color: BT.divider, width: 1),
        ),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
        _buildCardText(p.text),
        
        // NOW USING THE SLIDING CAROUSEL
        if (p.imageUrls.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: _openViewer)),
          
        if (p.music != null) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: MusicAttachmentCard(track: p.music!)),
        const Divider(height: 1, color: BT.divider),
        _buildActions(),
      ]),
    );
  }

  Widget _buildStraightRepostCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(
          borderRadius: 28,
          side: BorderSide(color: BT.divider, width: 1),
        ),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 12, 14, 0), 
          child: Row(
            children: [
              const Icon(Icons.repeat_rounded, size: 14, color: BT.textTertiary),
              const SizedBox(width: 5),
              Text('${p.repostedBy} reposted', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BT.textTertiary)),
            ],
          ),
        ),
        _buildCardHeader(p.originalAuthor ?? '', p.originalAvatarSeed ?? 'X', p.originalAvatarColorIndex, p.originalTimestamp ?? '', p.mood, topPadding: 4),
        _buildCardText(p.originalText ?? ''),
        
        if (p.originalImageUrls.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ImageCarousel(imageUrls: p.originalImageUrls, onImageTap: _openViewer)),
          
        if (p.music != null) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: MusicAttachmentCard(track: p.music!)
        ),
        const Divider(height: 1, color: BT.divider),
        _buildActions(),
      ]),
    );
  }

  Widget _buildQuoteRepostCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16), 
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(
          borderRadius: 28,
          side: BorderSide(color: BT.divider, width: 1),
        ),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
        _buildCardText(p.text), 
        
        if (p.imageUrls.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: _openViewer)),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: GestureDetector(
            onTap: widget.onCardTap,
            child: Container(
              decoration: BoxDecoration(
                color: BT.card, 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BT.divider, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Row(
                        children: [
                          _BubbleAvatar(seed: p.originalAvatarSeed ?? 'X', colorIndex: p.originalAvatarColorIndex, radius: 11),
                          const SizedBox(width: 8),
                          Text(p.originalAuthor ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5)),
                          const SizedBox(width: 4),
                          const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 13)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(p.originalTimestamp ?? '', style: const TextStyle(color: BT.textTertiary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ]
                      )
                    ),
                    if ((p.originalText ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Text(p.originalText!, style: const TextStyle(fontSize: 14, color: BT.textPrimary, height: 1.4))
                      ),
                    
                    if (p.originalImageUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2), 
                        child: ImageCarousel(imageUrls: p.originalImageUrls, height: 160, onImageTap: _openViewer),
                      ),
                      
                    if (p.music != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: MusicAttachmentCard(track: p.music!)
                      ),
                  ]
                )
              )
            )
          )
        ),
        const Divider(height: 1, color: BT.divider),
        _buildActions(),
      ]),
    );
  }

  Widget _buildCardHeader(String author, String seed, int colorIdx, String time, MoodTag mood, {double topPadding = 14}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 8),
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

  void _openViewer(String url) {
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0, 
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      )
    ));
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
          onTap: _showRepostOptions,
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
// MUSIC ATTACHMENT CARD
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
// THREAD SCREEN (WITH LIVE COMMENTS & OPTIONS)
// ============================================================================
class ThreadScreen extends StatefulWidget {
  final Post post;
  const ThreadScreen({Key? key, required this.post}) : super(key: key);
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _toggleCommentLike(String commentId, List<dynamic> likes) async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;
    
    HapticFeedback.lightImpact();
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId);
    
    if (likes.contains(currentUserUid)) {
      await ref.update({'likes': FieldValue.arrayRemove([currentUserUid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([currentUserUid])});
    }
  }

  void _showEditCommentSheet(String commentId, String currentText) {
    final editCtrl = TextEditingController(text: currentText);
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
                  const Text('Edit Reply', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
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
                        await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId).update({
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

  void _showCommentOptions(String commentId, String currentText) {
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
                title: const Text('Edit reply', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context); 
                  _showEditCommentSheet(commentId, currentText);       
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: BT.heartRed.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: BT.heartRed, size: 22)
                ),
                title: const Text('Delete reply', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () async {
                  Navigator.pop(context); 
                  HapticFeedback.mediumImpact();
                  try {
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId).delete();
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
                      'commentCount': FieldValue.increment(-1)
                    });
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
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .orderBy('createdAt', descending: false) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading replies.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: BT.pastelPurple)));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No replies yet. Be the first!", style: TextStyle(color: BT.textTertiary))),
                  );
                }

                return Column(
                  children: docs.map((doc) => _buildReply(doc)).toList(),
                );
              }
            ),
          ])),
        _buildReplyBar(),
      ]),
    );
  }

  Widget _buildOrigPost() {
    return RantCard(
      post: widget.post,
      bubbleAsset: 'assets/images/image_0.png',
      isPopped: true,
      onPopAction: () {},
      onCardTap: () {}, 
    );
  }

  Widget _buildReply(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final commentId = doc.id;
    final likes = data['likes'] as List<dynamic>? ?? [];
    
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = currentUserUid != null && likes.contains(currentUserUid);
    
    final myName = FirebaseAuth.instance.currentUser?.displayName != null 
        ? '@${FirebaseAuth.instance.currentUser!.displayName}' 
        : '@Me';
    final isMyComment = data['uid'] == currentUserUid || data['author'] == myName;
    
    String formattedTime = 'Just now';
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      formattedTime = DateFormat('MMM d, h:mm a').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 16), 
      decoration: ShapeDecoration(
        color: BT.card, 
        shape: const BubbleTailShape(
          borderRadius: 24,
          side: BorderSide(color: BT.divider, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BubbleAvatar(
            seed: data['avatarSeed'] ?? 'X', 
            colorIndex: data['avatarColorIndex'] ?? 0, 
            radius: 17
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(data['author'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13)),
              const SizedBox(width: 5),
              const Text('·', style: TextStyle(color: BT.textTertiary)),
              const SizedBox(width: 5),
              Text(formattedTime, style: const TextStyle(color: BT.textTertiary, fontSize: 11.5)),
              const Spacer(),
              if (isMyComment)
                GestureDetector(
                  onTap: () => _showCommentOptions(commentId, data['text'] ?? ''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.transparent, 
                    child: const Icon(Icons.more_horiz_rounded, color: BT.textTertiary, size: 16),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            Text(data['text'] ?? '', style: const TextStyle(fontSize: 13.5, color: BT.textPrimary, height: 1.4)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleCommentLike(commentId, likes),
                  child: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    color: isLiked ? BT.heartRed : BT.divider, 
                    size: 16
                  ),
                ),
                if (likes.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('${likes.length}', style: TextStyle(color: isLiked ? BT.heartRed : BT.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
                ]
              ],
            )
          ])),
        ]),
      ),
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
          onTap: () async {
            if (_ctrl.text.trim().isNotEmpty) {
              final text = _ctrl.text.trim();
              _ctrl.clear(); 
              FocusScope.of(context).unfocus(); 
              
              try {
                await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .add({
                    'uid': currentUser?.uid, 
                    'likes': [], 
                    'author': name,
                    'avatarSeed': initial,
                    'avatarColorIndex': math.Random().nextInt(6),
                    'text': text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .update({
                    'commentCount': FieldValue.increment(1) 
                  });
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to comment: $e')));
              }
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
// QUOTE COMPOSE SCREEN
// ============================================================================
class QuoteComposeScreen extends StatefulWidget {
  final Post post;
  const QuoteComposeScreen({Key? key, required this.post}) : super(key: key);
  @override
  State<QuoteComposeScreen> createState() => _QuoteComposeScreenState();
}

class _QuoteComposeScreenState extends State<QuoteComposeScreen> {
  final _ctrl = TextEditingController();
  
  List<Uint8List> _imagesBytes = [];
  bool _isPosting = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      List<Uint8List> newBytes = [];
      
      int remainingSlots = 4 - _imagesBytes.length;
      if (remainingSlots <= 0) return; 

      int takeCount = math.min(pickedFiles.length, remainingSlots);
      for (int i = 0; i < takeCount; i++) {
        final bytes = await pickedFiles[i].readAsBytes();
        newBytes.add(bytes);
      }

      setState(() {
        _imagesBytes.addAll(newBytes);
      });
    }
  }

  Future<void> _submitQuote() async {
    if (_ctrl.text.trim().isEmpty && _imagesBytes.isEmpty) return;
    
    setState(() => _isPosting = true);
    
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';
    final myInitial = myName.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      List<String> imageUrls = [];
      
      for (var bytes in _imagesBytes) {
        String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${_imagesBytes.indexOf(bytes)}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putData(bytes);
        String url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'repostCount': FieldValue.increment(1),
      });

      final p = widget.post;
      final isStraightRepost = p.isRepost && p.text.isEmpty;
      final origAuthor = isStraightRepost ? p.originalAuthor : p.author;
      final origSeed = isStraightRepost ? p.originalAvatarSeed : p.avatarSeed;
      final origColor = isStraightRepost ? p.originalAvatarColorIndex : p.avatarColorIndex;
      final origText = isStraightRepost ? p.originalText : p.text;
      final origTime = isStraightRepost ? p.originalTimestamp : p.timestamp;
      
      final origImages = isStraightRepost ? p.originalImageUrls : p.imageUrls;
      final origMusic = p.music?.toMap(); 

      await FirebaseFirestore.instance.collection('posts').add({
        'author': myName,
        'avatarSeed': myInitial,
        'avatarColorIndex': math.Random().nextInt(6),
        'text': _ctrl.text.trim(), 
        'mood': 'none',
        'likes': 0,
        'commentCount': 0,
        'repostCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'displayTime': 'Just now',
        'music': origMusic, 
        'imageUrls': imageUrls, 
        'isRepost': true,
        'originalPostId': isStraightRepost ? p.originalPostId : p.id, 
        'repostedBy': myName,
        'originalAuthor': origAuthor,
        'originalAvatarSeed': origSeed,
        'originalAvatarColorIndex': origColor,
        'originalText': origText,
        'originalTimestamp': origTime,
        'originalImageUrls': origImages, 
      });

      if (!mounted) return;
      Navigator.pop(context, 'success'); 
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final initial = currentUser?.displayName?.isNotEmpty == true ? currentUser!.displayName![0].toUpperCase() : '✦';
    
    final p = widget.post;
    final isStraightRepost = p.isRepost && p.text.isEmpty;
    final origAuthor = isStraightRepost ? p.originalAuthor : p.author;
    final origSeed = isStraightRepost ? p.originalAvatarSeed : p.avatarSeed;
    final origColor = isStraightRepost ? p.originalAvatarColorIndex : p.avatarColorIndex;
    final origText = isStraightRepost ? p.originalText : p.text;
    final origTime = isStraightRepost ? p.originalTimestamp : p.timestamp;
    
    final origImages = isStraightRepost ? p.originalImageUrls : p.imageUrls;
    final origMusic = p.music; 

    return Scaffold(
      backgroundColor: BT.bg,
      appBar: AppBar(
        backgroundColor: BT.bg, elevation: 0, surfaceTintColor: Colors.transparent,
        leadingWidth: 80,
        leading: TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: BT.textPrimary, fontSize: 16))),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitQuote,
              style: ElevatedButton.styleFrom(backgroundColor: BT.pastelPurple, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isPosting 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Post', style: TextStyle(fontWeight: FontWeight.w800)))),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BubbleAvatar(seed: initial, colorIndex: 4, radius: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(controller: _ctrl, autofocus: true, maxLines: null,
                                style: const TextStyle(fontSize: 16, color: BT.textPrimary, height: 1.4),
                                decoration: const InputDecoration(hintText: 'Add a comment...', hintStyle: TextStyle(color: BT.textTertiary, fontSize: 16), border: InputBorder.none, isDense: true)),
                              const SizedBox(height: 16),
                              
                              if (_imagesBytes.isNotEmpty) ...[
                                SizedBox(
                                  height: 90, 
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imagesBytes.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) => Stack(children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_imagesBytes[index], width: 90, height: 90, fit: BoxFit.cover)),
                                      Positioned(top: 4, right: 4, child: GestureDetector(
                                        onTap: () => setState(() => _imagesBytes.removeAt(index)),
                                        child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                                    ])),
                                ),
                                const SizedBox(height: 16),
                              ],

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: BT.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: BT.divider, width: 1.5)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                        _BubbleAvatar(seed: origSeed ?? 'X', colorIndex: origColor ?? 0, radius: 11),
                                        const SizedBox(width: 8),
                                        Text(origAuthor ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5)),
                                        const SizedBox(width: 4),
                                        const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(origTime ?? '', style: const TextStyle(color: BT.textTertiary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      ]),
                                    if ((origText ?? '').isNotEmpty)
                                      Padding(padding: const EdgeInsets.only(top: 8),
                                        child: Text(origText!, style: const TextStyle(fontSize: 14, color: BT.textPrimary, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis)),
                                    
                                    if (origImages.isNotEmpty)
                                      Padding(padding: const EdgeInsets.only(top: 8),
                                        child: ImageCarousel(imageUrls: origImages, height: 140, onImageTap: (_) {})), 

                                    if (origMusic != null)
                                      Padding(padding: const EdgeInsets.only(top: 8),
                                        child: MusicAttachmentCard(track: origMusic)),
                                  ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: BT.divider, width: 1))),
                child: Row(children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.1) : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.4) : BT.divider, width: 1.5)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.image_outlined, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary, size: 15),
                          const SizedBox(width: 5),
                          Text(_imagesBytes.isEmpty ? 'Image' : '${_imagesBytes.length} / 4 ✓', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary)),
                        ]))),
                  ]),
              )
            ],
          ),
        ),
      ),
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
  
  List<Uint8List> _imagesBytes = [];
  bool _isPosting = false; 

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      List<Uint8List> newBytes = [];
      
      int remainingSlots = 4 - _imagesBytes.length;
      if (remainingSlots <= 0) return; 

      int takeCount = math.min(pickedFiles.length, remainingSlots);
      
      for (int i = 0; i < takeCount; i++) {
        final bytes = await pickedFiles[i].readAsBytes();
        newBytes.add(bytes);
      }

      setState(() {
        _imagesBytes.addAll(newBytes);
      });
    }
  }

  Future<void> _submitPost() async {
    if (_ctrl.text.isEmpty && _music == null && _imagesBytes.isEmpty) return;

    setState(() => _isPosting = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final name = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty 
        ? '@${currentUser.displayName}' 
        : '@Me';
    final initial = name.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      List<String> imageUrls = [];
      
      for (var bytes in _imagesBytes) {
        String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${_imagesBytes.indexOf(bytes)}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putData(bytes);
        String url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

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
        'imageUrls': imageUrls, 
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
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('New Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
            ]),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]), borderRadius: BorderRadius.circular(30)),
              child: TextButton(onPressed: _isPosting ? null : _submitPost, 
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: _isPosting 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _ctrl, autofocus: true, maxLines: 4, maxLength: 280,
            style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
            decoration: InputDecoration(hintText: "what's going on?? ✦", hintStyle: TextStyle(color: BT.textTertiary.withOpacity(0.8), fontSize: 15), border: InputBorder.none, counterStyle: const TextStyle(color: BT.textTertiary, fontSize: 11))),
              
          if (_imagesBytes.isNotEmpty) ...[
            SizedBox(
              height: 110, 
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagesBytes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imagesBytes[index], width: 110, height: 110, fit: BoxFit.cover)),
                  Positioned(top: 6, right: 6, child: GestureDetector(
                    onTap: () => setState(() => _imagesBytes.removeAt(index)),
                    child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                ])),
            ),
            const SizedBox(height: 12),
          ],
              
          if (_music != null) ...[
            MusicAttachmentCard(track: _music!),
            const SizedBox(height: 6),
            GestureDetector(onTap: () => setState(() => _music = null),
              child: const Text('Remove', style: TextStyle(color: BT.textTertiary, fontSize: 11.5, decoration: TextDecoration.underline))),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('MOOD  ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: BT.textTertiary, letterSpacing: 0.8)),
                ...MoodTag.values.where((m) => m != MoodTag.none).map((m) {
                  final active = _mood == m;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = active ? MoodTag.none : m),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 150), margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: active ? m.bg : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? m.fg.withOpacity(0.5) : BT.divider, width: 1.5)),
                      child: Text(m.label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? m.fg : BT.textSecondary))));
                }),
              ]))),
            const SizedBox(width: 10),
            
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.1) : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.4) : BT.divider, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.image_outlined, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary, size: 15),
                  const SizedBox(width: 5),
                  Text(_imagesBytes.isEmpty ? 'Image' : '${_imagesBytes.length} / 4 ✓', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary)),
                ]))),
                
            const SizedBox(width: 10),
            
            GestureDetector(
              onTap: () {
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  builder: (_) => _MusicPickerSheet(onSelect: (t) { setState(() => _music = t); Navigator.pop(context); }));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _music != null ? BT.spotify.withOpacity(0.1) : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _music != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.music_note_rounded, color: _music != null ? BT.spotify : BT.textTertiary, size: 15),
                  const SizedBox(width: 5),
                  Text(_music != null ? 'Music ✓' : 'Music', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _music != null ? BT.spotify : BT.textTertiary)),
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