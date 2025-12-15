import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 1. Made the widget StatelessWidget as State was not necessary for the bubble itself.
// 2. Combined all parameters into a single constructor for simplicity.
// 3. Created a dedicated helper `_buildSharedPostView` for clarity.
// 4. Added dark mode awareness for better visuals.

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final Timestamp timestamp;
  final bool isRevoked;
  final VoidCallback? onRecall;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onReply;
  final String? replyToMessage;
  final String type;
  final String? imageUrl;
  final List<String> readBy;
  final bool isGroup;
  final Map<String, dynamic> reactions;
  final Function(String)? onReactionTap;
  final VoidCallback? onViewReactions;
  final bool isSharedPost;
  final String? sharedPostContent;
  final String? sharedPostUserName;
  final VoidCallback? onSharedPostTap;
  final bool showStatus;
  final List likedBy;
  final bool isLiked;
  final VoidCallback? onLikePressed;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.isRevoked,
    this.onRecall,
    this.onDeleteForMe,
    this.onReply,
    this.replyToMessage,
    this.type = 'text',
    this.imageUrl,
    this.readBy = const [],
    this.isGroup = false,
    this.reactions = const {},
    this.onReactionTap,
    this.onViewReactions,
    this.showStatus = false,
    this.likedBy = const [],
    this.isLiked = false,
    this.onLikePressed,
    this.isSharedPost = false,
    this.sharedPostContent,
    this.sharedPostUserName,
    this.onSharedPostTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isCurrentUser
        ? const Color(0xFF1877F2)
        : (isDark ? Colors.grey[800] : Colors.grey[200]);

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (isSharedPost && onSharedPostTap != null) {
            onSharedPostTap!();
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: isSharedPost ? _buildSharedPostView(context) : _buildStandardMessageView(context),
        ),
      ),
    );
  }

  Widget _buildStandardMessageView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isCurrentUser ? Colors.white : (isDark ? Colors.white : Colors.black);
    return Text(
      isRevoked ? "Tin nhắn đã được thu hồi" : message,
      style: TextStyle(fontSize: 16, color: textColor),
    );
  }

  Widget _buildSharedPostView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainMessageTextColor = isCurrentUser ? Colors.white : (isDark ? Colors.white : Colors.black);
    final innerTextColor = isCurrentUser ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87);
    final innerSubTextColor = isCurrentUser ? Colors.white.withOpacity(0.8) : (isDark ? Colors.white70 : Colors.black54);
    final borderColor = isCurrentUser ? Colors.white.withOpacity(0.5) : (isDark ? Colors.grey.shade500 : Colors.grey.shade400);
    final innerBgColor = isCurrentUser ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              message,
              style: TextStyle(fontSize: 16, color: mainMessageTextColor),
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: innerBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor, width: 3.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharedPostUserName ?? 'Người dùng',
                  style: TextStyle(fontWeight: FontWeight.bold, color: innerTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  sharedPostContent ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: innerSubTextColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
