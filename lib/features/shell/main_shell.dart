import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Bottom-nav shell for the tabbed section of the app.
///
/// The selected index is derived from the CURRENT ROUTE, not held in state.
/// That matters: a deep link or a back gesture changes the route without going
/// through the tap handler, and index-in-state would then disagree with what is
/// on screen.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_Tab>[
    _Tab('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    _Tab('/classrooms', Icons.class_outlined, Icons.class_, 'Classrooms'),
    _Tab('/profile', Icons.person_outline, Icons.person, 'Profile'),
  ];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // startsWith, not ==, so /classrooms/abc still lights up the Classrooms tab.
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final current = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: SizedBox(
        height: AppDimensions.bottomNavHeight,
        child: BottomNavigationBar(
          currentIndex: current,
          onTap: (i) {
            // `go`, not `push`: tapping a tab replaces the branch rather than
            // stacking another copy of it behind the current screen.
            if (i != current) context.go(_tabs[i].path);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.skyBlue,
          unselectedItemColor: AppColors.textTertiary,
          selectedFontSize: 12.sp,
          unselectedFontSize: 12.sp,
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(
                icon: Icon(t.icon),
                activeIcon: Icon(t.activeIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
