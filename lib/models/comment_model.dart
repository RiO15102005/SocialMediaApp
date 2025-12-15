import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final String? imageUrl;
  final Timestamp timestamp;
  final String? parentId;
  final List<String> likes;

  Comment({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.parentId,
    required this.likes,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      commentId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ?? 'Ẩn danh',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'],
      likes: List<String>.from(data['likes'] ?? []),
    );
  }

  int get likesCount => likes.length;
}
