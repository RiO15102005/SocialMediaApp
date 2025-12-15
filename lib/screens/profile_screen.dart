import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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
import '../services/upload_profile.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final PostService _postService = PostService();

  late String _targetUserId;
  late bool _isMyProfile;

  File? _avatarImage;
  File? _coverImage;

  late TabController _tabController;

  final String _emptyPostMessage = "Chưa có bài viết nào.";
  final String _emptySavedMessage = "Bạn chưa lưu bài viết nào!";

  @override
  void initState() {
    super.initState();

    final uid = currentUser?.uid ?? '';
    _targetUserId = widget.userId ?? uid;
    _isMyProfile = (_targetUserId == uid);

    _tabController = TabController(length: _isMyProfile ? 2 : 1, vsync: this);
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    final url = await AvatarUploadService.uploadAvatar(
      picked.path,
      currentUser!.uid,
    );

    if (url != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser!.uid)
          .update({"avatar": url});

      setState(() => _avatarImage = File(picked.path));
    }
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    final url = await AvatarUploadService.uploadCover(
      picked.path,
      currentUser!.uid,
    );

    if (url != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser!.uid)
          .update({"cover": url});

      setState(() => _coverImage = File(picked.path));
    }
  }

  void _onPostSaved(bool isSaved) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(isSaved ? "Bài viết đã được lưu!" : "Đã bỏ lưu bài viết."),
      ),
    );

    if (!isSaved && _isMyProfile && _tabController.index == 1) {
      setState(() {});
    }
  }

  Future<void> _addPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );

    if (result == true) setState(() {});
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Vui lòng đăng nhập.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        actions: _isMyProfile
            ? [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white), 
            onSelected: (v) {
              if (v == "logout") _logout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "logout",
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Đăng xuất",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            .collection("users")
            .doc(_targetUserId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snap.data!.data()!;
          final friendsCount = (userData["friends"] as List?)?.length ?? 0;

          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ProfileCover(
                      coverImage: _coverImage != null
                          ? FileImage(_coverImage!)
                      as ImageProvider<Object>
                          : (userData["cover"] != null
                          ? NetworkImage(userData["cover"])
                      as ImageProvider<Object>
                          : null),
                      isMyProfile: _isMyProfile,
                      onPickCover: _pickCover,
                    ),

                    ProfileAvatar(
                      avatarImage: _avatarImage != null
                          ? FileImage(_avatarImage!)
                      as ImageProvider<Object>
                          : (userData["avatar"] != null
                          ? NetworkImage(userData["avatar"])
                      as ImageProvider<Object>
                          : null),
                      isMyProfile: _isMyProfile,
                      onPickAvatar: _pickAvatar,
                    ),

                    ProfileInfo(
                      displayName:
                      userData["displayName"] ?? "Người dùng",
                      bio: userData["bio"] ?? "Chưa có mô tả",
                      friendsCount: friendsCount,
                      onFriendsTap: () {
                        if (friendsCount > 0) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FriendsScreen(userId: _targetUserId)),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _isMyProfile
                          ? Row(
                        children: [
                          Expanded(
                            child: AddPostButton(onAddPost: _addPost),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ActionButton(
                              isMyProfile: true,
                              targetUserId: _targetUserId,
                            ),
                          ),
                        ],
                      )
                          : ActionButton(
                        isMyProfile: false,
                        targetUserId: _targetUserId,
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (_isMyProfile)
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: "Bài viết"),
                          Tab(text: "Đã lưu"),
                        ],
                        labelColor: Colors.black,
                      ),
                  ],
                ),
              )
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
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final posts = snap.data!.docs
            .map((e) => Post.fromFirestore(e))
            .where((e) => !e.isDeleted && e.content.isNotEmpty)
            .toList();

        if (posts.isEmpty)
          return Center(child: Text(_emptyPostMessage));

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (_, i) => PostCard(
            post: posts[i],
            onPostSaved: _onPostSaved,
            source: "profile",
          ),
        );
      },
    );
  }

  Widget _buildSavedPostsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getSavedPostIdsStream(currentUser!.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(child: Text(_emptySavedMessage));
        }

        final savedPostIds = snap.data!.docs.map((doc) => doc.id).toList();

        return FutureBuilder<List<Post>>(
          future: _postService.getPostsFromPostIds(savedPostIds),
          builder: (context, postSnap) {
            if (postSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!postSnap.hasData || postSnap.data!.isEmpty) {
              return Center(child: Text(_emptySavedMessage));
            }

            final posts = postSnap.data!;

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (_, i) => PostCard(
                post: posts[i],
                onPostSaved: _onPostSaved,
                source: "profile",
              ),
            );
          },
        );
      },
    );
  }
}
