import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post.dart';
import '../../widgets/media_viewers.dart';
import '../../widgets/bubble_components.dart';

const Color appBgTint = Color(0xFFFFF5F8);

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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      int slots = 4 - _imagesBytes.length;
      if (slots <= 0) return;
      List<Uint8List> newBytes = [];
      for (int i = 0; i < math.min(pickedFiles.length, slots); i++) {
        newBytes.add(await pickedFiles[i].readAsBytes());
      }
      setState(() => _imagesBytes.addAll(newBytes));
    }
  }

  Future<void> _submitQuote() async {
    if (_ctrl.text.trim().isEmpty && _imagesBytes.isEmpty) return;
    setState(() => _isPosting = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    final myName = currentUser?.displayName?.isNotEmpty == true ? '@${currentUser!.displayName}' : '@Me';
    final myInitial = myName.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      List<String> imageUrls = [];
      for (var bytes in _imagesBytes) {
        String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${_imagesBytes.indexOf(bytes)}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putData(bytes);
        imageUrls.add(await ref.getDownloadURL());
      }
      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'repostCount': FieldValue.increment(1)});
      final p = widget.post;
      final isSR = p.isRepost && p.text.isEmpty;

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
        'music': p.music?.toMap(),
        'imageUrls': imageUrls,
        'isRepost': true,
        'seenBy': [],
        'originalPostId': isSR ? p.originalPostId : p.id,
        'repostedBy': myName,
        'originalAuthor': isSR ? p.originalAuthor : p.author,
        'originalAvatarSeed': isSR ? p.originalAvatarSeed : p.avatarSeed,
        'originalAvatarColorIndex': isSR ? p.originalAvatarColorIndex : p.avatarColorIndex,
        'originalText': isSR ? p.originalText : p.text,
        'originalTimestamp': isSR ? p.originalTimestamp : p.timestamp,
        'originalImageUrls': isSR ? p.originalImageUrls : p.imageUrls,
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
    final isSR = p.isRepost && p.text.isEmpty;
    final origAuthor = isSR ? p.originalAuthor : p.author;
    final origSeed = isSR ? p.originalAvatarSeed : p.avatarSeed;
    final origColor = isSR ? p.originalAvatarColorIndex : p.avatarColorIndex;
    final origText = isSR ? p.originalText : p.text;
    final origTime = isSR ? p.originalTimestamp : p.timestamp;
    final origImages = isSR ? p.originalImageUrls : p.imageUrls;
    final origMusic = p.music;

    return Scaffold(
      backgroundColor: appBgTint,
      appBar: AppBar(
        backgroundColor: BT.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: BT.textPrimary, fontSize: 16)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: BT.pastelPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isPosting
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Post', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BubbleAvatar(seed: initial, colorIndex: 4, radius: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _ctrl,
                                autofocus: true,
                                maxLines: null,
                                style: const TextStyle(fontSize: 16, color: BT.textPrimary, height: 1.4),
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle: const TextStyle(color: BT.textTertiary, fontSize: 16),
                                  border: InputBorder.none,
                                  counter: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _ctrl,
                                    builder: (_, value, __) => PulseCounter(current: value.text.length, maxChars: 280),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_imagesBytes.isNotEmpty) ...[
                                SizedBox(
                                  height: 90,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imagesBytes.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (_, index) => Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(_imagesBytes[index], width: 90, height: 90, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _imagesBytes.removeAt(index)),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: BT.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: BT.divider, width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        BubbleAvatar(seed: origSeed ?? 'X', colorIndex: origColor, radius: 11),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            origAuthor ?? '',
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
                                            origTime ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: BT.textTertiary, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((origText ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          origText!,
                                          style: const TextStyle(fontSize: 14, color: BT.textPrimary, height: 1.4),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (origImages.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: ImageCarousel(imageUrls: origImages, height: 140, onImageTap: (_) {}),
                                      ),
                                    if (origMusic != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: MusicAttachmentCard(track: origMusic!),
                                      ),
                                  ],
                                ),
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
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.1) : BT.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _imagesBytes.isNotEmpty ? BT.pastelBlue.withOpacity(0.4) : BT.divider, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              _imagesBytes.isEmpty ? 'Image' : '${_imagesBytes.length} / 4 ✓',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}