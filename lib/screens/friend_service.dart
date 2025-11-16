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

  // =============================
  // SEND REQUEST (pending)
  // =============================
  Future<void> sendFriendRequest(String targetId) async {
    final reqId = "${currentUserId}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).set({
      "senderId": currentUserId,
      "receiverId": targetId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  // =============================
  // CANCEL REQUEST (sender)
  // =============================
  Future<void> cancelFriendRequest(String targetId) async {
    final reqId = "${currentUserId}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).update({
      "status": "cancelled"
    }).catchError((_) {});
  }

  // =============================
  // UNFRIEND
  // =============================
  Future<void> unfriend(String targetId) async {
    await _firestore.collection("users").doc(currentUserId).update({
      "friends": FieldValue.arrayRemove([targetId])
    });

    await _firestore.collection("users").doc(targetId).update({
      "friends": FieldValue.arrayRemove([currentUserId])
    });
  }

  // =============================
  // BUILD UI
  // =============================
  @override
  Widget build(BuildContext context) {
    final targetId = widget.targetUserId;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("users").doc(targetId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();

        final friends = (userSnap.data!.get("friends") as List?) ?? [];
        final isFriend = friends.contains(currentUserId);

        // =============================
        // STREAM REQUEST 2 CHIỀU
        // =============================
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection("friend_requests")
              .where(
            Filter.or(
              Filter("senderId", isEqualTo: currentUserId),
              Filter("receiverId", isEqualTo: currentUserId),
              Filter("senderId", isEqualTo: targetId),
              Filter("receiverId", isEqualTo: targetId),
            ),
          )
              .snapshots(),
          builder: (context, reqSnap) {
            if (!reqSnap.hasData) return const SizedBox();

            String? status;
            bool sentByMe = false;
            bool sentToMe = false;

            for (var doc in reqSnap.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;

              final match = (d["senderId"] == currentUserId &&
                  d["receiverId"] == targetId) ||
                  (d["senderId"] == targetId &&
                      d["receiverId"] == currentUserId);

              if (match) {
                status = d["status"];
                sentByMe = d["senderId"] == currentUserId;
                sentToMe = d["receiverId"] == currentUserId;
              }
            }

            // =============================
            // FRIEND
            // =============================
            if (isFriend) {
              return _buildButton(
                label: "Bạn bè",
                icon: Icons.person,
                color: Colors.grey.shade300!,
                textColor: Colors.black,
                onPressed: () async {
                  final ok = await _confirm("Hủy kết bạn", "Bạn chắc muốn hủy kết bạn?");
                  if (ok) unfriend(targetId);
                },
              );
            }

            // =============================
            // PENDING
            // =============================
            if (status == "pending") {
              if (sentToMe) {
                // Người kia gửi cho mình
                return _buildButton(
                  label: "Trả lời lời mời",
                  icon: Icons.person_add_alt,
                  color: Colors.green,
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Hãy vào thông báo để xử lý.")),
                    );
                  },
                );
              }

              if (sentByMe) {
                // Mình gửi
                return _buildButton(
                  label: "Chờ phản hồi",
                  icon: Icons.hourglass_top,
                  color: Colors.grey.shade300!,
                  textColor: Colors.black,
                  onPressed: () async {
                    final ok =
                    await _confirm("Hủy lời mời", "Bạn muốn hủy lời mời kết bạn?");
                    if (ok) cancelFriendRequest(targetId);
                  },
                );
              }
            }

            // =============================
            // DECLINED / CANCELLED
            // =============================
            if (status == "declined" || status == "cancelled") {
              return _buildButton(
                label: "Thêm bạn bè",
                icon: Icons.person_add_alt_1,
                color: const Color(0xFF1877F2),
                textColor: Colors.white,
                onPressed: () => sendFriendRequest(targetId),
              );
            }

            // =============================
            // DEFAULT
            // =============================
            return _buildButton(
              label: "Thêm bạn bè",
              icon: Icons.person_add_alt_1,
              color: const Color(0xFF1877F2),
              textColor: Colors.white,
              onPressed: () => sendFriendRequest(targetId),
            );
          },
        );
      },
    );
  }

  // =============================
  // BUTTON WIDGET
  // =============================
  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  // =============================
  // CONFIRM DIALOG
  // =============================
  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Không")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Có")),
        ],
      ),
    ) ??
        false;
  }
}
