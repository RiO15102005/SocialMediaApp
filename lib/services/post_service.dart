import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/post_model.dart';

class PostService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _supabaseClient = supabase.Supabase.instance.client;

  final String postCol = "POST";
  final String commentCol = "COMMENTS";
  final String usersCol = "users";
  final String savedPostsSubCol = "saved_posts";


  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = 'public/$fileName';

      await _supabaseClient.storage
          .from('Post_media')
          .upload(filePath, imageFile);

      final imageUrl = _supabaseClient.storage
          .from('Post_media')
          .getPublicUrl(filePath);

      return imageUrl;
    } on supabase.StorageException catch (e) {
      print("Lỗi Supabase Storage: ${e.message}");
      return null;
    }
    catch (e) {
      print("Lỗi không xác định khi tải ảnh lên: $e");
      return null;
    }
  }

  Future<void> _deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final filePath = uri.pathSegments.last;
      await _supabaseClient.storage.from('Post_media').remove(['public/$filePath']);
    } catch (e) {
      print("Lỗi xóa ảnh: $e");
    }
  }


  Future<void> createPost({required String content, File? imageFile}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (content.trim().isEmpty && imageFile == null) {
      return; 
    }
    
    String? imageUrl;
    if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile);
        if (imageUrl == null) {
            throw Exception("Không thể tải ảnh lên. Vui lòng thử lại.");
        }
    }

    final userDoc = await _firestore.collection(usersCol).doc(user.uid).get();
    final userName =
        userDoc.data()?['displayName'] ?? user.email ?? "Ẩn danh";
    final userAvatar = userDoc.data()?['photoURL'];
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    final newPostRef = await _firestore.collection(postCol).add({
      "UID": user.uid,
      "userName": userName,
      "userAvatar": userAvatar,
      "content": content.trim(),
      "imageUrl": imageUrl,
      "likes": [],
      "savers": [],
      "repostedBy": [],
      "commentsCount": 0,
      "shares": 0,
      "timestamp": Timestamp.now(),
      "isHidden": false,
      "isDeleted": false,
      "isRepost": false,
      "originalPost": null,
    });

    for (var f in friends) {
      await _firestore.collection("notifications").add({
        "userId": f,
        "senderId": user.uid,
        "senderName": userName,
        "postId": newPostRef.id,
        "type": "post",
        "timestamp": Timestamp.now(),
        "isRead": false
      });
    }
  }

  Future<void> updatePost(String postId, String newContent, {File? newImage, bool imageRemoved = false}) async {
    final postRef = _firestore.collection(postCol).doc(postId);
    final postSnap = await postRef.get();
    if (!postSnap.exists) return;

    Map<String, dynamic> updates = {'content': newContent};
    String? oldImageUrl = postSnap.data()?['imageUrl'];

    if (imageRemoved) {
      if (oldImageUrl != null) await _deleteImage(oldImageUrl);
      updates['imageUrl'] = null;
    } else if (newImage != null) {
      if (oldImageUrl != null) await _deleteImage(oldImageUrl);
      updates['imageUrl'] = await _uploadImage(newImage);
    }

    await postRef.update(updates);
  }

  Future<void> repost(String originalPostId, String quote) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection(postCol).doc(originalPostId);
    final postDoc = await postRef.get();

    if (!postDoc.exists) {
      throw Exception("Bài viết gốc không tồn tại.");
    }

    final originalPost = Post.fromFirestore(postDoc);

    final userDoc = await _firestore.collection(usersCol).doc(user.uid).get();
    final userName =
        userDoc.data()?['displayName'] ?? user.email ?? "Ẩn danh";
    final userAvatar = userDoc.data()?['photoURL'];

    await _firestore.collection(postCol).add({
      "UID": user.uid,
      "userName": userName,
      "userAvatar": userAvatar,
      "content": quote, 
      "likes": [],
      "savers": [],
      "repostedBy": [],
      "commentsCount": 0,
      "shares": 0,
      "timestamp": Timestamp.now(),
      "isHidden": false,
      "isDeleted": false,
      "isRepost": true,
      "originalPost": originalPost.toEmbeddedMap(), 
    });

    await postRef.update({
      'repostedBy': FieldValue.arrayUnion([user.uid])
    });
  }

  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection(postCol).doc(postId).get();
      if (doc.exists) {
        return Post.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print("Error fetching post by ID: $e");
      return null;
    }
  }

  Future<List<Post>> getPostsFromPostIds(List<String> postIds) async {
    if (postIds.isEmpty) {
      return [];
    }
    try {
      final querySnapshot = await _firestore
          .collection(postCol)
          .where(FieldPath.documentId, whereIn: postIds)
          .get();
      return querySnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching posts from IDs: $e");
      return [];
    }
  }

  Stream<QuerySnapshot> getRepostedPostsStream(String userId) {
    return _firestore
        .collection(postCol)
        .where('repostedBy', arrayContains: userId)
        .snapshots();
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
        final udoc = await _firestore.collection(usersCol).doc(user.uid).get();
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

    final savedPostRef = _firestore
        .collection(usersCol)
        .doc(user.uid)
        .collection(savedPostsSubCol)
        .doc(postId);

    final postRef = _firestore.collection(postCol).doc(postId);
    final savedDoc = await savedPostRef.get();

    if (savedDoc.exists) {
      await savedPostRef.delete();
      await postRef.update({
        "savers": FieldValue.arrayRemove([user.uid])
      });
    } else {
      await savedPostRef.set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        "savers": FieldValue.arrayUnion([user.uid])
      });
    }
  }

  Future<void> incrementShare(String postId) async {
    final postRef = _firestore.collection(postCol).doc(postId);
    await postRef.update({'shares': FieldValue.increment(1)});
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
    File? imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (text.trim().isEmpty && imageFile == null) return;

    final postRef = _firestore.collection(postCol).doc(postId);
    final postSnap = await postRef.get();
    final postOwner = postSnap.data()?['UID'];

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile);
      if (imageUrl == null) {
        throw Exception("Không thể tải ảnh lên. Vui lòng thử lại.");
      }
    }

    final newComment = await postRef.collection(commentCol).add({
      "UID": user.uid,
      "userName": userName,
      "content": text.trim(),
      "imageUrl": imageUrl,
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
      final parentSnap =
          await postRef.collection(commentCol).doc(parentId).get();
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

  Future<void> updateComment(
      String postId, String commentId, String newContent,
      {File? newImage, bool imageRemoved = false}) async {
    final commentRef = _firestore
        .collection(postCol)
        .doc(postId)
        .collection(commentCol)
        .doc(commentId);
    final commentSnap = await commentRef.get();
    if (!commentSnap.exists) return;

    Map<String, dynamic> updates = {'content': newContent};
    String? oldImageUrl = commentSnap.data()?['imageUrl'];

    if (newImage != null) {
      if (oldImageUrl != null) await _deleteImage(oldImageUrl);
      updates['imageUrl'] = await _uploadImage(newImage);
    } else if (imageRemoved) {
      if (oldImageUrl != null) await _deleteImage(oldImageUrl);
      updates['imageUrl'] = null;
    }

    await commentRef.update(updates);
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

    final commentData = commentSnap.data();
    if (commentData != null &&
        commentData.containsKey('imageUrl') &&
        commentData['imageUrl'] != null) {
      await _deleteImage(commentData['imageUrl']);
    }

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

  Stream<DocumentSnapshot> getPostStream(String postId) {
    return _firestore.collection(postCol).doc(postId).snapshots();
  }

  Stream<QuerySnapshot> getSavedPostIdsStream(String userId) {
    return _firestore
        .collection(usersCol)
        .doc(userId)
        .collection(savedPostsSubCol)
        .orderBy('savedAt', descending: true)
        .snapshots();
  }
}
