// lib/widgets/chat_bubble.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatefulWidget {
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

  // Read status & Group
  final List<String> readBy;
  final bool isGroup;

  // Reactions
  final Map<String, dynamic> reactions;
  final Function(String)? onReactionTap;
  final VoidCallback? onViewReactions;

  // Shared Post
  final bool isSharedPost;
  final String? sharedPostContent;
  final String? sharedPostUserName;
  final VoidCallback? onSharedPostTap;

  // Old params compatibility
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
  })  : isSharedPost = false,
        sharedPostContent = null,
        sharedPostUserName = null,
        onSharedPostTap = null,
        super(key: key);

  const ChatBubble.sharedPost({
    Key? key,
    required this.isCurrentUser,
    required this.timestamp,
    required this.isRevoked,
    this.onRecall,
    this.onDeleteForMe,
    this.onReply,
    this.replyToMessage,
    this.sharedPostContent,
    this.sharedPostUserName,
    this.onSharedPostTap,
    this.readBy = const [],
    this.isGroup = false,
    this.reactions = const {},
    this.onReactionTap,
    this.onViewReactions,
    this.showStatus = false,
    this.likedBy = const [],
    this.isLiked = false,
    this.onLikePressed,
  })  : message = 'Đã chia sẻ một bài viết',
        isSharedPost = true,
        type = 'shared_post',
        imageUrl = null,
        super(key: key);

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showSeenDetails = false;

  final Map<String, String> _reactionIcons = {
    'like': '👍', 'love': '❤️', 'haha': '😂', 'sad': '😢',
  };

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSeenAvatar(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final avatar = data?['photoURL'];
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: CircleAvatar(
            radius: 8,
            backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
            child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 10) : null,
          ),
        );
      },
    );
  }

  Widget _buildSeenName(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final name = data?['displayName'] ?? "Người dùng";
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        );
      },
    );
  }

  Widget _buildReactionDisplay() {
    if (widget.reactions.isEmpty) return const SizedBox.shrink();

    if (!widget.isGroup) {
      final reaction = widget.reactions.values.last;
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
        child: Text(_reactionIcons[reaction] ?? '👍', style: const TextStyle(fontSize: 14)),
      );
    } else {
      Map<String, int> counts = {};
      widget.reactions.values.forEach((r) => counts[r] = (counts[r] ?? 0) + 1);
      var sortedKeys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      var top3 = sortedKeys.take(3).toList();
      var total = widget.reactions.length;

      return GestureDetector(
        onTap: widget.onViewReactions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ...top3.map((r) => Text(_reactionIcons[r] ?? '', style: const TextStyle(fontSize: 12))),
            if (total > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text(total.toString(), style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold))),
          ]),
        ),
      );
    }
  }

  void _showReactionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⭐ SỬA LỖI: CHỈ HIỆN THANH CẢM XÚC NẾU TIN NHẮN CHƯA BỊ THU HỒI
            if (!widget.isRevoked) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactionIcons.entries.map((e) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (widget.onReactionTap != null) widget.onReactionTap!(e.key);
                      },
                      child: Text(e.value, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
            ],

            // Các nút chức năng khác
            if (!widget.isRevoked && widget.onReply != null)
              ListTile(
                  leading: const Icon(Icons.reply, color: Colors.green),
                  title: const Text("Trả lời"),
                  onTap: () { Navigator.pop(ctx); widget.onReply!(); }
              ),

            if (!widget.isRevoked && widget.isCurrentUser && widget.onRecall != null)
              ListTile(
                  leading: const Icon(Icons.undo, color: Colors.blue),
                  title: const Text("Thu hồi"),
                  onTap: () { Navigator.pop(ctx); widget.onRecall!(); }
              ),

            if (widget.onDeleteForMe != null)
              ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Xóa cho mình"),
                  onTap: () { Navigator.pop(ctx); widget.onDeleteForMe!(); }
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            // ⭐ DOUBLE TAP: Chỉ cho phép nếu chưa thu hồi
            onDoubleTap: () {
              if (!widget.isRevoked && widget.onReactionTap != null) {
                widget.onReactionTap!('like');
              }
            },
            onLongPress: () => _showReactionMenu(context),
            onTap: () {
              if (widget.isCurrentUser && !widget.isRevoked) {
                setState(() => _showSeenDetails = !_showSeenDetails);
              }
              if (widget.type == 'image' && widget.imageUrl != null) {
                showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.network(widget.imageUrl!))));
              } else if (widget.isSharedPost && widget.onSharedPostTap != null) {
                widget.onSharedPostTap!();
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: (widget.type == 'image') ? Colors.transparent : (widget.isCurrentUser ? const Color(0xFF1877F2) : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (widget.replyToMessage != null && widget.replyToMessage!.isNotEmpty) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Colors.blue, width: 3))), child: Text(widget.replyToMessage!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic))),
                    if (widget.type == 'image' && widget.imageUrl != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(widget.imageUrl!, width: 200, fit: BoxFit.cover))
                    else if (widget.isSharedPost) RichText(text: TextSpan(style: TextStyle(fontSize: 16, color: widget.isCurrentUser ? Colors.white : Colors.black), children: [const TextSpan(text: 'Đã chia sẻ bài viết của '), TextSpan(text: widget.sharedPostUserName ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold)), const TextSpan(text: ': '), TextSpan(text: '''${widget.sharedPostContent}''', style: const TextStyle(fontStyle: FontStyle.italic))]))
                    else Text(widget.message, style: TextStyle(fontSize: 16, color: widget.isCurrentUser ? Colors.white : Colors.black)),
                    if (widget.type != 'image') Text(_formatTime(widget.timestamp), style: TextStyle(fontSize: 11, color: widget.isCurrentUser ? Colors.white70 : Colors.black54))
                  ]),
                ),

                // ⭐ CHỈ HIỆN REACTION NẾU CHƯA THU HỒI
                if (!widget.isRevoked && widget.reactions.isNotEmpty)
                  Positioned(
                    bottom: -5,
                    right: widget.isCurrentUser ? 10 : -5,
                    left: widget.isCurrentUser ? null : 10,
                    child: _buildReactionDisplay(),
                  ),
              ],
            ),
          ),

          if (widget.isCurrentUser && !widget.isRevoked && widget.readBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
              child: Builder(
                builder: (context) {
                  if (!widget.isGroup) {
                    if (_showSeenDetails) return const Text("Đã xem", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic));
                    else return _buildSeenAvatar(widget.readBy.first);
                  } else {
                    if (_showSeenDetails) return Wrap(alignment: WrapAlignment.end, spacing: 4, children: widget.readBy.map((uid) => _buildSeenName(uid)).toList());
                    else return Wrap(alignment: WrapAlignment.end, spacing: -5, children: widget.readBy.map((uid) => _buildSeenAvatar(uid)).toList());
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}