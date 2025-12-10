// lib/screens/profile_screen.dart

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
  late String _emptyPostMessage;
  final String _emptySavedMessage = "Bạn chưa lưu bài viết nào.";
  final String _emptyRepostMessage = "Chưa có bài viết nào được đăng lại.";

  File? _avatarImage;
  File? _coverImage;

  late TabController _tabController;

  final Map<String, String> _pendingActions = {}; // postId -> 'hide' or 'delete'
  final Map<String, Timer> _pendingTimers = {};
  final Set<String> _sessionHiddenPosts = {};
  List<Post> allPosts = [];

  @override
  void initState() {
    super.initState();
    final uid = currentUser?.uid ?? '';
    _targetUserId = widget.userId ?? uid;
    _isMyProfile = (_targetUserId == uid);
    _tabController = TabController(length: _isMyProfile ? 3 : 2, vsync: this);

    if (_isMyProfile) {
      _emptyPostMessage = "Chưa có bài viết nào để hiển thị.";
    } else {
      _emptyPostMessage = "Người dùng này chưa đăng bài viết nào.";
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clearPendingActions(commit: true);
    super.dispose();
  }

  void _clearPendingActions({bool commit = false}) {
    if (commit) {
      _pendingTimers.forEach((postId, timer) {
        timer.cancel();
        final action = _pendingActions[postId];
        if (action != null) {
          if (action == 'delete') {
            _postService.deletePost(postId);
          } else if (action == 'hide') {
            _sessionHiddenPosts.add(postId);
          }
        }
      });
    } else {
      for (var timer in _pendingTimers.values) {
        timer.cancel();
      }
    }
    
    _pendingTimers.clear();
    if (mounted) {
      setState(() {
        _pendingActions.clear();
      });
    }
  }

  void _commitAction(String postId, String action) {
    if (action == 'delete') {
      _postService.deletePost(postId);
    } else if (action == 'hide') {
      _sessionHiddenPosts.add(postId);
    }
    if(mounted){
      setState(() {
        _pendingActions.remove(postId);
        _pendingTimers.remove(postId);
      });
    }
  }

  Future<void> _refresh() async {
    _clearPendingActions(commit: true);
    if (mounted) {
      setState(() {
        // This will trigger the stream builders to rebuild
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _handlePostAction(String postId, String action) {
    if (!mounted) return;

    _pendingTimers[postId]?.cancel();

    setState(() {
      _pendingActions[postId] = action;
    });

    final timer = Timer(const Duration(seconds: 5), () {
      if (_pendingActions.containsKey(postId)) {
        _commitAction(postId, action);
      }
    });

    _pendingTimers[postId] = timer;
  }

  void _undoPostAction(String postId) {
    if (!mounted) return;

    _pendingTimers[postId]?.cancel();
    _pendingTimers.remove(postId);

    setState(() {
      _pendingActions.remove(postId);
    });
  }

  void _onPostSaved(bool isSaved) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved ? "Bài viết đã được lưu!" : "Đã bỏ lưu bài viết."),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey[800],
        ),
      );
      if (!isSaved && _tabController.index == 1) {
        setState(() {});
      }
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

  Widget _buildUndoBanner(String message, VoidCallback onUndo) {
    return Container(
      key: UniqueKey(),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(message, style: const TextStyle(color: Colors.black87)),
          TextButton(
            onPressed: onUndo,
            child: const Text('Hoàn tác', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
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
                        onPickCover: () {}),
                    ProfileAvatar(
                        avatarImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                        isMyProfile: _isMyProfile,
                        onPickAvatar: () {}),
                    ProfileInfo(
                        displayName: userData['displayName'] ?? 'Người dùng',
                        bio: userData['bio'] ?? 'Chưa có thông tin giới thiệu',
                        friendsCount: friendsCount,
                        onFriendsTap: () {
                          if (friendsCount > 0) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsScreen(userId: _targetUserId)));
                          }
                        }),
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
                    TabBar(
                      controller: _tabController,
                      tabs: _isMyProfile
                          ? const [
                        Tab(text: 'Bài viết'),
                        Tab(text: 'Đã lưu'),
                        Tab(text: 'Đã đăng lại'),
                      ]
                          : const [
                        Tab(text: 'Bài viết'),
                        Tab(text: 'Đã đăng lại'),
                      ],
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: _isMyProfile
                  ? [
                _buildPostsView(),
                _buildSavedPostsView(),
                _buildRepostsView(),
              ]
                  : [
                _buildPostsView(),
                _buildRepostsView(),
              ],
            ),
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

        allPosts = (snapshot.data?.docs ?? []).map((doc) => Post.fromFirestore(doc)).toList();

        final visiblePosts = allPosts.where((p) => 
          !p.isDeleted && 
          !_sessionHiddenPosts.contains(p.postId) &&
          !_pendingActions.containsKey(p.postId)
        ).toList();

        if (visiblePosts.isEmpty && _pendingActions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(_emptyPostMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: allPosts.length,
            itemBuilder: (context, index) {
              final post = allPosts[index];
              final action = _pendingActions[post.postId];

              if (action != null) {
                return _buildUndoBanner(
                  action == 'delete' ? 'Đã xóa bài viết.' : 'Đã ẩn bài viết.',
                  () => _undoPostAction(post.postId),
                );
              }

              if (post.isDeleted || _sessionHiddenPosts.contains(post.postId)) {
                return const SizedBox.shrink();
              }

              return PostCard(
                key: ValueKey(post.postId),
                post: post,
                onPostSaved: _onPostSaved,
                onPostDeleted: () => _handlePostAction(post.postId, 'delete'),
                onPostHidden: () => _handlePostAction(post.postId, 'hide'),
                source: 'profile',
              );
            },
          ),
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

        allPosts = (snapshot.data?.docs ?? []).map((doc) => Post.fromFirestore(doc)).toList();
        
        allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final visiblePosts = allPosts.where((p) => 
          !p.isDeleted && 
          !_sessionHiddenPosts.contains(p.postId) &&
          !_pendingActions.containsKey(p.postId)
        ).toList();

        if (visiblePosts.isEmpty && _pendingActions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_emptySavedMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: allPosts.length,
            itemBuilder: (context, index) {
              final post = allPosts[index];
               final action = _pendingActions[post.postId];

              if (action != null) {
                return _buildUndoBanner(
                  action == 'delete' ? 'Đã xóa bài viết.' : 'Đã ẩn bài viết.',
                  () => _undoPostAction(post.postId),
                );
              }

              if (post.isDeleted || _sessionHiddenPosts.contains(post.postId)) {
                return const SizedBox.shrink();
              }
              
              return PostCard(
                key: ValueKey(post.postId),
                post: post,
                onPostSaved: _onPostSaved,
                onPostDeleted: () => _handlePostAction(post.postId, 'delete'),
                onPostHidden: () => _handlePostAction(post.postId, 'hide'),
                source: 'profile',
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRepostsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getRepostedPostsStream(_targetUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Lỗi khi tải bài viết đã đăng lại."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        allPosts = (snapshot.data?.docs ?? []).map((doc) => Post.fromFirestore(doc)).toList();
        allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final visiblePosts = allPosts.where((p) => 
          !p.isDeleted && 
          !_sessionHiddenPosts.contains(p.postId) &&
          !_pendingActions.containsKey(p.postId)
        ).toList();

        if (visiblePosts.isEmpty && _pendingActions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_emptyRepostMessage, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
          );
        }
        

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: allPosts.length,
            itemBuilder: (context, index) {
              final post = allPosts[index];
              final action = _pendingActions[post.postId];

              if (action != null) {
                return _buildUndoBanner(
                  action == 'delete' ? 'Đã xóa bài viết.' : 'Đã ẩn bài viết.',
                  () => _undoPostAction(post.postId),
                );
              }

              if (post.isDeleted || _sessionHiddenPosts.contains(post.postId)) {
                return const SizedBox.shrink();
              }
              
              return PostCard(
                key: ValueKey(post.postId),
                post: post,
                onPostSaved: _onPostSaved,
                onPostDeleted: () => _handlePostAction(post.postId, 'delete'),
                onPostHidden: () => _handlePostAction(post.postId, 'hide'),
                source: 'profile',
              );
            },
          ),
        );
      },
    );
  }
}
