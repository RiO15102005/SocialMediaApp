// lib/screens/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final UserService _userService = UserService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailDisplayController = TextEditingController();

  String? avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _emailDisplayController.text = currentUser!.email ?? 'Không có email';
    }
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final data = await _userService.loadUserData(currentUser!.uid);

    if (data != null) {
      _nameController.text = data['displayName'] ?? '';
      _bioController.text = data['bio'] ?? '';
      avatarUrl = data['photoURL'];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng đổi ảnh tạm thời bị tắt.')),
    );
  }


  Future<void> _saveChanges() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu hồ sơ.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await _userService.saveProfileChanges(
        currentUser!.uid,
        _nameController.text,
        _bioController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailDisplayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 4,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên hiển thị', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Tiểu sử', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailDisplayController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Lưu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}