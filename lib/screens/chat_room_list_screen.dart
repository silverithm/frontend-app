import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../models/chat_room.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/common/app_action_sheet.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/chat/chat_room_avatar_stack.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/chat/chat_member_list.dart';
import 'chat_room_screen.dart';
import 'create_chat_room_screen.dart';

class ChatRoomListScreen extends StatefulWidget {
  /// 알림을 눌러 들어온 경우 그 방까지 바로 연다.
  /// 목록만 띄우면 "알림 → 그 대화"가 되지 않아 사용자가 방을 다시 찾아야 한다.
  final int? initialRoomId;

  const ChatRoomListScreen({super.key, this.initialRoomId});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // dispose 안전을 위해 provider 캐시
  late final ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadChatRooms();
      _connectWebSocket();
      // 이 화면이 떠 있는 동안 참여 중인 모든 방의 메시지를 실시간으로 받아
      // 목록의 미리보기/정렬이 수동 새로고침 없이 갱신되도록 한다.
      _chatProvider.subscribeToRoomList();
      _openInitialRoomIfAny();
    });
  }

  /// 알림으로 지목된 방을 목록을 받은 뒤에 연다.
  /// 방 정보(이름·참여 인원)가 있어야 대화 화면을 열 수 있어 목록 로드를 기다린다.
  /// 목록에 없으면(방금 초대된 방이 아직 목록에 안 잡힌 경우 등) 그 방 하나만 따로 받는다.
  Future<void> _openInitialRoomIfAny() async {
    final roomId = widget.initialRoomId;
    if (roomId == null || !mounted) return;

    var target = findChatRoomById(_chatProvider.chatRooms, roomId);
    if (target == null) {
      try {
        final response = await ApiService().getChatRoomDetail(roomId: roomId);
        final json = response['room'] ?? response;
        if (json is Map<String, dynamic>) target = ChatRoom.fromJson(json);
      } catch (e) {
        // 나간 방·삭제된 방 — 목록만 보여준다. 빈 화면으로 보내지 않는다
        debugPrint('[ChatRoomList] 알림의 방($roomId)을 찾지 못했습니다: $e');
      }
    }
    if (target != null && mounted) _navigateToChatRoom(target);
  }

  @override
  void dispose() {
    _chatProvider.unsubscribeFromRoomList();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChatRooms() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (authProvider.currentUser != null) {
      final companyId = authProvider.currentUser!.company?.id ?? '1';
      final userId = authProvider.currentUser!.chatUserId;

      await chatProvider.loadChatRooms(companyId: companyId, userId: userId);
    }
  }

  Future<void> _connectWebSocket() async {
    if (!mounted) return;
    final chatProvider = context.read<ChatProvider>();
    try {
      await chatProvider.connectWebSocket();
    } catch (e) {
      // 소켓 연결 실패가 목록 화면 자체를 죽이면 안 된다 —
      // 목록은 REST로 이미 떠 있고, 소켓은 다음 진입·재시도에서 다시 붙는다
      debugPrint('[ChatRoomList] 웹소켓 연결 실패: $e');
    }
  }

  void _navigateToChatRoom(ChatRoom room) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.selectRoom(room);

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)));
  }

  void _navigateToCreateChatRoom() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreateChatRoomScreen()))
        .then((created) {
          if (created == true) {
            _loadChatRooms();
          }
        });
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return '어제';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${time.month}/${time.day}';
    }

    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('채팅', style: AppTypography.heading5),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppSemanticColors.headerForeground),
            onPressed: _navigateToCreateChatRoom,
            tooltip: '새 채팅방',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppSemanticColors.headerForeground,
          unselectedLabelColor: AppSemanticColors.headerForegroundMuted,
          indicatorColor: AppSemanticColors.headerTabIndicator,
          labelStyle: AppTypography.labelLarge.copyWith(
            fontWeight: AppTypography.fontWeightBold,
          ),
          unselectedLabelStyle: AppTypography.labelLarge,
          // 상단 바 아래 선은 AppBar가 긋는다
          dividerColor: AppColors.transparent,
          tabs: const [
            Tab(text: '대화'),
            Tab(text: '직원'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomsTab(isAdmin),
          ChatMemberList(onOpenRoom: _navigateToChatRoom),
        ],
      ),
    );
  }

  Widget _buildRoomsTab(bool isAdmin) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading && chatProvider.chatRooms.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppSemanticColors.interactivePrimaryDefault,
            ),
          );
        }

        if (chatProvider.errorMessage.isNotEmpty &&
            chatProvider.chatRooms.isEmpty) {
          return _buildErrorState();
        }

        if (chatProvider.chatRooms.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _loadChatRooms,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
            itemCount: chatProvider.chatRooms.length,
            itemBuilder: (context, index) {
              final rooms = chatProvider.chatRooms;
              final room = rooms[index];
              final tile = _buildChatRoomTile(room, isAdmin);
              // 고정한 방 묶음의 끝에 구분선 — 고정 방은 목록 맨 위에 모여 있다
              final isLastPinned = room.pinned &&
                  (index + 1 >= rooms.length || !rooms[index + 1].pinned);
              if (!isLastPinned) return tile;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tile,
                  Container(height: 1, color: AppSemanticColors.subheaderBorder),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: '아직 채팅방이 없어요',
      description: '+ 버튼으로 첫 채팅을 시작해보세요',
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: AppSpacing.space12,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '채팅방 목록을 불러오지 못했습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.small,
            onPressed: _loadChatRooms,
          ),
        ],
      ),
    );
  }

  /// 목록에서 방을 길게 누르면 뜨는 액션 시트 — 카카오톡처럼 여기서 바로
  /// 나가기(+관리자면 삭제)까지 갈 수 있어야 한다. 채팅방에 들어가서 정보
  /// 화면까지 열어야만 나갈 수 있으면 사용자가 "기능이 없다"고 느낀다.
  void _showRoomActions(ChatRoom room, bool isAdmin) {
    showAppActionSheet(
      context,
      title: room.name,
      actions: [
        AppSheetAction(
          icon: room.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: room.pinned ? '고정 해제' : '상단 고정',
          onSelected: () => _togglePin(room),
        ),
        AppSheetAction(
          icon: Icons.logout,
          label: '채팅방 나가기',
          onSelected: () => _confirmLeaveRoom(room),
        ),
        if (isAdmin)
          AppSheetAction(
            icon: Icons.delete_outline,
            label: '채팅방 삭제',
            isDestructive: true,
            onSelected: () => _confirmDeleteRoom(room),
          ),
      ],
    );
  }

  Future<void> _togglePin(ChatRoom room) async {
    final chatProvider = context.read<ChatProvider>();
    final willPin = !room.pinned;

    final success = await chatProvider.togglePin(room);
    if (!mounted) return;

    if (success) {
      AppSnackBar.showSuccess(
        context,
        message: willPin ? '상단에 고정했어요' : '고정을 풀었어요',
      );
    } else {
      final errorMessage = chatProvider.errorMessage.isNotEmpty
          ? chatProvider.errorMessage
          : '상단 고정 변경에 실패했습니다.';
      AppSnackBar.showError(context, message: errorMessage);
    }
  }

  Future<void> _confirmLeaveRoom(ChatRoom room) async {
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

    final success = await chatProvider.leaveRoom(room.id, userId);
    if (!mounted) return;

    if (!success) {
      final errorMessage = chatProvider.errorMessage.isNotEmpty
          ? chatProvider.errorMessage
          : '채팅방 나가기에 실패했습니다.';
      AppSnackBar.showError(context, message: errorMessage);
    }
  }

  Future<void> _confirmDeleteRoom(ChatRoom room) async {
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
    final success = await chatProvider.deleteChatRoom(room.id);
    if (!mounted) return;

    if (!success) {
      final errorMessage = chatProvider.errorMessage.isNotEmpty
          ? chatProvider.errorMessage
          : '채팅방 삭제에 실패했습니다.';
      AppSnackBar.showError(context, message: errorMessage);
    }
  }

  /// 대화 목록 한 줄 — 높이 72(위아래 12 + 아바타 48).
  /// 제목 titleMedium(15/w600, 읽음 여부로 굵기를 바꾸지 않는다) · 미리보기 bodyMedium 14 ·
  /// 시간·인원 bodySmall 12. 고정 핀은 제목 앞이 아니라 시간 옆에 둬서 제목이 모든 줄에서
  /// 같은 x에서 시작한다. 구분선은 글자가 시작하는 자리부터.
  Widget _buildChatRoomTile(ChatRoom room, bool isAdmin) {
    const avatarSize = 48.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _navigateToChatRoom(room),
          onLongPress: () => _showRoomActions(room, isAdmin),
          child: Container(
            // 고정한 방은 연한 틸 바탕으로 구분한다
            color: room.pinned ? AppColors.careTealTint : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            child: Row(
              children: [
                // 채팅방 아바타/썸네일
                // 참여자 얼굴을 모아 보여준다 (카카오톡과 같은 방식).
                // 참여자를 못 받은 방은 위젯이 알아서 방 이름 첫 글자로 그린다.
                ChatRoomAvatarStack(
                  roomName: room.name,
                  avatars: room.avatars,
                  size: avatarSize,
                ),
                const SizedBox(width: AppSpacing.space3),

                // 채팅방 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.participantCount > 0) ...[
                            const SizedBox(width: AppSpacing.space1),
                            Text(
                              '${room.participantCount}명',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space0_5),
                      // 안 읽은 방은 굵기가 아니라 빨간 숫자 하나로만 알린다
                      Text(
                        room.lastMessage?.displayContent ?? '새로운 채팅방',
                        style: AppTypography.bodyMedium.copyWith(
                          color: room.unreadCount > 0
                              ? AppSemanticColors.textSecondary
                              : AppSemanticColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 시간 및 안읽은 수
                const SizedBox(width: AppSpacing.space2),
                SizedBox(
                  height: avatarSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (room.pinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: AppSpacing.space3,
                              color: AppColors.careTeal,
                            ),
                            const SizedBox(width: AppSpacing.space1),
                          ],
                          Text(
                            _formatLastMessageTime(
                              room.lastMessageAt ?? room.createdAt,
                            ),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (room.unreadCount > 0)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: AppSpacing.space5,
                            minHeight: AppSpacing.space5,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space1_5,
                          ),
                          // 안 읽은 수는 아래 탭·알림 종·웹 채팅 목록과 같은 빨강 — 틸은 '누르라'는 단추 색이다
                          decoration: BoxDecoration(
                            color: AppSemanticColors.statusErrorIcon,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.full,
                            ),
                          ),
                          child: Text(
                            room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                            style: AppTypography.labelStrong.copyWith(
                              color: AppSemanticColors.textInverse,
                              height: 1.2,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          indent: AppSpacing.space4 + avatarSize + AppSpacing.space3,
          color: AppSemanticColors.borderSubtle,
        ),
      ],
    );
  }
}

/// 알림이 가리킨 방을 받은 목록에서 찾는다(없으면 null).
ChatRoom? findChatRoomById(List<ChatRoom> rooms, int roomId) {
  for (final room in rooms) {
    if (room.id == roomId) return room;
  }
  return null;
}
