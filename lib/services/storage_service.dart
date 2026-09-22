import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // 로그인 정보(토큰·사용자 정보)를 iOS Keychain에도 함께 적어 두는 용도.
  //
  // SharedPreferences는 앱을 삭제하면 함께 지워지지만, iOS Keychain은 기기에
  // 남아 있다가 같은 앱을 다시 설치하면 그대로 보인다 — "앱을 새로 깔면 자동
  // 로그인이 풀린다"(2026-09) 문제의 iOS쪽 대응이다.
  //
  // Android는 대응 대상이 아니다: Android Keystore로 암호화된 값도 결국 앱
  // 데이터 영역(`/data/data/<pkg>`)에 저장되므로 앱을 삭제하면 똑같이 지워진다
  // (Auto Backup을 켜서 클라우드에 올리는 방법이 있지만, 이 프로젝트는 비밀값을
  // 백업에 올리지 않는다 — 별도 결정 없이는 켜지 않는다).
  static const _secureStorage = FlutterSecureStorage();

  /// Keychain에 함께 적어 둘 로그인 관련 키만 골라 둔다 — 그 밖의 값(최근 앨범,
  /// 이메일 기억하기 등)은 재설치 후 되살릴 필요가 없다.
  static const Set<String> _keychainMirroredKeys = {
    Constants.tokenKey,
    'refresh_token',
    'user_data',
  };

  bool get _mirrorsToKeychain => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await restoreFromKeychainIfNeeded();
  }

  /// 이번 설치에서 아직 로그인 정보가 없는데(=SharedPreferences가 비어 있음)
  /// Keychain에는 지난 설치의 값이 남아 있으면 그걸로 채운다.
  ///
  /// **여기서는 "값이 있는지"만 옮기고, "그 값이 여전히 유효한지"는 절대
  /// 판단하지 않는다.** 유효성 검증·만료 시 갱신·완전히 죽었을 때 로그인
  /// 화면으로 보내는 판단은 전부 기존 AuthProvider.checkAuthStatus가 서버에
  /// 물어보고 처리한다 — 여기서 잘못 판단해 깨진 세션을 억지로 밀어넣는 일이
  /// 없도록, 이 메서드는 "복사"만 한다.
  Future<void> restoreFromKeychainIfNeeded() async {
    if (!_mirrorsToKeychain) return;
    if (getString(Constants.tokenKey) != null) {
      // 이번 설치에 이미 값이 있다 — 방금 로그인했거나 삭제 없이 이어 쓰는 중.
      return;
    }

    try {
      final entries = await Future.wait(
        _keychainMirroredKeys.map((key) async {
          final value = await _secureStorage.read(key: key);
          return MapEntry(key, value);
        }),
      );
      final hasAny = entries.any((e) => e.value != null);
      if (!hasAny) return; // Keychain도 비어 있다 — 정말 처음 설치한 것

      for (final entry in entries) {
        if (entry.value != null) {
          await _prefs?.setString(entry.key, entry.value!);
        }
      }
      print('[StorageService] Keychain에서 로그인 정보 복원(재설치 감지)');
    } catch (e) {
      print('[StorageService] Keychain 복원 실패(무시하고 새로 로그인 진행): $e');
    }
  }

  Future<void> _mirrorWrite(String key, String? value) async {
    if (!_mirrorsToKeychain || !_keychainMirroredKeys.contains(key)) return;
    try {
      if (value == null) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e) {
      // Keychain 기록 실패는 로그인 자체를 막지 않는다 — SharedPreferences 쪽은
      // 이미 정상 기록됐으므로 이번 세션은 평소대로 동작한다.
      print('[StorageService] Keychain 기록 실패($key): $e');
    }
  }

  Future<void> saveString(String key, String value) async {
    await _prefs?.setString(key, value);
    await _mirrorWrite(key, value);
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
    await _mirrorWrite(key, null);
  }

  Future<void> clear() async {
    await _prefs?.clear();
    if (_mirrorsToKeychain) {
      for (final key in _keychainMirroredKeys) {
        await _mirrorWrite(key, null);
      }
    }
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

  /// 명시적 로그아웃 포함 — Keychain 사본도 함께 지운다. 안 지우면 로그아웃한
  /// 사람이 앱을 지웠다 다시 깔았을 때 지운 계정으로 자동로그인되어 버린다.
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
