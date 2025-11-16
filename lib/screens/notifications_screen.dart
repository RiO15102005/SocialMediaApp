// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_model.dart';
import '../screens/comment_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _showOld = false;

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "post": return Icons.post_add;
      case "like": return Icons.favorite;
      case "comment": return Icons.chat;
      case "reply": return Icons.reply;
      case "friend_request": return Icons.person_add_alt_1;
      default: return Icons.notifications;
    }
  }

  String _messageForType(Map<String, dynamic> n) {
    final name = n["senderName"] ?? "Ai đó";

    if (n["type"] == "friend_request" && n["accepted"] == true) {
      return "Bạn đã chấp nhận lời mời kết bạn của $name.";
    }

    switch (n["type"]) {
      case "post": return "$name vừa đăng bài viết mới.";
      case "like": return "$name đã thích bài viết của bạn.";
      case "comment": return "$name đã bình luận bài viết của bạn.";
      case "reply": return "$name đã trả lời bình luận của bạn.";
      case "friend_request": return "$name đã gửi cho bạn lời mời kết bạn.";
      default: return "Bạn có thông báo mới.";
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection("notifications").doc(id).update({
      "isRead": true,
    });
  }

  Future<Post?> _fetchPost(String postId) async {
    final snap = await FirebaseFirestore.instance.collection("POST").doc(postId).get();
    if (!snap.exists) return null;
    return Post.fromFirestore(snap);
  }

  // =====================================================
  // HANDLE FRIEND REQUEST
  // =====================================================

  Future<void> _acceptFriendRequest(String senderId, String notiId) async {
    // Cập nhật friendlist
    await FirebaseFirestore.instance.collection("users").doc(currentUser!.uid).update({
      "friends": FieldValue.arrayUnion([senderId])
    });

    await FirebaseFirestore.instance.collection("users").doc(senderId).update({
      "friends": FieldValue.arrayUnion([currentUser!.uid])
    });

    // Cập nhật notification
    await FirebaseFirestore.instance.collection("notifications").doc(notiId).update({
      "accepted": true
    });

    // Update friend_request
    final pending = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("senderId", isEqualTo: senderId)
        .where("receiverId", isEqualTo: currentUser!.uid)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (pending.docs.isNotEmpty) {
      await pending.docs.first.reference.update({"status": "accepted"});
    }
  }

  // ⭐ FIX QUAN TRỌNG: CHỈ UPDATE status = declined (KHÔNG XOÁ)
  Future<void> _declineFriendRequest(String senderId, String notiId) async {
    // Xoá notification
    await FirebaseFirestore.instance.collection("notifications").doc(notiId).delete();

    // Tìm đúng request pending
    final pending = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("senderId", isEqualTo: senderId)
        .where("receiverId", isEqualTo: currentUser!.uid)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (pending.docs.isNotEmpty) {
      await pending.docs.first.reference.update({"status": "declined"});
    }
  }

  // Confirm delete notification
  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa thông báo"),
        content: const Text("Bạn có chắc muốn xóa thông báo này không?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Không")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Có")),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Thông báo")),
        body: const Center(child: Text("Vui lòng đăng nhập.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        backgroundColor: const Color(0xFF1877F2),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("notifications")
            .where("userId", isEqualTo: currentUser!.uid)
            .orderBy("timestamp", descending: true)
            .snapshots(),

        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!.docs;
          if (all.isEmpty) {
            return const Center(child: Text("Không có thông báo."));
          }

          final newest10 = all.take(10).toList();
          final old = all.skip(10).toList();

          final showList = [...newest10];
          if (_showOld) showList.addAll(old);

          return ListView(
            children: [
              ...showList.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final notiId = doc.id;
                final isRead = data["isRead"] ?? false;
                final accepted = data["accepted"] ?? false;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: isRead ? Colors.white : const Color(0xFFE8F0FE),

                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(_iconForType(data["type"]), color: Colors.blue),
                    ),

                    title: Text(
                      _messageForType(data),
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data["timestamp"] != null)
                          Text(_formatTime(data["timestamp"])),
                        const SizedBox(height: 6),

                        // =============================
                        // FRIEND REQUEST BUTTONS
                        // =============================
                        if (data["type"] == "friend_request" && !accepted)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _acceptFriendRequest(
                                          data["senderId"], notiId);
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Đồng ý"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Từ chối kết bạn"),
                                          content: const Text(
                                            "Bạn có chắc muốn từ chối yêu cầu này không?",
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text("Không")),
                                            TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text("Có")),
                                          ],
                                        ),
                                      ) ?? false;

                                      if (ok) {
                                        await _declineFriendRequest(
                                            data["senderId"], notiId);
                                        setState(() {});
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                    ),
                                    child: const Text("Từ chối", style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (data["type"] == "friend_request" && accepted)
                          const Text(
                            "Đã chấp nhận yêu cầu kết bạn",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),

                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == "delete") {
                          final ok = await _confirmDelete();
                          if (ok) {
                            await FirebaseFirestore.instance
                                .collection("notifications")
                                .doc(notiId)
                                .delete();
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Xóa thông báo"),
                            ],
                          ),
                        ),
                      ],
                    ),

                    onTap: () async {
                      _markAsRead(notiId);

                      if (data["postId"] != null) {
                        final post = await _fetchPost(data["postId"]);
                        if (post != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommentScreen(post: post),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              }),

              if (old.isNotEmpty)
                ListTile(
                  title: Text(
                    _showOld
                        ? "Thu gọn thông báo cũ"
                        : "Xem thêm thông báo cũ (${old.length})",
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                  trailing: Icon(
                    _showOld ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue,
                  ),
                  onTap: () {
                    setState(() => _showOld = !_showOld);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
