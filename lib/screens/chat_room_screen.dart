import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:open_filex/open_filex.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import 'chat_room_info_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

enum _ChatRoomMenuAction { info, delete }

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
        userId: _authProvider.currentUser?.id ?? '',
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
        userId: authProvider.currentUser?.id ?? '',
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
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final hasText = _messageController.text.trim().isNotEmpty;
    final userId = authProvider.currentUser?.id ?? '';
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id ?? '';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.interactivePrimaryDefault
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: AppSemanticColors.interactivePrimaryDefault,
                    ),
                  ),
                  title: Text(
                    '사진',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '갤러리에서 사진 선택',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendPhoto();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusWarningIcon.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.insert_drive_file,
                      color: AppSemanticColors.statusWarningIcon,
                    ),
                  ),
                  title: Text(
                    '파일',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '문서, PDF 등 파일 선택',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 10MB 상수 (바이트)
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB

  Future<void> _pickAndSendPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        File file = File(image.path);
        final fileSize = await file.length();

        print(
          '[ChatRoomScreen] 선택된 파일: ${image.name}, 크기: ${_formatFileSize(fileSize)} ($fileSize bytes)',
        );

        // 10MB 초과시 압축
        if (fileSize > _maxFileSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '파일 크기가 ${_formatFileSize(fileSize)}입니다. 자동으로 압축 중...',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }

          final compressedFile = await _compressImage(file, fileSize);
          if (compressedFile != null) {
            file = compressedFile;
            final compressedSize = await file.length();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '압축 완료: ${_formatFileSize(fileSize)} → ${_formatFileSize(compressedSize)}',
                  ),
                  backgroundColor: AppSemanticColors.statusSuccessIcon,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('이미지 압축에 실패했습니다. 다른 이미지를 선택해주세요.'),
                  backgroundColor: AppSemanticColors.statusErrorIcon,
                ),
              );
            }
            return;
          }
        }

        // 전송 전 최종 파일 크기 확인
        final finalSize = await file.length();
        print(
          '[ChatRoomScreen] 전송할 파일 크기: ${_formatFileSize(finalSize)} ($finalSize bytes)',
        );

        final chatProvider = context.read<ChatProvider>();
        final authProvider = context.read<AuthProvider>();
        await chatProvider.sendFileMessage(
          widget.room.id,
          file,
          senderId: authProvider.currentUser?.id ?? '',
          senderName: authProvider.currentUser?.name ?? '',
        );
      }
    } catch (e) {
      print('[ChatRoomScreen] 사진 선택 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 선택에 실패했습니다: $e')));
      }
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

  Future<void> _pickAndSendFile() async {
    try {
      // 문서 파일만 허용 (SAF API 사용 - 권한 불필요)
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );
      final XFile? result = await openFile(acceptedTypeGroups: [typeGroup]);

      if (result != null) {
        File file = File(result.path);
        final fileSize = await file.length();

        // 문서 파일은 10MB 초과시 업로드 불가
        if (fileSize > _maxFileSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '파일 크기가 너무 큽니다 (${_formatFileSize(fileSize)}). 최대 10MB까지 업로드 가능합니다.',
                ),
                backgroundColor: AppSemanticColors.statusErrorIcon,
              ),
            );
          }
          return;
        }

        final chatProvider = context.read<ChatProvider>();
        final authProvider = context.read<AuthProvider>();
        await chatProvider.sendFileMessage(
          widget.room.id,
          file,
          senderId: authProvider.currentUser?.id ?? '',
          senderName: authProvider.currentUser?.name ?? '',
        );
      }
    } catch (e) {
      print('[ChatRoomScreen] 파일 선택 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일 선택에 실패했습니다: $e')));
      }
    }
  }

  void _showRoomInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomInfoScreen(room: widget.room)),
    );
  }

  Future<void> _confirmDeleteChatRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('채팅방 삭제'),
        content: const Text('이 채팅방을 삭제하시겠습니까?\n삭제 후에는 채팅방을 다시 열 수 없습니다.'),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage)));
  }

  Future<void> _handleRoomMenuAction(_ChatRoomMenuAction action) async {
    switch (action) {
      case _ChatRoomMenuAction.info:
        _showRoomInfo();
        return;
      case _ChatRoomMenuAction.delete:
        await _confirmDeleteChatRoom();
        return;
    }
  }

  // 자주 사용하는 이모지 목록
  static const List<String> _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _showMessageOptions(ChatMessage message) {
    final authProvider = context.read<AuthProvider>();
    final isMyMessage = message.senderId == authProvider.currentUser?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
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
                                : Colors.transparent,
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
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('복사'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 클립보드에 복사
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('읽은 사람 보기'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageReaders(message);
                },
              ),
              if (isMyMessage && !message.isDeleted)
                ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                  title: Text(
                    '삭제',
                    style: TextStyle(color: AppSemanticColors.statusErrorIcon),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // 리액션 토글
  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final userId = authProvider.currentUser?.id ?? '';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('리액션 처리 실패: $e')));
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
                  Text(reaction.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
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
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.space2),
            Text('${reaction.count}명', style: AppTypography.heading5),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reaction.userNames.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Text(
                reaction.userNames[index],
                style: AppTypography.bodyMedium,
              ),
            ),
          ),
        ),
        actions: [
          shadcn.GhostButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 파일 다운로드 및 열기
  Future<void> _downloadAndOpenFile(String? url, String fileName) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파일 URL이 없습니다')));
      return;
    }

    // 다운로드 진행 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => shadcn.AlertDialog(
        content: Column(
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('파일을 열 수 없습니다: ${result.message}')),
          );
        }
      }
    } catch (e) {
      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      print('[Download] 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('다운로드 실패: $e')));
      }
    }
  }

  void _showMessageReaders(ChatMessage message) async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadMessageReaders(widget.room.id, message.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ChatProvider>(
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
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              reader.userName.isNotEmpty
                                  ? reader.userName[0]
                                  : '?',
                            ),
                          ),
                          title: Text(reader.userName),
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
        );
      },
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?'),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
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
    final currentUserId = authProvider.currentUser?.id ?? '';

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
                  color: isAdmin
                      ? AppSemanticColors.textInverse
                      : AppSemanticColors.textPrimary,
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
                        color: isAdmin
                            ? AppSemanticColors.textInverse.withValues(
                                alpha: 0.7,
                              )
                            : AppSemanticColors.textTertiary,
                      ),
                    );
                  }
                  return Text(
                    '${widget.room.participantCount}명',
                    style: AppTypography.labelSmall.copyWith(
                      color: isAdmin
                          ? AppSemanticColors.textInverse.withValues(alpha: 0.7)
                          : AppSemanticColors.textTertiary,
                    ),
                  );
                },
              ),
            ],
          ),
          backgroundColor: isAdmin
              ? AppSemanticColors.interactivePrimaryDefault
              : AppSemanticColors.surfaceDefault,
          foregroundColor: isAdmin
              ? AppSemanticColors.textInverse
              : AppSemanticColors.textPrimary,
          elevation: 0,
          actions: [
            PopupMenuButton<_ChatRoomMenuAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleRoomMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem<_ChatRoomMenuAction>(
                  value: _ChatRoomMenuAction.info,
                  child: Text('채팅방 정보'),
                ),
                if (isAdmin)
                  const PopupMenuItem<_ChatRoomMenuAction>(
                    value: _ChatRoomMenuAction.delete,
                    child: Text('채팅 삭제'),
                  ),
              ],
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

                        // 시스템 메시지는 가운데 정렬로 별도 처리
                        if (message.type == MessageType.system) {
                          return _buildSystemMessage(message);
                        }

                        final isMyMessage = message.senderId == currentUserId;
                        final showSenderName =
                            !isMyMessage &&
                            (index == chatProvider.messages.length - 1 ||
                                chatProvider.messages[index + 1].senderId !=
                                    message.senderId);

                        return _buildMessageBubble(
                          message,
                          isMyMessage,
                          showSenderName,
                          isAdmin,
                        );
                      },
                    );
                  },
                ),
              ),

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

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isMyMessage,
    bool showSenderName,
    bool isAdmin,
  ) {
    final bubbleColor = isMyMessage
        ? AppSemanticColors.interactivePrimaryDefault
        : AppSemanticColors.surfaceDefault;

    final textColor = isMyMessage
        ? AppSemanticColors.textInverse
        : AppSemanticColors.textPrimary;

    // 안 읽은 사람 수 계산 (전체 참가자 - 읽은 사람 수)
    // 백엔드에서 발신자도 readCount에 포함됨
    final participantCount = widget.room.participantCount;
    final unreadCount = participantCount - message.readCount;

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
            if (!isMyMessage) const SizedBox(width: AppSpacing.space1),

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

            // 상대 메시지: 시간
            if (!isMyMessage) ...[
              const SizedBox(width: AppSpacing.space1),
              Text(
                _formatMessageTime(message.createdAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
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
          width: 12,
          height: 12,
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
          size: 12,
          color: AppSemanticColors.textTertiary,
        );
      case MessageSendingStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 12,
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
        return GestureDetector(
          onTap: () => _downloadAndOpenFile(
            message.fileUrl,
            message.fileName ?? 'image.png',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.fileUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  child: Image.network(
                    message.fileUrl!,
                    fit: BoxFit.cover,
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
        );

      case MessageType.file:
        return GestureDetector(
          onTap: () =>
              _downloadAndOpenFile(message.fileUrl, message.fileName ?? 'file'),
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
        return Text(
          message.content ?? '',
          style: AppTypography.bodyMedium.copyWith(color: textColor),
        );
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
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 첨부 버튼 (사진/파일)
          IconButton(
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

          // 전송 버튼
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppSemanticColors.interactivePrimaryDefault,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppSemanticColors.textInverse,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
