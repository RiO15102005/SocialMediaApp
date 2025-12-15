// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_service.dart';
import '../services/upload_profile.dart'; // Supabase upload

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
    _emailDisplayController.text = currentUser?.email ?? "Không có email";
    _loadUserData();
  }

  // ---------------- LOAD USER DATA ----------------
  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final data = await _userService.loadUserData(currentUser!.uid);

    if (data != null) {
      _nameController.text = data['displayName'] ?? '';
      _bioController.text = data['bio'] ?? '';
      avatarUrl = data['avatar']; // đúng field avatar
    }

    setState(() => _isLoading = false);
  }

  // ---------------- PICK & UPLOAD AVATAR ----------------
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    final uploadedUrl = await AvatarUploadService.uploadAvatar(
      picked.path,
      currentUser!.uid,
    );

    if (uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tải ảnh thất bại!")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"avatar": uploadedUrl});

    setState(() => avatarUrl = uploadedUrl);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")),
    );
  }

  // ---------------- SAVE ----------------
  Future<void> _saveChanges() async {
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _userService.saveProfileChanges(
        currentUser!.uid,
        _nameController.text.trim(),
        _bioController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật hồ sơ thành công!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi lưu: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        iconTheme: const IconThemeData(color: Colors.white), // icon trắng
        title: const Text(
          "Chỉnh sửa hồ sơ",
          style: TextStyle(
            color: Colors.white, // title trắng
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // -------- AVATAR --------
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 55, color: Colors.white)
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
                        color: Color(0xFF1877F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // -------- NAME --------
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Tên hiển thị",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // -------- BIO (GIỚI THIỆU) --------
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Giới thiệu",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // -------- EMAIL --------
            TextField(
              controller: _emailDisplayController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // -------- SAVE BUTTON --------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2), // xanh biển
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "Lưu",
                  style: TextStyle(
                    color: Colors.white, // chữ trắng
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}