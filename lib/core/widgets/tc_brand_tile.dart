import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The white logo mark inside a translucent rounded-square tile.
///
/// Shared because the splash and the sign-in header draw the same thing at two
/// sizes, and the Android launch window paints a third copy of it in XML. One
/// widget here keeps the two Flutter copies from drifting apart.
class TcBrandTile extends StatelessWidget {
  const TcBrandTile({super.key, this.size = 140, this.logoSize = 84});

  /// Design-spec values; scaled with `.r` at build time, never at static init.
  final double size;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        color: AppColors.heroTileBg,
        borderRadius: BorderRadius.circular((size * 0.27).r),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/images/thinktacLogo_white.svg',
        width: logoSize.r,
        semanticsLabel: 'app.title'.tr(),
      ),
    );
  }
}

/// The white logo mark on its own, with no tile behind it.
///
/// Separate from [TcBrandTile] rather than a flag on it: the tile exists to give
/// the mark contrast on the splash and the sign-in screen, where it sits alone
/// on a large field of navy. In a header the mark sits next to text on the same
/// navy, and a translucent square around it reads as a button the teacher can
/// press. Two widgets, because they are two different jobs.
class TcBrandMark extends StatelessWidget {
  const TcBrandMark({super.key, this.size = 40});

  /// Design-spec value; scaled with `.r` at build time, never at static init.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/thinktacLogo_white.svg',
      width: size.r,
      height: size.r,
      semanticsLabel: 'app.brand'.tr(),
    );
  }
}
