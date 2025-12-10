import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final Timestamp timestamp;
  final bool showStatus;
  final bool isRevoked;
  final List likedBy;
  final bool isLiked;
  final VoidCallback onLikePressed;
  final VoidCallback? onRecall;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onReply;
  final String? replyToMessage;

  // Shared post fields
  final bool isSharedPost;
  final String? sharedPostContent;
  final String? sharedPostUserName;
  final VoidCallback? onSharedPostTap;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.showStatus,
    required this.likedBy,
    required this.isLiked,
    required this.onLikePressed,
    required this.isRevoked,
    this.onRecall,
    this.onDeleteForMe,
    this.onReply,
    this.replyToMessage,
  })  : isSharedPost = false,
        sharedPostContent = null,
        sharedPostUserName = null,
        onSharedPostTap = null,
        super(key: key);

  const ChatBubble.sharedPost({
    Key? key,
    required this.isCurrentUser,
    required this.timestamp,
    required this.showStatus,
    required this.likedBy,
    required this.isLiked,
    required this.onLikePressed,
    required this.isRevoked,
    this.onRecall,
    this.onDeleteForMe,
    this.onReply,
    this.replyToMessage,
    this.sharedPostContent,
    this.sharedPostUserName,
    this.onSharedPostTap,
  })  : message = 'Shared a post',
        isSharedPost = true,
        super(key: key);

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRevoked && onReply != null)
                    ListTile(
                      leading: const Icon(Icons.reply, color: Colors.green),
                      title: const Text("Trả lời"),
                      onTap: () {
                        Navigator.pop(ctx);
                        onReply!();
                      },
                    ),
                  if (!isRevoked && isCurrentUser && onRecall != null)
                    ListTile(
                      leading: const Icon(Icons.undo, color: Colors.blue),
                      title: const Text("Thu hồi"),
                      onTap: () {
                        Navigator.pop(ctx);
                        onRecall!();
                      },
                    ),
                  if (onDeleteForMe != null)
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text("Xóa cho mình"),
                      onTap: () {
                        Navigator.pop(ctx);
                        onDeleteForMe!();
                      },
                    ),
                ],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyToMessage != null && replyToMessage!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  replyToMessage!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic),
                ),
              ),
            GestureDetector(
              onTap: isSharedPost ? onSharedPostTap : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? const Color(0xFF1877F2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSharedPost)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: isCurrentUser ? Colors.white : Colors.black,
                          ),
                          children: [
                            const TextSpan(text: 'Shared a post by '),
                            TextSpan(
                              text: sharedPostUserName ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ': '),
                            TextSpan(
                              text: '''$sharedPostContent''',
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 16,
                          color: isCurrentUser ? Colors.white : Colors.black,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                      ),
                    )
                  ],
                ),
              ),
            ),
            if (!isRevoked)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onLikePressed,
                      child: Icon(
                        isLiked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 16,
                        color: isLiked ? Colors.blue : Colors.grey,
                      ),
                    ),
                    if (likedBy.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          likedBy.length.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
