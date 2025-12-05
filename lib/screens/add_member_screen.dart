// lib/screens/add_member_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class AddMemberScreen extends StatefulWidget {
  final String groupId;
  final List<dynamic> currentMembers; // Danh sách ID hiện tại để lọc

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

  Future<void> _submit() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await _chatService.addMembersToGroup(widget.groupId, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context); // Quay lại màn hình thông tin nhóm
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã thêm thành viên mới")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
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
            onPressed: _isLoading ? null : _submit,
            child: const Text("Xong", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> allFriends = userData['friends'] ?? [];

          // Lọc ra những bạn bè CHƯA có trong nhóm
          final potentialMembers = allFriends.where((fid) => !widget.currentMembers.contains(fid)).toList();

          if (potentialMembers.isEmpty) {
            return const Center(child: Text("Không còn bạn bè nào để thêm."));
          }

          return ListView.builder(
            itemCount: potentialMembers.length,
            itemBuilder: (context, index) {
              final friendId = potentialMembers[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                builder: (context, friendSnap) {
                  if (!friendSnap.hasData) return const SizedBox();
                  final data = friendSnap.data!.data() as Map<String, dynamic>;
                  final name = data['displayName'] ?? 'No Name';
                  final avatar = data['photoURL'];

                  final isSelected = _selectedUserIds.contains(friendId);

                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFF1877F2),
                    title: Text(name),
                    secondary: CircleAvatar(
                      backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                      child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null,
                    ),
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