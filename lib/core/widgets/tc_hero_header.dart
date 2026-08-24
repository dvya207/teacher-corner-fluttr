import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Navy hero header with the mockup's 160° gradient and an optional rounded
/// white sheet rising into it from below.
///
/// Wraps the chrome of "hero + sheet" screens (classroom detail, profile,
/// reports, quiz detail): an optional back arrow / breadcrumb line, a title
/// block, and an optional row of [children] (typically TcHeroStatTile)s.
/// The hero is chrome; content belongs on the sheet below — pair with
/// [TcHeroSheet] or any container using [AppDimensions.radiusSheet].
class TcHeroHeader extends StatelessWidget {
  final String? breadcrumb;
  final VoidCallback? onBreadcrumbTap;
  final String? overline;
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Drawn to the LEFT of the overline, title and subtitle, vertically centred
  /// against them. The dashboard puts the ThinkTac mark here.
  ///
  /// A slot rather than a `showLogo` flag: this header is also used by the
  /// classroom and programme screens, which want a back arrow in that corner
  /// and no logo, and a boolean would have to grow a second one the first time
  /// anything else needed the space.
  final Widget? leading;

  final List<Widget> children;

  const TcHeroHeader({
    super.key,
    required this.title,
    this.breadcrumb,
    this.onBreadcrumbTap,
    this.overline,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.leading,
    this.trailing,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (breadcrumb != null || showBack)
                Row(
                  children: [
                    if (showBack)
                      InkWell(
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(24.r),
                        // 48-wide touch target kept fixed (tactile minimum).
                        child: SizedBox(
                          width: 48,
                          height: 40,
                          child: Icon(Icons.arrow_back_rounded,
                              color: AppColors.white, size: 22.r),
                        ),
                      ),
                    if (breadcrumb != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: onBreadcrumbTap,
                          child: Text(
                            breadcrumb!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                    ?trailing,
                  ],
                ),
              // The leading slot and the text block are laid out as one row, so
              // the mark stays optically centred against the title however many
              // lines the title wraps to.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: 12.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (overline != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            overline!.toUpperCase(),
                            style: AppTypography.label.copyWith(
                              color: AppColors.white.withValues(alpha: 0.65),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                        SizedBox(height: 4.h),
                        Text(
                          title,
                          style: AppTypography.heading1.copyWith(
                            color: AppColors.white,
                            fontSize: 24.sp,
                          ),
                        ),
                        // INSIDE this column, with the overline and the title,
                        // so all three share one left edge. Below the row it
                        // aligned to the container instead, which put the
                        // institution under the logo while the name sat
                        // indented past it.
                        if (subtitle != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            subtitle!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null && breadcrumb == null && !showBack)
                    trailing!,
                ],
              ),
              if (children.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Row(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(width: 12.w),
                      Expanded(child: children[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The white content sheet that rises into a [TcHeroHeader] with the
/// mockup's 20px rounded top edge.
class TcHeroSheet extends StatelessWidget {
  final Widget child;

  /// Optional padding override. When null, a responsive default of
  /// LTRB(16, 20, 16, 16) (scaled) is used. Kept nullable because `.w`/`.h`
  /// cannot be evaluated in a `const` default parameter value.
  final EdgeInsetsGeometry? padding;

  const TcHeroSheet({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
        child: child,
      ),
    );
  }
}
