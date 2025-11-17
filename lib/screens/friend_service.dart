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

  // -------------------------------------------
  // Gửi lời mời
  // -------------------------------------------
  Future<void> sendFriendRequest(String targetId) async {
    final reqId = "${currentUserId}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).set({
      "senderId": currentUserId,
      "receiverId": targetId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Gửi thông báo
    await _firestore.collection("notifications").add({
      "userId": targetId,
      "senderId": currentUserId,
      "senderName": _auth.currentUser!.email ?? "",
      "type": "friend_request",
      "accepted": false,
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });
  }

  // -------------------------------------------
  // Hủy lời mời
  // -------------------------------------------
  Future<void> cancelFriendRequest(String targetId) async {
    final reqId = "${currentUserId}_$targetId";

    // Update trạng thái → cancelled
    await _firestore.collection("friend_requests").doc(reqId).update({
      "status": "cancelled",
      "updatedAt": FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // -------------------------------------------
    // XÓA THÔNG BÁO CỦA B (REAL-TIME)
    // -------------------------------------------
    final q = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: targetId)
        .where("senderId", isEqualTo: currentUserId)
        .where("type", isEqualTo: "friend_request")
        .get();

    for (var d in q.docs) {
      await d.reference.delete();
    }
  }

  // -------------------------------------------
  // Hủy kết bạn
  // -------------------------------------------
  Future<void> unfriend(String targetId) async {
    await _firestore.collection("users").doc(currentUserId).update({
      "friends": FieldValue.arrayRemove([targetId])
    });
    await _firestore.collection("users").doc(targetId).update({
      "friends": FieldValue.arrayRemove([currentUserId])
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final targetId = widget.targetUserId;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection("users").doc(targetId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();

        final friends = (userSnap.data?.data()?["friends"] as List?) ?? [];
        final isFriend = friends.contains(currentUserId);

        final req1 = "${currentUserId}_$targetId";
        final req2 = "${targetId}_$currentUserId";

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection("friend_requests")
              .where(FieldPath.documentId, whereIn: [req1, req2])
              .snapshots(),
          builder: (context, reqSnap) {
            if (!reqSnap.hasData) {
              return _defaultAddButton(targetId);
            }

            String? status;
            bool sentByMe = false;
            bool sentToMe = false;

            for (var doc in reqSnap.data!.docs) {
              final d = doc.data();

              final match = (d["senderId"] == currentUserId && d["receiverId"] == targetId) ||
                  (d["senderId"] == targetId && d["receiverId"] == currentUserId);

              if (match) {
                status = d["status"];
                sentByMe = d["senderId"] == currentUserId;
                sentToMe = d["receiverId"] == currentUserId;
              }
            }

            // -------------------------------------------
            // ALREADY FRIENDS
            // -------------------------------------------
            if (isFriend) {
              return Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      "Bạn bè",
                      Icons.person,
                      Colors.grey.shade300!,
                      Colors.black,
                          () async {
                        final ok = await _confirm("Hủy kết bạn", "Bạn chắc chắn muốn hủy?");
                        if (ok) unfriend(targetId);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildButton(
                      "Nhắn tin",
                      Icons.message,
                      const Color(0xFF1877F2),
                      Colors.white,
                          () {},
                    ),
                  ),
                ],
              );
            }

            // -------------------------------------------
            // PENDING
            // -------------------------------------------
            if (status == "pending") {
              if (sentToMe) {
                return _buildButton(
                  "Trả lời lời mời",
                  Icons.person_add_alt,
                  Colors.green,
                  Colors.white,
                      () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vào thông báo để xử lý.")),
                    );
                  },
                );
              }

              if (sentByMe) {
                return _buildButton(
                  "Chờ phản hồi",
                  Icons.hourglass_top,
                  Colors.grey.shade300!,
                  Colors.black,
                      () async {
                    final ok = await _confirm("Hủy lời mời", "Bạn có muốn hủy lời mời?");
                    if (ok) cancelFriendRequest(targetId);
                  },
                );
              }
            }

            // -------------------------------------------
            // CANCELLED REAL-TIME → SHOW ADD FRIEND
            // -------------------------------------------
            if (status == "cancelled") {
              return _defaultAddButton(targetId);
            }

            if (status == "declined") {
              return _defaultAddButton(targetId);
            }

            return _defaultAddButton(targetId);
          },
        );
      },
    );
  }

  Widget _defaultAddButton(String targetId) {
    return _buildButton(
      "Thêm bạn bè",
      Icons.person_add_alt_1,
      const Color(0xFF1877F2),
      Colors.white,
          () => sendFriendRequest(targetId),
    );
  }

  Widget _buildButton(String label, IconData icon, Color bg, Color textColor, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
