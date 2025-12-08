import 'dart:async';
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
  final String _emptyMessage = "This place is quiet... Let's break the silence!";

  // State for managing inline undo actions
  final Map<String, String> _pendingActions = {}; // postId -> 'hide' or 'delete'
  final Map<String, Timer> _pendingTimers = {};

  @override
  void initState() {
    super.initState();
    _friendsListFuture = _userService.getCurrentUserFriendsList();
  }

  @override
  void dispose() {
    // Cancel all timers when the screen is disposed
    for (var timer in _pendingTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    // Clear pending actions on refresh
    _clearPendingActions();
    setState(() {
      _friendsListFuture = _userService.getCurrentUserFriendsList();
    });
  }

  void _clearPendingActions() {
    for (var timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    setState(() {
      _pendingActions.clear();
    });
  }

  void _handlePostAction(String postId, String action) {
    if (!mounted) return;

    // Cancel any existing timer for this post
    _pendingTimers[postId]?.cancel();

    // Set the pending action to show the inline banner
    setState(() {
      _pendingActions[postId] = action;
    });

    // Start a timer to commit the action after 5 seconds
    final timer = Timer(const Duration(seconds: 5), () {
      if (_pendingActions.containsKey(postId)) {
        if (action == 'delete') {
          _postService.deletePost(postId);
        } else if (action == 'hide') {
          _postService.hidePost(postId);
        }
        _pendingActions.remove(postId);
        _pendingTimers.remove(postId);
        // No need to call setState, the stream will update the UI
      }
    });

    _pendingTimers[postId] = timer;
  }

  void _undoPostAction(String postId) {
    if (!mounted) return;

    // Cancel the timer
    _pendingTimers[postId]?.cancel();
    _pendingTimers.remove(postId);

    // Remove the pending action to restore the post
    setState(() {
      _pendingActions.remove(postId);
    });
  }

  void _onPostSaved() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post saved!")),
      );
    }
  }

  Widget _buildUndoBanner(String message, VoidCallback onUndo) {
    return Container(
      key: UniqueKey(),
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(message, style: const TextStyle(color: Colors.white)),
          TextButton(
            onPressed: onUndo,
            child: const Text('Undo', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
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
            if (friendSnap.hasError || !friendSnap.hasData) {
              return const Center(child: Text("Không thể tải danh sách bạn bè."));
            }

            final allowedUIDs = List<String>.from(friendSnap.data!);
            if (!allowedUIDs.contains(currentUser!.uid)) {
              allowedUIDs.add(currentUser!.uid);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _postService.getAllPostsStream(),
              builder: (context, postSnap) {
                if (postSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (postSnap.hasError || !postSnap.hasData) {
                  return Center(child: Text("Lỗi khi tải bài viết: ${postSnap.error}"));
                }

                final docs = postSnap.data!.docs;
                final posts = docs.map((doc) => Post.fromFirestore(doc)).toList();

                final visiblePosts = posts.where((post) {
                  return allowedUIDs.contains(post.userId) &&
                         !post.isDeleted &&
                         !post.isHidden &&
                         !_pendingActions.containsKey(post.postId);
                }).toList();

                if (visiblePosts.isEmpty && _pendingActions.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Text(
                            _emptyMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final action = _pendingActions[post.postId];

                    if (action != null) {
                      return _buildUndoBanner(
                        action == 'delete' ? 'Đã xóa bài viết.' : 'Đã ẩn bài viết.',
                        () => _undoPostAction(post.postId),
                      );
                    } else if (post.isDeleted ||
                        post.isHidden ||
                        !allowedUIDs.contains(post.userId)) {
                      return const SizedBox.shrink();
                    }

                    return PostCard(
                      key: ValueKey(post.postId),
                      post: post,
                      source: "home",
                      onPostDeleted: () => _handlePostAction(post.postId, 'delete'),
                      onPostHidden: () => _handlePostAction(post.postId, 'hide'),
                      onPostSaved: _onPostSaved,
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
