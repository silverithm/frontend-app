import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';
import '../models/fcm_token_update_dto.dart';
import '../screens/my_vacation_screen.dart';
import '../screens/approval_hub_screen.dart';
import '../screens/notice_detail_screen.dart';
import '../screens/chat_room_list_screen.dart';
import '../screens/calendar_screen.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;

  // 토큰 재갱신 시 서버 전송을 위한 사용자 정보 저장
  String? _currentUserId;
  bool _isAdmin = false;

  BuildContext? _globalContext;

  /// 콜드 스타트 시 컨텍스트 준비 전에 도착한 알림 탭 데이터 (컨텍스트 설정 후 처리)
  Map<String, dynamic>? _pendingNavigationData;
  void Function(RemoteMessage)? onForegroundMessage;

  void setGlobalContext(BuildContext context) {
    _globalContext = context;

    // 앱 종료 상태에서 알림 탭으로 시작한 경우 — 컨텍스트가 없어 보류했던 이동을 지금 실행
    final pending = _pendingNavigationData;
    if (pending != null) {
      _pendingNavigationData = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateByType(pending));
    }
  }

  /// FCM 서비스 초기화
  Future<void> initialize() async {
    try {
      // 로컬 알림 설정 (권한 요청보다 먼저)
      await _initializeLocalNotifications();

      // 알림 권한 요청
      await _requestPermissions();

      // iOS 포그라운드 알림 표시 옵션 설정
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        log('[FCM] iOS 포그라운드 알림 표시 옵션 설정 완료');

        // iOS에서 APNS 토큰 수동 설정
        await _setAPNSToken();
      }

      // FCM 토큰 획득 (서버 전송은 로그인 후 실행)
      await _getTokenOnly();

      // 토큰 갱신 리스너 설정
      _setupTokenRefreshListener();

      // 메시지 리스너 설정
      _setupMessageListeners();

      log('[FCM] FCM 서비스 초기화 완료');
    } catch (e) {
      log('[FCM] FCM 서비스 초기화 실패: $e');
    }
  }
  
  /// 알림 권한 요청
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      announcement: false,
    );
    
    log('[FCM] 알림 권한 상태: ${settings.authorizationStatus}');
  }
  
  /// iOS에서 APNS 토큰 수동 설정
  Future<void> _setAPNSToken() async {
    try {
      // Firebase Messaging v15+ 에서는 setAPNSToken이 제거됨
      // 대신 getAPNSToken()을 여러 번 호출하여 토큰 활성화
      for (int i = 0; i < 5; i++) {
        try {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            log('[FCM] APNS 토큰 확인됨 (시도 ${i + 1}): ${apnsToken.substring(0, 20)}...');
            return;
          }
        } catch (e) {
          log('[FCM] APNS 토큰 확인 시도 ${i + 1} 실패: $e');
        }
        
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      log('[FCM] APNS 토큰 설정 시간 초과');
    } catch (e) {
      log('[FCM] APNS 토큰 설정 실패: $e');
    }
  }
  
  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/carev_icon');
    
    const DarwinInitializationSettings initializationSettingsiOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsiOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // iOS 로컬 알림 권한 별도 요청
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _requestIOSLocalNotificationPermissions();
    }
    
    // Android 알림 채널 생성
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: '중요한 알림을 위한 채널',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// iOS 로컬 알림 권한 요청
  Future<void> _requestIOSLocalNotificationPermissions() async {
    final iosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final bool? result = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      log('[FCM] iOS 로컬 알림 권한 요청 결과: $result');
    }
  }
  
  /// FCM 토큰만 획득 (서버 전송 없이)
  Future<void> _getTokenOnly() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS는 APNs 디바이스 토큰이 먼저 도착해야 FCM 토큰이 발급된다.
        // 첫 설치 직후에는 권한 팝업 → APNs 등록까지 수십 초가 걸릴 수 있어,
        // 짧게 몇 번 찔러보고 포기하면 토큰이 영영 등록되지 않는다 (실제 발생한 버그).
        log('[FCM] iOS FCM 토큰 획득 — APNS 토큰 대기 시작');
        await _waitForAPNSToken();

        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _currentToken = token;
            log('[FCM] FCM 토큰 획득 성공: ${token.substring(0, 20)}...');
            return;
          }
        } catch (e) {
          log('[FCM] FCM 토큰 획득 실패: $e');
        }

        // 아직 실패 — APNs 등록이 늦는 것뿐일 수 있으니 백그라운드에서 계속 재시도.
        // 성공하면 저장된 사용자 정보로 서버 업로드까지 이어진다.
        log('[FCM] FCM 토큰 미획득 — 백그라운드 재시도 예약');
        _scheduleTokenRetry();
        return;
      }

      // Android는 기존 로직
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        log('[FCM] FCM 토큰 획득: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      log('[FCM] FCM 토큰 획득 실패: $e');
    }
  }
  
  /// iOS 시뮬레이터 여부 확인
  bool _isIOSSimulator() {
    if (!kIsWeb && Platform.isIOS) {
      // iOS 시뮬레이터는 x86_64 또는 arm64 아키텍처를 사용
      // 하지만 더 정확한 방법은 없으므로 기본적으로 false 반환
      // 실제로는 네이티브 코드에서 확인해야 하지만, 
      // 여기서는 APNS 토큰 획득 실패로 판단
      return false;
    }
    return false;
  }
  
  /// FCM 토큰 획득 실패 시 백그라운드 재시도 (15초 간격, 최대 20회 = 5분).
  /// 성공하면 로그인돼 있는 경우 서버 업로드까지 수행한다.
  Timer? _tokenRetryTimer;
  int _tokenRetryCount = 0;

  void _scheduleTokenRetry() {
    _tokenRetryTimer?.cancel();
    _tokenRetryCount = 0;
    _tokenRetryTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      _tokenRetryCount++;
      if (_currentToken != null || _tokenRetryCount > 20) {
        timer.cancel();
        return;
      }
      try {
        final token = await _firebaseMessaging.getToken();
        if (token != null && token.isNotEmpty) {
          timer.cancel();
          _currentToken = token;
          log('[FCM] 재시도 ${_tokenRetryCount}회차에 FCM 토큰 획득: ${token.substring(0, 20)}...');
          if (_currentUserId != null && _currentUserId!.isNotEmpty) {
            if (_isAdmin) {
              await ApiService().updateAdminFcmToken(
                  userId: _currentUserId!, fcmToken: token);
            } else {
              await ApiService().updateFcmToken(
                  memberId: _currentUserId!, fcmToken: token);
            }
            log('[FCM] 재시도 획득 토큰 서버 전송 완료');
          }
        }
      } catch (e) {
        log('[FCM] 토큰 재시도 ${_tokenRetryCount}/20 실패: $e');
      }
    });
  }

  /// iOS에서 APNS 토큰이 설정될 때까지 대기 (최대 30초)
  Future<void> _waitForAPNSToken() async {
    const maxAttempts = 30;
    const delay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          log('[FCM] APNS 토큰 확인됨: ${apnsToken.substring(0, 20)}...');
          return;
        }
      } catch (e) {
        log('[FCM] APNS 토큰 확인 시도 ${attempt + 1}/$maxAttempts: $e');
      }
      
      if (attempt < maxAttempts - 1) {
        await Future.delayed(delay);
      }
    }
    
    log('[FCM] APNS 토큰 대기 시간 초과, FCM 토큰 획득을 계속 진행합니다.');
  }

  
  /// 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      log('[FCM] FCM 토큰 갱신됨: ${newToken.substring(0, 20)}...');
      _currentToken = newToken;

      // 로그인 상태인 경우 (사용자 ID가 저장되어 있는 경우) 서버로 재전송
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        log('[FCM] 토큰 갱신 - 서버로 재전송 시작 (userId: $_currentUserId, isAdmin: $_isAdmin)');
        try {
          if (_isAdmin) {
            await ApiService().updateAdminFcmToken(
              userId: _currentUserId!,
              fcmToken: newToken,
            );
          } else {
            await ApiService().updateFcmToken(
              memberId: _currentUserId!,
              fcmToken: newToken,
            );
          }
          log('[FCM] 토큰 갱신 후 서버 전송 완료');
        } catch (e) {
          log('[FCM] 토큰 갱신 후 서버 전송 실패: $e');
        }
      } else {
        log('[FCM] 토큰 갱신됨 - 로그인 상태 아님, 서버 전송 건너뜀');
      }
    });
  }
  
  /// 메시지 리스너 설정
  void _setupMessageListeners() {
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // 백그라운드 메시지 클릭 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // 앱이 종료된 상태에서 알림 클릭으로 앱이 시작된 경우
    _handleInitialMessage();
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    log('[FCM] 포그라운드 메시지 수신: ${message.notification?.title}');
    log('[FCM] 메시지 내용: ${message.notification?.body}');
    log('[FCM] 메시지 데이터: ${message.data}');

    // iOS는 setForegroundNotificationPresentationOptions(alert: true)로 시스템이
    // 원본 푸시를 이미 배너로 띄운다 — 여기서 로컬 알림까지 만들면 같은 알림이 2개 뜬다.
    // Android는 포그라운드 자동 표시가 없으므로 로컬 알림이 필요하다.
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      _showLocalNotification(message);
    }

    // 포그라운드 콜백 호출
    onForegroundMessage?.call(message);
  }
  
  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    log('[FCM] 로컬 알림 표시 시작');
    
    final notification = message.notification;
    if (notification != null) {
      log('[FCM] 알림 제목: ${notification.title}');
      log('[FCM] 알림 내용: ${notification.body}');
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: '중요한 알림을 위한 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/carev_icon',
        playSound: true,
        enableVibration: true,
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      );
      
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      try {
        // 고유한 ID 생성 (시간 기반)
        final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        await _localNotifications.show(
          notificationId,
          notification.title,
          notification.body,
          platformChannelSpecifics,
          payload: json.encode(message.data),
        );
        log('[FCM] 로컬 알림 표시 완료 (ID: $notificationId)');
      } catch (e) {
        log('[FCM] 로컬 알림 표시 실패: $e');
      }
    } else {
      log('[FCM] 알림 데이터가 없음');
    }
  }
  
  /// 백그라운드에서 알림 클릭 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    log('[FCM] 백그라운드 알림 클릭: ${message.notification?.title}');
    _handleNotificationNavigation(message);
  }
  
  /// 앱 종료 상태에서 알림 클릭으로 시작된 경우 처리
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      log('[FCM] 앱 시작 알림 클릭: ${initialMessage.notification?.title}');
      _handleNotificationNavigation(initialMessage);
    }
  }
  
  /// 로컬 알림 클릭 처리
  void _onNotificationTapped(NotificationResponse response) {
    log('[FCM] 로컬 알림 클릭: ${response.payload}');
    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = json.decode(response.payload!) as Map<String, dynamic>;
      _navigateByType(data);
    } catch (e) {
      log('[FCM] 알림 페이로드 파싱 실패: $e');
    }
  }

  /// 알림 클릭 시 네비게이션 처리
  void _handleNotificationNavigation(RemoteMessage message) {
    log('[FCM] 알림 네비게이션: ${message.data}');
    _navigateByType(message.data);
  }

  /// 타입별 화면 이동 (공통)
  void _navigateByType(Map<String, dynamic> data) {
    final context = _globalContext;
    if (context == null || !context.mounted) {
      // 콜드 스타트 직후 등 컨텍스트 준비 전 — setGlobalContext에서 재시도
      _pendingNavigationData = data;
      return;
    }

    final type = data['type']?.toString() ?? '';

    // 백엔드 타입: vacation_*, chat, schedule, notice, approval
    if (type.startsWith('vacation')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MyVacationScreen()),
      );
    } else if (type == 'approval') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ApprovalHubScreen(initialTab: 1)),
      );
    } else if (type == 'notice') {
      final noticeId = int.tryParse(data['noticeId']?.toString() ?? '');
      if (noticeId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoticeDetailScreen(noticeId: noticeId),
          ),
        );
      }
    } else if (type == 'chat') {
      // 백엔드가 roomId를 함께 보내므로 목록에서 멈추지 않고 그 대화까지 연다
      final roomId = int.tryParse(data['roomId']?.toString() ?? '');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomListScreen(initialRoomId: roomId),
        ),
      );
    } else if (type == 'schedule') {
      // 일정은 별도 상세 화면이 없어 그 날짜의 일정 달력을 펴 준다
      final date = DateTime.tryParse(data['scheduleDate']?.toString() ?? '');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CalendarScreen(initialScheduleDate: date),
        ),
      );
    }
  }
  
  /// 현재 FCM 토큰 반환
  String? get currentToken => _currentToken;
  
  /// 로그인 후 토큰 서버 전송 (직원용)
  Future<void> sendTokenToServer(String memberId) async {
    log('[FCM] sendTokenToServer 호출됨 (memberId: $memberId)');
    log('[FCM] 현재 토큰 상태: ${_currentToken != null ? '있음 (${_currentToken!.length}자)' : '없음'}');

    // 토큰 재갱신 시 사용할 사용자 정보 저장
    _currentUserId = memberId;
    _isAdmin = false;

    if (_currentToken != null && _currentToken!.isNotEmpty) {
      try {
        log('[FCM] 서버로 토큰 전송 시작...');
        await ApiService().updateFcmToken(
          memberId: memberId,
          fcmToken: _currentToken!,
        );
        log('[FCM] 로그인 후 토큰 전송 완료 (memberId: $memberId)');
      } catch (e) {
        log('[FCM] 로그인 후 토큰 전송 실패: $e');
      }
    } else {
      log('[FCM] FCM 토큰이 없어 서버 전송 불가');
      log('[FCM] 토큰 재획득 시도...');

      // 토큰이 없다면 다시 획득 시도
      await _getTokenOnly();

      if (_currentToken != null && _currentToken!.isNotEmpty) {
        try {
          log('[FCM] 재획득된 토큰으로 서버 전송 시작...');
          await ApiService().updateFcmToken(
            memberId: memberId,
            fcmToken: _currentToken!,
          );
          log('[FCM] 토큰 재획득 후 전송 완료 (memberId: $memberId)');
        } catch (e) {
          log('[FCM] 토큰 재획득 후 전송 실패: $e');
        }
      } else {
        log('[FCM] 토큰 재획득도 실패 - 서버 전송 불가');
      }
    }
  }

  /// 로그인 후 Admin 토큰 서버 전송 (관리자용)
  Future<void> sendAdminTokenToServer(String userId) async {
    log('[FCM] sendAdminTokenToServer 호출됨 (userId: $userId)');
    log('[FCM] 현재 토큰 상태: ${_currentToken != null ? '있음 (${_currentToken!.length}자)' : '없음'}');

    // 토큰 재갱신 시 사용할 사용자 정보 저장
    _currentUserId = userId;
    _isAdmin = true;

    if (_currentToken != null && _currentToken!.isNotEmpty) {
      try {
        log('[FCM] 서버로 토큰 전송 시작...');
        await ApiService().updateAdminFcmToken(
          userId: userId,
          fcmToken: _currentToken!,
        );
        log('[FCM] 로그인 후 토큰 전송 완료 (userId: $userId)');
      } catch (e) {
        log('[FCM] 로그인 후 토큰 전송 실패: $e');
      }
    } else {
      log('[FCM] FCM 토큰이 없어 서버 전송 불가');
      log('[FCM] 토큰 재획득 시도...');

      // 토큰이 없다면 다시 획득 시도
      await _getTokenOnly();

      if (_currentToken != null && _currentToken!.isNotEmpty) {
        try {
          log('[FCM] 재획득된 토큰으로 서버 전송 시작...');
          await ApiService().updateAdminFcmToken(
            userId: userId,
            fcmToken: _currentToken!,
          );
          log('[FCM] 토큰 재획득 후 전송 완료 (userId: $userId)');
        } catch (e) {
          log('[FCM] 토큰 재획득 후 전송 실패: $e');
        }
      } else {
        log('[FCM] 토큰 재획득도 실패 - 서버 전송 불가');
      }
    }
  }

  /// 로그아웃 시 사용자 정보 초기화
  void clearUserInfo() {
    log('[FCM] 사용자 정보 초기화');
    _currentUserId = null;
    _isAdmin = false;
  }

  /// 로그아웃 시 토큰 폐기: 서버에서 삭제 + 기기 토큰 재발급 무효화.
  /// 이후 다른 계정으로 로그인해도 이전 계정으로 알림이 가지 않는다.
  Future<void> revokeToken() async {
    final userId = _currentUserId;
    final isAdmin = _isAdmin;
    // 이 기기 토큰을 함께 보내야 서버가 이 기기만 해제한다.
    // 안 보내면 같은 계정으로 쓰던 다른 기기까지 알림이 멈춘다.
    final deviceToken = _currentToken;
    clearUserInfo();

    // 서버에서 토큰 제거 (실패해도 로그아웃 흐름은 계속)
    if (userId != null) {
      try {
        if (isAdmin) {
          await ApiService().deleteAdminFcmToken(
            userId: userId,
            fcmToken: deviceToken,
          );
        } else {
          await ApiService().deleteFcmToken(
            memberId: userId,
            fcmToken: deviceToken,
          );
        }
        log('[FCM] 서버 토큰 삭제 완료 (userId: $userId, admin: $isAdmin)');
      } catch (e) {
        log('[FCM] 서버 토큰 삭제 실패: $e');
      }
    }

    // 기기 토큰 무효화 — 다음 로그인 시 새 토큰 발급
    try {
      await _firebaseMessaging.deleteToken();
      _currentToken = null;
      log('[FCM] 기기 FCM 토큰 삭제 완료');
    } catch (e) {
      log('[FCM] 기기 FCM 토큰 삭제 실패: $e');
    }
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수로 정의)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('[FCM] 백그라운드 메시지 수신: ${message.notification?.title}');
  // 백그라운드에서 필요한 처리 로직
}