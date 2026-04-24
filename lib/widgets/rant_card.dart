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
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart'; 
import 'media_viewers.dart';
import 'bubble_components.dart';
import 'ghost_widgets.dart';
import 'music_picker_sheet.dart';

// ============================================================================
// REACTION TRAY CONFIG
// ============================================================================
const List<String> _kDefaultReactions = ['🎀', '😭', '🔥', '💀', '🫧', '❤️'];

class ReactionSettings {
  static List<String> current = ['🎀', '😭', '🔥', '💀', '🫧', '❤️'];
  static bool _loading = false;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final raw = doc.data()?['customReactions'];
        if (raw is List && raw.isNotEmpty) {
          current = List<String>.from(raw).take(6).toList();
        }
      }
      _loaded = true;
    } catch (_) {}
    _loading = false;
  }

  static Future<void> save(List<String> emojis) async {
    current = emojis;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid)
        .set({'customReactions': emojis}, SetOptions(merge: true));
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
  bool _liked      = false;
  bool _reposted   = false;
  bool _animating  = false;
  bool _isPeeking  = false;

  // ── Swipe to Reply State ──
  double _rawDrag = 0.0;
  bool _isDragging = false;
  bool _replyHapticFired = false;

  double get _actualDrag {
    if (_rawDrag <= 65) return _rawDrag;
    return 65 + (_rawDrag - 65) * 0.25; 
  }

  bool    _showTray   = false;
  String? _myReaction;                                
  String? _hoverEmoji;                                
  bool    _hoverCustomize = false;                    
  String? _floatEmoji;                                
  Map<String, List<String>> _reactions = {};  
  final GlobalKey _trayKey = GlobalKey();        
  final GlobalKey _customizeBtnKey = GlobalKey(); 
  List<String> _customReactions = List.from(_kDefaultReactions); 

  late AnimationController _heartCtrl;
  late Animation<double>   _heartScale;
  late AnimationController _popCtrl;
  late Animation<double>   _bubbleScale;
  late Animation<double>   _bubbleOpacity;
  late Animation<double>   _particleProgress;
  late Animation<double>   _cardScale;
  late Animation<double>   _cardOpacity;
  late Animation<double>   _cardSlide;
  late AnimationController _repostCtrl;
  late Animation<double>   _repostTurns;
  late AnimationController _trayCtrl;
  late Animation<double>   _trayScale;
  late Animation<double>   _trayOpacity;
  late Animation<Offset>   _traySlide;

  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _liked = widget.post.likedBy.contains(uid);
    }

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

    _repostCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _repostTurns = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _repostCtrl, curve: Curves.easeInOut));

    _trayCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _trayScale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _trayCtrl, curve: Curves.elasticOut));
    _trayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _trayCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _traySlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _trayCtrl, curve: Curves.easeOut));

    _loadReactions();
    ReactionSettings.load(); 
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _popCtrl.dispose();
    _repostCtrl.dispose();
    _trayCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.post.reactions != oldWidget.post.reactions) {
      setState(() {
        _loadReactions();
      });
    }
    
    if (widget.post.likedBy != oldWidget.post.likedBy) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        setState(() {
          _liked = widget.post.likedBy.contains(uid);
        });
      }
    }
  }

  String? _emojiAtPosition(Offset globalPos) {
    final ctx = _trayKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    final trayWidth = box.size.width;
    if (local.dy < -16 || local.dy > box.size.height + 16) return null;

    const slotW = 48.0;
    final totalW = ReactionSettings.current.length * slotW; 
    final startX = (trayWidth - totalW) / 2;
    final idx = ((local.dx - startX) / slotW).floor();
    if (idx < 0 || idx >= ReactionSettings.current.length) return null;
    return ReactionSettings.current[idx]; 
  }

  void _loadReactions() {
    final raw = widget.post.reactions; 
    if (raw != null) {
      _reactions = Map<String, List<String>>.from(raw); 
      final myName = _myName;
      _myReaction = null; 
      for (final entry in _reactions.entries) {
        if (entry.value.contains(myName)) {
          _myReaction = entry.key;
          break;
        }
      }
    }
  }

  String get _myName {
    final u = FirebaseAuth.instance.currentUser;
    final rawName = u?.displayName?.replaceAll('@', '') ?? 'Me';
    return '@$rawName';
  }

  void _openCustomizeSheet() async {
    if (mounted) {
      _trayCtrl.stop();
      setState(() {
        _showTray      = false;
        _hoverEmoji    = null;
        _hoverCustomize = false;
      });
    }
    if (!mounted) return;
    
    List<String>? result;
    try {
      result = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (_) => _EmojiCustomizeSheet(current: ReactionSettings.current),
      ); 
    } finally {
      if (mounted) {
        setState(() { 
          _showTray = false; 
          _hoverCustomize = false; 
          _hoverEmoji = null; 
        });
      }
    }
    
    if (result != null && mounted) {
      setState(() {
        _customReactions = result!;
      });
      ReactionSettings.save(result!);
    }
  }

  bool _isOverCustomizeButton(Offset globalPos) {
    final ctx = _customizeBtnKey.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final local = box.globalToLocal(globalPos);
    return local.dx >= -20 && local.dx <= box.size.width + 20 &&
           local.dy >= -20 && local.dy <= box.size.height + 20;
  }

  void _openReactionTray() {
    HapticFeedback.mediumImpact();
    setState(() { 
      _showTray = true; 
      _hoverEmoji = null; 
    });
    _trayCtrl.forward(from: 0);
  }

  Future<void> _closeTray() async {
    await _trayCtrl.reverse();
    if (mounted) setState(() => _showTray = false);
  }

  Future<void> _pickReaction(String emoji) async {
    HapticFeedback.lightImpact();
    final myName = _myName;
    final isRemoving = _myReaction == emoji;
    final oldReaction = _myReaction; 
    
    if (!isRemoving) setState(() => _floatEmoji = emoji);
    await _closeTray();

    setState(() {
      if (oldReaction != null && oldReaction != emoji) {
        _reactions[oldReaction]?.remove(myName);
        if (_reactions[oldReaction]?.isEmpty == true) _reactions.remove(oldReaction);
      }
      if (isRemoving) {
        _reactions[emoji]?.remove(myName);
        if (_reactions[emoji]?.isEmpty == true) _reactions.remove(emoji);
        _myReaction = null;
      } else {
        _reactions.putIfAbsent(emoji, () => []);
        if (!_reactions[emoji]!.contains(myName)) _reactions[emoji]!.add(myName);
        _myReaction = emoji;
      }
    });

    try {
      final Map<String, dynamic> updates = {};
      
      if (oldReaction != null) {
        if (_reactions.containsKey(oldReaction)) {
          updates['reactions.$oldReaction'] = _reactions[oldReaction];
        } else {
          updates['reactions.$oldReaction'] = FieldValue.delete();
        }
      }
      
      if (!isRemoving) {
        updates['reactions.$emoji'] = _reactions[emoji];
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .update(updates);
      }

      if (!isRemoving && widget.post.author != myName) {
        final targetUid = await NotificationService.getUidFromHandle(widget.post.author);

        if (targetUid != null) {
          await NotificationService.sendRealNotification(
            targetUserId: targetUid,
            type: 'reaction', 
            actorName: myName,
            message: ' reacted $emoji to your rant.', 
            referenceId: widget.post.id,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to sync reaction: $e');
    }
  }

  List<Particle> _generateParticles() {
    final rng = math.Random();
    final base  = BT.pastelAt(widget.post.avatarColorIndex);
    final next1 = BT.pastelAt(widget.post.avatarColorIndex + 1);
    final next2 = BT.pastelAt(widget.post.avatarColorIndex + 2);
    final palette = [base, next1, next2, Colors.white, BT.pastelPink, BT.pastelYellow, base];
    
    return List.generate(20, (i) => Particle(
      angle:    (i / 20) * math.pi * 2 + rng.nextDouble() * 0.4,
      distance: 55 + rng.nextDouble() * 55,
      color:    palette[rng.nextInt(palette.length)],
      size:     3.5 + rng.nextDouble() * 5.5,
    ));
  }

  void _triggerPop() {
    if (_animating) return;
    if (_isPeeking) setState(() => _isPeeking = false);
    
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
    final myName = _myName;
    if (widget.post.author != myName && !widget.post.seenBy.contains(myName)) {
      FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'seenBy': FieldValue.arrayUnion([myName])
      });
    }
  }

  void _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    HapticFeedback.lightImpact();
    
    final wasLiked = _liked;
    
    setState(() => _liked = !_liked);
    _heartCtrl.forward(from: 0);

    final myName = _myName;

    try {
      final docRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
      
      if (wasLiked) {
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([uid])
        });
      } else {
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([uid])
        });

        if (widget.post.author != myName) {
          final targetUid = await NotificationService.getUidFromHandle(widget.post.author);

          if (targetUid != null) {
            await NotificationService.sendRealNotification(
              targetUserId: targetUid,
              type: 'like',
              actorName: myName,
              message: ' liked your rant.',
              referenceId: widget.post.id,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to sync like: $e');
      if (mounted) {
        setState(() => _liked = wasLiked);
      }
    }
  }

  void _goToProfile(String handle) {
    if (widget.post.circle == null) return;
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfileScreen(targetCircle: widget.post.circle!, visitedHandle: handle)));
  }

  // ── NEW: SHOW USERS WHO LIKED OR REACTED ──
  void _showReactorsSheet({required String title, IconData? icon, Color? iconColor, List<String>? uids, List<String>? handles}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReactorsSheet(
        title: title,
        icon: icon,
        iconColor: iconColor,
        uids: uids ?? [],
        handles: handles ?? [],
        onUserTap: _goToProfile,
      ),
    );
  }

  void _openImageFullScreen(List<String> urls, dynamic param) {
    int index = 0;
    if (param is int) index = param;
    if (param is String) index = urls.indexOf(param).clamp(0, urls.length - 1);
    
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          iconTheme: const IconThemeData(color: Colors.white)
        ),
        body: PageView.builder(
          itemCount: urls.length,
          controller: PageController(initialPage: index),
          itemBuilder: (context, i) => InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0, 
            child: Center(child: Image.network(urls[i], fit: BoxFit.contain)),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPopped && !_animating) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () {
              if (_showTray) { _closeTray(); return; }
              widget.onCardTap();
            },
            onLongPressStart: (_) => _openReactionTray(),
            onLongPressMoveUpdate: (details) {
              if (!_showTray) return;
              final isOverCustomize = _isOverCustomizeButton(details.globalPosition);
              setState(() {
                _hoverCustomize = isOverCustomize;
                _hoverEmoji = isOverCustomize ? null : _emojiAtPosition(details.globalPosition);
              });
            },
            onLongPressEnd: (details) {
              if (!_showTray) return;
              if (_hoverCustomize) {
                _hoverCustomize = false;
                _hoverEmoji = null;
                _openCustomizeSheet();
                return;
              }
              final picked = _hoverEmoji ?? _myReaction;
              _hoverEmoji = null;
              _hoverCustomize = false;
              if (picked != null) {
                _pickReaction(picked);
              } else {
                _closeTray();
              }
            },
            onLongPressCancel: () {
              _hoverEmoji = null;
              _hoverCustomize = false;
              _closeTray();
            },
            
            // Swipe to Reply
            onHorizontalDragStart: (details) {
              if (_showTray) return;
              setState(() { _isDragging = true; _rawDrag = 0.0; _replyHapticFired = false; });
            },
            onHorizontalDragUpdate: (details) {
              if (_showTray) return;
              setState(() {
                _rawDrag += details.delta.dx;
                if (_rawDrag < 0) _rawDrag = 0; 
              });
              if (_actualDrag > 65 && !_replyHapticFired) {
                HapticFeedback.lightImpact();
                _replyHapticFired = true;
              } else if (_actualDrag < 65) {
                _replyHapticFired = false;
              }
            },
            onHorizontalDragEnd: (details) {
              if (_showTray) return;
              if (_actualDrag > 65) {
                HapticFeedback.mediumImpact();
                widget.onCardTap(); 
              }
              setState(() { _isDragging = false; _rawDrag = 0.0; _replyHapticFired = false; });
            },
            onHorizontalDragCancel: () {
              if (_showTray) return;
              setState(() { _isDragging = false; _rawDrag = 0.0; _replyHapticFired = false; });
            },
            
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 16,
                  child: Opacity(
                    opacity: (_actualDrag / 65).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: (_actualDrag / 65).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BT.pastelPurple.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.reply_rounded, color: BT.pastelPurple, size: 24),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack, 
                  transform: Matrix4.translationValues(_actualDrag, 0, 0),
                  child: _buildRevealedCard(),
                ),
              ],
            ),
          ),

          if (_showTray)
            Positioned(
              top: -68, left: 0, right: 0,
              child: _ReactionTray(
                key: _trayKey, reactions: ReactionSettings.current, 
                myReaction: _myReaction, hoverEmoji: _hoverEmoji,
                hoverCustomize: _hoverCustomize, trayCtrl: _trayCtrl,
                trayScale: _trayScale, trayOpacity: _trayOpacity,
                traySlide: _traySlide, onPick: _pickReaction,
                onDismiss: _closeTray, onCustomize: _openCustomizeSheet,
                customizeBtnKey: _customizeBtnKey,
              ),
            ),

          if (_floatEmoji != null)
            Positioned(
              top: -20, left: 0, right: 0,
              child: IgnorePointer(
                child: _FloatingEmoji(
                  emoji: _floatEmoji!,
                  onDone: () { if (mounted) setState(() => _floatEmoji = null); },
                ),
              ),
            ),
        ],
      );
    }

    if (!widget.isPopped && !_animating) {
      if (_isPeeking) {
        return AnimatedScale(
          scale: 0.96, duration: const Duration(milliseconds: 150),
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
        onLongPressUp: () { if (_isPeeking) setState(() => _isPeeking = false); },
        onLongPressCancel: () { if (_isPeeking) setState(() => _isPeeking = false); },
        child: ClipPath(
          clipper: BubbleTailClipper(borderRadius: 28),
          child: widget.post.isGhost
              ? GhostAnimatedBubble(post: widget.post, bubbleAsset: widget.bubbleAsset)
              : AnimatedBubble(post: widget.post, bubbleAsset: widget.bubbleAsset),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _popCtrl,
      builder: (_, __) {
        return Stack(
          clipBehavior: Clip.none, 
          children: [
            FractionalTranslation(
              translation: Offset(0, _cardSlide.value),
              child: Transform.scale(
                scale: _cardScale.value, alignment: Alignment.topCenter,
                child: Opacity(opacity: _cardOpacity.value, child: _buildRevealedCard()),
              ),
            ),
            if (_bubbleOpacity.value > 0.01)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Transform.scale(
                  scale: _bubbleScale.value, alignment: Alignment.center,
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
                    painter: ParticlePainter(particles: _particles, progress: _particleProgress.value),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color get _textPrimary => widget.post.isGhost ? Colors.white : BT.textPrimary;
  Color get _textSecondary => widget.post.isGhost ? Colors.white70 : BT.textSecondary;
  Color get _textTertiary => widget.post.isGhost ? Colors.white54 : BT.textTertiary;
  Color get _dividerColor => widget.post.isGhost ? Colors.white10 : BT.divider;

  Widget _buildRevealedCard() {
    Widget card;
    if (widget.post.isRepost) {
      card = widget.post.text.isEmpty ? _buildStraightRepostCard() : _buildQuoteRepostCard();
    } else {
      card = _buildNormalCard();
    }
    if (widget.post.isGhost && widget.post.expiresAt != null) {
      return GhostCardWrapper(post: widget.post, child: card);
    }
    return card;
  }

  ShapeDecoration get _cardDeco {
    final isGhost = widget.post.isGhost;
    return ShapeDecoration(
      color: isGhost ? const Color(0xFF1E1830) : BT.card, 
      shape: BubbleTailShape(
        borderRadius: 28, 
        side: BorderSide(
          color: isGhost ? const Color(0xFF6B5FA0).withOpacity(0.5) : BT.divider, 
          width: isGhost ? 1.5 : 1.0
        )
      ),
      shadows: [
        if (isGhost)
          BoxShadow(color: const Color(0xFF6B5FA0).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))
        else
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))
      ]
    );
  }

  Widget _wrapWithGhostSmoke(Widget child) {
    if (!widget.post.isGhost) return child;
    return ClipPath(
      clipper: BubbleTailClipper(borderRadius: 28),
      child: Stack(
        children: [
          const Positioned.fill(child: _CardSmokeBackground()),
          child,
        ],
      ),
    );
  }

  Widget _buildNormalCard() {
    final p = widget.post;
    return Container(
      decoration: _cardDeco,
      child: _wrapWithGhostSmoke(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
            _buildCardText(p.text),
            if (p.imageUrls.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: (val) => _openImageFullScreen(p.imageUrls, val))),
            if (p.music != null) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: MusicAttachmentCard(track: p.music!)),
            if (_reactions.isNotEmpty) _buildReactionBar(),
            Divider(height: 1, color: _dividerColor),
            _buildActions(),
          ]),
        ),
      ),
    );
  }

  Widget _buildStraightRepostCard() {
    final p = widget.post;
    return Container(
      decoration: _cardDeco,
      child: _wrapWithGhostSmoke(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 12, 14, 0),
              child: Row(children: [
                Icon(Icons.repeat_rounded, size: 14, color: _textTertiary),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => _goToProfile(p.repostedBy ?? ''),
                  child: Text('${p.repostedBy} reposted',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textTertiary))),
              ])),
            _buildCardHeader(p.originalAuthor ?? '', p.originalAvatarSeed ?? 'X',
                p.originalAvatarColorIndex, p.originalTimestamp ?? '', p.mood, topPadding: 4),
            _buildCardText(p.originalText ?? ''),
            if (p.originalImageUrls.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.originalImageUrls, onImageTap: (val) => _openImageFullScreen(p.originalImageUrls, val))),
            if (p.music != null) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: MusicAttachmentCard(track: p.music!)),
            if (_reactions.isNotEmpty) _buildReactionBar(),
            Divider(height: 1, color: _dividerColor),
            _buildActions(),
          ]),
        ),
      ),
    );
  }

  Widget _buildQuoteRepostCard() {
    final p = widget.post;
    return Container(
      decoration: _cardDeco,
      child: _wrapWithGhostSmoke(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildCardHeader(p.author, p.avatarSeed, p.avatarColorIndex, p.timestamp, p.mood),
            _buildCardText(p.text),
            if (p.imageUrls.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ImageCarousel(imageUrls: p.imageUrls, onImageTap: (val) => _openImageFullScreen(p.imageUrls, val))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: GestureDetector(
                onTap: widget.onCardTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.post.isGhost ? Colors.white.withOpacity(0.05) : BT.card, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _dividerColor, width: 1.5)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Row(children: [
                          GestureDetector(
                            onTap: () => _goToProfile(p.originalAuthor ?? ''),
                            child: BubbleAvatar(author: p.originalAuthor ?? '', seed: p.originalAvatarSeed ?? 'X', colorIndex: p.originalAvatarColorIndex, radius: 11)),
                          const SizedBox(width: 8),
                          Flexible(child: GestureDetector(
                            onTap: () => _goToProfile(p.originalAuthor ?? ''),
                            child: Text(p.originalAuthor ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: _textPrimary, fontSize: 13.5)))),
                          const SizedBox(width: 4),
                          Text('·', style: TextStyle(color: _textTertiary, fontSize: 13)),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.originalTimestamp ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _textTertiary, fontSize: 12))),
                        ])),
                      if ((p.originalText ?? '').isNotEmpty)
                        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Text(p.originalText!, style: TextStyle(fontSize: 14, color: _textPrimary, height: 1.4))),
                      if (p.originalImageUrls.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(bottom: 2),
                          child: ImageCarousel(imageUrls: p.originalImageUrls, height: 160, onImageTap: (val) => _openImageFullScreen(p.originalImageUrls, val))),
                      if (p.music != null)
                        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: MusicAttachmentCard(track: p.music!)),
                    ]))))),
            if (_reactions.isNotEmpty) _buildReactionBar(),
            Divider(height: 1, color: _dividerColor),
            _buildActions(),
          ]),
        ),
      ),
    );
  }

  Widget _buildCardHeader(String author, String seed, int colorIdx, String time, MoodTag mood, {double topPadding = 14}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => _goToProfile(author),
          child: BubbleAvatar(author: author, seed: seed, colorIndex: colorIdx, radius: 18)),
        const SizedBox(width: 10),
        Expanded(child: Row(children: [
          Flexible(child: GestureDetector(
            onTap: () => _goToProfile(author),
            child: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: _textPrimary, fontSize: 13.5)))),
          const SizedBox(width: 4),
          Text('·', style: TextStyle(color: _textTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Flexible(child: Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _textTertiary, fontSize: 12))),
        ])),
        if (widget.post.isGhost) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lens_blur, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('24h', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (mood != MoodTag.none) ...[MoodPill(mood: mood), const SizedBox(width: 6)],
        GestureDetector(
          onTap: _showOptionsSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: Colors.transparent,
            child: Icon(Icons.more_horiz_rounded, color: _textTertiary, size: 20))),
      ]));
  }

  Widget _buildCardText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Text(text, style: TextStyle(fontSize: 14.5, color: _textPrimary, height: 1.45)));
  }

  Widget _buildReactionBar() {
    final myName = _myName;
    final sorted = _reactions.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Wrap(spacing: 6, runSpacing: 6,
        children: sorted.map((entry) {
          final emoji   = entry.key;
          final count   = entry.value.length;
          final isMine  = entry.value.contains(myName);

          return GestureDetector(
            onTap: () => _pickReaction(emoji),
            // ── NEW: LONG PRESS TO SEE WHO REACTED ──
            onLongPress: () {
              HapticFeedback.selectionClick();
              _showReactorsSheet(title: 'Reacted $emoji', handles: entry.value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isMine ? BT.pastelPurple.withOpacity(0.18) : _dividerColor.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isMine ? BT.pastelPurple.withOpacity(0.45) : Colors.transparent, width: 1.2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text('$count', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isMine ? BT.pastelPurple : _textSecondary)),
              ])));
        }).toList()));
  }

  Widget _buildActions() {
    final myName = _myName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleLike,
          // ── NEW: LONG PRESS TO SEE WHO LIKED ──
          onLongPress: () {
            if (widget.post.likedBy.isEmpty) return;
            HapticFeedback.selectionClick();
            _showReactorsSheet(
              title: 'Liked by', 
              icon: Icons.favorite_rounded, 
              iconColor: BT.heartRed, 
              uids: widget.post.likedBy
            );
          },
          child: Row(children: [
            AnimatedBuilder(
              animation: _heartScale,
              builder: (_, child) => Transform.scale(scale: _heartScale.value, child: child),
              child: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? BT.heartRed : _textTertiary, size: 19)),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(color: _liked ? BT.heartRed : _textTertiary, fontWeight: FontWeight.w600, fontSize: 13),
              child: Text('${widget.post.likedBy.length}')), 
          ])),
        const SizedBox(width: 20),
        TapBounce(
          onTap: widget.onCardTap,
          child: Row(children: [
            Icon(Icons.chat_bubble_outline_rounded, color: _textTertiary, size: 18),
            const SizedBox(width: 5),
            Text('${widget.post.commentCount}', style: TextStyle(color: _textTertiary, fontWeight: FontWeight.w600, fontSize: 13)),
          ])),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _showRepostOptions,
          child: Row(children: [
            RotationTransition(turns: _repostTurns,
              child: Icon(Icons.repeat_rounded, color: _reposted ? BT.repostTeal : _textTertiary, size: 20)),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(color: _reposted ? BT.repostTeal : _textTertiary, fontWeight: FontWeight.w600, fontSize: 13),
              child: Text('${widget.post.repostCount + (_reposted ? 1 : 0)}')),
          ])),
        const Spacer(),
        if (widget.post.author == myName && widget.post.seenBy.isNotEmpty)
          Row(children: [
            Icon(Icons.remove_red_eye_rounded, color: _textTertiary, size: 16),
            const SizedBox(width: 4),
            Text(widget.post.seenBy.length == 1 ? 'Seen by ${widget.post.seenBy.first.replaceAll('@', '')}' : '${widget.post.seenBy.length} views',
              style: TextStyle(color: _textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
          ]),
        Icon(Icons.bookmark_border_rounded, color: _textTertiary, size: 19),
      ]));
  }

  void _showOptionsSheet() {
    final myName = _myName;
    if (widget.post.author != myName) return;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: BT.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: BT.pastelBlue.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded, color: Color(0xFF6AAED6), size: 22)),
              title: const Text('Edit this rant', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              onTap: () { Navigator.pop(context); _showEditSheet(); }),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: BT.heartRed.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: BT.heartRed, size: 22)),
              title: const Text('Delete this rant', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.w700, fontSize: 15)),
              onTap: () async {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                try {
                  if (widget.post.isRepost && widget.post.originalPostId != null) {
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.originalPostId).update({'repostCount': FieldValue.increment(-1)});
                  }
                  await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).delete();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }),
          ]))));
  }

  void _showRepostOptions() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: BT.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: BT.repostTeal.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.repeat_rounded, color: BT.repostTeal, size: 22)),
              title: const Text('Repost', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              onTap: () { Navigator.pop(context); _executeRepost(isQuote: false); }),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: BT.pastelPurple.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded, color: BT.pastelPurple, size: 22)),
              title: const Text('Quote', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              onTap: () { Navigator.pop(context); _openQuoteScreen(); }),
          ]))));
  }

  void _openQuoteScreen() async =>
      await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteComposeScreen(post: widget.post)));

  void _executeRepost({required bool isQuote}) async {
    if (_reposted) return;
    HapticFeedback.lightImpact();
    setState(() => _reposted = true);
    _repostCtrl.forward(from: 0);

    final myName    = _myName;
    final myInitial = myName.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'repostCount': FieldValue.increment(1),
      });
      final isSR = widget.post.isRepost && widget.post.text.isEmpty;
      await FirebaseFirestore.instance.collection('posts').add({
        'author': myName, 'avatarSeed': myInitial,
        'avatarColorIndex': math.Random().nextInt(6),
        'text': '', 'mood': 'none', 
        'likedBy': [], 
        'commentCount': 0, 'repostCount': 0,
        'createdAt': FieldValue.serverTimestamp(), 'displayTime': 'Just now',
        'music': widget.post.music?.toMap(), 'isRepost': true, 'seenBy': [],
        'circle': widget.post.circle,
        'reactions': {},
        'isGhost': false,
        'originalPostId': isSR ? widget.post.originalPostId : widget.post.id,
        'repostedBy': myName,
        'originalAuthor': isSR ? widget.post.originalAuthor : widget.post.author,
        'originalAvatarSeed': isSR ? widget.post.originalAvatarSeed : widget.post.avatarSeed,
        'originalAvatarColorIndex': isSR ? widget.post.originalAvatarColorIndex : widget.post.avatarColorIndex,
        'originalText': isSR ? widget.post.originalText : widget.post.text,
        'originalTimestamp': isSR ? widget.post.originalTimestamp : widget.post.timestamp,
        'originalImageUrls': isSR ? widget.post.originalImageUrls : widget.post.imageUrls,
      });

      final targetAuthorName = isSR ? widget.post.originalAuthor : widget.post.author;
      
      if (targetAuthorName != null && targetAuthorName != myName) {
        final targetUid = await NotificationService.getUidFromHandle(targetAuthorName);

        if (targetUid != null) {
          await NotificationService.sendRealNotification(
            targetUserId: targetUid,
            type: 'repost',
            actorName: myName,
            message: ' reposted your rant.',
            referenceId: isSR ? widget.post.originalPostId : widget.post.id, 
          );
        }
      }
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
      final pickedFiles = await ImagePicker().pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        int slots = 5 - (existingImageUrls.length + newImageBytes.length);
        if (slots <= 0) return;
        List<Uint8List> bl = [];
        for (int i = 0; i < math.min(pickedFiles.length, slots); i++) bl.add(await pickedFiles[i].readAsBytes());
        setModalState(() => newImageBytes.addAll(bl));
      }
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(width: 3.5, height: 22,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('Edit Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
              ]),
              Container(
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]), borderRadius: BorderRadius.circular(30)),
                child: TextButton(
                  onPressed: isSaving ? null : () async {
                    if (editCtrl.text.trim().isEmpty && editedMusic == null && existingImageUrls.isEmpty && newImageBytes.isEmpty) return;
                    setModalState(() => isSaving = true);
                    try {
                      Map<String, dynamic> updates = {'text': editCtrl.text.trim()};
                      List<String> finalUrls = List.from(existingImageUrls);
                      for (var bytes in newImageBytes) {
                        final ref = FirebaseStorage.instance.ref().child('bubbles/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await ref.putData(bytes);
                        finalUrls.add(await ref.getDownloadURL());
                      }
                      updates['imageUrls'] = finalUrls;
                      if (editedMusic != null) updates['music'] = editedMusic!.toMap();
                      else updates['music'] = FieldValue.delete();
                      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update(updates);
                      if (!mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      setModalState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: isSaving
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
            ]),
            const SizedBox(height: 16),
            TextField(controller: editCtrl, autofocus: true, maxLines: 4, maxLength: 280,
              style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
              decoration: const InputDecoration(border: InputBorder.none, counterStyle: TextStyle(color: BT.textTertiary, fontSize: 11))),
            if (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ...[
              SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, children: [
                ...existingImageUrls.map((url) => Padding(padding: const EdgeInsets.only(right: 10),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 110, height: 110, fit: BoxFit.cover)),
                    Positioned(top: 6, right: 6, child: GestureDetector(
                      onTap: () => setModalState(() => existingImageUrls.remove(url)),
                      child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                  ]))),
                ...newImageBytes.map((bytes) => Padding(padding: const EdgeInsets.only(right: 10),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, width: 110, height: 110, fit: BoxFit.cover)),
                    Positioned(top: 6, right: 6, child: GestureDetector(
                      onTap: () => setModalState(() => newImageBytes.remove(bytes)),
                      child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                  ]))),
              ])),
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
              child: Row(children: [
                GestureDetector(
                  onTap: () => pickEditImages(setModalState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? BT.pastelBlue.withOpacity(0.1) : BT.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? BT.pastelBlue.withOpacity(0.4) : BT.divider, width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.image_outlined, color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary, size: 15),
                      const SizedBox(width: 5),
                      Text((existingImageUrls.isEmpty && newImageBytes.isEmpty) ? 'Image' : '${existingImageUrls.length + newImageBytes.length} / 5 ✓',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: (existingImageUrls.isNotEmpty || newImageBytes.isNotEmpty) ? const Color(0xFF6AAED6) : BT.textTertiary)),
                    ]))),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                    builder: (_) => MusicPickerSheet(onSelect: (t) { setModalState(() => editedMusic = t); Navigator.pop(context); })),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: editedMusic != null ? BT.spotify.withOpacity(0.1) : BT.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: editedMusic != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.music_note_rounded, color: editedMusic != null ? BT.spotify : BT.textTertiary, size: 15),
                      const SizedBox(width: 5),
                      Text(editedMusic != null ? 'Music ✓' : 'Music', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: editedMusic != null ? BT.spotify : BT.textTertiary)),
                    ]))),
              ])),
          ])))));
  }
} 

