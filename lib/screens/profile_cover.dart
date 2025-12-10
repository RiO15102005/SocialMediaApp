import 'dart:io';
import 'package:flutter/material.dart';

class ProfileCover extends StatelessWidget {
  final ImageProvider<Object>? coverImage;
  final bool isMyProfile;
  final VoidCallback? onPickCover;

  const ProfileCover({
    super.key,
    required this.coverImage,
    required this.isMyProfile,
    this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          color: Colors.grey[300],
          child: coverImage != null
              ? Image(
            image: coverImage!,
            fit: BoxFit.cover,
          )
              : const Icon(Icons.image, size: 80, color: Colors.white),
        ),

        if (isMyProfile)
          Positioned(
            bottom: 10,
            right: 10,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1877F2),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: onPickCover,
              ),
            ),
          ),
      ],
    );
  }
}
