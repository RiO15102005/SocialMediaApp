// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final List<String> likes;
  final int shares;
  final Timestamp timestamp;
  final int commentsCount;

  Post({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.likes,
    required this.shares,
    required this.timestamp,
    required this.commentsCount,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Post(
      postId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ,
      content: data['Cont'] ?? '',
      likes: List<String>.from(data['Like'] ?? []),
      shares: data['Share'] ?? 0,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      commentsCount: data['commentsCount'] ?? 0,
    );
  }
}