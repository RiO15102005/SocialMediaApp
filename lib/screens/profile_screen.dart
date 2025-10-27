import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_profile_screen.dart';
import 'chat_screen.dart';
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
  bool _friendRequestSent = false;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? currentUser!.uid;
    _isMyProfile = (_targetUserId == currentUser!.uid);
    if (!_isMyProfile) _checkFriendRequest();
  }

  Future<void> _checkFriendRequest() async {
    final sent = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUser!.uid)
        .where('receiverId', isEqualTo: _targetUserId)
        .get();
    if (mounted) {
      setState(() {
        _friendRequestSent = sent.docs.isNotEmpty;
      });
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      if (isAvatar) {
        _avatarImage = File(pickedFile.path);
      } else {
        _coverImage = File(pickedFile.path);
      }
    });

    String path = isAvatar ? 'avatars/$_targetUserId.jpg' : 'covers/$_targetUserId.jpg';
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .update(isAvatar ? {'avatarUrl': url} : {'coverUrl': url});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvatar ? 'Cập nhật avatar thành công!' : 'Cập nhật ảnh bìa thành công!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
    }
  }

  Future<void> _sendFriendRequest() async {
    if (currentUser == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final existingRequest = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUser!.uid)
        .where('receiverId', isEqualTo: _targetUserId)
        .get();

    if (!mounted) return;

    if (existingRequest.docs.isNotEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Bạn đã gửi lời mời đến người này.')),
      );
      return;
    }

    final myUserData =
    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final targetUserData =
    await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();

    try {
      await FirebaseFirestore.instance.collection('friend_requests').add({
        'senderId': currentUser!.uid,
        'senderEmail': myUserData.data()?['email'],
        'receiverId': _targetUserId,
        'receiverEmail': targetUserData.data()?['email'],
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });

      if (!mounted) return;
      setState(() => _friendRequestSent = true);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Đã gửi lời mời kết bạn!')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gửi lời mời thất bại: $e')),
      );
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (currentUser == null) return;
    final requests = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUser!.uid)
        .where('receiverId', isEqualTo: _targetUserId)
        .get();

    for (var doc in requests.docs) {
      await doc.reference.delete();
    }

    if (!mounted) return;
    setState(() => _friendRequestSent = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã hủy lời mời kết bạn')));
  }

  Future<void> _startChat() async {
    if (currentUser == null) return;

    final navigator = Navigator.of(context);
    List<String> ids = [currentUser!.uid, _targetUserId];
    ids.sort();
    String chatId = ids.join('_');

    DocumentSnapshot chatDoc =
    await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTimestamp': Timestamp.now(),
      });
    }

    final targetUserData =
    await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
    if (!mounted) return;

    final data = targetUserData.data();
    final String receiverName = (data?['displayName'] as String?) ?? 'Người dùng';

    navigator.push(
      MaterialPageRoute(builder: (context) => ChatScreen(chatId: chatId, receiverName: receiverName)),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Widget _buildActionButton(Map<String, dynamic> userData) {
    if (_isMyProfile) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1877F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))
              .then((_) => setState(() {}));
        },
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('Chỉnh sửa hồ sơ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    final bool areFriends = (userData['friends'] as List?)?.contains(currentUser?.uid) ?? false;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        _friendRequestSent || areFriends ? Colors.grey[300] : const Color(0xFF1877F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: areFriends
          ? _startChat
          : _friendRequestSent
          ? _cancelFriendRequest
          : _sendFriendRequest,
      icon: Icon(
        areFriends
            ? Icons.chat_bubble_outline
            : _friendRequestSent
            ? Icons.cancel
            : Icons.person_add_alt_1,
        color: areFriends ? Colors.black : Colors.white,
      ),
      label: Text(
        areFriends
            ? 'Nhắn tin'
            : _friendRequestSent
            ? 'Hủy lời mời'
            : 'Thêm bạn bè',
        style: TextStyle(
          color: areFriends ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        title: const Text(
          'Trang cá nhân',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(_targetUserId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Không thể tải thông tin người dùng.'));
          }

          final userData = snapshot.data!.data()!;
          final displayName = userData['displayName'] ?? 'Chưa có tên';
          final bio = userData['bio'] ?? 'Chưa có tiểu sử';
          final friends = (userData['friends'] as List?) ?? [];
          final friendsCount = friends.length;
          final coverUrl = userData['coverUrl'] ?? '';
          final avatarUrl = userData['avatarUrl'] ?? '';

          ImageProvider? avatarProvider;
          if (avatarUrl.isNotEmpty) {
            avatarProvider = NetworkImage(avatarUrl);
          } else if (_avatarImage != null) {
            avatarProvider = FileImage(_avatarImage!);
          }

          ImageProvider? coverProvider;
          if (coverUrl.isNotEmpty) {
            coverProvider = NetworkImage(coverUrl);
          } else if (_coverImage != null) {
            coverProvider = FileImage(_coverImage!);
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        image: coverProvider != null
                            ? DecorationImage(image: coverProvider, fit: BoxFit.cover)
                            : null,
                      ),
                    ),
                    if (_isMyProfile)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.black),
                            onPressed: () => _pickImage(false),
                          ),
                        ),
                      ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      if (_isMyProfile)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF1877F2),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.camera_alt,
                                  size: 18, color: Colors.white),
                              onPressed: () => _pickImage(true),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendsScreen(userId: _targetUserId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  splashColor: Colors.blue.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      "$friendsCount người bạn",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Giới thiệu",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 8),
                      Text(
                        bio.isNotEmpty ? bio : "Chưa có thông tin giới thiệu",
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: double.infinity, child: _buildActionButton(userData)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
