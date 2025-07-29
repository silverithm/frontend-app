import 'dart:convert';
import 'dart:typed_data';

class JwtUtils {
  /// JWT 토큰을 디코딩하여 payload 반환
  static Map<String, dynamic>? decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('[JWT] 잘못된 JWT 토큰 형식');
        return null;
      }

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      print('[JWT] 디코딩된 payload: $payloadMap');
      return payloadMap;
    } catch (e) {
      print('[JWT] 토큰 디코딩 실패: $e');
      return null;
    }
  }

  /// JWT 토큰에서 역할 정보 추출
  static String? getRoleFromToken(String token) {
    final payload = decodeJwt(token);
    if (payload == null) return null;

    // 'auth' 필드에서 역할 정보 추출 (예: "ROLE_ADMIN")
    final auth = payload['auth'] as String?;
    if (auth != null) {
      print('[JWT] 토큰에서 추출한 역할: $auth');
      return auth;
    }

    // 'role' 필드에서 역할 정보 추출
    final role = payload['role'] as String?;
    if (role != null) {
      print('[JWT] 토큰에서 추출한 역할: $role');
      return role;
    }

    print('[JWT] 토큰에서 역할 정보를 찾을 수 없음');
    return null;
  }

  /// 역할 문자열을 정규화 (ROLE_ADMIN -> ADMIN)
  static String normalizeRole(String role) {
    if (role.startsWith('ROLE_')) {
      return role.substring(5); // 'ROLE_' 제거
    }
    return role.toUpperCase();
  }
}