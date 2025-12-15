import 'dart:async';
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
  final String source;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostHidden;

  const CommentScreen({
    super.key,
    required this.post,
    this.source = "home",
    this.onPostDeleted,
    this.onPostHidden,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoadingName = true;
  String _currentUserName = "Bạn";
  final String _emptyMessage =
      "Chưa có bình luận nào... Hãy là người đầu tiên phá vỡ sự im lặng!";

  String? _replyingId;
  String? _replyingName;

  final Set<String> _expanded = {};

  bool _isPostActionPending = false;

  // For optimistic UI updates
  List<Comment> _comments = [];
  final Set<String> _deletedComments = {};

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    if (currentUser == null) return;
    final data = await _userService.loadUserData(currentUser!.uid);

    setState(() {
      _currentUserName =
          data?["displayName"] ?? currentUser!.email!.split("@")[0];
      _isLoadingName = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      // This will trigger the StreamBuilder to fetch the latest comments
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

  void _handlePostDeleted() {
    widget.onPostDeleted?.call();
    setState(() {
      _isPostActionPending = true;
    });
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _handlePostHidden() {
    widget.onPostHidden?.call();
    setState(() {
      _isPostActionPending = true;
    });
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parentId = _replyingId;

    FocusScope.of(context).unfocus();

    _controller.clear();
    setState(() {
      _replyingId = null;
      _replyingName = null;
    });

    await _postService.sendComment(
      widget.post.postId,
      text,
      _currentUserName,
      parentId: parentId,
    );
  }

  Future<void> _editComment(String commentId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa bình luận'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.trim().isNotEmpty && newContent != currentContent) {
      await _postService.updateComment(widget.post.postId, commentId, newContent.trim());
    }
  }

  void _replyTo(String id, String name) {
    setState(() {
      _replyingId = id;
      _replyingName = name;
      _expanded.add(id);
    });

    Future.delayed(const Duration(milliseconds: 80), () {
      _focusNode.requestFocus();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  Future<void> _deleteComment(String commentId) async {
    if (!mounted) return;

    // Optimistic deletion
    setState(() {
      _deletedComments.add(commentId);
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Đã xóa bình luận"),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await _postService.deleteComment(widget.post.postId, commentId);
    } catch (e) {
      // Revert if deletion fails
      setState(() {
        _deletedComments.remove(commentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Lỗi khi xóa bình luận"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _likeComment(String commentId) async {
    await _postService.toggleCommentLike(widget.post.postId, commentId);
  }

  @override
  Widget build(BuildContext context) {
    final String postOwner = widget.post.userId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Bình luận",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (!_isPostActionPending)
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(8),
                            child: PostCard(
                              post: widget.post,
                              showCommentButton: false,
                              showLikeButton: true,
                              source: widget.source,
                              onPostDeleted: _handlePostDeleted,
                              onPostHidden: _handlePostHidden,
                              onPostSaved: _onPostSaved,
                            ),
                          ),
                        Container(
                            height: 8,
                            width: double.infinity,
                            color: const Color(0xFFF0F2F5)),
                      ],
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _postService.getCommentsStream(widget.post.postId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      // Filter out optimistically deleted comments
                      final allDocs = snap.data!.docs
                          .where((doc) => !_deletedComments.contains(doc.id))
                          .toList();
                      _comments =
                          allDocs.map((e) => Comment.fromFirestore(e)).toList();

                      final parents = _comments
                          .where((c) => c.parentId == null)
                          .toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      final repliesMap = <String, List<Comment>>{};
                      for (final c in _comments.where((c) => c.parentId != null)) {
                        repliesMap.putIfAbsent(c.parentId!, () => []).add(c);
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final parent = parents[i];
                            final replies =
                                repliesMap[parent.commentId]?.toList() ?? [];
                            final expanded = _expanded.contains(parent.commentId);

                            final bool canDeleteParent = (currentUser != null) &&
                                (currentUser!.uid == postOwner ||
                                    currentUser!.uid == parent.userId);
                            final bool isPostAuthor = parent.userId == postOwner;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                cmt.CommentItem(
                                  comment: parent,
                                  replyCount: replies.length,
                                  showReplies: expanded,
                                  canDelete: canDeleteParent,
                                  isPostAuthor: isPostAuthor,
                                  onReply: _replyTo,
                                  onToggleReplies: _toggle,
                                  onDelete: _deleteComment,
                                  onEdit: _editComment,
                                  onLike: _likeComment,
                                ),
                                if (expanded)
                                  ...replies.map((r) {
                                    final bool canDeleteReply =
                                        (currentUser != null) &&
                                            (currentUser!.uid == postOwner ||
                                                currentUser!.uid == r.userId);
                                    final bool isReplyPostAuthor =
                                        r.userId == postOwner;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(left: 32),
                                      child: cmt.CommentItem(
                                        comment: r,
                                        replyCount: 0,
                                        showReplies: false,
                                        canDelete: canDeleteReply,
                                        isPostAuthor: isReplyPostAuthor,
                                        onReply: _replyTo,
                                        onDelete: _deleteComment,
                                        onEdit: _editComment,
                                        onLike: _likeComment,
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                          childCount: parents.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoadingName) _inputBox(),
        ],
      ),
    );
  }

  Widget _inputBox() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyingName != null)
              Row(
                children: [
                  Expanded(
                    child: Text("Đang trả lời $_replyingName",
                        style: const TextStyle(
                            color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _replyingId = null;
                        _replyingName = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  )
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                        hintText: "Viết bình luận...", border: InputBorder.none),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                IconButton(
                    onPressed: _sendComment,
                    icon: const Icon(Icons.send, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
