import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'friends_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActionButton extends StatelessWidget {
  final bool isMyProfile;
  final String targetUserId;
  final Map<String, dynamic> userData;

  const ActionButton({
    super.key,
    required this.isMyProfile,
    required this.targetUserId,
    required this.userData,
  });

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (isMyProfile) {
      return Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          icon: const Icon(Icons.edit, color: Colors.black),
          label: const Text('Chỉnh sửa hồ sơ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // StreamBuilder kết hợp friends + friend_requests
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
      builder: (context, userSnapshot) {
        final friends = (userSnapshot.data?.get('friends') as List?) ?? [];
        final isFriend = friends.contains(currentUser!.uid);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('senderId', isEqualTo: currentUser!.uid)
              .where('receiverId', isEqualTo: targetUserId)
              .snapshots(),
          builder: (context, reqSnapshot) {
            final hasSentRequest = reqSnapshot.data?.docs.isNotEmpty ?? false;

            if (isFriend) {
              return Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    // Hủy kết bạn logic
                  },
                  icon: const Icon(Icons.people_alt_outlined, color: Colors.black),
                  label: const Text('Bạn bè', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              );
            } else {
              return Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSentRequest ? Colors.grey[300] : const Color(0xFF1877F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: hasSentRequest ? () {} : () {},
                  icon: Icon(hasSentRequest ? Icons.cancel : Icons.person_add_alt_1,
                      color: hasSentRequest ? Colors.black : Colors.white),
                  label: Text(hasSentRequest ? 'Hủy lời mời' : 'Thêm bạn bè',
                      style: TextStyle(
                          color: hasSentRequest ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
              );
            }
          },
        );
      },
    );
  }
}
