import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/chat_service.dart';
import '../services/post_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/shared_post_bubble.dart'; // Import the new widget
import 'comment_screen.dart';
import 'group_info_screen.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  late String chatRoomId;
  late String uid;

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;

    chatRoomId = widget.isGroup
        ? widget.receiverId
        : _chatService.getChatRoomId(uid, widget.receiverId);

    _updateLastReadTime();
    _chatService.markMessagesAsRead(chatRoomId);
  }

  @override
  void dispose() {
    _updateLastReadTime();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return "Vừa xong";
    if (diff.inMinutes < 60) return "${diff.inMinutes} phút trước";
    if (diff.inHours < 24) return "${diff.inHours} giờ trước";
    if (diff.inDays < 7) return "${diff.inDays} ngày trước";
    return DateFormat('dd/MM/yyyy').format(timestamp);
  }

  Future<void> _updateLastReadTime() async {
    await FirebaseFirestore.instance
        .collection("chat_rooms")
        .doc(chatRoomId)
        .set({
      "lastReadTime": {uid: FieldValue.serverTimestamp()}
    }, SetOptions(merge: true));
  }

  void _navigateToProfile() {
    if (!widget.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: widget.receiverId),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    await _chatService.sendMessage(
      widget.receiverId,
      text,
      isGroup: widget.isGroup,
    );

    _updateLastReadTime();
    _scrollToBottom();
  }

  Future<void> _confirmRecall(String msgId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thu hồi tin nhắn?"),
        content: const Text("Tin nhắn sẽ bị thu hồi cho tất cả mọi người."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Thu hồi", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _chatService.recallMessage(chatRoomId, msgId);
    }
  }

  Future<void> _confirmDeleteForMe(String msgId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa tin nhắn cho bạn?"),
        content: const Text("Tin nhắn chỉ bị xóa ở phía bạn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _chatService.deleteMessageForMe(chatRoomId, msgId);
    }
  }

  Future<void> _navigateToCommentScreen(String postId) async {
    try {
      final Post? post = await _postService.getPostById(postId);
      if (post != null && !post.isDeleted && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommentScreen(post: post),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bài viết đã bị xóa.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Không thể tải bài viết: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: widget.receiverAvatar != null && widget.receiverAvatar!.isNotEmpty
                    ? NetworkImage(widget.receiverAvatar!)
                    : null,
                child: (widget.receiverAvatar == null || widget.receiverAvatar!.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(widget.receiverName),
            ],
          ),
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfoScreen(
                      groupId: chatRoomId,
                      groupName: widget.receiverName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder(
      stream: _chatService.getMessages(chatRoomId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Đã xảy ra lỗi..."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(child: Text("Hãy bắt đầu cuộc trò chuyện!"));
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageItem(messages[index]);
          },
        );
      },
    );
  }

  // Updated to use SharedPostBubble
  Widget _buildMessageItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isCurrentUser = data['senderId'] == uid;
    final isRevoked = data['isRecalled'] ?? false;
    final type = data['type'] ?? 'text';

    if (type == 'shared_post') {
      if (isRevoked) {
        return ChatBubble(
          message: "Tin nhắn đã được thu hồi",
          isCurrentUser: isCurrentUser,
          timestamp: data['timestamp'],
          isRevoked: true,
        );
      }
      // Use the new SharedPostBubble widget
      return SharedPostBubble(
        isMe: isCurrentUser,
        message: data['message'] ?? '',
        postAuthorName: data['sharedPostUserName'] ?? 'Người dùng',
        postContent: data['sharedPostContent'] ?? '',
        postCreatedTime: data.containsKey('sharedPostTimestamp') 
            ? _formatTimestamp((data['sharedPostTimestamp'] as Timestamp).toDate())
            : '',
        onTap: () => _navigateToCommentScreen(data['postId'] ?? ''),
      );
    }

    // Regular text/image bubble
    return ChatBubble(
      message: isRevoked ? "Tin nhắn đã được thu hồi" : (data['message'] ?? ''),
      isCurrentUser: isCurrentUser,
      timestamp: data['timestamp'],
      isRevoked: isRevoked,
      onRecall: isCurrentUser ? () => _confirmRecall(doc.id) : null,
      onDeleteForMe: () => _confirmDeleteForMe(doc.id),
      type: type,
      imageUrl: data['imageUrl'],
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Nhập tin nhắn...",
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.black12,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              return IconButton(
                icon: Transform.rotate(
                  angle: -0.5,
                  child: Icon(
                    Icons.send,
                    color: value.text.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
                onPressed: value.text.isNotEmpty ? sendMessage : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
