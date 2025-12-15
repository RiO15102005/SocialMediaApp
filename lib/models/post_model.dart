import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content; // For a repost, this is the quote.
  final String? imageUrl; // <-- THÊM TRƯỜNG MỚI ĐỂ LƯU URL ẢNH
  final List<String> likes;
  final List<String> savers;
  final List<String> repostedBy;
  final int shares;
  final Timestamp timestamp;
  final int commentsCount;
  bool isHidden;
  bool isDeleted;

  // Repost-specific fields
  final bool isRepost;
  final Post? originalPost;

  Post({
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.imageUrl, // <-- THÊM VÀO CONSTRUCTOR
    required this.likes,
    required this.savers,
    required this.repostedBy,
    required this.shares,
    required this.timestamp,
    required this.commentsCount,
    this.isHidden = false,
    this.isDeleted = false,
    this.isRepost = false,
    this.originalPost,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Post(
      postId: doc.id,
      userId: data['UID'] ?? '',
      userName: data['userName'] ?? 'Ẩn danh',
      userAvatar: data['userAvatar'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'], // <-- ĐỌC TỪ FIRESTORE
      likes: List<String>.from(data['likes'] ?? []),
      savers: List<String>.from(data['savers'] ?? []),
      repostedBy: List<String>.from(data['repostedBy'] ?? []),
      shares: data['shares'] ?? 0,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      commentsCount: data['commentsCount'] ?? 0,
      isHidden: data['isHidden'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isRepost: data['isRepost'] ?? false,
      originalPost: data['originalPost'] != null ? Post.fromMap(data['originalPost']) : null,
    );
  }

  // Create a Post from a map (used for the nested originalPost)
  factory Post.fromMap(Map<String, dynamic> map) {
     return Post(
      postId: map['postId'] ?? '',
      userId: map['UID'] ?? '',
      userName: map['userName'] ?? 'Ẩn danh',
      userAvatar: map['userAvatar'],
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'], // <-- THÊM VÀO ĐỂ HIỂN THỊ ẢNH TRONG BÀI REPOST
      timestamp: map['timestamp'] ?? Timestamp.now(),
      // These fields are not needed for the nested post card.
      likes: [],
      savers: [],
      repostedBy: [],
      shares: 0,
      commentsCount: 0,
    );
  }

  // Convert a Post object to a Map for storing in Firestore as a nested object
  Map<String, dynamic> toEmbeddedMap() {
    return {
      'postId': postId,
      'UID': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'imageUrl': imageUrl, // <-- THÊM VÀO ĐỂ LƯU KHI BÀI VIẾT ĐƯỢC REPOST
      'timestamp': timestamp,
    };
  }
}