// ============================================================================
// ANIMATED SMOKE BACKGROUND FOR GHOST CARDS
// ============================================================================
class _CardSmokeBackground extends StatefulWidget {
  const _CardSmokeBackground();
  @override State<_CardSmokeBackground> createState() => _CardSmokeBackgroundState();
}

class _CardSmokeBackgroundState extends State<_CardSmokeBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  @override 
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }
  
  @override 
  void dispose() { 
    _ctrl.dispose(); 
    super.dispose(); 
  }
  
  @override 
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 0.5, -1.0),
              end: Alignment(1.0 - t * 0.5, 1.0),
              colors: [
                const Color(0xFF6B5FA0).withOpacity(0.1),
                const Color(0xFF4A3D78).withOpacity(0.0),
                const Color(0xFF9B8FBF).withOpacity(0.15),
              ],
            )
          )
        );
      }
    );
  }
}

// ============================================================================
// REACTION TRAY WIDGET
// ============================================================================
class _ReactionTray extends StatelessWidget {
  final List<String>          reactions;
  final String?               myReaction;
  final String?               hoverEmoji;
  final AnimationController   trayCtrl;
  final Animation<double>     trayScale, trayOpacity;
  final Animation<Offset>     traySlide;
  final void Function(String) onPick;
  final VoidCallback          onDismiss;
  final VoidCallback          onCustomize;
  final bool                  hoverCustomize;
  final GlobalKey             customizeBtnKey;

