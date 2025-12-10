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

  final String uid = FirebaseAuth.instance.currentUser!.uid;
  String _search = "";

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  // For last message per room, we create a stream that listens to messages collection and emits latest visible message
  Stream<String> lastVisibleMessageStream(String roomId) {
    // map messages stream to a string representing last visible message
    return _chatService.getMessages(roomId).map((snap) {
      String result = "";
      final docs = snap.docs;
      for (var i = docs.length - 1; i >= 0; i--) {
        final data = docs[i].data() as Map<String, dynamic>;
        final deletedFor = List<String>.from(data["deletedFor"] ?? []);
        if (deletedFor.contains(uid)) continue;

        if (data["isRecalled"] == true) {
          result = "Tin nhắn đã được thu hồi •";
        } else if (data['type'] == 'shared_post') {
          final content = data['sharedPostContent'] as String?;
          final userName = data['sharedPostUserName'] as String?;
          final customMessage = data['message'] as String?;

          if (customMessage != null && customMessage.isNotEmpty) {
            result = customMessage;
          } else {
            result =
                'Đã chia sẻ một bài viết của ${userName ?? 'Người dùng'}: "${content ?? ''}"';
          }
        } else {
          result = data["message"] ?? "";
        }
        break;
      }
      return result;
    }).distinct();
  }

  bool isUnread(Map<String, dynamic> data) {
    final updated = data["updatedAt"];
    if (updated == null) return false;

    final lastRead = (data["lastReadTime"] ?? {})[uid];
    if (lastRead == null) return true;

    return updated.toDate().isAfter(lastRead.toDate());
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
              Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.chatRoomsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snap.data!.docs;

        if (rooms.isEmpty) {
          return const Center(child: Text("Chưa có tin nhắn"));
        }

        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (ctx, idx) {
            final room = rooms[idx];
            final data = room.data() as Map<String, dynamic>;
            final roomId = room.id;

            final isGroup = data["isGroup"] == true;
            final unread = isUnread(data);

            return StreamBuilder<String>(
              stream: lastVisibleMessageStream(roomId),
              builder: (context, lastSnap) {
                final lastMsg = lastSnap.data ?? "";

                if (isGroup) {
                  final name = data["groupName"] ?? "Nhóm";
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.groups, color: Colors.white),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? Colors.black : Colors.grey,
                        fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onLongPress: () => showDeleteDialog(context, roomId, name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: roomId,
                            receiverName: name,
                            receiverAvatar: "",
                            isGroup: true,
                          ),
                        ),
                      );
                    },
                  );
                }

                final participants = List.from(data["participants"] ?? []);
                final otherId = participants.firstWhere((x) => x != uid, orElse: () => "");

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection("users").doc(otherId).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox();
                    final user = userSnap.data!.data() as Map<String, dynamic>;
                    final name = user["displayName"] ?? "Người dùng";
                    final avatar = user["photoURL"];

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => _navigateToProfile(context, otherId),
                        child: CircleAvatar(
                          backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                          child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null,
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () => _navigateToProfile(context, otherId),
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      subtitle: Text(
                        lastMsg.isEmpty ? "Tin nhắn đã bị xóa" : lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? Colors.black : Colors.grey,
                          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onLongPress: () => showDeleteDialog(context, roomId, name),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: otherId,
                              receiverName: name,
                              receiverAvatar: avatar,
                              isGroup: false,
                            ),
                          ),
                        );
                      },
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
                hintText: "Tìm kiếm bạn bè...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(child: buildChatList()),
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
