import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../services/api_service.dart';
import '../services/socket_reconnect.dart';
import '../services/chat_outbox.dart';
import '../services/storage_service.dart';
import '../utils/chat_date_jump.dart';
import '../utils/chat_message_pagination.dart';

class ChatProvider with ChangeNotifier {
  // State
  List<ChatRoom> _chatRooms = [];
  ChatRoom? _selectedRoom;
  List<ChatMessage> _messages = [];
  List<ChatParticipant> _participants = [];
  List<ChatMessageReader> _messageReaders = [];
  List<ChatMessage> _sharedMedia = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isConnected = false;
  Set<String> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};

  // Current user info for message handling
  String? _currentUserId;
  String? _companyId;

  // 접속 상태 — 지금 붙어 있는 사람들의 userId
  Set<String> _onlineUserIds = {};
  StompUnsubscribe? _presenceSubscription;

  // Pagination for messages
  // 옛 대화를 이어 붙이는 중인지 — 화면 전체 로딩(_isLoading)과 따로 둔다.
  // _isLoading은 방 목록 조회 등 다른 작업도 같이 쓰기 때문에, 그걸로 무한
  // 스크롤을 막으면 마침 방 목록이 갱신되는 순간의 스크롤이 통째로 무시된다
  // (= "위로 올려도 아무 일도 안 일어난다"의 한 원인).
  bool _isLoadingOlderMessages = false;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasMoreMessages = true;

  /// 화면이 지금 목록 맨 아래(최신) 근처를 보고 있는지 알려 주는 콜백. 채팅방 화면이 등록한다.
  /// 없으면 맨 아래를 보고 있다고 본다.
  bool Function()? viewerNearBottom;

  /// 끊겼다 붙은 사이 대화가 한 페이지 넘게 쌓였는데, 화면이 옛 대화를 읽는 중이라
  /// 목록을 갈아끼우지 않고 미뤄 둔 상태. 화면은 이걸 보고 "새 메시지 보기"를 띄운다.
  bool _hasNewerMessages = false;
  bool get hasNewerMessages => _hasNewerMessages;
  /// 한 번이라도 붙은 적이 있는가 — 첫 연결과 '다시 붙음'을 가른다.
  /// 다시 붙은 것일 때만 끊긴 사이에 놓친 메시지를 채운다.
  bool _hasConnectedBefore = false;

  /// 기기 네트워크가 끊겼다 돌아오는 걸 듣는다 — 비행기 모드를 풀었는데 다음 재시도
  /// (최대 60초)까지 그냥 기다리는 걸 막는다(socket_reconnect.dart의
  /// shouldReconnectOnConnectivityChange).
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ChatProvider() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object e) => print('[ChatProvider] 연결성 감시 에러: $e'),
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final shouldReconnect = shouldReconnectOnConnectivityChange(
      hasConnection: hasConnection,
      isSocketConnected: _isConnected && (_stompClient?.connected ?? false),
      intentionallyDisconnected: _intentionallyDisconnected,
      stoppedForAuth: _stoppedForAuth,
    );
    if (!shouldReconnect) return;
    print('[ChatProvider] 네트워크가 돌아왔다 — 대기를 걷어내고 바로 다시 붙는다');
    // 대기 타이머를 걷어내고 시도 횟수를 되돌린 뒤 바로 붙는 것까지 ensureConnected가
    // 이미 하는 일이다(앱 복귀 때와 같은 절차) — 토큰 유무·플래그 재확인도 겹쳐서 안전하다.
    ensureConnected();
  }

  // WebSocket
  StompClient? _stompClient;
  /// connectWebSocket이 호출될 때마다 하나씩 오른다 — 종료 콜백이 어느 연결의 것인지 가린다
  int _socketGeneration = 0;

  /// 다시 붙기 예약 — 간격을 점점 늘린다 (socket_reconnect.dart)
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// 인증 문제로 끊겼다 — 다음에 붙기 전에 토큰을 새로 받는다
  bool _needsFreshToken = false;

  /// 세션이 끝나 재연결을 멈춘 상태. 다시 로그인하거나 앱을 다시 열면 풀린다.
  bool _stoppedForAuth = false;

  /// 언제부터 끊겨 있는지 — 화면에 "얼마나 안 붙었는지" 보여주는 데 쓴다.
  /// 다시 붙으면 null로 돌아간다.
  DateTime? _disconnectedSince;

  /// 화면에서 일부러 끊은 것인지 (로그아웃·계정 전환) — 그때는 다시 붙지 않는다
  bool _intentionallyDisconnected = false;

  /// 보낸 메시지의 발신함 — "반드시 도착하거나 반드시 실패로 보인다". 규칙은 chat_outbox.dart.
  late final ChatOutbox _outbox = ChatOutbox(_PrefsOutboxStore());

  /// 소켓으로 보낸 뒤 서버 에코를 기다리는 시계 — localId → timer. 넘기면 REST로 다시 보낸다.
  final Map<String, Timer> _ackTimers = {};
  final Map<int, List<StompUnsubscribe>> _roomSubscriptions = {};

  // 채팅방 목록 화면에서 전체 방을 실시간 갱신하기 위한 경량 구독
  // (메시지 토픽만 — 상세 화면의 타이핑/읽음 구독과 달리 방마다 전부 걸어도 부담 없다)
  final Map<int, StompUnsubscribe> _roomListSubscriptions = {};
  bool _isWatchingRoomList = false;
  Timer? _roomListRefreshDebounce;

  // Set current user ID for message handling
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// 기관 ID를 알려준다. 이미 연결돼 있으면 그 자리에서 접속 등록까지 한다.
  void setCompanyId(String companyId) {
    if (_companyId == companyId) return;
    _companyId = companyId;
    if (_isConnected) _registerPresence();
  }

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  ChatRoom? get selectedRoom => _selectedRoom;
  List<ChatMessage> get messages => _messages;
  List<ChatParticipant> get participants => _participants;
  List<ChatMessageReader> get messageReaders => _messageReaders;
  List<ChatMessage> get sharedMedia => _sharedMedia;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isConnected => _isConnected;
  /// 세션이 끝나 재연결이 멈춘 상태인가 — 화면에서 재로그인 안내를 띄우는 데 쓴다.
  bool get stoppedForAuth => _stoppedForAuth;
  /// 언제부터 끊겨 있는지 (붙어 있으면 null).
  DateTime? get disconnectedSince => _disconnectedSince;
  Set<String> get typingUsers => _typingUsers;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  Set<String> get onlineUserIds => _onlineUserIds;

  bool isOnline(String userId) => _onlineUserIds.contains(userId);

  int get totalUnreadCount =>
      _chatRooms.fold(0, (sum, room) => sum + room.unreadCount);

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

  // ===================== WebSocket 관리 =====================

  Future<void> connectWebSocket() async {
    if (_stompClient != null && _stompClient!.connected) {
      print('[ChatProvider] WebSocket 이미 연결됨');
      return;
    }

    // 붙기 시작했으니 예약해 둔 재시도는 취소한다
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stoppedForAuth = false;
    _intentionallyDisconnected = false;

    // **실패한 채로 남아 있는 예전 클라이언트를 반드시 끈다.**
    // 안 끄면 그 클라이언트도 계속 다시 붙으려 하고, 화면을 옮길 때마다 하나씩 쌓여
    // 초당 여러 번 서버를 두드리게 된다(운영에서 실제로 초당 여섯 번까지 올라갔다).
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
    }

    try {
      // 인증 문제로 끊겼던 것이면 토큰부터 새로 받는다 — 만료된 토큰을 들고
      // 다시 붙어 봐야 또 401이다.
      //
      // 서버가 재시작돼 끊긴 경우(401이 아니라 그냥 연결 끊김)는 _needsFreshToken이
      // 서지 않는다. 그 상태로 간격을 늘려 가며 기다리는 동안 토큰이 만료될 수 있으므로,
      // 붙기 직전에 들고 있는 토큰의 exp를 직접 본다 — 401을 한 번 맞고서야 갱신하는
      // 왕복을 없앤다(socket_reconnect.dart의 isJwtExpired).
      final needsRefresh =
          _needsFreshToken || isJwtExpired(StorageService().getToken());
      if (needsRefresh) {
        _needsFreshToken = false;
        final refresh = await ApiService().refreshToken();
        if (refresh.shouldLogout) {
          // 세션이 진짜로 끝났다. 여기서 계속 시도하면 서버만 두드린다.
          // 조용히 멈추지 않고 로그인 화면으로 보내 다시 로그인하도록 안내한다.
          print('[ChatProvider] 세션 만료 — 소켓 재연결을 멈추고 재로그인을 안내한다');
          _stoppedForAuth = true;
          _isConnected = false;
          _markDisconnected();
          notifyListeners();
          unawaited(
            ApiService().performGlobalLogout(
              message: '로그인이 만료되었습니다. 다시 로그인해주세요',
            ),
          );
          return;
        }
      }

      final token = StorageService().getToken();
      if (token == null) {
        print('[ChatProvider] 토큰이 없어 WebSocket 연결 불가');
        return;
      }

      final wsUrl = 'wss://silverithm.site/ws/chat';

      // 이 연결의 세대 번호. 옛 클라이언트를 끄면서 나는 종료 신호가 새 연결을 다시 끊게
      // 두지 않기 위해, 종료 콜백은 자기 세대일 때만 처리한다.
      final generation = ++_socketGeneration;
      _stompClient = StompClient(
        config: StompConfig(
          url: wsUrl,
          onConnect: _onConnect,
          onDisconnect: _onDisconnect,
          onStompError: _onStompError,
          onWebSocketError: _onWebSocketError,
          // 서버가 소켓을 정상 종료하면(배포로 컨테이너 교체, 서버 재시작) 오류가 아니라
          // '종료'로 온다. 이 콜백이 없던 동안은 그 경우 앱이 끊긴 줄도 모르고 조용히
          // 멈춰 있었다 — 재접속도, 끊김 표시도 없이. 하트비트로 죽은 연결을 잡아낸 뒤
          // 패키지가 소켓을 닫을 때도 여기로 온다.
          onWebSocketDone: () => _onWebSocketDone(generation),
          stompConnectHeaders: {'Authorization': 'Bearer $token'},
          webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
          heartbeatOutgoing: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
          // 패키지의 자동 재연결은 **붙을 때 읽은 토큰을 그대로 다시 쓴다.**
          // 만료된 토큰으로 5초마다 영원히 두드리게 되므로 끄고, 우리가 직접
          // 토큰을 새로 받아 간격을 늘려 가며 붙는다(socket_reconnect.dart).
          reconnectDelay: Duration.zero,
        ),
      );

      _stompClient!.activate();
      print('[ChatProvider] WebSocket 연결 시도...');
    } catch (e) {
      print('[ChatProvider] WebSocket 연결 에러: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _onConnect(StompFrame frame) {
    // 서버가 하트비트를 주는지 남긴다 — 서버가 0으로 답하면 클라이언트는 끊김을 못 알아챈다
    print('[ChatProvider] WebSocket 연결 성공 (heart-beat=${frame.headers['heart-beat']})');
    _isConnected = true;
    _disconnectedSince = null;
    // 붙었으니 재시도 간격을 처음으로 되돌린다
    _reconnectAttempt = 0;
    _needsFreshToken = false;
    _typingUsers.clear();
    _cancelAllTypingTimers();
    notifyListeners();

    // 현재 선택된 채팅방이 있으면 구독
    if (_selectedRoom != null) {
      _subscribeToRoom(_selectedRoom!.id);
      // 구독은 '앞으로 올 것'만 받는다. 다시 붙은 것이라면 끊겨 있던 동안 지나간
      // 메시지를 따로 받아와야 한다 — 첫 연결은 화면이 이미 불러왔으므로 건너뛴다.
      if (_hasConnectedBefore) {
        backfillMissedMessages(_selectedRoom!.id);
      }
    }
    // 끊겨 있는 동안 실패한 메시지는 이제 보낼 수 있다 — 이 세션 것만 (chat_outbox.dart)
    if (_hasConnectedBefore) _resendFailedInSession();
    _hasConnectedBefore = true;

    // 목록 화면을 보고 있었다면 재연결 시 전체 방 구독을 복원한다
    _syncRoomListSubscriptions();

    _registerPresence();
  }

  /// 끊긴 시각을 기록한다 — 이미 끊긴 채로 또 에러가 겹쳐 와도 처음 끊긴 시각을 지키기
  /// 위해 이미 값이 있으면 덮어쓰지 않는다(그래야 화면의 "몇 초째 끊김" 표시가 맞는다).
  void _markDisconnected() {
    _disconnectedSince ??= DateTime.now();
  }

  /// 소켓이 닫혔다(정상 종료·하트비트 실패). 끊김으로 표시하고 다시 붙는다.
  void _onWebSocketDone(int generation) {
    if (generation != _socketGeneration) return; // 이미 갈아 끼운 옛 연결의 종료
    if (_intentionallyDisconnected) return;
    if (!_isConnected && (_reconnectTimer?.isActive ?? false)) return;
    print('[ChatProvider] WebSocket 닫힘 — 다시 붙는다');
    _isConnected = false;
    _markDisconnected();
    _roomSubscriptions.clear();
    _roomListSubscriptions.clear();
    _presenceSubscription = null;
    _onlineUserIds = {};
    _scheduleReconnect();
    notifyListeners();
  }

  void _onDisconnect(StompFrame frame) {
    print('[ChatProvider] WebSocket 연결 해제');
    _isConnected = false;
    _markDisconnected();
    _scheduleReconnect();
    _roomSubscriptions.clear();
    _roomListSubscriptions.clear();
    _typingUsers.clear();
    _cancelAllTypingTimers();
    // 끊긴 동안은 남의 상태를 알 수 없으니 표시하지 않는다
    _presenceSubscription = null;
    _onlineUserIds = {};
    notifyListeners();
  }

  void _onStompError(StompFrame frame) {
    print('[ChatProvider] STOMP 에러: ${frame.body}');
    _isConnected = false;
    _markDisconnected();
    if (looksLikeAuthFailure(frame.body)) _needsFreshToken = true;
    _scheduleReconnect();
    notifyListeners();
  }

  void _onWebSocketError(dynamic error) {
    print('[ChatProvider] WebSocket 에러: $error');
    _isConnected = false;
    _markDisconnected();
    // 401로 막힌 것이면 토큰부터 새로 받아야 한다 — 같은 토큰으로 다시 붙으면 또 401이다
    if (looksLikeAuthFailure(error)) _needsFreshToken = true;
    _scheduleReconnect();
    notifyListeners();
  }

  /// 다시 붙기를 예약한다. 간격은 2초에서 시작해 60초까지 늘어난다.
  ///
  /// 예약은 **하나만** 살아 있는다 — 에러와 끊김이 함께 오는 경우가 흔한데,
  /// 그때마다 예약을 쌓으면 재시도가 겹쳐 서버를 두드리게 된다.
  void _scheduleReconnect() {
    if (_intentionallyDisconnected || _stoppedForAuth) return;
    if (_reconnectTimer?.isActive ?? false) return;

    final delay = socketRetryDelay(_reconnectAttempt);
    _reconnectAttempt++;
    print('[ChatProvider] ${delay.inSeconds}초 뒤 다시 붙는다 (시도 $_reconnectAttempt)');

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_intentionallyDisconnected || _stoppedForAuth) return;
      connectWebSocket();
    });
  }

  void disconnectWebSocket() {
    // 사람이 끊은 것이다 — 다시 붙지 않는다
    _intentionallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
      _isConnected = false;
      // 다음에 붙는 것은 '다시 붙음'이 아니라 새 연결이다 (로그아웃·계정 전환)
      _hasConnectedBefore = false;
      _roomSubscriptions.clear();
      _roomListSubscriptions.clear();
      _typingUsers.clear();
      _cancelAllTypingTimers();
      _presenceSubscription = null;
      _onlineUserIds = {};
      print('[ChatProvider] WebSocket 연결 해제');
      notifyListeners();
    }
  }

  void _subscribeToRoom(int roomId) {
    if (_stompClient == null || !_stompClient!.connected) {
      print('[ChatProvider] WebSocket 미연결 - 구독 불가');
      return;
    }

    // 목록용 경량 구독이 있었다면 상세 구독으로 승격 (중복 수신 방지)
    _roomListSubscriptions.remove(roomId)?.call();

    // 기존 구독이 있으면 해제
    _unsubscribeFromRoom(roomId);

    final subscriptions = <StompUnsubscribe>[];

    // 메시지 수신 구독
    subscriptions.add(
      _stompClient!.subscribe(
        destination: '/topic/chat/$roomId',
        callback: (frame) {
          if (frame.body != null) {
            _handleIncomingMessage(frame.body!, currentUserId: _currentUserId);
          }
        },
      ),
    );

    // 타이핑 상태 구독
    subscriptions.add(
      _stompClient!.subscribe(
        destination: '/topic/chat/$roomId/typing',
        callback: (frame) {
          if (frame.body != null) {
            _handleTypingStatus(frame.body!);
          }
        },
      ),
    );

    // 읽음 상태 구독
    subscriptions.add(
      _stompClient!.subscribe(
        destination: '/topic/chat/$roomId/read',
        callback: (frame) {
          if (frame.body != null) {
            _handleReadStatus(frame.body!);
          }
        },
      ),
    );

    _roomSubscriptions[roomId] = subscriptions;
    print('[ChatProvider] 채팅방 $roomId 구독 완료 (${subscriptions.length}개 토픽)');
  }

  void _unsubscribeFromRoom(int roomId) {
    final subscriptions = _roomSubscriptions[roomId];
    if (subscriptions != null) {
      for (final unsubscribe in subscriptions) {
        unsubscribe();
      }
    }
    _roomSubscriptions.remove(roomId);
    print('[ChatProvider] 채팅방 $roomId 구독 해제');
  }

  // ===================== 채팅방 목록 실시간 구독 =====================

  /// 채팅방 목록 화면이 떠 있는 동안 참여 중인 모든 방의 메시지 토픽을 구독한다.
  /// 상세 화면과 달리 방이 열려 있지 않아도 새 메시지의 미리보기/정렬이 즉시 반영되도록 한다.
  void subscribeToRoomList() {
    _isWatchingRoomList = true;
    _syncRoomListSubscriptions();
  }

  /// 목록 화면을 벗어날 때 호출 — 더 이상 필요 없는 구독을 전부 해제한다.
  void unsubscribeFromRoomList() {
    _isWatchingRoomList = false;
    for (final unsubscribe in _roomListSubscriptions.values) {
      unsubscribe();
    }
    _roomListSubscriptions.clear();
  }

  /// 현재 채팅방 목록과 구독 상태를 맞춘다: 새로 생긴 방은 구독을 걸고,
  /// 목록에서 사라진 방은 구독을 해제하며, 상세 화면이 이미 구독 중인 방은 건너뛴다.
  void _syncRoomListSubscriptions() {
    if (!_isWatchingRoomList) return;
    if (_stompClient == null || !_stompClient!.connected) return;

    final currentIds = _chatRooms.map((r) => r.id).toSet();

    final staleIds = _roomListSubscriptions.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _roomListSubscriptions.remove(id)?.call();
    }

    for (final roomId in currentIds) {
      if (_roomSubscriptions.containsKey(roomId)) continue;
      if (_roomListSubscriptions.containsKey(roomId)) continue;

      _roomListSubscriptions[roomId] = _stompClient!.subscribe(
        destination: '/topic/chat/$roomId',
        callback: (frame) {
          if (frame.body != null) {
            _handleIncomingMessage(frame.body!, currentUserId: _currentUserId);
          }
        },
      );
    }
  }

  /// FCM 포그라운드 수신 등 외부 트리거로 목록을 새로고침한다.
  /// 짧은 시간에 여러 번 호출돼도 마지막 한 번만 API를 호출하도록 디바운스한다.
  void refreshRoomListDebounced({
    required String companyId,
    required String userId,
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _roomListRefreshDebounce?.cancel();
    _roomListRefreshDebounce = Timer(delay, () {
      loadChatRooms(companyId: companyId, userId: userId);
    });
  }

  // ===================== 접속 상태 =====================

  /// 내가 붙었음을 알리고, 같은 기관 사람들의 상태 변화를 구독한다.
  /// 연결이 끊기면 서버가 알아서 오프라인 처리하므로 나갈 때 보낼 것은 없다.
  void _registerPresence() {
    final companyId = _companyId;
    final userId = _currentUserId;
    if (companyId == null || userId == null) return;
    if (_stompClient == null || !_stompClient!.connected) return;

    _presenceSubscription?.call();
    _presenceSubscription = _stompClient!.subscribe(
      destination: '/topic/presence/$companyId',
      callback: (frame) {
        if (frame.body != null) _handlePresenceChange(frame.body!);
      },
    );

    _stompClient!.send(
      destination: '/app/presence/join',
      body: json.encode({'userId': userId, 'companyId': companyId}),
    );

    // 이미 붙어 있던 사람들은 방송을 못 받으므로 한 번 받아온다
    loadOnlineUsers();
    print('[ChatProvider] 접속 상태 등록: userId=$userId, companyId=$companyId');
  }

  void _handlePresenceChange(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final changedId = data['userId']?.toString();
      final online = data['online'] as bool? ?? false;
      if (changedId == null) return;

      final next = Set<String>.from(_onlineUserIds);
      if (online) {
        next.add(changedId);
      } else {
        next.remove(changedId);
      }
      _onlineUserIds = next;
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 접속 상태 파싱 에러: $e');
    }
  }

  /// 현재 접속자 전체를 다시 받아온다 (화면 첫 진입·새로고침용)
  Future<void> loadOnlineUsers() async {
    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final response = await ApiService().getOnlineUsers(companyId: companyId);
      final ids = response['onlineUserIds'] as List<dynamic>?;
      _onlineUserIds = (ids ?? []).map((e) => e.toString()).toSet();
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 접속 상태 조회 에러: $e');
    }
  }

  void _handleIncomingMessage(String body, {String? currentUserId}) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;

      // WebSocket 메시지 타입 확인
      final messageType = data['type']?.toString();

      // 누가 메시지를 지웠을 때 — 그 자리를 '삭제된 메시지입니다'로 갈아끼운다.
      // 목록에서 빼지 않는 건 답장이 걸린 대화가 끊기지 않게 하려는 것이다.
      if (messageType == 'DELETE' && data['message'] != null) {
        final deleted = ChatMessage.fromJson(
          data['message'] as Map<String, dynamic>,
        );
        final deletedRoomId =
            (data['roomId'] as num?)?.toInt() ?? deleted.chatRoomId;
        if (_selectedRoom != null && deletedRoomId == _selectedRoom!.id) {
          final index = _messages.indexWhere((m) => m.id == deleted.id);
          if (index != -1) {
            _messages[index] = deleted;
            notifyListeners();
          }
        }
        return;
      }

      // 누가 메시지를 수정했을 때 — 그 자리를 수정된 내용으로 갈아끼운다.
      if (messageType == 'EDIT' && data['message'] != null) {
        final edited = ChatMessage.fromJson(
          data['message'] as Map<String, dynamic>,
        );
        final editedRoomId =
            (data['roomId'] as num?)?.toInt() ?? edited.chatRoomId;
        if (_selectedRoom != null && editedRoomId == _selectedRoom!.id) {
          final index = _messages.indexWhere((m) => m.id == edited.id);
          if (index != -1) {
            _messages[index] = edited;
            notifyListeners();
          }
        }
        return;
      }

      ChatMessage? message;
      int? roomId;

      if (messageType == 'MESSAGE' && data['message'] != null) {
        // ChatWebSocketMessage 형식 (백엔드에서 보낸 래퍼)
        message = ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
        roomId = (data['roomId'] as num?)?.toInt() ?? message.chatRoomId;
      } else if (data['id'] != null && data['chatRoomId'] != null) {
        // 직접 ChatMessage 형식
        message = ChatMessage.fromJson(data);
        roomId = message.chatRoomId;
      } else if (messageType == 'JOIN' || messageType == 'LEAVE') {
        // 입장/퇴장 이벤트는 별도 처리
        print('[ChatProvider] 입장/퇴장 이벤트: $messageType');
        return;
      } else {
        print('[ChatProvider] 알 수 없는 메시지 형식: $data');
        return;
      }

      // 내가 보낸 메시지인지 확인
      final isMyMessage =
          currentUserId != null && message.senderId == currentUserId;

      // 내가 보낸 메시지의 에코라면 발신함에서 지운다 — 방을 나가 있어도 재전송 시계는 멈춰야 한다
      final echoedKey = message.clientMessageId;
      if (echoedKey != null && echoedKey.isNotEmpty) {
        final acked = _outbox.acknowledgeByClientMessageId(echoedKey);
        if (acked != null) _cancelAckTimer(acked.localId);
      }

      // 현재 선택된 채팅방의 메시지인 경우 목록에 추가
      if (_selectedRoom != null && roomId == _selectedRoom!.id) {
        // 이미 있는 메시지인지 체크 (서버 ID로)
        final existingIndex = _messages.indexWhere(
          (m) => m.id > 0 && m.id == message!.id,
        );
        if (existingIndex != -1) {
          // 이미 있는 메시지면 무시
          return;
        }

        // 내 '전송 중' 말풍선인가 — 식별자로만 찾는다.
        // 전에는 (보낸 사람, 내용)으로 찾고 5초 안의 같은 내용을 중복으로 버렸다.
        // "네", "네"처럼 같은 말을 연달아 보내면 두 번째가 사라지던 이유다.
        final pendingIndex = indexOfPending(_messages, message);
        if (pendingIndex != -1) {
          _settlePending(_messages[pendingIndex].localId!, message);
        } else {
          _messages.insert(0, message);
          notifyListeners();
        }
      }

      // 채팅방 목록 업데이트 (마지막 메시지 + unreadCount)
      final roomIndex = _chatRooms.indexWhere((r) => r.id == roomId);
      if (roomIndex != -1) {
        final currentRoom = _chatRooms[roomIndex];

        // 현재 보고 있는 채팅방이 아니고 내가 보낸 메시지가 아니면 unreadCount 증가
        final bool isViewingThisRoom =
            _selectedRoom != null && _selectedRoom!.id == roomId;
        final int newUnreadCount = (!isViewingThisRoom && !isMyMessage)
            ? currentRoom.unreadCount + 1
            : currentRoom.unreadCount;

        _chatRooms[roomIndex] = currentRoom.copyWith(
          lastMessage: message,
          lastMessageAt: message.createdAt,
          unreadCount: newUnreadCount,
        );

        // 정렬 (최신 메시지 순)
        _chatRooms.sort((a, b) {
          final aTime = a.lastMessageAt ?? a.createdAt;
          final bTime = b.lastMessageAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
        notifyListeners();
      }
    } catch (e) {
      print('[ChatProvider] 메시지 파싱 에러: $e');
    }
  }

  void _handleTypingStatus(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final userName =
          data['senderName']?.toString() ?? data['userName']?.toString() ?? '';
      final isTyping = data['isTyping'] as bool? ?? false;

      if (userName.isEmpty) return;

      // 현재 사용자 자신의 타이핑 상태는 무시
      if (_currentUserId != null &&
          (data['senderId']?.toString() == _currentUserId ||
              data['userId']?.toString() == _currentUserId))
        return;

      if (isTyping) {
        _typingUsers.add(userName);

        // 기존 타이머 취소
        _typingTimers[userName]?.cancel();

        // 5초 후 자동 제거
        _typingTimers[userName] = Timer(const Duration(seconds: 5), () {
          _typingUsers.remove(userName);
          _typingTimers.remove(userName);
          notifyListeners();
        });
      } else {
        _typingUsers.remove(userName);
        _typingTimers[userName]?.cancel();
        _typingTimers.remove(userName);
      }
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 타이핑 상태 파싱 에러: $e');
    }
  }

  void _cancelAllTypingTimers() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
  }

  void _handleReadStatus(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      // ChatWebSocketMessage 형식 지원
      final lastReadMessageId = (data['lastReadMessageId'] as num?)?.toInt();
      final messageId =
          (data['messageId'] as num?)?.toInt() ?? lastReadMessageId;
      final readCount = data['readCount'] as int?;
      final userId = data['senderId']?.toString() ?? data['userId']?.toString();
      final userName =
          data['senderName']?.toString() ?? data['userName']?.toString();

      print(
        '[ChatProvider] 읽음 상태 수신: messageId=$messageId, userId=$userId, userName=$userName',
      );

      // 서버가 특정 메시지의 정확한 읽은 수를 준 경우엔 그 값을 그대로 쓴다
      if (data['messageId'] != null && readCount != null) {
        final messageIndex = _messages.indexWhere((m) => m.id == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            readCount: readCount,
          );
          notifyListeners();
        }
        return;
      }

      // 그 외에는 '그 사람이 어디까지 읽었는지'만 옮긴다.
      // 메시지마다 readCount를 +1 하던 이전 방식은 같은 사람이 두 번 읽을 때
      // 이전 메시지가 또 올라가, 안 읽은 수가 실제보다 빨리 사라졌다.
      if (lastReadMessageId != null && userId != null) {
        final index = _participants.indexWhere((p) => p.userId == userId);
        if (index != -1) {
          final current = _participants[index].lastReadMessageId ?? 0;
          if (lastReadMessageId > current) {
            _participants[index] = _participants[index].copyWith(
              lastReadMessageId: lastReadMessageId,
            );
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('[ChatProvider] 읽음 상태 파싱 에러: $e');
    }
  }

  // WebSocket으로 메시지 전송
  void sendMessageViaWebSocket(
    int roomId,
    String content, {
    MessageType type = MessageType.text,
    required String senderId,
    required String senderName,
    int? replyToId,
    String? clientMessageId,
  }) {
    if (_stompClient == null || !_stompClient!.connected) {
      print('[ChatProvider] WebSocket 미연결 - 메시지 전송 불가');
      return;
    }

    final messageData = {
      'chatRoomId': roomId,
      'content': content,
      'type': type.name.toUpperCase(),
      'senderId': senderId,
      'senderName': senderName,
      // 답장이면 원본 id를 함께 보낸다. 서버가 원본을 펼쳐 되돌려준다(웹과 같은 계약).
      if (replyToId != null) 'replyToId': replyToId,
      // 서버가 그대로 되돌려주는 식별자 — 에코를 내 말풍선에 붙이고, 재전송 중복을 막는다
      if (clientMessageId != null) 'clientMessageId': clientMessageId,
    };

    _stompClient!.send(
      destination: '/app/chat/$roomId/send',
      body: json.encode(messageData),
    );
  }

  // 타이핑 상태 전송
  void sendTypingStatus(
    int roomId,
    bool isTyping, {
    required String userId,
    required String userName,
  }) {
    if (_stompClient == null || !_stompClient!.connected) return;

    final typingData = {
      'isTyping': isTyping,
      'userId': userId,
      'userName': userName,
    };

    _stompClient!.send(
      destination: '/app/chat/$roomId/typing',
      body: json.encode(typingData),
    );
  }

  // 읽음 상태 전송
  void sendReadStatus(
    int roomId,
    int lastMessageId, {
    required String userId,
    required String userName,
  }) {
    if (_stompClient == null || !_stompClient!.connected) return;

    final readData = {
      'lastMessageId': lastMessageId,
      'userId': userId,
      'userName': userName,
    };

    _stompClient!.send(
      destination: '/app/chat/$roomId/read',
      body: json.encode(readData),
    );
  }

  // ===================== 채팅방 관리 =====================

  Future<void> loadChatRooms({
    required String companyId,
    required String userId,
  }) async {
    try {
      setLoading(true);
      clearError();

      // 현재 사용자 ID 저장
      _currentUserId = userId;
      setCompanyId(companyId);

      final response = await ApiService().getChatRooms(
        companyId: companyId,
        userId: userId,
      );

      print('[ChatProvider] 채팅방 목록 응답: $response');

      if (response['rooms'] != null) {
        final List<dynamic> content = response['rooms'] as List<dynamic>;
        _chatRooms = content
            .map((json) => ChatRoom.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        _chatRooms = content
            .map((json) => ChatRoom.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _chatRooms = [];
      }

      // 내가 보낸 마지막 메시지인 경우 unreadCount를 0으로 설정
      // (내가 보낸 메시지는 내가 읽을 필요 없음)
      for (int i = 0; i < _chatRooms.length; i++) {
        final room = _chatRooms[i];
        if (room.lastMessage != null && room.lastMessage!.senderId == userId) {
          _chatRooms[i] = room.copyWith(unreadCount: 0);
        }
      }

      // 최신 메시지 순 정렬
      _chatRooms.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      print('[ChatProvider] 로드된 채팅방 수: ${_chatRooms.length}');
      _syncRoomListSubscriptions();
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 채팅방 목록 로드 에러: $e');
      setError('채팅방 목록을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  Future<ChatRoom?> createChatRoom({
    required String companyId,
    required String name,
    String? description,
    required String createdBy,
    required String createdByName,
    required List<String> participantIds,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().createChatRoom(
        companyId: companyId,
        name: name,
        description: description,
        createdBy: createdBy,
        createdByName: createdByName,
        participantIds: participantIds,
      );

      print('[ChatProvider] 채팅방 생성 응답: $response');

      final roomData = response['room'] ?? response;
      final newRoom = ChatRoom.fromJson(roomData as Map<String, dynamic>);

      _chatRooms.insert(0, newRoom);
      _syncRoomListSubscriptions();
      notifyListeners();

      return newRoom;
    } catch (e) {
      print('[ChatProvider] 채팅방 생성 에러: $e');
      setError('채팅방 생성에 실패했습니다: ${e.toString()}');
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> updateChatRoom({
    required int roomId,
    required String name,
    String? description,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().updateChatRoom(
        roomId: roomId,
        name: name,
        description: description,
      );

      print('[ChatProvider] 채팅방 수정 응답: $response');

      final roomIndex = _chatRooms.indexWhere((r) => r.id == roomId);
      if (roomIndex != -1) {
        _chatRooms[roomIndex] = _chatRooms[roomIndex].copyWith(
          name: name,
          description: description,
        );
        if (_selectedRoom?.id == roomId) {
          _selectedRoom = _chatRooms[roomIndex];
        }
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('[ChatProvider] 채팅방 수정 에러: $e');
      setError('채팅방 수정에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> leaveRoom(int roomId, String userId) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().leaveChatRoom(
        roomId: roomId,
        userId: userId,
      );

      print('[ChatProvider] 채팅방 나가기 응답: $response');

      // 구독 해제
      _unsubscribeFromRoom(roomId);

      // 목록에서 제거
      _chatRooms.removeWhere((r) => r.id == roomId);
      if (_selectedRoom?.id == roomId) {
        _selectedRoom = null;
        _messages.clear();
        _participants.clear();
      }
      _syncRoomListSubscriptions();
      notifyListeners();

      return true;
    } catch (e) {
      print('[ChatProvider] 채팅방 나가기 에러: $e');
      setError('채팅방 나가기에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> deleteChatRoom(int roomId) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().deleteChatRoom(roomId: roomId);

      print('[ChatProvider] 채팅방 삭제 응답: $response');

      _unsubscribeFromRoom(roomId);
      _chatRooms.removeWhere((r) => r.id == roomId);
      if (_selectedRoom?.id == roomId) {
        _selectedRoom = null;
        _messages.clear();
        _participants.clear();
      }
      _syncRoomListSubscriptions();
      notifyListeners();

      return true;
    } catch (e) {
      print('[ChatProvider] 채팅방 삭제 에러: $e');
      setError('채팅방 삭제에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  void selectRoom(ChatRoom room) {
    // 이전 채팅방 구독 해제
    if (_selectedRoom != null && _selectedRoom!.id != room.id) {
      _unsubscribeFromRoom(_selectedRoom!.id);
    }

    _selectedRoom = room;
    _messages.clear();
    _participants.clear();
    _currentPage = 0;
    _hasMoreMessages = true;
    _typingUsers.clear();

    // 채팅방 목록에서 unreadCount를 0으로 설정 (입장 시 읽음 처리)
    final roomIndex = _chatRooms.indexWhere((r) => r.id == room.id);
    if (roomIndex != -1) {
      _chatRooms[roomIndex] = _chatRooms[roomIndex].copyWith(unreadCount: 0);
    }

    // 새 채팅방 구독
    if (_isConnected) {
      _subscribeToRoom(room.id);
    }

    notifyListeners();
  }

  void clearSelectedRoom() {
    if (_selectedRoom != null) {
      _unsubscribeFromRoom(_selectedRoom!.id);
    }
    _selectedRoom = null;
    _messages.clear();
    _participants.clear();
    _typingUsers.clear();
    // 방을 나간 자리를 목록용 경량 구독으로 다시 채운다 (목록 화면을 보고 있을 때만)
    _syncRoomListSubscriptions();
    notifyListeners();
  }

  // ===================== 참가자 관리 =====================

  Future<void> loadParticipants(int roomId) async {
    try {
      final response = await ApiService().getChatParticipants(roomId: roomId);

      print('[ChatProvider] 참가자 목록 응답: $response');

      if (response['participants'] != null) {
        final List<dynamic> content = response['participants'] as List<dynamic>;
        _participants = content
            .map(
              (json) => ChatParticipant.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        _participants = [];
      }

      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 참가자 목록 로드 에러: $e');
    }
  }

  Future<bool> addParticipants(int roomId, List<String> userIds) async {
    try {
      final response = await ApiService().addChatParticipants(
        roomId: roomId,
        userIds: userIds,
      );

      print('[ChatProvider] 참가자 추가 응답: $response');

      // 참가자 목록 새로고침
      await loadParticipants(roomId);

      return true;
    } catch (e) {
      print('[ChatProvider] 참가자 추가 에러: $e');
      setError('참가자 추가에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  Future<bool> removeParticipant(
    int roomId,
    String userId, {
    bool isKicked = false,
  }) async {
    try {
      final response = await ApiService().removeChatParticipant(
        roomId: roomId,
        userId: userId,
        isKicked: isKicked,
      );

      print('[ChatProvider] 참가자 제거 응답: $response');

      // 참가자 목록에서 제거
      _participants.removeWhere((p) => p.userId == userId);
      notifyListeners();

      return true;
    } catch (e) {
      print('[ChatProvider] 참가자 제거 에러: $e');
      setError('참가자 제거에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  // ===================== 메시지 관리 =====================

  Future<void> loadMessages({required int roomId, bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _messages.clear();
      _hasMoreMessages = true;
      _hasNewerMessages = false;
    }

    if (!_hasMoreMessages && !refresh) return;

    // 스크롤 이벤트는 화면이 다시 그려지는 것보다 훨씬 빨리 연달아 오므로
    // 재진입은 호출부가 아니라 여기서 막는다 — 같은 페이지를 두 번 받아
    // 페이지 번호만 건너뛰는 일(= 대화 구멍)을 없앤다.
    //
    // 이 판정과 플래그 세팅은 try 밖에 있어야 한다. 안에 두면 "이미 불러오는
    // 중이라 그냥 빠져나온" 두 번째 호출까지 finally를 지나면서 남의 잠금을
    // 풀어버린다(그러면 재진입 방지가 사실상 없는 것과 같다).
    if (_isLoadingOlderMessages) return;
    if (!refresh) {
      _isLoadingOlderMessages = true;
      notifyListeners();
    }

    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getChatMessages(
        roomId: roomId,
        page: _currentPage,
      );

      print('[ChatProvider] 메시지 목록 응답: $response');

      if (response['messages'] != null) {
        final List<dynamic> content = response['messages'] as List<dynamic>;
        final List<ChatMessage> newMessages = content
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _messages = newMessages;
        } else {
          appendOlderMessages(_messages, newMessages);
        }

        _hasMoreMessages =
            response['hasMore'] as bool? ??
            (response['totalPages'] != null
                ? _currentPage < (response['totalPages'] as int) - 1
                : false);
        _currentPage++;
      } else if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        final List<ChatMessage> newMessages = content
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _messages = newMessages;
        } else {
          appendOlderMessages(_messages, newMessages);
        }

        _hasMoreMessages =
            response['hasMore'] as bool? ??
            (response['totalPages'] != null
                ? _currentPage < (response['totalPages'] as int) - 1
                : false);
        _currentPage++;
      } else {
        if (refresh) {
          _messages = [];
        }
        _hasMoreMessages = false;
      }

      if (refresh) _restoreFailedBubbles(roomId);

      print('[ChatProvider] 로드된 메시지 수: ${_messages.length}');
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 메시지 목록 로드 에러: $e');
      setError('메시지를 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      _isLoadingOlderMessages = false;
      setLoading(false);
    }
  }

  /// 소켓이 끊겼다 다시 붙었을 때, 끊겨 있던 사이에 지나간 메시지를 채워 넣는다.
  ///
  /// 재구독만으로는 부족하다 — 구독은 '앞으로 올 것'만 받기 때문이다.
  /// 목록을 통째로 갈아끼우면(loadMessages refresh) 위로 올려 불러온 옛 대화와
  /// 스크롤 위치가 날아가므로, 모르는 것만 최신 쪽(앞)에 끼워 넣는다.
  ///
  /// _messages는 최신이 앞(index 0)인 순서이고, 서버도 최신순으로 준다.
  Future<void> backfillMissedMessages(int roomId) async {
    try {
      final response = await ApiService().getChatMessages(roomId: roomId, page: 0);
      final content =
          (response['messages'] ?? response['content']) as List<dynamic>?;
      if (content == null || content.isEmpty) return;

      final latest = content
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();

      final knownIds = _messages.map((m) => m.id).toSet();
      final missed = latest.where((m) => !knownIds.contains(m.id)).toList();
      if (missed.isEmpty) return;

      // 새로 받은 한 페이지가 내가 아는 것과 하나도 안 겹치면, 두 구간 사이가 비어 있다
      // (끊긴 사이에 한 페이지를 넘게 쌓인 경우). 억지로 이으면 빠진 구간이 없는 것처럼
      // 보이므로, 그때는 새로 받은 구간만 남기고 위로 올려 불러오는 경로에 나머지를 맡긴다.
      final overlaps = latest.any((m) => knownIds.contains(m.id));
      if (!overlaps) {
        // 옛 대화를 읽는 중이면 목록을 갈아끼우지 않는다 — 갈아끼우면 읽던 자리가
        // 맨 아래(최신)로 튀어 "자꾸 최신으로 돌아간다"는 제보가 됐다. 대신 표시만 남긴다.
        final nearBottom = viewerNearBottom?.call() ?? true;
        if (!nearBottom) {
          _hasNewerMessages = true;
          print('[ChatProvider] 재연결 후 대화가 많이 밀렸지만 옛 대화를 읽는 중 — 새 메시지 보기로 미룸');
          notifyListeners();
          return;
        }
        _messages = latest;
        _currentPage = 1;
        _hasMoreMessages = true;
        print('[ChatProvider] 재연결 후 대화가 많이 밀려 최신 구간부터 다시 잡음');
        notifyListeners();
        return;
      }

      missed.sort((a, b) => b.id.compareTo(a.id)); // 최신이 앞
      _messages.insertAll(0, missed);
      print('[ChatProvider] 재연결 후 놓친 메시지 ${missed.length}건 보충');
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 재연결 후 놓친 메시지 보충 실패: $e');
    }
  }

  /// 문자 메시지를 보낸다. 화면에는 즉시 '전송 중' 말풍선이 뜬다.
  ///
  /// 소켓이 붙어 있으면 소켓으로 보내고 [ackTimeout] 안에 서버 에코를 기다린다.
  /// 에코가 없으면 같은 식별자로 REST로 다시 보낸다 — 서버는 같은 식별자를 두 번 저장하지
  /// 않으므로 소켓 전송이 실은 도착해 있었어도 중복이 생기지 않는다.
  /// 그것도 실패하면 '실패'로 남기고 다시 보내기를 기다린다(chat_outbox.dart).
  Future<bool> sendTextMessage(
    int roomId,
    String content, {
    required String senderId,
    required String senderName,
    ChatMessage? replyTo,
  }) async {
    final now = DateTime.now();
    final entry = OutboxEntry(
      localId: 'local_${now.millisecondsSinceEpoch}_${_pendingLocalIdSeq++}',
      clientMessageId: newClientMessageId(),
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      replyToId: replyTo?.id,
      createdAt: now,
    );

    // 임시 메시지 생성 (전송 중 상태)
    final pendingMessage = ChatMessage(
      id: -now.millisecondsSinceEpoch, // 음수 임시 ID
      chatRoomId: roomId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.text,
      content: content,
      createdAt: now,
      readCount: 1, // 발신자 본인은 이미 읽음
      sendingStatus: MessageSendingStatus.sending,
      localId: entry.localId,
      clientMessageId: entry.clientMessageId,
      // 보내는 순간부터 답장 미리보기가 보이도록 낙관적 버블에도 담는다.
      // 서버 응답이 오면 그쪽 값으로 통째로 교체된다.
      replyToId: replyTo?.id,
      replyToSenderName: replyTo?.senderName,
      replyToContent: replyTo?.content,
      replyToType: replyTo?.type.name.toUpperCase(),
      replyToMediaType: replyTo?.mediaType,
    );

    // 즉시 UI에 표시
    _messages.insert(0, pendingMessage);
    notifyListeners();
    _outbox.expectAck(entry);

    // 소켓이 정말 살아 있을 때만 소켓으로 — _isConnected만 믿으면 죽은 소켓에 보내고 잊는다
    if (_isConnected && (_stompClient?.connected ?? false)) {
      sendMessageViaWebSocket(
        roomId,
        content,
        senderId: senderId,
        senderName: senderName,
        replyToId: replyTo?.id,
        clientMessageId: entry.clientMessageId,
      );
      _startAckTimer(entry);
      return true;
    }

    return _sendViaRest(entry);
  }

  /// 소켓으로 보낸 뒤 에코를 기다린다. 시간 안에 안 오면 REST로 같은 식별자로 다시 보낸다.
  void _startAckTimer(OutboxEntry entry) {
    _ackTimers[entry.localId]?.cancel();
    _ackTimers[entry.localId] = Timer(ackTimeout, () {
      _ackTimers.remove(entry.localId);
      final stillWaiting = _outbox.awaitingAck.any((e) => e.localId == entry.localId);
      if (!stillWaiting) return;
      print('[ChatProvider] ${ackTimeout.inSeconds}초 안에 서버 에코 없음 — REST로 다시 보낸다: ${entry.clientMessageId}');
      _sendViaRest(entry);
    });
  }

  void _cancelAckTimer(String localId) {
    _ackTimers.remove(localId)?.cancel();
  }

  void _cancelAllAckTimers() {
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
  }

  /// 서버 에코가 내 말풍선에 닿았다 — 시계를 멈추고 발신함에서 지우고 말풍선을 바꾼다.
  void _settlePending(String localId, ChatMessage serverMessage) {
    _cancelAckTimer(localId);
    _outbox.acknowledge(localId);
    _replacePendingMessage(localId, serverMessage);
  }

  /// REST로 보낸다(같은 식별자). 성공하면 말풍선을 서버 메시지로 바꾸고, 실패하면 '실패'로 남긴다.
  Future<bool> _sendViaRest(OutboxEntry entry) async {
    try {
      final Map<String, dynamic> response;
      if (entry.isFile) {
        response = await ApiService().uploadChatFile(
          roomId: entry.roomId,
          file: File(entry.filePath!),
          senderId: entry.senderId,
          senderName: entry.senderName,
          batchId: entry.batchId,
          batchSize: entry.batchSize,
          clientMessageId: entry.clientMessageId,
        );
      } else {
        response = await ApiService().sendChatMessage(
          roomId: entry.roomId,
          content: entry.content ?? '',
          type: 'TEXT',
          senderId: entry.senderId,
          senderName: entry.senderName,
          replyToId: entry.replyToId,
          clientMessageId: entry.clientMessageId,
        );
      }

      final messageData = response['message'] ?? response;
      final newMessage = ChatMessage.fromJson(
        messageData as Map<String, dynamic>,
      );
      _cancelAckTimer(entry.localId);
      _outbox.acknowledge(entry.localId);
      _replacePendingMessage(entry.localId, newMessage);
      return true;
    } catch (e) {
      print('[ChatProvider] 전송 실패(REST): ${entry.clientMessageId} $e');
      _cancelAckTimer(entry.localId);
      _outbox.markFailed(entry.localId);
      _updatePendingMessageStatus(entry.localId, MessageSendingStatus.failed);
      setError(entry.isFile
          ? '파일 전송에 실패했습니다: ${e.toString()}'
          : '메시지 전송에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// '다시 보내기'. 실패한 말풍선을 같은 식별자로 REST로 다시 보낸다.
  Future<bool> retryMessage(String localId) async {
    final entry = _outbox.entry(localId);
    if (entry == null) return false;
    final resend = entry.asInSession();
    _outbox.expectAck(resend);
    _updatePendingMessageStatus(localId, MessageSendingStatus.sending);
    return _sendViaRest(resend);
  }

  /// '보내지 않고 삭제'. 서버에 없는 말풍선을 화면과 발신함에서 지운다.
  void discardLocalMessage(String localId) {
    _cancelAckTimer(localId);
    _outbox.discard(localId);
    _messages.removeWhere((m) => m.localId == localId);
    notifyListeners();
  }

  /// 소켓이 다시 붙었다 — 이 세션에서 실패한 것만 자동으로 다시 보낸다.
  /// 앱을 껐다 켠 뒤 남은 실패는 여기 오지 않는다(chat_outbox.dart의 이유).
  void _resendFailedInSession() {
    for (final entry in _outbox.autoResendCandidates()) {
      print('[ChatProvider] 다시 붙음 — 실패한 메시지 자동 재전송: ${entry.clientMessageId}');
      _outbox.expectAck(entry);
      _updatePendingMessageStatus(entry.localId, MessageSendingStatus.sending);
      _sendViaRest(entry);
    }
  }

  /// 방에 들어갔을 때, 이 방에서 실패한 채 남은 메시지를 '실패' 말풍선으로 되살린다.
  void _restoreFailedBubbles(int roomId) {
    for (final entry in _outbox.failedForRoom(roomId)) {
      if (_messages.any((m) => m.localId == entry.localId)) continue;
      _messages.insert(0, entry.toFailedMessage());
    }
  }

  /// 앱이 앞으로 돌아왔을 때 — 소켓이 죽어 있으면 기다리지 않고 바로 다시 붙는다.
  ///
  /// 화면이 꺼지거나 망이 바뀌면 소켓은 조용히 죽고, 앱은 하트비트가 어긋나기 전까지
  /// 그걸 모른다. 그 사이에 보낸 메시지가 사라지던 게 이번 사고다.
  void ensureConnected() {
    if (_intentionallyDisconnected || _stoppedForAuth) return;
    if (StorageService().getToken() == null) return;
    final alive = _isConnected && (_stompClient?.connected ?? false);
    if (alive) {
      // 클라이언트는 '붙어 있다'고 알고 있어도, 화면이 꺼진 동안 조용히 죽었다가
      // 아직 하트비트가 그걸 알아채기 전일 수 있다(끊김 감지 자체가 다음 하트비트까지
      // 늦어진다). 열려 있는 방이 있으면 그 사이 놓친 메시지가 없는지 확인해 둔다 —
      // backfillMissedMessages는 이미 아는 메시지와 겹치면 아무것도 안 하는 안전한 호출이다.
      if (_hasConnectedBefore && _selectedRoom != null) {
        backfillMissedMessages(_selectedRoom!.id);
      }
      return;
    }
    print('[ChatProvider] 앱 복귀 — 소켓이 죽어 있어 바로 다시 붙는다');
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    connectWebSocket();
  }

  /// [insertPendingFileMessage]로 띄워둔 버블을, 업로드를 시도조차 하지 못한
  /// 경우(예: 동영상 압축 실패 + 용량 초과로 건너뜀)에 실패 상태로 바꾼다.
  void markPendingFileMessageFailed(String localId) {
    _updatePendingMessageStatus(localId, MessageSendingStatus.failed);
  }

  void _updatePendingMessageStatus(
    String localId,
    MessageSendingStatus status,
  ) {
    final index = _messages.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(sendingStatus: status);
      notifyListeners();
    }
  }

  void _replacePendingMessage(String localId, ChatMessage newMessage) {
    final index = _messages.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      _messages[index] = newMessage.copyWith(
        sendingStatus: MessageSendingStatus.sent,
      );
      notifyListeners();
      return;
    }
    // 말풍선이 없다(그 사이 목록을 다시 불러왔다). 지금 그 방이면 서버 메시지를 그대로 끼운다.
    if (_selectedRoom?.id == newMessage.chatRoomId &&
        !_messages.any((m) => m.id > 0 && m.id == newMessage.id)) {
      _messages.insert(0, newMessage);
      notifyListeners();
    }
  }

  // insertPendingFileMessage가 같은 밀리초 안에 여러 번 불려도(사진 여러 장을
  // 한 번에 고를 때) localId가 겹치지 않도록 붙이는 일련번호.
  int _pendingLocalIdSeq = 0;

  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];

  /// 파일 업로드를 시작하기 전, 화면에 바로 보일 "전송 중" 버블부터 만들어
  /// 목록 맨 앞에 끼워 넣고 그 localId를 돌려준다.
  ///
  /// 사진 여러 장을 한 번에 골라 동시 업로드할 때, 업로드는 동시 개수를
  /// 제한하더라도 버블만은 선택 즉시 전부 보이게 하기 위해
  /// [uploadPendingFileMessage]와 분리했다.
  String insertPendingFileMessage(
    int roomId,
    String fileName, {
    required String senderId,
    required String senderName,
  }) {
    final localId =
        'local_file_${DateTime.now().millisecondsSinceEpoch}_${_pendingLocalIdSeq++}';
    final isImage = _imageExtensions.any(
      (ext) => fileName.toLowerCase().endsWith('.$ext'),
    );

    final pendingMessage = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch, // 음수 임시 ID
      chatRoomId: roomId,
      senderId: senderId,
      senderName: senderName,
      type: isImage ? MessageType.image : MessageType.file,
      content: fileName,
      fileName: fileName,
      createdAt: DateTime.now(),
      sendingStatus: MessageSendingStatus.sending,
      localId: localId,
      clientMessageId: newClientMessageId(),
    );

    // 즉시 UI에 표시
    _messages.insert(0, pendingMessage);
    notifyListeners();

    return localId;
  }

  /// [insertPendingFileMessage]로 이미 목록에 끼워 넣은 버블의 실제 업로드를
  /// 수행한다. 성공하면 서버가 준 메시지로 교체하고, 실패하면 그 버블만
  /// 실패 상태로 바꾼다(다른 버블 전송에는 영향 없음).
  Future<bool> uploadPendingFileMessage(
    int roomId,
    File file, {
    required String localId,
    required String senderId,
    required String senderName,
    String? batchId,
    int? batchSize,
  }) async {
    final pending = _messages
        .cast<ChatMessage?>()
        .firstWhere((m) => m!.localId == localId, orElse: () => null);
    final entry = OutboxEntry(
      localId: localId,
      clientMessageId: pending?.clientMessageId ?? newClientMessageId(),
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      filePath: file.path,
      batchId: batchId,
      batchSize: batchSize,
      createdAt: pending?.createdAt ?? DateTime.now(),
    );
    // 파일은 언제나 REST다 — 실패하면 발신함에 남아 '다시 보내기'로 같은 식별자로 올라간다
    _outbox.expectAck(entry);
    return _sendViaRest(entry);
  }

  /// 파일 하나를 곧바로 만들고 업로드한다(버블을 미리 띄워둘 필요가 없는
  /// 단건 전송용). 여러 장을 동시 업로드하려면 [insertPendingFileMessage] +
  /// [uploadPendingFileMessage]를 따로 쓴다.
  Future<bool> sendFileMessage(
    int roomId,
    File file, {
    required String senderId,
    required String senderName,
    String? batchId,
    int? batchSize,
  }) async {
    final fileName = file.path.split('/').last;
    final localId = insertPendingFileMessage(
      roomId,
      fileName,
      senderId: senderId,
      senderName: senderName,
    );
    return uploadPendingFileMessage(
      roomId,
      file,
      localId: localId,
      senderId: senderId,
      senderName: senderName,
      batchId: batchId,
      batchSize: batchSize,
    );
  }

  Future<bool> deleteMessage(int roomId, int messageId) async {
    if (messageId <= 0) {
      // 아직 서버에 없는 말풍선 — 서버는 "메시지를 찾을 수 없습니다"로 답한다(운영 500)
      setError('아직 보내지지 않은 메시지입니다');
      return false;
    }
    try {
      final response = await ApiService().deleteChatMessage(
        roomId: roomId,
        messageId: messageId,
      );

      print('[ChatProvider] 메시지 삭제 응답: $response');

      // 메시지를 삭제됨 상태로 변경
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          isDeleted: true,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('[ChatProvider] 메시지 삭제 에러: $e');
      setError('메시지 삭제에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  Future<bool> editMessage(int roomId, int messageId, String content) async {
    if (messageId <= 0) {
      setError('아직 보내지지 않은 메시지입니다');
      return false;
    }
    try {
      final response = await ApiService().editChatMessage(
        roomId: roomId,
        messageId: messageId,
        content: content,
      );

      print('[ChatProvider] 메시지 수정 응답: $response');

      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final messageData = response['message'];
        if (messageData is Map<String, dynamic>) {
          _messages[messageIndex] = ChatMessage.fromJson(messageData);
        } else {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            content: content,
            editedAt: DateTime.now(),
          );
        }
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('[ChatProvider] 메시지 수정 에러: $e');
      setError('메시지 수정에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  // ===================== 공지 =====================

  void _applyRoomFromResponse(Map<String, dynamic> response, int roomId) {
    final roomData = response['room'];
    if (roomData is! Map<String, dynamic>) return;

    final updated = ChatRoom.fromJson(roomData);
    final index = _chatRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) _chatRooms[index] = updated;
    if (_selectedRoom?.id == roomId) _selectedRoom = updated;
    notifyListeners();
  }

  /// 메시지 하나를 방 상단에 고정한다.
  Future<bool> setNotice(int roomId, int messageId, String setByName) async {
    try {
      final response = await ApiService().setChatRoomNotice(
        roomId: roomId,
        messageId: messageId,
        setByName: setByName,
      );
      _applyRoomFromResponse(response, roomId);
      return true;
    } catch (e) {
      print('[ChatProvider] 공지 등록 에러: $e');
      setError('공지 등록에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  Future<bool> clearNotice(int roomId, String setByName) async {
    try {
      final response = await ApiService().clearChatRoomNotice(
        roomId: roomId,
        setByName: setByName,
      );
      _applyRoomFromResponse(response, roomId);
      return true;
    } catch (e) {
      print('[ChatProvider] 공지 해제 에러: $e');
      setError('공지를 내리지 못했습니다: ${e.toString()}');
      return false;
    }
  }

  // ===================== 대화 검색 =====================

  /// 검색 결과는 화면에서만 쓰므로 provider 상태로 들고 있지 않는다.
  Future<List<ChatMessage>> searchMessages(int roomId, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    try {
      final response = await ApiService().searchChatMessages(
        roomId: roomId,
        keyword: keyword.trim(),
      );
      final list = response['messages'] as List<dynamic>?;
      return (list ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[ChatProvider] 대화 검색 에러: $e');
      return [];
    }
  }

  // ===================== 날짜로 이동 =====================

  /// 그 날짜의 첫 메시지 id를 구한다.
  /// 그 날짜 이후 대화가 없으면(404) null을 돌려주고, 그 밖의 오류(형식 오류,
  /// 비참가자 등)는 ApiException 그대로 던져 화면에서 사정을 보여주게 한다 —
  /// 조용히 실패시키지 않는다.
  Future<int?> findFirstMessageIdOnDate(
    int roomId,
    DateTime date, {
    String? userId,
  }) async {
    try {
      final response = await ApiService().getFirstMessageOnDate(
        roomId: roomId,
        date: formatChatDateQuery(date),
        userId: userId,
      );
      return response['messageId'] as int?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ===================== 읽음 처리 =====================

  Future<void> markAsRead(
    int roomId,
    int lastMessageId, {
    required String userId,
    required String userName,
  }) async {
    try {
      // 읽음은 REST로 반드시 남긴다. 전에는 소켓이 붙어 있으면 소켓으로만 보냈는데,
      // 조용히 죽은 소켓에 보낸 읽음은 서버에 닿지 않아 "읽었는데 숫자가 안 사라진다"가 됐다.
      // 소켓은 다른 사람 화면의 읽음 표시를 바로 갱신하는 용도로 덧붙여 보낸다.
      await ApiService().markChatAsRead(
        roomId: roomId,
        lastMessageId: lastMessageId,
        userId: userId,
        userName: userName,
      );
      if (_isConnected) {
        sendReadStatus(
          roomId,
          lastMessageId,
          userId: userId,
          userName: userName,
        );
      }

      // 로컬 안읽은 수 초기화
      final roomIndex = _chatRooms.indexWhere((r) => r.id == roomId);
      if (roomIndex != -1) {
        _chatRooms[roomIndex] = _chatRooms[roomIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      print('[ChatProvider] 읽음 처리 에러: $e');
    }
  }

  Future<void> loadMessageReaders(int roomId, int messageId) async {
    try {
      final response = await ApiService().getChatMessageReaders(
        roomId: roomId,
        messageId: messageId,
      );

      print('[ChatProvider] 읽은 사람 목록 응답: $response');

      if (response['readers'] != null) {
        final List<dynamic> content = response['readers'] as List<dynamic>;
        _messageReaders = content
            .map(
              (json) =>
                  ChatMessageReader.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        _messageReaders = [];
      }

      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 읽은 사람 목록 로드 에러: $e');
    }
  }

  void clearMessageReaders() {
    _messageReaders = [];
    notifyListeners();
  }

  // ===================== 리액션 =====================

  /// 메시지 리액션 로컬 업데이트
  void updateMessageReactions(int messageId, List<ReactionSummary> reactions) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(reactions: reactions);
      notifyListeners();
    }
  }

  // ===================== 공유 미디어 =====================

  Future<void> loadSharedMedia(int roomId, {String? type}) async {
    try {
      final response = await ApiService().getChatSharedMedia(
        roomId: roomId,
        type: type,
      );

      print('[ChatProvider] 공유 미디어 응답: $response');

      if (response['files'] != null) {
        final List<dynamic> content = response['files'] as List<dynamic>;
        _sharedMedia = content
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _sharedMedia = [];
      }

      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 공유 미디어 로드 에러: $e');
    }
  }

  void clearSharedMedia() {
    _sharedMedia = [];
    notifyListeners();
  }

  // ===================== 상태 초기화 =====================

  void reset() {
    disconnectWebSocket();
    _cancelAllTypingTimers();
    _cancelAllAckTimers();
    _roomListRefreshDebounce?.cancel();
    _isWatchingRoomList = false;
    _chatRooms = [];
    _selectedRoom = null;
    _messages = [];
    _participants = [];
    _messageReaders = [];
    _sharedMedia = [];
    _isLoading = false;
    _errorMessage = '';
    _isConnected = false;
    _typingUsers = {};
    _onlineUserIds = {};
    _presenceSubscription = null;
    _companyId = null;
    _currentPage = 0;
    _totalPages = 0;
    _hasMoreMessages = true;
    _isLoadingOlderMessages = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _roomListRefreshDebounce?.cancel();
    _cancelAllTypingTimers();
    // 소켓을 안 끊고 dispose하면 STOMP 콜백이 dispose된 provider에 대고
    // notifyListeners()를 불러 크래시로 이어질 수 있다.
    disconnectWebSocket();
    super.dispose();
  }
}

/// 발신함의 실패 목록을 shared_preferences 한 칸에 둔다.
class _PrefsOutboxStore implements OutboxStore {
  static const _key = 'chat_outbox_failed';

  @override
  String? read() => StorageService().getString(_key);

  @override
  Future<void> write(String json) => StorageService().saveString(_key, json);
}
