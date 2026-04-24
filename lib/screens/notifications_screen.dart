import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Make sure these paths match your folder structure! ──
import '../models/post.dart';
import '../screens/thread_screen.dart';

// ============================================================================
// NOTIFICATION SERVICE (Upgraded Detective)
// ============================================================================
class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// ── BULLETPROOF HELPER: Find a user's UID from their handle ──
  static Future<String?> getUidFromHandle(String handle) async {
    if (handle.isEmpty) return null;
    
    // Strip the @ symbol for the search
    final rawName = handle.replaceAll('@', ''); 
    
    // We will check all common field names just in case!
    final fieldsToCheck = ['name', 'username', 'displayName', 'handle'];

    for (String field in fieldsToCheck) {
      // Check exact match
      var query = await _firestore.collection('users').where(field, isEqualTo: rawName).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.id;
      
      // Check with the @ symbol included
      query = await _firestore.collection('users').where(field, isEqualTo: '@$rawName').limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.id;
    }

    // 🚨 IF IT FAILS, IT WILL PRINT THIS IN YOUR TERMINAL/CONSOLE 🚨
    debugPrint('======================================================');
    debugPrint('🚨 NOTIFICATION FAILED: Could not find user: $rawName');
    debugPrint('🚨 Make sure your "users" collection has a document where the name exactly matches "$rawName" (Case-sensitive!).');
    debugPrint('======================================================');
    return null;
  }

  /// Call this when a real user performs an action worth notifying about!
  static Future<void> sendRealNotification({
    required String targetUserId, 
    required String type,         
    required String actorName,    
    required String message,      
    String? referenceId,          
  }) async {
    final currentUser = _auth.currentUser;
    
    if (currentUser == null || currentUser.uid == targetUserId) return;

    final cleanActorName = '@${actorName.replaceAll('@', '')}';
    final initial = cleanActorName.replaceAll('@', '').substring(0, 1).toUpperCase();

    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
      'type': type,
      'actorName': cleanActorName,
      'actorInitial': initial,
      'actorColorIndex': math.Random().nextInt(6), 
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'referenceId': referenceId,
    });
  }
}

// ============================================================================
// NOTIFICATIONS SCREEN 
// ============================================================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── NUKE BUTTON: Clear all notifications ──
  Future<void> _clearAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    HapticFeedback.heavyImpact(); 

    final snapshots = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .get();

    if (snapshots.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Mark all as read ──
  Future<void> _markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    HapticFeedback.lightImpact();
    
    final batch = _firestore.batch();
    final unreadDocs = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Mark a single notification as read ──
  Future<void> _markAsRead(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA), // bg
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5FA), // bg
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D263B), size: 20), // textPrimary
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications 🔔', 
          style: TextStyle(color: Color(0xFF2D263B), fontWeight: FontWeight.w900, fontSize: 18)), // textPrimary
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFFF5277)), // heartRed
            tooltip: 'Clear all notifications',
            onPressed: _clearAllNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Color(0xFF9B8EAD)), // textTertiary
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFA898D4))); // pastelPurple
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return _NotificationTile(
                      data: data,
                      onTap: () async {
                        if (data['isRead'] == false) {
                          _markAsRead(docId);
                        }

                        final String? postId = data['referenceId'];
                        if (postId == null || postId.isEmpty) return; 

                        try {
                          final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
                          
                          if (postDoc.exists && context.mounted) {
                            final post = Post.fromFirestore(postDoc);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreadScreen(post: post),
                              ),
                            );
                          } else if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('This rant seems to have vanished into the void.'))
                             );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open post: $e'))
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.15), blurRadius: 20)], // pastelPurple
            ),
            child: const Text('📭', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 24),
          const Text('All caught up!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D263B))), // textPrimary
          const SizedBox(height: 8),
          const Text('When your friends interact with your\nrants, you\'ll see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B5F80), height: 1.5)), // textSecondary
          const SizedBox(height: 32),
          const Text('(Go post something to get the conversation started!)',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B8EAD), fontStyle: FontStyle.italic)), // textTertiary
        ],
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION TILE WIDGET
// ============================================================================
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificationTile({required this.data, required this.onTap});

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  ({IconData icon, Color color, Color bgColor}) _getStyle(String type) {
    switch (type) {
      case 'like':
        return (icon: Icons.favorite_rounded, color: const Color(0xFFFF5277), bgColor: const Color(0xFFFF5277).withOpacity(0.15)); 
      case 'comment':
        return (icon: Icons.chat_bubble_rounded, color: const Color(0xFF98C4D4), bgColor: const Color(0xFF98C4D4).withOpacity(0.15)); 
      case 'repost':
        return (icon: Icons.repeat_rounded, color: const Color(0xFF4DB6AC), bgColor: const Color(0xFF4DB6AC).withOpacity(0.15)); 
      case 'reaction':
        return (icon: Icons.add_reaction_rounded, color: const Color(0xFFFFD6A5), bgColor: const Color(0xFFFFD6A5).withOpacity(0.15)); 
      case 'circle_join':
        return (icon: Icons.key_rounded, color: const Color(0xFFA898D4), bgColor: const Color(0xFFA898D4).withOpacity(0.15)); 
      default:
        return (icon: Icons.notifications_rounded, color: const Color(0xFF9B8EAD), bgColor: const Color(0xFFF7F5FA)); 
    }
  }

  Color _getAvatarColor(int index) {
    const colors = [
      Color(0xFFFFB3C8), // pink
      Color(0xFFADD4EC), // blue
      Color(0xFFCFB8E8), // purple
      Color(0xFFB8EDD6), // mint
      Color(0xFFFFD6A5), // orange
      Color(0xFFFFF0A0), // yellow
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bool isRead = data['isRead'] ?? true;
    final String actorName = data['actorName'] ?? '@Someone';
    final String initial = data['actorInitial'] ?? '?';
    final int colorIdx = data['actorColorIndex'] ?? 0;
    final String message = data['message'] ?? ' interacted with you.';
    final String type = data['type'] ?? 'unknown';
    final Timestamp? time = data['createdAt'] as Timestamp?;

    final style = _getStyle(type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFA898D4).withOpacity(0.05), // pastelPurple
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? const Color(0xFFE8E4EE) : const Color(0xFFA898D4).withOpacity(0.3), // divider, pastelPurple
            width: isRead ? 1.0 : 1.5,
          ),
          boxShadow: isRead ? [] : [
            BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)) 
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _getAvatarColor(colorIdx),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initial, 
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: style.bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(style.icon, size: 12, color: style.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14.5, color: Color(0xFF2D263B), height: 1.4, fontFamily: 'Nunito'), // textPrimary
                      children: [
                        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: message, style: TextStyle(
                          color: isRead ? const Color(0xFF6B5F80) : const Color(0xFF2D263B), 
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_timeAgo(time), 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: isRead ? const Color(0xFF9B8EAD) : const Color(0xFFA898D4), 
                    )),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFA898D4), // pastelPurple
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}