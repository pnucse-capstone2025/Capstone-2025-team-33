import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    appBarTheme: AppBarTheme(
      color: AppColors.white,
      iconTheme: IconThemeData(color: AppColors.primary),
      elevation: 1,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: TextTheme(
      // headline1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      // subtitle1: TextStyle(fontSize: 16, color: AppColors.textSecondary),
      // bodyText2: TextStyle(fontSize: 14, color: AppColors.textPrimary),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: const Color.fromARGB(255, 191, 99, 78),
    ),
  );
}
