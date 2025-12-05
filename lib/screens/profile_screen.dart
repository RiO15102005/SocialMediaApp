// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_cover.dart';
import 'profile_avatar.dart';
import 'profile_info.dart';
import 'add_post_button.dart';
import 'action_button.dart';
import 'create_post_screen.dart';
import 'friends_list_screen.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late String _targetUserId;
  late bool _isMyProfile;

  File? _avatarImage;
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    // Xử lý trường hợp currentUser null
    final uid = currentUser?.uid ?? '';
    _targetUserId = widget.userId ?? uid;
    _isMyProfile = (_targetUserId == uid);
  }

  Future<void> _pickAvatar() async {}
  Future<void> _pickCover() async {}

  Future<void> _addPost() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bài viết mới đã được đăng!')));
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text("Vui lòng đăng nhập để xem profile.")));
    }

    if (_targetUserId.isEmpty) {
      return const Scaffold(body: Center(child: Text("Không tìm thấy người dùng.")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _isMyProfile
            ? [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ]
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_targetUserId)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. AN TOÀN: Kiểm tra loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. AN TOÀN: Kiểm tra dữ liệu
          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return const Center(child: Text("Người dùng không tồn tại hoặc chưa có dữ liệu."));
          }

          // 3. AN TOÀN: Lấy dữ liệu với giá trị mặc định
          final userData = snapshot.data!.data() ?? {};
          final displayName = userData['displayName'] ?? 'Chưa có tên';
          final bio = userData['bio'] ?? 'Chưa có tiểu sử';
          final friends = (userData['friends'] as List?) ?? [];
          final friendsCount = friends.length;
          final bool isFriend = friends.contains(currentUser!.uid);

          ImageProvider? avatarProvider =
          _avatarImage != null ? FileImage(_avatarImage!) : null;
          ImageProvider? coverProvider =
          _coverImage != null ? FileImage(_coverImage!) : null;

          // Nếu có ảnh từ Firebase thì ưu tiên hiển thị (bạn có thể bỏ qua nếu chưa làm upload ảnh)
          if (avatarProvider == null && userData['photoURL'] != null && userData['photoURL'].isNotEmpty) {
            avatarProvider = NetworkImage(userData['photoURL']);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ProfileCover(
                        coverImage: coverProvider,
                        isMyProfile: _isMyProfile,
                        onPickCover: _pickCover),
                    ProfileAvatar(
                        avatarImage: avatarProvider,
                        isMyProfile: _isMyProfile,
                        onPickAvatar: _pickAvatar),
                    ProfileInfo(
                        displayName: displayName,
                        bio: bio,
                        friendsCount: friendsCount,
                        onFriendsTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      FriendsScreen(userId: _targetUserId)));
                        }),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _isMyProfile
                          ? Row(
                        children: [
                          Expanded(
                              child: AddPostButton(onAddPost: _addPost)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: ActionButton(
                                  isMyProfile: _isMyProfile,
                                  targetUserId: _targetUserId)),
                        ],
                      )
                          : ActionButton(
                          isMyProfile: _isMyProfile,
                          targetUserId: _targetUserId),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: const Color(0xFFF0F2F5),
                      child: const Text("Bài viết",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              if (!_isMyProfile && !isFriend)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "Bạn không thể xem bài viết của $displayName khi chưa là bạn bè.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('POST')
                      .where('UID', isEqualTo: _targetUserId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          ));
                    }

                    if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) {
                      return const SliverToBoxAdapter(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Text("Chưa có bài viết nào."))));
                    }

                    final docs = postSnapshot.data!.docs;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final post = Post.fromFirestore(docs[index]);
                          return Column(children: [
                            PostCard(
                                post: post,
                                showLikeButton: true,
                                showCommentButton: true),
                            const Divider(
                                height: 12,
                                thickness: 10,
                                color: Color(0xFFF0F2F5)),
                          ]);
                        },
                        childCount: docs.length,
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}