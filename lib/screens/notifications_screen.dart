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
  
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = "";
  String _filter = "all"; // "all", "read", "unread"

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================
  // FORMAT TIME
  // ===========================
  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  // ===========================
  // ICON FOR TYPE
  // ===========================
  IconData _iconForType(String type) {
    switch (type) {
      case "post":
        return Icons.post_add;
      case "like":
        return Icons.favorite;
      case "comment":
        return Icons.chat;
      case "reply":
        return Icons.reply;
      case "friend_request":
        return Icons.person_add_alt_1;
      case "friend_accepted":
        return Icons.person;
      default:
        return Icons.notifications;
    }
  }

  // ===========================
  // MESSAGE FOR NOTIFICATION
  // ===========================
  String _messageForType(Map<String, dynamic> n) {
    final name = n["senderName"] ?? "Ai đó";

    if (n["type"] == "friend_accepted") {
      return "$name đã chấp nhận lời mời kết bạn của bạn.";
    }

    if (n["type"] == "friend_request") {
      return "$name đã gửi cho bạn lời mời kết bạn.";
    }

    switch (n["type"]) {
      case "post":
        return "$name vừa đăng bài viết mới.";
      case "like":
        return "$name đã thích bài viết của bạn.";
      case "comment":
        return "$name đã bình luận bài viết của bạn.";
      case "reply":
        return "$name đã trả lời bình luận của bạn.";
      default:
        return "Bạn có thông báo mới.";
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection("notifications").doc(id).update({
      "isRead": true,
    });
  }

  Future<void> _deleteNotification(String id) async {
    await FirebaseFirestore.instance.collection("notifications").doc(id).delete();
  }

  Future<void> _blockUser(String userIdToBlock) async {
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection("users").doc(currentUser!.uid).update({
      "blockedUsers": FieldValue.arrayUnion([userIdToBlock]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bạn đã chặn người dùng này.")),
      );
    }
  }

  Future<Post?> _fetchPost(String postId) async {
    final snap = await FirebaseFirestore.instance.collection("POST").doc(postId).get();
    if (!snap.exists) return null;
    return Post.fromFirestore(snap);
  }

  Future<bool> _isRequestCancelled(String senderId) async {
    if (currentUser == null) return false;
    final q = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("senderId", isEqualTo: senderId)
        .where("receiverId", isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return false;
    return q.docs.first.data()["status"] == "cancelled";
  }

  Future<void> _acceptFriendRequest(String senderId, String notiId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection("users").doc(currentUser!.uid).update({
      "friends": FieldValue.arrayUnion([senderId])
    });
    await FirebaseFirestore.instance.collection("users").doc(senderId).update({
      "friends": FieldValue.arrayUnion([currentUser!.uid])
    });

    await FirebaseFirestore.instance.collection("notifications").doc(notiId).update({
      "accepted": true
    }).catchError((_) {});

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

    final me = await FirebaseFirestore.instance.collection("users").doc(currentUser!.uid).get();
    final senderName = me.data()?["displayName"] ?? "Ai đó";

    await FirebaseFirestore.instance.collection("notifications").add({
      "userId": senderId,
      "senderId": currentUser!.uid,
      "senderName": senderName,
      "type": "friend_accepted",
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false
    });
  }

  Future<void> _declineFriendRequest(String senderId, String notiId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection("notifications").doc(notiId).delete();

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

  Future<bool> _confirmAction(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Không")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Có")),
        ],
      ),
    ) ??
        false;
  }
  
  void _handleAppBarMenu(String value) {
    switch(value) {
      case "mark_all_read":
        _markAllAsRead();
        break;
      case "delete_all":
        _deleteAllNotifications();
        break;
      case "filter_unread":
        setState(() => _filter = "unread");
        break;
      case "filter_read":
        setState(() => _filter = "read");
        break;
      case "filter_all":
        setState(() => _filter = "all");
        break;
    }
  }
  
  Future<void> _markAllAsRead() async {
    if(currentUser == null) return;
    final notifications = await FirebaseFirestore.instance
      .collection("notifications")
      .where("userId", isEqualTo: currentUser!.uid)
      .where("isRead", isEqualTo: false)
      .get();
      
    final batch = FirebaseFirestore.instance.batch();
    for(final doc in notifications.docs) {
      batch.update(doc.reference, {"isRead": true});
    }
    await batch.commit();
  }
  
  Future<void> _deleteAllNotifications() async {
    final confirm = await _confirmAction("Xóa tất cả?", "Bạn có chắc muốn xóa tất cả thông báo không? Hành động này không thể hoàn tác.");
    if(!confirm || currentUser == null) return;
    
    final notifications = await FirebaseFirestore.instance
      .collection("notifications")
      .where("userId", isEqualTo: currentUser!.uid)
      .get();
      
    final batch = FirebaseFirestore.instance.batch();
    for(final doc in notifications.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Tìm kiếm thông báo...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70)
                ),
                style: const TextStyle(color: Colors.white),
              )
            : const Text("Thông báo"),
        backgroundColor: const Color(0xFF1877F2),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = "";
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleAppBarMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(value: "mark_all_read", child: Text("Đánh dấu tất cả đã đọc")),
              const PopupMenuItem(value: "delete_all", child: Text("Xóa tất cả thông báo")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: "filter_unread", child: Text("Chỉ hiện chưa đọc")),
              const PopupMenuItem(value: "filter_read", child: Text("Chỉ hiện đã đọc")),
              const PopupMenuItem(value: "filter_all", child: Text("Hiện tất cả")),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("notifications")
            .where("userId", isEqualTo: currentUser!.uid)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          var all = snap.data!.docs;

          if (_filter == "unread") {
            all = all.where((doc) => doc.data()["isRead"] == false).toList();
          } else if (_filter == "read") {
            all = all.where((doc) => doc.data()["isRead"] == true).toList();
          }

          if (_searchQuery.isNotEmpty) {
            all = all.where((doc) {
              final data = doc.data();
              final message = _messageForType(data).toLowerCase();
              final sender = (data["senderName"] ?? "").toLowerCase();
              final query = _searchQuery.toLowerCase();
              return message.contains(query) || sender.contains(query);
            }).toList();
          }
          
          if (all.isEmpty) return const Center(child: Text("Không có thông báo."));

          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (context, index) {
                final doc = all[index];
                final data = doc.data();
                final notiId = doc.id;
                final isRead = data["isRead"] ?? false;
                final accepted = data["accepted"] ?? false;

                if (data["type"] == "friend_request") {
                  _isRequestCancelled(data["senderId"]).then((cancelled) async {
                    if (cancelled) {
                      await FirebaseFirestore.instance.collection("notifications").doc(notiId).delete();
                    }
                  });
                }

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
                      style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                    ),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data["timestamp"] != null) Text(_formatTime(data["timestamp"])),
                        const SizedBox(height: 8),

                        if (data["type"] == "friend_request" && !accepted)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _acceptFriendRequest(data["senderId"], notiId);
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
                                      final ok = await _confirmAction("Từ chối kết bạn", "Bạn có chắc muốn từ chối yêu cầu này không?");
                                      if (ok) {
                                        await _declineFriendRequest(data["senderId"], notiId);
                                      }
                                    },
                                    child: const Text("Từ chối", style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (data["type"] == "friend_request" && accepted)
                          const Text("Đã chấp nhận yêu cầu kết bạn",
                              style: TextStyle(color: Colors.green)),
                      ],
                    ),

                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'mark_as_read':
                            await _markAsRead(notiId);
                            break;
                          case 'delete':
                            final ok = await _confirmAction("Xóa thông báo","Bạn có chắc muốn xóa thông báo này không?");
                            if (ok) {
                              await _deleteNotification(notiId);
                            }
                            break;
                          case 'block':
                             final confirm = await _confirmAction(
                                "Chặn người dùng",
                                "Bạn có muốn chặn ${data['senderName'] ?? 'người dùng này'}? Bạn sẽ không nhận được thông báo từ họ nữa.",
                              );
                              if (confirm) {
                                await _blockUser(data['senderId']);
                              }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isRead)
                          const PopupMenuItem(
                            value: 'mark_as_read',
                            child: Row(
                              children: [
                                Icon(Icons.check, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Đánh dấu đã đọc"),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Xóa thông báo"),
                            ],
                          ),
                        ),
                         if (data['senderId'] != null)
                          const PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.orange),
                                SizedBox(width: 8),
                                Text("Chặn người dùng này"),
                              ],
                            ),
                          ),
                      ],
                    ),

                    onTap: () async {
                      if(!isRead) _markAsRead(notiId);

                      if (data["postId"] != null) {
                        final post = await _fetchPost(data["postId"]);
                        if (post != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CommentScreen(post: post)),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bài viết hoặc bình luận này đã bị xóa."),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              },
          );
        },
      ),
    );
  }
}
