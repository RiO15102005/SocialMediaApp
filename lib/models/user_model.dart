class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
  });
}
