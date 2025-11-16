import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final String postCol = "POST";
  final String commentCol = "COMMENTS";

  // ============================================================
  //                   TẠO BÀI VIẾT + GỬI NOTI CHO BẠN BÈ
  // ============================================================
  Future<void> createPost({required String content}) async {
    final user = _auth.currentUser;
    if (user == null || content.trim().isEmpty) return;

    final userDoc =
    await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName'] ?? user.email ?? "Ẩn danh";

    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    // Tạo bài viết
    final newPost = await _firestore.collection(postCol).add({
      "UID": user.uid,
      "userName": userName,
      "content": content.trim(),
      "likes": [],
      "commentsCount": 0,
      "timestamp": Timestamp.now(),
    });

    // 🔔 Gửi thông báo cho bạn bè
    for (var f in friends) {
      await _firestore.collection("notifications").add({
        "userId": f,               // người nhận
        "senderId": user.uid,      // người đăng bài
        "senderName": userName,
        "postId": newPost.id,
        "type": "post",
        "timestamp": Timestamp.now(),
        "isRead": false
      });
    }
  }

  // ============================================================
  //                          LIKE + NOTIFICATION
  // ============================================================
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final snap = await postRef.get();

    List<dynamic> likes = snap.data()?['likes'] ?? [];
    final postOwner = snap.data()?['UID'];

    final isLiked = likes.contains(user.uid);

    if (isLiked) {
      await postRef.update({
        "likes": FieldValue.arrayRemove([user.uid])
      });
    } else {
      await postRef.update({
        "likes": FieldValue.arrayUnion([user.uid])
      });

      // 🔔 Gửi thông báo like
      if (user.uid != postOwner) {
        final udoc = await _firestore.collection('users').doc(user.uid).get();
        final name = udoc.data()?['displayName'] ?? "Người dùng";

        await _firestore.collection('notifications').add({
          "userId": postOwner,
          "senderId": user.uid,
          "senderName": name,
          "postId": postId,
          "type": "like",
          "timestamp": Timestamp.now(),
          "isRead": false
        });
      }
    }
  }

  // ============================================================
  //                     XÓA BÀI VIẾT
  // ============================================================
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final doc = await postRef.get();
    if (!doc.exists || doc['UID'] != user.uid) return;

    // Xoá comments
    final comments = await postRef.collection(commentCol).get();
    for (final c in comments.docs) {
      await c.reference.delete();
    }

    await postRef.delete();
  }

  // ============================================================
  //                     STREAM COMMENT
  // ============================================================
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection(postCol)
        .doc(postId)
        .collection(commentCol)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // ============================================================
  //               GỬI COMMENT + NOTIFICATION
  // ============================================================
  Future<void> sendComment(
      String postId,
      String text,
      String userName, {
        String? parentId,
      }) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final postSnap = await postRef.get();
    final postOwner = postSnap.data()?['UID'];

    // Tạo comment
    final newComment = await postRef.collection(commentCol).add({
      "UID": user.uid,
      "userName": userName,
      "content": text.trim(),
      "timestamp": Timestamp.now(),
      "parentId": parentId,
    });

    await postRef.update({
      "commentsCount": FieldValue.increment(1)
    });

    // 🔔 NOTI: Bình luận vào bài viết
    if (parentId == null && user.uid != postOwner) {
      await _firestore.collection("notifications").add({
        "userId": postOwner,
        "senderId": user.uid,
        "senderName": userName,
        "postId": postId,
        "commentId": newComment.id,
        "type": "comment",
        "timestamp": Timestamp.now(),
        "isRead": false
      });
    }

    // 🔔 NOTI: Trả lời bình luận
    if (parentId != null) {
      final parentSnap = await postRef.collection(commentCol).doc(parentId).get();
      final parentOwner = parentSnap.data()?['UID'];

      if (parentOwner != user.uid) {
        await _firestore.collection("notifications").add({
          "userId": parentOwner,
          "senderId": user.uid,
          "senderName": userName,
          "postId": postId,
          "commentId": parentId,
          "type": "reply",
          "timestamp": Timestamp.now(),
          "isRead": false
        });
      }
    }
  }

  // ============================================================
  //              XOÁ COMMENT (CÓ KIỂM TRA QUYỀN)
  // ============================================================
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final postSnap = await postRef.get();
    final postOwner = postSnap.data()?['UID'];

    final commentRef = postRef.collection(commentCol).doc(commentId);
    final commentSnap = await commentRef.get();

    if (!commentSnap.exists) return;

    final commentOwner = commentSnap.data()?['UID'];

    // Quyền xoá:
    // 1. Chủ bài viết -> xoá tất cả comment
    // 2. Chủ bình luận -> chỉ xoá comment của mình
    if (user.uid == postOwner || user.uid == commentOwner) {
      await commentRef.delete();
      await postRef.update({
        "commentsCount": FieldValue.increment(-1)
      });
    }
  }

  // ============================================================
  //                   STREAM TẤT CẢ BÀI VIẾT
  // ============================================================
  Stream<QuerySnapshot> getAllPostsStream() {
    return _firestore
        .collection(postCol)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