  const _ReactionTray({
    Key? key,
    required this.reactions,
    required this.myReaction,
    required this.hoverEmoji,
    required this.trayCtrl,
    required this.trayScale,
    required this.trayOpacity,
    required this.traySlide,
    required this.onPick,
    required this.onDismiss,
    required this.onCustomize,
    this.hoverCustomize = false,
    required this.customizeBtnKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: trayOpacity,
        child: SlideTransition(
          position: traySlide,
          child: ScaleTransition(
            scale: trayScale,
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(color: BT.pastelPurple.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withOpacity(0.07),    blurRadius: 8,  offset: const Offset(0, 2)),
                ],
                border: Border.all(color: BT.divider, width: 1)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reactions.asMap().entries.map((entry) {
                    final idx    = entry.key;
                    final emoji  = entry.value;
                    final isMe     = myReaction == emoji;
                    final isHover  = hoverEmoji == emoji;

                    return AnimatedBuilder(
                      animation: trayCtrl,
                      builder: (_, child) {
                        final start   = (idx * 0.06).clamp(0.0, 0.6);
                        final end     = (start + 0.45).clamp(0.0, 1.0);
                        final t       = ((trayCtrl.value - start) / (end - start)).clamp(0.0, 1.0);
                        return Transform.scale(
                          scale:   Curves.elasticOut.transform(t),
                          child: Opacity(opacity: Curves.easeOut.transform(t), child: child));
                      },
                      child: _EmojiButton(
                        emoji:      emoji,
                        isSelected: isMe,
                        isHovered:  isHover,
                        onTap:      () => onPick(emoji)));
                  }),

                  AnimatedBuilder(
                    animation: trayCtrl,
                    builder: (_, child) => Opacity(
                      opacity: Curves.easeOut.transform(trayCtrl.value.clamp(0.0, 1.0)),
                      child: child),
                    child: Container(
                      width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: BT.divider)),

                  AnimatedBuilder(
                    animation: trayCtrl,
                    builder: (_, child) {
                      final t = ((trayCtrl.value - 0.40) / 0.45).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: Curves.elasticOut.transform(t),
                        child: Opacity(opacity: Curves.easeOut.transform(t), child: child));
                    },
                    child: GestureDetector(
                      onTap: onCustomize,
                      child: AnimatedContainer(
                        key: customizeBtnKey,
                        duration: const Duration(milliseconds: 150),
                        width: 40, height: 40,
                        margin: const EdgeInsets.only(left: 2),
                        transform: Matrix4.translationValues(0, hoverCustomize ? -10.0 : 0.0, 0),
                        decoration: BoxDecoration(
                          color: hoverCustomize
                              ? BT.pastelPurple.withOpacity(0.22)
                              : BT.pastelPurple.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hoverCustomize
                                ? BT.pastelPurple.withOpacity(0.60)
                                : BT.pastelPurple.withOpacity(0.25),
                            width: hoverCustomize ? 2.0 : 1.2)),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(fontSize: hoverCustomize ? 20.0 : 16.0),
                          child: const Text('✏️', textAlign: TextAlign.center)))))
                ]))))));
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final bool   isSelected, isHovered;
  final VoidCallback onTap;
  const _EmojiButton({
    required this.emoji, required this.isSelected,
    required this.isHovered, required this.onTap});
  @override State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hoverLift = widget.isHovered ? -10.0 : 0.0;
    final baseSize  = (widget.isSelected || widget.isHovered) ? 23.0 : 20.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _ctrl.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 44, height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          transform: Matrix4.translationValues(0, hoverLift, 0),
          decoration: BoxDecoration(
            color: widget.isSelected || widget.isHovered
                ? BT.pastelPurple.withOpacity(0.18) : Colors.transparent,
            shape: BoxShape.circle,
            border: (widget.isSelected || widget.isHovered)
                ? Border.all(color: BT.pastelPurple.withOpacity(0.45), width: 1.5)
                : null),
          child: Center(child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(fontSize: widget.isHovered ? 24.0 : baseSize),
            child: Text(widget.emoji))))));
  }
}

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onDone;
  const _FloatingEmoji({required this.emoji, required this.onDone});
  @override State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _opacity, _scale, _dy;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _dy = Tween<double>(begin: 0.0, end: -55.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.6).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    ]).animate(_ctrl);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
    ]).animate(_ctrl);
    _ctrl.forward().then((_) => widget.onDone());
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, _dy.value),
      child: Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Text(widget.emoji,
            style: const TextStyle(fontSize: 32),
            textAlign: TextAlign.center)))));
}

