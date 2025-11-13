// lib/screens/user_post_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class UserPostScreen extends StatelessWidget {
  final String userId;

  const UserPostScreen({super.key, required this.userId});

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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('Chưa có bài viết nào.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final post = Post.fromFirestore(doc);
            return PostCard(post: post);
          },
        );
      },
    );
  }
}