// lib/screens/create_group_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final String? preSelectedUserId;
  const CreateGroupScreen({super.key, this.preSelectedUserId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ChatService _chatService = ChatService();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedUserId != null) _selectedUserIds.add(widget.preSelectedUserId!);
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  Future<void> _createGroup() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên nhóm"))); return; }
    if (_selectedUserIds.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chọn ít nhất 1 người bạn"))); return; }
    setState(() => _isLoading = true);
    try {
      String newGroupId = await _chatService.createGroupChat(name, _selectedUserIds);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: newGroupId, receiverName: name, isGroup: true)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo nhóm mới"), backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white, actions: [TextButton(onPressed: _isLoading ? null : _createGroup, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("TẠO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Tên nhóm", border: OutlineInputBorder(), prefixIcon: Icon(Icons.group), hintText: "Ví dụ: Nhóm học tập..."))),
        const Divider(thickness: 1), const Padding(padding: EdgeInsets.only(left: 16, bottom: 8, top: 8), child: Align(alignment: Alignment.centerLeft, child: Text("Chọn thành viên:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        Expanded(child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
            final friendIds = userData['friends'] ?? [];
            if (friendIds.isEmpty) return const Center(child: Text("Bạn chưa có bạn bè nào."));
            return ListView.builder(
              itemCount: friendIds.length,
              itemBuilder: (context, index) {
                final friendId = friendIds[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                  builder: (context, friendSnap) {
                    if (!friendSnap.hasData) return const SizedBox();
                    final friendData = friendSnap.data!.data() as Map<String, dynamic>;
                    final name = friendData['displayName'] ?? 'Không tên';
                    final avatar = friendData['photoURL'];
                    final isSelected = _selectedUserIds.contains(friendId);
                    return CheckboxListTile(
                      value: isSelected, activeColor: const Color(0xFF1877F2),
                      secondary: CircleAvatar(backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person) : null),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      onChanged: (val) { setState(() { if (val == true) _selectedUserIds.add(friendId); else _selectedUserIds.remove(friendId); }); },
                    );
                  },
                );
              },
            );
          },
        )),
      ]),
    );
  }
}