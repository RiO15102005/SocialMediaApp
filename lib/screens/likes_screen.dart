import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

class LikesScreen extends StatelessWidget {
  final List<String> userIds;

  const LikesScreen({Key? key, required this.userIds}) : super(key: key);

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' Số lượt thích'),
      ),
      body: ListView.builder(
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          final userId = userIds[index];
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Đang tải...'),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const ListTile(
                  title: Text('Không tìm thấy người dùng'),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final userName = userData['displayName'] ?? 'Người dùng';
              final userAvatar = userData['photoURL'];

              return ListTile(
                onTap: () => _navigateToProfile(context, userId),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null || userAvatar.isEmpty
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                title: Text(userName),
              );
            },
          );
        },
      ),
    );
  }
}
