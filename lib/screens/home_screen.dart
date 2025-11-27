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
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late Future<List<String>> _friendsListFuture;

  @override
  void initState() {
    super.initState();
    _friendsListFuture = _userService.getCurrentUserFriendsList();
  }

  Future<void> _refresh() async {
    setState(() {
      _friendsListFuture = _userService.getCurrentUserFriendsList();
    });
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Vui lòng đăng nhập để xem bảng tin.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        backgroundColor: const Color(0xFF1877F2),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFFF0F2F5),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: _refresh,
        child: FutureBuilder<List<String>>(
          future: _friendsListFuture,
          builder: (context, friendSnap) {
            if (friendSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!friendSnap.hasData) {
              return const Center(child: Text("Không thể tải danh sách bạn bè."));
            }

            final allowedUIDs = List<String>.from(friendSnap.data!);
            if (!allowedUIDs.contains(currentUser!.uid)) {
              allowedUIDs.add(currentUser!.uid);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _postService.getAllPostsStream(),
              builder: (context, postSnap) {
                if (!postSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = postSnap.data!.docs;

                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = data["UID"] as String?;
                  return uid != null && allowedUIDs.contains(uid);
                }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text("Chưa có bài viết nào.", style: TextStyle(fontSize: 16))),
                    ],
                  );
                }

                filtered.sort((a, b) {
                  final ta = (a.data() as Map<String, dynamic>)["timestamp"] as Timestamp?;
                  final tb = (b.data() as Map<String, dynamic>)["timestamp"] as Timestamp?;
                  return (tb ?? Timestamp.now()).compareTo(ta ?? Timestamp.now());
                });

                final lastIndex = filtered.length - 1;

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final post = Post.fromFirestore(filtered[index]);
                    return Column(
                      children: [
                        PostCard(
                          post: post,
                          showLikeButton: true,
                          showCommentButton: true,
                          source: "home",
                        ),
                        if (index != lastIndex)
                          const Divider(height: 12, thickness: 10, color: Color(0xFFF0F2F5)),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
          if (result == true) {
            _refresh();
          }
        },
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}
