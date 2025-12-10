import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import 'group_info_screen.dart';
import 'post_detail_screen.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  late String chatRoomId;
  late String uid;

  Future<void> _updateLastReadTime() async {
    await FirebaseFirestore.instance
        .collection("chat_rooms")
        .doc(chatRoomId)
        .set({
      "lastReadTime": {uid: FieldValue.serverTimestamp()}
    }, SetOptions(merge: true));
  }

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;

    chatRoomId = widget.isGroup
        ? widget.receiverId
        : _chatService.getChatRoomId(uid, widget.receiverId);

    _updateLastReadTime();
    _chatService.markMessagesAsRead(chatRoomId, isGroup: widget.isGroup);
  }

  @override
  void dispose() {
    _updateLastReadTime();
    _messageController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    uid = _auth.currentUser!.uid; // ensure current

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: (widget.receiverAvatar != null && widget.receiverAvatar!.isNotEmpty)
                  ? NetworkImage(widget.receiverAvatar!)
                  : null,
              child: (widget.receiverAvatar == null || widget.receiverAvatar!.isEmpty)
                  ? Icon(widget.isGroup ? Icons.groups : Icons.person)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.receiverName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: chatRoomId, groupName: widget.receiverName)));
              },
            ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Lỗi tải tin nhắn"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // auto-scroll after build frame
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;

                    final deletedFor = (data["deletedFor"] is List) ? List<String>.from(data["deletedFor"]) : <String>[];
                    if (deletedFor.contains(uid)) {
                      return const SizedBox.shrink();
                    }

                    final likedBy = (data["likedBy"] is List) ? List<String>.from(data["likedBy"]) : <String>[];
                    final isRevoked = data["isRecalled"] == true;
                    final isMe = data["senderId"] == uid;
                    final isSharedPost = data['type'] == 'shared_post';

                    if (isSharedPost) {
                      return ChatBubble.sharedPost(
                        isCurrentUser: isMe,
                        timestamp: data["timestamp"] ?? Timestamp.now(),
                        showStatus: false,
                        likedBy: likedBy,
                        isLiked: likedBy.contains(uid),
                        onLikePressed: () {
                          if (!isRevoked) _chatService.toggleLikeMessage(chatRoomId, doc.id);
                        },
                        isRevoked: isRevoked,
                        onRecall: isMe && !isRevoked ? () => _confirmRecall(doc.id) : null,
                        onDeleteForMe: () => _confirmDeleteForMe(doc.id),
                        sharedPostContent: data['sharedPostContent'],
                        sharedPostUserName: data['sharedPostUserName'],
                        onSharedPostTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailScreen(postId: data['postId']),
                            ),
                          );
                        },
                      );
                    } else {
                      return ChatBubble(
                        message: data["message"] ?? "",
                        isCurrentUser: isMe,
                        timestamp: data["timestamp"] ?? Timestamp.now(),
                        showStatus: false,
                        likedBy: likedBy,
                        isLiked: likedBy.contains(uid),
                        onLikePressed: () {
                          if (!isRevoked) _chatService.toggleLikeMessage(chatRoomId, doc.id);
                        },
                        isRevoked: isRevoked,
                        onRecall: isMe && !isRevoked ? () => _confirmRecall(doc.id) : null,
                        onDeleteForMe: () => _confirmDeleteForMe(doc.id),
                      );
                    }
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    ),
                    onTap: _scrollToBottom,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1877F2),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
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
