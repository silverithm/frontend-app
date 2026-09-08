import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/text_scale.dart';

class AppProvider with ChangeNotifier {
  static const String _textSizeKey = 'app_text_size';

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isDarkMode = false;
  AppTextSize _textSize = AppTextSize.normal;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isDarkMode => _isDarkMode;

  /// 사용자가 앱에서 고른 글자 크기. 기기 설정과 함께 최종 배율을 정한다(text_scale.dart).
  AppTextSize get textSize => _textSize;

  AppProvider() {
    _loadThemeMode();
    _loadTextSize();
  }

  void _loadTextSize() {
    _textSize = AppTextSize.fromName(StorageService().getString(_textSizeKey));
  }

  Future<void> setTextSize(AppTextSize size) async {
    if (_textSize == size) return;
    _textSize = size;
    notifyListeners();
    await StorageService().saveString(_textSizeKey, size.name);
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
