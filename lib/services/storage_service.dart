import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<void> saveBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<void> saveInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  // 토큰 관련 편의 메서드
  Future<void> saveToken(String token) async {
    await saveString(Constants.tokenKey, token);
  }

  String? getToken() {
    return getString(Constants.tokenKey);
  }

  Future<void> removeToken() async {
    await remove(Constants.tokenKey);
  }

  // refresh token 관련 메서드
  Future<void> saveRefreshToken(String refreshToken) async {
    await saveString('refresh_token', refreshToken);
  }

  String? getRefreshToken() {
    return getString('refresh_token');
  }

  Future<void> removeRefreshToken() async {
    await remove('refresh_token');
  }

  Future<void> removeAllTokens() async {
    await removeToken();
    await removeRefreshToken();
  }

  // 사용자 정보 저장/복원 메서드
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final userDataJson = jsonEncode(userData);
    await saveString('user_data', userDataJson);
  }

  Map<String, dynamic>? getSavedUserData() {
    final userDataJson = getString('user_data');
    if (userDataJson != null) {
      try {
        return jsonDecode(userDataJson) as Map<String, dynamic>;
      } catch (e) {
        print('[StorageService] 사용자 정보 파싱 오류: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> removeUserData() async {
    await remove('user_data');
  }

  Future<void> removeAll() async {
    await removeAllTokens();
    await removeUserData();
    // 이메일 기억하기는 보존
  }

  // 이메일 기억하기 관련 메서드 (로그아웃 시에도 보존)
  Future<void> saveRememberedEmail(String email) async {
    await saveString('remembered_email', email);
  }

  String? getRememberedEmail() {
    return getString('remembered_email');
  }

  Future<void> saveRememberEmailEnabled(bool enabled) async {
    await saveBool('remember_email_enabled', enabled);
  }

  bool getRememberEmailEnabled() {
    return getBool('remember_email_enabled') ?? false;
  }

  Future<void> clearRememberedEmail() async {
    await remove('remembered_email');
    await remove('remember_email_enabled');
  }
}
