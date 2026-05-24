import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local/user_local_repository.dart';
import 'models/training_models.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RowingApp());
}

class RowingApp extends StatefulWidget {
  const RowingApp({super.key});

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  final UserLocalRepository _userRepo = UserLocalRepository();
  static const _themeKey = 'app_theme';
  static const _splitUnitKey = 'preferred_split_unit';
  static const _legacyGenderKey = 'selected_gender';
  static const _legacyMaxHrKey = 'max_hr';
  AppThemeVariant _theme = AppThemeVariant.light;
  SplitInputUnit _preferredSplitUnit = SplitInputUnit.split;
  String? _selectedGender;
  bool _hasPrediction = false;
  PredictionResult? _lastPrediction;
  int? _maxHr;
  bool _showSplash = true;
  bool _settingsReady = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadUiBootstrapCache();
    if (!mounted) return;
    setState(() => _settingsReady = true);
    await _loadSavedSettings();
    if (!mounted) return;
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showSplash = false);
    });
  }

  Future<void> _loadUiBootstrapCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      final savedSplit = prefs.getString(_splitUnitKey);
      if (!mounted) return;
      setState(() {
        _theme = savedTheme == 'dark' ? AppThemeVariant.dark : AppThemeVariant.light;
        _preferredSplitUnit =
            savedSplit == 'watts' ? SplitInputUnit.watts : SplitInputUnit.split;
      });
    } catch (_) {}
  }

  Future<void> _loadSavedSettings() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    final legacyTheme = prefs?.getString(_themeKey);
    final legacySplit = prefs?.getString(_splitUnitKey);
    final legacyGender = prefs?.getString(_legacyGenderKey);
    final legacyMaxHr = prefs?.getInt(_legacyMaxHrKey);
    final user = await _userRepo.getCurrentUser();
    var themeRaw = user.theme;
    var splitRaw = user.splitUnit;
    var gender = user.gender;
    var maxHr = user.maxHr;
    if (themeRaw == null && legacyTheme != null) {
      await _userRepo.updateTheme(legacyTheme);
      themeRaw = legacyTheme;
    }
    if (splitRaw == null && legacySplit != null) {
      await _userRepo.updateSplitUnit(legacySplit);
      splitRaw = legacySplit;
    }
    if (gender == null && legacyGender != null) {
      await _userRepo.updateGender(legacyGender);
      gender = legacyGender;
      await prefs?.remove(_legacyGenderKey);
    }
    if (maxHr == null && legacyMaxHr != null) {
      await _userRepo.updateMaxHr(legacyMaxHr);
      maxHr = legacyMaxHr;
      await prefs?.remove(_legacyMaxHrKey);
    }
    final theme = themeRaw == 'dark' ? AppThemeVariant.dark : AppThemeVariant.light;
    final split = splitRaw == 'watts' ? SplitInputUnit.watts : SplitInputUnit.split;
    if (themeRaw != null) {
      await prefs?.setString(_themeKey, themeRaw);
    }
    if (splitRaw != null) {
      await prefs?.setString(_splitUnitKey, splitRaw);
    }

    final restoredPrediction = user.lastPrediction2k == null
        ? null
        : PredictionResult(
            createdAt: user.lastPrediction2kDate ?? DateTime.now(),
            predicted2kSeconds: user.lastPrediction2k!,
            gender: gender ?? 'male',
          );

    if (!mounted) return;
    setState(() {
      _theme = theme;
      _preferredSplitUnit = split;
      _selectedGender = gender;
      _hasPrediction = restoredPrediction != null;
      _lastPrediction = restoredPrediction;
      _maxHr = maxHr;
    });
  }

  Future<void> _onThemeChanged(AppThemeVariant value) async {
    setState(() => _theme = value);
    await _userRepo.updateTheme(value == AppThemeVariant.dark ? 'dark' : 'light');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, value == AppThemeVariant.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> _onPreferredSplitUnitChanged(SplitInputUnit value) async {
    setState(() => _preferredSplitUnit = value);
    await _userRepo.updateSplitUnit(value == SplitInputUnit.watts ? 'watts' : 'split');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_splitUnitKey, value == SplitInputUnit.watts ? 'watts' : 'split');
    } catch (_) {}
  }

  Future<void> _onGenderChanged(String value) async {
    setState(() => _selectedGender = value);
    await _userRepo.updateGender(value);
  }

  Future<void> _onPredictionCreated(PredictionResult result) async {
    setState(() {
      _lastPrediction = result;
      _hasPrediction = true;
    });
    await _userRepo.updateLastPrediction(
      seconds: result.predicted2kSeconds,
      date: result.createdAt,
    );
  }

  Future<void> _onMaxHrChanged(int? value) async {
    setState(() => _maxHr = value);
    await _userRepo.updateMaxHr(value);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsReady) {
      return const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      );
    }
    return MaterialApp(
      title: 'Rowing Tracker',
      theme: AppThemes.toThemeData(_theme),
      home: _showSplash
          ? SplashScreen(themeVariant: _theme)
          : HomeScreen(
              currentTheme: _theme,
              onThemeChanged: _onThemeChanged,
              preferredSplitUnit: _preferredSplitUnit,
              onPreferredSplitUnitChanged: (value) {
                _onPreferredSplitUnitChanged(value);
              },
              selectedGender: _selectedGender,
              onGenderChanged: (value) {
                _onGenderChanged(value);
              },
              hasPrediction: _hasPrediction,
              lastPrediction: _lastPrediction,
              onPredictionCreated: (result) {
                _onPredictionCreated(result);
              },
              maxHr: _maxHr,
              onMaxHrChanged: (value) {
                _onMaxHrChanged(value);
              },
            ),
    );
  }
}