// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final String _userCollection = 'users';

  // === HÀM TẠO HỒ SƠ CƠ BẢN (FIX LỖI PROFILE TRỐNG) ===
  Future<void> createBasicProfile(User user) async {
    final userRef = _firestore.collection(_userCollection).doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Người dùng mới',
        'bio': '',
        'friendsList': [],
        'postCount': 0,
        'followerCount': 0,
        'photoURL': null,
      });
    }
  }

  // === HÀM LẤY DANH SÁCH BẠN BÈ (Cho Newfeed) ===
  Future<List<String>> getCurrentUserFriendsList() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    try {
      final doc = await _firestore.collection(_userCollection).doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final friends = List<String>.from(data['friendsList'] ?? []);
        friends.add(user.uid);
        return friends.toSet().toList();
      }
      return [user.uid];
    } catch (e) {
      return [_auth.currentUser!.uid];
    }
  }

  // === LOGIC LOAD DATA PROFILE ===
  Future<Map<String, dynamic>?> loadUserData(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection(_userCollection).doc(uid).get();
    return doc.data();
  }

  // === FIX: LƯU THAY ĐỔI PROFILE (Sử dụng SET với merge: true) ===
  Future<void> saveProfileChanges(String uid, String displayName, String bio) async {
    if (uid.isEmpty) return;
    try {
      await _firestore.collection(_userCollection).doc(uid).set({
        'displayName': displayName.trim(),
        'bio': bio.trim(),
      }, SetOptions(merge: true)); // FIX LỖI NOT-FOUND

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