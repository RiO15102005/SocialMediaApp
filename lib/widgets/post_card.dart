import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showActions;

  const PostCard({
    super.key,
    required this.post,
    this.showActions = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _toggleLike() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích bài viết.')),
      );
      return;
    }
    try {
      await _postService.toggleLike(widget.post.postId, widget.post.likes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: ${e.toString()}')),
        );
      }
    }
  }

  void _openCommentsWithAnimation() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CommentScreen(post: widget.post),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideTween = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut));
          return SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const SizedBox.shrink();

    final bool isLiked =
        currentUser != null && widget.post.likes.contains(currentUser!.uid);
    final String postTime =
    widget.post.timestamp.toDate().toString().substring(0, 16);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin người đăng
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      postTime,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (currentUser?.uid == widget.post.userId)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await _postService.deletePost(
                          widget.post.postId,
                          widget.post.userId,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Xóa bài viết',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Nội dung bài đăng
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  widget.post.content,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),

            // Nút Thích và Bình luận
            if (widget.showActions) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: _toggleLike,
                    icon: Icon(
                      isLiked
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      color: isLiked
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    label: Text(
                      'Thích (${widget.post.likes.length})',
                      style: TextStyle(
                        color: isLiked
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openCommentsWithAnimation,
                    icon:
                    const Icon(Icons.comment_outlined, color: Colors.grey),
                    label: Text(
                      'Bình luận (${widget.post.commentsCount})',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
