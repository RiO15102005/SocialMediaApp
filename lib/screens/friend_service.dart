// lib/screens/friend_button.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendButton extends StatefulWidget {
  final String targetUserId;
  const FriendButton({super.key, required this.targetUserId});

  @override
  State<FriendButton> createState() => _FriendButtonState();
}

class _FriendButtonState extends State<FriendButton> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;
  String get currentUserEmail => _auth.currentUser!.email ?? '';

  /// Gửi lời mời
  Future<void> sendFriendRequest(String targetUserId) async {
    await _firestore.collection('friend_requests').add({
      'senderId': currentUserId,
      'senderEmail': currentUserEmail,
      'receiverId': targetUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Hủy lời mời
  Future<void> cancelFriendRequest(String targetUserId) async {
    final requests = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in requests.docs) {
      await doc.reference.delete();
    }
  }

  /// Hủy kết bạn
  Future<void> unfriend(String targetUserId) async {
    final users = _firestore.collection('users');
    await users.doc(currentUserId).update({
      'friends': FieldValue.arrayRemove([targetUserId]),
    });
    await users.doc(targetUserId).update({
      'friends': FieldValue.arrayRemove([currentUserId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetUserId = widget.targetUserId;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(targetUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox();
        final friends = (userSnapshot.data?.get('friends') as List?) ?? [];
        final isFriend = friends.contains(currentUserId);

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('friend_requests')
              .where('senderId', isEqualTo: currentUserId)
              .where('receiverId', isEqualTo: targetUserId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, reqSnapshot) {
            final hasSentRequest = reqSnapshot.data?.docs.isNotEmpty ?? false;

            if (isFriend) {
              return _buildButton(
                label: 'Nhắn tin',
                icon: Icons.message,
                color: const Color(0xFF1877F2),
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đi tới màn hình nhắn tin...')),
                  );
                },
              );
            }

            if (hasSentRequest) {
              return _buildButton(
                label: 'Đã gửi lời mời',
                icon: Icons.hourglass_top,
                color: Colors.grey[300]!,
                textColor: Colors.black,
                onPressed: () async {
                  final confirm = await _showConfirmDialog(
                    context,
                    'Hủy lời mời kết bạn',
                    'Bạn có chắc muốn hủy lời mời kết bạn này không?',
                  );
                  if (confirm) {
                    await cancelFriendRequest(targetUserId);
                  }
                },
              );
            }

            return _buildButton(
              label: 'Thêm bạn bè',
              icon: Icons.person_add_alt_1,
              color: const Color(0xFF1877F2),
              textColor: Colors.white,
              onPressed: () async {
                await sendFriendRequest(targetUserId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi lời mời kết bạn!')),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(icon, color: textColor),
          label: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(
      BuildContext context, String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Có'),
          ),
        ],
      ),
    ) ??
        false;
  }
}
