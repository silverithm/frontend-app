import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';
import '../utils/constants.dart';

class AppVersionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isVersionChecked = false;
  bool _needsUpdate = false;
  bool _forceUpdate = false;
  String _updateMessage = '';
  String _latestVersion = '';
  String _currentVersion = '';

  bool get isVersionChecked => _isVersionChecked;

  bool get needsUpdate => _needsUpdate;

  bool get forceUpdate => _forceUpdate;

  String get updateMessage => _updateMessage;

  String get latestVersion => _latestVersion;

  String get currentVersion => _currentVersion;

  Future<void> checkAppVersion() async {
    try {
      print('[AppVersionProvider] === 앱 버전 체크 시작 ===');
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      print('[AppVersionProvider] 현재 앱 버전: $_currentVersion');

      print('[AppVersionProvider] API 호출 시작: /v1/app-version');
      final data = await _apiService.get('/v1/app-version');
      print('[AppVersionProvider] API 응답 수신: $data');

      String platformVersion = '';
      String minimumVersion = '';

      if (Platform.isIOS) {
        platformVersion = data['iosVersion'] ?? '';
        minimumVersion = data['iosMinimumVersion'] ?? '';
      } else if (Platform.isAndroid) {
        platformVersion = data['androidVersion'] ?? '';
        minimumVersion = data['androidMinimumVersion'] ?? '';
      }

      _latestVersion = platformVersion;
      _updateMessage =
          data['updateMessage'] ??
          'A new version is available. Please update to continue.';
      _forceUpdate = data['forceUpdate'] ?? false;

      final currentVersionParts = _parseVersion(_currentVersion);
      final latestVersionParts = _parseVersion(platformVersion);
      final minimumVersionParts = _parseVersion(minimumVersion);

      // Only show update if current version is actually lower than latest version
      _needsUpdate =
          _isVersionLower(currentVersionParts, latestVersionParts) &&
          !_isVersionEqual(currentVersionParts, latestVersionParts);

      if (_forceUpdate && minimumVersion.isNotEmpty) {
        _forceUpdate =
            _isVersionLower(currentVersionParts, latestVersionParts) &&
            !_isVersionEqual(currentVersionParts, latestVersionParts);
        ;
      }

      print('[AppVersionProvider] 버전 체크 완료 - needsUpdate: $_needsUpdate, forceUpdate: $_forceUpdate');
      _isVersionChecked = true;
      notifyListeners();
      print('[AppVersionProvider] === 앱 버전 체크 성공 완료 ===');
    } catch (e) {
      print('[AppVersionProvider] 앱 버전 체크 실패: $e');
      print('[AppVersionProvider] 실패해도 계속 진행...');
      _isVersionChecked = true;
      notifyListeners();
      print('[AppVersionProvider] === 앱 버전 체크 실패 완료 ===');
    }
  }

  List<int> _parseVersion(String version) {
    try {
      return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    } catch (e) {
      return [0, 0, 0];
    }
  }

  bool _isVersionLower(List<int> current, List<int> compare) {
    for (int i = 0; i < compare.length; i++) {
      if (i >= current.length) return true;
      if (current[i] < compare[i]) return true;
      if (current[i] > compare[i]) return false;
    }
    return false;
  }

  bool _isVersionEqual(List<int> current, List<int> compare) {
    int maxLength = current.length > compare.length
        ? current.length
        : compare.length;
    for (int i = 0; i < maxLength; i++) {
      int currentPart = i < current.length ? current[i] : 0;
      int comparePart = i < compare.length ? compare[i] : 0;
      if (currentPart != comparePart) return false;
    }
    return true;
  }

  void reset() {
    _isVersionChecked = false;
    _needsUpdate = false;
    _forceUpdate = false;
    _updateMessage = '';
    _latestVersion = '';
    _currentVersion = '';
    notifyListeners();
  }
}
