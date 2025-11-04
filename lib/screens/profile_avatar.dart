import 'dart:io';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final ImageProvider? avatarImage;
  final bool isMyProfile;
  final VoidCallback? onPickAvatar;

  const ProfileAvatar({
    super.key,
    this.avatarImage,
    required this.isMyProfile,
    this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 50,
              backgroundImage: avatarImage,
              child: avatarImage == null ? const Icon(Icons.person, size: 50) : null,
            ),
          ),
          if (isMyProfile)
            Positioned(
              bottom: 4,
              right: 4,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1877F2),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  onPressed: onPickAvatar,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
