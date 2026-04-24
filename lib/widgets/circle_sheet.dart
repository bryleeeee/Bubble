import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/notifications_screen.dart'; // Adjust this path if needed!

// ============================================================================
// CIRCLE SHEET (100% Standalone - No BT Imports Needed)
// ============================================================================
class CircleSheet extends StatefulWidget {
  final String current;
  final Function(String) onSelect;

  const CircleSheet({Key? key, required this.current, required this.onSelect})
      : super(key: key);

  @override
  State<CircleSheet> createState() => _CircleSheetState();
}

class _CircleSheetState extends State<CircleSheet>
    with SingleTickerProviderStateMixin {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Shimmer for the sheet header
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── CREATE ───────────────────────────────────────────────────────────────
  Future<void> _createCircle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController();
    final circleName = await _showBubbleInputDialog(
      title: 'New Circle',
      subtitle: 'Give your bubble a name',
      hint: 'e.g. The Void, Besties…',
      controller: nameCtrl,
      confirmLabel: 'Create',
      confirmColor: const Color(0xFFA898D4), // pastelPurple
      maxLength: 15,
    );
    if (circleName == null || circleName.isEmpty) return;

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd  = math.Random();
    final code = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    HapticFeedback.mediumImpact();
    await _firestore.collection('circles').add({
      'name': circleName,
      'inviteCode': code,
      'ownerId': user.uid,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _showCodeDialog(code, isNew: true, circleName: circleName);
  }

  // ── JOIN ─────────────────────────────────────────────────────────────────
  Future<void> _joinCircle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final codeCtrl   = TextEditingController();
    bool  isLoading  = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => _BubbleDialog(
          title: 'Join a Circle',
          titleEmoji: '🔑',
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Text(
                'Enter the 6-character code from your friend.',
                style: TextStyle(color: Color(0xFF6B5F80), fontSize: 13.5, height: 1.4), // textSecondary
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _BubbleTextField(
                controller: codeCtrl,
                hint: 'A B C 1 2 3',
                maxLength: 6,
                capitalize: TextCapitalization.characters,
                errorText: errorMsg,
                centered: true,
                letterSpacing: 6,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _BubbleOutlineButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BubbleGradientButton(
                      label: isLoading ? null : 'Join',
                      loading: isLoading,
                      colors: const [Color(0xFF98C4D4), Color(0xFFA898D4)], // pastelBlue, pastelPurple
                      onTap: () async {
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (code.length != 6) {
                          setD(() => errorMsg = 'Code must be 6 characters');
                          return;
                        }
                        setD(() { isLoading = true; errorMsg = null; });
                        
                        final q = await _firestore.collection('circles')
                            .where('inviteCode', isEqualTo: code).limit(1).get();
                        
                        if (q.docs.isEmpty) {
                          setD(() { isLoading = false; errorMsg = 'Invalid code — circle not found'; });
                          return;
                        }
                        
                        final circleDoc = q.docs.first;
                        final circleData = circleDoc.data();
                        
                        // 1. Add the user to the circle
                        await circleDoc.reference.update({
                          'members': FieldValue.arrayUnion([user.uid])
                        });

                        // ── 2. SEND NOTIFICATION TO THE OWNER! ──
                        final ownerId = circleData['ownerId'] as String?;
                        final circleName = circleData['name'] ?? 'your circle';
                        
                        // Don't notify the owner if they somehow use their own code
                        if (ownerId != null && ownerId != user.uid) {
                          final myName = user.displayName != null && user.displayName!.isNotEmpty 
                              ? '@${user.displayName}' 
                              : '@Someone';
                              
                          try {
                            await NotificationService.sendRealNotification(
                              targetUserId: ownerId,
                              type: 'circle_join',
                              actorName: myName,
                              message: ' joined your circle "$circleName".',
                              referenceId: null, // Since it's a circle, not a post, we don't need to link to a thread
                            );
                          } catch (e) {
                            debugPrint('Failed to send join notification: $e');
                          }
                        }
                        
                        HapticFeedback.lightImpact();
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Joined $circleName! 🫧'))
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── RENAME ───────────────────────────────────────────────────────────────
  Future<void> _renameCircle(String docId, String currentName) async {
    final nameCtrl = TextEditingController(text: currentName);
    final newName  = await _showBubbleInputDialog(
      title: 'Rename Circle',
      subtitle: null,
      hint: currentName,
      controller: nameCtrl,
      confirmLabel: 'Save',
      confirmColor: const Color(0xFF98C4D4), // pastelBlue
      maxLength: 15,
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    
    await _firestore.collection('circles').doc(docId).update({'name': newName});
    if (widget.current == currentName && mounted) widget.onSelect(newName);
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  Future<void> _deleteCircle(String docId, String circleName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _BubbleDialog(
        title: 'Delete "$circleName"?',
        titleEmoji: '💥',
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Text(
              'All members will lose access. This can\'t be undone.',
              style: TextStyle(color: Color(0xFF6B5F80), fontSize: 13.5, height: 1.4), // textSecondary
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BubbleOutlineButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BubbleGradientButton(
                    label: 'Delete',
                    colors: const [Color(0xFFFF5277), Color(0xFFFF9DAF)], // heartRed, light pink
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    
    if (ok == true) {
      await _firestore.collection('circles').doc(docId).delete();
      if (widget.current == circleName && mounted) widget.onSelect('Nom');
    }
  }

  // ── CODE DIALOG ──────────────────────────────────────────────────────────
  void _showCodeDialog(String code, {bool isNew = false, String circleName = ''}) {
    showDialog(
      context: context,
      builder: (_) => _BubbleDialog(
        title: isNew ? 'Circle Created!' : 'Invite Code',
        titleEmoji: isNew ? '🎉' : '🔑',
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (isNew) ...[
              Text(
                '"$circleName" is live. Share the code below with your people.',
                style: const TextStyle(color: Color(0xFF6B5F80), fontSize: 13.5, height: 1.4), // textSecondary
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Text(
                'Share this code with friends to invite them.',
                style: TextStyle(color: Color(0xFF6B5F80), fontSize: 13.5, height: 1.4), // textSecondary
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            // Code card
            _CodeCard(code: code),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BubbleOutlineButton(
                    label: 'Done',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BubbleGradientButton(
                    label: 'Copy Code',
                    colors: const [Color(0xFFD498B2), Color(0xFFA898D4)], // pastelPink, pastelPurple
                    icon: Icons.copy_rounded,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied! 🫧'))
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── INPUT DIALOG HELPER ───────────────────────────────────────────────────
  Future<String?> _showBubbleInputDialog({
    required String title,
    required String? subtitle,
    required String hint,
    required TextEditingController controller,
    required String confirmLabel,
    required Color confirmColor,
    required int maxLength,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _BubbleDialog(
        title: title,
        titleEmoji: '✏️',
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6B5F80), fontSize: 13.5), // textSecondary
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
            ],
            _BubbleTextField(
              controller: controller,
              hint: hint,
              maxLength: maxLength,
              autofocus: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BubbleOutlineButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BubbleGradientButton(
                    label: confirmLabel,
                    colors: [const Color(0xFFD498B2), confirmColor], // pastelPink
                    onTap: () => Navigator.pop(context, controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── MAIN SHEET BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5FA), // bg
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // ── Handle ─────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E4EE), // divider
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header with shimmer ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3.5, height: 22,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF98C4D4), Color(0xFFA898D4)]), // pastelBlue, pastelPurple
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Your Circles',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D263B)), // textPrimary
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Switch where your rants land',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF6B5F80), fontWeight: FontWeight.w500), // textSecondary
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Circle list ─────────────────────────────────────────────────────
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('circles')
                  .where('members', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(color: Color(0xFFA898D4), strokeWidth: 2.5), // pastelPurple
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white, // card
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E4EE), width: 1.2), // divider
                      ),
                      child: const Column(
                        children: [
                          Text('🫧', style: TextStyle(fontSize: 36)),
                          SizedBox(height: 10),
                          Text(
                            'No circles yet',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D263B)), // textPrimary
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create one or join a friend\'s circle.',
                            style: TextStyle(color: Color(0xFF6B5F80), fontSize: 13), // textSecondary
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: docs.map((doc) {
                      final data     = doc.data() as Map<String, dynamic>;
                      final name     = data['name'] ?? 'Unknown';
                      final code     = data['inviteCode'] ?? '';
                      final ownerId  = data['ownerId'] as String?;
                      final isOwner  = ownerId == user.uid;
                      final selected = widget.current == name;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CircleItem(
                          name: name,
                          isSelected: selected,
                          isOwner: isOwner,
                          memberCount: (data['members'] as List?)?.length ?? 1,
                          onTap: () {
                            widget.onSelect(name);
                            Navigator.pop(context);
                          },
                          onInvite: () => _showCodeDialog(code, circleName: name),
                          onRename: isOwner ? () => _renameCircle(doc.id, name) : null,
                          onDelete: isOwner ? () => _deleteCircle(doc.id, name) : null,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // ── Action buttons ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _BubbleOutlineButton(
                    label: 'Join Circle',
                    icon: Icons.key_rounded,
                    iconColor: const Color(0xFF98C4D4), // pastelBlue
                    textColor: const Color(0xFF98C4D4), // pastelBlue
                    borderColor: const Color(0xFF98C4D4).withOpacity(0.5), // pastelBlue
                    onTap: _joinCircle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BubbleGradientButton(
                    label: 'Create Circle',
                    icon: Icons.add_rounded,
                    colors: const [Color(0xFFD498B2), Color(0xFFA898D4)], // pastelPink, pastelPurple
                    onTap: _createCircle,
                  ),
                ),
              ],
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ============================================================================
// CIRCLE ITEM TILE
// ============================================================================
class _CircleItem extends StatelessWidget {
  final String name;
  final bool   isSelected, isOwner;
  final int    memberCount;
  final VoidCallback onTap;
  final VoidCallback onInvite;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _CircleItem({
    required this.name, required this.isSelected, required this.isOwner,
    required this.memberCount, required this.onTap, required this.onInvite,
    this.onRename, this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA898D4).withOpacity(0.10) : Colors.white, // pastelPurple, card
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFA898D4).withOpacity(0.40) : const Color(0xFFE8E4EE), // pastelPurple, divider
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Row(
          children: [
            // Circle indicator dot
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSelected
                      ? [const Color(0xFFA898D4).withOpacity(0.9), const Color(0xFF98C4D4).withOpacity(0.7)] // pastelPurple, pastelBlue
                      : [const Color(0xFFE8E4EE), const Color(0xFFE8E4EE).withOpacity(0.6)], // divider
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : const Color(0xFF9B8EAD), // textTertiary
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Name + member count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFFA898D4) : const Color(0xFF2D263B), // pastelPurple, textPrimary
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$memberCount ${memberCount == 1 ? 'member' : 'members'}${isOwner ? ' · owner' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF9B8EAD), fontWeight: FontWeight.w500), // textTertiary
                  ),
                ],
              ),
            ),

            // Selected checkmark
            if (isSelected) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFA898D4), shape: BoxShape.circle), // pastelPurple
                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 4),
            ],

            // Options menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded,
                color: isSelected ? const Color(0xFFA898D4) : const Color(0xFF9B8EAD), size: 20), // pastelPurple, textTertiary
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white, // card
              elevation: 8,
              onSelected: (v) {
                if (v == 'invite') onInvite();
                if (v == 'rename') onRename?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                _popItem('invite', Icons.key_rounded, 'Invite Code', const Color(0xFF98C4D4)), // pastelBlue
                if (isOwner) ...[
                  const PopupMenuDivider(),
                  _popItem('rename', Icons.edit_rounded, 'Rename', const Color(0xFF6B5F80)), // textSecondary
                  _popItem('delete', Icons.delete_outline_rounded, 'Delete', const Color(0xFFFF5277)), // heartRed
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popItem(String value, IconData icon, String label, Color color) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              label, 
              style: TextStyle(
                color: color == const Color(0xFFFF5277) ? const Color(0xFFFF5277) : const Color(0xFF2D263B), // heartRed : textPrimary
                fontWeight: FontWeight.w600, fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

// ============================================================================
// CODE CARD  (animated shimmer code display)
// ============================================================================
class _CodeCard extends StatefulWidget {
  final String code;
  const _CodeCard({required this.code});
  @override State<_CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends State<_CodeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override 
  void initState() { 
    super.initState(); 
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); 
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
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-2.0 + _ctrl.value * 4.0, -0.5),
            end:   Alignment(-1.4 + _ctrl.value * 4.0,  0.5),
            colors: [
              const Color(0xFFA898D4).withOpacity(0.12), // pastelPurple
              const Color(0xFF98C4D4).withOpacity(0.22), // pastelBlue
              const Color(0xFFD498B2).withOpacity(0.14), // pastelPink
              const Color(0xFFA898D4).withOpacity(0.12), // pastelPurple
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA898D4).withOpacity(0.35), width: 1.5), // pastelPurple
        ),
        child: Column(
          children: [
            const Text('🔑', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              widget.code.split('').join('  '),   // spaced for readability
              style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: Color(0xFF2D263B), letterSpacing: 2, // textPrimary
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '6-character invite code',
              style: TextStyle(fontSize: 11.5, color: const Color(0xFF9B8EAD).withOpacity(0.8)), // textTertiary
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED DIALOG CHROME
// ============================================================================
class _BubbleDialog extends StatelessWidget {
  final String title, titleEmoji;
  final Widget child;

  const _BubbleDialog({required this.title, required this.titleEmoji, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white, // card
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: const Color(0xFFA898D4).withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8)), // pastelPurple
            BoxShadow(color: Colors.black.withOpacity(0.05),    blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFA898D4).withOpacity(0.12), const Color(0xFFD498B2).withOpacity(0.08)], // pastelPurple, pastelPink
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Text(titleEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    title, 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF2D263B)), // textPrimary
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED INPUT FIELD
// ============================================================================
class _BubbleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final bool autofocus;
  final bool centered;
  final double? letterSpacing, fontSize;
  final FontWeight? fontWeight;
  final String? errorText;
  final TextCapitalization capitalize;

  const _BubbleTextField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.autofocus = false,
    this.centered = false,
    this.letterSpacing,
    this.fontSize,
    this.fontWeight,
    this.errorText,
    this.capitalize = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5FA), // bg
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null ? const Color(0xFFFF5277).withOpacity(0.6) : const Color(0xFFE8E4EE), // heartRed, divider
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLength: maxLength,
            textCapitalization: capitalize,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: fontSize ?? 15,
              fontWeight: fontWeight ?? FontWeight.w600,
              color: const Color(0xFF2D263B), // textPrimary
              letterSpacing: letterSpacing,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: const Color(0xFF9B8EAD).withOpacity(0.7), fontWeight: FontWeight.w400), // textTertiary
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              counterStyle: const TextStyle(color: Color(0xFF9B8EAD), fontSize: 11), // textTertiary
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFFF5277)), // heartRed
              const SizedBox(width: 4),
              Text(errorText!, style: const TextStyle(color: Color(0xFFFF5277), fontSize: 12, fontWeight: FontWeight.w600)), // heartRed
            ],
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// SHARED BUTTONS
// ============================================================================
class _BubbleGradientButton extends StatelessWidget {
  final String? label;
  final List<Color> colors;
  final VoidCallback onTap;
  final IconData? icon;
  final bool loading;

  const _BubbleGradientButton({
    required this.colors, required this.onTap,
    this.label, this.icon, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18, height: 18, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 16), 
                      const SizedBox(width: 5),
                    ],
                    if (label != null) 
                      Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BubbleOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color iconColor;
  final Color textColor;
  final Color? borderColor;

  const _BubbleOutlineButton({
    required this.label, required this.onTap,
    this.icon,
    this.iconColor = const Color(0xFF6B5F80), // textSecondary
    this.textColor = const Color(0xFF6B5F80), // textSecondary
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5FA), // bg
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: borderColor ?? const Color(0xFFE8E4EE), width: 1.5), // divider
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 15), 
                const SizedBox(width: 5),
              ],
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}