// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final String _userCollection = 'users';

  // Tạo hồ sơ cơ bản khi user đăng ký
  Future<void> createBasicProfile(User user) async {
    final userRef = _firestore.collection(_userCollection).doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Người dùng mới',
        'bio': '',
        'friends': [],      // 👈 SỬA CHÍNH XÁC CHỖ NÀY
        'photoURL': '',
        'createdAt': Timestamp.now(),
      });
    }
  }

  // Lấy danh sách bạn bè (Newfeed)
  Future<List<String>> getCurrentUserFriendsList() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore.collection(_userCollection).doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        return [user.uid];
      }

      final data = doc.data()!;
      final friends = List<String>.from(data['friends'] ?? []); // 👈 ĐÚNG KEY

      // Newfeed phải hiển thị cả bài của mình
      friends.add(user.uid);

      return friends.toSet().toList();
    } catch (e) {
      return [user!.uid];
    }
  }

  // Load dữ liệu profile
  Future<Map<String, dynamic>?> loadUserData(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection(_userCollection).doc(uid).get();
    return doc.data();
  }

  // Lưu thay đổi profile
  Future<void> saveProfileChanges(String uid, String displayName, String bio) async {
    if (uid.isEmpty) return;

    try {
      await _firestore.collection(_userCollection).doc(uid).set({
        'displayName': displayName.trim(),
        'bio': bio.trim(),
      }, SetOptions(merge: true));

      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
    } catch (e) {
      throw Exception('Lỗi khi lưu hồ sơ: $e');
    }
  }
}
