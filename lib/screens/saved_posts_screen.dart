import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final PostService _postService = PostService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _onPostSaved(bool isSaved) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved ? "Bài viết đã được lưu" : "Đã bỏ lưu bài viết"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey[800],
        ),
      );
      // The stream will rebuild the list automatically.
      if (!isSaved) {
        setState(() {}); // Trigger a rebuild to reflect the change instantly.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài viết đã lưu')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem các bài viết đã lưu của bạn.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết đã lưu'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _postService.getSavedPostsStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa lưu bài viết nào.'));
          }

          final posts = snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onPostSaved: _onPostSaved,
              );
            },
          );
        },
      ),
    );
  }
}
