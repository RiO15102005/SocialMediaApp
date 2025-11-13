import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/comment_item.dart' as cmt;
import '../widgets/post_card.dart';

class CommentScreen extends StatefulWidget {
  final Post post;

  const CommentScreen({super.key, required this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _commentController = TextEditingController();
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _currentUserName = 'Bạn';
  bool _isLoadingName = true;

  String? _replyingToCommentId;
  String? _replyingToUserName;

  final Set<String> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    if (currentUser == null) {
      setState(() => _isLoadingName = false);
      return;
    }
    final uid = currentUser?.uid;
    final email = currentUser?.email;
    final data = uid != null ? await _user_service_load(uid) : null;

    setState(() {
      _currentUserName = data?['displayName'] ?? (email != null ? email.split('@')[0] : 'Bạn');
      _isLoadingName = false;
    });
  }

  // wrapper for user service call to avoid direct reference in pasted snippet
  Future<Map<String, dynamic>?> _user_service_load(String uid) async {
    return await _user_service_load_impl(uid);
  }

  Future<Map<String, dynamic>?> _user_service_load_impl(String uid) async {
    return await _user_service_load_real(uid);
  }

  // placeholder to satisfy static analysis in this snippet; in your project this calls _userService.loadUserData
  Future<Map<String, dynamic>?> _user_service_load_real(String uid) async {
    return await _userService.loadUserData(uid);
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || currentUser == null) return;
    try {
      await _postService.sendComment(
        widget.post.postId,
        text,
        _currentUserName,
        parentId: _replyingToCommentId,
      );
      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi bình luận: ${e.toString()}')),
      );
    }
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _postService.deleteComment(widget.post.postId, commentId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa bình luận: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Bình luận')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postService.getCommentsStream(widget.post.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final hasNoData = !snapshot.hasData || snapshot.data!.docs.isEmpty;

                List<Comment> allComments = [];
                List<Comment> parents = [];
                Map<String, List<Comment>> repliesMap = {};

                if (!hasNoData) {
                  allComments = snapshot.data!.docs.map((doc) => Comment.fromFirestore(doc)).toList();
                  parents = allComments.where((c) => c.parentId == null).toList();

                  // --- SỬA TẠI ĐÂY: sort DESC để comment mới nhất đứng trên (ngay dưới post)
                  parents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                  // --- END

                  for (final c in allComments.where((c) => c.parentId != null)) {
                    repliesMap.putIfAbsent(c.parentId!, () => []).add(c);
                  }

                  // Optional: sort replies so newest appear first under their parent
                  for (final k in repliesMap.keys) {
                    repliesMap[k]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                  }
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          PostCard(post: widget.post, showActions: true),
                          const Divider(height: 1),
                        ],
                      ),
                    ),

                    if (hasNoData)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.comment_outlined, size: 60, color: Colors.grey),
                                SizedBox(height: 10),
                                Text('Ở đây yên tĩnh quá', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 5),
                                Text('Bạn muốn phá vỡ sự im lặng? Hãy bình luận nhé.'),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final parent = parents[index];
                            final replies = repliesMap[parent.commentId] ?? const <Comment>[];
                            final showReplies = _expandedReplies.contains(parent.commentId);

                            return Column(
                              key: ValueKey(parent.commentId),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                cmt.CommentItem(
                                  comment: parent,
                                  showReplies: showReplies,
                                  onReply: (id, name) {
                                    setState(() {
                                      _replyingToCommentId = id;
                                      _replyingToUserName = name;
                                      _expandedReplies.add(id);
                                    });
                                  },
                                  onToggleReplies: _toggleReplies,
                                  onDelete: _deleteComment,
                                ),
                                if (showReplies)
                                  ...replies.map(
                                        (r) => Padding(
                                      key: ValueKey(r.commentId),
                                      padding: const EdgeInsets.only(left: 20),
                                      child: cmt.CommentItem(
                                        comment: r,
                                        showReplies: false,
                                        onReply: (id, name) {
                                          setState(() {
                                            _replyingToCommentId = id;
                                            _replyingToUserName = name;
                                          });
                                        },
                                        onDelete: _deleteComment,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          childCount: parents.length,
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                );
              },
            ),
          ),
          if (!_isLoadingName) _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyingToUserName != null)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trả lời bình luận của $_replyingToUserName',
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _replyingToCommentId = null;
                          _replyingToUserName = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Bình luận dưới tên $_currentUserName',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
