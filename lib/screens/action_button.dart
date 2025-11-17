// lib/screens/action_button.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';

class ActionButton extends StatefulWidget {
  final bool isMyProfile;
  final String targetUserId;

  const ActionButton({
    super.key,
    required this.isMyProfile,
    required this.targetUserId,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser!.uid;
  String get currentEmail => _auth.currentUser!.email ?? "";

  // Create a notification (simple)
  Future<void> _createNotification({
    required String receiverId,
    required String type,
    String? senderName,
  }) async {
    final name = senderName ??
        (await _firestore.collection("users").doc(currentUid).get())
            .data()?["displayName"] ??
        currentEmail;

    await _firestore.collection("notifications").add({
      "userId": receiverId, // who will see this notification
      "senderId": currentUid,
      "senderName": name,
      "type": type,
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });
  }

  // send request (doc id = sender_receiver)
  Future<void> sendRequest(String targetId) async {
    final reqId = "${currentUid}_$targetId";
    await _firestore.collection("friend_requests").doc(reqId).set({
      "senderId": currentUid,
      "receiverId": targetId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });
    await _createNotification(receiverId: targetId, type: "friend_request");
  }

  // cancel request (sender cancels) -> set status cancelled
  Future<void> cancelRequest(String targetId) async {
    final reqId = "${currentUid}_$targetId";
    await _firestore.collection("friend_requests").doc(reqId).update({
      "status": "cancelled",
      "updatedAt": FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // unfriend (remove both sides)
  Future<void> unfriend(String targetId) async {
    await _firestore.collection("users").doc(currentUid).update({
      "friends": FieldValue.arrayRemove([targetId])
    });
    await _firestore.collection("users").doc(targetId).update({
      "friends": FieldValue.arrayRemove([currentUid])
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

    if (widget.isMyProfile) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          },
          icon: const Icon(Icons.edit, color: Colors.black),
          label: const Text("Chỉnh sửa hồ sơ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      );
    }

    // watch target user's friend list (to know if already friends)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection("users").doc(targetId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();
        final friends = (userSnap.data?.data()?["friends"] as List?) ?? [];
        final isFriend = friends.contains(currentUid);

        // Prepare two possible request doc ids
        final reqId1 = "${currentUid}_$targetId";
        final reqId2 = "${targetId}_$currentUid";

        // Listen to friend_requests documents for both possible ids
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection("friend_requests")
              .where(FieldPath.documentId, whereIn: [reqId1, reqId2])
              .snapshots(),
          builder: (context, reqSnap) {
            if (!reqSnap.hasData) {
              // No docs found yet -> default button
              if (isFriend) {
                // already friend
                return Row(
                  children: [
                    Expanded(
                      child: _btn("Bạn bè", Icons.person, Colors.grey.shade300!, Colors.black, () async {
                        final ok = await _confirm("Hủy kết bạn", "Bạn chắc chắn muốn hủy kết bạn?");
                        if (ok) unfriend(targetId);
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _btn("Nhắn tin", Icons.message, const Color(0xFF1877F2), Colors.white, () {})),
                  ],
                );
              }
              return _btn("Thêm bạn bè", Icons.person_add_alt_1, const Color(0xFF1877F2), Colors.white, () => sendRequest(targetId));
            }

            // Determine status from returned docs
            String? status;
            bool sentByMe = false;
            bool sentToMe = false;

            for (var doc in reqSnap.data!.docs) {
              final id = doc.id;
              final d = doc.data();
              if (id == reqId1 || id == reqId2) {
                status = d["status"] as String?;
                sentByMe = d["senderId"] == currentUid;
                sentToMe = d["receiverId"] == currentUid;
                break;
              }
            }

            if (isFriend) {
              // already friend
              return Row(
                children: [
                  Expanded(
                    child: _btn("Bạn bè", Icons.person, Colors.grey.shade300!, Colors.black, () async {
                      final ok = await _confirm("Hủy kết bạn", "Bạn chắc chắn muốn hủy kết bạn?");
                      if (ok) unfriend(targetId);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("Nhắn tin", Icons.message, const Color(0xFF1877F2), Colors.white, () {})),
                ],
              );
            }

            // pending
            if (status == "pending") {
              if (sentToMe) {
                // they sent to me -> receiver view
                return _btn("Trả lời lời mời", Icons.person_add, Colors.orange.shade300!, Colors.black, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng vào Thông báo để xử lý lời mời.")));
                });
              }

              if (sentByMe) {
                // I sent -> can cancel
                return _btn("Chờ phản hồi", Icons.hourglass_top, Colors.grey.shade300!, Colors.black, () async {
                  final ok = await _confirm("Hủy lời mời", "Bạn có muốn hủy lời mời không?");
                  if (ok) {
                    await cancelRequest(targetId);
                    setState(() {});
                  }
                });
              }
            }

            // declined or cancelled -> show add friend
            if (status == "declined" || status == "cancelled") {
              return _btn("Thêm bạn bè", Icons.person_add_alt_1, const Color(0xFF1877F2), Colors.white, () => sendRequest(targetId));
            }

            // default: show add friend
            return _btn("Thêm bạn bè", Icons.person_add_alt_1, const Color(0xFF1877F2), Colors.white, () => sendRequest(targetId));
          },
        );
      },
    );
  }

  Widget _btn(String label, IconData icon, Color bg, Color textColor, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }
}
