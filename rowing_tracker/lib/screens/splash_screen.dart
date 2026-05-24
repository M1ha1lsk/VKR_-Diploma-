import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    required this.themeVariant,
  });

  final AppThemeVariant themeVariant;

  String get _imagePath {
    switch (themeVariant) {
      case AppThemeVariant.light:
        return 'assets/images/splash_logo_light.png';
      case AppThemeVariant.dark:
        return 'assets/images/splash_logo_dark.png';
    }
  }

  Color get _backgroundColor {
    switch (themeVariant) {
      case AppThemeVariant.light:
        return Colors.white;
      case AppThemeVariant.dark:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Image.asset(
          _imagePath,
          width: 320,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}