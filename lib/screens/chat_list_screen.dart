// lib/screens/chat_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import 'package:zalo_app/screens/chat_screen.dart';

class ChatListItem extends StatefulWidget {
  final DocumentSnapshot chatDoc;

  const ChatListItem({super.key, required this.chatDoc});

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  String? _otherUserId;
  String _otherUserName = 'Đang tải...';

  @override
  void initState() {
    super.initState();
    _getOtherUserInfo();
  }

  void _getOtherUserInfo() async {
    final chatData = widget.chatDoc.data() as Map<String, dynamic>;
    final participants = chatData['participants'] as List<dynamic>;

    _otherUserId = participants.firstWhere(
          (id) => id != _currentUser!.uid,
      orElse: () => null,
    );

    if (_otherUserId != null) {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(_otherUserId).get();
      if (userDoc.exists) {
        setState(() {
          _otherUserName =
              userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? 'Người dùng';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatData = widget.chatDoc.data() as Map<String, dynamic>;

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          if (_otherUserId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: _otherUserId),
              ),
            );
          }
        },
        child: const CircleAvatar(child: Icon(Icons.person)),
      ),
      title: GestureDetector(
        onTap: () {
          if (_otherUserId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: _otherUserId),
              ),
            );
          }
        },
        child: Text(_otherUserName),
      ),
      subtitle: Text(
        chatData['lastMessage'] ?? '...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        if (_otherUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: widget.chatDoc.id,
                receiverName: _otherUserName,
              ),
            ),
          );
        }
      },
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem tin nhắn.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _currentUser!.uid)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Đã xảy ra lỗi!'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có cuộc trò chuyện nào.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              return ChatListItem(chatDoc: snapshot.data!.docs[index]);
            },
          );
        },
      ),
    );
  }
}
