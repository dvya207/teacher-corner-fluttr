import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

/// Rounded-square tinted icon container — the mockup's list-row leading tile
/// (classroom list, quiz list, events, awards). Defaults to the sky tint;
/// pass [color] for the amber/mustard/grey variants.
class TcIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const TcIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.skyBlue,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    // Square tactile tile: scale the box and its glyph with `.r` (min axis) so
    // it stays a proportionate square on every device. `size` is the
    // design-spec value; scaling happens here, never at static init.
    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular((size * 0.27).r),
      ),
      child: Icon(icon, color: color, size: (size * 0.5).r),
    );
  }
}
