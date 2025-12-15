// lib/screens/chat_list_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/chat_screen.dart';
import 'package:zalo_app/screens/create_group_screen.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import '../services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _search = "";
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  Stream<String> lastVisibleMessageStream(String roomId) {
    return _chatService.getLastMessageStream(roomId).map((snap) {
      if (snap.docs.isEmpty) return "Chưa có tin nhắn";

      final data = snap.docs.first.data() as Map<String, dynamic>;
      final deletedFor = List<String>.from(data["deletedFor"] ?? []);

      if (deletedFor.contains(uid)) return "Tin nhắn đã xóa";

      if (data["isRecalled"] == true) {
        return "Tin nhắn đã được thu hồi";
      } else if (data['type'] == 'image') {
        return "📷 [Hình ảnh]";
      } else if (data['type'] == 'shared_post') {
        final content = data['sharedPostContent'] as String?;
        final userName = data['sharedPostUserName'] as String?;
        final customMessage = data['message'] as String?;
        if (customMessage != null && customMessage.isNotEmpty) {
          return customMessage;
        } else {
          return 'Đã chia sẻ bài viết của ${userName ?? 'Người dùng'}';
        }
      } else {
        return data["message"] ?? "";
      }
    });
  }

  bool isUnread(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    if (data['lastSenderId'] == uid) return false;
    if (doc.metadata.hasPendingWrites) return false;

    final updated = data["updatedAt"];
    if (updated == null) return false;

    final lastReadMap = data["lastReadTime"] as Map<String, dynamic>?;
    final lastRead = lastReadMap?[uid] as Timestamp?;

    if (lastRead == null) return true;

    final Timestamp? updatedTs = (updated is Timestamp) ? updated : null;
    if (updatedTs == null) return false;

    return updatedTs.millisecondsSinceEpoch > lastRead.millisecondsSinceEpoch;
  }

  void showDeleteDialog(BuildContext context, String roomId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Xóa hội thoại với $name?"),
        content: const Text("Chỉ xóa cho bạn, người kia vẫn xem được."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              await _chatService.hideChatRoom(roomId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  // ⭐ Widget đường kẻ phân cách (Indent = 72: chuẩn Material cho Avatar + Text)
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 72, // Đẩy vào 72px để tránh Avatar
      color: Color(0xFFEEEEEE), // Màu xám nhạt tinh tế
    );
  }

  Widget _buildActiveChatList({bool shrinkWrap = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.chatRoomsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snap.data!.docs;

        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (ctx, idx) {
            final room = rooms[idx];
            final data = room.data() as Map<String, dynamic>;
            final roomId = room.id;

            final Map deletedAtMap = (data["deletedAt"] is Map) ? data["deletedAt"] : {};
            final Timestamp? deletedAt = deletedAtMap[uid] as Timestamp?;
            final Timestamp? updatedAt = data["updatedAt"] as Timestamp?;
            if (deletedAt != null) {
              if (updatedAt == null || updatedAt.compareTo(deletedAt) <= 0) {
                return const SizedBox.shrink();
              }
            }

            final isGroup = data["isGroup"] == true;
            final unread = isUnread(room);

            return StreamBuilder<String>(
              stream: lastVisibleMessageStream(roomId),
              builder: (context, lastSnap) {
                final lastMsg = lastSnap.data ?? "";

                if (isGroup) {
                  final name = data["groupName"] ?? "Nhóm";
                  if (_search.isNotEmpty && !name.toLowerCase().contains(_search)) {
                    return const SizedBox.shrink();
                  }

                  // ⭐ Wrap ListTile trong Column để thêm Divider
                  return Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.groups, color: Colors.white),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread ? Colors.black : Colors.grey,
                            fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onLongPress: () => showDeleteDialog(context, roomId, name),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: roomId, receiverName: name, isGroup: true)));
                        },
                      ),
                      _buildDivider(), // Thêm dòng kẻ
                    ],
                  );
                }

                final participants = List.from(data["participants"] ?? []);
                final otherId = participants.firstWhere((x) => x != uid, orElse: () => "");
                if (otherId.isEmpty) return const SizedBox.shrink();

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection("users").doc(otherId).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox.shrink();
                    final user = userSnap.data!.data() as Map<String, dynamic>?;
                    final name = user?["displayName"] ?? "Người dùng";
                    final email = user?["email"] ?? "";
                    final avatar = user?["photoURL"];

                    if (_search.isNotEmpty) {
                      bool matchName = name.toString().toLowerCase().contains(_search);
                      bool matchEmail = email.toString().toLowerCase().contains(_search);
                      if (!matchName && !matchEmail) {
                        return const SizedBox.shrink();
                      }
                    }

                    // ⭐ Wrap ListTile trong Column để thêm Divider
                    return Column(
                      children: [
                        ListTile(
                          leading: GestureDetector(
                            onTap: () => _navigateToProfile(context, otherId),
                            child: CircleAvatar(
                              backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                              child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null,
                            ),
                          ),
                          title: Text(name, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600)),
                          subtitle: Text(
                            lastMsg.isEmpty ? "Tin nhắn đã xóa" : lastMsg,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: unread ? Colors.black87 : Colors.grey, fontWeight: unread ? FontWeight.bold : FontWeight.normal),
                          ),
                          onLongPress: () => showDeleteDialog(context, roomId, name),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: otherId, receiverName: name, receiverAvatar: avatar, isGroup: false)));
                          },
                        ),
                        _buildDivider(), // Thêm dòng kẻ
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendSuggestions() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();

        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> friendIds = userData['friends'] ?? [];

        if (friendIds.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, allUsersSnap) {
            if (!allUsersSnap.hasData) return const Center(child: CircularProgressIndicator());

            final allDocs = allUsersSnap.data!.docs;

            final matchedFriends = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final userId = doc.id;
              final name = (d['displayName'] ?? '').toString().toLowerCase();
              final email = (d['email'] ?? '').toString().toLowerCase();
              bool isFriend = friendIds.contains(userId);
              bool isMatch = name.contains(_search) || email.contains(_search);
              return isFriend && isMatch;
            }).toList();

            if (matchedFriends.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Không tìm thấy bạn bè phù hợp", style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matchedFriends.length,
              itemBuilder: (context, index) {
                final userDoc = matchedFriends[index];
                final userData = userDoc.data() as Map<String, dynamic>;
                final name = userData['displayName'] ?? 'Người dùng';
                final email = userData['email'] ?? '';
                final avatar = userData['photoURL'];
                final userId = userDoc.id;

                // ⭐ Wrap ListTile trong Column để thêm Divider
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                        child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name),
                      subtitle: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.message, color: Color(0xFF1877F2)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: userId,
                              receiverName: name,
                              receiverAvatar: avatar,
                              isGroup: false,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDivider(), // Thêm dòng kẻ
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tin nhắn"),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1877F2),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: "Tìm theo tên hoặc email...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  _searchController.clear();
                  setState(() => _search = "");
                })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _search.isEmpty
                ? _buildActiveChatList()
                : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[100],
                    child: const Text("Cuộc trò chuyện", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  _buildActiveChatList(shrinkWrap: true),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[100],
                    child: const Text("Gợi ý từ danh bạ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  _buildFriendSuggestions(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1877F2),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
      ),
    );
  }
}