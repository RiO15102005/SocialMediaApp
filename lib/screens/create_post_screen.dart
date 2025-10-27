// lib/screens/create_post_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đăng bài')),
      );
      return;
    }

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung không được để trống')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy thông tin người dùng từ collection 'users'
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userName': userData?['displayName'] ?? userData?['email'] ?? 'Người dùng ẩn danh',
        'content': _textController.text.trim(),
        'timestamp': Timestamp.now(),
        'likes': [], // Thêm trường likes
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng bài thất bại: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo bài viết'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('ĐĂNG', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì?',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
