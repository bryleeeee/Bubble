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
import 'media_viewers.dart';
import 'bubble_components.dart';
import 'music_picker_sheet.dart';

// ============================================================================
// COMPOSE SHEET
// ============================================================================
class ComposeSheet extends StatefulWidget {
  final String targetCircle;
  const ComposeSheet({Key? key, required this.targetCircle}) : super(key: key);
  @override State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet>
    with TickerProviderStateMixin {
  
  MoodTag  _mood       = MoodTag.none;
  MusicTrack? _music;
  final _ctrl          = TextEditingController();
  List<Uint8List> _imagesBytes = [];
  bool _isPosting      = false;
  bool _isGhostMode    = false;

  // Ghost mode transition
  late AnimationController _ghostCtrl;
  late AnimationController _shakeCtrl; 
  late Animation<double>   _ghostTint;   
  late Animation<double>   _ghostShake;  

  @override
  void initState() {
    super.initState();
    _ghostCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _ghostTint = CurvedAnimation(parent: _ghostCtrl, curve: Curves.easeInOut);

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _shakeCtrl.value = 1.0; 
    
    _ghostShake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0).chain(CurveTween(curve: Curves.easeIn)),  weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -3.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),  weight: 15),
    ]).animate(_shakeCtrl); 
  }

  @override 
  void dispose() { 
    _ghostCtrl.dispose(); 
    _shakeCtrl.dispose(); 
    _ctrl.dispose(); 
    super.dispose(); 
  }

  void _toggleGhost() {
    HapticFeedback.mediumImpact();
    setState(() => _isGhostMode = !_isGhostMode);
    if (_isGhostMode) {
      _ghostCtrl.forward();
      _shakeCtrl.forward(from: 0.0);
    } else {
      _ghostCtrl.reverse();
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      int slots = 5 - _imagesBytes.length; // ── INCREASED TO 5 ──
      if (slots <= 0) return;
      List<Uint8List> newBytes = [];
      for (int i = 0; i < math.min(pickedFiles.length, slots); i++) {
        newBytes.add(await pickedFiles[i].readAsBytes());
      }
      setState(() => _imagesBytes.addAll(newBytes));
    }
  }

  Future<void> _submitPost() async {
    if (_ctrl.text.isEmpty && _music == null && _imagesBytes.isEmpty) return;
    setState(() => _isPosting = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final name    = currentUser?.displayName?.isNotEmpty == true ? '@${currentUser!.displayName}' : '@Me';
    final initial = name.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      List<String> imageUrls = [];
      for (var bytes in _imagesBytes) {
        final ref = FirebaseStorage.instance.ref()
            .child('bubbles/${DateTime.now().millisecondsSinceEpoch}_${_imagesBytes.indexOf(bytes)}.jpg');
        await ref.putData(bytes);
        imageUrls.add(await ref.getDownloadURL());
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
        'seenBy': [],
        'circle': widget.targetCircle,
        'reactions': {},
        'isGhost': _isGhostMode,
        'expiresAt': _isGhostMode
            ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)))
            : null,
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
    return AnimatedBuilder(
      animation: _ghostTint,
      builder: (context, child) {
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(_ghostShake.value, 0),
              child: child!,
            ),
            if (_ghostTint.value > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _ghostTint.value * 0.18,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF7B6EA8).withOpacity(0.0),
                                const Color(0xFF9B8FBF).withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_ghostTint.value > 0.3)
              Positioned.fill(
                child: IgnorePointer(
                  // ── FIXED: UNDERSCORE RESTORED ──
                  child: _GhostParticleOverlay(intensity: _ghostTint.value),
                ),
              ),
          ],
        );
      },
      child: _buildSheetContent(),
    );
  }

  Widget _buildSheetContent() {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: _isGhostMode ? const Color(0xFFF5F2FA) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 3.5, height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _isGhostMode
                              ? [const Color(0xFF8B7BAF), const Color(0xFF6B5F94)]
                              : [BT.pastelPink, BT.pastelPurple],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18,
                            color: _isGhostMode ? const Color(0xFF3D3560) : BT.textPrimary,
                            height: 1.1,
                          ),
                          child: Text(_isGhostMode ? 'Ghost Rant 👻' : 'New Rant'),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isGhostMode
                                ? const Color(0xFF8B7BAF).withOpacity(0.15)
                                : BT.pastelPurple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isGhostMode
                                ? 'vanishes in 24h'
                                : 'in ${widget.targetCircle}',
                            style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w800,
                              color: _isGhostMode
                                  ? const Color(0xFF8B7BAF)
                                  : BT.pastelPurple,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isGhostMode
                          ? [const Color(0xFF8B7BAF), const Color(0xFF5E5280)]
                          : [BT.pastelPink, BT.pastelPurple],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextButton(
                    onPressed: _isPosting ? null : _submitPost,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isPosting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true, maxLines: 4, maxLength: 280,
              style: TextStyle(
                fontSize: 15, height: 1.5,
                color: _isGhostMode ? const Color(0xFF3D3560) : BT.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: _isGhostMode ? "whisper something... 👻" : "what's going on?? ✦",
                hintStyle: TextStyle(
                  color: _isGhostMode ? const Color(0xFF8B7BAF).withOpacity(0.6) : BT.textTertiary.withOpacity(0.8),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                counter: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _ctrl,
                  builder: (_, value, __) => PulseCounter(current: value.text.length, maxChars: 280),
                ),
              ),
            ),
            if (_imagesBytes.isNotEmpty) ...[
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagesBytes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imagesBytes[index], width: 110, height: 110, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagesBytes.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_music != null) ...[
              MusicAttachmentCard(track: _music!),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _music = null),
                child: const Text('Remove', style: TextStyle(color: BT.textTertiary, fontSize: 11.5, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('MOOD  ', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 11,
                          color: _isGhostMode ? const Color(0xFF8B7BAF) : BT.textTertiary,
                          letterSpacing: 0.8,
                        )),
                        ...MoodTag.values.where((m) => m != MoodTag.none).map((m) {
                          final active = _mood == m;
                          return GestureDetector(
                            onTap: () => setState(() => _mood = active ? MoodTag.none : m),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? m.bg : BT.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: active ? m.fg.withOpacity(0.5) : BT.divider, width: 1.5),
                              ),
                              child: Text(m.label, style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? m.fg : BT.textSecondary,
                              )),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _GhostToggle(isActive: _isGhostMode, onTap: _toggleGhost),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickImages,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.1) : BT.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.4) : BT.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                          color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary,
                          size: 15),
                        if (_imagesBytes.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          // ── INCREASED TO 5 ──
                          Text('${_imagesBytes.length}/5',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6AAED6))),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context, isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                    builder: (_) => MusicPickerSheet(onSelect: (t) { setState(() => _music = t); Navigator.pop(context); }),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _music != null ? BT.spotify.withOpacity(0.1) : BT.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _music != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded,
                          color: _music != null ? BT.spotify : BT.textTertiary, size: 15),
                        if (_music != null) ...[
                          const SizedBox(width: 5),
                          const Text('✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BT.spotify)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GHOST TOGGLE BUTTON
// ============================================================================
class _GhostToggle extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _GhostToggle({required this.isActive, required this.onTap});
  @override State<_GhostToggle> createState() => _GhostToggleState();
}

class _GhostToggleState extends State<_GhostToggle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84).chain(CurveTween(curve: Curves.easeIn)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.06).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 25),
    ]).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _ctrl.forward(from: 0); widget.onTap(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive ? const Color(0xFF2D2547) : BT.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isActive ? const Color(0xFF6B5FA0) : BT.divider,
              width: 1.5),
            boxShadow: widget.isActive
                ? [BoxShadow(color: const Color(0xFF6B5FA0).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
                : []),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: widget.isActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lens_blur, size: 14, color: BT.textTertiary),
            ]),
            secondChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lens_blur, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ghost', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                    Text('24h', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.65), height: 1.1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GHOST PARTICLE OVERLAY
// ============================================================================
class _GhostParticleOverlay extends StatefulWidget {
  final double intensity;
  const _GhostParticleOverlay({required this.intensity});
  @override State<_GhostParticleOverlay> createState() => _GhostParticleOverlayState();
}

class _GhostParticleOverlayState extends State<_GhostParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random(42);
  late List<_GhostDot> _dots;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _dots = List.generate(8, (i) => _GhostDot(
      x: _rng.nextDouble(),
      phase: _rng.nextDouble(),
      speed: 0.5 + _rng.nextDouble() * 0.5,
      size: 3.0 + _rng.nextDouble() * 4.0,
    ));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final sz = MediaQuery.of(context).size;
        return Stack(
          children: _dots.map((dot) {
            final t = (_ctrl.value * dot.speed + dot.phase) % 1.0;
            final y = sz.height * (1.0 - t);
            final opacity = math.sin(t * math.pi).clamp(0.0, 1.0) * widget.intensity * 0.4;
            return Positioned(
              left: sz.width * dot.x - dot.size / 2,
              top: y,
              child: Container(
                width: dot.size, height: dot.size,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B8FBF).withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _GhostDot {
  final double x, phase, speed, size;
  _GhostDot({required this.x, required this.phase, required this.speed, required this.size});
}