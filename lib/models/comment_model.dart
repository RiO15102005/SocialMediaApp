// lib/models/comment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final Timestamp timestamp;
  final String? parentId;

  Comment({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    this.parentId,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      commentId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ?? 'Ẩn danh',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'], // reply parent id
    );
  }
}
