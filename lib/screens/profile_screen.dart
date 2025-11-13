// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'friend_service.dart';
=======
>>>>>>> 65700f8d05b208fb26f4403d68be3d64c1dffe0c
import 'profile_cover.dart';
import 'profile_avatar.dart';
import 'profile_info.dart';
import 'add_post_button.dart';
import 'create_post_screen.dart';
import 'friends_list_screen.dart';
import 'user_post_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  late String _targetUserId;
  late bool _isMyProfile;

  late Future<Map<String, dynamic>?> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser != null) {
      _targetUserId = widget.userId ?? _currentUser!.uid;
      _isMyProfile = (_targetUserId == _currentUser!.uid);
      _userProfileFuture = _loadData();
    } else {
      _targetUserId = widget.userId ?? '';
      _isMyProfile = false;
      _userProfileFuture = Future.value(null);
    }
  }

  Future<Map<String, dynamic>?> _loadData() async {
    if (_targetUserId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
      return doc.data();
    } catch (e) {
      print("Lỗi tải hồ sơ: $e");
      return null;
    }
  }

<<<<<<< HEAD
  Future<void> _pickAvatar() async {}
  Future<void> _pickCover() async {}

=======
>>>>>>> 65700f8d05b208fb26f4403d68be3d64c1dffe0c
  Future<void> _addPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true && mounted) {
      setState(() {
        _userProfileFuture = _loadData();
      });
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      setState(() {
        _userProfileFuture = _loadData();
      });
    }
  }

  Future<void> _pickAvatar() async {}
  Future<void> _pickCover() async {}

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        actions: _isMyProfile
            ? [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('Đăng xuất'),
              ),
            ],
          ),
        ]
            : null,
      ),
<<<<<<< HEAD
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_targetUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final userData = snapshot.data!.data()!;
=======
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải hồ sơ: ${snapshot.error}'));
          }
          if (!snapshot.hasData && _targetUserId.isEmpty) {
            return const Center(child: Text("Vui lòng đăng nhập để xem hồ sơ."));
          }

          final userData = snapshot.data ?? {};
>>>>>>> 65700f8d05b208fb26f4403d68be3d64c1dffe0c
          final displayName = userData['displayName'] ?? 'Chưa có tên';
          final bio = userData['bio'] ?? 'Chưa có tiểu sử';
          final friends = (userData['friends'] as List?) ?? [];
          final friendsCount = friends.length;
          final photoURL = userData['photoURL'];
          final coverURL = userData['coverURL'];

          ImageProvider? avatarProvider = (photoURL != null && photoURL.isNotEmpty) ? NetworkImage(photoURL) : null;
          ImageProvider? coverProvider = (coverURL != null && coverURL.isNotEmpty) ? NetworkImage(coverURL) : null;

          final bool isFriend = friends.contains(currentUser?.uid);

          return SingleChildScrollView(
            child: Column(
              children: [
                ProfileCover(
                  coverImage: coverProvider,
                  isMyProfile: _isMyProfile,
                  onPickCover: _pickCover,
                ),
                ProfileAvatar(
                  avatarImage: avatarProvider,
                  isMyProfile: _isMyProfile,
                  onPickAvatar: _pickAvatar,
                ),
                ProfileInfo(
                  displayName: displayName,
                  bio: bio,
                  friendsCount: friendsCount,
<<<<<<< HEAD
                  onFriendsTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendsScreen(userId: _targetUserId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Nút hành động
                _isMyProfile
                    ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: AddPostButton(onAddPost: _addPost)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ActionButton(
                          isMyProfile: _isMyProfile,
                          targetUserId: _targetUserId,
                          userData: userData,
                        ),
                      ),
                    ],
                  ),
                )
                    : FriendButton(targetUserId: _targetUserId),

=======
                  onFriendsTap: () {},
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildActionButton(context, _isMyProfile, userData),
                ),
>>>>>>> 65700f8d05b208fb26f4403d68be3d64c1dffe0c
                const SizedBox(height: 30),
                UserPostScreen(userId: _targetUserId),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, bool isCurrentUser, Map<String, dynamic> userData) {
    if (isCurrentUser) {
      return Row(
        children: [
          AddPostButton(onAddPost: _addPost),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _editProfile,
              icon: const Icon(Icons.edit, color: Colors.black),
              label: const Text('Chỉnh sửa hồ sơ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text("Theo dõi"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text("Nhắn tin"),
            ),
          ),
        ],
      );
    }
  }
}
