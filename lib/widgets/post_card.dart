import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/post_model.dart';
import '../screens/create_post_screen.dart';
import '../screens/likes_screen.dart';
import '../services/post_service.dart';
import '../screens/comment_screen.dart';
import '../screens/share_post_screen.dart';
import '../screens/profile_screen.dart';

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

  void _navigateToProfile(String userId) {
    final currentProfile =
    context.findAncestorWidgetOfExactType<ProfileScreen>();
    if (currentProfile != null && currentProfile.userId == userId) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final isLiked = widget.post.likes.contains(uid);

    setState(() {
      isLiked
          ? widget.post.likes.remove(uid)
          : widget.post.likes.add(uid);
    });

    try {
      await _postService.toggleLike(widget.post.postId);
    } catch (_) {
      setState(() {
        isLiked
            ? widget.post.likes.add(uid)
            : widget.post.likes.remove(uid);
      });
    }
  }

  Future<void> _toggleSave() async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final isSaved = widget.post.savers.contains(uid);

    setState(() {
      isSaved
          ? widget.post.savers.remove(uid)
          : widget.post.savers.add(uid);
    });

    widget.onPostSaved?.call(!isSaved);

    try {
      await _postService.toggleSavePost(widget.post.postId);
    } catch (_) {
      setState(() {
        isSaved
            ? widget.post.savers.add(uid)
            : widget.post.savers.remove(uid);
      });
      widget.onPostSaved?.call(isSaved);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SharePostScreen(
        post: widget.post,
      ),
    );

    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'reposted'
              ? 'Đã chia sẻ bài viết.'
              : 'Đã gửi bài viết cho bạn bè.',
        ),
      ),
    );
  }

  void _showLikes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: LikesScreen(userIds: widget.post.likes),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(widget.post),
          const SizedBox(height: 8),
          _buildContent(widget.post),
          const SizedBox(height: 8),
          _buildActions(widget.post),
          _buildLikesContext(widget.post),
        ],
      ),
    );
  }

  Widget _buildHeader(Post post, {bool showActions = true}) {
    final isMine = currentUser?.uid == post.userId;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateToProfile(post.userId),
          child: CircleAvatar(
            radius: 20,
            backgroundImage:
            post.userAvatar?.isNotEmpty == true
                ? NetworkImage(post.userAvatar!)
                : null,
            child: post.userAvatar?.isEmpty ?? true
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToProfile(post.userId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                Text(
                  _formatTime(post.timestamp.toDate()),
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        if (showActions)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) async {
              if (v == 'delete') widget.onPostDeleted?.call();
              if (v == 'hide') widget.onPostHidden?.call();
              if (v == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePostScreen(post: post),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (isMine)
                const PopupMenuItem(
                    value: 'edit', child: Text('Chỉnh sửa')),
              if (isMine)
                const PopupMenuItem(
                    value: 'delete', child: Text('Xóa')),
              const PopupMenuItem(
                  value: 'hide', child: Text('Ẩn bài viết')),
            ],
          ),
      ],
    );
  }

  Widget _buildContent(Post post) {
    if (post.isRepost && post.originalPost != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(post.content),
            ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(post.originalPost!, showActions: false),
                const SizedBox(height: 8),
                Text(
                  post.originalPost!.content,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final long = post.content.length > 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _expanded || !long
              ? post.content
              : '${post.content.substring(0, 200)}...',
        ),
        if (long)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Thu gọn' : 'Xem thêm',
              style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildActions(Post post) {
    final liked =
        currentUser != null &&
            post.likes.contains(currentUser!.uid);
    final saved =
        currentUser != null &&
            post.savers.contains(currentUser!.uid);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _icon(
              icon: liked
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: liked ? Colors.red : Colors.grey,
              text: post.likes.length.toString(),
              onTap: _toggleLike,
            ),
            InkWell(
              onTap: _openComments,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.comment,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.commentsCount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _openShareSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Transform.rotate(
                      angle: 0.35,
                      child: const FaIcon(
                        FontAwesomeIcons.paperPlane,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(post.shares.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
        _icon(
          icon: saved
              ? Icons.bookmark
              : Icons.bookmark_border,
          color:
          saved ? const Color(0xFF1877F2) : Colors.grey,
          text: '',
          onTap: _toggleSave,
        ),
      ],
    );
  }

  Widget _icon({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color),
            if (text.isNotEmpty) const SizedBox(width: 4),
            if (text.isNotEmpty)
              Text(text,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLikesContext(Post post) {
    if (post.likes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: _showLikes,
        child: Text(
          '${post.likes.length} lượt thích',
          style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
