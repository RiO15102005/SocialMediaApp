class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final List<String> repostedPosts;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.repostedPosts = const [],
  });
}