const _kEmojiCategories = [
  (label: 'Feelings',  emoji: '😤',  items: ['😤','😭','🥺','😡','🤬','😱','🫠','😮‍💨','🥲','😔','😩','😫','🤯','🙃','😒','😞','😣','🤒','😓','😶']),
  (label: 'Reactions', emoji: '🔥',  items: ['🔥','💀','👀','💅','🫧','❤️','💔','🫶','👏','🤝','😮','😂','💯','🙌','✨','🎉','💥','⚡','🤣','😆']),
  (label: 'Vibes',     emoji: '🌸',  items: ['🌸','🫶','✨','💫','🌙','⭐','🦋','🌈','💕','🫂','🥰','😍','🤩','💖','🌺','🌻','🍀','🎀','🪷','💐']),
  (label: 'Sassy',     emoji: '💅',  items: ['💅','🤌','👑','💁','😏','🙄','🫠','🤷','😌','🫡','🤭','😈','👿','🤪','😜','🥱','🙈','💋','🫦','😎']),
  (label: 'Symbols',   emoji: '💯',  items: ['💯','❗','❓','💢','💤','🚫','✅','❌','⭕','🔴','🟣','🔵','💜','💙','🩷','🖤','🤍','🩶','💛','🟡']),
];

class _EmojiCustomizeSheet extends StatefulWidget {
  final List<String> current;
  const _EmojiCustomizeSheet({required this.current});
  @override State<_EmojiCustomizeSheet> createState() => _EmojiCustomizeSheetState();
}

