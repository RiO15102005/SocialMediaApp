import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showLikeButton;
  final bool showCommentButton;
  final String source;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostHidden;
  final VoidCallback? onPostSaved;

  const PostCard({
    super.key,
    required this.post,
    this.showLikeButton = true,
    this.showCommentButton = true,
    this.source = "home",
    this.onPostDeleted,
    this.onPostHidden,
    this.onPostSaved,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _expanded = false;

  Future<void> _toggleLike() async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final isLiked = widget.post.likes.contains(uid);

    setState(() {
      isLiked ? widget.post.likes.remove(uid) : widget.post.likes.add(uid);
    });

    try {
      await _postService.toggleLike(widget.post.postId);
    } catch (_) {
      setState(() {
        isLiked ? widget.post.likes.add(uid) : widget.post.likes.remove(uid);
      });
    }
  }

  Future<void> _toggleSave() async {
    if (currentUser == null) return;
    await _postService.toggleSavePost(widget.post.postId);
    widget.onPostSaved?.call();
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentScreen(
          post: widget.post,
          source: widget.source,
          onPostDeleted: widget.onPostDeleted,
          onPostHidden: widget.onPostHidden,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays < 7) {
      if (difference.inHours > 0) {
        return "${difference.inHours} giờ trước";
      } else if (difference.inMinutes > 0) {
        return "${difference.inMinutes} phút trước";
      } else {
        return "Vừa xong";
      }
    } else {
      return DateFormat('dd/MM').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.isHidden || widget.post.isDeleted) {
      return const SizedBox.shrink();
    }
    final bool isLiked = currentUser != null && widget.post.likes.contains(currentUser!.uid);
    final bool isSaved = currentUser != null && widget.post.savers.contains(currentUser!.uid);
    final String timeStr = _formatTimestamp(widget.post.timestamp.toDate());

    final bool longContent = widget.post.content.length > 140;
    final String displayContent =
        (!longContent || _expanded) ? widget.post.content : widget.post.content.substring(0, 140) + '...';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(radius: 20, child: Icon(Icons.person, size: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.post.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, size: 20),
                onSelected: (value) {
                  if (value == "delete") {
                    widget.onPostDeleted?.call();
                  } else if (value == "hide") {
                    widget.onPostHidden?.call();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: "hide",
                    child: Text("Ẩn bài viết"),
                  ),
                  if (currentUser?.uid == widget.post.userId)
                    const PopupMenuItem(
                      value: "delete",
                      child: Text("Xóa bài viết", style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayContent,
                    style: const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.black87),
                  ),
                  if (longContent)
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        _expanded ? "Thu gọn" : "Xem thêm",
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1877F2)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.showLikeButton)
                InkWell(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: isLiked ? const Color(0xFF1877F2) : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Thích (${widget.post.likes.length})",
                        style: TextStyle(
                          fontSize: 13,
                          color: isLiked ? const Color(0xFF1877F2) : Colors.grey,
                          fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.showCommentButton)
                InkWell(
                  onTap: _openComments,
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      const Text(
                        "Bình luận",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "(${widget.post.commentsCount})",
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: _toggleSave,
                child: Row(
                  children: [
                    Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? const Color(0xFF1877F2) : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Lưu",
                      style: TextStyle(
                        fontSize: 13,
                        color: isSaved ? const Color(0xFF1877F2) : Colors.grey,
                        fontWeight: isSaved ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
