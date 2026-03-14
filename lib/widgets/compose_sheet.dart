import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import 'media_viewers.dart';
import 'bubble_components.dart';
import 'music_picker_sheet.dart';

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({Key? key}) : super(key: key);
  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  MoodTag _mood = MoodTag.none;
  MusicTrack? _music;
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

  Future<void> _submitPost() async {
    if (_ctrl.text.isEmpty && _music == null && _imagesBytes.isEmpty) return;
    setState(() => _isPosting = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    final name = currentUser?.displayName?.isNotEmpty == true ? '@${currentUser!.displayName}' : '@Me';
    final initial = name.replaceAll('@', '').substring(0, 1).toUpperCase();

    try {
      List<String> imageUrls = [];
      for (var bytes in _imagesBytes) {
        String fileName = 'bubbles/${DateTime.now().millisecondsSinceEpoch}_${_imagesBytes.indexOf(bytes)}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
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
                        gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('New Rant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
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
              autofocus: true,
              maxLines: 4,
              maxLength: 280,
              style: const TextStyle(fontSize: 15, color: BT.textPrimary, height: 1.5),
              decoration: InputDecoration(
                hintText: "what's going on?? ✦",
                hintStyle: TextStyle(color: BT.textTertiary.withOpacity(0.8), fontSize: 15),
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
                        top: 6,
                        right: 6,
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
                        const Text('MOOD  ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: BT.textTertiary, letterSpacing: 0.8)),
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
                              child: Text(m.label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? m.fg : BT.textSecondary)),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _imagesBytes.isNotEmpty ? const Color(0xFF6AAED6) : BT.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                      builder: (_) => MusicPickerSheet(
                        onSelect: (t) {
                          setState(() => _music = t);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _music != null ? BT.spotify.withOpacity(0.1) : BT.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _music != null ? BT.spotify.withOpacity(0.4) : BT.divider, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, color: _music != null ? BT.spotify : BT.textTertiary, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          _music != null ? 'Music ✓' : 'Music',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _music != null ? BT.spotify : BT.textTertiary),
                        ),
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