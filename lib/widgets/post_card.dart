import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showLikeButton;
  final bool showCommentButton;

  const PostCard({
    super.key,
    required this.post,
    this.showLikeButton = true,
    this.showCommentButton = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

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

  // =====================================
  // ⭐ MỞ COMMENT
  // =====================================
  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentScreen(post: widget.post)),
    );
  }

  // =====================================
  // ⭐ XÓA BÀI VIẾT — CÓ XÁC NHẬN
  // =====================================
  Future<void> _confirmDeletePost() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Xóa bài viết?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Bạn có chắc chắn muốn xóa bài viết này không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Hủy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Xóa",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _postService.deletePost(widget.post.postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        currentUser != null && widget.post.likes.contains(currentUser!.uid);

    final String timeStr =
    widget.post.timestamp.toDate().toString().substring(0, 16);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ================= HEADER =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 24,
                child: Icon(Icons.person, size: 22),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // ================= XÓA BÀI =================
              if (currentUser?.uid == widget.post.userId)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 22),
                  onSelected: (value) async {
                    if (value == "delete") {
                      await _confirmDeletePost();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: "delete",
                      child: Text(
                        "Xóa bài viết",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ================= CONTENT =================
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                widget.post.content,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),

          const SizedBox(height: 14),

          // ================= ACTIONS =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // LIKE BUTTON
                if (widget.showLikeButton)
                  Expanded(
                    child: InkWell(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color:
                            isLiked ? const Color(0xFF1877F2) : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Thích (${widget.post.likes.length})",
                            style: TextStyle(
                              fontSize: 14,
                              color: isLiked
                                  ? const Color(0xFF1877F2)
                                  : Colors.grey,
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
                          const Icon(Icons.chat_bubble_outline,
                              size: 20, color: Colors.grey),
                          const SizedBox(width: 6),

                          // ⭐ HIỂN THỊ SỐ BÌNH LUẬN ⭐
                          Text(
                            "Bình luận (${widget.post.commentsCount})",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
