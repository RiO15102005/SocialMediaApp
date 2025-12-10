import 'dart:io';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final ImageProvider<Object>? avatarImage;
  final bool isMyProfile;
  final VoidCallback? onPickAvatar;

  const ProfileAvatar({
    super.key,
    required this.avatarImage,
    required this.isMyProfile,
    this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -35),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 55,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? const Icon(Icons.person, size: 55)
                  : null,
            ),
          ),

          if (isMyProfile)
            Positioned(
              bottom: 4,
              right: 4,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF1877F2),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: onPickAvatar,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
