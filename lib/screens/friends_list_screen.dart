// lib/screens/friends_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';

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

  // ==================================================================
  // HÀM CHUNG: XỬ LÝ HỦY LỜI MỜI – CHẤP NHẬN – TỪ CHỐI
  // ==================================================================
  Future<void> _cancelRequest(String requestId) async {
    await FirebaseFirestore.instance.collection("friend_requests").doc(requestId).delete();
  }

  Future<void> _acceptRequest(String senderId, String requestId) async {
    final uid = currentUser!.uid;

    // Cập nhật danh sách bạn bè 2 chiều
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "friends": FieldValue.arrayUnion([senderId])
    });
    await FirebaseFirestore.instance.collection("users").doc(senderId).update({
      "friends": FieldValue.arrayUnion([uid])
    });

    // Xoá lời mời
    await FirebaseFirestore.instance.collection("friend_requests").doc(requestId).delete();
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseFirestore.instance.collection("friend_requests").doc(requestId).delete();
  }

  // ==================================================================
  // TABS "ĐÃ GỬI" & "ĐÃ NHẬN"
  // ==================================================================
  Widget _buildRequestList(Query<Map<String, dynamic>> query, bool isSentTab) {
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
            final requestId = doc.id;

            // Lấy UID người còn lại trong lời mời
            final otherUserId =
            isSentTab ? data["receiverId"] : data["senderId"];

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection("users").doc(otherUserId).get(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final user = snap.data!.data();
                if (user == null) return const SizedBox.shrink();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user["avatarUrl"] != null
                        ? NetworkImage(user["avatarUrl"])
                        : null,
                    child: user["avatarUrl"] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),

                  title: Text(user["displayName"] ?? "Người dùng"),
                  subtitle: Text(user["email"] ?? ""),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: otherUserId),
                      ),
                    );
                  },

                  // =========================
                  //   HÀNH ĐỘNG: HỦY / CHẤP NHẬN / TỪ CHỐI
                  // =========================
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nếu là tab "ĐÃ GỬI" → chỉ có nút HỦY
                      if (isSentTab)
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () async {
                            await _cancelRequest(requestId);
                          },
                        ),

                      // Tab "ĐÃ NHẬN": Có 2 nút
                      if (!isSentTab) ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () async {
                            await _acceptRequest(otherUserId, requestId);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await _declineRequest(requestId);
                          },
                        ),
                      ]
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  // ==================================================================
  // GIAO DIỆN CHÍNH
  // ==================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bạn bè & lời mời", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1877F2),
        iconTheme: const IconThemeData(color: Colors.white),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
          // ===========================================================
          // TAB 1 — BẠN BÈ
          // ===========================================================
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(widget.userId)
                .snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final data = snapshot.data!.data();
              final friends = (data?["friends"] as List?) ?? [];

              if (friends.isEmpty) {
                return const Center(child: Text("Chưa có bạn bè."));
              }

              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friendId = friends[index];

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection("users").doc(friendId).get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final user = snap.data!.data();
                      if (user == null) return const SizedBox.shrink();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user["avatarUrl"] != null
                              ? NetworkImage(user["avatarUrl"])
                              : null,
                          child: user["avatarUrl"] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user["displayName"] ?? "Người dùng"),
                        subtitle: Text(user["email"] ?? ""),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: friendId),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          // ===========================================================
          // TAB 2 — ĐÃ GỬI LỜI MỜI
          // ===========================================================
          _buildRequestList(
            FirebaseFirestore.instance
                .collection("friend_requests")
                .where("senderId", isEqualTo: widget.userId)
                .where("status", isEqualTo: "pending"),
            true,
          ),

          // ===========================================================
          // TAB 3 — ĐÃ NHẬN LỜI MỜI
          // ===========================================================
          _buildRequestList(
            FirebaseFirestore.instance
                .collection("friend_requests")
                .where("receiverId", isEqualTo: widget.userId)
                .where("status", isEqualTo: "pending"),
            false,
          ),
        ],
      ),
    );
  }
}
