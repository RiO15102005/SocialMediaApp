// lib/screens/add_member_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class AddMemberScreen extends StatefulWidget {
  final String groupId;
  final List<String> currentMembers; // Danh sách thành viên hiện tại để loại trừ

  const AddMemberScreen({
    super.key,
    required this.groupId,
    required this.currentMembers,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final ChatService _chatService = ChatService();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  Future<void> _addMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Hàm này trong ChatService đã bao gồm logic gửi thông báo hệ thống
      await _chatService.addMembersToGroup(widget.groupId, _selectedUserIds);

      if (mounted) {
        Navigator.pop(context); // Quay lại trang Info
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã thêm thành viên vào nhóm")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thêm thành viên"),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: (_isLoading || _selectedUserIds.isEmpty) ? null : _addMembers,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("THÊM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> friendIds = userData['friends'] ?? [];

          if (friendIds.isEmpty) {
            return const Center(child: Text("Bạn không có bạn bè nào để thêm."));
          }

          // Lọc ra những người chưa có trong nhóm
          final availableFriends = friendIds.where((fid) => !widget.currentMembers.contains(fid)).toList();

          if (availableFriends.isEmpty) {
            return const Center(child: Text("Tất cả bạn bè đã ở trong nhóm."));
          }

          return ListView.builder(
            itemCount: availableFriends.length,
            itemBuilder: (context, index) {
              final friendId = availableFriends[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                builder: (context, friendSnap) {
                  if (!friendSnap.hasData) return const SizedBox();
                  final friendData = friendSnap.data!.data() as Map<String, dynamic>?;
                  if (friendData == null) return const SizedBox();

                  final name = friendData['displayName'] ?? 'Không tên';
                  final avatar = friendData['photoURL'];
                  final isSelected = _selectedUserIds.contains(friendId);

                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFF1877F2),
                    secondary: CircleAvatar(
                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                          ? NetworkImage(avatar)
                          : null,
                      child: (avatar == null || avatar.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(name),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedUserIds.add(friendId);
                        } else {
                          _selectedUserIds.remove(friendId);
                        }
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}