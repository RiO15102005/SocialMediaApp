import 'package:flutter/material.dart';

class ProfileCover extends StatelessWidget {
  final ImageProvider? coverImage;
  final bool isMyProfile;
  final VoidCallback? onPickCover;

  const ProfileCover({
    super.key,
    this.coverImage,
    required this.isMyProfile,
    this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: coverImage != null ? DecorationImage(image: coverImage!, fit: BoxFit.cover) : null,
          ),
        ),
        if (isMyProfile)
          Positioned(
            bottom: 10,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.black),
                onPressed: onPickCover,
              ),
            ),
          ),
      ],
    );
  }
}
