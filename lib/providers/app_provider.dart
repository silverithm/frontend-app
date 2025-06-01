import 'package:flutter/material.dart';

class AppProvider with ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isDarkMode = false;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isDarkMode => _isDarkMode;

  AppProvider() {
    _loadThemeMode();
  }

  void _loadThemeMode() {
    // TODO: SharedPreferences에서 테마 설정 로드
    // 현재는 기본값 사용
    _isDarkMode = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeMode();
    notifyListeners();
  }

  void _saveThemeMode() {
    // TODO: SharedPreferences에 테마 설정 저장
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}
