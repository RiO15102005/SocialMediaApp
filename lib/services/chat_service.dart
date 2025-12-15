import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _supabase = Supabase.instance.client;

  // ----------------------------------------------------------------------
  // CÁC HÀM STREAM
  // ----------------------------------------------------------------------

  Stream<QuerySnapshot> chatRoomsStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ⭐ Lọc tin nhắn theo mốc thời gian (startAfter)
  Stream<QuerySnapshot> getMessages(String roomId, {Timestamp? startAfter}) {
    Query query = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    if (startAfter != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startAfter);
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> getLastMessageStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  // ----------------------------------------------------------------------
  // GỬI TIN NHẮN
  // ----------------------------------------------------------------------

  Future<void> sendMessage(String receiverId, String message,
      {bool isGroup = false, String? replyToMessage, String? replyToName}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();

    await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
      "senderId": uid,
      "receiverId": isGroup ? null : receiverId,
      "message": message,
      "type": "text",
      "replyToMessage": replyToMessage,
      "replyToName": replyToName,
      "timestamp": timestamp,
      "readBy": [uid],
      "reactions": {},
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

  Future<void> sendImageMessage(String receiverId, File imageFile,
      {bool isGroup = false, String? replyToMessage, String? replyToName}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();
    final fileTimestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      String fileName = "$uid-$fileTimestamp-${DateTime.now().microsecond}.jpg";
      String filePath = "$roomId/$fileName";

      await _supabase.storage.from('chat_images').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      String downloadUrl = _supabase.storage.from('chat_images').getPublicUrl(filePath);

      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid,
        "receiverId": isGroup ? null : receiverId,
        "message": "📷 Hình ảnh",
        "imageUrl": downloadUrl,
        "type": "image",
        "replyToMessage": replyToMessage,
        "replyToName": replyToName,
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
      print("❌ Lỗi gửi ảnh: $e");
    }
  }

  // ----------------------------------------------------------------------
  // NHÓM CHAT (GROUP) - LOGIC JOIN TIME
  // ----------------------------------------------------------------------

  Future<String> createGroupChat(String name, List<String> members) async {
    final uid = _auth.currentUser!.uid;
    final timestamp = Timestamp.now();

    // Khởi tạo joinTimes cho các thành viên ban đầu
    Map<String, Timestamp> joinTimes = {};
    joinTimes[uid] = timestamp;
    for (var m in members) {
      joinTimes[m] = timestamp;
    }

    final ref = await _firestore.collection("chat_rooms").add({
      "groupName": name,
      "participants": [uid, ...members],
      "joinTimes": joinTimes, // ⭐ Lưu
      "isGroup": true,
      "adminId": uid,
      "lastReadTime": {},
      "lastMessage": "Đã tạo nhóm",
      "lastSenderId": uid,
      "updatedAt": FieldValue.serverTimestamp()
    });

    _handleGroupCreationSystemMessages(ref.id, name, members, uid);
    return ref.id;
  }

  Future<void> addMembersToGroup(String groupId, List<String> members) async {
    final timestamp = Timestamp.now();

    await _firestore.collection("chat_rooms").doc(groupId).update({
      "participants": FieldValue.arrayUnion(members)
    });

    // Cập nhật joinTimes cho thành viên mới
    Map<String, dynamic> updates = {};
    for (var m in members) {
      updates["joinTimes.$m"] = timestamp;
    }
    if (updates.isNotEmpty) {
      await _firestore.collection("chat_rooms").doc(groupId).update(updates);
    }

    final uid = _auth.currentUser!.uid;
    final myDoc = await _firestore.collection('users').doc(uid).get();
    final myName = myDoc.data()?['displayName'] ?? "Ai đó";

    for (var mId in members) {
      if (mId == uid) continue;
      final mDoc = await _firestore.collection('users').doc(mId).get();
      final mName = mDoc.data()?['displayName'] ?? "thành viên mới";
      await _sendSystemMessage(groupId, "$myName đã thêm $mName vào nhóm");
    }
  }

  // ⭐ XÓA joinTimes KHI RỜI NHÓM ĐỂ RESET LỊCH SỬ
  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    await _firestore.collection("chat_rooms").doc(groupId).update({
      "participants": FieldValue.arrayRemove([uid]),
      "joinTimes.$uid": FieldValue.delete(), // 🔴 Xóa mốc thời gian cũ
    });

    final cUid = _auth.currentUser!.uid;
    final mDoc = await _firestore.collection('users').doc(cUid).get();
    final myName = mDoc.data()?['displayName'] ?? "QTV";
    final tDoc = await _firestore.collection('users').doc(uid).get();
    final tName = tDoc.data()?['displayName'] ?? "thành viên";

    await _sendSystemMessage(groupId, "$myName đã mời $tName ra khỏi nhóm");
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection("chat_rooms").doc(groupId).update({
      "participants": FieldValue.arrayRemove([uid]),
      "joinTimes.$uid": FieldValue.delete(), // 🔴 Xóa mốc thời gian cũ
    });

    final mDoc = await _firestore.collection('users').doc(uid).get();
    final myName = mDoc.data()?['displayName'] ?? "Một thành viên";

    await _sendSystemMessage(groupId, "$myName đã rời nhóm");
  }

  // ----------------------------------------------------------------------
  // CÁC HÀM TIỆN ÍCH KHÁC
  // ----------------------------------------------------------------------

  Future<void> _sendSystemMessage(String groupId, String message) async {
    final timestamp = FieldValue.serverTimestamp();
    await _firestore.collection("chat_rooms").doc(groupId).collection("messages").add({
      "senderId": "system",
      "message": message,
      "type": "system",
      "timestamp": timestamp,
      "readBy": [],
      "reactions": {},
      "likedBy": [],
      "deletedFor": [],
      "isRecalled": false,
    });
    await _firestore.collection("chat_rooms").doc(groupId).set({
      "lastMessage": message,
      "updatedAt": timestamp,
    }, SetOptions(merge: true));
  }

  Future<void> _handleGroupCreationSystemMessages(String groupId, String groupName, List<String> members, String uid) async {
    try {
      final myDoc = await _firestore.collection('users').doc(uid).get();
      final myName = myDoc.data()?['displayName'] ?? "QTV";
      await _sendSystemMessage(groupId, '$myName đã tạo nhóm "$groupName"');
      for (var memberId in members) {
        if (memberId == uid) continue;
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        if (memberDoc.exists) {
          final memberName = memberDoc.data()?['displayName'] ?? "thành viên mới";
          await _sendSystemMessage(groupId, "$myName đã thêm $memberName vào nhóm");
        }
      }
    } catch (e) {
      print("Lỗi system msg: $e");
    }
  }

  Future<void> recallMessage(String roomId, String msgId) async {
    try {
      final docRef = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;
      final data = docSnap.data() as Map<String, dynamic>;

      if (data['type'] == 'image' && data['imageUrl'] != null) {
        String imageUrl = data['imageUrl'];
        if (imageUrl.contains("/chat_images/")) {
          final parts = imageUrl.split("/chat_images/");
          if (parts.length > 1) {
            final filePath = Uri.decodeFull(parts[1]);
            await _supabase.storage.from('chat_images').remove([filePath]);
          }
        }
      }
      await docRef.update({
        "isRecalled": true,
        "message": "Tin nhắn đã được thu hồi",
        "type": "text",
        "imageUrl": null,
        "reactions": {},
        "likedBy": []
      });
      await _firestore.collection("chat_rooms").doc(roomId).set(
          {"updatedAt": FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      print("Error recall: $e");
    }
  }

  Future<void> deleteMessageForMe(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId).update({"deletedFor": FieldValue.arrayUnion([uid])});
  }

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
    await _firestore.collection("chat_rooms").doc(roomId).set({"deletedAt": {uid: FieldValue.serverTimestamp()}}, SetOptions(merge: true));
  }

  Future<void> deleteChatRoom(String roomId) async {
    final snap = await _firestore.collection("chat_rooms").doc(roomId).collection("messages").get();
    WriteBatch batch = _firestore.batch();
    for (var msg in snap.docs) batch.delete(msg.reference);
    await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).delete();
  }

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

  Future<void> toggleLikeMessage(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final List likedBy = List.from(snap.data()!["likedBy"] ?? []);
    if (likedBy.contains(uid)) await ref.update({"likedBy": FieldValue.arrayRemove([uid])});
    else await ref.update({"likedBy": FieldValue.arrayUnion([uid])});
  }

  Future<void> markMessagesAsRead(String roomId) async {
    final uid = _auth.currentUser!.uid;
    final snap = await _firestore.collection("chat_rooms").doc(roomId).collection("messages").orderBy("timestamp", descending: true).limit(20).get();
    WriteBatch batch = _firestore.batch();
    bool hasUpdate = false;
    for (var doc in snap.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {"readBy": FieldValue.arrayUnion([uid])});
        hasUpdate = true;
      }
    }
    if (hasUpdate) await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).set({"lastReadTime": {uid: FieldValue.serverTimestamp()}}, SetOptions(merge: true));
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
    final originalAuthorAvatar = postData['userAvatar'];

    for (String recipientId in recipientIds) {
      final recipientDoc = await _firestore.collection('chat_rooms').doc(recipientId).get();
      final bool isGroup = recipientDoc.exists && (recipientDoc.data()?['isGroup'] ?? false);
      final roomId = isGroup ? recipientId : getChatRoomId(uid, recipientId);
      final timestamp = FieldValue.serverTimestamp();

      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid, 
        "receiverId": isGroup ? null : recipientId, 
        "message": message, 
        "postId": postId,
        "type": "shared_post", 
        "sharedPostContent": postContent, 
        "sharedPostUserName": originalAuthorName,
        "sharedPostUserAvatar": originalAuthorAvatar,
        "timestamp": timestamp, 
        "readBy": [uid], 
        "reactions": {}, 
        "likedBy": [], 
        "deletedFor": [], 
        "isRecalled": false,
      });
      await _firestore.collection("notifications").add({
        "userId": recipientId, "senderId": uid, "senderName": senderName, "postId": postId, "type": "shared_post", "message": message, "timestamp": timestamp, "isRead": false
      });
      final lastMessageText = "Đã chia sẻ một bài viết của $originalAuthorName";
      await _firestore.collection("chat_rooms").doc(roomId).set({
        if (!isGroup) "participants": [uid, recipientId], "lastMessage": message != null && message.isNotEmpty ? message : lastMessageText,
        "updatedAt": timestamp, "lastSenderId": uid,
      }, SetOptions(merge: true));
    }
  }

  String getChatRoomId(String u1, String u2) => u1.compareTo(u2) <= 0 ? "${u1}_$u2" : "${u2}_$u1";
}
