// lib/screens/search_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchText = "";
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ======================================================
  // GỢI Ý NGƯỜI DÙNG — CÓ THỂ BAO GỒM BẠN BÈ
  // ======================================================
  Widget _buildSuggestionList(List friends) {
    if (_searchText.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final allUsers = snap.data!.docs;

        final filtered = allUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data["uid"];

          if (uid == currentUid) return false;

          final name = (data["displayName"] ?? "").toLowerCase();
          final email = (data["email"] ?? "").toLowerCase();

          return name.startsWith(_searchText) || email.startsWith(_searchText);
        }).toList();

        if (filtered.isEmpty) return const SizedBox.shrink();

        // ⭐ Sắp xếp: bạn bè lên trước
        filtered.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final uidA = da["uid"];
          final uidB = db["uid"];
          final isFriendA = friends.contains(uidA);
          final isFriendB = friends.contains(uidB);

          if (isFriendA && !isFriendB) return -1;
          if (!isFriendA && isFriendB) return 1;
          return 0;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade200,
              child: const Text(
                "Gợi ý",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            ...filtered.map((doc) {
              final user = doc.data() as Map<String, dynamic>;
              final uid = user["uid"];
              final isFriend = friends.contains(uid);

              final displayName = (user["displayName"] == null ||
                  user["displayName"].toString().trim().isEmpty)
                  ? "Người dùng"
                  : user["displayName"];

              final email = user["email"] ?? "";

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(displayName),
                subtitle: Text(email),
                trailing: Text(
                  isFriend ? "Bạn bè" : "Người lạ",
                  style: TextStyle(
                    color: isFriend ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: uid),
                    ),
                  );
                },
              );
            }),

            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ======================================================
  // DANH SÁCH BẠN BÈ — KHÔNG HIỆN TRẠNG THÁI
  // ======================================================
  Widget _buildFriendsList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(currentUid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final data = snap.data!.data() as Map<String, dynamic>;
        final friends = (data["friends"] as List?) ?? [];

        if (friends.isEmpty) {
          return const Center(child: Text("Bạn chưa có bạn bè."));
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: friends.length,
          itemBuilder: (context, i) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(friends[i])
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();

                final friend = userSnap.data!.data() as Map<String, dynamic>;
                final displayName = (friend["displayName"] == null ||
                    friend["displayName"].toString().trim().isEmpty)
                    ? "Người dùng"
                    : friend["displayName"];

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(displayName),
                  subtitle: Text(friend["email"] ?? ""),
                  trailing: const SizedBox(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: friends[i]),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ======================================================
  // UI CHÍNH — CHỐNG OVERFLOW, CUỘN MƯỢT
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ⭐ GIẢI QUYẾT VỤ OVERFLOW
      appBar: AppBar(
        title: const Text("Tìm kiếm bạn bè"),
        backgroundColor: const Color(0xFF1877F2),
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
          // ================= INPUT SEARCH =================
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Nhập tên hoặc email...",
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // ================= VÙNG DƯỚI CUỘN ĐƯỢC =================
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gợi ý khi đang gõ
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(currentUid)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final data = snap.data!.data() as Map<String, dynamic>;
                      final friends = (data["friends"] as List?) ?? [];
                      return _buildSuggestionList(friends);
                    },
                  ),

                  // Title "Danh sách bạn bè"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade300,
                    child: const Text(
                      "Danh sách bạn bè",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // LIST BẠN BÈ — CUỘN TRONG KHUNG CỐ ĐỊNH
                  SizedBox(
                    height: 500,
                    child: _buildFriendsList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
