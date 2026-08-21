import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';
// ignore_for_file: deprecated_member_use

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    // App-wide default body font so plain Text() that doesn't go through
    // AppTypography still renders the brand body face (Noto Sans, bundled under
    // assets/fonts). Headings/labels/buttons set Montserrat explicitly via
    // AppTypography or the component textStyles below.
    fontFamily: 'Noto Sans',
    colorScheme: ColorScheme.light(
      primary: AppColors.skyBlue,
      secondary: AppColors.navy,
      surface: AppColors.white,
      error: AppColors.errorRed,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.lightGrey,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.appBarTitle,
      toolbarHeight: AppDimensions.appBarHeight,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: AppDimensions.elevationCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: AppColors.white,
        minimumSize: Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        textStyle: AppTypography.buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.skyBlue,
        minimumSize: Size(double.infinity, AppDimensions.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        side: BorderSide(color: AppColors.skyBlue, width: 1.5),
        textStyle: AppTypography.buttonText.copyWith(color: AppColors.skyBlue),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: EdgeInsets.symmetric(
        vertical: 14.h, horizontal: 12.w,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
        borderSide: BorderSide(color: AppColors.borderInput, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
        borderSide: BorderSide(color: AppColors.borderInput, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
        borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
      ),
      hintStyle: AppTypography.inputText.copyWith(color: AppColors.textDisabled),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.skyBlue,
      unselectedItemColor: AppColors.textDisabled,
      type: BottomNavigationBarType.fixed,
      elevation: AppDimensions.elevationBottomNav,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      elevation: AppDimensions.elevationBottomNav,
      indicatorColor: AppColors.skyBlue.withOpacity(0.15),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return IconThemeData(color: AppColors.skyBlue, size: 24.r);
        }
        return IconThemeData(color: AppColors.textDisabled, size: 24.r);
      }),
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return AppTypography.caption.copyWith(
            color: AppColors.skyBlue,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.caption.copyWith(color: AppColors.textDisabled);
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
    ),
    dividerColor: AppColors.borderLight,
  );
}
