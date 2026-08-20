import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasMoreMessages = true;

  // WebSocket
  StompClient? _stompClient;
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
  Set<String> get typingUsers => _typingUsers;
  bool get hasMoreMessages => _hasMoreMessages;
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

    try {
      final token = StorageService().getToken();
      if (token == null) {
        print('[ChatProvider] 토큰이 없어 WebSocket 연결 불가');
        return;
      }

      final wsUrl = 'wss://silverithm.site/ws/chat';

      _stompClient = StompClient(
        config: StompConfig(
          url: wsUrl,
          onConnect: _onConnect,
          onDisconnect: _onDisconnect,
          onStompError: _onStompError,
          onWebSocketError: _onWebSocketError,
          stompConnectHeaders: {'Authorization': 'Bearer $token'},
          webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
          heartbeatOutgoing: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
          reconnectDelay: const Duration(seconds: 5),
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
    print('[ChatProvider] WebSocket 연결 성공');
    _isConnected = true;
    _typingUsers.clear();
    _cancelAllTypingTimers();
    notifyListeners();

    // 현재 선택된 채팅방이 있으면 구독
    if (_selectedRoom != null) {
      _subscribeToRoom(_selectedRoom!.id);
    }

    // 목록 화면을 보고 있었다면 재연결 시 전체 방 구독을 복원한다
    _syncRoomListSubscriptions();

    _registerPresence();
  }

  void _onDisconnect(StompFrame frame) {
    print('[ChatProvider] WebSocket 연결 해제');
    _isConnected = false;
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
    notifyListeners();
  }

  void _onWebSocketError(dynamic error) {
    print('[ChatProvider] WebSocket 에러: $error');
    _isConnected = false;
    notifyListeners();
  }

  void disconnectWebSocket() {
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
      _isConnected = false;
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

        // 내가 보낸 pending 메시지가 있는지 확인 (같은 content, sender)
        final pendingIndex = _messages.indexWhere(
          (m) =>
              m.sendingStatus == MessageSendingStatus.sending &&
              m.senderId == message!.senderId &&
              m.content == message.content,
        );

        if (pendingIndex != -1) {
          // pending 메시지를 서버 메시지로 교체
          _messages[pendingIndex] = message.copyWith(
            sendingStatus: MessageSendingStatus.sent,
          );
          notifyListeners();
        } else {
          // 최근에 같은 내용의 메시지를 보냈는지 확인 (중복 방지)
          final recentDuplicate = _messages.any(
            (m) =>
                m.senderId == message!.senderId &&
                m.content == message.content &&
                m.createdAt.difference(message.createdAt).abs().inSeconds < 5,
          );

          if (!recentDuplicate) {
            // 새 메시지 추가
            _messages.insert(0, message);
            notifyListeners();
          }
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
    try {
      if (refresh) {
        _currentPage = 0;
        _messages.clear();
        _hasMoreMessages = true;
      }

      if (!_hasMoreMessages && !refresh) return;

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
          _messages.addAll(newMessages);
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
          _messages.addAll(newMessages);
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

      print('[ChatProvider] 로드된 메시지 수: ${_messages.length}');
      notifyListeners();
    } catch (e) {
      print('[ChatProvider] 메시지 목록 로드 에러: $e');
      setError('메시지를 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  Future<bool> sendTextMessage(
    int roomId,
    String content, {
    required String senderId,
    required String senderName,
  }) async {
    // 로컬 임시 ID 생성
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    // 임시 메시지 생성 (전송 중 상태)
    final pendingMessage = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch, // 음수 임시 ID
      chatRoomId: roomId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.text,
      content: content,
      createdAt: DateTime.now(),
      readCount: 1, // 발신자 본인은 이미 읽음
      sendingStatus: MessageSendingStatus.sending,
      localId: localId,
    );

    // 즉시 UI에 표시
    _messages.insert(0, pendingMessage);
    notifyListeners();

    try {
      // WebSocket이 연결되어 있으면 WebSocket으로 전송
      if (_isConnected) {
        sendMessageViaWebSocket(
          roomId,
          content,
          senderId: senderId,
          senderName: senderName,
        );
        // WebSocket 응답이 올 때까지 sending 상태 유지 (중복 방지를 위해)
        // _handleIncomingMessage에서 pending 메시지를 찾아서 교체함
        return true;
      }

      // HTTP fallback
      final response = await ApiService().sendChatMessage(
        roomId: roomId,
        content: content,
        type: 'TEXT',
        senderId: senderId,
        senderName: senderName,
      );

      print('[ChatProvider] 메시지 전송 응답: $response');

      final messageData = response['message'] ?? response;
      final newMessage = ChatMessage.fromJson(
        messageData as Map<String, dynamic>,
      );

      // 임시 메시지를 실제 메시지로 교체
      _replacePendingMessage(localId, newMessage);

      return true;
    } catch (e) {
      print('[ChatProvider] 메시지 전송 에러: $e');
      // 전송 실패 상태로 변경
      _updatePendingMessageStatus(localId, MessageSendingStatus.failed);
      setError('메시지 전송에 실패했습니다: ${e.toString()}');
      return false;
    }
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
    }
  }

  Future<bool> sendFileMessage(
    int roomId,
    File file, {
    required String senderId,
    required String senderName,
  }) async {
    // 로컬 임시 ID 생성
    final localId = 'local_file_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = file.path.split('/').last;
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
    ].any((ext) => fileName.toLowerCase().endsWith('.$ext'));

    // 임시 메시지 생성 (전송 중 상태)
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
    );

    // 즉시 UI에 표시
    _messages.insert(0, pendingMessage);
    notifyListeners();

    try {
      final response = await ApiService().uploadChatFile(
        roomId: roomId,
        file: file,
        senderId: senderId,
        senderName: senderName,
      );

      print('[ChatProvider] 파일 업로드 응답: $response');

      final messageData = response['message'] ?? response;
      final newMessage = ChatMessage.fromJson(
        messageData as Map<String, dynamic>,
      );

      // 임시 메시지를 실제 메시지로 교체
      _replacePendingMessage(localId, newMessage);

      return true;
    } catch (e) {
      print('[ChatProvider] 파일 전송 에러: $e');
      // 전송 실패 상태로 변경
      _updatePendingMessageStatus(localId, MessageSendingStatus.failed);
      setError('파일 전송에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deleteMessage(int roomId, int messageId) async {
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

  // ===================== 읽음 처리 =====================

  Future<void> markAsRead(
    int roomId,
    int lastMessageId, {
    required String userId,
    required String userName,
  }) async {
    try {
      // WebSocket 연결 시 WebSocket으로, 아니면 HTTP로 전송 (이중 전송 방지)
      if (_isConnected) {
        sendReadStatus(
          roomId,
          lastMessageId,
          userId: userId,
          userName: userName,
        );
      } else {
        await ApiService().markChatAsRead(
          roomId: roomId,
          lastMessageId: lastMessageId,
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
    notifyListeners();
  }

  @override
  void dispose() {
    _roomListRefreshDebounce?.cancel();
    _cancelAllTypingTimers();
    // 소켓을 안 끊고 dispose하면 STOMP 콜백이 dispose된 provider에 대고
    // notifyListeners()를 불러 크래시로 이어질 수 있다.
    disconnectWebSocket();
    super.dispose();
  }
}
