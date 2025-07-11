import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';
import '../models/fcm_token_update_dto.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _currentToken;
  
  /// FCM 서비스 초기화
  Future<void> initialize() async {
    try {
      // 로컬 알림 설정 (권한 요청보다 먼저)
      await _initializeLocalNotifications();
      
      // 알림 권한 요청
      await _requestPermissions();
      
      // iOS에서 APNS 토큰 수동 설정
      if (defaultTargetPlatform == TargetPlatform.iOS) {
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
      // iOS에서 APNS 토큰 없이 FCM 토큰 시도 (새로운 방식)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        log('[FCM] iOS에서 FCM 토큰 직접 획득 시도');
        
        // 방법 1: APNS 토큰 없이 직접 시도
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _currentToken = token;
            log('[FCM] FCM 토큰 획득 성공 (APNS 우회): ${token.substring(0, 20)}...');
            return;
          }
        } catch (directError) {
          log('[FCM] FCM 토큰 직접 획득 실패: $directError');
        }
        
        // 방법 2: 알림 권한 재요청 후 시도
        log('[FCM] 알림 권한 재요청 후 FCM 토큰 재시도');
        await _requestPermissions();
        await Future.delayed(Duration(seconds: 3));
        
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _currentToken = token;
            log('[FCM] FCM 토큰 재획득 성공: ${token.substring(0, 20)}...');
            return;
          }
        } catch (retryError) {
          log('[FCM] FCM 토큰 재획득 실패: $retryError');
        }
        
        // 방법 3: Firebase 다시 초기화 후 시도
        log('[FCM] Firebase 재초기화 후 FCM 토큰 시도');
        await Future.delayed(Duration(seconds: 2));
        
        try {
          final token = await _firebaseMessaging.getToken();
          if (token != null && token.isNotEmpty) {
            _currentToken = token;
            log('[FCM] FCM 토큰 최종 획득 성공: ${token.substring(0, 20)}...');
            return;
          }
        } catch (finalError) {
          log('[FCM] FCM 토큰 최종 획득 실패: $finalError');
        }
        
        log('[FCM] iOS에서 FCM 토큰 획득 실패 - 프로비저닝 프로파일과 인증서를 확인해주세요');
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
  
  /// iOS에서 APNS 토큰이 설정될 때까지 대기
  Future<void> _waitForAPNSToken() async {
    const maxAttempts = 10;
    const delay = Duration(milliseconds: 500);
    
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
  
  /// 서버에 FCM 토큰 전송
  Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: 실제 사용자 ID를 얻어와야 함
      // 현재는 임시로 '1'을 사용
      await ApiService().updateFcmToken(
        memberId: '1', // 실제 구현 시 로그인된 사용자 ID 사용
        fcmToken: token,
      );
      log('[FCM] 서버에 FCM 토큰 전송 완료');
    } catch (e) {
      log('[FCM] 서버에 FCM 토큰 전송 실패: $e');
    }
  }
  
  /// 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      log('[FCM] FCM 토큰 갱신: ${newToken.substring(0, 20)}...');
      _currentToken = newToken;
      // 토큰 갱신 시에도 로그인 상태인 경우에만 서버 전송
      // 이는 sendTokenToServer 메서드에서 처리
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
    
    // 포그라운드에서 로컬 알림 표시
    _showLocalNotification(message);
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
          payload: message.data.toString(),
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
    // TODO: 알림 클릭 시 적절한 화면 이동 로직 구현
  }
  
  /// 알림 클릭 시 네비게이션 처리
  void _handleNotificationNavigation(RemoteMessage message) {
    // TODO: 메시지 데이터에 따른 적절한 화면 이동 로직 구현
    final data = message.data;
    log('[FCM] 알림 데이터: $data');
    
    // 예시: 알림 타입에 따른 화면 이동
    switch (data['type']) {
      case 'vacation':
        // 휴가 관련 화면으로 이동
        break;
      case 'schedule':
        // 일정 관련 화면으로 이동
        break;
      default:
        // 기본 홈 화면으로 이동
        break;
    }
  }
  
  /// 현재 FCM 토큰 반환
  String? get currentToken => _currentToken;
  
  /// 로그인 후 토큰 서버 전송
  Future<void> sendTokenToServer(String memberId) async {
    log('[FCM] sendTokenToServer 호출됨 (memberId: $memberId)');
    log('[FCM] 현재 토큰 상태: ${_currentToken != null ? '있음 (${_currentToken!.length}자)' : '없음'}');
    
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
}

/// 백그라운드 메시지 핸들러 (최상위 함수로 정의)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('[FCM] 백그라운드 메시지 수신: ${message.notification?.title}');
  // 백그라운드에서 필요한 처리 로직
}