import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final String _userCollection = 'users';
  final String _postCollection = 'POST';

  // Create a basic profile when a user signs up
  Future<void> createBasicProfile(User user) async {
    final userRef = _firestore.collection(_userCollection).doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'New User',
        'bio': '',
        'friends': [],
        'savedPosts': [], // Add this field
        'photoURL': '',
        'createdAt': Timestamp.now(),
      });
    }
  }

  // Get the list of friends for the news feed
  Future<List<String>> getCurrentUserFriendsList() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore.collection(_userCollection).doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        return [user.uid];
      }

      final data = doc.data()!;
      final friends = List<String>.from(data['friends'] ?? []);

      // The news feed should also show the user's own posts
      friends.add(user.uid);

      return friends.toSet().toList();
    } catch (e) {
      return [user.uid];
    }
  }
  // Get the list of friends for the current user
  Future<List<Map<String, String>>> getFriends() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore.collection(_userCollection).doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        return [];
      }

      final data = doc.data()!;
      final friendIds = List<String>.from(data['friends'] ?? []);

      if (friendIds.isEmpty) {
        return [];
      }

      final friendDocs = await _firestore
          .collection(_userCollection)
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();

      return friendDocs.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['displayName'] as String?) ?? 'N/A',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }


  // Load user profile data
  Future<Map<String, dynamic>?> loadUserData(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection(_userCollection).doc(uid).get();
    return doc.data();
  }

  // Save profile changes
  Future<void> saveProfileChanges(String uid, String displayName, String bio) async {
    if (uid.isEmpty) return;

    try {
      await _firestore.collection(_userCollection).doc(uid).set({
        'displayName': displayName.trim(),
        'bio': bio.trim(),
      }, SetOptions(merge: true));

      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
    } catch (e) {
      throw Exception('Error saving profile: $e');
    }
  }

  // Save or unsave a post
  Future<void> toggleSavePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection(_userCollection).doc(user.uid);
    final doc = await userRef.get();

    if (doc.exists) {
      final savedPosts = List<String>.from(doc.data()?['savedPosts'] ?? []);
      if (savedPosts.contains(postId)) {
        await userRef.update({
          'savedPosts': FieldValue.arrayRemove([postId])
        });
      } else {
        await userRef.update({
          'savedPosts': FieldValue.arrayUnion([postId])
        });
      }
    }
  }

  // Get a stream of saved posts for the current user
  Stream<List<Post>> getSavedPostsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(_userCollection)
        .doc(user.uid)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return [];

      final savedPostIds = List<String>.from(userDoc.data()?['savedPosts'] ?? []);
      if (savedPostIds.isEmpty) return [];

      final postFutures = savedPostIds
          .map((postId) => _firestore.collection(_postCollection).doc(postId).get())
          .toList();

      final postDocs = await Future.wait(postFutures);

      return postDocs
          .where((doc) => doc.exists)
          .map((doc) => Post.fromFirestore(doc))
          .toList();
    });
  }
}
