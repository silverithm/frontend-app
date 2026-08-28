import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
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
import '../widgets/common/app_action_sheet.dart';

enum _ChatRoomMenuAction { info, search, files, delete }

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

  @override
  void dispose() {
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final chatProvider = context.read<ChatProvider>();
      if (!chatProvider.isLoading && chatProvider.hasMoreMessages) {
        chatProvider.loadMessages(roomId: widget.room.id);
      }
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
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

    await chatProvider.sendTextMessage(
      widget.room.id,
      content,
      senderId: userId,
      senderName: userName,
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
                title: '사진',
                description: '갤러리에서 사진 선택',
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

  // 10MB 상수 (바이트)
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB

  /// 갤러리에서 사진을 여러 장 골라 한 번에 보낸다.
  /// 각 사진은 독립된 메시지 버블로 즉시 올라가 각자 전송중 표시가 붙으므로
  /// 진행 상황은 그 버블들로 보이고, 한 장이 실패해도 나머지는 계속 전송된다.
  Future<void> _pickAndSendPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) return;

      if (images.length > 1 && mounted) {
        AppSnackBar.showInfo(context, message: '사진 ${images.length}장 전송 중...');
      }

      int successCount = 0;
      int failCount = 0;

      for (final image in images) {
        final ok = await _sendPhotoFile(image);
        if (ok) {
          successCount++;
        } else {
          failCount++;
        }
      }

      if (images.length > 1 && mounted) {
        if (failCount == 0) {
          AppSnackBar.showSuccess(context, message: '사진 $successCount장 전송 완료');
        } else {
          AppSnackBar.showError(
            context,
            message: '사진 전송 완료 $successCount장 / 실패 $failCount장',
          );
        }
      }
    } catch (e) {
      print('[ChatRoomScreen] 사진 선택 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '사진 선택에 실패했습니다: $e');
      }
    }
  }

  /// 사진 한 장을 (필요하면 압축 후) 전송한다. 성공하면 true.
  Future<bool> _sendPhotoFile(XFile image) async {
    try {
      File file = File(image.path);
      final fileSize = await file.length();

      print(
        '[ChatRoomScreen] 선택된 파일: ${image.name}, 크기: ${_formatFileSize(fileSize)} ($fileSize bytes)',
      );

      // 10MB 초과시 압축
      if (fileSize > _maxFileSize) {
        final compressedFile = await _compressImage(file, fileSize);
        if (compressedFile != null) {
          file = compressedFile;
        } else {
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: '${image.name} 압축에 실패해 전송하지 못했습니다.',
            );
          }
          return false;
        }
      }

      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      return await chatProvider.sendFileMessage(
        widget.room.id,
        file,
        senderId: authProvider.currentUser?.chatUserId ?? '',
        senderName: authProvider.currentUser?.name ?? '',
      );
    } catch (e) {
      print('[ChatRoomScreen] 사진 전송 에러: $e');
      return false;
    }
  }

  /// 이미지 압축 메서드 - 10MB 미만이 될 때까지 압축
  Future<File?> _compressImage(File file, int originalSize) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${tempDir.path}/$fileName';

      // 목표 크기: 9MB (여유분 확보)
      const int targetSize = 9 * 1024 * 1024;

      // 압축 품질 계산 (파일 크기에 따라 조절)
      int quality = 85;
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

      XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1920,
        minHeight: 1920,
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

      int successCount = 0;
      int failCount = 0;

      for (final result in results) {
        final ok = await _sendDocumentFile(result);
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
  Future<bool> _sendDocumentFile(XFile result) async {
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
    AppBottomSheet.show(
      context,
      child: SafeArea(
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

                          return SeedListCell(
                            leading: isImage && file.fileUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.md,
                                    ),
                                    child: Image.network(
                                      file.fileUrl!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      // 44dp 썸네일에 원본 해상도를 그대로 디코드하지 않도록 제한
                                      cacheWidth: 88,
                                      cacheHeight: 88,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_outlined),
                                    ),
                                  )
                                : Icon(
                                    Icons.insert_drive_file_outlined,
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
      isImage: message.type == MessageType.image,
    );
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
  static const List<String> _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _showMessageOptions(ChatMessage message) {
    final authProvider = context.read<AuthProvider>();
    final isMyMessage = message.senderId == authProvider.currentUser?.chatUserId;
    final rootContext = context;

    AppBottomSheet.show(
      context,
      child: SafeArea(
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

          return SafeArea(
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

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];
                        // localId → id 순으로 안정된 키를 준다. 전송 중(sending) 메시지가
                        // 서버 확정 메시지로 교체돼도 같은 자리로 인식되게 한다.
                        final itemKey = ValueKey(
                          message.localId ?? message.id,
                        );

                        // 시스템 메시지는 가운데 정렬로 별도 처리
                        if (message.type == MessageType.system) {
                          return KeyedSubtree(
                            key: itemKey,
                            child: _buildSystemMessage(message),
                          );
                        }

                        final isMyMessage = message.senderId == currentUserId;
                        final showSenderName =
                            !isMyMessage &&
                            (index == chatProvider.messages.length - 1 ||
                                chatProvider.messages[index + 1].senderId !=
                                    message.senderId);

                        return KeyedSubtree(
                          key: itemKey,
                          child: _buildMessageBubble(
                            message,
                            isMyMessage,
                            showSenderName,
                            isAdmin,
                            chatProvider.participants,
                          ),
                        );
                      },
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
    List<ChatParticipant> participants,
  ) {
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
    final unreadCount = participants.isEmpty
        ? widget.room.participantCount - message.readCount
        : participants
              .where(
                (p) =>
                    p.userId != message.senderId &&
                    (p.lastReadMessageId ?? 0) < message.id,
              )
              .length;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        child: Row(
          mainAxisAlignment: isMyMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMyMessage) ...[
              const SizedBox(width: AppSpacing.space1),
              // 상대방 아바타 — 연속 메시지 그룹의 이름 표시 시점(showSenderName)에만 노출
              showSenderName
                  ? SeedAvatar(
                      name: message.senderName,
                      imageUrl: _findSenderProfileImageUrl(
                        message.senderId,
                        participants,
                      ),
                      size: SeedAvatarSize.small,
                    )
                  : const SizedBox(width: AppSpacing.space8),
              const SizedBox(width: AppSpacing.space2),
            ],

            // 내 메시지: 전송 상태 + 안읽은 수 + 시간
            if (isMyMessage) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 안 읽은 사람 수 (0보다 클 때만, 실패 상태 제외)
                  if (unreadCount > 0 &&
                      message.sendingStatus != MessageSendingStatus.failed)
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
                      // 전송 상태 아이콘
                      _buildSendingStatusIcon(message.sendingStatus, isAdmin),
                      const SizedBox(width: 2),
                      Text(
                        _formatMessageTime(message.createdAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.space1),
            ],

            // 메시지 버블
            Flexible(
              child: Column(
                crossAxisAlignment: isMyMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showSenderName && !isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.space2,
                        bottom: AppSpacing.space1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.senderName,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                          if (message.senderPosition?.trim().isNotEmpty ??
                              false)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.space0_5,
                              ),
                              child: Text(
                                message.senderPosition!.trim(),
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space3,
                      vertical: AppSpacing.space2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          message.sendingStatus == MessageSendingStatus.sending
                          ? bubbleColor.withValues(alpha: 0.7)
                          : bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppBorderRadius.xl),
                        topRight: const Radius.circular(AppBorderRadius.xl),
                        bottomLeft: Radius.circular(
                          isMyMessage
                              ? AppBorderRadius.xl
                              : AppBorderRadius.base,
                        ),
                        bottomRight: Radius.circular(
                          isMyMessage
                              ? AppBorderRadius.base
                              : AppBorderRadius.xl,
                        ),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: message.type == MessageType.system
                        ? Text(
                            message.displayContent,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _buildMessageContent(message, textColor),
                  ),
                  // 리액션 표시
                  if (message.reactions.isNotEmpty)
                    _buildReactionDisplay(message, isMyMessage),
                ],
              ),
            ),

            // 상대 메시지: 안읽은 수 + 시간
            // 읽음 표시는 누가 보냈든 똑같이 뜬다 — 내 메시지에만 두면
            // 상대 메시지를 아직 누가 안 봤는지 알 수 없다
            if (!isMyMessage) ...[
              const SizedBox(width: AppSpacing.space1),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unreadCount > 0)
                    Text(
                      '$unreadCount',
                      style: AppTypography.labelSmall.copyWith(
                        color: isAdmin
                            ? AppSemanticColors.textSecondary
                            : AppSemanticColors.interactivePrimaryDefault,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildMessageContent(ChatMessage message, Color textColor) {
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
              if (message.fileUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  child: Image.network(
                    message.fileUrl!,
                    fit: BoxFit.cover,
                    // 말풍선 최대 폭(화면의 70%)보다 큰 원본을 그대로 디코드하지 않도록 제한
                    cacheWidth:
                        (MediaQuery.of(context).size.width * 0.7 * 2).round(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: AppSemanticColors.backgroundTertiary,
                        child: Icon(
                          Icons.broken_image,
                          color: AppSemanticColors.textTertiary,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          ),
        );

      case MessageType.file:
        return GestureDetector(
          onTap: () => _openAttachment(message),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file, color: textColor, size: 18),
              const SizedBox(width: AppSpacing.space1),
              Flexible(
                child: Text(
                  message.fileName ?? '파일',
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
      case MessageType.system:
        return _buildTextWithMentions(message.content ?? '', textColor);
    }
  }

  /// '@이름'을 굵게 칠해 눈에 띄게 한다. 내가 불린 경우는 배경까지 넣는다.
  Widget _buildTextWithMentions(String content, Color textColor) {
    final myName = context.read<AuthProvider>().currentUser?.name ?? '';
    final matches = RegExp(r'@[^\s@]+').allMatches(content).toList();

    if (matches.isEmpty) {
      return Text(
        content,
        style: AppTypography.bodyMedium.copyWith(color: textColor),
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, match.start)));
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

    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: AppTypography.bodyMedium.copyWith(color: textColor),
        children: spans,
      ),
    );
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
      child: Row(
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
                    Icons.send_rounded,
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
    );
  }
}
