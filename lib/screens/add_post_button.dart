import 'package:flutter/material.dart';

class AddPostButton extends StatelessWidget {
  final VoidCallback? onAddPost;

  const AddPostButton({super.key, this.onAddPost});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onAddPost,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Tạo bài viết',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}
