import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
import 'package:open_filex/open_filex.dart';
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
import '../utils/chat_image_url.dart';
import '../utils/chat_media.dart' as chat_media;
import '../utils/chat_message_grouping.dart';
import '../utils/chat_message_pagination.dart';
import 'chat_room_info_screen.dart';
import 'document_viewer_screen.dart';
import 'hwp_editor_screen.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';
import '../widgets/chat/chat_image_viewer.dart';
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

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _isTyping = false;

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
    _authProvider = context.read<AuthProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMessages();
      _markAsRead();
      // 메시지 발신자 아바타 표시용 참가자 정보 로드
      _chatProvider.loadParticipants(widget.room.id);
    });

    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
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
                    // 구분선과 같은 톤이되, 대화 위에 뜨므로 불투명하게 덮는다
                    color: AppSemanticColors.backgroundTertiary,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    border: Border.all(color: AppSemanticColors.borderSubtle),
                  ),
                  child: Text(
                    _scrollDateLabel ?? '',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
    final messages = chatProvider.messages;
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
    AppBottomSheet.show(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeedListCell(
                leadingIcon: Icons.photo_library,
                title: '사진·동영상',
                description: '갤러리에서 사진·동영상 선택',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendPhoto();
                },
              ),
              SeedListCell(
                leadingIcon: Icons.insert_drive_file,
                title: '파일',
                description: '문서, PDF 등 파일 선택',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        ),
      ),
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
  static const double _metaColumnWidth = 56;

  // 말풍선 최대 폭. 화면의 70%를 기본으로 하되, 좌우 고정 요소(목록 좌우 패딩,
  // 아바타 열, 사이 여백, 시각 열)를 뺀 실제 여유 폭을 넘지 않게 한다.
  // 이미지 자리표시자가 이 값을 그대로 쓰므로 넘치면 오버플로가 난다.
  double _bubbleMaxWidth(BuildContext context) {
    const reserved = AppSpacing.space4 * 2 + // ListView 좌우 패딩
        AppSpacing.space1 + // 아바타 앞 여백
        ChatAvatarSlot.width +
        AppSpacing.space2 + // 아바타와 본문 사이
        AppSpacing.space1 + // 말풍선과 시각 열 사이
        _metaColumnWidth;
    final width = MediaQuery.of(context).size.width;
    return math.min(width * 0.7, width - reserved);
  }

  /// 말풍선 **안쪽**에서 실제로 그릴 수 있는 폭.
  ///
  /// 좌우 안쪽 여백(space3)을 빼고, 남의 말풍선은 1px 테두리가 좌우로 한 겹 더
  /// 있으므로(내 말풍선은 border: null) 그 2px까지 뺀다. 이걸 빼먹으면 격자의
  /// 오른쪽 칸이 딱 2px 잘린다 — 사진처럼 폭을 꽉 채우는 자식에서만 드러난다.
  double _bubbleContentWidth(BuildContext context, bool isMyMessage) {
    final borderWidth = isMyMessage ? 0.0 : 2.0;
    return _bubbleMaxWidth(context) - AppSpacing.space3 * 2 - borderWidth;
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
        return compressedFile;
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
    final converted = await _compressImage(file, fileSize);
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
  Future<File?> _compressImage(File file, int originalSize) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${tempDir.path}/$fileName';

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

        final recompressPath =
            '${tempDir.path}/recompressed_${attempts}_$fileName';

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

  void _showRoomInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomInfoScreen(room: widget.room)),
    );
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
                            fontWeight: FontWeight.bold,
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
  Widget _buildNoticeBanner(ChatRoom room, bool isAdmin) {
    if (!room.hasNotice) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusInfoBackground,
        border: Border(
          bottom: BorderSide(
            color: AppSemanticColors.statusInfoBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: AppSpacing.space5,
            color: AppSemanticColors.statusInfoIcon,
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
                    room.noticeContent ?? '',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.statusInfoText,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((room.noticeByName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${room.noticeByName} 등록',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.statusInfoText.withValues(
                            alpha: 0.7,
                          ),
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
                              color: AppSemanticColors.statusInfoText,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                room.noticeFileName ?? '파일',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppSemanticColors.statusInfoText,
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
                    color: AppSemanticColors.statusInfoText,
                  ),
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
              Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: AppSemanticColors.statusInfoIcon,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    '공지',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(room.noticeContent ?? '', style: AppTypography.bodyMedium),
              if ((room.noticeByName ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '${room.noticeByName} 등록',
                  style: AppTypography.labelSmall.copyWith(
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
    bool didAutofocus = false;

    AppBottomSheet.show(
      context,
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

            setSheetState(() => isSearching = true);
            final found = await _chatProvider.searchMessages(
              widget.room.id,
              keyword,
            );
            setSheetState(() {
              results = found;
              isSearching = false;
              hasSearched = true;
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
                                _formatMessageTime(message.createdAt),
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
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
      searchController.dispose();
      searchFocusNode.dispose();
    });
  }

  // ===================== 파일함 =====================

  Future<void> _showFileDrawer() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSharedMedia(widget.room.id);

    if (!mounted) return;

    AppBottomSheet.show(
      context,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final files = provider.sharedMedia;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      color: AppSemanticColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '주고받은 파일 ${files.length}건',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                                    child: CachedNetworkImage(
                                      imageUrl: thumbUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      // 44dp 썸네일에 원본 해상도를 그대로 디코드하지 않도록 제한
                                      memCacheWidth: 88,
                                      memCacheHeight: 88,
                                      errorWidget: (_, __, ___) =>
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
                                '${file.senderName} · ${_formatMessageTime(file.createdAt)}',
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
      onDownload: (item) => _downloadAndOpenFile(item.imageUrl, item.fileName),
      onDownloadAll: _downloadAllImages,
    );
  }

  /// 사진 묶음을 한 번에 받는다.
  ///
  /// 서른 장을 한 장씩 눌러 받게 두면 기능이 있으나 마나다.
  /// 한꺼번에 다 밀면 회선이 좁은 현장에서 오히려 느려지고 실패하므로 세 개씩 받는다.
  /// 한 장이 실패해도 나머지는 계속 받고, 끝에 몇 장 받았는지 알려준다.
  Future<void> _downloadAllImages(List<ChatImageItem> items) async {
    if (items.isEmpty) return;

    final total = items.length;
    var done = 0;
    var failed = 0;

    AppSnackBar.showInfo(context, message: '$total장 저장 중...');

    final directory = await getApplicationDocumentsDirectory();
    final dioClient = dio.Dio();

    Future<void> saveOne(ChatImageItem item) async {
      try {
        // 같은 이름이 겹치면 덮어써 버린다 — 번호를 붙여 구분한다
        final safeName = item.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final path = '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        await dioClient.download(item.imageUrl, path);
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
        onDownload: () => _downloadAndOpenFile(url, name),
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

  void _showMessageOptions(ChatMessage message) {
    final authProvider = context.read<AuthProvider>();
    final isMyMessage = message.senderId == authProvider.currentUser?.chatUserId;
    final rootContext = context;

    // 항목이 늘면 시트가 화면을 넘친다 — 실제로 '수정'과 '삭제'가 화면 밖으로 밀려
    // 안 보였다("길게 눌러도 수정이 없다"). 높이를 화면의 85%로 묶고 안에서 스크롤한다.
    // 짧을 때는 mainAxisSize.min 덕에 지금처럼 내용 높이에 딱 맞게 뜬다.
    AppBottomSheet.show(
      context,
      isScrollControlled: true,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(rootContext).size.height * 0.85,
          ),
          child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이모지 빠른 선택
            if (message.type != MessageType.system)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                  horizontal: AppSpacing.space4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickEmojis.map((emoji) {
                    // 이미 선택한 이모지인지 확인
                    final isSelected = message.reactions.any(
                      (r) => r.emoji == emoji && r.myReaction,
                    );
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _toggleReaction(message, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.space2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppSemanticColors.interactivePrimaryDefault
                                    .withValues(alpha: 0.2)
                              : AppColors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.lg,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 1),
            if (message.type != MessageType.system && !message.isDeleted)
              SeedListCell(
                leadingIcon: Icons.reply,
                title: '답장',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _startReplying(message);
                },
              ),
            SeedListCell(
              leadingIcon: Icons.copy,
              title: '복사',
              showChevron: false,
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                if (rootContext.mounted) {
                  AppSnackBar.showSuccess(rootContext, message: '복사되었습니다');
                }
              },
            ),
            SeedListCell(
              leadingIcon: Icons.visibility,
              title: '읽은 사람 보기',
              showChevron: false,
              onTap: () {
                Navigator.pop(context);
                _showMessageReaders(message);
              },
            ),
            if (message.type != MessageType.system && !message.isDeleted)
              SeedListCell(
                leadingIcon: Icons.campaign_outlined,
                title: '공지로 등록',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _setAsNotice(message);
                },
              ),
            if (message.type != MessageType.system && !message.isDeleted)
              SeedListCell(
                leadingIcon: Icons.event_available_outlined,
                title: '일정 등록',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _showAddScheduleFromMessage(message);
                },
              ),
            if (isMyMessage &&
                !message.isDeleted &&
                message.type == MessageType.text)
              SeedListCell(
                leadingIcon: Icons.edit,
                title: '수정',
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _startEditing(message);
                },
              ),
            if (isMyMessage && !message.isDeleted)
              SeedListCell(
                leadingIcon: Icons.delete,
                title: '삭제',
                isDestructive: true,
                showChevron: false,
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
          ],
        ),
          ),
        ),
      ),
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

  // 리액션 표시 위젯
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
                vertical: AppSpacing.space1,
              ),
              decoration: BoxDecoration(
                color: reaction.myReaction
                    ? AppSemanticColors.interactivePrimaryDefault.withValues(
                        alpha: 0.2,
                      )
                    : AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
                border: Border.all(
                  color: reaction.myReaction
                      ? AppSemanticColors.interactivePrimaryDefault
                      : AppSemanticColors.borderDefault,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.emoji,
                    style: const TextStyle(fontSize: AppTypography.fontSizeBase),
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    '${reaction.count}',
                    style: AppTypography.labelSmall.copyWith(
                      color: reaction.myReaction
                          ? AppSemanticColors.interactivePrimaryDefault
                          : AppSemanticColors.textSecondary,
                      fontWeight: reaction.myReaction
                          ? FontWeight.bold
                          : FontWeight.normal,
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
  Future<void> _downloadAndOpenFile(String? url, String fileName) async {
    if (url == null || url.isEmpty) {
      AppSnackBar.showError(context, message: '파일 URL이 없습니다');
      return;
    }

    // 다운로드 진행 표시
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
            Text('다운로드 중...', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.space2),
            Text(
              fileName,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    try {
      // 저장 경로 설정
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // 파일 다운로드
      final dioClient = dio.Dio();
      await dioClient.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('[Download] ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      // 파일 열기
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        if (mounted) {
          AppSnackBar.showError(context,
              message: '파일을 열 수 없습니다: ${result.message}');
        }
      }
    } catch (e) {
      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      print('[Download] 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '다운로드 실패: $e');
      }
    }
  }

  void _showMessageReaders(ChatMessage message) async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadMessageReaders(widget.room.id, message.id);

    if (!mounted) return;

    AppBottomSheet.show(
      context,
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
                    '읽은 사람 (${readers.length}명)',
                    style: AppTypography.heading6,
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
                          style: AppTypography.labelSmall.copyWith(
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
        backgroundColor: AppSemanticColors.backgroundSecondary,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.room.name,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppSemanticColors.textPrimary,
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
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    );
                  }
                  return Text(
                    '${widget.room.participantCount}명',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  );
                },
              ),
            ],
          ),
          backgroundColor: AppSemanticColors.surfaceDefault,
          foregroundColor: AppSemanticColors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: '더보기',
              // 기본 Material 팝업 대신 앱 공통 액션 시트 (다른 ⋮ 메뉴와 같은 문법)
              onPressed: () => showAppActionSheet(
                context,
                title: widget.room.name,
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
                child: Consumer<ChatProvider>(
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
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
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

    return KeyedSubtree(
      key: itemKey,
      child: Column(
        children: [
          if (showDateSeparator) _buildDateSeparator(message.createdAt),
          _buildMessageBubble(
            // 시각·읽음 표시는 묶음의 **가장 최신** 사진 기준으로 보여준다.
            groupMessages == null ? message : groupMessages.last,
            isMyMessage,
            showSenderName,
            isAdmin,
            chatProvider.participants,
            photoGroup: groupMessages,
          ),
        ],
      ),
    );
  }

  /// 시스템 메시지 (가운데 정렬, 시간 없음)
  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        child: Text(
          message.displayContent,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 날짜 구분선 — 가운데 정렬, 옅은 배경의 알약 모양.
  /// 시스템 메시지 알약(_buildSystemMessage)과 톤을 맞추되 글자 스타일로 구분한다.
  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(
          formatDateSeparatorLabel(date),
          style: AppTypography.labelSmall.copyWith(
            color: AppSemanticColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
  }) {
    final bubbleColor = isMyMessage
        ? AppSemanticColors.interactivePrimaryDefault
        : AppSemanticColors.surfaceDefault;

    final textColor = isMyMessage
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

    // 말풍선(+리액션) 본체 — 내/남 메시지 공통.
    final bubble = Column(
      crossAxisAlignment: isMyMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: sendingStatus == MessageSendingStatus.sending
                ? bubbleColor.withValues(alpha: 0.7)
                : bubbleColor,
            // 배경(gray50)과 남의 말풍선(흰색)은 명도차가 거의 없어 그냥 두면
            // 경계가 안 보인다. 검은 테두리는 앱 톤에서 튀므로 옅은 회색
            // 실선(borderDefault) 한 겹으로만 경계를 만든다.
            border: isMyMessage
                ? null
                : Border.all(
                    color: AppSemanticColors.borderDefault,
                    width: 1,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppBorderRadius.xl),
              topRight: const Radius.circular(AppBorderRadius.xl),
              bottomLeft: Radius.circular(
                isMyMessage ? AppBorderRadius.xl : AppBorderRadius.base,
              ),
              bottomRight: Radius.circular(
                isMyMessage ? AppBorderRadius.base : AppBorderRadius.xl,
              ),
            ),
          ),
          constraints: BoxConstraints(maxWidth: _bubbleMaxWidth(context)),
          child: photoGroup != null
              ? ChatPhotoGroup(
                  messages: photoGroup,
                  // 말풍선 좌우 안쪽 여백(space3 * 2)을 뺀 실제 그릴 수 있는 폭
                  maxWidth: _bubbleContentWidth(context, isMyMessage),
                  onTap: (i) => _openPhotoGroup(photoGroup, i),
                  onLongPress: (i) => _showMessageOptions(photoGroup[i]),
                )
              : message.type == MessageType.system
              ? Text(
                  message.displayContent,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : _buildMessageContent(message, textColor, isMyMessage),
        ),
        // 리액션 표시
        if (message.reactions.isNotEmpty)
          _buildReactionDisplay(message, isMyMessage),
      ],
    );

    // 시각·읽음 표시 열.
    // 읽음 표시는 누가 보냈든 똑같이 뜬다 — 내 메시지에만 두면
    // 상대 메시지를 아직 누가 안 봤는지 알 수 없다.
    Widget metaColumn({required bool alignEnd}) {
      return Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (unreadCount > 0 &&
              sendingStatus != MessageSendingStatus.failed)
            Text(
              '$unreadCount',
              style: AppTypography.labelSmall.copyWith(
                color: isAdmin
                    ? AppSemanticColors.textSecondary
                    : AppSemanticColors.interactivePrimaryDefault,
                fontWeight: FontWeight.bold,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyMessage) ...[
                _buildSendingStatusIcon(sendingStatus, isAdmin),
                const SizedBox(width: 2),
              ],
              Text(
                _formatMessageTime(message.createdAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        child: isMyMessage
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  metaColumn(alignEnd: true),
                  const SizedBox(width: AppSpacing.space1),
                  Flexible(child: bubble),
                ],
              )
            // 남의 메시지 — 카톡 배치.
            //   [아바타]  이름 (직종)
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(child: bubble),
                            const SizedBox(width: AppSpacing.space1),
                            metaColumn(alignEnd: false),
                          ],
                        ),
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

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.space2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: textColor.withValues(alpha: 0.35), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.replyToSenderName ?? '',
            style: AppTypography.labelSmall.copyWith(
              color: textColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: textColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBody(
    ChatMessage message,
    Color textColor,
    bool isMyMessage,
  ) {
    if (message.isDeleted) {
      return Text(
        '삭제된 메시지입니다',
        style: AppTypography.bodyMedium.copyWith(
          color: textColor.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
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
                    final placeholderWidth = _bubbleMaxWidth(context);
                    final placeholderHeight = placeholderWidth * 0.75;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      child: CachedNetworkImage(
                        imageUrl: _chatImageUrl(message)!,
                        fit: BoxFit.cover,
                        // 말풍선 최대 폭보다 큰 원본을 그대로 디코드하지 않도록 제한
                        memCacheWidth: (placeholderWidth * 2).round(),
                        placeholder: (context, url) => SizedBox(
                          width: placeholderWidth,
                          height: placeholderHeight,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return SizedBox(
                            width: placeholderWidth,
                            height: placeholderHeight,
                            child: Container(
                              color: AppSemanticColors.backgroundTertiary,
                              child: Icon(
                                Icons.broken_image,
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
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
            maxWidth: _bubbleContentWidth(context, isMyMessage),
            onTap: () => _openAttachment(message),
          );
        }

        final isVideo = _isVideoFileName(message.fileName ?? '');
        return GestureDetector(
          onTap: () => _openAttachment(message),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.play_circle_outline : Icons.attach_file,
                color: textColor,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.space1),
              Flexible(
                child: Text(
                  isVideo ? '동영상 · ${message.fileName ?? ''}' : (message.fileName ?? '파일'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );

      case MessageType.text:
        if (message.editedAt != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextWithMentions(message.content ?? '', textColor),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '수정됨',
                  style: AppTypography.bodySmall.copyWith(
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          );
        }
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
              fontWeight: FontWeight.w600,
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
          spans.add(TextSpan(text: text.substring(cursor, match.start)));
        }

        final mention = match.group(0)!;
        final isMe = myName.isNotEmpty && mention == '@$myName';

        spans.add(
          TextSpan(
            text: mention,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: isMe
                  ? AppSemanticColors.statusWarningBackground
                  : null,
              color: isMe ? AppSemanticColors.statusWarningText : textColor,
            ),
          ),
        );
        cursor = match.end;
      }

      if (cursor < text.length) {
        spans.add(TextSpan(text: text.substring(cursor)));
      }
    }

    return RichText(
      text: TextSpan(
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

  String _formatMessageTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period $displayHour:$minute';
  }

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
        children: [
          // 첨부 버튼 (사진/파일)
          IconButton(
            tooltip: '파일 첨부',
            onPressed: _showAttachmentOptions,
            icon: Icon(
              Icons.add_circle_outline,
              color: AppSemanticColors.textTertiary,
            ),
          ),

          // 메시지 입력 필드
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
              ),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space3,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.space2),

          // 전송 버튼 — Material+InkWell로 눌림 피드백 부여
          Material(
            color: AppSemanticColors.interactivePrimaryDefault,
            shape: const CircleBorder(),
            child: Semantics(
              button: true,
              label: '메시지 전송',
              child: InkWell(
              onTap: _sendMessage,
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
        borderRadius: BorderRadius.circular(AppBorderRadius.base),
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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    fontWeight: FontWeight.bold,
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
        borderRadius: BorderRadius.circular(AppBorderRadius.base),
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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    fontWeight: FontWeight.bold,
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
              size: AppSpacing.space5,
              color: AppSemanticColors.textTertiary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
