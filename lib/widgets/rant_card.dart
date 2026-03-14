import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../screens/thread_screen.dart';
import '../screens/quote_compose_screen.dart';
import 'media_viewers.dart';
import 'bubble_components.dart';
import 'music_picker_sheet.dart';

class RantCard extends StatefulWidget {
  final Post post;
  final String bubbleAsset;
  final bool isPopped;
  final VoidCallback onPopAction;
  final VoidCallback onCardTap;

  const RantCard({
    Key? key,
    required this.post,
    required this.bubbleAsset,
    required this.isPopped,
    required this.onPopAction,
    required this.onCardTap,
  }) : super(key: key);

  @override
  State<RantCard> createState() => _RantCardState();
}

class _RantCardState extends State<RantCard> with TickerProviderStateMixin {
  bool _liked = false;
  bool _reposted = false;
  bool _animating = false;
  bool _isPeeking = false;

  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late AnimationController _popCtrl;
  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleOpacity;
  late Animation<double> _particleProgress;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<double> _cardSlide;
  late AnimationController _repostCtrl;
  late Animation<double> _repostTurns;

  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.65).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.65, end: 0.92).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_heartCtrl);

    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

    _bubbleScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.20).chain(CurveTween(curve: Curves.easeOut)), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.20, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 32),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
    ]).animate(_popCtrl);

    _bubbleOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
    ]).animate(_popCtrl);

    _particleProgress = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 78),
    ]).animate(_popCtrl);

    _cardOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 48),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 22),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
    ]).animate(_popCtrl);

    _cardScale = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.82), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_popCtrl);

    _cardSlide = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
    ]).animate(_popCtrl);

    _repostCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _repostTurns = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _repostCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _popCtrl.dispose();
    _repostCtrl.dispose();
    super.dispose();
  }

  List<Particle> _generateParticles() {
    final rng = math.Random();
    final base = BT.pastelAt(widget.post.avatarColorIndex);
    final next1 = BT.pastelAt(widget.post.avatarColorIndex + 1);
    final next2 = BT.pastelAt(widget.post.avatarColorIndex + 2);
    final palette = [base, next1, next2, Colors.white, BT.pastelPink, BT.pastelYellow, base];

    return List.generate(
      20,
      (i) => Particle(
        angle: (i / 20) * math.pi * 2 + rng.nextDouble() * 0.4,
        distance: 55 + rng.nextDouble() * 55,
        color: palette[rng.nextInt(palette.length)],
        size: 3.5 + rng.nextDouble() * 5.5,
      ),
    );
  }

  void _triggerPop() {
    if (_animating) return;
    if (_isPeeking) {
      setState(() => _isPeeking = false);
    }
    HapticFeedback.mediumImpact();
    _markAsSeen();
    _particles = _generateParticles();
    setState(() => _animating = true);
    _popCtrl.forward(from: 0).then((_) {
      widget.onPopAction();
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => _animating = false);
      }
    });
  }

  void _markAsSeen() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty
        ? '@${currentUser.displayName}'
        : '@Me';

    if (widget.post.author != myName && !widget.post.seenBy.contains(myName)) {
      FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'seenBy': FieldValue.arrayUnion([myName])
      });
    }
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPopped && !_animating) {
      return GestureDetector(
        onTap: widget.onCardTap,
        child: _buildRevealedCard(),
      );
    }

    if (!widget.isPopped && !_animating) {
      if (_isPeeking) {
        return AnimatedScale(
          scale: 0.96,
          duration: const Duration(milliseconds: 150),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
              child: IgnorePointer(child: _buildRevealedCard()),
            ),
          ),
        );
      }

      return GestureDetector(
        onTap: _triggerPop,
        onLongPress: () {
          HapticFeedback.lightImpact();
          setState(() => _isPeeking = true);
        },
        onLongPressUp: () {
          if (_isPeeking) setState(() => _isPeeking = false);
        },
        onLongPressCancel: () {
          if (_isPeeking) setState(() => _isPeeking = false);
        },
        child: ClipPath(
          clipper: BubbleTailClipper(borderRadius: 28),
          child: AnimatedBubble(post: widget.post, bubbleAsset: widget.bubbleAsset),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _popCtrl,
      builder: (_, __) => Stack(
        clipBehavior: Clip.none,
        children: [
          FractionalTranslation(
            translation: Offset(0, _cardSlide.value),
            child: Transform.scale(
              scale: _cardScale.value,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: _cardOpacity.value,
                child: _buildRevealedCard(),
              ),
            ),
          ),
          if (_bubbleOpacity.value > 0.01)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Transform.scale(
                scale: _bubbleScale.value,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: _bubbleOpacity.value,
                  child: ClipPath(
                    clipper: BubbleTailClipper(borderRadius: 28),
                    child: AnimatedBubble(post: widget.post, bubbleAsset: widget.bubbleAsset),
                  ),
                ),
              ),
            ),
          if (_particleProgress.value > 0 && _particleProgress.value < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ParticlePainter(
                    particles: _particles,
                    progress: _particleProgress.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRevealedCard() {
    if (widget.post.isRepost) {
      return widget.post.text.isEmpty ? _buildStraightRepostCard() : _buildQuoteRepostCard();
    }
    return _buildNormalCard();
  }

  Widget _buildNormalCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(borderRadius: 28, side: BorderSide(color: BT.divider, width: 1)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
          _buildCardText(p.text),
          if (p.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: (_) {}),
            ),
          if (p.music != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: MusicAttachmentCard(track: p.music!),
            ),
          const Divider(height: 1, color: BT.divider),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildStraightRepostCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(borderRadius: 28, side: BorderSide(color: BT.divider, width: 1)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 12, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 14, color: BT.textTertiary),
                const SizedBox(width: 5),
                Text(
                  '${p.repostedBy} reposted',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BT.textTertiary),
                ),
              ],
            ),
          ),
          _buildCardHeader(
            p.originalAuthor ?? '',
            p.originalAvatarSeed ?? 'X',
            p.originalAvatarColorIndex,
            p.originalTimestamp ?? '',
            p.mood,
            topPadding: 4,
          ),
          _buildCardText(p.originalText ?? ''),
          if (p.originalImageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.originalImageUrls, onImageTap: (_) {}),
            ),
          if (p.music != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: MusicAttachmentCard(track: p.music!),
            ),
          const Divider(height: 1, color: BT.divider),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildQuoteRepostCard() {
    final p = widget.post;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(borderRadius: 28, side: BorderSide(color: BT.divider, width: 1)),
        shadows: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
          _buildCardText(p.text),
          if (p.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: (_) {}),
            ),
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
                            BubbleAvatar(
                              author: p.originalAuthor ?? '', // FETCH QUOTED AVATAR
                              seed: p.originalAvatarSeed ?? 'X', 
                              colorIndex: p.originalAvatarColorIndex, 
                              radius: 11
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                p.originalAuthor ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 13)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                p.originalTimestamp ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: BT.textTertiary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((p.originalText ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Text(p.originalText!, style: const TextStyle(fontSize: 14, color: BT.textPrimary, height: 1.4)),
                        ),
                      if (p.originalImageUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: ImageCarousel(imageUrls: p.originalImageUrls, height: 160, onImageTap: (_) {}),
                        ),
                      if (p.music != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: MusicAttachmentCard(track: p.music!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: BT.divider),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String author, String seed, int colorIdx, String time, MoodTag mood, {double topPadding = 14}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 8),
      child: Row(
        children: [
          BubbleAvatar(author: author, seed: seed, colorIndex: colorIdx, radius: 18), // FETCH AUTHOR AVATAR
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('·', style: TextStyle(color: BT.textTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: BT.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (mood != MoodTag.none) ...[
            MoodPill(mood: mood),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: _showOptionsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.transparent,
              child: const Icon(Icons.more_horiz_rounded, color: BT.textTertiary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Text(text, style: const TextStyle(fontSize: 14.5, color: BT.textPrimary, height: 1.45)),
    );
  }

  Widget _buildActions() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty
        ? '@${currentUser.displayName}'
        : '@Me';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _heartScale,
                  builder: (_, child) => Transform.scale(scale: _heartScale.value, child: child),
                  child: Icon(
                    _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _liked ? BT.heartRed : BT.textTertiary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: _liked ? BT.heartRed : BT.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  child: Text('${widget.post.likes + (_liked ? 1 : 0)}'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          TapBounce(
            onTap: widget.onCardTap,
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: BT.textTertiary, size: 18),
                const SizedBox(width: 5),
                Text(
                  '${widget.post.commentCount}',
                  style: const TextStyle(color: BT.textTertiary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _showRepostOptions,
            child: Row(
              children: [
                RotationTransition(
                  turns: _repostTurns,
                  child: Icon(
                    Icons.repeat_rounded,
                    color: _reposted ? BT.repostTeal : BT.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: _reposted ? BT.repostTeal : BT.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  child: Text('${widget.post.repostCount + (_reposted ? 1 : 0)}'),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (widget.post.author == myName && widget.post.seenBy.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.remove_red_eye_rounded, color: BT.textTertiary, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.post.seenBy.length == 1
                      ? 'Seen by ${widget.post.seenBy.first.replaceAll('@', '')}'
                      : '${widget.post.seenBy.length} views',
                  style: const TextStyle(color: BT.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
              ],
            ),
          const Icon(Icons.bookmark_border_rounded, color: BT.textTertiary, size: 19),
        ],
      ),
    );
  }

  void _showRepostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
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
                  child: const Icon(Icons.repeat_rounded, color: BT.repostTeal, size: 22),
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
                  child: const Icon(Icons.edit_rounded, color: BT.pastelPurple, size: 22),
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteComposeScreen(post: widget.post)));
  }

  void _executeRepost({required bool isQuote}) async {
    if (_reposted) return;
    HapticFeedback.lightImpact();
    setState(() => _reposted = true);
    _repostCtrl.forward(from: 0);

    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName?.isNotEmpty == true ? '@${currentUser!.displayName}' : '@Me';
    final myInitial = myName.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'repostCount': FieldValue.increment(1),
      });
      final isStraightRepost = widget.post.isRepost && widget.post.text.isEmpty;

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
        'music': widget.post.music?.toMap(),
        'isRepost': true,
        'seenBy': [],
        'originalPostId': isStraightRepost ? widget.post.originalPostId : widget.post.id,
        'repostedBy': myName,
        'originalAuthor': isStraightRepost ? widget.post.originalAuthor : widget.post.author,
        'originalAvatarSeed': isStraightRepost ? widget.post.originalAvatarSeed : widget.post.avatarSeed,
        'originalAvatarColorIndex': isStraightRepost ? widget.post.originalAvatarColorIndex : widget.post.avatarColorIndex,
        'originalText': isStraightRepost ? widget.post.originalText : widget.post.text,
        'originalTimestamp': isStraightRepost ? widget.post.originalTimestamp : widget.post.timestamp,
        'originalImageUrls': isStraightRepost ? widget.post.originalImageUrls : widget.post.imageUrls,
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
        int remainingSlots = 4 - (existingImageUrls.length + newImageBytes.length);
        if (remainingSlots <= 0) return;
        List<Uint8List> bytesList = [];
        for (int i = 0; i < math.min(pickedFiles.length, remainingSlots); i++) {
          bytesList.add(await pickedFiles[i].readAsBytes());
        }
        setModalState(() => newImageBytes.addAll(bytesList));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Edit Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextButton(
                        onPressed: isSaving ? null : () async {
                          if (editCtrl.text.trim().isEmpty && editedMusic == null && existingImageUrls.isEmpty && newImageBytes.isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            Map<String, dynamic> updates = {'text': editCtrl.text.trim()};
                            List<String> finalUrls = List.from(existingImageUrls);
                            for (var bytes in newImageBytes) {
                              String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${newImageBytes.indexOf(bytes)}.jpg';
                              Reference ref = FirebaseStorage.instance.ref().child(fileName);
                              await ref.putData(bytes);
                              finalUrls.add(await ref.getDownloadURL());
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isSaving
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: editCtrl,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 280,
                  style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counter: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: editCtrl,
                      builder: (_, value, __) => PulseCounter(current: value.text.length, maxChars: 280),
                    ),
                  ),
                ),
                if (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ...[
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...existingImageUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url, width: 110, height: 110, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => existingImageUrls.remove(url)),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                        ...newImageBytes.map((bytes) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(bytes, width: 110, height: 110, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => newImageBytes.remove(bytes)),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (editedMusic != null) ...[
                  MusicAttachmentCard(track: editedMusic!),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setModalState(() => editedMusic = null),
                    child: const Text('Remove', style: TextStyle(color: BT.textTertiary, fontSize: 11.5, decoration: TextDecoration.underline)),
                  ),
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
                            border: Border.all(
                              color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? BT.pastelBlue.withOpacity(0.4) : BT.divider,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                (existingImageUrls.isEmpty && newImageBytes.isEmpty) ? 'Image' : '${existingImageUrls.length + newImageBytes.length} / 4 ✓',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                          builder: (_) => MusicPickerSheet(
                            onSelect: (t) {
                              setModalState(() => editedMusic = t);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: editedMusic != null ? BT.spotify.withOpacity(0.1) : BT.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: editedMusic != null ? BT.spotify.withOpacity(0.4) : BT.divider,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                color: editedMusic != null ? BT.spotify : BT.textTertiary,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                editedMusic != null ? 'Music ✓' : 'Music',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: editedMusic != null ? BT.spotify : BT.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName?.isNotEmpty == true ? '@${currentUser!.displayName}' : '@Me';
    if (widget.post.author != myName) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
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
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF6AAED6), size: 22),
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
                  child: const Icon(Icons.delete_outline_rounded, color: BT.heartRed, size: 22),
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
}