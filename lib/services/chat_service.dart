// lib/services/chat_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Stream danh sách phòng chat
  Stream<QuerySnapshot> chatRoomsStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // Stream tin nhắn
  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Gửi tin nhắn Text
  Future<void> sendMessage(String receiverId, String message,
      {bool isGroup = false, String? replyToMessage}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = Timestamp.now();

    await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
      "senderId": uid,
      "receiverId": isGroup ? null : receiverId,
      "message": message,
      "type": "text",
      "replyToMessage": replyToMessage,
      "timestamp": timestamp,
      "readBy": [uid], // Người gửi mặc định đã xem
      "reactions": {}, // Thêm reactions map
      "likedBy": [],
      "deletedFor": [],
      "isRecalled": false,
    });

    await _firestore.collection("chat_rooms").doc(roomId).set({
      if (!isGroup) "participants": [uid, receiverId],
      "lastMessage": message,
      "updatedAt": timestamp,
      "lastSenderId": uid,
    }, SetOptions(merge: true));
  }

  // Gửi hình ảnh
  Future<void> sendImageMessage(String receiverId, File imageFile,
      {bool isGroup = false, String? replyToMessage}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = Timestamp.now();

    try {
      String fileName = "${timestamp.millisecondsSinceEpoch}.jpg";
      Reference ref = _storage.ref().child('chat_images').child(roomId).child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid,
        "receiverId": isGroup ? null : receiverId,
        "message": "📷 Hình ảnh",
        "imageUrl": downloadUrl,
        "type": "image",
        "replyToMessage": replyToMessage,
        "timestamp": timestamp,
        "readBy": [uid],
        "reactions": {},
        "likedBy": [],
        "deletedFor": [],
        "isRecalled": false,
      });

      await _firestore.collection("chat_rooms").doc(roomId).set({
        if (!isGroup) "participants": [uid, receiverId],
        "lastMessage": "📷 [Hình ảnh]",
        "updatedAt": timestamp,
        "lastSenderId": uid,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Lỗi gửi ảnh: $e");
    }
  }

  // Gửi tin nhắn hệ thống
  Future<void> _sendSystemMessage(String groupId, String message) async {
    await _firestore.collection("chat_rooms").doc(groupId).collection("messages").add({
      "senderId": "system",
      "message": message,
      "type": "system",
      "timestamp": Timestamp.now(),
      "readBy": [],
      "reactions": {},
      "likedBy": [],
      "deletedFor": [],
      "isRecalled": false,
    });

    await _firestore.collection("chat_rooms").doc(groupId).set({
      "lastMessage": message,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ================= ĐÁNH DẤU ĐÃ ĐỌC (CẬP NHẬT MỚI) =================
  Future<void> markMessagesAsRead(String roomId) async {
    final uid = _auth.currentUser!.uid;

    // Lấy 20 tin nhắn gần nhất để tối ưu
    final snap = await _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .limit(20)
        .get();

    WriteBatch batch = _firestore.batch();
    bool hasUpdate = false;

    for (var doc in snap.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? []);

      // Nếu ID của mình chưa có trong mảng readBy thì thêm vào
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          "readBy": FieldValue.arrayUnion([uid])
        });
        hasUpdate = true;
      }
    }

    if (hasUpdate) {
      await batch.commit();
    }

    // Cập nhật lastReadTime cho Chat List
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "lastReadTime": {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  // Xóa đoạn chat (Ẩn khỏi list)
  Future<void> hideChatRoom(String roomId) async {
    final uid = _auth.currentUser!.uid;
    final snap = await _firestore.collection("chat_rooms").doc(roomId).collection("messages").get();
    WriteBatch batch = _firestore.batch();
    for (var msg in snap.docs) {
      final data = msg.data();
      final deletedFor = List<String>.from(data['deletedFor'] ?? []);
      if (!deletedFor.contains(uid)) {
        batch.update(msg.reference, {"deletedFor": FieldValue.arrayUnion([uid])});
      }
    }
    await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "deletedAt": {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<void> deleteMessageForMe(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId).update({
      "deletedFor": FieldValue.arrayUnion([uid])
    });
  }

  Future<void> recallMessage(String roomId, String msgId) async {
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    await ref.update({
      "isRecalled": true, "message": "Tin nhắn đã được thu hồi", "type": "text", "reactions": {}, "likedBy": []
    });
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Reaction Logic
  Future<void> sendReaction(String roomId, String msgId, String reactionType) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    await ref.update({"reactions.$uid": reactionType});
  }

  Future<void> removeReaction(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    await ref.update({"reactions.$uid": FieldValue.delete()});
  }

  // Support cũ cho toggle like (nếu vẫn dùng)
  Future<void> toggleLikeMessage(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final List likedBy = List.from(snap.data()!["likedBy"] ?? []);
    if (likedBy.contains(uid)) {
      await ref.update({"likedBy": FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({"likedBy": FieldValue.arrayUnion([uid])});
    }
  }

  String getChatRoomId(String u1, String u2) => u1.compareTo(u2) <= 0 ? "${u1}_$u2" : "${u2}_$u1";

  Future<String> createGroupChat(String name, List<String> members) async {
    final uid = _auth.currentUser!.uid;
    final ref = await _firestore.collection("chat_rooms").add({
      "groupName": name, "participants": [uid, ...members], "isGroup": true,
      "adminId": uid, "lastReadTime": {}, "lastMessage": "Đã tạo nhóm",
      "lastSenderId": uid, "updatedAt": FieldValue.serverTimestamp()
    });
    return ref.id;
  }

  Future<void> addMembersToGroup(String groupId, List<String> members) async {
    await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayUnion(members)});
    final uid = _auth.currentUser!.uid;
    final myDoc = await _firestore.collection('users').doc(uid).get();
    final myName = myDoc.data()?['displayName'] ?? "Ai đó";
    for (var mId in members) {
      final mDoc = await _firestore.collection('users').doc(mId).get();
      final mName = mDoc.data()?['displayName'] ?? "thành viên mới";
      await _sendSystemMessage(groupId, "$myName đã thêm $mName vào nhóm");
    }
  }

  Future<void> removeMemberFromGroup(String groupId, String uidToRemove) async {
    await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayRemove([uidToRemove])});
    final currentUid = _auth.currentUser!.uid;
    final myDoc = await _firestore.collection('users').doc(currentUid).get();
    final myName = myDoc.data()?['displayName'] ?? "Quản trị viên";
    final mDoc = await _firestore.collection('users').doc(uidToRemove).get();
    final mName = mDoc.data()?['displayName'] ?? "thành viên";
    await _sendSystemMessage(groupId, "$myName đã mời $mName ra khỏi nhóm");
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayRemove([uid])});
    final myDoc = await _firestore.collection('users').doc(uid).get();
    final myName = myDoc.data()?['displayName'] ?? "Một thành viên";
    await _sendSystemMessage(groupId, "$myName đã rời nhóm");
  }

  Future<void> deleteChatRoom(String roomId) async {
    final snap = await _firestore.collection("chat_rooms").doc(roomId).collection("messages").get();
    WriteBatch batch = _firestore.batch();
    for (var msg in snap.docs) batch.delete(msg.reference);
    await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).delete();
  }

  Future<void> sendSharedPost({required List<String> recipientIds, required String postId, String? message}) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final senderName = userDoc.data()?['displayName'] ?? 'Người dùng';
    final postDoc = await _firestore.collection('POST').doc(postId).get();
    if (!postDoc.exists) return;
    final postData = postDoc.data()!;
    final postContent = postData['content'] ?? '';
    final originalAuthorName = postData['userName'] ?? 'Người dùng';

    for (String recipientId in recipientIds) {
      final recipientDoc = await _firestore.collection('chat_rooms').doc(recipientId).get();
      final bool isGroup = recipientDoc.exists && (recipientDoc.data()?['isGroup'] ?? false);
      final roomId = isGroup ? recipientId : getChatRoomId(uid, recipientId);

      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid, "receiverId": isGroup ? null : recipientId,
        "message": message, "postId": postId, "type": "shared_post",
        "sharedPostContent": postContent, "sharedPostUserName": originalAuthorName,
        "timestamp": Timestamp.now(), "readBy": [uid], "reactions": {}, "likedBy": [], "deletedFor": [], "isRecalled": false,
      });
      await _firestore.collection("notifications").add({
        "userId": recipientId, "senderId": uid, "senderName": senderName, "postId": postId, "type": "shared_post", "message": message, "timestamp": Timestamp.now(), "isRead": false
      });
      final lastMessageText = "Đã chia sẻ một bài viết của $originalAuthorName";
      await _firestore.collection("chat_rooms").doc(roomId).set({
        if (!isGroup) "participants": [uid, recipientId],
        "lastMessage": message != null && message.isNotEmpty ? message : lastMessageText,
        "updatedAt": FieldValue.serverTimestamp(), "lastSenderId": uid,
      }, SetOptions(merge: true));
    }
  }
}