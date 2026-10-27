import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_snackbar.dart';
import '../seed/seed_avatar.dart';

/// 1:1 방 이름 — 웹과 같은 규칙을 써야 같은 방을 찾아 들어간다.
String directRoomName(String memberName) => '$memberName 님과의 대화';

/// 기관 사람들을 접속 중인 순서로 보여주고, 누르면 1:1 대화를 연다.
class ChatMemberList extends StatefulWidget {
  final void Function(ChatRoom room) onOpenRoom;

  const ChatMemberList({super.key, required this.onOpenRoom});

  @override
  State<ChatMemberList> createState() => _ChatMemberListState();
}

class _ChatMemberListState extends State<ChatMemberList> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isOpening = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
      context.read<ChatProvider>().loadOnlineUsers();
    });
  }

  Future<void> _loadMembers() async {
    final companyId = context.read<AuthProvider>().currentUser?.company?.id;
    if (companyId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '기관 정보를 찾을 수 없습니다';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService().getCompanyMembers(
        companyId: companyId,
      );
      final list =
          response['members'] as List<dynamic>? ??
          response['content'] as List<dynamic>? ??
          [];

      if (!mounted) return;
      setState(() {
        _members = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '직원 목록을 불러오지 못했습니다';
      });
    }
  }

  Future<void> _refresh() async {
    unawaited(context.read<AuthProvider>().refreshProfileFromServer());
    await _loadMembers();
    if (mounted) await context.read<ChatProvider>().loadOnlineUsers();
  }

  /// 이미 있는 1:1 방이면 그곳으로, 없으면 새로 만든다.
  Future<void> _openDirectChat(String memberId, String memberName) async {
    if (_isOpening) return;

    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final myId = authProvider.currentUser?.id ?? '';
    final myName = authProvider.currentUser?.name ?? '';
    final companyId = authProvider.currentUser?.company?.id ?? '';
    final roomName = directRoomName(memberName);

    ChatRoom? existing;
    for (final room in chatProvider.chatRooms) {
      if (room.participantCount == 2 && room.name == roomName) {
        existing = room;
        break;
      }
    }

    if (existing != null) {
      widget.onOpenRoom(existing);
      return;
    }

    setState(() => _isOpening = true);
    final created = await chatProvider.createChatRoom(
      companyId: companyId,
      name: roomName,
      description: '1:1 대화',
      createdBy: myId,
      createdByName: myName,
      participantIds: [memberId, myId].toSet().toList(),
    );

    if (!mounted) return;
    setState(() => _isOpening = false);

    if (created == null) {
      AppSnackBar.showError(context, message: '대화를 열지 못했습니다');
      return;
    }
    widget.onOpenRoom(created);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
      );
    }

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final myId = context.read<AuthProvider>().currentUser?.id ?? '';

        // 나를 뺀 나머지를 접속 중인 사람부터, 그다음 이름순으로 정렬한다
        final others =
            _members.where((m) => m['id']?.toString() != myId).toList()..sort((
              a,
              b,
            ) {
              final aOnline = chatProvider.isOnline(a['id']?.toString() ?? '');
              final bOnline = chatProvider.isOnline(b['id']?.toString() ?? '');
              if (aOnline != bOnline) return aOnline ? -1 : 1;
              return (a['name']?.toString() ?? '').compareTo(
                b['name']?.toString() ?? '',
              );
            });

        final onlineCount = others
            .where((m) => chatProvider.isOnline(m['id']?.toString() ?? ''))
            .length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
            children: [
              _buildMyProfileTile(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space4,
                  AppSpacing.space3,
                  AppSpacing.space4,
                  AppSpacing.space2,
                ),
                child: Text(
                  '직원 ${others.length}명 · 접속 중 $onlineCount명',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ),
              ...others.map((member) {
                final id = member['id']?.toString() ?? '';
                return _buildMemberTile(
                  id: id,
                  name: member['name']?.toString() ?? '',
                  position: member['position']?.toString(),
                  imageUrl: member['profileImageUrl']?.toString(),
                  isOnline: chatProvider.isOnline(id),
                  onTap: () =>
                      _openDirectChat(id, member['name']?.toString() ?? ''),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyProfileTile() {
    final me = context.watch<AuthProvider>().currentUser;
    final myPosition = (me?.position ?? '').isNotEmpty ? me!.position! : null;
    return Container(
      color: AppSemanticColors.backgroundSecondary,
      child: _buildMemberTile(
        id: me?.id ?? '',
        name: me?.name ?? '나',
        position: myPosition != null ? '$myPosition (나)' : '나',
        imageUrl: me?.profileImageUrl,
        // 내가 이 화면을 보고 있다는 것 자체가 접속 중이라는 뜻
        isOnline: true,
        onTap: null,
      ),
    );
  }

  /// 사람 한 줄 — 높이 64(위아래 12 + 아바타 40). 이름 titleMedium + 직종 bodySmall을 한 줄에.
  /// 접속 중이면 아바타에 초록 점만 단다(점이 없으면 오프라인 — "오프라인" 문구를 줄마다 반복하지 않는다).
  Widget _buildMemberTile({
    required String id,
    required String name,
    String? position,
    String? imageUrl,
    required bool isOnline,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _isOpening ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    SeedAvatar(
                      name: name,
                      imageUrl: imageUrl,
                      size: SeedAvatarSize.medium,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: AppSpacing.space2_5,
                          height: AppSpacing.space2_5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppSemanticColors.statusSuccessIcon,
                            border: Border.all(
                              color: AppSemanticColors.surfaceDefault,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((position ?? '').isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          position!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          indent: AppSpacing.space4 + AppSpacing.space10 + AppSpacing.space3,
          color: AppSemanticColors.borderSubtle,
        ),
      ],
    );
  }
}
