import 'package:flutter/material.dart';

class AddPostButton extends StatelessWidget {
  final VoidCallback? onAddPost;

  const AddPostButton({super.key, this.onAddPost});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1877F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onAddPost,
        icon: const Icon(Icons.post_add, color: Colors.white),
        label: const Text('Thêm bài viết', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
