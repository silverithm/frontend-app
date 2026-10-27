import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:dio/dio.dart' as dio;
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/schedule_colors.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../utils/message_links.dart';
import '../utils/chat_date_jump.dart';
import '../utils/chat_time_format.dart';
import '../utils/file_download_open.dart';
import '../utils/chat_image_url.dart';
import '../utils/chat_media.dart' as chat_media;
import '../utils/chat_message_grouping.dart';
import '../utils/chat_message_pagination.dart';
import '../utils/korean_keep_all.dart';
import 'chat_room_info_screen.dart';
import 'document_viewer_screen.dart';
import 'hwp_editor_screen.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';
import '../widgets/chat/chat_bubble_layout.dart';
import '../widgets/chat/chat_file_card.dart';
import '../widgets/chat/chat_image_viewer.dart';
import '../widgets/chat/chat_photo.dart';
import '../widgets/chat/chat_photo_group.dart';
import '../widgets/chat/chat_sender_header.dart';
import '../widgets/common/app_action_sheet.dart';

enum _ChatRoomMenuAction { info, search, files, leave, delete }

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _isTyping = false;

  /// 끊긴 배너의 "30초 넘게 못 붙었다" 문구를 위한 재확인 시계.
  /// isConnected 자체는 바뀌지 않아도 시간만 흘러 문구가 바뀌어야 하므로 따로 둔다.
  Timer? _connectionWatchTimer;

  // @멘션 — 입력 중인 '@뒤 글자'와 후보 목록
  String? _mentionQuery;
  List<ChatParticipant> _mentionCandidates = [];

  // 메시지 수정 중이면 그 메시지, 아니면 null(일반 전송 모드)
  ChatMessage? _editingMessage;
  /// 답장 대상. 수정과 마찬가지로 입력창 위에 원문 미리보기를 띄운다.
  ChatMessage? _replyingTo;

  // dispose 안전을 위해 provider 캐시
  late final ChatProvider _chatProvider;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    // 재연결 후 대화가 많이 밀렸을 때 목록을 갈아끼워도 되는지(맨 아래를 보고 있는지) 알려 준다
    _chatProvider.viewerNearBottom = _viewerNearBottom;
    _authProvider = context.read<AuthProvider>();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMessages();
      _markAsRead();
      // 메시지 발신자 아바타 표시용 참가자 정보 로드
      _chatProvider.loadParticipants(widget.room.id);
    });

    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);

    // 끊김 배너의 "30초 넘게" 문구가 시간에 맞춰 바뀌도록 가볍게 다시 그린다.
    // isConnected 자체는 이 방에서 바꾸지 않으므로 setState만 한다.
    _connectionWatchTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_chatProvider.isConnected) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // 화면이 꺼졌다 돌아왔을 때 — 소켓 하트비트가 아직 끊김을 알아채기 전이라도
    // 지금 열어 둔 이 방에서 놓친 메시지가 없는지 바로 확인한다. ensureConnected는
    // 소켓이 죽어 있으면 재연결도 함께 한다(main_screen의 전역 처리와 같은 호출이지만,
    // 여기서는 '지금 보고 있는 방'을 확실히 채워 두려고 이 화면에서도 직접 건다).
    _chatProvider.ensureConnected();
  }

  // --- 스크롤 중 날짜 배지 ---------------------------------------------------
  //
  // 위로 한참 올렸을 때 "지금 보는 게 며칠 대화인지" 알려주는 떠 있는 알약.
  // 날짜 문구는 구분선과 **같은** `formatDateSeparatorLabel`을 쓴다 —
  // 규칙이 두 벌이 되면 언젠가 서로 어긋난다. [[chat_message_grouping]]

  /// 지금 띄우고 있는 문구 (null이면 안 보인다)
  String? _scrollDateLabel;

  /// 멈추면 사라지게 하는 타이머
  Timer? _dateBadgeHideTimer;

  /// 메시지 자리마다 붙이는 키 — 화면 맨 위 항목이 무엇인지 재는 데 쓴다.
  /// ListView는 화면 밖 항목을 만들지 않으므로, 웹처럼 '지나간 구분선'을
  /// 읽는 방법이 통하지 않는다. 그래서 보이는 항목을 직접 잰다.
  final Map<String, GlobalKey> _messageProbeKeys = {};

  /// 목록 영역 — 화면 위 경계를 재는 기준
  final GlobalKey _messageListAreaKey = GlobalKey();

  GlobalKey _probeKeyFor(String id) =>
      _messageProbeKeys.putIfAbsent(id, () => GlobalKey());

  /// 답장 인용문을 눌러 찾아온 메시지 — 잠깐 배경으로 알려 준다
  int? _highlightedMessageId;

  /// 인용된 원본으로 데려간다 (카톡과 같은 동작).
  ///
  /// 원본이 아직 안 불러온 옛 대화에 있을 수 있어, 몇 쪽까지는 더 받아 보며 찾는다.
  /// 그래도 못 찾으면 말없이 가만있지 않고 사정을 알린다.
  Future<void> _jumpToRepliedMessage(int replyToId) async {
    final ok = await _jumpToMessage(replyToId);
    if (!ok && mounted) {
      AppSnackBar.showInfo(context, message: '원본이 너무 오래된 대화에 있어 찾지 못했습니다');
    }
  }

  /// [replyToId]를 [_jumpToRepliedMessage]가 재사용하고, 날짜로 이동
  /// ([_jumpToDate])도 같은 경로를 쓴다 — 목록에 없으면 옛 대화를 몇 쪽 더
  /// 받아 찾고, 도착하면 잠깐 배경을 강조한다. 찾았는지 여부만 돌려주고
  /// 못 찾았을 때 보여줄 안내는 호출한 쪽의 문맥에 맞게 각자 띄운다.
  ///
  /// [onLoadProgress]는 옛 대화를 더 받는 동안 매 시도마다 불린다 (진행 표시용).
  Future<bool> _jumpToMessage(
    int targetId, {
    int maxTries = 5,
    void Function(int triesSoFar)? onLoadProgress,
    bool Function()? isCancelled,
  }) async {
    final provider = context.read<ChatProvider>();

    int indexOf() => provider.messages.indexWhere((m) => m.id == targetId);

    var found = indexOf() >= 0;
    var tries = 0;
    while (shouldKeepLoadingForDateJump(
      found: found,
      hasMore: provider.hasMoreMessages,
      triesSoFar: tries,
      maxTries: maxTries,
    )) {
      await provider.loadMessages(roomId: widget.room.id);
      if (!mounted || (isCancelled?.call() ?? false)) return false;
      found = indexOf() >= 0;
      tries++;
      onLoadProgress?.call(tries);
    }

    if (!found) return false;

    await _scrollToProbe('id:$targetId');
    if (!mounted) return true;

    setState(() => _highlightedMessageId = targetId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
    return true;
  }

  /// 그 메시지 자리가 보일 때까지 한 화면씩 옮겨 가며 찾는다.
  ///
  /// 목록은 화면 밖 항목을 아예 만들지 않는다. 그래서 아직 안 그려진 메시지는
  /// 자리(키)도 없어 바로 데려갈 수 없다 — 조금씩 옮기며 그려지기를 기다린다.
  /// 목록이 거꾸로(최신이 아래) 그려지므로 오래된 쪽은 스크롤 값이 커지는 방향이다.
  Future<void> _scrollToProbe(String probeId) async {
    for (var attempt = 0; attempt < 15; attempt++) {
      final context = _messageProbeKeys[probeId]?.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          alignment: 0.4,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
        return;
      }

      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final next = (position.pixels + position.viewportDimension * 0.8)
          .clamp(0.0, position.maxScrollExtent);
      if (next <= position.pixels) return; // 더 갈 데가 없다
      await _scrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }
  }

  static String _probeIdOf(ChatMessage message) =>
      message.localId ?? 'id:${message.id}';

  /// 화면 맨 위에 걸친 메시지를 찾아 그 날짜를 배지로 띄운다.
  void _updateScrollDateBadge() {
    final areaBox =
        _messageListAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (areaBox == null || !areaBox.hasSize) return;
    final areaTop = areaBox.localToGlobal(Offset.zero).dy;

    ChatMessage? topmost;
    double? bestTop;
    for (final message in _chatProvider.messages) {
      final box = _messageProbeKeys[_probeIdOf(message)]
          ?.currentContext
          ?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      // 화면 위로 완전히 지나간 항목은 지금 보이는 것이 아니다
      if (top + box.size.height <= areaTop) continue;
      if (bestTop == null || top < bestTop) {
        bestTop = top;
        topmost = message;
      }
    }
    if (topmost == null) return;

    final label = formatDateSeparatorLabel(topmost.createdAt);
    if (_scrollDateLabel != label) {
      setState(() => _scrollDateLabel = label);
    }
    _dateBadgeHideTimer?.cancel();
    _dateBadgeHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _scrollDateLabel = null);
    });
  }

  /// 목록 위에 배지를 얹는다. 목록 자체는 그대로 두고 덧씌우기만 한다.
  Widget _withScrollDateBadge(Widget list) {
    return Stack(
      key: _messageListAreaKey,
      children: [
        list,
        Positioned(
          top: AppSpacing.space2,
          left: 0,
          right: 0,
          // 대화를 가리기만 할 뿐 눌리면 안 된다
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _scrollDateLabel == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3,
                    vertical: AppSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    // 날짜 구분선과 같은 알약 — 대화 위에 뜨므로 불투명하게 덮는다
                    color: AppSemanticColors.borderDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  ),
                  child: Text(
                    _scrollDateLabel ?? '',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_chatProvider.viewerNearBottom == _viewerNearBottom) {
      _chatProvider.viewerNearBottom = null;
    }
    _connectionWatchTimer?.cancel();
    _dateBadgeHideTimer?.cancel();
    // 타이핑 중이면 타이핑 중지 알림 전송
    if (_isTyping) {
      _chatProvider.sendTypingStatus(
        widget.room.id,
        false,
        userId: _authProvider.currentUser?.chatUserId ?? '',
        userName: _authProvider.currentUser?.name ?? '',
      );
    }
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadMessages(roomId: widget.room.id, refresh: true);
  }

  void _markAsRead() {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    // 맨 앞이 보내는 중인 내 말풍선이면 번호가 임시 음수다 — 서버에 있는 가장 최신 번호를 쓴다.
    // (음수로 읽음 처리하면 서버의 읽음 위치가 망가져 안읽음이 방 전체로 되살아났다)
    final messages = chatProvider.messages.where((m) => m.id > 0);
    if (messages.isNotEmpty) {
      chatProvider.markAsRead(
        widget.room.id,
        messages.first.id,
        userId: authProvider.currentUser?.chatUserId ?? '',
        userName: authProvider.currentUser?.name ?? '',
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final chatProvider = context.read<ChatProvider>();

    // 지금 화면 맨 위가 며칠 대화인지 알려주는 떠 있는 배지
    _updateScrollDateBadge();

    // 목록은 reverse라 pixels가 0이면 맨 아래(최신)다. 한 화면 절반쯤 올라가면 '맨 아래로'를 띄운다.
    final away = _scrollController.position.pixels >
        math.max(240.0, _scrollController.position.viewportDimension * 0.5);
    if (away != _showJumpToBottom) {
      setState(() => _showJumpToBottom = away);
    }

    // 목록이 reverse:true라 maxScrollExtent 쪽이 가장 오래된 끝이다.
    // 판단 자체는 순수 함수로 빼서 단위 테스트로 고정해 뒀다
    // (test/chat_message_pagination_test.dart).
    //
    // 막는 조건으로 provider 전체의 isLoading이 아니라 옛 대화 전용 플래그를
    // 쓴다 — isLoading은 방 목록 조회도 함께 켜기 때문에, 그걸 보면 마침
    // 목록이 갱신되는 순간의 스크롤이 통째로 무시된다.
    if (shouldLoadOlderMessages(
      pixels: _scrollController.position.pixels,
      maxScrollExtent: _scrollController.position.maxScrollExtent,
      hasMore: chatProvider.hasMoreMessages,
      isLoadingOlder: chatProvider.isLoadingOlderMessages,
    )) {
      chatProvider.loadMessages(roomId: widget.room.id);
    }
  }

  void _onTextChanged() {
    _updateMentionCandidates();

    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final hasText = _messageController.text.trim().isNotEmpty;
    final userId = authProvider.currentUser?.chatUserId ?? '';
    final userName = authProvider.currentUser?.name ?? '';

    if (hasText && !_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(
        widget.room.id,
        true,
        userId: userId,
        userName: userName,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        chatProvider.sendTypingStatus(
          widget.room.id,
          false,
          userId: userId,
          userName: userName,
        );
      }
    });
  }

  // ===================== @멘션 =====================

  /// 커서 앞의 '@…'를 찾아 후보를 추린다. 공백이 들어오면 멘션 입력이 끝난 것으로 본다.
  void _updateMentionCandidates() {
    final selection = _messageController.selection;
    final text = _messageController.text;
    final cursor = selection.baseOffset;

    if (cursor < 0 || cursor > text.length) {
      _setMentionQuery(null);
      return;
    }

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) {
      _setMentionQuery(null);
      return;
    }

    // '@' 바로 앞은 줄머리이거나 공백이어야 멘션으로 본다 (이메일 주소 오인 방지)
    if (atIndex > 0 && !RegExp(r'\s').hasMatch(before[atIndex - 1])) {
      _setMentionQuery(null);
      return;
    }

    final query = before.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n')) {
      _setMentionQuery(null);
      return;
    }

    _setMentionQuery(query);
  }

  void _setMentionQuery(String? query) {
    if (query == null) {
      if (_mentionQuery != null) {
        setState(() {
          _mentionQuery = null;
          _mentionCandidates = [];
        });
      }
      return;
    }

    final myId = context.read<AuthProvider>().currentUser?.chatUserId;
    final participants = context.read<ChatProvider>().participants;
    final lower = query.toLowerCase();

    final candidates = participants
        .where((p) => p.userId != myId)
        .where((p) => query.isEmpty || p.userName.toLowerCase().contains(lower))
        .take(5)
        .toList();

    setState(() {
      _mentionQuery = query;
      _mentionCandidates = candidates;
    });
  }

  /// 후보를 고르면 '@이름 '으로 바꿔 넣고 커서를 뒤로 옮긴다.
  void _applyMention(ChatParticipant participant) {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) return;

    final replacement = '@${participant.userName} ';
    final newText = text.replaceRange(atIndex, cursor, replacement);
    final newCursor = atIndex + replacement.length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _mentionQuery = null;
      _mentionCandidates = [];
    });
  }

  Widget _buildMentionSuggestions() {
    if (_mentionQuery == null || _mentionCandidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          top: BorderSide(color: AppSemanticColors.borderSubtle, width: 1),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionCandidates.length,
        itemBuilder: (context, index) {
          final participant = _mentionCandidates[index];
          return SeedListCell(
            leading: SeedAvatar(
              name: participant.userName,
              imageUrl: participant.profileImageUrl,
              size: SeedAvatarSize.small,
            ),
            title: participant.userName,
            showChevron: false,
            onTap: () => _applyMention(participant),
          );
        },
      ),
    );
  }

  /// 롱프레스 메뉴에서 '수정'을 고르면 입력창을 그 메시지의 수정 모드로 바꾼다.
  void _startEditing(ChatMessage message) {
    final chatProvider = context.read<ChatProvider>();
    setState(() {
      _editingMessage = message;
    });

    final text = message.content ?? '';
    // 프로그램적으로 텍스트를 채우면 _onTextChanged가 함께 발동한다
    // (@멘션 삽입 코드와 동일한 방식으로 처리).
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();

    // 수정 중엔 타이핑 상태를 굳이 올리지 않는다.
    if (_isTyping) {
      _isTyping = false;
      final authProvider = context.read<AuthProvider>();
      chatProvider.sendTypingStatus(
        widget.room.id,
        false,
        userId: authProvider.currentUser?.chatUserId ?? '',
        userName: authProvider.currentUser?.name ?? '',
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    _messageController.clear();
  }

  /// 롱프레스 메뉴에서 '답장'을 고르면 입력창 위에 원문 미리보기를 띄운다.
  /// 수정 중이었다면 그쪽을 접는다 — 둘을 동시에 할 수는 없다.
  void _startReplying(ChatMessage message) {
    setState(() {
      _editingMessage = null;
      _replyingTo = message;
    });
    _focusNode.requestFocus();
  }

  void _cancelReplying() {
    setState(() {
      _replyingTo = null;
    });
  }

  /// 답장 미리보기에 보여줄 한 줄 — 사진·동영상·파일은 글자가 없으므로 종류로 대신한다.
  /// 모델이 이미 같은 판단을 하고 있으므로(displayContent) 그것을 그대로 쓴다.
  String _replyPreviewText(ChatMessage message) => message.displayContent;

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      final original = (editing.content ?? '').trim();
      if (content.isEmpty || content == original) {
        _cancelEditing();
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      await chatProvider.editMessage(widget.room.id, editing.id, content);
      _messageController.clear();
      _cancelEditing();
      return;
    }

    if (content.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.chatUserId ?? '';
    final userName = authProvider.currentUser?.name ?? '';
    _messageController.clear();

    // 타이핑 상태 해제
    if (_isTyping) {
      _isTyping = false;
      chatProvider.sendTypingStatus(
        widget.room.id,
        false,
        userId: userId,
        userName: userName,
      );
    }

    final replyTarget = _replyingTo;
    if (replyTarget != null) _cancelReplying();

    await chatProvider.sendTextMessage(
      widget.room.id,
      content,
      senderId: userId,
      senderName: userName,
      replyTo: replyTarget,
    );

    // 스크롤을 맨 아래로
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppTransitions.normal,
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentOptions() {
    // 길게 누르기·더보기와 같은 시트 하나를 쓴다(줄 높이·아이콘·글자가 시트마다 달랐다).
    showAppActionSheet(
      context,
      actions: [
        AppSheetAction(
          icon: Icons.photo_library_outlined,
          label: '사진·동영상',
          description: '갤러리에서 사진·동영상 선택',
          onSelected: _pickAndSendPhoto,
        ),
        AppSheetAction(
          icon: Icons.insert_drive_file_outlined,
          label: '파일',
          description: '문서, PDF 등 파일 선택',
          onSelected: _pickAndSendFile,
        ),
      ],
    );
  }

  // 위에서부터 채우는 분기를 쓸 최대 메시지 수.
  //
  // 그 분기는 항목을 한 번에 다 만든다(ListView.builder의 지연 생성이 없다).
  // 그래서 상한이 필요하다 — 옛 대화를 끝까지 불러온 방은 hasMore가 false라도
  // 수백 건일 수 있고, 그걸 통째로 만들면 느려진다.
  // 한 화면에 들어가는 말풍선은 많아야 스무 개 남짓이라, 40이면 "화면보다
  // 짧을 수 있는" 경우를 모두 덮으면서 만드는 비용은 무시할 만하다.
  static const int _topAlignMaxMessages = 40;

  // 시각·읽음 표시 열이 실제로 차지하는 대략적 폭("오후 12:34" 기준).
  // 말풍선 최대 폭을 계산할 때 미리 빼두는 용도다.
  static const double _metaColumnWidth = 60;

  // 말풍선 최대 폭. 화면의 70%를 기본으로 하되, 좌우 고정 요소(목록 좌우 패딩,
  // 아바타 열, 사이 여백, 시각 열)를 뺀 실제 여유 폭을 넘지 않게 한다.
  // 이미지 자리표시자가 이 값을 그대로 쓰므로 넘치면 오버플로가 난다.
  //
  // 내 말풍선은 아바타 열이 없어서 남보다 넓게 쓴다 — 같은 폭으로 묶어 두면 쓸데없이
  // 좁아 "요" 한 글자가 둘째 줄에 남는 일이 늘었다(R1-21).
  double _bubbleMaxWidth(BuildContext context, {bool isMine = false}) {
    final width = MediaQuery.of(context).size.width;
    if (isMine) {
      const reservedMine =
          AppSpacing.space4 * 2 + // ListView 좌우 패딩
          AppSpacing.space1 + // 말풍선과 시각 열 사이
          _metaColumnWidth;
      return math.min(width * 0.78, width - reservedMine);
    }
    const reserved =
        AppSpacing.space4 * 2 + // ListView 좌우 패딩
        AppSpacing.space1 + // 아바타 앞 여백
        ChatAvatarSlot.width +
        AppSpacing.space2 + // 아바타와 본문 사이
        AppSpacing.space1 + // 말풍선과 시각 열 사이
        _metaColumnWidth;
    return math.min(width * 0.7, width - reserved);
  }

  // 10MB 상수 (바이트) — 사진·문서
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB
  // 동영상은 압축을 거치므로 좀 더 넉넉하게 허용 (압축 실패 시 원본 기준)
  static const int _maxVideoFileSize = 100 * 1024 * 1024; // 100MB

  // 사진 여러 장을 고를 때 실제 업로드(네트워크)는 한 번에 이만큼만 동시에
  // 내보낸다. 현장 회선이 좁아 전부 동시에 밀면 오히려 느려지고 타임아웃 난다.
  static const int _maxConcurrentUploads = 3;

  // 동영상 확장자 목록은 utils/chat_media.dart 한 곳에만 둔다 —
  // 모델(ChatMessage.mediaKind)과 화면이 같은 기준으로 판정해야 하기 때문이다.
  bool _isVideoFileName(String fileName) {
    return chat_media.isVideoFileName(fileName);
  }

  // JPEG로 바꾸면 안 되는 이미지 포맷 — 원본 그대로 올린다.
  //
  //  - gif: 변환하면 움직임이 사라진다.
  //  - png: 투명 배경이 검게 칠해진다. 이건 되돌릴 수 없는 손실인데,
  //         서버가 PNG를 이미 제대로 처리하고 어디서나 보이므로
  //         변환해서 얻을 것이 없다.
  //
  // 기본값은 어디까지나 '변환'이다 — 목록에 없는 포맷(새로 나오는 것 포함)은
  // 전부 JPEG로 정규화된다.
  static const Set<String> _keepAsIsImageExtensions = {'gif', 'png'};

  static String _fileExtension(String fileName) {
    return fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
  }

  /// 사진은 포맷과 무관하게 JPEG로 정규화해 올리므로(_prepareImageFile),
  /// "전송 중" 버블에 쓸 이름도 미리 .jpg로 맞춘다. 그래야 사진 버블로 뜨고,
  /// 서버가 확장자로 정하는 content-type도 image/jpeg가 된다.
  static String _plannedUploadFileName(String fileName) {
    if (_keepAsIsImageExtensions.contains(_fileExtension(fileName))) {
      return fileName;
    }
    final dot = fileName.lastIndexOf('.');
    return '${dot > 0 ? fileName.substring(0, dot) : fileName}.jpg';
  }

  /// 같은 이름의 사진을 동시에 여러 장 보내도 서로 덮어쓰지 않게 폴더를 가른다.
  static int _uploadWorkSeq = 0;

  /// 압축 결과를 담을 자리. **파일 이름은 원본을 물려받는다.**
  ///
  /// 업로드된 파일 이름이 그대로 파일 모아보기와 저장 파일 이름이 된다.
  /// 압축기가 붙인 임시 이름(compressed_1757….jpg)을 쓰면 그 이름이 대화 밖까지 따라 나온다.
  Future<String> _uploadWorkPath(String desiredName) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(
      '${tempDir.path}/carev_upload/'
      '${DateTime.now().microsecondsSinceEpoch}_${_uploadWorkSeq++}',
    );
    await dir.create(recursive: true);
    return '${dir.path}/$desiredName';
  }

  // video_compress는 네이티브 쪽 압축기가 한 번에 하나만 돌아간다
  // (동시에 부르면 StateError). 동영상 여러 개를 골라도 압축만은 순서대로
  // 한 개씩 처리되도록 이 체인으로 직렬화한다. 사진 압축·업로드는 이 제약이
  // 없으므로 그대로 동시 처리된다.
  Future<void> _videoCompressChain = Future.value();

  Future<T> _serializeVideoCompress<T>(Future<T> Function() action) {
    final result = _videoCompressChain.then((_) => action());
    _videoCompressChain = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// [items]를 최대 [limit]개씩 동시에 처리한다(작업자 풀 방식).
  Future<void> _runWithConcurrencyLimit<T>(
    List<T> items,
    int limit,
    Future<void> Function(T item) action,
  ) async {
    final iterator = items.iterator;

    Future<void> worker() async {
      while (iterator.moveNext()) {
        await action(iterator.current);
      }
    }

    await Future.wait(List.generate(limit, (_) => worker()));
  }

  /// 갤러리에서 사진·동영상을 여러 개 골라 한 번에 보낸다.
  /// 고르는 즉시 전부 "전송 중" 버블부터 띄우고, 실제 업로드(네트워크)만
  /// [_maxConcurrentUploads]개씩 동시에 내보낸다. 한 개가 실패해도 나머지는
  /// 계속 전송되고, 실패한 것만 따로 알린다.
  Future<void> _pickAndSendPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultipleMedia();

      if (picked.isEmpty) return;

      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      final senderId = authProvider.currentUser?.chatUserId ?? '';
      final senderName = authProvider.currentUser?.name ?? '';

      if (picked.length > 1 && mounted) {
        AppSnackBar.showInfo(context, message: '${picked.length}개 전송 중...');
      }

      // 한 번의 동작으로 보낸 것이므로 알림도 한 번이어야 한다. 같은 묶음 표시를 달아
      // 보내면 서버가 마지막 장까지 올라온 뒤 "사진 5장" 알림을 한 번만 보낸다.
      final batchId = picked.length > 1
          ? '${DateTime.now().millisecondsSinceEpoch}-${widget.room.id}-photo'
          : null;
      final batchSize = picked.length > 1 ? picked.length : null;

      // 선택 즉시 전부 "전송 중" 버블을 띄운다 — 실제 업로드는 아래에서
      // 동시 개수를 제한해 진행하지만, 진행 상황은 버블로 바로 보인다.
      final pending = picked.map((xfile) {
        final isVideo = _isVideoFileName(xfile.name);
        final localId = chatProvider.insertPendingFileMessage(
          widget.room.id,
          isVideo ? xfile.name : _plannedUploadFileName(xfile.name),
          senderId: senderId,
          senderName: senderName,
        );
        return (xfile: xfile, localId: localId, isVideo: isVideo);
      }).toList();

      int successCount = 0;
      int failCount = 0;

      await _runWithConcurrencyLimit(pending, _maxConcurrentUploads, (item) async {
        final ok = await _prepareAndUploadMedia(
          item.xfile,
          localId: item.localId,
          isVideo: item.isVideo,
          senderId: senderId,
          senderName: senderName,
          batchId: batchId,
          batchSize: batchSize,
        );
        if (ok) {
          successCount++;
        } else {
          failCount++;
        }
      });

      if (picked.length > 1 && mounted) {
        if (failCount == 0) {
          AppSnackBar.showSuccess(context, message: '$successCount개 전송 완료');
        } else {
          AppSnackBar.showError(
            context,
            message: '전송 완료 $successCount개 / 실패 $failCount개',
          );
        }
      }
    } catch (e) {
      print('[ChatRoomScreen] 사진·동영상 선택 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '사진·동영상 선택에 실패했습니다: $e');
      }
    }
  }

  /// 이미 버블(localId)이 떠 있는 사진/동영상 한 개를 (필요하면 압축 후)
  /// 업로드한다. 성공하면 true. 실패해도 이 버블만 실패 상태가 되고
  /// 다른 버블 전송에는 영향을 주지 않는다.
  Future<bool> _prepareAndUploadMedia(
    XFile original, {
    required String localId,
    required bool isVideo,
    required String senderId,
    required String senderName,
    String? batchId,
    int? batchSize,
  }) async {
    final chatProvider = context.read<ChatProvider>();
    try {
      File file = File(original.path);
      final fileSize = await file.length();

      print(
        '[ChatRoomScreen] 선택된 파일: ${original.name}, 크기: ${_formatFileSize(fileSize)} ($fileSize bytes), video=$isVideo',
      );

      if (isVideo) {
        final prepared = await _prepareVideoFile(file, fileSize, original.name);
        if (prepared == null) {
          chatProvider.markPendingFileMessageFailed(localId);
          return false;
        }
        file = prepared;
      } else {
        final prepared = await _prepareImageFile(file, fileSize, original.name);
        if (prepared == null) {
          chatProvider.markPendingFileMessageFailed(localId);
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: '${original.name} 압축에 실패해 전송하지 못했습니다.',
            );
          }
          return false;
        }
        file = prepared.file;
        // 변환에 실패해 원본을 그대로 올리는 경우 — 조용히 넘어가지 않는다.
        if (prepared.warning != null && mounted) {
          AppSnackBar.showError(context, message: prepared.warning!);
        }
      }

      return await chatProvider.uploadPendingFileMessage(
        widget.room.id,
        file,
        localId: localId,
        senderId: senderId,
        senderName: senderName,
        batchId: batchId,
        batchSize: batchSize,
      );
    } catch (e) {
      print('[ChatRoomScreen] 사진·동영상 전송 에러: $e');
      chatProvider.markPendingFileMessageFailed(localId);
      return false;
    }
  }

  /// 동영상을 업로드 전에 720p 정도로 압축한다(보통 원본의 1/5~1/10).
  /// 압축에 실패하면 원본을 그대로 쓰되, 원본이 100MB를 넘으면 안내만 하고
  /// null을 돌려줘 이 파일만 건너뛴다. 압축은 한 번에 하나씩만 진행된다
  /// (video_compress 네이티브 제약).
  Future<File?> _prepareVideoFile(
    File file,
    int originalSize,
    String displayName,
  ) async {
    if (mounted) {
      AppSnackBar.showInfo(context, message: '$displayName 압축 중...');
    }

    try {
      final info = await _serializeVideoCompress(
        () => VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.Res1280x720Quality,
          deleteOrigin: false,
          includeAudio: true,
        ),
      );

      final compressedPath = info?.path;
      if (compressedPath != null) {
        final compressedFile = File(compressedPath);
        final compressedSize = await compressedFile.length();
        print(
          '[ChatRoomScreen] 동영상 압축 완료: ${_formatFileSize(originalSize)} → ${_formatFileSize(compressedSize)}',
        );
        // 사진과 같은 이유로 이름을 원본에서 물려받는다 — 압축기가 붙인 이름이
        // 파일 모아보기와 저장 파일 이름으로 그대로 새어 나간다. 출력은 항상 mp4다.
        final dot = displayName.lastIndexOf('.');
        final baseName = dot > 0 ? displayName.substring(0, dot) : displayName;
        try {
          return await compressedFile.rename(await _uploadWorkPath('$baseName.mp4'));
        } catch (e) {
          // 이름을 못 바꿔도 전송 자체를 막지는 않는다
          print('[ChatRoomScreen] 동영상 이름 정리 실패(무시): $e');
          return compressedFile;
        }
      }

      print('[ChatRoomScreen] 동영상 압축 실패, 원본으로 대체 시도: $displayName');
    } catch (e) {
      print('[ChatRoomScreen] 동영상 압축 에러: $e, 원본으로 대체 시도: $displayName');
    }

    // 압축 실패 — 원본이 100MB 이내면 원본을 그대로 올리고, 넘으면 건너뛴다
    if (originalSize <= _maxVideoFileSize) {
      return file;
    }

    if (mounted) {
      AppSnackBar.showError(
        context,
        message:
            '$displayName 압축에 실패했고 용량이 커서(${_formatFileSize(originalSize)}) 건너뛰었습니다.',
      );
    }
    return null;
  }

  /// 사진 한 장을 업로드할 수 있는 형태로 다듬는다 — **포맷과 무관하게
  /// JPEG로 정규화한다.**
  ///
  /// 현장에서는 아이폰 HEIC, 안드로이드 JPEG, 카톡 저장본, 화면 캡처(PNG),
  /// 스캔 앱 결과물(WEBP/TIFF 등)이 뒤섞여 들어온다. "HEIC만 변환"으로는
  /// 새 포맷이 나올 때마다 또 막히므로, 아예 올리기 전에 한 포맷으로
  /// 맞춰버린다. 파일 이름 확장자도 .jpg가 된다(서버가 확장자로
  /// content-type을 정한다).
  ///
  /// 예외는 GIF뿐이다 — JPEG로 바꾸면 움직임이 사라지고, GIF는 서버·브라우저
  /// 모두 표준 지원이라 원본 그대로 올려도 문제가 없다.
  ///
  /// 돌려주는 `warning`이 있으면 변환에 실패해 원본을 그대로 올린다는 뜻이다
  /// (호출부가 사용자에게 알린다 — 조용히 실패하지 않는 것이 요점이다).
  /// 아예 올릴 수 없으면 null을 돌려준다.
  ///
  /// 동영상은 이 경로를 타지 않는다(_prepareVideoFile / video_compress).
  Future<({File file, String? warning})?> _prepareImageFile(
    File file,
    int fileSize,
    String originalName,
  ) async {
    // GIF·PNG — 움직임과 투명 배경을 살리려고 원본 그대로 둔다.
    // 10MB를 넘으면 올릴 수 없다.
    if (_keepAsIsImageExtensions.contains(_fileExtension(originalName))) {
      if (fileSize > _maxFileSize) return null;
      return (file: file, warning: null);
    }

    print(
      '[ChatRoomScreen] 사진 JPEG 정규화: $originalName (${_formatFileSize(fileSize)})',
    );
    final converted = await _compressImage(file, fileSize, originalName);
    if (converted != null) {
      return (file: converted, warning: null);
    }

    // 변환 실패. 원본이라도 올려보되 반드시 알린다 —
    // 지금까지 "사진이 안 올라간다"의 정체가 이 조용한 실패였다.
    if (fileSize > _maxFileSize) return null;
    return (
      file: file,
      warning: '$originalName을(를) JPEG로 바꾸지 못해 원본 그대로 보냅니다. '
          '기기에 따라 사진이 안 보일 수 있습니다.',
    );
  }

  /// 이미지 압축 메서드 - 10MB 미만이 될 때까지 압축(출력은 항상 JPEG)
  Future<File?> _compressImage(
    File file,
    int originalSize,
    String originalName,
  ) async {
    try {
      final fileName = _plannedUploadFileName(originalName);
      final targetPath = await _uploadWorkPath(fileName);

      // 목표 크기: 9MB (여유분 확보)
      const int targetSize = 9 * 1024 * 1024;

      // 압축 품질 계산 (파일 크기에 따라 조절).
      // 10MB 이하(= 대부분의 사진, 정규화만 하는 경우)는 화질을 우선해 90.
      // 어르신 상태를 남기는 기록 사진이라 흐려지면 쓸모가 없어진다.
      int quality = 90;
      if (originalSize > 30 * 1024 * 1024) {
        quality = 40; // 30MB 초과: 품질 40%
      } else if (originalSize > 20 * 1024 * 1024) {
        quality = 50; // 20MB 초과: 품질 50%
      } else if (originalSize > 15 * 1024 * 1024) {
        quality = 60; // 15MB 초과: 품질 60%
      } else if (originalSize > 10 * 1024 * 1024) {
        quality = 70; // 10MB 초과: 품질 70%
      }

      print(
        '[ChatRoomScreen] 이미지 압축 시작: ${_formatFileSize(originalSize)}, 품질: $quality%',
      );

      // format을 명시해 어떤 입력 포맷(HEIC/PNG/WEBP/…)이 들어와도 결과는
      // 항상 JPEG가 되게 한다. minWidth/minHeight는 "짧은 변이 이보다
      // 작아지지 않게" 축소하는 값이라, 아이폰 12MP 사진(4032x3024)은
      // 2560x1920으로 줄어든다 — 눈으로 화질 저하를 느끼지 않으면서
      // 업로드는 크게 가벼워지는 선이다.
      XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1920,
        minHeight: 1920,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile == null) {
        print('[ChatRoomScreen] 압축 실패: compressedXFile is null');
        return null;
      }

      File compressedFile = File(compressedXFile.path);
      int compressedSize = await compressedFile.length();

      print('[ChatRoomScreen] 1차 압축 결과: ${_formatFileSize(compressedSize)}');

      // 여전히 10MB 초과시 추가 압축
      int attempts = 0;
      while (compressedSize > targetSize && quality > 20 && attempts < 5) {
        quality -= 15;
        attempts++;

        // 이름은 그대로 두고 자리만 새로 잡는다 — 이름이 바뀌면 압축 횟수가 밖으로 새어 나간다
        final recompressPath = await _uploadWorkPath(fileName);

        compressedXFile = await FlutterImageCompress.compressAndGetFile(
          compressedFile.path,
          recompressPath,
          quality: quality,
          minWidth: 1280,
          minHeight: 1280,
          format: CompressFormat.jpeg,
        );

        if (compressedXFile == null) break;

        compressedFile = File(compressedXFile.path);
        compressedSize = await compressedFile.length();

        print(
          '[ChatRoomScreen] ${attempts + 1}차 압축 결과: ${_formatFileSize(compressedSize)}, 품질: $quality%',
        );
      }

      // 최종 확인
      if (compressedSize > _maxFileSize) {
        print(
          '[ChatRoomScreen] 압축 후에도 10MB 초과: ${_formatFileSize(compressedSize)}',
        );
        return null;
      }

      return compressedFile;
    } catch (e) {
      print('[ChatRoomScreen] 이미지 압축 에러: $e');
      return null;
    }
  }

  /// 파일 크기 포맷팅
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 문서 파일을 여러 개 골라 한 번에 보낸다. 사진과 마찬가지로 각 파일은
  /// 독립된 버블로 올라가고, 한 개가 실패해도 나머지는 계속 전송한다.
  Future<void> _pickAndSendFile() async {
    try {
      // 문서 파일만 허용 (SAF API 사용 - 권한 불필요)
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );
      final List<XFile> results = await openFiles(
        acceptedTypeGroups: [typeGroup],
      );

      if (results.isEmpty) return;

      if (results.length > 1 && mounted) {
        AppSnackBar.showInfo(context, message: '파일 ${results.length}개 전송 중...');
      }

      // 사진과 같은 이유로, 한 번에 고른 문서도 알림은 한 번만 간다
      final batchId = results.length > 1
          ? '${DateTime.now().millisecondsSinceEpoch}-${widget.room.id}-doc'
          : null;
      final batchSize = results.length > 1 ? results.length : null;

      int successCount = 0;
      int failCount = 0;

      for (final result in results) {
        final ok = await _sendDocumentFile(result, batchId: batchId, batchSize: batchSize);
        if (ok) {
          successCount++;
        } else {
          failCount++;
        }
      }

      if (results.length > 1 && mounted) {
        if (failCount == 0) {
          AppSnackBar.showSuccess(context, message: '파일 $successCount개 전송 완료');
        } else {
          AppSnackBar.showError(
            context,
            message: '파일 전송 완료 $successCount개 / 실패 $failCount개',
          );
        }
      }
    } catch (e) {
      print('[ChatRoomScreen] 파일 선택 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '파일 선택에 실패했습니다: $e');
      }
    }
  }

  /// 문서 파일 하나를 전송한다. 성공하면 true.
  Future<bool> _sendDocumentFile(XFile result, {String? batchId, int? batchSize}) async {
    try {
      final file = File(result.path);
      final fileSize = await file.length();

      // 문서 파일은 10MB 초과시 업로드 불가
      if (fileSize > _maxFileSize) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message:
                '${result.name} 크기가 너무 큽니다 (${_formatFileSize(fileSize)}). 최대 10MB까지 업로드 가능합니다.',
          );
        }
        return false;
      }

      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      return await chatProvider.sendFileMessage(
        widget.room.id,
        file,
        senderId: authProvider.currentUser?.chatUserId ?? '',
        senderName: authProvider.currentUser?.name ?? '',
        batchId: batchId,
        batchSize: batchSize,
      );
    } catch (e) {
      print('[ChatRoomScreen] 파일 전송 에러: $e');
      return false;
    }
  }

  Future<void> _showRoomInfo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomInfoScreen(room: widget.room)),
    );
    // 정보 화면에서 이름을 바꿨을 수 있다 — 제목을 다시 그린다
    if (mounted) setState(() {});
  }

  /// 방 이름 — 정보 화면에서 바꾸면 목록(ChatProvider)에 먼저 반영되므로 그쪽을 따른다
  String get _roomName {
    for (final room in context.read<ChatProvider>().chatRooms) {
      if (room.id == widget.room.id) return room.name;
    }
    return widget.room.name;
  }

  /// 최신 방 정보(ChatProvider)의 인원 수. 없으면 진입 시점 값.
  int _participantCountOf(ChatProvider provider) {
    for (final room in provider.chatRooms) {
      if (room.id == widget.room.id) return room.participantCount;
    }
    return widget.room.participantCount;
  }

  bool _appBarTitleCentered(BuildContext context) {
    final themed = Theme.of(context).appBarTheme.centerTitle;
    if (themed != null) return themed;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  Future<void> _confirmDeleteChatRoom() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '채팅방 삭제',
      message: '이 채팅방을 삭제하시겠습니까?\n삭제 후에는 채팅방을 다시 열 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed != true || !mounted) return;

    final chatProvider = context.read<ChatProvider>();
    final success = await chatProvider.deleteChatRoom(widget.room.id);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final errorMessage = chatProvider.errorMessage.isNotEmpty
        ? chatProvider.errorMessage
        : '채팅방 삭제에 실패했습니다.';
    AppSnackBar.showError(context, message: errorMessage);
  }

  /// 상단 ⋯ 메뉴에서 바로 나가기 — 채팅방 정보 화면까지 들어가지 않아도
  /// 되게 한다(정보 화면 안의 나가기는 그대로 두되, 여기서도 도달 가능해야 한다).
  Future<void> _confirmLeaveChatRoom() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '채팅방 나가기',
      message: '이 채팅방을 나가시겠습니까?\n나가면 대화 내용을 더 이상 볼 수 없습니다.',
      confirmText: '나가기',
      cancelText: '취소',
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final userId = authProvider.currentUser?.chatUserId ?? '';

    final success = await chatProvider.leaveRoom(widget.room.id, userId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final errorMessage = chatProvider.errorMessage.isNotEmpty
        ? chatProvider.errorMessage
        : '채팅방 나가기에 실패했습니다.';
    AppSnackBar.showError(context, message: errorMessage);
  }

  Future<void> _handleRoomMenuAction(_ChatRoomMenuAction action) async {
    switch (action) {
      case _ChatRoomMenuAction.info:
        _showRoomInfo();
        return;
      case _ChatRoomMenuAction.search:
        _showMessageSearch();
        return;
      case _ChatRoomMenuAction.files:
        await _showFileDrawer();
        return;
      case _ChatRoomMenuAction.leave:
        await _confirmLeaveChatRoom();
        return;
      case _ChatRoomMenuAction.delete:
        await _confirmDeleteChatRoom();
        return;
    }
  }

  // ===================== 공지 =====================

  Future<void> _setAsNotice(ChatMessage message) async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();

    final success = await chatProvider.setNotice(
      widget.room.id,
      message.id,
      authProvider.currentUser?.name ?? '',
    );

    if (!mounted) return;
    if (success) {
      AppSnackBar.showSuccess(context, message: '공지로 등록했습니다');
    } else {
      AppSnackBar.showError(context, message: '공지 등록에 실패했습니다');
    }
  }

  Future<void> _clearNotice() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();

    final success = await chatProvider.clearNotice(
      widget.room.id,
      authProvider.currentUser?.name ?? '',
    );

    if (!mounted) return;
    if (success) {
      AppSnackBar.showSuccess(context, message: '공지를 내렸습니다');
    } else {
      AppSnackBar.showError(context, message: '공지를 내리지 못했습니다');
    }
  }

  // ===================== 채팅 → 일정 등록 =====================

  /// 메시지를 기반으로 일정 등록 시트를 연다. 메시지 텍스트가 제목에
  /// 미리 채워지고(수정 가능), 그 외 항목은 캘린더 화면의 일정 등록과 동일한
  /// 4개 기본 구분 + 날짜/시간/알림 흐름을 그대로 따른다. 등록은
  /// ScheduleProvider.createSchedule을 그대로 호출하므로 월간 화면과
  /// 같은 데이터로 즉시 반영된다.
  void _showAddScheduleFromMessage(ChatMessage message) {
    final defaultTitle = message.type == MessageType.text
        ? (message.content ?? '')
        : (message.fileName ?? message.displayContent.replaceAll(
            RegExp(r'^\[[^\]]*\]\s*'),
            '',
          ));

    final titleController = TextEditingController(text: defaultTitle);
    final contentController = TextEditingController();
    final locationController = TextEditingController();
    String selectedCategory = 'MEETING';
    String selectedColorHex = '';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    bool isAllDay = true;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    bool sendNotification = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: AppSpacing.space10,
                        height: AppSpacing.space1,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.borderDefault,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '일정 등록',
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 제목 — 채팅 메시지 내용이 기본값이며 자유롭게 수정 가능
                    SeedTextField(
                      label: '제목 *',
                      controller: titleController,
                      placeholder: '일정 제목을 입력하세요',
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    SeedTextField(
                      label: '내용',
                      controller: contentController,
                      placeholder: '일정 내용을 입력하세요',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 일정 구분 (기본 4종)
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: '일정 구분',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.lg,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MEETING', child: Text('회의')),
                        DropdownMenuItem(value: 'EVENT', child: Text('행사')),
                        DropdownMenuItem(
                          value: 'TRAINING',
                          child: Text('교육'),
                        ),
                        DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedCategory = value ?? 'MEETING';
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    Text(
                      '색상',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space2,
                      children: [
                        _buildScheduleSwatch(
                          color: null,
                          isSelected: selectedColorHex.isEmpty,
                          tooltip: '색상 없음',
                          onTap: () {
                            setModalState(() {
                              selectedColorHex = '';
                            });
                          },
                        ),
                        for (final option in ScheduleColorPalette.values)
                          _buildScheduleSwatch(
                            color: option.color,
                            isSelected: selectedColorHex == option.hex,
                            tooltip: option.name,
                            onTap: () {
                              setModalState(() {
                                selectedColorHex = option.hex;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    SeedTextField(
                      label: '장소',
                      controller: locationController,
                      placeholder: '장소를 입력하세요',
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '종일',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: isAllDay,
                          onChanged: (value) {
                            setModalState(() {
                              isAllDay = value;
                            });
                          },
                          activeTrackColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startDate = picked;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '시작일',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.lg,
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                              ),
                              child: Text(
                                '${startDate.month}/${startDate.day}',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  endDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '종료일',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.lg,
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                              ),
                              child: Text(
                                '${endDate.month}/${endDate.day}',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    if (!isAllDay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '시작 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.lg,
                                    ),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.access_time,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '종료 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.lg,
                                    ),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.access_time,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '알림 발송',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: sendNotification,
                          onChanged: (value) {
                            setModalState(() {
                              sendNotification = value;
                            });
                          },
                          activeTrackColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    SizedBox(
                      width: double.infinity,
                      child: SeedButton(
                        label: '등록',
                        variant: SeedButtonVariant.brandSolid,
                        size: SeedButtonSize.large,
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            AppSnackBar.showWarning(
                              context,
                              message: '제목을 입력해주세요',
                            );
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final scheduleProvider = context
                              .read<ScheduleProvider>();
                          final companyId =
                              authProvider.currentUser?.company?.id ?? '1';

                          final startDateStr =
                              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                          final endDateStr =
                              '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                          final scheduleData = <String, dynamic>{
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim().isEmpty
                                ? null
                                : contentController.text.trim(),
                            'category': selectedCategory,
                            'color': selectedColorHex,
                            'location': locationController.text.trim().isEmpty
                                ? null
                                : locationController.text.trim(),
                            'startDate': startDateStr,
                            'endDate': endDateStr,
                            'isAllDay': isAllDay,
                            'sendNotification': sendNotification,
                          };

                          if (!isAllDay) {
                            scheduleData['startTime'] =
                                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                            scheduleData['endTime'] =
                                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                          }

                          Navigator.pop(context);

                          final success = await scheduleProvider
                              .createSchedule(
                                companyId: companyId.toString(),
                                scheduleData: scheduleData,
                              );

                          if (mounted) {
                            if (success) {
                              AppSnackBar.showSuccess(
                                context,
                                message: '일정이 등록되었습니다',
                              );
                            } else {
                              AppSnackBar.showError(
                                context,
                                message: '일정 등록에 실패했습니다',
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleSwatch({
    required Color? color,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? AppSemanticColors.surfaceDefault,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppSemanticColors.interactivePrimaryDefault
                  : AppSemanticColors.borderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: color == null
              ? Icon(
                  Icons.block,
                  size: 16,
                  color: AppSemanticColors.textTertiary,
                )
              : (isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: AppSemanticColors.textInverse,
                      )
                    : null),
        ),
      ),
    );
  }

  /// 방 상단에 붙는 공지 띠. 눌러서 펼치면 전체 내용이 보인다.
  /// 재로그인 안내가 필요한 임계 시간 — 이보다 오래 못 붙으면 "잠깐 끊김"이
  /// 아니라 눈에 띄게 알린다.
  static const _connectionNoticeThreshold = Duration(seconds: 30);

  /// 소켓이 끊긴 동안 조용히 있지 않는다. 처음엔 옅게 "다시 연결 중"을 보여주고,
  /// [_connectionNoticeThreshold]를 넘기면 더 눈에 띄게 바꾼다. 재로그인이
  /// 필요한 경우(_stoppedForAuth)는 별도 문구로 안내한다 — ChatProvider가
  /// 이미 로그인 화면으로 보내는 중이지만, 화면 전환 전 잠깐이라도 이유를 보여준다.
  /// 목록은 reverse라 pixels가 0이면 맨 아래(최신)다. 한 화면의 절반 안쪽이면 '아래를 보는 중'.
  bool _viewerNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels < position.viewportDimension * 0.5;
  }

  /// 옛 대화를 읽는 중에 재연결로 새 대화가 많이 쌓였을 때 — 목록을 튀게 하지 않고 알려 준다
  /// 위로 올려 옛 대화를 읽는 중일 때 뜨는 '맨 아래로' 단추.
  bool _showJumpToBottom = false;

  Widget _buildJumpToBottomButton() {
    if (!_showJumpToBottom) return const SizedBox.shrink();
    return Material(
      color: AppSemanticColors.surfaceDefault,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            0,
            duration: AppTransitions.normal,
            curve: Curves.easeOut,
          );
        },
        child: Tooltip(
          message: '맨 아래로',
          child: Semantics(
            button: true,
            label: '맨 아래로',
            excludeSemantics: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_downward,
                size: 20,
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewerMessagesPill() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (!chatProvider.hasNewerMessages) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
          child: Center(
            child: Material(
              color: AppSemanticColors.brandDefault,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () async {
                  await chatProvider.loadMessages(roomId: widget.room.id, refresh: true);
                  if (!mounted || !_scrollController.hasClients) return;
                  _scrollController.jumpTo(0);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward, size: 16, color: Colors.white),
                      const SizedBox(width: AppSpacing.space1),
                      Text(
                        '새 메시지 보기',
                        style: AppTypography.labelMedium.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionBanner() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isConnected) return const SizedBox.shrink();

        final String message;
        final bool severe;
        if (chatProvider.stoppedForAuth) {
          message = '로그인이 만료되었습니다. 다시 로그인해주세요';
          severe = true;
        } else {
          final since = chatProvider.disconnectedSince;
          final longDown = since != null &&
              DateTime.now().difference(since) >= _connectionNoticeThreshold;
          message = longDown
              ? '연결이 계속 끊겨 있습니다. 네트워크 상태를 확인해주세요'
              : '연결이 끊겨 다시 연결하는 중...';
          severe = longDown;
        }

        final backgroundColor = severe
            ? AppSemanticColors.statusErrorBackground
            : AppSemanticColors.statusWarningBackground;
        final borderColor = severe
            ? AppSemanticColors.statusErrorBorder
            : AppSemanticColors.statusWarningBorder;
        final textColor = severe
            ? AppSemanticColors.statusErrorText
            : AppSemanticColors.statusWarningText;
        final iconColor = severe
            ? AppSemanticColors.statusErrorIcon
            : AppSemanticColors.statusWarningIcon;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            children: [
              if (!severe)
                SizedBox(
                  width: AppSpacing.space4,
                  height: AppSpacing.space4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              else
                Icon(Icons.wifi_off, size: AppSpacing.space4, color: iconColor),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 고정 공지는 기본으로 한 줄만 보여준다. 넉 줄짜리 배너가 대화를 밀어내
  /// "채팅이 답답하다"는 얘기가 있었다. 누르면 펼치고, 다시 누르면 접힌다.
  bool _noticeExpanded = false;

  Widget _buildNoticeBanner(ChatRoom room, bool isAdmin) {
    if (!room.hasNotice) return const SizedBox.shrink();

    // 틸 상단 바 바로 아래라 파랑(info) 대신 같은 틸의 연한 면을 쓴다(정보 화면 탭바와 같은 면).
    // 접힘·펼침 모두 앞 아이콘(확성기)은 고정, 뒤 꺾쇠만 바뀐다 — 같은 띠의 아이콘 뜻이 뒤집히지 않게.
    const noticeBorder = Border(
      bottom: BorderSide(color: AppSemanticColors.subheaderBorder, width: 1),
    );

    if (!_noticeExpanded) {
      return Material(
        color: AppSemanticColors.subheaderBackground,
        child: InkWell(
          onTap: () => setState(() => _noticeExpanded = true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            decoration: const BoxDecoration(border: noticeBorder),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined, size: AppSpacing.space5, color: AppSemanticColors.subheaderLink),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Text(
                    room.noticeContent ?? '',
                    style: AppTypography.labelStrong.copyWith(
                      color: AppSemanticColors.textPrimary,
                      ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.expand_more, size: AppSpacing.space5, color: AppSemanticColors.textTertiary),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: const BoxDecoration(
        color: AppSemanticColors.subheaderBackground,
        border: noticeBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: AppSpacing.space5,
            color: AppSemanticColors.subheaderLink,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: GestureDetector(
              onTap: () => _showNoticeDetail(room),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keepAll(room.noticeContent ?? ''),
                    style: AppTypography.labelStrong.copyWith(
                      color: AppSemanticColors.textPrimary,
                      ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((room.noticeByName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${room.noticeByName} 등록',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ),
                  if ((room.noticeFileUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: () => _openNoticeFile(room),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: AppSpacing.space4,
                              color: AppSemanticColors.textLink,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                room.noticeFileName ?? '파일',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textLink,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isAdmin)
            Semantics(
              button: true,
              label: '공지 지우기',
              child: GestureDetector(
                onTap: _clearNotice,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3,
                    vertical: AppSpacing.space2_5,
                  ),
                  child: Icon(
                    Icons.close,
                    size: AppSpacing.space4,
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ),
            ),
          // 아이콘이 아니라 꺾쇠를 눌러 접는다 — 앞 아이콘은 늘 같은 확성기다
          GestureDetector(
            onTap: () => setState(() => _noticeExpanded = false),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.space1),
              child: Icon(
                Icons.expand_less,
                size: AppSpacing.space5,
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoticeDetail(ChatRoom room) {
    // 공지가 길면 화면을 넘긴다. 스크롤이 없으면 넘친 부분을 볼 방법이 아예 없어서
    // "긴 글은 다 볼 수가 없다"는 신고가 들어왔다. 시트 높이를 화면의 80%로 제한하고
    // 내용은 스크롤되게 한다 — 짧은 공지는 mainAxisSize.min 덕에 지금처럼 딱 맞게 뜬다.
    AppBottomSheet.show(
      context,
      title: '공지',
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                keepAll(room.noticeContent ?? ''),
                style: AppTypography.bodyMedium,
              ),
              if ((room.noticeByName ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '${room.noticeByName} 등록',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
              if ((room.noticeFileUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _openNoticeFile(room);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: AppSpacing.space4,
                        color: AppSemanticColors.textLink,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          room.noticeFileName ?? '파일',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textLink,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===================== 대화 검색 =====================

  void _showMessageSearch() {
    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();
    List<ChatMessage> results = [];
    bool isSearching = false;
    bool hasSearched = false;
    bool searchFailed = false;
    bool sheetClosed = false;
    int searchSeq = 0;
    bool didAutofocus = false;

    AppBottomSheet.show(
      context,
      title: '대화 검색',
      height: MediaQuery.of(context).size.height * 0.75,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          if (!didAutofocus) {
            didAutofocus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              searchFocusNode.requestFocus();
            });
          }

          Future<void> runSearch() async {
            final keyword = searchController.text.trim();
            if (keyword.isEmpty) return;

            final seq = ++searchSeq;
            setSheetState(() {
              isSearching = true;
              searchFailed = false;
            });
            List<ChatMessage> found = [];
            bool failed = false;
            try {
              found = await _chatProvider.searchMessages(
                widget.room.id,
                keyword,
              );
            } catch (e) {
              debugPrint('[ChatRoom] 대화 검색 실패: $e');
              failed = true;
            }
            // 시트가 닫혔거나 그 사이 입력이 바뀌어 새 검색이 시작됐으면 결과를 버린다.
            if (sheetClosed || seq != searchSeq) return;
            setSheetState(() {
              results = found;
              isSearching = false;
              hasSearched = true;
              searchFailed = failed;
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  child: Row(
                    children: [
                      Expanded(
                        child: SeedTextField(
                          label: '대화 내용 검색',
                          showLabel: false,
                          controller: searchController,
                          focusNode: searchFocusNode,
                          placeholder: '대화 내용 검색',
                          prefixIcon: Icons.search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => runSearch(),
                          onChanged: (_) {
                            // 입력이 바뀌면 이전 키워드의 결과를 비운다.
                            searchSeq++;
                            if (hasSearched || isSearching || results.isNotEmpty) {
                              setSheetState(() {
                                results = [];
                                hasSearched = false;
                                isSearching = false;
                                searchFailed = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      // 날짜로 이동은 검색창과 같은 줄에 둔다. 따로 한 줄을 차지하면 검색창이
                      // 자동으로 키보드를 올린 상태에서 시트 높이가 모자라 아래가 넘쳤다(360dp 캡처).
                      Semantics(
                        button: true,
                        label: '날짜로 이동',
                        child: SeedButton(
                          label: '날짜',
                          variant: SeedButtonVariant.neutralOutline,
                          size: SeedButtonSize.small,
                          prefixIcon: Icons.calendar_today,
                          onPressed: _jumpToDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      SeedButton(
                        label: '검색',
                        variant: SeedButtonVariant.brandSolid,
                        size: SeedButtonSize.small,
                        onPressed: runSearch,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : !hasSearched
                      ? Center(
                          child: Text(
                            '찾을 말을 입력해주세요',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        )
                      : searchFailed
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '검색하지 못했습니다',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              SeedButton(
                                label: '다시 시도',
                                variant: SeedButtonVariant.neutralOutline,
                                size: SeedButtonSize.small,
                                onPressed: runSearch,
                              ),
                            ],
                          ),
                        )
                      : results.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없습니다',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final message = results[index];
                            return SeedListCell(
                              title: message.senderName,
                              description: message.displayContent,
                              showChevron: false,
                              trailing: Text(
                                formatChatDateTime(message.createdAt),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                final ok = await _jumpToMessage(message.id);
                                if (!ok && mounted) {
                                  AppSnackBar.showInfo(
                                    context,
                                    message: '검색한 메시지를 찾지 못했습니다',
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      sheetClosed = true;
      searchController.dispose();
      searchFocusNode.dispose();
    });
  }

  /// "날짜로 이동" — 카톡처럼 날짜를 고르면 그 날 첫 메시지로 바로 간다.
  ///
  /// 서버가 그 날짜의 첫 메시지 id를 알려주면(first-on-date), 화면에서는
  /// [_jumpToMessage]로 재사용해 옛 대화를 필요한 만큼 더 받으며 찾아간다.
  /// 상한은 [chatDateJumpMaxLoadTries] — 답장 인용문 이동(5쪽)보다 훨씬
  /// 넉넉한 건, 몇 달 전 날짜를 찍을 수도 있어서다.
  Future<void> _jumpToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      locale: const Locale('ko', 'KR'),
      helpText: '이동할 날짜 선택',
    );
    if (picked == null || !mounted) return;

    // 검색 시트를 닫고 대화 화면에서 진행 표시·강조를 보여준다
    Navigator.of(context).pop();

    final userId = _authProvider.currentUser?.chatUserId;
    final progressNotifier = ValueNotifier<int>(0);
    // 진행 창의 '취소'를 누르면 true — 이후 도착하는 요청 결과는 무시한다.
    var cancelled = false;

    AppDialog.showCustom<void>(
      context,
      barrierDismissible: false,
      child: ValueListenableBuilder<int>(
        valueListenable: progressNotifier,
        builder: (context, tries, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.space4),
              Text(
                '${formatChatDateQuery(picked)} 대화를 찾는 중...',
                style: AppTypography.bodyMedium,
              ),
              if (tries > 0) ...[
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '옛 대화 $tries쪽째 확인 중',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space4),
              Builder(
                builder: (dialogContext) => TextButton(
                  onPressed: () {
                    cancelled = true;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final messageId = await _chatProvider.findFirstMessageIdOnDate(
        widget.room.id,
        picked,
        userId: userId,
      );
      if (cancelled) return;

      if (messageId == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          AppSnackBar.showInfo(context, message: '그 날짜 이후 대화가 없습니다');
        }
        return;
      }

      final found = await _jumpToMessage(
        messageId,
        maxTries: chatDateJumpMaxLoadTries,
        onLoadProgress: (tries) {
          if (!cancelled) progressNotifier.value = tries;
        },
        isCancelled: () => cancelled,
      );
      if (cancelled) return;

      if (mounted) Navigator.pop(context);
      if (!found && mounted) {
        AppSnackBar.showInfo(context, message: '그 날짜의 대화를 찾지 못했습니다');
      }
    } on ApiException catch (e) {
      // 서버 문구(예: 'Method Not Allowed')를 그대로 보여주면 선생님들은 무슨 뜻인지 모른다
      debugPrint('[ChatRoom] 날짜로 이동 실패: ${e.message}');
      if (cancelled) return;
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppSnackBar.showError(context, message: '날짜로 이동하지 못했습니다. 잠시 후 다시 시도해주세요');
      }
    } catch (e) {
      debugPrint('[ChatRoom] 날짜로 이동 실패: $e');
      if (cancelled) return;
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppSnackBar.showError(context, message: '날짜로 이동하지 못했습니다. 잠시 후 다시 시도해주세요');
      }
    } finally {
      progressNotifier.dispose();
    }
  }

  // ===================== 파일함 =====================

  Future<void> _showFileDrawer() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSharedMedia(widget.room.id);

    if (!mounted) return;

    AppBottomSheet.show(
      context,
      title: '주고받은 파일',
      height: MediaQuery.of(context).size.height * 0.7,
      child: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final files = provider.sharedMedia;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${files.length}건',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: files.isEmpty
                    ? Center(
                        child: Text(
                          '아직 주고받은 파일이 없습니다',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final isImage = file.type == MessageType.image;
                          final thumbUrl = resolveChatImageUrl(file);

                          return SeedListCell(
                            leading: isImage && thumbUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.md,
                                    ),
                                    child: ChatPhoto(
                                      imageUrl: thumbUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      // 44dp 썸네일에 원본 해상도를 그대로 디코드하지 않도록 제한
                                      memCacheWidth: 88,
                                      memCacheHeight: 88,
                                      brokenBuilder: (_) =>
                                          const Icon(Icons.image_outlined),
                                    ),
                                  )
                                : Icon(
                                    // 파일함에서도 동영상은 한눈에 알아보게 한다
                                    file.isVideoMessage
                                        ? Icons.videocam_outlined
                                        : Icons.insert_drive_file_outlined,
                                    color: AppSemanticColors.textSecondary,
                                  ),
                            title: file.fileName ?? '파일',
                            description:
                                '${file.senderName} · ${formatChatDateTime(file.createdAt)}',
                            showChevron: false,
                            onTap: () {
                              Navigator.pop(context);
                              _openAttachment(file);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 웹 뷰어(carev.kr/doc-view)가 앱 안에서 그려줄 수 있는 형식.
  /// 웹의 chatAttachments.ts 목록과 맞춰둔다 — 한쪽만 고치면 "열었는데 못 읽는 창"이 뜬다.
  static const Set<String> _inAppViewableExtensions = {
    'docx',
    'xlsx', 'xlsm',
    'pptx',
    'txt', 'csv', 'md', 'json', 'log', 'xml', 'yaml', 'yml',
  };
  static const Set<String> _hwpExtensions = {'hwp', 'hwpx'};

  static String _extensionOf(String fileName) {
    final idx = fileName.lastIndexOf('.');
    return idx >= 0 ? fileName.substring(idx + 1).toLowerCase() : '';
  }

  /// 사진·문서는 앱 안에서 바로 보고, 나머지(pdf·옛 오피스 등)는 기기 뷰어에 맡긴다.
  void _openAttachment(ChatMessage message) {
    _openFile(
      url: message.fileUrl,
      name: message.fileName ?? '파일',
      // 동영상이 사진 뷰어로 들어가지 않도록 파생 판정(mediaKind)을 쓴다.
      isImage: message.isPhotoMessage,
    );
  }

  /// 사진 묶음의 [index]번째를 전체화면으로 연다. 좌우로 넘기면 같은 묶음의
  /// 다른 사진이 보인다. **목록은 축소본, 여기는 언제나 원본(fileUrl)이다.**
  void _openPhotoGroup(List<ChatMessage> group, int index) {
    final items = <ChatImageItem>[];
    for (final message in group) {
      final url = message.fileUrl;
      if (url == null || url.isEmpty) continue;
      items.add(
        ChatImageItem(imageUrl: url, fileName: message.fileName ?? '사진'),
      );
    }
    if (items.isEmpty) return;

    ChatImageViewer.openGallery(
      context,
      items: items,
      initialIndex: index.clamp(0, items.length - 1),
      onDownload: (item) => _saveImage(item.imageUrl, item.fileName),
      onDownloadAll: _downloadAllImages,
    );
  }

  /// 사진첩에 저장할 때 기본으로 쓰는 앨범 이름 — 늘 시트 맨 위에 뜬다.
  static const String _photoAlbumName = '케어브이';

  /// 최근 쓴(기본 앨범 제외) 앨범 이름을 SharedPreferences에 기억해두는 키.
  static const String _recentAlbumsPrefsKey = 'chat_recent_photo_albums';
  static const int _maxRecentAlbums = 4;

  /// 폴더 선택(파일시스템 — 사진첩 밖) 선택지를 가리키는 내부 값.
  static const String _folderChoice = '__folder__';
  /// "새 앨범에 저장" 선택지를 가리키는 내부 값 — 고르면 이름 입력을 이어서 받는다.
  static const String _newAlbumChoice = '__new_album__';

  Future<List<String>> _loadRecentAlbums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentAlbumsPrefsKey) ?? const [];
      return raw.where((a) => a.trim().isNotEmpty && a != _photoAlbumName).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 방금 쓴 앨범을 "최근 사용" 맨 앞으로 올린다(기본 앨범은 항상 뜨니 기억할 필요 없다).
  Future<void> _rememberAlbum(String album) async {
    if (album.trim().isEmpty || album == _photoAlbumName) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_recentAlbumsPrefsKey) ?? const [];
      final updated = [album, ...current.where((a) => a != album)]
          .take(_maxRecentAlbums)
          .toList();
      await prefs.setStringList(_recentAlbumsPrefsKey, updated);
    } catch (_) {
      // 최근 목록 기억에 실패해도 이번 저장 자체는 이미 끝났으니 무시한다
    }
  }

  /// 이미지 하나를 저장한다 — 저장 앨범을 고르는 시트를 먼저 띄운다.
  Future<void> _saveImage(String url, String fileName) async {
    final choice = await _pickSaveDestination();
    if (choice == null) return;
    if (choice == _folderChoice) {
      await _saveImageToChosenFolder(url, fileName);
    } else {
      await _saveImageToAlbum(url, fileName, choice);
    }
  }

  /// 저장 앨범을 고르는 시트 — 기본 앨범('케어브이') · 최근 쓴 앨범들 ·
  /// 새 앨범 이름 입력을 제공한다. "폴더 선택해 저장"(사진첩 밖 파일시스템)은
  /// Android의 저장소 접근 구조상 Android에서만 의미가 있다.
  Future<String?> _pickSaveDestination() async {
    final recentAlbums = await _loadRecentAlbums();
    if (!mounted) return null;

    final choice = await AppBottomSheet.show<String>(
      context,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SeedListCell(
              title: "사진첩 '$_photoAlbumName'에 저장",
              showChevron: false,
              onTap: () => Navigator.of(context).pop(_photoAlbumName),
            ),
            for (final album in recentAlbums)
              SeedListCell(
                title: "사진첩 '$album'에 저장",
                showChevron: false,
                onTap: () => Navigator.of(context).pop(album),
              ),
            SeedListCell(
              title: '새 앨범 이름 입력',
              leadingIcon: Icons.create_new_folder_outlined,
              showChevron: false,
              onTap: () => Navigator.of(context).pop(_newAlbumChoice),
            ),
            if (Platform.isAndroid)
              SeedListCell(
                title: '폴더 선택해 저장',
                leadingIcon: Icons.folder_open_outlined,
                showChevron: false,
                onTap: () => Navigator.of(context).pop(_folderChoice),
              ),
          ],
        ),
      ),
    );

    if (choice != _newAlbumChoice) return choice;

    if (!mounted) return null;
    final input = await AppDialog.showInput(
      context,
      title: '새 앨범 이름',
      hintText: '예: 어르신 사진',
      confirmText: '저장',
    );
    final name = input?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  /// 저장용 다운로드 클라이언트 — 시간 제한이 없으면 연결이 멈췄을 때 "저장 중"이
  /// 끝없이 돈다(느린 서버에서 60초 넘게 멈춘 것을 기기에서 확인). 받는 도중
  /// 60초 동안 한 바이트도 안 오면 실패로 끝내고 알린다.
  static dio.Dio _saveClient() => dio.Dio(dio.BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ));

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final response = await _saveClient().get<List<int>>(
        url,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) return null;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  /// 사진첩 저장용 이름 — gal이 확장자를 스스로 붙이므로 마지막 확장자를 뗀다
  static String _photoBaseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || fileName.length - dot > 6) return fileName;
    return fileName.substring(0, dot);
  }

  /// 사진첩에 넣는다 — 이름 있는 앨범에 넣으려면 iOS가 사진 보관함 '전체 접근'을
  /// 요구한다. 사용자가 '추가만 허용'을 골랐으면 앨범 없이 사진첩(최근 항목)에라도
  /// 넣는다 — 그냥 실패로 끝내면 사진이 어디에도 남지 않는다.
  /// 앨범에 들어갔으면 true, 앨범 없이 사진첩에만 들어갔으면 false. 사진첩 자체가
  /// 막혀 있으면 예외를 그대로 던진다.
  Future<bool> _putToGallery({
    Uint8List? bytes,
    String? videoPath,
    String? name,
    required String album,
  }) async {
    try {
      if (videoPath != null) {
        await Gal.putVideo(videoPath, album: album);
      } else {
        await Gal.putImageBytes(bytes!, album: album, name: name ?? 'image');
      }
      return true;
    } on GalException catch (e) {
      if (e.type != GalExceptionType.accessDenied) rethrow;
      if (videoPath != null) {
        await Gal.putVideo(videoPath);
      } else {
        await Gal.putImageBytes(bytes!, name: name ?? 'image');
      }
      return false;
    }
  }

  static const String _noAlbumAccessMessage =
      '앨범 권한이 없어 사진첩(최근 항목)에 저장했습니다';

  Future<void> _saveImageToAlbum(String url, String fileName, String album) async {
    final bytes = await _downloadBytes(url);
    if (bytes == null) {
      if (mounted) AppSnackBar.showError(context, message: '저장에 실패했습니다');
      return;
    }
    try {
      // gal이 확장자를 붙이므로 이름에서 떼고 넘긴다 — 안 떼면 'a.jpg.jpg'로 저장된다
      final inAlbum = await _putToGallery(
          bytes: bytes, album: album, name: _photoBaseName(fileName));
      await _rememberAlbum(album);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: inAlbum ? "사진첩 '$album' 앨범에 저장했습니다" : _noAlbumAccessMessage,
      );
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, message: '저장에 실패했습니다');
    }
  }

  Future<void> _saveImageToChosenFolder(String url, String fileName) async {
    final dirPath = await getDirectoryPath();
    if (dirPath == null) return; // 취소

    final bytes = await _downloadBytes(url);
    if (bytes == null) {
      if (mounted) AppSnackBar.showError(context, message: '저장에 실패했습니다');
      return;
    }
    try {
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      await File('$dirPath/$safeName').writeAsBytes(bytes);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '저장했습니다');
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, message: '저장에 실패했습니다');
    }
  }

  /// 동영상을 기기에 저장한다 — 사진과 같은 앨범 선택 시트를 거친다
  /// (현장 요청: "원하는 폴더에 사진, 동영상 저장할 수 있게"). 동영상은 수십 MB라
  /// 메모리에 통째로 올리지 않고 임시 파일로 받아 사진첩에 넘긴 뒤 지운다.
  Future<void> _saveVideo(ChatMessage message) async {
    final url = message.fileUrl;
    if (url == null || url.isEmpty) {
      AppSnackBar.showError(context, message: '동영상 주소가 없습니다');
      return;
    }
    final fileName = (message.fileName?.trim().isNotEmpty ?? false)
        ? message.fileName!.trim()
        : 'video_${message.id}.mp4';

    final choice = await _pickSaveDestination();
    if (choice == null || !mounted) return;
    if (choice == _folderChoice) {
      await _saveImageToChosenFolder(url, fileName);
      return;
    }

    AppDialog.showCustom<void>(
      context,
      barrierDismissible: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.space4),
            Text('동영상 저장 중...', style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );

    Directory? tempDir;
    var ok = false;
    var inAlbum = true;
    try {
      // 사진첩에는 임시 파일 이름이 그대로 올라간다 — 겹치지 않는 임시 폴더를 만들고
      // 그 안에 원래 이름으로 받는다 ('save_1790…_영상.mp4'로 보이던 것)
      final base = await getTemporaryDirectory();
      tempDir = await Directory(
              '${base.path}/video_save_${DateTime.now().microsecondsSinceEpoch}')
          .create(recursive: true);
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final temp = File('${tempDir.path}/$safeName');
      await _saveClient().download(url, temp.path);
      inAlbum = await _putToGallery(videoPath: temp.path, album: choice);
      await _rememberAlbum(choice);
      ok = true;
    } catch (e) {
      print('[ChatRoomScreen] 동영상 저장 실패: $e');
    } finally {
      try {
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // 진행 표시 닫기
    if (ok) {
      AppSnackBar.showSuccess(
        context,
        message: inAlbum ? "사진첩 '$choice' 앨범에 저장했습니다" : _noAlbumAccessMessage,
      );
    } else {
      AppSnackBar.showError(context, message: '동영상 저장에 실패했습니다');
    }
  }

  /// 사진 묶음을 한 번에 받는다.
  ///
  /// 서른 장을 한 장씩 눌러 받게 두면 기능이 있으나 마나다.
  /// 한꺼번에 다 밀면 회선이 좁은 현장에서 오히려 느려지고 실패하므로 세 개씩 받는다.
  /// 한 장이 실패해도 나머지는 계속 받고, 끝에 몇 장 받았는지 알려준다.
  Future<void> _downloadAllImages(List<ChatImageItem> items) async {
    if (items.isEmpty) return;

    final choice = await _pickSaveDestination();
    if (choice == null) return;

    final total = items.length;
    var done = 0;
    var failed = 0;

    AppSnackBar.showInfo(context, message: '$total장 저장 중...');

    if (choice == _folderChoice) {
      final dirPath = await getDirectoryPath();
      if (dirPath == null) return; // 취소

      Future<void> saveOne(ChatImageItem item) async {
        final bytes = await _downloadBytes(item.imageUrl);
        if (bytes == null) {
          failed++;
          return;
        }
        try {
          // 같은 이름이 겹치면 덮어써 버린다 — 번호를 붙여 구분한다
          final safeName = item.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final path = '$dirPath/${DateTime.now().microsecondsSinceEpoch}_$safeName';
          await File(path).writeAsBytes(bytes);
          done++;
        } catch (_) {
          failed++;
        }
      }

      await _runWithConcurrencyLimit(items, 3, saveOne);

      if (!mounted) return;
      if (failed == 0) {
        AppSnackBar.showSuccess(context, message: '$done장을 저장했습니다');
      } else {
        AppSnackBar.showError(context, message: '$done장 저장, $failed장 실패했습니다');
      }
      return;
    }

    final album = choice;
    var outsideAlbum = 0;
    Future<void> saveOne(ChatImageItem item) async {
      final bytes = await _downloadBytes(item.imageUrl);
      if (bytes == null) {
        failed++;
        return;
      }
      try {
        final inAlbum = await _putToGallery(
            bytes: bytes, album: album, name: _photoBaseName(item.fileName));
        if (!inAlbum) outsideAlbum++;
        done++;
      } catch (_) {
        failed++;
      }
    }

    await _runWithConcurrencyLimit(items, 3, saveOne);

    if (!mounted) return;
    if (failed == 0) {
      await _rememberAlbum(album);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: outsideAlbum > 0
            ? '앨범 권한이 없어 $done장을 사진첩(최근 항목)에 저장했습니다'
            : "사진첩 '$album' 앨범에 $done장을 저장했습니다",
      );
    } else {
      AppSnackBar.showError(
        context,
        message: '$done장 저장, $failed장 실패했습니다',
      );
    }
  }

  /// 공지에 첨부된 파일도 채팅 파일 메시지와 같은 방식으로 연다.
  void _openNoticeFile(ChatRoom room) {
    _openFile(url: room.noticeFileUrl, name: room.noticeFileName ?? '파일');
  }

  void _openFile({required String? url, required String name, bool isImage = false}) {
    if (isImage && url != null && url.isNotEmpty) {
      ChatImageViewer.open(
        context,
        imageUrl: url,
        fileName: name,
        onDownload: () => _saveImage(url, name),
      );
      return;
    }

    if (url != null && url.isNotEmpty) {
      final ext = _extensionOf(name);

      // 한글 문서는 이미 앱에 있는 뷰어(결재 첨부와 같은 것)로
      if (_hwpExtensions.contains(ext)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HwpEditorScreen(filePath: url, fileName: name),
          ),
        );
        return;
      }

      // 워드·엑셀·슬라이드·텍스트는 관리자 웹과 같은 뷰어를 앱 안에서
      if (_inAppViewableExtensions.contains(ext)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              filePath: url,
              fileName: name,
              onDownload: () => _downloadAndOpenFile(url, name),
            ),
          ),
        );
        return;
      }
    }

    // pdf는 기기 기본 뷰어가 더 잘 보여주고, 그 밖의 형식은 열 방법이 없다
    _downloadAndOpenFile(url, name);
  }

  // 자주 사용하는 이모지 목록
  // 웹(ChatManagement.tsx/FloatingChatMessages.tsx)과 같은 세트 — 한쪽에서
  // 단 반응이 다른 쪽에서도 같은 이모지로 보여야 한다. 순서도 맞춰둔다.
  static const List<String> _quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '✅'];

  /// 스크린리더용 이모지 이름.
  static const Map<String, String> _emojiLabels = {
    '❤️': '하트',
    '👍': '좋아요',
    '😂': '웃음',
    '😮': '놀람',
    '😢': '슬픔',
    '✅': '확인',
  };

  /// 전송 중이거나 실패한 말풍선의 메뉴 — 다시 보내기 / 보내지 않고 삭제.
  void _showLocalMessageOptions(ChatMessage message) {
    final failed = message.sendingStatus == MessageSendingStatus.failed;
    final localId = message.localId;
    showAppActionSheet(
      context,
      title: failed ? '보내지 못한 메시지입니다' : '보내는 중입니다',
      actions: [
        if (failed && localId != null)
          AppSheetAction(
            icon: Icons.refresh,
            label: '다시 보내기',
            onSelected: () => context.read<ChatProvider>().retryMessage(localId),
          ),
        if (failed && localId != null)
          AppSheetAction(
            icon: Icons.delete_outline,
            label: '보내지 않고 삭제',
            isDestructive: true,
            onSelected: () =>
                context.read<ChatProvider>().discardLocalMessage(localId),
          ),
      ],
    );
  }

  /// 실패한 말풍선(사진 묶음이면 묶음 안의 실패한 것들)을 다시 보낸다.
  void _retryFailed(List<ChatMessage> messages) {
    final chatProvider = context.read<ChatProvider>();
    for (final m in messages) {
      if (m.sendingStatus == MessageSendingStatus.failed && m.localId != null) {
        chatProvider.retryMessage(m.localId!);
      }
    }
  }

  void _showMessageOptions(ChatMessage message) {
    // 서버에 아직 없는 말풍선(전송 중·실패)은 수정·삭제·반응을 보낼 곳이 없다.
    // 전에는 같은 메뉴가 떠서 서버가 "메시지를 찾을 수 없습니다"(500)로 답했다.
    if (message.isLocalOnly) {
      _showLocalMessageOptions(message);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final isMyMessage = message.senderId == authProvider.currentUser?.chatUserId;
    final rootContext = context;

    final canAct = message.type != MessageType.system && !message.isDeleted;
    final isVideoFile = !message.isDeleted &&
        (message.isVideoMessage ||
            (message.type == MessageType.file &&
                _isVideoFileName(message.fileName ?? '')));

    // 첨부·더보기와 같은 시트 하나를 쓴다. 위 묶음(답장·복사·공지·일정)과 아래 묶음
    // (읽은 사람·수정·삭제)을 구분선 한 줄로 나눠 긴 목록이 한 덩어리로 보이지 않게 한다.
    // 항목이 늘어도 시트가 화면을 넘치지 않는다(높이 85%에서 멈추고 안에서 스크롤).
    showAppActionSheet(
      context,
      // 이모지 빠른 선택 — 24px 글자를 40×40 칸에
      header: message.type == MessageType.system
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.space2,
                horizontal: AppSpacing.space4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickEmojis.map((emoji) {
                  // 이미 선택한 이모지인지 확인
                  final isSelected = message.reactions.any(
                    (r) => r.emoji == emoji && r.myReaction,
                  );
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${_emojiLabels[emoji] ?? emoji} 반응',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _toggleReaction(message, emoji);
                      },
                      child: Container(
                        width: AppSpacing.space10,
                        height: AppSpacing.space10,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppSemanticColors.brandWeak
                              : AppColors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.full,
                          ),
                        ),
                        // 이모지는 글꼴 크기를 직접 지정하는 예외(글자 역할 표 밖)
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: AppTypography.fontSize3xl),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
      actions: [
        if (canAct)
          AppSheetAction(
            icon: Icons.reply,
            label: '답장',
            onSelected: () => _startReplying(message),
          ),
        AppSheetAction(
          icon: Icons.copy,
          label: '복사',
          onSelected: () {
            Clipboard.setData(ClipboardData(text: message.content ?? ''));
            if (rootContext.mounted) {
              AppSnackBar.showSuccess(rootContext, message: '복사되었습니다');
            }
          },
        ),
        if (isVideoFile)
          AppSheetAction(
            icon: Icons.download_outlined,
            label: '동영상 저장',
            onSelected: () => _saveVideo(message),
          ),
        if (canAct)
          AppSheetAction(
            icon: Icons.campaign_outlined,
            label: '공지로 등록',
            onSelected: () => _setAsNotice(message),
          ),
        if (canAct)
          AppSheetAction(
            icon: Icons.event_available_outlined,
            label: '일정 등록',
            onSelected: () => _showAddScheduleFromMessage(message),
          ),
        AppSheetAction(
          icon: Icons.visibility_outlined,
          label: '읽은 사람 보기',
          hasDividerAbove: true,
          onSelected: () => _showMessageReaders(message),
        ),
        if (isMyMessage && !message.isDeleted && message.type == MessageType.text)
          AppSheetAction(
            icon: Icons.edit_outlined,
            label: '수정',
            onSelected: () => _startEditing(message),
          ),
        if (isMyMessage && !message.isDeleted)
          AppSheetAction(
            icon: Icons.delete_outline,
            label: '삭제',
            isDestructive: true,
            onSelected: () => _deleteMessage(message),
          ),
      ],
    );
  }

  // 리액션 토글
  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final userId = authProvider.currentUser?.chatUserId ?? '';
    final userName = authProvider.currentUser?.name ?? '';

    try {
      final result = await ApiService().toggleChatReaction(
        roomId: widget.room.id,
        messageId: message.id,
        userId: userId,
        userName: userName,
        emoji: emoji,
      );

      // 로컬 상태 업데이트
      if (result['action'] == 'added') {
        // 리액션 추가됨
        final updatedReactions = List<ReactionSummary>.from(message.reactions);
        final existingIndex = updatedReactions.indexWhere(
          (r) => r.emoji == emoji,
        );
        if (existingIndex >= 0) {
          // 기존 이모지에 추가
          updatedReactions[existingIndex] = updatedReactions[existingIndex]
              .copyWith(
                count: updatedReactions[existingIndex].count + 1,
                userNames: [
                  ...updatedReactions[existingIndex].userNames,
                  userName,
                ],
                myReaction: true,
              );
        } else {
          // 새 이모지 추가
          updatedReactions.add(
            ReactionSummary(
              emoji: emoji,
              count: 1,
              userNames: [userName],
              myReaction: true,
            ),
          );
        }
        chatProvider.updateMessageReactions(message.id, updatedReactions);
      } else {
        // 리액션 삭제됨
        final updatedReactions = List<ReactionSummary>.from(message.reactions);
        final existingIndex = updatedReactions.indexWhere(
          (r) => r.emoji == emoji,
        );
        if (existingIndex >= 0) {
          if (updatedReactions[existingIndex].count <= 1) {
            updatedReactions.removeAt(existingIndex);
          } else {
            updatedReactions[existingIndex] = updatedReactions[existingIndex]
                .copyWith(
                  count: updatedReactions[existingIndex].count - 1,
                  userNames: updatedReactions[existingIndex].userNames
                      .where((n) => n != userName)
                      .toList(),
                  myReaction: false,
                );
          }
        }
        chatProvider.updateMessageReactions(message.id, updatedReactions);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '리액션 처리 실패: $e');
      }
    }
  }

  // 리액션 표시 위젯 — 말풍선 줄 아래(시각 열과 따로)에 놓는다.
  // 남의 칩은 흰 면, 내 반응은 옅은 틸 면 + 틸 숫자. 테두리는 두지 않는다(칩만 두꺼워 보였다).
  Widget _buildReactionDisplay(ChatMessage message, bool isMyMessage) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space1),
      child: Wrap(
        alignment: isMyMessage ? WrapAlignment.end : WrapAlignment.start,
        spacing: AppSpacing.space1,
        runSpacing: AppSpacing.space1,
        children: message.reactions.map((reaction) {
          return GestureDetector(
            onTap: () => _toggleReaction(message, reaction.emoji),
            onLongPress: () => _showReactionUsers(reaction),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2,
                vertical: AppSpacing.space0_5,
              ),
              decoration: BoxDecoration(
                color: reaction.myReaction
                    ? AppSemanticColors.brandWeak
                    : AppSemanticColors.surfaceDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction.emoji, style: AppTypography.bodyMedium),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    '${reaction.count}',
                    style: AppTypography.bodySmall.copyWith(
                      color: reaction.myReaction
                          ? AppSemanticColors.interactivePrimaryDefault
                          : AppSemanticColors.textSecondary,
                      fontWeight: reaction.myReaction
                          ? AppTypography.fontWeightSemibold
                          : AppTypography.fontWeightNormal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 리액션 누른 사람 목록 표시
  void _showReactionUsers(ReactionSummary reaction) {
    AppDialog.showCustom<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: AppTypography.fontSize3xl),
                ),
                const SizedBox(width: AppSpacing.space2),
                Text('${reaction.count}명', style: AppTypography.heading5),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reaction.userNames.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space2,
                  ),
                  child: Text(
                    reaction.userNames[index],
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
            SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '닫기',
                variant: SeedButtonVariant.neutralOutline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 파일 다운로드 및 열기
  Future<void> _downloadAndOpenFile(String? url, String fileName) =>
      downloadAndOpenFile(context, url, fileName);

  void _showMessageReaders(ChatMessage message) async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadMessageReaders(widget.room.id, message.id);

    if (!mounted) return;

    AppBottomSheet.show(
      context,
      title: '읽은 사람',
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final readers = chatProvider.messageReaders;

          // 사람이 많은 방(28명 등)에서는 명단이 화면을 넘긴다 —
          // 스크롤이 없으면 아래쪽 사람은 볼 방법이 없다(롱프레스 메뉴가 그랬다).
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  child: Text(
                    '${readers.length}명',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
                if (readers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.space4),
                    child: Text(
                      '아직 읽은 사람이 없습니다',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: readers.length,
                    itemBuilder: (context, index) {
                      final reader = readers[index];
                      return SeedListCell(
                        leading: SeedAvatar(
                          name: reader.userName,
                          imageUrl: reader.profileImageUrl,
                          size: SeedAvatarSize.small,
                        ),
                        title: reader.userName,
                        showChevron: false,
                        trailing: Text(
                          _formatReadTime(reader.readAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      context.read<ChatProvider>().clearMessageReaders();
    });
  }

  String _formatReadTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금';
  }

  void _deleteMessage(ChatMessage message) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '메시지 삭제',
      message: '이 메시지를 삭제하시겠습니까?',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed == true && mounted) {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.deleteMessage(widget.room.id, message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
    final currentUserId = authProvider.currentUser?.chatUserId ?? '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<ChatProvider>().clearSelectedRoom();
        }
      },
      child: Scaffold(
        // 대화 바탕은 한 단계 낮춰 남의 흰 말풍선이 테두리 없이도 읽히게 한다
        backgroundColor: chatOtherBubbleOutlined
            ? AppSemanticColors.backgroundSecondary
            : AppSemanticColors.chatBackground,
        appBar: AppBar(
          title: Column(
            // 제목과 인원 수가 같은 정렬이 되도록 AppBar의 제목 정렬(iOS 가운데/그 외 왼쪽)을 따른다.
            crossAxisAlignment: _appBarTitleCentered(context)
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                _roomName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 두 줄(제목+인원)이라 상단 바 기본(heading5 18) 대신 한 단계 작은 heading6 16.
                // 줄간격 1.75짜리 bodyLarge는 아래 인원 줄과 간격이 벌어졌다.
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.headerForeground,
                ),
              ),
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  if (chatProvider.typingUsers.isNotEmpty) {
                    final typingText = chatProvider.typingUsers.length == 1
                        ? '${chatProvider.typingUsers.first}님이 입력 중...'
                        : '${chatProvider.typingUsers.length}명이 입력 중...';
                    return Text(
                      typingText,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.headerForegroundMuted,
                        height: 1.2,
                      ),
                    );
                  }
                  return Text(
                    '${_participantCountOf(chatProvider)}명',
                    style: AppTypography.bodySmall.copyWith(
                      height: 1.2,
                      color: AppSemanticColors.headerForegroundMuted,
                    ),
                  );
                },
              ),
            ],
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: '더보기',
              // 기본 Material 팝업 대신 앱 공통 액션 시트 (다른 ⋮ 메뉴와 같은 문법)
              onPressed: () => showAppActionSheet(
                context,
                title: _roomName,
                actions: [
                  AppSheetAction(
                    icon: Icons.info_outline,
                    label: '채팅방 정보',
                    onSelected: () =>
                        _handleRoomMenuAction(_ChatRoomMenuAction.info),
                  ),
                  AppSheetAction(
                    icon: Icons.search,
                    label: '대화 내용 검색',
                    onSelected: () =>
                        _handleRoomMenuAction(_ChatRoomMenuAction.search),
                  ),
                  AppSheetAction(
                    icon: Icons.folder_outlined,
                    label: '주고받은 파일',
                    onSelected: () =>
                        _handleRoomMenuAction(_ChatRoomMenuAction.files),
                  ),
                  AppSheetAction(
                    icon: Icons.logout,
                    label: '채팅방 나가기',
                    onSelected: () =>
                        _handleRoomMenuAction(_ChatRoomMenuAction.leave),
                  ),
                  if (isAdmin)
                    AppSheetAction(
                      icon: Icons.delete_outline,
                      label: '채팅 삭제',
                      isDestructive: true,
                      onSelected: () =>
                          _handleRoomMenuAction(_ChatRoomMenuAction.delete),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            // 빈 화면 탭 시 키보드 내리기
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              // 소켓 연결 상태 — 끊긴 동안은 조용히 있지 않고 알려 준다
              _buildConnectionBanner(),
              _buildNewerMessagesPill(),

              // 상단 고정 공지
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final room =
                      chatProvider.selectedRoom?.id == widget.room.id
                      ? chatProvider.selectedRoom!
                      : chatProvider.chatRooms.firstWhere(
                          (r) => r.id == widget.room.id,
                          orElse: () => widget.room,
                        );
                  return _buildNoticeBanner(room, isAdmin);
                },
              ),

              // 메시지 목록
              Expanded(
                child: Stack(
                  children: [
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, child) {
                        if (chatProvider.isLoading &&
                            chatProvider.messages.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (chatProvider.messages.isEmpty) {
                          return Center(
                            child: Text(
                              '메시지가 없습니다.\n첫 메시지를 보내보세요!',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          );
                        }

                        final messages = chatProvider.messages;
                        // 사진 묶음은 목록 전체를 한 번 훑어야 정해지므로 여기서 한 번만 만든다.
                        final photoGroups = buildPhotoGroupMap(messages);
                        final hasStatusRow =
                            chatProvider.isLoadingOlderMessages ||
                            !chatProvider.hasMoreMessages;
                        // 목록의 가장 오래된 끝(reverse:true라 화면 위쪽)에 상태
                        // 한 줄을 덧붙인다. 불러오는 중인지 끝에 닿은 건지
                        // 구분이 안 되면 느린 페이지네이션이 "고장난 것"처럼
                        // 보인다. 문구는 웹(관리자 채팅)과 같게 맞춘다.
                        final itemCount = messages.length + (hasStatusRow ? 1 : 0);

                        // 대화가 화면보다 짧으면 위에서부터 채운다.
                        //
                        // reverse:true 목록은 내용이 적으면 아래에 붙고 위가 텅 빈다.
                        // 새로 만든 방·이제 막 시작한 1:1 대화가 늘 그 모습이라
                        // "왜 중간에서 시작하냐"가 된다. reverse를 상황에 따라 끄는
                        // 방식은 항목 순서까지 뒤집혀 위험하므로 쓰지 않는다.
                        // 대신 스크롤뷰에 "내용 최소 높이 = 화면 높이"만 준다.
                        //
                        // 경계에서 튀지 않는 이유: 내용이 화면보다 길어지는 순간
                        // minHeight는 아무 일도 하지 않는다(이미 더 크므로).
                        // 남는 공간이 0으로 연속적으로 줄어들 뿐이라 튀는 지점이
                        // 아예 생기지 않는다. reverse:true도 그대로라 스크롤은
                        // 계속 최신(아래)에 붙어 시작한다.
                        if (!chatProvider.hasMoreMessages &&
                            messages.length <= _topAlignMaxMessages) {
                          return _withScrollDateBadge(
                            LayoutBuilder(
                            builder: (context, constraints) {
                              const padding = EdgeInsets.all(AppSpacing.space4);
                              final minHeight = math.max(
                                0.0,
                                constraints.maxHeight - padding.vertical,
                              );
                              return SingleChildScrollView(
                                controller: _scrollController,
                                reverse: true,
                                padding: padding,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: minHeight,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Column은 위→아래, 목록 index는 reverse
                                      // (0 = 최신)라 거꾸로 훑는다.
                                      for (int i = itemCount - 1; i >= 0; i--)
                                        _buildMessageListItem(
                                          chatProvider,
                                          i,
                                          currentUserId: currentUserId,
                                          isAdmin: isAdmin,
                                          photoGroups: photoGroups,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          );
                        }

                        return _withScrollDateBadge(
                          ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.all(AppSpacing.space4),
                            itemCount: itemCount,
                            itemBuilder: (context, index) => _buildMessageListItem(
                              chatProvider,
                              index,
                              currentUserId: currentUserId,
                              isAdmin: isAdmin,
                              photoGroups: photoGroups,
                            ),
                          ),
                        );
                      },
                    ),
                    // 위로 올려 읽는 중일 때 돌아갈 길 — 자동으로 따라 내려가지 않으므로 항상 열어 둔다
                    Positioned(
                      right: AppSpacing.space4,
                      bottom: AppSpacing.space3,
                      child: _buildJumpToBottomButton(),
                    ),
                  ],
                ),
              ),

              // @멘션 후보 (입력 중일 때만)
              _buildMentionSuggestions(),

              // 메시지 입력창
              _buildMessageInput(isAdmin),
            ],
          ),
        ),
      ),
    );
  }

  /// 메시지 목록 항목 하나.
  ///
  /// 짧은 방(위에서부터 채우는 Column)과 긴 방(ListView.builder)이 같은 코드를
  /// 쓰도록 뽑아냈다. [index]는 두 경우 모두 **reverse 기준**이다 —
  /// 0이 가장 최신이고, messages.length가 가장 오래된 끝의 상태 줄이다.
  Widget _buildMessageListItem(
    ChatProvider chatProvider,
    int index, {
    required String currentUserId,
    required bool isAdmin,
    required Map<int, List<int>> photoGroups,
  }) {
    final messages = chatProvider.messages;

    // 가장 오래된 끝의 상태 줄
    if (index >= messages.length) {
      final isLoadingOlder = chatProvider.isLoadingOlderMessages;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoadingOlder) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.space2),
              ],
              Text(
                isLoadingOlder ? '이전 대화를 불러오는 중...' : '대화의 시작입니다',
                style: AppTypography.bodySmall.copyWith(color: AppSemanticColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    final message = messages[index];
    // localId → id 순으로 안정된 키를 준다. 전송 중(sending) 메시지가
    // 서버 확정 메시지로 교체돼도 같은 자리로 인식되게 한다.
    // GlobalKey인 것은 스크롤 중 '화면 맨 위가 어느 메시지인지' 재기 위해서다
    // (같은 id면 늘 같은 키라 자리 인식은 지금까지와 똑같다). [[_updateScrollDateBadge]]
    final itemKey = _probeKeyFor(_probeIdOf(message));

    // 날짜가 바뀌는 지점(또는 가장 오래된 메시지 위)에 구분선을 끼워넣는다.
    final showDateSeparator = shouldShowDateSeparatorAbove(messages, index);

    // 시스템 메시지는 가운데 정렬로 별도 처리
    if (message.type == MessageType.system) {
      return KeyedSubtree(
        key: itemKey,
        child: Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.createdAt),
            _buildSystemMessage(message),
          ],
        ),
      );
    }

    final isMyMessage = message.senderId == currentUserId;
    final showSenderName =
        !isMyMessage && isSenderGroupStart(messages, index);

    // 사진 묶음은 **가장 오래된 사진의 자리**(group.first)에서 한 번에 그린다.
    // 날짜 구분선과 발신자 헤더 판정이 모두 그 자리를 기준으로 이미 맞게 나오므로
    // 기존 규칙을 손대지 않고 그대로 얹을 수 있다. 나머지 자리는 비워 둔다
    // (목록의 인덱스 수는 그대로라 스크롤·페이지네이션 계산이 흔들리지 않는다).
    final groupIndices = photoGroups[index];
    if (groupIndices != null && index != groupIndices.first) {
      return KeyedSubtree(key: itemKey, child: const SizedBox.shrink());
    }

    final groupMessages = groupIndices == null
        ? null
        : [for (final i in groupIndices) messages[i]];

    // 답장 인용문을 눌러 찾아온 메시지는 잠깐 배경으로 알려 준다 — 데려다 놓고
    // 아무 표시가 없으면 어느 줄을 보라는 건지 알 수 없다.
    final isHighlighted = _highlightedMessageId != null &&
        (groupMessages == null
            ? message.id == _highlightedMessageId
            : groupMessages.any((m) => m.id == _highlightedMessageId));

    return KeyedSubtree(
      key: itemKey,
      child: Column(
        children: [
          if (showDateSeparator) _buildDateSeparator(message.createdAt),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppSemanticColors.brandDefault.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: _buildMessageBubble(
              // 시각·읽음 표시는 묶음의 **가장 최신** 사진 기준으로 보여준다.
              groupMessages == null ? message : groupMessages.last,
              isMyMessage,
              showSenderName,
              isAdmin,
              chatProvider.participants,
              photoGroup: groupMessages,
              // 간격·꼬리는 묶음의 **가장 오래된** 자리(index), 시각은 **가장 최신**
              // 자리(groupIndices.last)를 기준으로 고른다.
              topGap: chatBubbleTopGap(messages, index),
              isRunStart: isSenderGroupStart(messages, index),
              showMeta: isMinuteRunEnd(messages, groupIndices?.last ?? index),
            ),
          ),
        ],
      ),
    );
  }

  /// 가운데 알약 — 날짜 구분선과 시스템 안내가 같은 모양을 쓴다(R1-10).
  /// 대화 바탕(chatBackground) 위에서 보이도록 바탕보다 한 단계 진한 옅은 면, 테두리 없음.
  Widget _buildCenterPill(
    String text, {
    required TextStyle style,
    required EdgeInsetsGeometry margin,
  }) {
    return Container(
      margin: margin,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.borderDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(text, style: style, textAlign: TextAlign.center),
      ),
    );
  }

  /// 시스템 메시지 (가운데 정렬, 시간 없음) — 위·아래 12px
  Widget _buildSystemMessage(ChatMessage message) {
    return _buildCenterPill(
      keepAll(message.displayContent),
      style: AppTypography.bodySmall.copyWith(color: AppSemanticColors.textSecondary),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
    );
  }

  /// 날짜 구분선 — 위 24px, 아래 12px. 시스템 안내와 같은 알약, 글자만 한 단계 진하게.
  Widget _buildDateSeparator(DateTime date) {
    return _buildCenterPill(
      formatDateSeparatorLabel(date),
      style: AppTypography.labelMedium.copyWith(color: AppSemanticColors.textSecondary),
      margin: const EdgeInsets.only(top: AppSpacing.space6, bottom: AppSpacing.space3),
    );
  }

  /// 채팅 버블·파일함 썸네일에 그릴 이미지 URL을 고르는 단일 지점.
  /// 썸네일(thumbnailUrl)이 있으면 그걸, 없으면 원본(fileUrl)을 쓴다
  /// (로직은 utils/chat_image_url.dart의 순수 함수로 분리해 단위 테스트한다).
  /// 전체화면 보기(_openAttachment)는 이 함수를 쓰지 않고 계속 원본
  /// fileUrl을 그대로 쓴다.
  String? _chatImageUrl(ChatMessage message) => resolveChatImageUrl(message);

  /// senderId로 참가자 목록에서 프로필 사진 URL을 찾는다 (없으면 null → 이니셜 표시).
  String? _findSenderProfileImageUrl(
    String senderId,
    List<ChatParticipant> participants,
  ) {
    for (final participant in participants) {
      if (participant.userId == senderId) {
        return participant.profileImageUrl;
      }
    }
    return null;
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isMyMessage,
    bool showSenderName,
    bool isAdmin,
    List<ChatParticipant> participants, {
    /// 사진 묶음(오래된→최신). null이면 지금까지처럼 메시지 한 건짜리 말풍선.
    List<ChatMessage>? photoGroup,

    /// 위 말풍선과의 간격(chatBubbleTopGap) — 같은 사람·같은 분이면 좁게, 사람이 바뀌면 넓게.
    double topGap = 0,

    /// 같은 사람 묶음의 첫 말풍선인지 — 꼬리 모서리(4px)는 여기에만 둔다.
    bool isRunStart = true,

    /// 같은 사람·같은 분 묶음의 마지막 말풍선인지 — 시각·안 읽은 수는 여기에만 붙인다.
    bool showMeta = true,
  }) {
    // 지운 메시지는 남·나 모두 같은 옅은 면 + 흐린 글자(채운 색 위의 반투명 글자는 대비가 모자랐다)
    final isDeletedBubble = photoGroup == null && message.isDeleted;
    final bubbleColor = isDeletedBubble
        ? AppSemanticColors.backgroundTertiary
        : isMyMessage
        ? AppSemanticColors.interactivePrimaryDefault
        : AppSemanticColors.surfaceDefault;

    final textColor = isDeletedBubble
        ? AppSemanticColors.textTertiary
        : isMyMessage
        ? AppSemanticColors.textInverse
        : AppSemanticColors.textPrimary;

    // 안 읽은 사람 수 — 참가자마다 '어디까지 읽었는지'를 보고 센다.
    // 보낸 사람 자신은 언제나 읽은 것으로 친다(서버는 전송 시 읽음 행만 남기고
    // 참가자 포인터는 옮기지 않는다).
    // 참가자를 아직 못 받았을 때만 서버가 준 readCount로 대신 센다.
    int unreadCountOf(ChatMessage m) {
      return participants.isEmpty
          ? widget.room.participantCount - m.readCount
          : participants
                .where(
                  (p) =>
                      p.userId != m.senderId &&
                      (p.lastReadMessageId ?? 0) < m.id,
                )
                .length;
    }

    // 묶음에서는 **가장 덜 읽힌 사진**의 수를 쓴다. 묶음 안에서도 읽음이 서로
    // 다를 수 있는데, 더 적은 쪽을 보여주면 "다 읽었다"고 잘못 말하게 된다.
    final unreadCount = photoGroup == null
        ? unreadCountOf(message)
        : photoGroup.map(unreadCountOf).reduce((a, b) => a > b ? a : b);

    // 전송 상태도 묶음 전체에서 가장 나쁜 것을 따른다 — 한 장이라도 실패했으면
    // 실패로 보여야 다시 보낼 수 있다.
    MessageSendingStatus groupStatus() {
      if (photoGroup == null) return message.sendingStatus;
      if (photoGroup.any((m) => m.sendingStatus == MessageSendingStatus.failed)) {
        return MessageSendingStatus.failed;
      }
      if (photoGroup.any(
        (m) => m.sendingStatus == MessageSendingStatus.sending,
      )) {
        return MessageSendingStatus.sending;
      }
      return MessageSendingStatus.sent;
    }

    final sendingStatus = groupStatus();

    // 사진·동영상은 말풍선 틀 없이 사진만 둥글게 보여준다 — 틀(여백 12 + 테두리)까지 두면
    // 사진 둘레에 두꺼운 상자가 둘러져 무거웠다(D4). 묶음뿐 아니라 한 장짜리·동영상도 같다.
    final isMediaBubble =
        photoGroup != null ||
        (!message.isDeleted && (message.type == MessageType.image || message.isVideoMessage));

    final outlined = !isMyMessage && !isMediaBubble && chatOtherBubbleOutlined;

    // 꼬리 모서리(작은 모서리)는 같은 사람 묶음의 첫 말풍선에만 둔다. 모든 말풍선에
    // 같은 꼬리를 달면 도장 찍은 듯 반복돼 거칠어 보인다.
    const big = Radius.circular(AppBorderRadius.xl);
    const small = Radius.circular(AppBorderRadius.base);
    final BorderRadius bubbleRadius = isMediaBubble
        ? BorderRadius.circular(AppBorderRadius.xl2)
        : BorderRadius.only(
            topLeft: (!isMyMessage && isRunStart) ? small : big,
            topRight: (isMyMessage && isRunStart) ? small : big,
            bottomLeft: big,
            bottomRight: big,
          );

    // 말풍선 본체
    final bubbleBox = Container(
      padding: isMediaBubble
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
      clipBehavior: isMediaBubble ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: isMediaBubble
            ? null
            : sendingStatus == MessageSendingStatus.sending
            ? bubbleColor.withValues(alpha: 0.7)
            : bubbleColor,
        // 남의 말풍선(흰색)은 대화 바탕(chatBackground)을 한 단계 낮춰 테두리 없이도 읽히게 한다.
        // 대안(옅은 테두리)은 시안 비교용으로만 남겨 둔다.
        border: outlined ? Border.all(color: AppColors.gray200) : null,
        borderRadius: bubbleRadius,
      ),
      constraints: BoxConstraints(maxWidth: _bubbleMaxWidth(context, isMine: isMyMessage)),
      child: photoGroup != null
          ? ChatPhotoGroup(
              messages: photoGroup,
              // 사진은 여백·테두리 없이 그리므로 말풍선 폭을 그대로 쓴다
              maxWidth: _bubbleMaxWidth(context, isMine: isMyMessage),
              onTap: (i) => _openPhotoGroup(photoGroup, i),
              onLongPress: (i) => _showMessageOptions(photoGroup[i]),
            )
          : _buildMessageContent(message, textColor, isMyMessage),
    );

    // 시각·읽음 표시 열.
    // 읽음 표시는 누가 보냈든 똑같이 뜬다 — 내 메시지에만 두면
    // 상대 메시지를 아직 누가 안 봤는지 알 수 없다.
    // 같은 사람의 같은 분 묶음에서는 **마지막 말풍선에만** 시각·안 읽은 수를 붙이고,
    // 전송 중·실패처럼 지금 알려야 하는 상태만 모든 말풍선에 남긴다(R1-03·R1-22).
    final showFailed = isMyMessage && sendingStatus == MessageSendingStatus.failed;
    final showSending = isMyMessage && sendingStatus == MessageSendingStatus.sending;
    final showUnread = showMeta && unreadCount > 0 && sendingStatus != MessageSendingStatus.failed;
    final showTime = showMeta && !showFailed;
    final hasMeta = showFailed || showSending || showUnread || showTime;

    Widget metaColumn({required bool alignEnd}) {
      final edited = message.editedAt != null && photoGroup == null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 안 읽은 수는 역할(직원·관리자)과 무관하게 같은 틸 — 같은 정보는 한 색이다
          if (showUnread)
            Text(
              '$unreadCount',
              style: AppTypography.labelStrong.copyWith(
                color: AppSemanticColors.interactivePrimaryDefault,
                height: 1.2,
              ),
            ),
          // 실패는 아이콘만으로는 부족하다 — 다시 타이핑하지 않고 그 자리에서 보낼 수 있어야 한다
          if (showFailed)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _retryFailed(photoGroup ?? [message]),
              child: Padding(
                // 글자 높이만으로는 누르기 어려워 위아래로 늘려 최소 32px 확보
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                child: Text(
                  '다시 보내기',
                  style: AppTypography.labelStrong.copyWith(
                    color: AppSemanticColors.statusErrorText,
                    ),
                ),
              ),
            ),
          if (showSending || showTime)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSending) ...[
                  _buildSendingStatusIcon(sendingStatus, isAdmin),
                  if (showTime) const SizedBox(width: AppSpacing.space1),
                ],
                if (showTime)
                  Text(
                    // 수정 표시는 말풍선 안 둘째 줄이 아니라 시각 옆에 — 말풍선이 커지지 않는다
                    edited
                        ? '수정됨 · ${_formatMessageTime(message.createdAt)}'
                        : _formatMessageTime(message.createdAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
        ],
      );
    }

    // 말풍선 줄 — 시각 열은 반응 칩이 아니라 **말풍선 바닥**에 맞춘다.
    Widget bubbleRow({required bool alignEnd}) {
      final meta = hasMeta ? metaColumn(alignEnd: alignEnd) : null;
      final gap = const SizedBox(width: AppSpacing.space1);
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: alignEnd
            ? [
                if (meta != null) ...[meta, gap],
                Flexible(child: bubbleBox),
              ]
            : [
                Flexible(child: bubbleBox),
                if (meta != null) ...[gap, meta],
              ],
      );
    }

    final reactions = message.reactions.isNotEmpty
        ? _buildReactionDisplay(message, isMyMessage)
        : null;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: EdgeInsets.only(top: topGap),
        child: isMyMessage
            ? SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [bubbleRow(alignEnd: true), if (reactions != null) reactions],
                ),
              )
            // 남의 메시지 — 카톡 배치.
            //   [아바타]  이름 직종
            //             [말풍선]
            // 아바타는 그룹 첫 메시지에만 그리고, 이어지는 메시지는 같은 폭
            // (ChatAvatarSlot.width)만 차지해 말풍선이 세로로 정렬된다.
            // 이름·직종은 아바타 오른쪽 한 줄에 놓여 남는 가로폭을 전부 쓴다.
            : Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: AppSpacing.space1),
                  ChatAvatarSlot(
                    visible: showSenderName,
                    senderName: message.senderName,
                    imageUrl: _findSenderProfileImageUrl(
                      message.senderId,
                      participants,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showSenderName)
                          ChatSenderHeader(
                            senderName: message.senderName,
                            senderPosition: message.senderPosition,
                          ),
                        bubbleRow(alignEnd: false),
                        if (reactions != null) reactions,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSendingStatusIcon(MessageSendingStatus status, bool isAdmin) {
    switch (status) {
      case MessageSendingStatus.sending:
        return SizedBox(
          width: AppSpacing.space3,
          height: AppSpacing.space3,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppSemanticColors.textTertiary,
            ),
          ),
        );
      case MessageSendingStatus.sent:
        return Icon(
          Icons.check,
          size: AppSpacing.space3,
          color: AppSemanticColors.textTertiary,
        );
      case MessageSendingStatus.failed:
        return Icon(
          Icons.error_outline,
          size: AppSpacing.space3,
          color: AppSemanticColors.statusErrorIcon,
        );
    }
  }

  /// 답장이면 원문 미리보기를 본문 위에 붙인다. 삭제된 메시지에는 붙이지 않는다
  /// (본문 자리에 "삭제된 메시지입니다"만 남아야 한다).
  Widget _buildMessageContent(
    ChatMessage message,
    Color textColor,
    bool isMyMessage,
  ) {
    final body = _buildMessageBody(message, textColor, isMyMessage);
    if (message.replyToId == null || message.isDeleted) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyQuote(message, textColor),
        const SizedBox(height: AppSpacing.space1),
        body,
      ],
    );
  }

  /// 답장 원문 한 줄 — 왼쪽 세로선 + 보낸 사람 + 내용.
  /// 원문이 지워졌으면 서버가 "삭제된 메시지입니다"를 내려준다.
  Widget _buildReplyQuote(ChatMessage message, Color textColor) {
    final quoted = message.replyToContent ?? '';
    final preview = quoted.isNotEmpty
        ? quoted
        : switch ((message.replyToMediaType ?? message.replyToType ?? '').toUpperCase()) {
            'IMAGE' => '사진',
            'VIDEO' => '동영상',
            _ => '파일',
          };

    // 인용 블록 — 은은한 바탕 위에 글자를 알파로 흐리지 않고 두 단계로만 나눈다.
    // (Border에 borderRadius를 주면 한쪽 선만 그릴 수 없어서 왼쪽 선은 따로 그린다.)
    final isOnBrand = textColor == AppSemanticColors.textInverse;
    return Semantics(
      button: true,
      label: '답장 원본으로 이동',
      child: GestureDetector(
        // 누르면 그 원본으로 데려간다 (카톡과 같은 동작)
        onTap: message.replyToId == null
            ? null
            : () => _jumpToRepliedMessage(message.replyToId!),
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Container(
            color: isOnBrand
                ? AppSemanticColors.textInverse.withValues(alpha: 0.16)
                : AppSemanticColors.backgroundSecondary,
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 2,
                    color: isOnBrand
                        ? AppSemanticColors.textInverse.withValues(alpha: 0.5)
                        : AppSemanticColors.borderHover,
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space1_5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.replyToSenderName ?? '',
                            style: AppTypography.labelStrong.copyWith(
                              color: textColor.withValues(alpha: 0.85),
                              ),
                          ),
                          // 두 줄로 잘라 "..."을 붙이지 않는다 — 무슨 말에 답한 건지 읽는 자리인데
                          // 정작 그 말이 잘려 있으면 소용이 없다. 길면 아래로 흐른다.
                          Text(
                            keepAll(preview),
                            style: AppTypography.bodySmall.copyWith(
                              color: textColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBody(
    ChatMessage message,
    Color textColor,
    bool isMyMessage,
  ) {
    if (message.isDeleted) {
      // 이탤릭 없음 — 한글에는 기울임 글꼴이 없어 합성 기울임이 지글거린다.
      // 색은 말풍선이 이미 옅은 면 + textTertiary로 바꿔 둔다(남·나 동일).
      return Text('삭제된 메시지입니다', style: AppTypography.bodyMedium.copyWith(color: textColor));
    }

    switch (message.type) {
      case MessageType.image:
        return Semantics(
          button: true,
          label: '이미지 크게 보기',
          child: GestureDetector(
            onTap: () => _openAttachment(message),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_chatImageUrl(message) != null)
                  Builder(
                    builder: (context) {
                      // 말풍선 최대 폭과 같은 가로/세로 4:3 자리를 로딩 중에도
                      // 미리 잡아둬 이미지가 뜨며 스크롤이 튀지 않게 한다.
                      final placeholderWidth = _bubbleMaxWidth(context, isMine: isMyMessage);
                      final placeholderHeight = placeholderWidth * 0.75;
                      final sendFailed = message.sendingStatus == MessageSendingStatus.failed;
                      // 바깥 말풍선이 이미 둥글게 잘라 주므로 안쪽 ClipRRect는 두지 않는다.
                      return Stack(
                        children: [
                          // 깨져 오면 스스로 다시 받는다 (ChatPhoto) — 앱은 깨진 응답까지 캐시에 남는다
                          ChatPhoto(
                            imageUrl: _chatImageUrl(message)!,
                            fit: BoxFit.cover,
                            // 말풍선 최대 폭보다 큰 원본을 그대로 디코드하지 않도록 제한
                            memCacheWidth: (placeholderWidth * 2).round(),
                            placeholder: (context) => Container(
                              width: placeholderWidth,
                              height: placeholderHeight,
                              color: AppSemanticColors.backgroundTertiary,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            brokenBuilder: (context) => SizedBox(
                              width: placeholderWidth,
                              height: placeholderHeight,
                              child: Container(
                                color: AppSemanticColors.backgroundTertiary,
                                child: Icon(
                                  Icons.broken_image,
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                          if (sendFailed) const ChatSendFailedOverlay(),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );

      case MessageType.file:
        // 동영상은 저장 타입이 여전히 FILE로 온다(구버전 앱이 모르는 타입을
        // 글로 떨어뜨리기 때문 — utils/chat_media.dart 주석 참고).
        // 대신 서버가 준 mediaType(없으면 mimeType·확장자)으로 알아보고,
        // 첨부 한 줄이 아니라 눌러서 재생하는 타일로 그린다.
        // 탭하면 기기 기본 플레이어로 열린다(_openAttachment → _downloadAndOpenFile).
        if (message.isVideoMessage) {
          return ChatVideoBubble(
            message: message,
            // 사진처럼 말풍선 틀 없이 그리므로 말풍선 폭 그대로
            maxWidth: _bubbleMaxWidth(context, isMine: isMyMessage),
            onTap: () => _openAttachment(message),
          );
        }

        final isVideo = _isVideoFileName(message.fileName ?? '');
        return ChatFileCard(
          name: message.fileName ?? '파일',
          fileSize: message.fileSize,
          isVideo: isVideo,
          onBrand: isMyMessage,
          onTap: () => _openAttachment(message),
        );

      case MessageType.text:
        // '수정됨'은 시각 옆으로 옮겼다(말풍선 안 둘째 줄은 틸 위에서 흐리고 말풍선만 키웠다).
        return _buildTextWithMentions(message.content ?? '', textColor);
      case MessageType.system:
        return _buildTextWithMentions(message.content ?? '', textColor);
    }
  }

  /// '@이름'을 굵게 칠하고, 링크는 눌러서 열 수 있게 그린다.
  ///
  /// 링크가 그냥 글자였다 — 붙여 넣어도 눌리지 않았다. 언급과 링크가 한 글에
  /// 섞여 있을 수 있으므로 두 규칙을 한 번에 적용한다.
  Widget _buildTextWithMentions(String content, Color textColor) {
    final myName = context.read<AuthProvider>().currentUser?.name ?? '';

    final spans = <InlineSpan>[];

    // 먼저 링크로 쪼개고, 링크가 아닌 조각 안에서만 언급을 찾는다.
    for (final part in splitMessageLinks(content)) {
      if (part.isLink) {
        spans.add(
          TextSpan(
            text: part.text,
            style: TextStyle(
              color: textColor,
              decoration: TextDecoration.underline,
              decorationColor: textColor.withValues(alpha: 0.6),
            ),
            recognizer: (TapGestureRecognizer()
              ..onTap = () => _openLink(part.url!)),
          ),
        );
        continue;
      }

      final text = part.text;
      final matches = RegExp(r'@[^\s@]+').allMatches(text).toList();
      var cursor = 0;

      for (final match in matches) {
        if (match.start > cursor) {
          spans.add(TextSpan(text: keepAll(text.substring(cursor, match.start))));
        }

        final mention = match.group(0)!;
        final isMe = myName.isNotEmpty && mention == '@$myName';

        spans.add(
          TextSpan(
            text: mention,
            style: TextStyle(
              fontWeight: AppTypography.fontWeightSemibold,
              backgroundColor: isMe ? AppSemanticColors.statusWarningBackground : null,
              color: isMe ? AppSemanticColors.statusWarningText : textColor,
            ),
          ),
        );
        cursor = match.end;
      }

      if (cursor < text.length) {
        spans.add(TextSpan(text: keepAll(text.substring(cursor))));
      }
    }

    // RichText가 아니라 Text.rich여야 한다. RichText는 글자 배율(기본값 noScaling)도 앱 서체도
    // 물려받지 않아, 말풍선 본문만 글자 크기 설정을 무시하고 작게·다른 서체로 그려졌다
    // (같은 말풍선의 답장 인용문은 커지는데 본문은 그대로였다).
    return Text.rich(
      TextSpan(
        style: AppTypography.bodyMedium.copyWith(color: textColor),
        children: spans,
      ),
    );
  }

  /// 링크를 바깥 브라우저로 연다. 못 열면 조용히 끝내지 않고 이유를 보여준다.
  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppSnackBar.showError(context, message: '링크를 열 수 없습니다: $url');
    }
  }

  String _formatMessageTime(DateTime time) => formatChatClock(time);

  Widget _buildMessageInput(bool isAdmin) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.space4,
        right: AppSpacing.space4,
        top: AppSpacing.space2,
        bottom: AppSpacing.space2 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          top: BorderSide(color: AppSemanticColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingMessage != null) _buildEditingBanner(),
          if (_replyingTo != null) _buildReplyingBanner(),
          Row(
        // 여러 줄로 늘어나도 첨부·전송 버튼은 입력 상자 **아래**에 붙어 있다(카톡·Slack과 같다)
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 첨부 버튼 (사진/파일) — 전송 버튼과 같은 40 지름
          Tooltip(
            message: '파일 첨부',
            child: Semantics(
            button: true,
            label: '파일 첨부',
            child: Material(
              color: AppSemanticColors.backgroundTertiary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _showAttachmentOptions,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: AppSpacing.space10,
                  height: AppSpacing.space10,
                  child: Icon(
                    Icons.add_rounded,
                    size: AppSpacing.space6,
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),

          // 메시지 입력 필드
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
              ),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                // 스타일을 안 주면 테마 기본(16)이 써져 타이핑하는 순간 힌트(14)·말풍선(14)보다 커졌다
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
                cursorColor: AppSemanticColors.interactivePrimaryDefault,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  // 글자를 키우면 '메시지를 입력하세 / 요'로 글자 중간에서 줄이 넘어갔다 — 한 줄로 두고 줄인다
                  hintMaxLines: 1,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space2_5,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                // 카카오톡과 같게: 키보드 엔터는 줄바꿈, 전송은 오른쪽 버튼으로만
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.space2),

          // 전송 버튼 — Material+InkWell로 눌림 피드백 부여.
          // 입력이 비어 있으면(첨부는 고르는 즉시 전송되어 대기분이 없다) 비활성 모양.
          // 수정 중에는 비워도 눌러 수정을 접을 수 있으므로 활성으로 둔다.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, _) {
              final canSend =
                  _editingMessage != null || value.text.trim().isNotEmpty;
              return Material(
                color: canSend
                    ? AppSemanticColors.interactivePrimaryDefault
                    : AppSemanticColors.interactivePrimaryDisabled,
                shape: const CircleBorder(),
                child: Semantics(
                  button: true,
                  enabled: canSend,
                  label: '메시지 전송',
                  child: InkWell(
                    onTap: canSend ? _sendMessage : null,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: AppSpacing.space10,
                      height: AppSpacing.space10,
                      child: Center(
                        child: Icon(
                          _editingMessage != null
                              ? Icons.check_rounded
                              : Icons.send_rounded,
                          color: AppSemanticColors.textInverse,
                          size: AppSpacing.space5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
          ),
        ],
      ),
    );
  }

  /// 입력창 위에 뜨는 '메시지 수정 중' 배너.
  /// 답장 대상 미리보기 — 입력창 위에 누구의 무슨 말에 답하는지 보여준다.
  /// 수정 배너와 같은 모양이되 아이콘과 문구만 다르다.
  Widget _buildReplyingBanner() {
    final target = _replyingTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: AppSpacing.space4,
            color: AppSemanticColors.interactivePrimaryDefault,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${target.senderName}님에게 답장',
                  style: AppTypography.labelStrong.copyWith(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    ),
                ),
                Text(
                  _replyPreviewText(target),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '답장 취소',
            onPressed: _cancelReplying,
            icon: Icon(
              Icons.close,
              size: AppSpacing.space4,
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingBanner() {
    final editing = _editingMessage!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit,
            size: AppSpacing.space4,
            color: AppSemanticColors.interactivePrimaryDefault,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '메시지 수정 중',
                  style: AppTypography.labelStrong.copyWith(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    ),
                ),
                Text(
                  editing.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '수정 취소',
            onPressed: _cancelEditing,
            icon: Icon(
              Icons.close,
              size: AppSpacing.space4,
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
