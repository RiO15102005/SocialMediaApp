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
  final String? replyToName;

  final String type;
  final String? imageUrl;
  final String senderId;
  final String? senderAvatarUrl;
  final List<String> readBy;
  final bool isGroup;
  final Map<String, dynamic> reactions;
  final Function(String)? onReactionTap;
  final VoidCallback? onViewReactions;
  final bool isSharedPost;
  final String? sharedPostContent;
  final String? sharedPostUserName;
  final String? sharedPostUserAvatar; 
  final String? sharedPostImageUrl; // Thêm vào
  final VoidCallback? onSharedPostTap;
  final bool showStatus;
  final List likedBy;
  final bool isLiked;
  final VoidCallback? onLikePressed;

  final bool isHighlighted;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.isRevoked,
    required this.senderId,
    this.senderAvatarUrl,
    this.onRecall,
    this.onDeleteForMe,
    this.onReply,
    this.replyToMessage,
    this.replyToName,
    this.type = 'text',
    this.imageUrl,
    this.readBy = const [],
    this.isGroup = false,
    this.reactions = const {},
    this.onReactionTap,
    this.onViewReactions,
    this.isSharedPost = false,
    this.sharedPostContent,
    this.sharedPostUserName,
    this.sharedPostUserAvatar, 
    this.sharedPostImageUrl, // Thêm vào
    this.onSharedPostTap,
    this.showStatus = false,
    this.likedBy = const [],
    this.isLiked = false,
    this.onLikePressed,
    this.isHighlighted = false,
  }) : super(key: key);

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showSeenDetails = false;
  final Map<String, String> _reactionIcons = {'like': '👍', 'love': '❤️', 'haha': '😂', 'sad': '😢'};

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSenderAvatar() {
    if (widget.senderAvatarUrl != null && widget.senderAvatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: 14, backgroundImage: NetworkImage(widget.senderAvatarUrl!));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.senderId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircleAvatar(radius: 14, backgroundColor: Colors.grey);
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final avatar = data?['photoURL'];
        if (avatar != null && avatar.isNotEmpty) {
          return CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatar));
        } else {
          return const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16));
        }
      },
    );
  }

  Widget _buildReplyHeader() {
    if (widget.replyToName == null) return const SizedBox.shrink();
    const textStyle = TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600);
    final padding = widget.isCurrentUser
        ? const EdgeInsets.only(right: 14, bottom: 4)
        : const EdgeInsets.only(left: 14, bottom: 4);

    if (widget.isCurrentUser) {
      return Padding(padding: padding, child: Text("Bạn đã trả lời ${widget.replyToName}", style: textStyle));
    } else {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.senderId).get(),
        builder: (context, snapshot) {
          String senderName = "Người dùng";
          if (snapshot.hasData) senderName = snapshot.data!.get('displayName') ?? "Người dùng";
          return Padding(padding: padding, child: Text("$senderName đã trả lời ${widget.replyToName}", style: textStyle));
        },
      );
    }
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
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
            child: CircleAvatar(radius: 7, backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 8) : null),
          ),
        );
      },
    );
  }

  Widget _buildOverflowAvatar(int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        width: 16, height: 16, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
        child: Text("+$count", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
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
          child: Container(constraints: const BoxConstraints(maxWidth: 80), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic))),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]),
        child: Text(_reactionIcons[reaction] ?? '👍', style: const TextStyle(fontSize: 14)),
      );
    } else {
      Map<String, int> counts = {}; widget.reactions.forEach((k, r) => counts[r] = (counts[r] ?? 0) + 1);
      var sortedKeys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      var top3 = sortedKeys.take(3).toList(); var total = widget.reactions.length;
      return GestureDetector(
        onTap: widget.onViewReactions,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [...top3.map((r) => Text(_reactionIcons[r] ?? '', style: const TextStyle(fontSize: 12))), if (total > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text(total.toString(), style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)))]
            )
        ),
      );
    }
  }

  void _showReactionMenu(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (!widget.isRevoked) ...[Container(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _reactionIcons.entries.map((e) => GestureDetector(onTap: () { Navigator.pop(ctx); if(widget.onReactionTap != null) widget.onReactionTap!(e.key); }, child: Text(e.value, style: const TextStyle(fontSize: 32)))).toList())), const Divider()],
      if (!widget.isRevoked && widget.onReply != null) ListTile(leading: const Icon(Icons.reply, color: Colors.green), title: const Text("Trả lời"), onTap: () { Navigator.pop(ctx); widget.onReply!(); }),
      if (!widget.isRevoked && widget.isCurrentUser && widget.onRecall != null) ListTile(leading: const Icon(Icons.undo, color: Colors.blue), title: const Text("Thu hồi"), onTap: () { Navigator.pop(ctx); widget.onRecall!(); }),
      if (widget.onDeleteForMe != null) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Xóa cho mình"), onTap: () { Navigator.pop(ctx); widget.onDeleteForMe!(); }),
    ])));
  }

  Widget _buildSharedPostCard() {
    final cardColor = widget.isCurrentUser ? Colors.blue.shade50 : Colors.white;
    final hasAvatar = widget.sharedPostUserAvatar != null && widget.sharedPostUserAvatar!.isNotEmpty;
    final hasImage = widget.sharedPostImageUrl != null && widget.sharedPostImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: widget.onSharedPostTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.isCurrentUser ? Colors.blue.shade200 : Colors.grey.shade300, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: hasAvatar ? NetworkImage(widget.sharedPostUserAvatar!) : null,
                  child: !hasAvatar ? const Icon(Icons.person, size: 20) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.sharedPostUserName ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.sharedPostContent != null && widget.sharedPostContent!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  widget.sharedPostContent!,
                  maxLines: 5, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  widget.sharedPostImageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bubbleColor;
    if (widget.isHighlighted) {
      bubbleColor = Colors.amber.shade300;
    } else if (widget.type == 'image' || (widget.isSharedPost && widget.message.isEmpty)) {
      bubbleColor = Colors.transparent;
    } else {
      bubbleColor = widget.isCurrentUser ? const Color(0xFF1877F2) : Colors.grey[200]!;
    }

    final textColor = (widget.isHighlighted) ? Colors.black : (widget.isCurrentUser ? Colors.white : Colors.black);

    return Align(
      alignment: widget.isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isCurrentUser) ...[_buildSenderAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (widget.replyToMessage != null && widget.replyToMessage!.isNotEmpty && !widget.isRevoked)
                  Column(
                      crossAxisAlignment: widget.isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        _buildReplyHeader(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Transform.translate(
                            offset: const Offset(0, 10),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7, minWidth: 50),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade300)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.replyToMessage!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87))]),
                            ),
                          ),
                        ),
                      ]
                  ),

                GestureDetector(
                  onDoubleTap: () { if (!widget.isRevoked && widget.onReactionTap != null) widget.onReactionTap!('like'); },
                  onLongPress: () => _showReactionMenu(context),
                   onTap: () {
                    if ((widget.isCurrentUser || widget.isGroup) && !widget.isRevoked) setState(() => _showSeenDetails = !_showSeenDetails);
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
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: (widget.isSharedPost && widget.message.isEmpty) ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(18),
                          border: (widget.replyToMessage != null && !widget.isRevoked) ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.type == 'image' && widget.imageUrl != null)
                              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(widget.imageUrl!, width: 200, fit: BoxFit.cover))
                            else if (widget.isSharedPost)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.message.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(widget.message, style: TextStyle(fontSize: 16, color: textColor)),
                                    ),
                                  _buildSharedPostCard(),
                                ],
                              )
                            else
                              Text(widget.message, style: TextStyle(fontSize: 16, color: textColor)),

                            const SizedBox(height: 4),
                            if (widget.type != 'image' && !(widget.isSharedPost && widget.message.isEmpty))
                              Text(
                                _formatTime(widget.timestamp),
                                style: TextStyle(fontSize: 10, color: (widget.isHighlighted) ? Colors.black54 : (widget.isCurrentUser ? Colors.white70 : Colors.black54), fontStyle: FontStyle.italic),
                              ),
                            if (!widget.isRevoked && widget.reactions.isNotEmpty) const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      if (!widget.isRevoked && widget.reactions.isNotEmpty) Positioned(bottom: -6, right: 0, child: _buildReactionDisplay()),
                    ],
                  ),
                ),

                if ((widget.isCurrentUser || widget.isGroup) && !widget.isRevoked && widget.readBy.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4, top: 6),
                    child: Builder(
                      builder: (context) {
                        if (!widget.isGroup) {
                          if (!widget.isCurrentUser) return const SizedBox.shrink();
                          if (_showSeenDetails) return const Text("Đã xem", style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic));
                          else return _buildSeenAvatar(widget.readBy.first);
                        } else {
                          if (_showSeenDetails) return Wrap(alignment: WrapAlignment.end, spacing: 4, children: widget.readBy.map((uid) => _buildSeenName(uid)).toList());
                          else {
                            List<Widget> avatarWidgets = []; int maxAvatars = 5; int totalViewers = widget.readBy.length; int displayCount = totalViewers > maxAvatars ? 4 : totalViewers;
                            for (int i = 0; i < displayCount; i++) avatarWidgets.add(_buildSeenAvatar(widget.readBy[i]));
                            if (totalViewers > maxAvatars) avatarWidgets.add(_buildOverflowAvatar(totalViewers - 4));
                            return Wrap(alignment: WrapAlignment.end, spacing: -5, children: avatarWidgets);
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
