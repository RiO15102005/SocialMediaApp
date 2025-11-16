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

  // ==========================================
  // Tạo notification
  // ==========================================
  Future<void> _createNotification({
    required String receiverId,
    required String type,
  }) async {
    final me = await _firestore.collection("users").doc(currentUid).get();
    final senderName = me["displayName"] ?? currentEmail;

    await _firestore.collection("notifications").add({
      "userId": receiverId,
      "senderId": currentUid,
      "senderName": senderName,
      "type": type,
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });
  }

  // ==========================================
  // Gửi lời mời kết bạn
  // ==========================================
  Future<void> sendRequest(String targetId) async {
    final reqId = "${currentUid}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).set({
      "senderId": currentUid,
      "receiverId": targetId,
      "status": "pending",
      "timestamp": FieldValue.serverTimestamp(),
    });

    await _createNotification(
        receiverId: targetId, type: "friend_request");
  }

  // ==========================================
  // Hủy lời mời (update status = cancelled)
  // ==========================================
  Future<void> cancelRequest(String targetId) async {
    final reqId = "${currentUid}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).update({
      "status": "cancelled",
    }).catchError((_) {});
  }

  // ==========================================
  // Unfriend
  // ==========================================
  Future<void> unfriend(String targetId) async {
    await _firestore.collection("users").doc(currentUid).update({
      "friends": FieldValue.arrayRemove([targetId])
    });

    await _firestore.collection("users").doc(targetId).update({
      "friends": FieldValue.arrayRemove([currentUid])
    });
  }

  // ==========================================
  // Confirm dialog
  // ==========================================
  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Không")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Có")),
        ],
      ),
    ) ??
        false;
  }

  // ==========================================
  // UI
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final targetId = widget.targetUserId;

    if (widget.isMyProfile) {
      return _btn(
        "Chỉnh sửa hồ sơ",
        Icons.edit,
        Colors.white,
        Colors.black,
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          );
        },
      );
    }

    // ============================
    // Stream users
    // ============================
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("users").doc(targetId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();

        final friends = (userSnap.data!.get("friends") as List?) ?? [];
        final isFriend = friends.contains(currentUid);

        // ============================
        // Stream friend requests 2 chiều
        // ============================
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection("friend_requests")
              .where("senderId", whereIn: [currentUid, targetId])
              .where("receiverId", whereIn: [currentUid, targetId])
              .snapshots(),
          builder: (context, reqSnap) {
            if (!reqSnap.hasData) return const SizedBox();

            String? status;
            bool sentByMe = false;
            bool sentToMe = false;

            for (var d in reqSnap.data!.docs) {
              final data = d.data() as Map<String, dynamic>;

              if ((data["senderId"] == currentUid &&
                  data["receiverId"] == targetId) ||
                  (data["senderId"] == targetId &&
                      data["receiverId"] == currentUid)) {
                status = data["status"];
                sentByMe = data["senderId"] == currentUid;
                sentToMe = data["receiverId"] == currentUid;
              }
            }

            // ==========================================
            // ALREADY FRIENDS
            // ==========================================
            if (isFriend) {
              return Row(
                children: [
                  Expanded(
                    child: _btn(
                      "Bạn bè",
                      Icons.person,
                      Colors.grey.shade300!,
                      Colors.black,
                          () async {
                        final ok = await _confirm("Hủy kết bạn",
                            "Bạn chắc chắn muốn hủy kết bạn?");
                        if (ok) unfriend(targetId);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _btn(
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

            // ==========================================
            // REQUEST PENDING
            // ==========================================
            if (status == "pending") {
              if (sentToMe) {
                return _btn(
                  "Trả lời lời mời",
                  Icons.person_add,
                  Colors.orange,
                  Colors.black,
                      () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Vào thông báo để xử lý lời mời.")),
                    );
                  },
                );
              }

              if (sentByMe) {
                return _btn(
                  "Chờ phản hồi",
                  Icons.hourglass_top,
                  Colors.grey.shade300!,
                  Colors.black,
                      () async {
                    final ok = await _confirm(
                        "Hủy lời mời", "Bạn muốn hủy lời mời không?");
                    if (ok) cancelRequest(targetId);
                  },
                );
              }
            }

            // ==========================================
            // REQUEST DECLINED / CANCELLED → ADD FRIEND
            // ==========================================
            if (status == "declined" || status == "cancelled") {
              return _btn(
                "Thêm bạn bè",
                Icons.person_add_alt_1,
                const Color(0xFF1877F2),
                Colors.white,
                    () => sendRequest(targetId),
              );
            }

            // ==========================================
            // DEFAULT
            // ==========================================
            return _btn(
              "Thêm bạn bè",
              Icons.person_add_alt_1,
              const Color(0xFF1877F2),
              Colors.white,
                  () => sendRequest(targetId),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // BTN builder
  // ==========================================
  Widget _btn(String label, IconData icon, Color bg, Color textColor,
      VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style:
          TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
