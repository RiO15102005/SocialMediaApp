import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';

class SharePostScreen extends StatefulWidget {
  final Post post;

  const SharePostScreen({Key? key, required this.post}) : super(key: key);

  @override
  _SharePostScreenState createState() => _SharePostScreenState();
}

class _SharePostScreenState extends State<SharePostScreen> {
  final _postService = PostService();
  final _userService = UserService();
  final _chatService = ChatService();
  final _quoteController = TextEditingController();
  List<String> _selectedFriends = [];
  late Future<List<Map<String, String>>> _friendsFuture;
  final String? _currentUserAvatar = FirebaseAuth.instance.currentUser?.photoURL;
  final String? _currentUserName = FirebaseAuth.instance.currentUser?.displayName;
  bool _isSharing = false; // To prevent double taps


  @override
  void initState() {
    super.initState();
    _friendsFuture = _userService.getFriends();
  }

  void _toggleFriendSelection(String userId) {
    setState(() {
      if (_selectedFriends.contains(userId)) {
        _selectedFriends.remove(userId);
      } else {
        _selectedFriends.add(userId);
      }
    });
  }

  Future<void> _performShareAction() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // If friends are selected, send a message
      if (_selectedFriends.isNotEmpty) {
        _chatService.sendSharedPost(
          recipientIds: _selectedFriends,
          postId: widget.post.postId,
          message: _quoteController.text, 
        );
        _postService.incrementShare(widget.post.postId);
        if (mounted) {
          Navigator.of(context).pop('sent');
        }
      } 
      // Otherwise, repost to the user's feed
      else {
        await _postService.repost(widget.post.postId, _quoteController.text);
        if (mounted) {
          Navigator.of(context).pop('reposted');
        }
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã có lỗi xảy ra: ${e.toString()}')),
        );
      }
       setState(() => _isSharing = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: _currentUserAvatar != null ? NetworkImage(_currentUserAvatar!) : null,
                      child: _currentUserAvatar == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentUserName ?? 'Bạn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _quoteController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Hãy nói gì đó...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                    onPressed: _performShareAction,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSharing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('Chia sẻ ngay'),
                    ),
                ),
              ),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Gửi bằng Messenger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: FutureBuilder<List<Map<String, String>>>(
                  future: _friendsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Không có bạn bè.'));
                    }

                    final friends = snapshot.data!;
                    
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selectedFriends.contains(friend['id']!);
                        
                        return GestureDetector(
                          onTap: () => _toggleFriendSelection(friend['id']!),
                          child: SizedBox(
                            width: 70,
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: friend['avatar'] != null && friend['avatar']!.isNotEmpty ? NetworkImage(friend['avatar']!) : null,
                                      child: friend['avatar'] == null || friend['avatar']!.isEmpty ? const Icon(Icons.person) : null,
                                    ),
                                    if (isSelected)
                                      const Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.white,
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundColor: Colors.blue,
                                            child: Icon(Icons.check, size: 12, color: Colors.white),
                                          ), 
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  friend['name']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
