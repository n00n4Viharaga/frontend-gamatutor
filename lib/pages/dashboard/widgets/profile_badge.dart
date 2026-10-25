import 'package:flutter/material.dart';
import '../config/profile_meta.dart';

class ProfileBadge extends StatelessWidget {
  final ProfileMeta meta;
  final bool outlined;
  final double size;

  const ProfileBadge({
    Key? key,
    required this.meta,
    this.outlined = false,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : meta.lightBg,
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: meta.color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(meta.emoji, style: TextStyle(fontSize: size + 2)),
          const SizedBox(width: 6),
          Text(
            meta.displayName,
            style: TextStyle(
              color: meta.color,
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}