import 'package:flutter/material.dart';

class ProfileInfo extends StatelessWidget {
  final String displayName;
  final String bio;
  final int friendsCount;
  final VoidCallback? onFriendsTap;

  const ProfileInfo({
    super.key,
    required this.displayName,
    required this.bio,
    required this.friendsCount,
    this.onFriendsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onFriendsTap,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              Text(bio.isNotEmpty ? bio : "Chưa có thông tin giới thiệu",
                  style: const TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
