import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/post_model.dart';
import '../screens/likes_screen.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';
import '../screens/share_post_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showLikeButton;
  final bool showCommentButton;
  final String source;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onPostHidden;
  final ValueChanged<bool>? onPostSaved;

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
    final uid = currentUser!.uid;
    final isCurrentlySaved = widget.post.savers.contains(uid);
    final bool newSaveState = !isCurrentlySaved;

    setState(() {
      if (newSaveState) {
        widget.post.savers.add(uid);
      } else {
        widget.post.savers.remove(uid);
      }
    });

    widget.onPostSaved?.call(newSaveState);

    try {
      await _postService.toggleSavePost(widget.post.postId);
    } catch (_) {
      setState(() {
        if (newSaveState) {
          widget.post.savers.remove(uid);
        } else {
          widget.post.savers.add(uid);
        }
      });
      widget.onPostSaved?.call(isCurrentlySaved);
    }
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

  void _openShareSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: SharePostScreen(post: widget.post),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã chia sẻ bài viết này.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLikes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: LikesScreen(userIds: widget.post.likes),
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
    final int likeCount = widget.post.likes.length;

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
            children: [
              if (widget.showLikeButton)
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleLike,
                ),
              if (likeCount > 0)
                Text(
                  '$likeCount',
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(width: 16),
              if (widget.showCommentButton)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey),
                  onPressed: _openComments,
                ),
              if (widget.post.commentsCount > 0)
                Text(
                  '${widget.post.commentsCount}',
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.near_me_outlined, color: Colors.grey),
                onPressed: _openShareSheet,
              ),
              if (widget.post.shares > 0)
                Text(
                  '${widget.post.shares}',
                  style: const TextStyle(color: Colors.grey),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? Theme.of(context).primaryColor : Colors.grey,
                  weight: isSaved ? 700 : 400,
                ),
                onPressed: _toggleSave,
              ),
            ],
          ),
          if (isLiked && likeCount > 1)
            GestureDetector(
              onTap: _showLikes,
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                child: Text(
                  '${isLiked ? 'Bạn và ' : ''}${likeCount - 1} người khác đã thích',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
