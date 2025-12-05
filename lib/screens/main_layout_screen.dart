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
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  final currentUser = FirebaseAuth.instance.currentUser;

  StreamSubscription<QuerySnapshot>? _chatNotificationSubscription;
  final ChatService _chatService = ChatService();

  // ⭐ NEW: To track the timestamp of the last notified message for each room.
  final Map<String, Timestamp> _lastMessageTimestamps = {};

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    ChatListScreen(),
    SearchScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
        final unreadCount = messagesSnapshot.docs.where((doc) => doc.data()['senderId'] != currentUserId).length;
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

  // Logic để lắng nghe tin nhắn mới (cho pop-up)
  void _listenForNewChatMessages() {
    if (currentUser == null) return;

    _chatNotificationSubscription = _chatService.chatRoomsStream().listen((snapshot) {
      if (!mounted) return;

      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data() as Map<String, dynamic>;
          final roomId = docChange.doc.id;

          // ⭐ FIXED: This block prevents the pop-up from re-appearing after reading.
          final Timestamp? newTimestamp = data['updatedAt'] as Timestamp?;
          final Timestamp? lastKnownTimestamp = _lastMessageTimestamps[roomId];

          // Only proceed if the message timestamp is genuinely newer than the last one we notified for.
          if (newTimestamp != null && (lastKnownTimestamp == null || newTimestamp.compareTo(lastKnownTimestamp) > 0)) {
            final lastSenderId = data['lastSenderId'];

            if (lastSenderId != null && lastSenderId != currentUser!.uid) {
              // This is a new message from someone else. Update our tracker.
              _lastMessageTimestamps[roomId] = newTimestamp;

              if (_selectedIndex != 1) {
                final List<dynamic> participants = data['participants'] ?? [];
                if (participants.length < 2) continue;

                final String otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "💬 $otherUserName: $lastMessageContent",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Text(
                                'XEM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Bảng tin'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat),
                if (currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .where('participants', arrayContains: currentUser!.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                      final futures = snapshot.data!.docs.map((doc) {
                        return _calculateUnreadMessagesInRoom(doc.id, currentUser!.uid);
                      }).toList();
                      return FutureBuilder<List<int>>(
                          future: Future.wait(futures),
                          builder: (context, unreadSnapshot) {
                            if (!unreadSnapshot.hasData || unreadSnapshot.connectionState == ConnectionState.waiting) return const SizedBox();
                            final totalUnreadCount = unreadSnapshot.data?.fold(0, (sum, count) => sum + count) ?? 0;
                            if (totalUnreadCount == 0) return const SizedBox();
                            return Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  '$totalUnreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          });
                    },
                  ),
              ],
            ),
            label: 'Nhắn tin',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("notifications")
                        .where("userId", isEqualTo: currentUser!.uid)
                        .where("isRead", isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final count = snapshot.data!.docs.length;
                      if (count == 0) return const SizedBox();
                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            label: 'Thông báo',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
