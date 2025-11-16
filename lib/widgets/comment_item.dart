// lib/widgets/comment_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/comment_model.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final int replyCount;
  final bool showReplies;

  final bool canDelete; // ⭐ Chủ bài viết hoặc chủ bình luận

  final void Function(String id, String user)? onReply;
  final void Function(String id)? onToggleReplies;
  final void Function(String id)? onDelete;

  const CommentItem({
    super.key,
    required this.comment,
    required this.replyCount,
    required this.canDelete,
    this.showReplies = false,
    this.onReply,
    this.onToggleReplies,
    this.onDelete,
  });

  // ================== FORMAT TIME ==================
  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // ================== CONFIRM DELETE ==================
  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Xóa bình luận?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Bạn có chắc chắn muốn xóa bình luận này không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (yes == true && onDelete != null) {
      onDelete!(comment.commentId);
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person, size: 18),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== HEADER: NAME + TIME =====
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(comment.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // ===== CONTENT =====
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 6),

                // ===== ACTIONS =====
                Row(
                  children: [
                    // TRẢ LỜI
                    TextButton(
                      onPressed: () => onReply?.call(
                        comment.commentId,
                        comment.userName,
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        "Trả lời",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),

                    // ===== DELETE BUTTON (ONLY IF ALLOWED) =====
                    if (canDelete)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == "delete") {
                            _confirmDelete(context);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: "delete",
                            child: Text(
                              "Xóa bình luận",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),

                    // ===== SHOW REPLIES =====
                    if (replyCount > 0 && !showReplies)
                      TextButton(
                        onPressed: () =>
                            onToggleReplies?.call(comment.commentId),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(left: 8),
                        ),
                        child: Text(
                          "Xem trả lời ($replyCount)",
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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
