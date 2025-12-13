// lib/services/chat_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import thư viện Supabase

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Khởi tạo client Supabase để thao tác với Storage
  final _supabase = Supabase.instance.client;

  // ----------------------------------------------------------------------
  // CÁC HÀM STREAM (Lắng nghe dữ liệu)
  // ----------------------------------------------------------------------

  // Stream danh sách phòng chat
  Stream<QuerySnapshot> chatRoomsStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // Stream tin nhắn trong một phòng (Sắp xếp mới nhất ở đầu)
  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Stream tin nhắn cuối cùng (Dùng cho màn hình danh sách chat)
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
  // CÁC HÀM GỬI TIN NHẮN
  // ----------------------------------------------------------------------

  // Gửi tin nhắn văn bản (Text)
  Future<void> sendMessage(String receiverId, String message,
      {bool isGroup = false, String? replyToMessage, String? replyToName}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // Lưu tin nhắn vào collection 'messages'
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

    // Cập nhật thông tin phòng chat (để hiển thị tin nhắn cuối ở danh sách)
    await _firestore.collection("chat_rooms").doc(roomId).set({
      if (!isGroup) "participants": [uid, receiverId],
      "lastMessage": message,
      "updatedAt": timestamp,
      "lastSenderId": uid,
    }, SetOptions(merge: true));
  }

  // ⭐ Gửi hình ảnh (SỬ DỤNG SUPABASE STORAGE)
  Future<void> sendImageMessage(String receiverId, File imageFile,
      {bool isGroup = false, String? replyToMessage, String? replyToName}) async {
    final uid = _auth.currentUser!.uid;
    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);
    final timestamp = FieldValue.serverTimestamp();
    final fileTimestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Tạo tên file và đường dẫn trên Supabase
      // Cấu trúc: roomId/uid-timestamp.jpg
      String fileName = "$uid-$fileTimestamp.jpg";
      String filePath = "$roomId/$fileName";

      // 2. Upload ảnh lên bucket 'chat_images'
      await _supabase.storage.from('chat_images').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true
        ),
      );

      // 3. Lấy đường dẫn công khai (Public URL)
      String downloadUrl = _supabase.storage
          .from('chat_images')
          .getPublicUrl(filePath);

      // 4. Lưu thông tin tin nhắn vào Firestore
      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid,
        "receiverId": isGroup ? null : receiverId,
        "message": "📷 Hình ảnh",
        "imageUrl": downloadUrl, // URL từ Supabase
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

      // 5. Cập nhật phòng chat
      await _firestore.collection("chat_rooms").doc(roomId).set({
        if (!isGroup) "participants": [uid, receiverId],
        "lastMessage": "📷 [Hình ảnh]",
        "updatedAt": timestamp,
        "lastSenderId": uid,
      }, SetOptions(merge: true));

    } catch (e) {
      print("❌ Lỗi gửi ảnh qua Supabase: $e");
    }
  }

  // ----------------------------------------------------------------------
  // CÁC HÀM TƯƠNG TÁC (Thu hồi, Xóa, Reaction, Like)
  // ----------------------------------------------------------------------

  // ⭐ HÀM THU HỒI TIN NHẮN (Kèm logic xóa ảnh trên Supabase)
  Future<void> recallMessage(String roomId, String msgId) async {
    try {
      // 1. Lấy reference tới tài liệu tin nhắn
      final docRef = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);

      // Đọc tin nhắn trước để kiểm tra nội dung
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() as Map<String, dynamic>;

      // 2. Nếu là tin nhắn ảnh và có URL -> Xóa file trên Supabase
      if (data['type'] == 'image' && data['imageUrl'] != null) {
        String imageUrl = data['imageUrl'];

        // Trích xuất đường dẫn file từ URL
        // URL Supabase thường có dạng: .../chat_images/roomId/filename.jpg
        if (imageUrl.contains("/chat_images/")) {
          final parts = imageUrl.split("/chat_images/");
          if (parts.length > 1) {
            // Decode để xử lý các ký tự đặc biệt (ví dụ khoảng trắng -> %20)
            final filePath = Uri.decodeFull(parts[1]);

            // Gọi lệnh xóa của Supabase
            await _supabase.storage.from('chat_images').remove([filePath]);
            print("🗑️ Đã xóa ảnh trên Supabase: $filePath");
          }
        }
      }

      // 3. Cập nhật trạng thái tin nhắn trong Firestore thành "Đã thu hồi"
      await docRef.update({
        "isRecalled": true,
        "message": "Tin nhắn đã được thu hồi",
        "type": "text",      // Chuyển về dạng text
        "imageUrl": null,    // Xóa liên kết ảnh
        "reactions": {},
        "likedBy": []
      });

      // 4. Cập nhật thời gian phòng chat để refresh danh sách nếu cần
      await _firestore.collection("chat_rooms").doc(roomId).set(
          {"updatedAt": FieldValue.serverTimestamp()}, SetOptions(merge: true));

    } catch (e) {
      print("❌ Lỗi khi thu hồi tin nhắn: $e");
    }
  }

  // Xóa tin nhắn "Chỉ ở phía tôi" (Delete For Me)
  Future<void> deleteMessageForMe(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId).update({"deletedFor": FieldValue.arrayUnion([uid])});
  }

  // Ẩn/Xóa đoạn chat (Chỉ ở phía tôi)
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

  // Thả cảm xúc (Reaction)
  Future<void> sendReaction(String roomId, String msgId, String reactionType) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    await ref.update({"reactions.$uid": reactionType});
  }

  // Gỡ cảm xúc
  Future<void> removeReaction(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    await ref.update({"reactions.$uid": FieldValue.delete()});
  }

  // Thích tin nhắn (Like)
  Future<void> toggleLikeMessage(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore.collection("chat_rooms").doc(roomId).collection("messages").doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final List likedBy = List.from(snap.data()!["likedBy"] ?? []);
    if (likedBy.contains(uid)) await ref.update({"likedBy": FieldValue.arrayRemove([uid])});
    else await ref.update({"likedBy": FieldValue.arrayUnion([uid])});
  }

  // Đánh dấu đã đọc
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

  // ----------------------------------------------------------------------
  // CÁC HÀM XỬ LÝ NHÓM CHAT (Group Chat)
  // ----------------------------------------------------------------------

  // Gửi tin nhắn hệ thống (Thông báo trong nhóm)
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

  // Tạo nhóm mới
  Future<String> createGroupChat(String name, List<String> members) async {
    final uid = _auth.currentUser!.uid;
    final ref = await _firestore.collection("chat_rooms").add({
      "groupName": name,
      "participants": [uid, ...members],
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

  // Xử lý gửi tin nhắn hệ thống khi tạo nhóm
  Future<void> _handleGroupCreationSystemMessages(String groupId, String groupName, List<String> members, String uid) async {
    try {
      final myDoc = await _firestore.collection('users').doc(uid).get();
      final myName = myDoc.data()?['displayName'] ?? "QTV";

      await _sendSystemMessage(groupId, "$myName đã tạo nhóm \"$groupName\"");

      for (var memberId in members) {
        if (memberId == uid) continue;
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        if (memberDoc.exists) {
          final memberName = memberDoc.data()?['displayName'] ?? "thành viên mới";
          await _sendSystemMessage(groupId, "$myName đã thêm $memberName vào nhóm");
        }
      }
    } catch (e) {
      print("Lỗi gửi tin nhắn hệ thống (Background): $e");
    }
  }

  // Thêm thành viên vào nhóm
  Future<void> addMembersToGroup(String groupId, List<String> members) async {
    await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayUnion(members)});

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

  // Mời thành viên ra khỏi nhóm (Kick)
  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayRemove([uid])});
    final cUid = _auth.currentUser!.uid; final mDoc = await _firestore.collection('users').doc(cUid).get(); final myName = mDoc.data()?['displayName'] ?? "QTV";
    final tDoc = await _firestore.collection('users').doc(uid).get(); final tName = tDoc.data()?['displayName'] ?? "thành viên";
    await _sendSystemMessage(groupId, "$myName đã mời $tName ra khỏi nhóm");
  }

  // Rời nhóm
  Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser!.uid; await _firestore.collection("chat_rooms").doc(groupId).update({"participants": FieldValue.arrayRemove([uid])});
    final mDoc = await _firestore.collection('users').doc(uid).get(); final myName = mDoc.data()?['displayName'] ?? "Một thành viên";
    await _sendSystemMessage(groupId, "$myName đã rời nhóm");
  }

  // Giải tán nhóm (Xóa toàn bộ)
  Future<void> deleteChatRoom(String roomId) async {
    final snap = await _firestore.collection("chat_rooms").doc(roomId).collection("messages").get();
    WriteBatch batch = _firestore.batch(); for (var msg in snap.docs) batch.delete(msg.reference); await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).delete();
  }

  // ----------------------------------------------------------------------
  // TIỆN ÍCH
  // ----------------------------------------------------------------------

  // Chia sẻ bài viết
  Future<void> sendSharedPost({required List<String> recipientIds, required String postId, String? message}) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final senderName = userDoc.data()?['displayName'] ?? 'Người dùng';
    final postDoc = await _firestore.collection('POST').doc(postId).get(); if (!postDoc.exists) return;
    final postData = postDoc.data()!; final postContent = postData['content'] ?? ''; final originalAuthorName = postData['userName'] ?? 'Người dùng';
    for (String recipientId in recipientIds) {
      final recipientDoc = await _firestore.collection('chat_rooms').doc(recipientId).get();
      final bool isGroup = recipientDoc.exists && (recipientDoc.data()?['isGroup'] ?? false);
      final roomId = isGroup ? recipientId : getChatRoomId(uid, recipientId);
      final timestamp = FieldValue.serverTimestamp();

      await _firestore.collection("chat_rooms").doc(roomId).collection("messages").add({
        "senderId": uid, "receiverId": isGroup ? null : recipientId, "message": message, "postId": postId,
        "type": "shared_post", "sharedPostContent": postContent, "sharedPostUserName": originalAuthorName,
        "timestamp": timestamp, "readBy": [uid], "reactions": {}, "likedBy": [], "deletedFor": [], "isRecalled": false,
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

  // Tạo ID phòng chat 1-1 (Sắp xếp theo alphabet để luôn duy nhất)
  String getChatRoomId(String u1, String u2) => u1.compareTo(u2) <= 0 ? "${u1}_$u2" : "${u2}_$u1";
}