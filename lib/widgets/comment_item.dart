import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart' as model;
import '../screens/profile_screen.dart';
import '../services/user_service.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final int replyCount;
  final bool showReplies;
  final bool canDelete;
  final bool isPostAuthor;

  final void Function(String id, String user)? onReply;
  final void Function(String id)? onToggleReplies;
  final void Function(String id)? onDelete;
  final void Function(String id, String currentContent)? onEdit;
  final void Function(String id)? onLike;

  const CommentItem({
    super.key,
    required this.comment,
    required this.replyCount,
    required this.canDelete,
    required this.isPostAuthor,
    this.showReplies = false,
    this.onReply,
    this.onToggleReplies,
    this.onDelete,
    this.onEdit,
    this.onLike,
  });

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays >= 7) {
      return DateFormat('dd/MM').format(dt);
    } else {
      return timeago.format(dt, locale: 'vi');
    }
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _showLikes(BuildContext context) async {
    if (comment.likes.isEmpty) return;

    final userService = UserService();
    final users = await userService.getUsers(comment.likes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '${comment.likes.length} người đã thích',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (itemCtx, i) {
                  final user = users[i];
                  return ListTile(
                    onTap: () => _navigateToProfile(context, user.uid),
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.photoURL ?? ''),
                      child: user.photoURL == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    title:
                        Text(user.displayName ?? 'Người dùng không xác định'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa bình luận?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Bạn có chắc chắn muốn xóa bình luận này không?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Hủy")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Xóa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (yes == true && onDelete != null) {
      onDelete!(comment.commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == comment.userId;
    final isLiked = currentUser != null && comment.likes.contains(currentUser.uid);

    return GestureDetector(
      onLongPress: () => _showLikes(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context, comment.userId),
                  child: const CircleAvatar(
                      radius: 18, child: Icon(Icons.person, size: 18)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(context, comment.userId),
                        child: Row(children: [
                          Text(comment.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if (isPostAuthor)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Tác giả',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 6),
                          Text(_formatTime(comment.timestamp),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content, style: const TextStyle(fontSize: 14.5)),
                      const SizedBox(height: 6),
                      Row(children: [
                        TextButton(
                          onPressed: () =>
                              onReply?.call(comment.commentId, comment.userName),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: Text("Trả lời",
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700])),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => onLike?.call(comment.commentId),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? Colors.red : Colors.grey[700],
                          ),
                        ),
                        if (comment.likesCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '${comment.likesCount}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (canDelete || isOwner)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == "delete") {
                                _confirmDelete(context);
                              } else if (value == "edit") {
                                onEdit?.call(comment.commentId, comment.content);
                              }
                            },
                            itemBuilder: (_) {
                              final items = <PopupMenuEntry<String>>[];
                              if (isOwner) {
                                items.add(const PopupMenuItem(
                                    value: "edit", child: Text("Chỉnh sửa")));
                              }
                              if (canDelete) {
                                items.add(const PopupMenuItem(
                                    value: "delete",
                                    child: Text("Xóa bình luận",
                                        style: TextStyle(color: Colors.red))));
                              }
                              return items;
                            },
                          ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            if (replyCount > 0 && !showReplies)
              Padding(
                padding: const EdgeInsets.only(left: 46.0, top: 8.0),
                child: TextButton(
                  onPressed: () => onToggleReplies?.call(comment.commentId),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: Text("Xem $replyCount trả lời",
                      style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
