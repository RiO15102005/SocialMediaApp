import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

class SharePostScreen extends StatefulWidget {
  final Post post;

  const SharePostScreen({Key? key, required this.post}) : super(key: key);

  @override
  _SharePostScreenState createState() => _SharePostScreenState();
}

class _SharePostScreenState extends State<SharePostScreen> {
  final _chatService = ChatService();
  final _userService = UserService();
  final _messageController = TextEditingController();
  List<String> _selectedRecipients = [];
  late Future<List<Map<String, String>>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _userService.getFriends();
  }

  void _toggleRecipient(String userId) {
    setState(() {
      if (_selectedRecipients.contains(userId)) {
        _selectedRecipients.remove(userId);
      } else {
        _selectedRecipients.add(userId);
      }
    });
  }

  void _sendSharedPost() {
    if (_selectedRecipients.isEmpty) {
      // Show an error or prompt to select recipients
      return;
    }

    _chatService.sendSharedPost(
      recipientIds: _selectedRecipients,
      postId: widget.post.postId,
      message: _messageController.text,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Share Post', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16.0),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Add a message...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: FutureBuilder<List<Map<String, String>>>(
              future: _friendsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No friends to show.'));
                }

                final friends = snapshot.data!;

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = _selectedRecipients.contains(friend['id']!);

                    return CheckboxListTile(
                      title: Text(friend['name']!),
                      value: isSelected,
                      onChanged: (value) => _toggleRecipient(friend['id']!),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _sendSharedPost,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
