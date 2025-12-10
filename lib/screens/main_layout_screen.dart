// lib/screens/main_layout_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

class MainLayoutScreen extends StatefulWidget {
  final int initialIndex; // ⭐ THÊM
  const MainLayoutScreen({super.key, this.initialIndex = 0});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  late int _selectedIndex; // ⭐ ĐỔI int → late int

  final currentUser = FirebaseAuth.instance.currentUser;

  StreamSubscription<QuerySnapshot>? _chatNotificationSubscription;
  final ChatService _chatService = ChatService();

  final Map<String, Timestamp> _lastMessageTimestamps = {};

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    ChatListScreen(),
    SearchScreen(),
    NotificationsScreen(),
    ProfileScreen(), // ⭐ TAB PROFILE = 4
  ];

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex; // ⭐ CHỌN TAB BAN ĐẦU

    _listenForNewChatMessages();
  }

  @override
  void dispose() {
    _chatNotificationSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(Timestamp t) {
    final dt = t.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Future<int> _calculateUnreadMessagesInRoom(String roomId, String currentUserId) async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).get();
      if (!roomDoc.exists) return 0;
      final data = roomDoc.data();

      final Map<String, dynamic> lastReadTimeMap = data?['lastReadTime'] ?? {};
      final Timestamp? lastReadTime = lastReadTimeMap[currentUserId] as Timestamp?;

      Query<Map<String, dynamic>> messagesQuery = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages');

      if (lastReadTime != null) {
        messagesQuery = messagesQuery.where('timestamp', isGreaterThan: lastReadTime);
        final messagesSnapshot = await messagesQuery.get();
        final unreadCount =
            messagesSnapshot.docs.where((doc) => doc.data()['senderId'] != currentUserId).length;
        return unreadCount;
      } else {
        messagesQuery = messagesQuery.where('senderId', isNotEqualTo: currentUserId);
        final messagesSnapshot = await messagesQuery.get();
        return messagesSnapshot.docs.length;
      }
    } catch (e) {
      debugPrint("Error calculating unread messages for room $roomId: $e");
      return 0;
    }
  }

  void _listenForNewChatMessages() {
    if (currentUser == null) return;

    _chatNotificationSubscription = _chatService.chatRoomsStream().listen((snapshot) {
      if (!mounted) return;

      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data() as Map<String, dynamic>;
          final roomId = docChange.doc.id;

          final Timestamp? newTimestamp = data['updatedAt'] as Timestamp?;
          final Timestamp? lastKnownTimestamp = _lastMessageTimestamps[roomId];

          if (newTimestamp != null &&
              (lastKnownTimestamp == null || newTimestamp.compareTo(lastKnownTimestamp) > 0)) {
            final lastSenderId = data['lastSenderId'];

            if (lastSenderId != null && lastSenderId != currentUser!.uid) {
              _lastMessageTimestamps[roomId] = newTimestamp;

              if (_selectedIndex != 1) {
                final List<dynamic> participants = data['participants'] ?? [];
                if (participants.length < 2) continue;

                final String otherUserId =
                participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
                if (otherUserId.isEmpty) continue;

                FirebaseFirestore.instance.collection('users').doc(otherUserId).get().then((userDoc) {
                  if (!mounted) return;

                  final otherUserName = userDoc.data()?['displayName'] ?? "Người dùng";
                  final lastMessageContent = data['lastMessage'] ?? "Tin nhắn mới";

                  final String formattedTime = _formatTime(newTimestamp);

                  final screenHeight = MediaQuery.of(context).size.height;
                  final safeAreaTop = MediaQuery.of(context).padding.top;

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                receiverId: otherUserId,
                                receiverName: otherUserName,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("💬 $otherUserName: $lastMessageContent",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Text('XEM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  )),
                            ),
                          ],
                        ),
                      ),
                      backgroundColor: const Color(0xFF1877F2),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.fromLTRB(16, safeAreaTop + 10, 16, screenHeight - safeAreaTop - 120),
                    ),
                  );
                });
              }
            }
          }
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Bảng tin'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Nhắn tin'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
