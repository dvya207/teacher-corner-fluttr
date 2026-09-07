import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// Shared AppBar with a persistent ThinkTac brand mark in the leading slot.
///
/// Telco-style brand persistence (Sriram audit, 2026-04-29). The mark must
/// appear on every authenticated screen, not just splash/login/dashboard.
/// See `DESIGN.md` §6.
///
/// Layout:
///
///     [← back?]  [logo 22dp]  Title (centered)         [trailing?]
///
/// Variants:
///
///   * `TcAppBar(title:)` — root-tab AppBar, no back arrow.
///   * `TcAppBar(title:, showBack: true)` — pushed-screen AppBar.
///   * `TcAppBar(title: null)` — compact; logo + trailing only.
///   * `TcAppBar(title:, subtitle:)` — two lines, and TALLER. The bar grows to
///     76 rather than squeezing two lines into 56, and the title stops being
///     centred: a centred title above a centred subtitle reads as one
///     off-balance block once the title ellipsizes, which it does at this
///     width. Used by the learning unit screen for its progress readout.
class TcAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  /// A second, smaller line under [title]. Ignored when [titleWidget] is given,
  /// which owns its own layout.
  final String? subtitle;
  final Widget? titleWidget;
  final bool showBack;
  final Widget? trailing;
  final List<Widget>? actions;
  final Color backgroundColor;
  final bool centerTitle;

  const TcAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.showBack = false,
    this.trailing,
    this.actions,
    this.backgroundColor = AppColors.navy,
    this.centerTitle = true,
  });

  /// Whether the two-line variant is in play, which decides the height.
  bool get _hasSubtitle =>
      titleWidget == null &&
      title != null &&
      subtitle != null &&
      subtitle!.trim().isNotEmpty;

  @override
  Size get preferredSize => Size.fromHeight(_hasSubtitle ? 76 : 56);

  @override
  Widget build(BuildContext context) {
    final whiteOnNavy = backgroundColor == AppColors.navy;
    final logoAsset = whiteOnNavy
        ? 'assets/images/thinktacLogo_white.svg'
        : 'assets/images/thinktacLogo_color.svg';
    final fg = whiteOnNavy ? AppColors.white : AppColors.navy;

    final trailingChildren = <Widget>[];
    if (trailing != null) trailingChildren.add(trailing!);
    if (actions != null) trailingChildren.addAll(actions!);

    return Material(
      color: backgroundColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        // App bar height is platform chrome (matches AppDimensions.appBarHeight
        // / kToolbarHeight and preferredSize); NOT scaled.
        child: SizedBox(
          height: _hasSubtitle ? 76 : 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: [
                if (showBack)
                  _BarIcon(
                      icon: Icons.arrow_back,
                      color: fg,
                      onTap: () => Navigator.of(context).maybePop()),
                if (showBack) SizedBox(width: 4.w),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: SvgPicture.asset(
                    logoAsset,
                    width: 22.r,
                    height: 22.r,
                    fit: BoxFit.contain,
                  ),
                ),
                if (titleWidget != null) ...[
                  SizedBox(width: 8.w),
                  Expanded(child: titleWidget!),
                ] else if (title != null) ...[
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: _hasSubtitle
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title!,
                          textAlign: _hasSubtitle
                              ? TextAlign.start
                              : (centerTitle
                                    ? TextAlign.center
                                    : TextAlign.start),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _hasSubtitle ? 18.sp : 16.sp,
                            fontWeight: FontWeight.w600,
                            color: fg,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (_hasSubtitle) ...[
                          SizedBox(height: 2.h),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: fg.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
                if (trailingChildren.isNotEmpty)
                  ...trailingChildren
                else if (centerTitle && title != null && !_hasSubtitle)
                  // symmetric spacer so centered title is actually centered
                  SizedBox(width: 22.r + 8.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BarIcon(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 48x48 is the minimum tactile touch target; kept fixed (not scaled
      // below 48dp). Only the glyph inside scales.
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: color, size: 22.r),
      ),
    );
  }
}
