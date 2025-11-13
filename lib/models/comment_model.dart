import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final Timestamp timestamp;
  final String? parentId;
  final int replyCount;

  Comment({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    this.parentId,
    this.replyCount = 0,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Comment(
      commentId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ?? 'Vô danh',
      content: data['Comm'] ?? '',
      timestamp: data['Date'] ?? Timestamp.now(),
      parentId: data['parentId'],
      replyCount: data['replyCount'] ?? 0,
    );
  }
}
