import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/post.dart';
import '../widgets/bubble_components.dart';
import '../widgets/rant_card.dart';

const Color appBgTint = Color(0xFFFFF5F8);

class ThreadScreen extends StatefulWidget {
  final Post post;
  const ThreadScreen({Key? key, required this.post}) : super(key: key);
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleCommentLike(String commentId, List<dynamic> likes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId);
    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
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
                        const Text('Edit Reply', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: BT.textPrimary)),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [BT.pastelBlue, BT.pastelPurple]),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextButton(
                        onPressed: isSaving ? null : () async {
                          if (editCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId).update({'text': editCtrl.text.trim()});
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCommentOptions(String commentId, String currentText) {
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
                  child: const Icon(Icons.delete_outline_rounded, color: BT.heartRed, size: 22),
                ),
                title: const Text('Delete reply', style: TextStyle(color: BT.heartRed, fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () async {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                  try {
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').doc(commentId).delete();
                    await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({'commentCount': FieldValue.increment(-1)});
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
      backgroundColor: appBgTint,
      appBar: AppBar(
        backgroundColor: BT.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: BT.textPrimary,
        title: const Text('Thread', style: TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: BT.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: const Divider(height: 1, color: BT.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              children: [
                RantCard(
                  post: widget.post,
                  bubbleAsset: 'assets/images/image_0.png',
                  isPopped: true,
                  onPopAction: () {},
                  onCardTap: () {},
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: BT.divider),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Replies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BT.textSecondary)),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').orderBy('createdAt', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Error loading replies.'));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: BT.pastelPurple),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('No replies yet. Be the first!', style: TextStyle(color: BT.textTertiary)),
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((doc) => _buildReply(doc)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildReplyBar(),
        ],
      ),
    );
  }

  Widget _buildReply(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final commentId = doc.id;
    final likes = data['likes'] as List<dynamic>? ?? [];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = uid != null && likes.contains(uid);
    final myName = uid != null ? '@${FirebaseAuth.instance.currentUser!.displayName}' : '@Me';
    final isMyComment = data['uid'] == uid || data['author'] == myName;

    String formattedTime = 'Just now';
    if (data['createdAt'] != null) {
      formattedTime = DateFormat('MMM d, h:mm a').format((data['createdAt'] as Timestamp).toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: BT.card,
        shape: const BubbleTailShape(borderRadius: 24, side: BorderSide(color: BT.divider, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FETCH REPLY AUTHOR AVATAR
            BubbleAvatar(author: data['author'] ?? '', seed: data['avatarSeed'] ?? 'X', colorIndex: data['avatarColorIndex'] ?? 0, radius: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data['author'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: BT.textPrimary, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('·', style: TextStyle(color: BT.textTertiary)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          formattedTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BT.textTertiary, fontSize: 11.5),
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data['text'] ?? '',
                    style: const TextStyle(fontSize: 13.5, color: BT.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCommentLike(commentId, likes),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? BT.heartRed : BT.divider,
                          size: 16,
                        ),
                      ),
                      if (likes.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${likes.length}',
                          style: TextStyle(
                            color: isLiked ? BT.heartRed : BT.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final initial = currentUser?.displayName?.isNotEmpty == true ? currentUser!.displayName![0].toUpperCase() : '✦';
    final name = currentUser?.displayName != null ? '@${currentUser!.displayName}' : '@Me';

    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: BT.card,
        border: Border(top: BorderSide(color: BT.divider, width: 1)),
      ),
      child: Row(
        children: [
          // SHOW LIVE AVATAR ON REPLY BAR
          BubbleAvatar(author: name, seed: initial, colorIndex: 4, radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Post your reply...',
                hintStyle: TextStyle(color: BT.textTertiary, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (_ctrl.text.trim().isNotEmpty) {
                final text = _ctrl.text.trim();
                _ctrl.clear();
                FocusScope.of(context).unfocus();
                try {
                  await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).collection('comments').add({
                    'uid': currentUser?.uid,
                    'likes': [],
                    'author': name,
                    'avatarSeed': initial,
                    'avatarColorIndex': math.Random().nextInt(6),
                    'text': text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
                    'commentCount': FieldValue.increment(1),
                  });
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to comment: $e')));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}