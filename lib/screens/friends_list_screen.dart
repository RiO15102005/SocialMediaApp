import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  final String userId;
  const FriendsScreen({super.key, required this.userId});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildUserList(Query<Map<String, dynamic>> query) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Không có dữ liệu."));
        }
        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data();
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: data['avatarUrl'] != null ? NetworkImage(data['avatarUrl']) : null,
                child: data['avatarUrl'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(data['displayName'] ?? "Người dùng"),
              subtitle: Text(data['email'] ?? ""),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bạn bè & lời mời", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1877F2),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Bạn bè"),
            Tab(text: "Đã gửi"),
            Tab(text: "Đã nhận"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ✅ Tab 1: Danh sách bạn bè
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data();
              final friends = (data?['friends'] as List?) ?? [];
              if (friends.isEmpty) return const Center(child: Text("Chưa có bạn bè."));
              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(friends[index])
                        .get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final user = snap.data!.data();
                      if (user == null) return const SizedBox.shrink();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatarUrl'] != null
                              ? NetworkImage(user['avatarUrl'])
                              : null,
                          child:
                          user['avatarUrl'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(user['displayName'] ?? "Người dùng"),
                        subtitle: Text(user['email'] ?? ""),
                      );
                    },
                  );
                },
              );
            },
          ),

          // ✅ Tab 2: Đã gửi lời mời
          _buildUserList(FirebaseFirestore.instance
              .collection('friend_requests')
              .where('senderId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'pending')),

          // ✅ Tab 3: Đã nhận lời mời
          _buildUserList(FirebaseFirestore.instance
              .collection('friend_requests')
              .where('receiverId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'pending')),
        ],
      ),
    );
  }
}
