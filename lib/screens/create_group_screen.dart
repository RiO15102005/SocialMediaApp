// lib/screens/create_group_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart'; // Import màn hình chat (cùng thư mục)
import '../services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  // Controller để nhập tên nhóm
  final TextEditingController _nameController = TextEditingController();

  // Service xử lý logic chat (tạo nhóm, gửi tin...)
  final ChatService _chatService = ChatService();

  // Lấy ID người dùng hiện tại
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Danh sách ID các bạn bè được chọn
  final List<String> _selectedUserIds = [];

  // Trạng thái đang tải (khi bấm nút Tạo)
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Hàm xử lý khi bấm nút "TẠO"
  Future<void> _createGroup() async {
    // 1. Ẩn bàn phím
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();

    // Validate dữ liệu đầu vào
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên nhóm")),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chọn ít nhất 1 người bạn")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Gọi service để tạo nhóm và LẤY VỀ ID NHÓM MỚI (GroupId)
      String newGroupId = await _chatService.createGroupChat(name, _selectedUserIds);

      // Kiểm tra widget còn tồn tại không trước khi chuyển màn hình
      if (!mounted) return;

      // 3. Chuyển hướng thẳng sang màn hình ChatScreen của nhóm vừa tạo
      // Sử dụng pushReplacement để thay thế màn hình tạo nhóm bằng màn hình chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: newGroupId, // ID phòng chat chính là ID nhóm
            receiverName: name,     // Tên nhóm
            isGroup: true,          // Đánh dấu đây là cuộc trò chuyện nhóm
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi tạo nhóm: $e"),
              backgroundColor: Colors.red,
            )
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
        title: const Text("Tạo nhóm mới"),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        actions: [
          // Nút TẠO trên thanh AppBar
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
                : const Text(
                "TẠO",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Phần nhập tên nhóm
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Tên nhóm",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
                hintText: "Ví dụ: Nhóm học tập...",
              ),
            ),
          ),

          const Divider(thickness: 1),

          // Tiêu đề danh sách bạn bè
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Chọn thành viên:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            ),
          ),

          // Danh sách bạn bè (Checkbox)
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
              builder: (context, userSnap) {
                // Xử lý trạng thái loading/error
                if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
                if (userSnap.hasError) return const Center(child: Text("Có lỗi xảy ra"));

                final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                final List<dynamic> friendIds = userData['friends'] ?? [];

                if (friendIds.isEmpty) {
                  return const Center(
                    child: Text("Bạn chưa có bạn bè nào để thêm vào nhóm.", style: TextStyle(color: Colors.grey)),
                  );
                }

                // Hiển thị list bạn bè
                return ListView.builder(
                  itemCount: friendIds.length,
                  itemBuilder: (context, index) {
                    final friendId = friendIds[index];

                    // Lấy thông tin chi tiết từng người bạn
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
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedUserIds.add(friendId);
                              } else {
                                _selectedUserIds.remove(friendId);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundImage: (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}