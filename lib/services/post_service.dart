import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final String _postCollection = 'POST';
  final String _userCollection = 'users';
  final String _commentSubcollection = 'Comm';

  // === HÀM 1: TẠO POST ===
  Future<void> createPost({required String content}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Người dùng chưa đăng nhập.");
    if (content.trim().isEmpty) throw Exception("Nội dung bài đăng không được để trống.");

    final userDoc = await _firestore.collection(_userCollection).doc(user.uid).get();
    final userData = userDoc.data();
    final String userName = userData?['displayName'] ?? user.email?.split('@')[0] ?? 'Ẩn danh';

    await _firestore.collection(_postCollection).add({
      'UID': user.uid,
      'userName': userName,
      'Cont': content.trim(),
      'Like': [],
      'Share': 0,
      'timestamp': Timestamp.now(),
      'commentsCount': 0,
    });
  }

  // === HÀM 2: LẤY POST ===
  Stream<QuerySnapshot> getPostsStream(List<String> uidsToDisplay) {
    if (uidsToDisplay.isEmpty) {
      return _firestore.collection(_postCollection).where('UID', isEqualTo: 'invalid_uid_placeholder').snapshots();
    }
    if (uidsToDisplay.length > 10) {
      uidsToDisplay = uidsToDisplay.sublist(0, 10);
    }
    return _firestore
        .collection(_postCollection)
        .where('UID', whereIn: uidsToDisplay)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // === HÀM 3: LIKE ===
  Future<void> toggleLike(String postId, List<String> currentLikes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Vui lòng đăng nhập để thích bài viết.");
    final String userId = user.uid;
    final postRef = _firestore.collection(_postCollection).doc(postId);

    final bool isLiked = currentLikes.contains(userId);
    if (isLiked) {
      await postRef.update({'Like': FieldValue.arrayRemove([userId])});
    } else {
      await postRef.update({'Like': FieldValue.arrayUnion([userId])});
    }
  }

  // === HÀM 4: XÓA POST ===
  Future<void> deletePost(String postId, String postUserId) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != postUserId) {
      throw Exception("Bạn không có quyền xóa bài viết này.");
    }
    await _firestore.collection(_postCollection).doc(postId).delete();
  }

  // === HÀM 5: GỬI BÌNH LUẬN (có hỗ trợ trả lời) ===
  Future<void> sendComment(
      String postId,
      String commentText,
      String userName, {
        String? parentId,
      }) async {
    final user = _auth.currentUser;
    if (user == null || commentText.trim().isEmpty) return;

    final commentsRef = _firestore.collection(_postCollection).doc(postId).collection(_commentSubcollection);

    await commentsRef.add({
      'UID': user.uid,
      'userName': userName,
      'Comm': commentText.trim(),
      'Date': Timestamp.now(),
      'parentId': parentId,
      'replyCount': 0,
    });

    // Luôn tăng tổng commentsCount của post (bao gồm cả trả lời)
    await _firestore.collection(_postCollection).doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });

    // Nếu là trả lời thì tăng replyCount của bình luận gốc
    if (parentId != null && parentId.isNotEmpty) {
      final parentRef = commentsRef.doc(parentId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(parentRef);
        if (snap.exists) {
          final current = (snap.data()?['replyCount'] ?? 0) as int;
          tx.update(parentRef, {'replyCount': current + 1});
        }
      });
    }
  }

  // === HÀM 6: LẤY STREAM BÌNH LUẬN (cả gốc và trả lời) ===
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection(_postCollection)
        .doc(postId)
        .collection(_commentSubcollection)
        .orderBy('Date', descending: true)
        .snapshots();
  }

  // === HÀM 7: XÓA BÌNH LUẬN ===
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Bạn chưa đăng nhập.");

    final commentRef = _firestore
        .collection(_postCollection)
        .doc(postId)
        .collection(_commentSubcollection)
        .doc(commentId);

    final snap = await commentRef.get();
    if (!snap.exists) throw Exception("Bình luận không tồn tại.");

    final data = snap.data();
    if (data?['UID'] != user.uid) {
      throw Exception("Bạn không có quyền xóa bình luận này.");
    }

    await commentRef.delete();

    // Giảm tổng số commentsCount của post
    await _firestore.collection(_postCollection).doc(postId).update({
      'commentsCount': FieldValue.increment(-1),
    });
  }
}
