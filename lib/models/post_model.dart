import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final List<String> likes;
  final List<String> savers;
  final List<String> repostedBy;
  final int shares;
  final Timestamp timestamp;
  final int commentsCount;
  bool isHidden;
  bool isDeleted;

  Post({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.likes,
    required this.savers,
    required this.repostedBy,
    required this.shares,
    required this.timestamp,
    required this.commentsCount,
    this.isHidden = false,
    this.isDeleted = false,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Post(
      postId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ?? 'Ẩn danh',
      content: data['content'] ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      savers: List<String>.from(data['savers'] ?? []),
      repostedBy: List<String>.from(data['repostedBy'] ?? []),
      shares: data['shares'] ?? 0,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      commentsCount: data['commentsCount'] ?? 0,
      isHidden: data['isHidden'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}
