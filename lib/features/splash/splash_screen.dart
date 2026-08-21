import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// Shown while auth resolves, and not one frame longer.
///
/// It holds no timer and makes no navigation decision of its own: the router's
/// redirect moves off this screen the moment `authLoaded` flips. A splash with
/// its own minimum duration is just a fixed tax on every launch, paid by a
/// teacher who is already standing in front of a class.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/thinktacLogo_white.svg',
                width: 180.w,
                semanticsLabel: 'app.title'.tr(),
              ),
              SizedBox(height: AppDimensions.spacing32),
              SizedBox(
                height: 24.r,
                width: 24.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              ),
              SizedBox(height: AppDimensions.spacing16),
              Text(
                'splash.message'.tr(),
                style: AppTypography.bodySmall.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
