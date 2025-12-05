// lib/screens/action_button.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import 'chat_screen.dart'; // - Import quan trọng

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

  // 1. Tạo thông báo (notification)
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
      "userId": receiverId,
      "senderId": currentUid,
      "senderName": name,
      "type": type,
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });
  }

  // 2. Gửi lời mời kết bạn
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

  // 3. Hủy lời mời
  Future<void> cancelRequest(String targetId) async {
    final reqId = "${currentUid}_$targetId";

    await _firestore.collection("friend_requests").doc(reqId).update({
      "status": "cancelled",
      "updatedAt": FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // Xóa thông báo tương ứng
    final q = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: targetId)
        .where("senderId", isEqualTo: currentUid)
        .where("type", isEqualTo: "friend_request")
        .get();

    for (var d in q.docs) {
      await d.reference.delete();
    }
  }

  // 4. Hủy kết bạn
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Không"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Có"),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final targetId = widget.targetUserId;

    // Nếu là profile của mình -> Nút chỉnh sửa
    if (widget.isMyProfile) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          },
          icon: const Icon(Icons.edit, color: Colors.black),
          label: const Text("Chỉnh sửa hồ sơ",
              style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      );
    }

    // Lắng nghe dữ liệu user mục tiêu (để biết tên, avatar và danh sách bạn bè)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection("users").doc(targetId).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();

        // ⭐ Lấy thông tin user để chuyển sang màn hình chat
        final userData = userSnap.data!.data();
        final targetName = userData?['displayName'] ?? "Người dùng";
        final targetAvatar = userData?['photoURL'];

        final friends = (userData?["friends"] as List?) ?? [];
        final isFriend = friends.contains(currentUid);

        final reqId1 = "${currentUid}_$targetId";
        final reqId2 = "${targetId}_$currentUid";

        // Lắng nghe trạng thái lời mời kết bạn
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection("friend_requests")
              .where(FieldPath.documentId, whereIn: [reqId1, reqId2])
              .snapshots(),
          builder: (context, reqSnap) {

            // Hàm tiện ích để mở ChatScreen
            void openChat() {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    receiverId: targetId,
                    receiverName: targetName,
                    receiverAvatar: targetAvatar,
                  ),
                ),
              );
            }

            // Trường hợp 1: Chưa có dữ liệu request, nhưng đã là bạn bè
            if (!reqSnap.hasData) {
              if (isFriend) {
                return Row(
                  children: [
                    Expanded(
                      child: _btn("Bạn bè", Icons.person,
                          Colors.grey.shade300!, Colors.black, () async {
                            final ok = await _confirm(
                                "Hủy kết bạn", "Bạn chắc chắn muốn hủy kết bạn?");
                            if (ok) unfriend(targetId);
                          }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // ⭐ SỬA: Thay hàm rỗng bằng openChat
                      child: _btn("Nhắn tin", Icons.message,
                          const Color(0xFF1877F2), Colors.white, openChat),
                    ),
                  ],
                );
              }
              return _btn("Thêm bạn bè", Icons.person_add_alt_1,
                  const Color(0xFF1877F2), Colors.white,
                      () => sendRequest(targetId));
            }

            // Kiểm tra trạng thái request
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

            // Trường hợp 2: Đã là bạn bè (Dù request cũ thế nào)
            if (isFriend) {
              return Row(
                children: [
                  Expanded(
                    child: _btn("Bạn bè", Icons.person, Colors.grey.shade300!,
                        Colors.black, () async {
                          final ok = await _confirm(
                              "Hủy kết bạn", "Bạn chắc chắn muốn hủy kết bạn?");
                          if (ok) unfriend(targetId);
                        }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    // ⭐ SỬA: Thay hàm rỗng bằng openChat
                    child: _btn("Nhắn tin", Icons.message,
                        const Color(0xFF1877F2), Colors.white, openChat),
                  ),
                ],
              );
            }

            // Trường hợp 3: Đang chờ xử lý (Pending)
            if (status == "pending") {
              if (sentToMe) {
                return _btn(
                  "Trả lời lời mời",
                  Icons.person_add,
                  Colors.orange.shade300!,
                  Colors.black,
                      () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text("Vui lòng vào Thông báo để xử lý lời mời.")),
                    );
                  },
                );
              }

              if (sentByMe) {
                return _btn("Chờ phản hồi", Icons.hourglass_top,
                    Colors.grey.shade300!, Colors.black, () async {
                      final ok = await _confirm(
                          "Hủy lời mời", "Bạn có muốn hủy lời mời không?");
                      if (ok) {
                        await cancelRequest(targetId);
                        setState(() {});
                      }
                    });
              }
            }

            // Mặc định: Nút thêm bạn bè
            return _btn("Thêm bạn bè", Icons.person_add_alt_1,
                const Color(0xFF1877F2), Colors.white,
                    () => sendRequest(targetId));
          },
        );
      },
    );
  }

  // Widget nút bấm chung
  Widget _btn(String label, IconData icon, Color bg, Color textColor, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor),
        label: Text(label,
            style:
            TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
      ),
    );
  }
}