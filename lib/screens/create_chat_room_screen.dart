import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'chat_room_screen.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';
import '../widgets/common/app_snackbar.dart';

class CreateChatRoomScreen extends StatefulWidget {
  const CreateChatRoomScreen({super.key});

  @override
  State<CreateChatRoomScreen> createState() => _CreateChatRoomScreenState();
}

class _CreateChatRoomScreenState extends State<CreateChatRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedParticipantIds = {};
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '1';

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().getCompanyMembers(
        companyId: companyId,
      );
      print('[CreateChatRoomScreen] 회원 목록 응답: $response');

      if (response['members'] != null) {
        setState(() {
          _members = (response['members'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
        });
      } else if (response['content'] != null) {
        setState(() {
          _members = (response['content'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('[CreateChatRoomScreen] 회원 목록 로드 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '회원 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createChatRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.showInfo(context, message: '채팅방 이름을 입력해주세요');
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      AppSnackBar.showInfo(context, message: '참가자를 1명 이상 선택해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';
      final userId = authProvider.currentUser?.chatUserId ?? '';
      final userName = authProvider.currentUser?.name ?? '';

      // 자신도 참가자에 포함
      final participantIds = [
        ..._selectedParticipantIds,
        userId,
      ].toSet().toList();

      final room = await chatProvider.createChatRoom(
        companyId: companyId,
        name: name,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdBy: userId,
        createdByName: userName,
        participantIds: participantIds,
      );

      if (room != null && mounted) {
        // 생성한 방으로 바로 입장한다 (목록으로 돌아가 다시 누르게 하지 않는다)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
        );
      } else if (mounted) {
        AppSnackBar.showError(context, message: '채팅방 생성에 실패했습니다');
      }
    } catch (e) {
      debugPrint('[CreateChatRoomScreen] 채팅방 생성 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '채팅방 생성에 실패했습니다. 잠시 후 다시 시도해 주세요');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser?.chatUserId ?? '';

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        // 상단 바 기본 제목(heading5) — 채팅 화면들 사이에서 제목 글자가 변하지 않게
        title: const Text('새 채팅방'),
        elevation: 0,
        actions: [
          // 앱바 안의 '만들기'는 높이가 56으로 늘어난 회색 타일이 되던 단추 대신 글자 단추.
          // 이름이 비면 흐리게 — 주 행동이 비활성처럼 보이던 문제도 함께 풀린다.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space2),
            child: Center(
              child: ListenableBuilder(
                listenable: _nameController,
                builder: (context, _) {
                  final enabled =
                      !_isLoading && _nameController.text.trim().isNotEmpty;
                  return TextButton(
                    onPressed: _isLoading ? null : _createChatRoom,
                    child: Text(
                      '만들기',
                      style: AppTypography.buttonMedium.copyWith(
                        color: enabled
                            ? AppSemanticColors.headerForeground
                            : AppSemanticColors.headerForegroundMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _members.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 채팅방 이름
                  SeedTextField(
                    label: '채팅방 이름',
                    controller: _nameController,
                    placeholder: '채팅방 이름을 입력하세요',
                    maxLength: Constants.maxChatRoomNameLength,
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // 채팅방 설명 (선택)
                  SeedTextField(
                    label: '설명 (선택)',
                    controller: _descriptionController,
                    placeholder: '채팅방 설명을 입력하세요',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.space6),

                  // 참가자 선택
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '참가자 선택',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_selectedParticipantIds.length}명 선택됨',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),

                  // 전체 선택 버튼
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space2,
                    ),
                    child: Row(
                      children: [
                        SeedButton(
                          label: '전체 선택',
                          variant: SeedButtonVariant.neutralOutline,
                          size: SeedButtonSize.small,
                          onPressed: () {
                            setState(() {
                              _selectedParticipantIds.clear();
                              for (final member in _members) {
                                final memberId = member['id']?.toString() ?? '';
                                if (memberId.isNotEmpty &&
                                    memberId != currentUserId) {
                                  _selectedParticipantIds.add(memberId);
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        SeedButton(
                          label: '선택 해제',
                          // '전체 선택'과 같은 모양 — 형제 단추가 한쪽은 외곽, 한쪽은 채움이던 것을 맞춤
                          variant: SeedButtonVariant.neutralOutline,
                          size: SeedButtonSize.small,
                          onPressed: () {
                            setState(() {
                              _selectedParticipantIds.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // 회원 목록 — SeedListSection(단일 표면 + 내부 구분선)으로 통일
                  _members.isEmpty
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                            border: Border.all(color: AppSemanticColors.borderSubtle),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.space4),
                          child: Text(
                            '회원이 없습니다',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        )
                      : SeedListSection(
                          children: _members.map((member) {
                            final memberId = member['id']?.toString() ?? '';
                            final memberName =
                                member['name']?.toString() ?? '알 수 없음';
                            final memberRole = member['role']?.toString() ?? '';
                            final memberPosition =
                                member['position']?.toString().trim() ?? '';
                            final isCurrentUser = memberId == currentUserId;
                            final isSelected = _selectedParticipantIds
                                .contains(memberId);
                            // 직종과 역할 문구가 같은 말이면 한 번만("요양보호사 • 요양보호사" 방지)
                            final roleText =
                                memberRole.isEmpty ? '' : _getRoleText(memberRole);
                            final meta = [
                              if (memberPosition.isNotEmpty) memberPosition,
                              if (roleText.isNotEmpty && roleText != memberPosition)
                                roleText,
                            ].join(' · ');

                            void toggle() {
                              setState(() {
                                if (isSelected) {
                                  _selectedParticipantIds.remove(memberId);
                                } else {
                                  _selectedParticipantIds.add(memberId);
                                }
                              });
                            }

                            // 사람 한 줄 — 채팅 탭 직원 목록과 같은 규칙(높이 64, 이름 titleMedium + 메타 bodySmall)
                            return InkWell(
                              onTap: isCurrentUser ? null : toggle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space4,
                                  vertical: AppSpacing.space3,
                                ),
                                child: Row(
                                  children: [
                                    SeedAvatar(
                                      name: memberName,
                                      // 사진을 안 넘기면 등록돼 있어도 이름 첫 글자만 나온다
                                      imageUrl:
                                          member['profileImageUrl']?.toString(),
                                      size: SeedAvatarSize.medium,
                                    ),
                                    const SizedBox(width: AppSpacing.space3),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              memberName +
                                                  (isCurrentUser ? ' (나)' : ''),
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                color: AppSemanticColors
                                                    .textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (meta.isNotEmpty) ...[
                                            const SizedBox(
                                              width: AppSpacing.space2,
                                            ),
                                            Text(
                                              meta,
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                color: AppSemanticColors
                                                    .textTertiary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // 기본 Checkbox는 미체크일 때 검은 2px 테두리라 틸 앱 톤에서 튀었다.
                                    // 나는 늘 들어가므로 체크된 채 비활성으로 보여준다.
                                    Checkbox(
                                      value: isCurrentUser ? true : isSelected,
                                      onChanged: isCurrentUser
                                          ? null
                                          : (_) => toggle(),
                                      activeColor: AppSemanticColors
                                          .interactivePrimaryDefault,
                                      checkColor: AppSemanticColors.textInverse,
                                      side: BorderSide(
                                        color: AppSemanticColors.borderHover,
                                        width: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  String _getRoleText(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'ROLE_ADMIN':
        return '관리자';
      case 'CAREGIVER':
        return '요양보호사';
      case 'SOCIAL_WORKER':
        return '사회복지사';
      case 'NURSE':
        return '간호사';
      case 'OFFICE':
        return '사무원';
      default:
        return role;
    }
  }
}
