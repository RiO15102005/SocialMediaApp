import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================= STREAM PHÒNG CHAT =================
  Stream<QuerySnapshot> chatRoomsStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ================= STREAM TIN NHẮN ====================
  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ================= GỬI TIN NHẮN =======================
  Future<void> sendMessage(String receiverId, String message,
      {bool isGroup = false}) async {
    final uid = _auth.currentUser!.uid;

    final roomId = isGroup ? receiverId : getChatRoomId(uid, receiverId);

    await _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .add({
      "senderId": uid,
      "receiverId": isGroup ? null : receiverId,
      "message": message,
      "timestamp": Timestamp.now(),
      "isRead": false,
      "likedBy": [],
      "deletedFor": [],
      "isRecalled": false,
    });

    // Cập nhật lastMessage + updatedAt để chat list refresh
    await _firestore.collection("chat_rooms").doc(roomId).set({
      if (!isGroup) "participants": [uid, receiverId],
      "lastMessage": message,
      "updatedAt": FieldValue.serverTimestamp(),
      "lastSenderId": uid,
    }, SetOptions(merge: true));
  }

  // ================= GỬI BÀI VIẾT ĐƯỢC CHIA SẺ =======================
  Future<void> sendSharedPost({
    required List<String> recipientIds,
    required String postId,
    String? message,
  }) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final senderName = userDoc.data()?['displayName'] ?? 'Người dùng';

    final postDoc = await _firestore.collection('POST').doc(postId).get();
    if (!postDoc.exists) {
      return;
    }
    final postData = postDoc.data()!;
    final postContent = postData['content'] ?? '';
    final originalAuthorName = postData['userName'] ?? 'Người dùng';

    for (String recipientId in recipientIds) {
      // Determine if the recipient is a group or a single user
      final recipientDoc =
          await _firestore.collection('chat_rooms').doc(recipientId).get();
      final bool isGroup =
          recipientDoc.exists && (recipientDoc.data()?['isGroup'] ?? false);

      final roomId = isGroup ? recipientId : getChatRoomId(uid, recipientId);

      // Add a new message with the shared post
      final newMessage = await _firestore
          .collection("chat_rooms")
          .doc(roomId)
          .collection("messages")
          .add({
        "senderId": uid,
        "receiverId": isGroup ? null : recipientId,
        "message": message,
        "postId": postId,
        "type": "shared_post",
        "sharedPostContent": postContent,
        "sharedPostUserName": originalAuthorName,
        "timestamp": Timestamp.now(),
        "isRead": false,
        "likedBy": [],
        "deletedFor": [],
        "isRecalled": false,
      });

      // Create a notification for the recipient
      await _firestore.collection("notifications").add({
        "userId": recipientId,
        "senderId": uid,
        "senderName": senderName,
        "postId": postId,
        "type": "shared_post",
        "message": message,
        "timestamp": Timestamp.now(),
        "isRead": false
      });
      
      final lastMessageText = "Đã chia sẻ một bài viết của $originalAuthorName: \"$postContent\"";

      // Update the last message and timestamp of the chat room
      await _firestore.collection("chat_rooms").doc(roomId).set({
        if (!isGroup) "participants": [uid, recipientId],
        "lastMessage": message != null && message.isNotEmpty ? message : lastMessageText,
        "updatedAt": FieldValue.serverTimestamp(),
        "lastSenderId": uid,
      }, SetOptions(merge: true));
    }
  }

  // ================= ĐÁNH DẤU ĐÃ ĐỌC ====================
  Future<void> markMessagesAsRead(String roomId, {bool isGroup = false}) async {
    final uid = _auth.currentUser!.uid;

    QuerySnapshot snap;

    if (isGroup) {
      snap = await _firestore
          .collection("chat_rooms")
          .doc(roomId)
          .collection("messages")
          .where("senderId", isNotEqualTo: uid)
          .where("isRead", isEqualTo: false)
          .get();
    } else {
      snap = await _firestore
          .collection("chat_rooms")
          .doc(roomId)
          .collection("messages")
          .where("receiverId", isEqualTo: uid)
          .where("isRead", isEqualTo: false)
          .get();
    }

    if (snap.docs.isNotEmpty) {
      WriteBatch batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {"isRead": true});
      }
      await batch.commit();
    }

    // CHỈ update lastReadTime (không đụng updatedAt) để tránh flicker
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "lastReadTime": {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  // ================= LIKE / UNLIKE ======================
  Future<void> toggleLikeMessage(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .doc(msgId);

    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final List likedBy = List.from(data["likedBy"] ?? []);

    if (likedBy.contains(uid)) {
      await ref.update({"likedBy": FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({"likedBy": FieldValue.arrayUnion([uid])});
    }

    // Bump room updatedAt để UI chat list có thể phản ứng (tùy ý — nếu không muốn thì bỏ)
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ================= THU HỒI TIN NHẮN ===================
  Future<void> recallMessage(String roomId, String msgId) async {
    final ref = _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .doc(msgId);

    final snap = await ref.get();
    if (!snap.exists) return;

    await ref.update({
      "isRecalled": true,
      "message": "Tin nhắn đã được thu hồi •",
      "likedBy": [],
    });

    // Nếu tin nhắn này là lastMessage của phòng -> cập nhật lastMessage
    final lastMsgSnap = await _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .limit(1)
        .get();

    if (lastMsgSnap.docs.isNotEmpty && lastMsgSnap.docs.first.id == msgId) {
      await _firestore.collection("chat_rooms").doc(roomId).set({
        "lastMessage": "Tin nhắn đã được thu hồi •",
        "updatedAt": FieldValue.serverTimestamp(),
        "lastSenderId": snap.data()!["senderId"],
      }, SetOptions(merge: true));
    } else {
      // Bump updatedAt để chat_list nhận biết
      await _firestore.collection("chat_rooms").doc(roomId).set({
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ================= XÓA 1 TIN NHẮN CHO MÌNH =============
  Future<void> deleteMessageForMe(String roomId, String msgId) async {
    final uid = _auth.currentUser!.uid;
    final ref = _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .doc(msgId);

    final snap = await ref.get();
    if (!snap.exists) return;

    await ref.update({
      "deletedFor": FieldValue.arrayUnion([uid])
    });

    // bump updatedAt để chat list biết có thay đổi (giúp update preview)
    await _firestore.collection("chat_rooms").doc(roomId).set({
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ================= XÓA CHAT 1 PHÍA ====================
  Future<void> hideChatRoom(String roomId) async {
    final uid = _auth.currentUser!.uid;

    final snap = await _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .get();

    WriteBatch batch = _firestore.batch();

    for (var msg in snap.docs) {
      batch.update(msg.reference, {
        "deletedFor": FieldValue.arrayUnion([uid])
      });
    }

    await batch.commit();

    await _firestore.collection("chat_rooms").doc(roomId).set({
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ================= XÓA PHÒNG CHAT (ADMIN) ======================
  Future<void> deleteChatRoom(String roomId) async {
    final snap = await _firestore
        .collection("chat_rooms")
        .doc(roomId)
        .collection("messages")
        .get();

    WriteBatch batch = _firestore.batch();
    for (var msg in snap.docs) {
      batch.delete(msg.reference);
    }

    await batch.commit();
    await _firestore.collection("chat_rooms").doc(roomId).delete();
  }

  // ================= ROOM ID ============================
  String getChatRoomId(String u1, String u2) {
    return u1.compareTo(u2) <= 0 ? "${u1}_$u2" : "${u2}_$u1";
  }

  // ================= GROUP ==============================
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

    return ref.id;
  }

  Future<void> addMembersToGroup(String groupId, List<String> members) async {
    await _firestore
        .collection("chat_rooms")
        .doc(groupId)
        .update({"participants": FieldValue.arrayUnion(members)});
  }

  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    await _firestore
        .collection("chat_rooms")
        .doc(groupId)
        .update({"participants": FieldValue.arrayRemove([uid])});
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection("chat_rooms")
        .doc(groupId)
        .update({"participants": FieldValue.arrayRemove([uid])});
  }
}
