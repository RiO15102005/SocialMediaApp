import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

class PostService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final String postCol = "POST";
  final String commentCol = "COMMENTS";

  Future<void> createPost({required String content}) async {
    final user = _auth.currentUser;
    if (user == null || content.trim().isEmpty) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['displayName'] ?? user.email ?? "Ẩn danh";
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    final newPost = await _firestore.collection(postCol).add({
      "UID": user.uid,
      "userName": userName,
      "content": content.trim(),
      "likes": [],
      "savers": [],
      "commentsCount": 0,
      "timestamp": Timestamp.now(),
      "isHidden": false,
      "isDeleted": false,
    });

    for (var f in friends) {
      await _firestore.collection("notifications").add({
        "userId": f,
        "senderId": user.uid,
        "senderName": userName,
        "postId": newPost.id,
        "type": "post",
        "timestamp": Timestamp.now(),
        "isRead": false
      });
    }
  }

  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final snap = await postRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data == null) return;

    final likes = List<String>.from(data['likes'] ?? []);
    final postOwner = data['UID'];
    final isLiked = likes.contains(user.uid);

    if (isLiked) {
      await postRef.update({"likes": FieldValue.arrayRemove([user.uid])});
    } else {
      await postRef.update({"likes": FieldValue.arrayUnion([user.uid])});
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

  Future<void> toggleSavePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final snap = await postRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data == null) return;

    final savers = List<String>.from(data['savers'] ?? []);
    final isSaved = savers.contains(user.uid);

    if (isSaved) {
      await postRef.update({"savers": FieldValue.arrayRemove([user.uid])});
    } else {
      await postRef.update({"savers": FieldValue.arrayUnion([user.uid])});
    }
  }

  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    await postRef.update({'isDeleted': true});
  }

  Future<void> unDeletePost(String postId) async {
    final postRef = _firestore.collection(postCol).doc(postId);
    await postRef.update({'isDeleted': false});
  }

  Future<void> hidePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    await postRef.update({'isHidden': true});
  }

  Future<void> unhidePost(String postId) async {
    final postRef = _firestore.collection(postCol).doc(postId);
    await postRef.update({'isHidden': false});
  }

  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection(postCol)
        .doc(postId)
        .collection(commentCol)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

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

    final newComment = await postRef.collection(commentCol).add({
      "UID": user.uid,
      "userName": userName,
      "content": text.trim(),
      "timestamp": Timestamp.now(),
      "parentId": parentId,
      "likes": [],
    });

    await postRef.update({"commentsCount": FieldValue.increment(1)});

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

    if (user.uid == postOwner || user.uid == commentOwner) {
      await commentRef.delete();
      await postRef.update({"commentsCount": FieldValue.increment(-1)});
    }
  }

  Future<void> toggleCommentLike(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final commentRef = _firestore
        .collection(postCol)
        .doc(postId)
        .collection(commentCol)
        .doc(commentId);

    final snap = await commentRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data == null) return;

    final likes = List<String>.from(data['likes'] ?? []);
    final isLiked = likes.contains(user.uid);

    if (isLiked) {
      await commentRef.update({"likes": FieldValue.arrayRemove([user.uid])});
    } else {
      await commentRef.update({"likes": FieldValue.arrayUnion([user.uid])});
    }
  }

  Stream<QuerySnapshot> getAllPostsStream() {
    return _firestore
        .collection(postCol)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserPostsStream(String userId) {
    return _firestore
        .collection(postCol)
        .where('UID', isEqualTo: userId)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getSavedPostsStream(String userId) {
    return _firestore
        .collection(postCol)
        .where('savers', arrayContains: userId)
        .snapshots();
  }
}
