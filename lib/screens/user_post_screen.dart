// lib/screens/user_post_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class UserPostScreen extends StatelessWidget {
  final String userId;
  final bool isMyProfile;

  const UserPostScreen({super.key, required this.userId, required this.isMyProfile});

  @override
  Widget build(BuildContext context) {
    final PostService postService = PostService();

    Stream<QuerySnapshot> postsStream = FirebaseFirestore.instance
        .collection('POST')
        .where('UID', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải bài viết: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        // Bỏ lọc theo content.trim() để không vô tình loại hết bài viết
        final posts = docs.map((doc) => Post.fromFirestore(doc)).where((post) => !post.isDeleted).toList();

        if (posts.isEmpty) {
          final emptyMessage = isMyProfile
              ? 'Chưa có bài viết nào để hiển thị.'
              : 'Người dùng này chưa đăng bài viết nào.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(emptyMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post);
          },
        );
      },
    );
  }
}
