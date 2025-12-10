// lib/screens/group_info_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'add_member_screen.dart'; // Đảm bảo file này tồn tại (xem code bên dưới)
import 'profile_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final currentUser = FirebaseAuth.instance.currentUser!;

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  // Xóa thành viên
  void _kickMember(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Xóa $memberName?"),
        content: const Text("Người này sẽ bị xóa khỏi nhóm."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // ChatService đã có logic gửi thông báo hệ thống
              await _chatService.removeMemberFromGroup(widget.groupId, memberId);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Rời nhóm
  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rời nhóm?"),
        content: const Text("Bạn sẽ không còn là thành viên của nhóm này."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.leaveGroup(widget.groupId);
              if (mounted) {
                // Quay về trang chủ (Chat List)
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text("Rời nhóm", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Giải tán nhóm
  void _disbandGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Giải tán nhóm?"),
        content: const Text("Nhóm và toàn bộ tin nhắn sẽ bị xóa vĩnh viễn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatService.deleteChatRoom(widget.groupId);
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            child: const Text("Giải tán", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông tin nhóm"),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Đã xảy ra lỗi tải dữ liệu."));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Nếu nhóm bị xóa hoặc mình bị kick (không còn quyền đọc)
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Nhóm không tồn tại hoặc bạn không có quyền truy cập."));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;

          // ⭐ QUAN TRỌNG: Ép kiểu an toàn sang List<String>
          final List<String> participants = List<String>.from(groupData['participants'] ?? []);

          final String adminId = groupData['adminId'] ?? '';
          final bool isAdmin = (currentUser.uid == adminId);

          return Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(radius: 40, child: Icon(Icons.groups, size: 40)),
              const SizedBox(height: 10),
              Text(
                groupData['groupName'] ?? "Nhóm",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text("${participants.length} thành viên", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nút Thêm
                  Column(children: [
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMemberScreen(
                              groupId: widget.groupId,
                              currentMembers: participants, // Truyền List<String> đã ép kiểu
                            ),
                          ),
                        );
                      },
                    ),
                    const Text("Thêm"),
                  ]),
                  const SizedBox(width: 30),
                  // Nút Rời
                  Column(children: [
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      onPressed: _leaveGroup,
                    ),
                    const Text("Rời nhóm", style: TextStyle(color: Colors.red)),
                  ]),
                ],
              ),
              const Divider(height: 30, thickness: 5),

              // Danh sách thành viên
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final memberId = participants[index];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        final userData = userSnap.data!.data() as Map<String, dynamic>?;
                        final name = userData?['displayName'] ?? 'Người dùng';
                        final avatar = userData?['photoURL'];

                        final bool isMe = (memberId == currentUser.uid);
                        final bool isMemberAdmin = (memberId == adminId);

                        return ListTile(
                          onTap: () => _navigateToProfile(context, memberId),
                          leading: CircleAvatar(
                            backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                            child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null,
                          ),
                          title: Row(
                            children: [
                              Text(name, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                              if (isMemberAdmin)
                                const Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Text("(Admin)", style: TextStyle(color: Colors.blue, fontSize: 12)),
                                ),
                            ],
                          ),
                          subtitle: isMe ? const Text("Bạn") : null,
                          trailing: (isAdmin && !isMe)
                              ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _kickMember(memberId, name),
                          )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),

              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _disbandGroup,
                      child: const Text("Giải tán nhóm"),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}