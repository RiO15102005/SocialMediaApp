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
  final String _emptyMessage = "Nơi này thật yên tĩnh... Hãy phá vỡ sự im lặng này!";

  final Map<String, String> _pendingActions = {}; // postId -> 'hide' or 'delete'
  final Map<String, Timer> _pendingTimers = {};
  final Set<String> _sessionHiddenPosts = {};
  List<Post> _allPosts = []; // Keep a state copy of posts to avoid loading indicators on refresh

  @override
  void initState() {
    super.initState();
    _friendsListFuture = _userService.getCurrentUserFriendsList();
  }

  @override
  void dispose() {
    _clearPendingActions(commit: true);
    super.dispose();
  }

  void _commitAction(String postId, String action) {
    if (action == 'delete') {
      _postService.deletePost(postId);
    } else if (action == 'hide') {
      _sessionHiddenPosts.add(postId);
    }
    if (mounted) {
      setState(() {
        _pendingActions.remove(postId);
        _pendingTimers.remove(postId);
      });
    }
  }

  void _clearPendingActions({bool commit = false}) {
    final actionsToCommit = Map<String, String>.from(_pendingActions);

    for (var timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();

    if (mounted) {
      setState(() {
        _pendingActions.clear();
      });
    }

    if (commit) {
      actionsToCommit.forEach((postId, action) {
        if (action == 'delete') {
          _postService.deletePost(postId);
        } else if (action == 'hide') {
          _sessionHiddenPosts.add(postId);
        }
      });
    }
  }

  Future<void> _refresh() async {
    _clearPendingActions(commit: true);
    if (mounted) {
      setState(() {
        _friendsListFuture = _userService.getCurrentUserFriendsList();
      });
      await _friendsListFuture;
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
          content: Text(isSaved ? "Đã lưu bài viết" : "Đã bỏ lưu bài viết"),
          duration: const Duration(seconds: 2),
        ),
      );
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
            if (friendSnap.connectionState == ConnectionState.waiting && _allPosts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (friendSnap.hasError) {
              return const Center(child: Text("Không thể tải danh sách bạn bè."));
            }

            final allowedUIDs = List<String>.from(friendSnap.data ?? []);
            if (!allowedUIDs.contains(currentUser!.uid)) {
              allowedUIDs.add(currentUser!.uid);
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _postService.getAllPostsStream(),
              builder: (context, postSnap) {
                if (postSnap.connectionState == ConnectionState.waiting && _allPosts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (postSnap.hasError) {
                  return Center(child: Text("Lỗi khi tải bài viết: ${postSnap.error}"));
                }
                if (postSnap.hasData) {
                  _allPosts = (postSnap.data?.docs ?? []).map((doc) => Post.fromFirestore(doc)).toList();
                }

                final visiblePosts = _allPosts.where((post) {
                  return allowedUIDs.contains(post.userId) &&
                         !post.isDeleted &&
                         !_sessionHiddenPosts.contains(post.postId);
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
                  itemCount: _allPosts.length,
                  itemBuilder: (context, index) {
                    final post = _allPosts[index];
                    final action = _pendingActions[post.postId];

                    if (action != null) {
                      return _buildUndoBanner(
                        action == 'delete' ? 'Đã xóa bài viết.' : 'Đã ẩn bài viết.',
                        () => _undoPostAction(post.postId),
                      );
                    }
                    
                    if (post.isDeleted ||
                        _sessionHiddenPosts.contains(post.postId) ||
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
