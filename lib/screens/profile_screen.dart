import 'dart:async';
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
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  late String _targetUserId;
  late bool _isMyProfile;
  final String _emptyPostMessage = "This place is quiet... Let's break the silence!";
  final String _emptySavedMessage = "You haven't saved any posts yet!";

  File? _avatarImage;
  File? _coverImage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final uid = currentUser?.uid ?? '';
    _targetUserId = widget.userId ?? uid;
    _isMyProfile = (_targetUserId == uid);
    _tabController = TabController(length: _isMyProfile ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPostSaved() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bài viết đã được lưu!")),
      );
    }
  }

  Future<void> _addPost() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bài viết mới đã được đăng!')));
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
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
      backgroundColor: Colors.white,
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
        stream: FirebaseFirestore.instance.collection('users').doc(_targetUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
            return const Center(child: Text("Không thể tải dữ liệu người dùng."));
          }

          final userData = userSnapshot.data!.data()!;
          final friendsCount = (userData['friends'] as List?)?.length ?? 0;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ProfileCover(
                        coverImage: _coverImage != null ? FileImage(_coverImage!) : null,
                        isMyProfile: _isMyProfile,
                        onPickCover: () {}
                    ),
                    ProfileAvatar(
                        avatarImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                        isMyProfile: _isMyProfile,
                        onPickAvatar: () {}
                    ),
                    ProfileInfo(
                        displayName: userData['displayName'] ?? 'Người dùng',
                        bio: userData['bio'] ?? 'Chưa có thông tin giới thiệu',
                        friendsCount: friendsCount,
                        onFriendsTap: () {
                          if (friendsCount > 0) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsScreen(userId: _targetUserId)));
                          }
                        }
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _isMyProfile
                          ? Row(
                        children: [
                          Expanded(child: AddPostButton(onAddPost: _addPost)),
                          const SizedBox(width: 10),
                          Expanded(child: ActionButton(isMyProfile: true, targetUserId: _targetUserId)),
                        ],
                      )
                          : ActionButton(isMyProfile: false, targetUserId: _targetUserId),
                    ),
                    const SizedBox(height: 20),
                    if (_isMyProfile)
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Bài viết'),
                          Tab(text: 'Đã lưu'),
                        ],
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                      ),
                  ],
                ),
              ),
            ],
            body: _isMyProfile
                ? TabBarView(
              controller: _tabController,
              children: [
                _buildPostsView(),
                _buildSavedPostsView(),
              ],
            )
                : _buildPostsView(),
          );
        },
      ),
    );
  }

  Widget _buildPostsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getUserPostsStream(_targetUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Lỗi khi tải bài viết."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final posts = docs.map((doc) => Post.fromFirestore(doc)).toList();

        if (posts.isEmpty) {
          return Center(child: Text(_emptyPostMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post, onPostSaved: _onPostSaved, source: 'profile');
          },
        );
      },
    );
  }

  Widget _buildSavedPostsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getSavedPostsStream(currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Lỗi khi tải bài viết đã lưu: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text(_emptySavedMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)));
        }

        // Sort posts on the client-side
        final posts = docs.map((doc) => Post.fromFirestore(doc)).toList();
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post, onPostSaved: _onPostSaved, source: 'profile');
          },
        );
      },
    );
  }
}
