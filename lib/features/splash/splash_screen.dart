import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/tc_brand_tile.dart';
import '../../core/widgets/tc_dots_loader.dart';

/// The first screen of a cold start, matching the approved 2026-08 mockup.
///
/// It still makes no navigation decision of its own. The router's redirect
/// moves off this screen, now gated on BOTH `authLoaded` and the minimum
/// display window in `SplashGate`, so the branding is actually seen instead of
/// flashing past on a warm start. The hold is a deliberate reversal of this
/// file's earlier "no minimum duration" rule, made on Divya's instruction that
/// the splash must appear before the login page; the cost is documented in
/// NOTES.md.
///
/// Every string here comes from the mockup, via `assets/l10n`. The native
/// launch window (`android/.../launch_background.xml`, `values-v31/styles.xml`)
/// paints the same navy and logo, so the OS-to-Flutter handover is invisible.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Design-spec sizes, scaled at build time.
  static const double _tileSize = 140;
  static const double _logoSize = 84;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Flat navy, not the hero gradient: the mockup's field is a single tone.
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TcBrandTile(size: _tileSize, logoSize: _logoSize),
                SizedBox(height: AppDimensions.spacing24),
                Text(
                  'app.brand'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: AppDimensions.spacing12),
                Text(
                  // Upper-cased in the widget, not in the JSON, so the Hindi
                  // string is not mangled by a casing rule that does not apply
                  // to Devanagari.
                  'splash.product'.tr().toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle.copyWith(
                    color: AppColors.splashProductLabel,
                    letterSpacing: 2.5,
                  ),
                ),
                SizedBox(height: AppDimensions.spacing12),
                Text(
                  'splash.tagline'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onNavySecondary,
                  ),
                ),
                SizedBox(height: AppDimensions.spacing32),
                TcDotsLoader(
                  // The old "Getting things ready…" copy is not in the mockup,
                  // so it is no longer drawn — but it is exactly what a screen
                  // reader should hear in place of three silent dots.
                  semanticsLabel: 'splash.message'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
