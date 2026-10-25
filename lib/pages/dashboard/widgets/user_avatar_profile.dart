import 'package:avatar_builder/avatar_builder.dart';
import 'package:flutter/material.dart';

class UserAvatarProfile extends StatelessWidget {
  final Avataaar avatar;
  final double size;
  final bool isCircle; // True untuk foto profil, False untuk badan penuh

  const UserAvatarProfile({
    Key? key,
    required this.avatar,
    this.size = 80,
    this.isCircle = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget = AvatarWidget(avatar: avatar, size: size);

    if (isCircle) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: Colors.white, width: 3),
        ),
        // Crop bagian atas (kepala) agar pas di lingkaran
        child: ClipOval(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size,
              height: size,
              child: avatarWidget,
            ),
          ),
        ),
      );
    }

    // Tampilan full body (untuk Focus Session)
    return avatarWidget;
  }
}