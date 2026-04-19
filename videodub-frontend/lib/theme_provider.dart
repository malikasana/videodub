import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const darkBg = Color(0xFF0D0D1A);
  static const darkSurface = Color(0xFF12121F);
  static const darkCard = Color(0xFF1A1A2E);
  static const darkBorder = Color(0xFF2A2A3E);
  static const darkText = Color(0xFFE8E8FF);
  static const darkTextMuted = Color(0xFF6B6B9A);
  static const darkTextHint = Color(0xFF4A4A6A);
  static const darkTextFaint = Color(0xFF3A3A5C);

  static const lightBg = Color(0xFFF7F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF0F0F8);
  static const lightBorder = Color(0xFFE0E0EC);
  static const lightText = Color(0xFF1A1A2E);
  static const lightTextMuted = Color(0xFF6B6B9A);
  static const lightTextHint = Color(0xFFAAAAAA);
  static const lightTextFaint = Color(0xFFCCCCCC);

  static const purple = Color(0xFF7F77DD);
  static const purpleLight = Color(0xFFAFA9EC);
  static const purpleDark = Color(0xFF534AB7);
  static const teal = Color(0xFF5DCAA5);
  static const danger = Color(0xFFE24B4A);
  static const warning = Color(0xFFEF9F27);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purple,
        surface: AppColors.darkSurface,
        background: AppColors.darkBg,
      ),
    );
  }

  static ThemeData light() {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.purple,
        surface: AppColors.lightSurface,
        background: AppColors.lightBg,
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  // Load persisted theme on startup
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Color get bg => _isDarkMode ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => _isDarkMode ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => _isDarkMode ? AppColors.darkCard : AppColors.lightCard;
  Color get border => _isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
  Color get text => _isDarkMode ? AppColors.darkText : AppColors.lightText;
  Color get textMuted => _isDarkMode ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  Color get textHint => _isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint;
  Color get textFaint => _isDarkMode ? AppColors.darkTextFaint : AppColors.lightTextFaint;
}

class ThemeScope extends InheritedNotifier<ThemeProvider> {
  const ThemeScope({
    super.key,
    required ThemeProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static ThemeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}