class _EmojiCustomizeSheetState extends State<_EmojiCustomizeSheet>
    with SingleTickerProviderStateMixin {
  late List<String>   _selected;
  late TabController  _tabCtrl;

  static const int kMaxReactions = 6;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.current);
    _tabCtrl  = TabController(length: _kEmojiCategories.length, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _toggleEmoji(String emoji) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selected.contains(emoji)) {
        _selected.remove(emoji);
      } else if (_selected.length < kMaxReactions) {
        _selected.add(emoji);
      } else {
        _selected.removeAt(0);
        _selected.add(emoji);
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _removeSlot(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selected.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: BT.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: BT.divider, borderRadius: BorderRadius.circular(2))),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 3.5, height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  const Text('Your Reactions',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
                ]),
                const SizedBox(height: 2),
                Text('${_selected.length} / $kMaxReactions selected',
                  style: const TextStyle(fontSize: 12.5, color: BT.textSecondary,
                    fontWeight: FontWeight.w500)),
              ]),
              const Spacer(),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).pop(List<String>.from(_selected)),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: BT.pastelPurple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                    child: const Text('Save',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))))),
            ])),

          const SizedBox(height: 14),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BT.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BT.divider, width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Row(children: [
              ...List.generate(kMaxReactions, (i) {
                final filled = i < _selected.length;
                return Expanded(
                  child: GestureDetector(
                    onTap: filled ? () => _removeSlot(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 46,
                      decoration: BoxDecoration(
                        color: filled
                            ? BT.pastelPurple.withOpacity(0.10)
                            : BT.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: filled
                              ? BT.pastelPurple.withOpacity(0.30)
                              : BT.divider.withOpacity(0.8),
                          width: 1.2)),
                      child: filled
                          ? Stack(alignment: Alignment.center, children: [
                              Text(_selected[i], style: const TextStyle(fontSize: 22)),
                              Positioned(top: 3, right: 3,
                                child: Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    color: BT.textTertiary.withOpacity(0.55),
                                    shape: BoxShape.circle),
                                  child: const Center(child: Icon(Icons.close, size: 9, color: Colors.white)))),
                            ])
                          : Center(child: Text('+',
                              style: TextStyle(fontSize: 20, color: BT.textTertiary.withOpacity(0.5),
                                fontWeight: FontWeight.w300)))),
                  ));
              }),
            ])),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 12, color: BT.textTertiary.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text('Tap a slot to remove • Tap an emoji below to add',
                style: TextStyle(fontSize: 11.5, color: BT.textTertiary.withOpacity(0.7))),
            ])),

          const SizedBox(height: 10),

          Container(
            color: BT.card,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: BT.pastelPurple,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: BT.textPrimary,
              unselectedLabelColor: BT.textTertiary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              dividerColor: BT.divider,
              tabs: _kEmojiCategories.map((c) =>
                Tab(text: '${c.emoji} ${c.label}')).toList())),

          Expanded(child: TabBarView(
            controller: _tabCtrl,
            children: _kEmojiCategories.map((category) {
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4),
                itemCount: category.items.length,
                itemBuilder: (context, i) {
                  final emoji    = category.items[i];
                  final isChosen = _selected.contains(emoji);

                  return GestureDetector(
                    onTap: () => _toggleEmoji(emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isChosen
                            ? BT.pastelPurple.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isChosen
                            ? Border.all(color: BT.pastelPurple.withOpacity(0.40), width: 1.2)
                            : null),
                      child: Stack(alignment: Alignment.center, children: [
                        AnimatedScale(
                          scale: isChosen ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Text(emoji, style: const TextStyle(fontSize: 24))),
                        if (isChosen)
                          Positioned(top: 4, right: 4,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: BT.pastelPurple,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: BT.pastelPurple.withOpacity(0.5), blurRadius: 4)]),
                              child: const Icon(Icons.check_rounded, size: 9, color: Colors.white))),
                      ])));
                });
            }).toList())),
        ]),
      ),
    );
  }
}

