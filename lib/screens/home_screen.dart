import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_post_screen.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final currentUser = FirebaseAuth.instance.currentUser;

  late Future<List<String>> _friendsListFuture;

  @override
  void initState() {
    super.initState();
    _refreshFriendsAndPosts();
  }

  void _refreshFriendsAndPosts() {
    if (currentUser == null) return;
    setState(() {
      _friendsListFuture = _userService.getCurrentUserFriendsList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Vui lòng đăng nhập để xem bảng tin."));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<String>>(
        future: _friendsListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Lỗi khi lấy danh sách bạn bè: ${snapshot.error}'));
          }

          final friendsUids = snapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: _postService.getPostsStream(friendsUids),
            builder: (context, postSnapshot) {
              if (postSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (postSnapshot.hasError) {
                return Center(child: Text('Đã xảy ra lỗi: ${postSnapshot.error}'));
              }
              if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Chưa có bài đăng nào từ bạn bè.'));
              }

              return ListView.builder(
                itemCount: postSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = postSnapshot.data!.docs[index];
                  final post = Post.fromFirestore(doc);
                  return PostCard(post: post, showActions: true); // ✅ sửa tại đây
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (result == true) _refreshFriendsAndPosts();
        },
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
