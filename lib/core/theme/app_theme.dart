import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimary,
        brightness: Brightness.light,
        primary: AppColors.brandPrimary,
        secondary: AppColors.brandSecondary,
        surface: AppColors.lightSurface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.lightBg,
      fontFamily: 'Roboto',
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme, AppColors.lightTextPrimary,
          AppColors.lightTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: AppColors.lightBorder,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.brandPrimary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.brandPrimary : AppColors.lightTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandPrimary : AppColors.lightTextSecondary,
          );
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: const Duration(milliseconds: 160),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          animationDuration: const Duration(milliseconds: 160),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: Colors.white.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimaryDark,
        brightness: Brightness.dark,
        primary: AppColors.brandPrimaryDark,
        secondary: AppColors.brandSecondary,
        surface: AppColors.darkSurface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      fontFamily: 'Roboto',
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme, AppColors.darkTextPrimary,
          AppColors.darkTextSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: AppColors.darkBorder,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.brandPrimaryDark.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.brandPrimaryDark : AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandPrimaryDark : AppColors.darkTextSecondary,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimaryDark,
          foregroundColor: Colors.black,
          elevation: 0,
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: Colors.white.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceAlt,
        contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color primary, Color secondary) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(color: primary, fontWeight: FontWeight.w800),
      headlineMedium: base.headlineMedium?.copyWith(color: primary, fontWeight: FontWeight.w800),
      headlineSmall: base.headlineSmall?.copyWith(color: primary, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(color: primary, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(color: primary, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(color: primary, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: primary),
      bodyMedium: base.bodyMedium?.copyWith(color: secondary),
      bodySmall: base.bodySmall?.copyWith(color: secondary),
      labelLarge: base.labelLarge?.copyWith(color: primary, fontWeight: FontWeight.w600),
    );
  }
}
