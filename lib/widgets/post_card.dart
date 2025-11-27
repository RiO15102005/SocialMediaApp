import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showLikeButton;
  final bool showCommentButton;
  final String source; // "home" hoặc "profile"

  const PostCard({
    super.key,
    required this.post,
    this.showLikeButton = true,
    this.showCommentButton = true,
    this.source = "home",
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _expanded = false; // xem thêm/thu gọn

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
      // rollback nếu Firestore lỗi
      setState(() {
        isLiked ? widget.post.likes.add(uid) : widget.post.likes.remove(uid);
      });
    }
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentScreen(post: widget.post, source: widget.source)),
    );
  }

  Future<void> _confirmDeletePost() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Xóa bài viết?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Bạn có chắc chắn muốn xóa bài viết này không?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xóa", style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );

    if (confirm == true) {
      await _postService.deletePost(widget.post.postId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xóa thành công")));
      if (widget.source == "home") {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        currentUser != null && widget.post.likes.contains(currentUser!.uid);
    final String timeStr =
    widget.post.timestamp.toDate().toString().substring(0, 16);

    // Kiểu Facebook: font nhỏ, nội dung có xem thêm/thu gọn
    final bool longContent = widget.post.content.length > 140;
    final String displayContent = (!longContent || _expanded)
        ? widget.post.content
        : widget.post.content.substring(0, 140) + '...';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
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
              if (currentUser?.uid == widget.post.userId)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (value) async {
                    if (value == "delete") {
                      await _confirmDeletePost();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: "delete",
                      child: Text("Xóa bài viết", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 8),

          // CONTENT + Xem thêm/Thu gọn
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

          // ACTIONS
          Row(
            children: [
              // LIKE BUTTON (kiểu Facebook)
              if (widget.showLikeButton)
                Expanded(
                  child: InkWell(
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
                ),

              // COMMENT BUTTON + COUNT
              if (widget.showCommentButton)
                Expanded(
                  child: InkWell(
                    onTap: _openComments,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                ),
            ],
          ),
        ],
      ),
    );
  }
}