// ============================================================================
// ── NEW: REACTORS SHEET WIDGET ──
// ============================================================================
class _ReactorsSheet extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final List<String> uids;
  final List<String> handles;
  final void Function(String) onUserTap;

  const _ReactorsSheet({
    required this.title,
    this.icon,
    this.iconColor,
    required this.uids,
    required this.handles,
    required this.onUserTap,
  });

  @override
  State<_ReactorsSheet> createState() => _ReactorsSheetState();
}

class _ReactorsSheetState extends State<_ReactorsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    List<Map<String, dynamic>> fetched = [];
    final firestore = FirebaseFirestore.instance;

    try {
      if (widget.uids.isNotEmpty) {
        // Fetch based on the new array of UIDs
        for (var uid in widget.uids.take(50)) {
          final doc = await firestore.collection('users').doc(uid).get();
          if (doc.exists) {
            fetched.add({...doc.data() as Map<String, dynamic>, 'uid': doc.id});
          }
        }
      } else if (widget.handles.isNotEmpty) {
        // Fetch based on handles
        for (var handle in widget.handles.take(50)) {
          final cleanHandle = handle.replaceAll('@', '');
          final q = await firestore.collection('users').where('name', isEqualTo: cleanHandle).limit(1).get();
          if (q.docs.isNotEmpty) {
            fetched.add({...q.docs.first.data(), 'uid': q.docs.first.id});
          } else {
            // If the user deleted their account but their reaction remains
            fetched.add({'name': cleanHandle, 'profileUrl': '', 'fallback': true});
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching reactors: $e');
    }

    if (mounted) {
      setState(() {
        _users = fetched;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        // Prevents the sheet from taking up the whole screen if there are a ton of likes
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Standard Bubble Sheet Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(color: BT.divider, borderRadius: BorderRadius.circular(2))
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.iconColor, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BT.textPrimary)),
                ],
              ),
            ),
            const Divider(color: BT.divider),
            
            // Dynamic List
            _loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: BT.pastelPurple),
                )
              : _users.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No one to show.', style: TextStyle(color: BT.textSecondary)),
                  )
                : Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _users.length,
                      itemBuilder: (context, i) {
                        final u = _users[i];
                        final name = u['name'] ?? 'Unknown';
                        final handle = '@$name';
                        final profileUrl = u['profileUrl'] as String?;
                        final initial = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: BT.pastelPurple.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: profileUrl != null && profileUrl.isNotEmpty
                                ? Image.network(profileUrl, fit: BoxFit.cover)
                                : Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                            ),
                          ),
                          title: Text(handle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: BT.textPrimary)),
                          onTap: () {
                            Navigator.pop(context); // Close the sheet
                            widget.onUserTap(handle); // Jump to their profile
                          },
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}