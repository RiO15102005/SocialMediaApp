import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LikesScreen extends StatelessWidget {
  final List<String> userIds;

  const LikesScreen({Key? key, required this.userIds}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lượt thích'),
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
                leading: CircleAvatar(
                  backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null ? const Icon(Icons.person) : null,
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
