// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_service.dart';
import 'profile_cover.dart';
import 'profile_avatar.dart';
import 'profile_info.dart';
import 'add_post_button.dart';
import 'action_button.dart';
import 'create_post_screen.dart';
import 'friends_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late String _targetUserId;
  late bool _isMyProfile;

  File? _avatarImage;
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? currentUser!.uid;
    _isMyProfile = (_targetUserId == currentUser!.uid);
  }

  Future<void> _pickAvatar() async {}
  Future<void> _pickCover() async {}

  Future<void> _addPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true) {}
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ]
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_targetUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final userData = snapshot.data!.data()!;
          final displayName = userData['displayName'] ?? 'Chưa có tên';
          final bio = userData['bio'] ?? 'Chưa có tiểu sử';
          final friends = (userData['friends'] as List?) ?? [];
          final friendsCount = friends.length;

          ImageProvider? avatarProvider = _avatarImage != null ? FileImage(_avatarImage!) : null;
          ImageProvider? coverProvider = _coverImage != null ? FileImage(_coverImage!) : null;

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

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
