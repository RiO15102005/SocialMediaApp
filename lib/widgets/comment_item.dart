import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final int replyCount;
  final bool showReplies;
  final bool canDelete;

  final void Function(String id, String user)? onReply;
  final void Function(String id)? onToggleReplies;
  final void Function(String id)? onDelete;
  final void Function(String id)? onLike;

  const CommentItem({
    super.key,
    required this.comment,
    required this.replyCount,
    required this.canDelete,
    this.showReplies = false,
    this.onReply,
    this.onToggleReplies,
    this.onDelete,
    this.onLike,
  });

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa bình luận?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Bạn có chắc chắn muốn xóa bình luận này không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red))),
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
    final isLiked = currentUser != null && comment.likes.contains(currentUser.uid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 6),
                Text(_formatTime(comment.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              Text(comment.content, style: const TextStyle(fontSize: 14.5)),
              const SizedBox(height: 6),
              Row(children: [
                // Trả lời
                TextButton(
                  onPressed: () => onReply?.call(comment.commentId, comment.userName),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: Text("Trả lời", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ),
                const SizedBox(width: 8),

                // Thích bình luận (đổi màu khi liked)
                TextButton(
                  onPressed: () => onLike?.call(comment.commentId),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 16,
                        color: isLiked ? const Color(0xFF1877F2) : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Thích (${comment.likesCount})",
                        style: TextStyle(
                          fontSize: 13,
                          color: isLiked ? const Color(0xFF1877F2) : Colors.grey[700],
                          fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                // Xóa
                if (canDelete)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == "delete") _confirmDelete(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: "delete", child: Text("Xóa bình luận", style: TextStyle(color: Colors.red))),
                    ],
                  ),

                // Xem trả lời
                if (replyCount > 0 && !showReplies)
                  TextButton(
                    onPressed: () => onToggleReplies?.call(comment.commentId),
                    style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8), minimumSize: Size.zero),
                    child: Text("Xem trả lời ($replyCount)", style: TextStyle(color: Colors.blue[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
