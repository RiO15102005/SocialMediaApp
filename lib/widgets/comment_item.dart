import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/comment_model.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final void Function(String commentId, String userName)? onReply;
  final void Function(String commentId)? onToggleReplies;
  final void Function(String commentId)? onDelete;
  final bool showReplies;

  const CommentItem({
    super.key,
    required this.comment,
    this.onReply,
    this.onToggleReplies,
    this.onDelete,
    this.showReplies = false,
  });

  String _formatTime(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(_formatTime(comment.timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        if (onReply != null) onReply!(comment.commentId, comment.userName);
                      },
                      child: Text('Trả lời', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ),
                    // ✅ Nút 3 chấm để xóa
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) {
                        if (value == 'delete' && onDelete != null) {
                          onDelete!(comment.commentId);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa bình luận'),
                        ),
                      ],
                    ),
                    if (comment.replyCount > 0 && !showReplies)
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
                        onPressed: () {
                          if (onToggleReplies != null) onToggleReplies!(comment.commentId);
                        },
                        child: Text(
                          'Xem ${comment.replyCount} trả lời',
                          style: TextStyle(color: Colors.blue[700],
                              fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
