import 'package:flutter/material.dart';

class SharedPostBubble extends StatelessWidget {
  final String message;
  final String postAuthorName;
  final String postContent;
  final String? postImageUrl;
  final String postCreatedTime;
  final bool isMe;
  final VoidCallback? onTap;

  const SharedPostBubble({
    Key? key,
    required this.message,
    required this.postAuthorName,
    required this.postContent,
    this.postImageUrl,
    required this.postCreatedTime,
    required this.isMe,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMe ? const Color(0xFF1877F2) : const Color(0xFFE4E6EB);
    final cardBackgroundColor = isMe ? Colors.black.withOpacity(0.18) : Colors.white;
    final primaryTextColor = isMe ? Colors.white : Colors.black87;
    final secondaryTextColor = isMe ? Colors.white.withOpacity(0.9) : Colors.black54;
    final ctaColor = isMe ? Colors.white : const Color(0xFF1877F2);

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0, bottom: 6.0),
                  child: Text(
                    "Đã chia sẻ bài viết",
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor.withOpacity(isMe ? 0.8 : 1.0),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  decoration: BoxDecoration(
                      color: cardBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isMe ? null : Border.all(color: Colors.grey.shade300, width: 0.5)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postAuthorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        postCreatedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                      if (postContent.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            postContent,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: secondaryTextColor, fontSize: 14, height: 1.3),
                          ),
                        ),
                      if (postImageUrl != null && postImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              postImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    "Xem bài viết",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ctaColor,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
