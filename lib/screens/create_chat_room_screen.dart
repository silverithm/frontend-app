import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/api_service.dart';
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
      print('[CreateChatRoomScreen] 회원 목록 로드 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '회원 목록을 불러오는데 실패했습니다: $e');
      }
    } finally {
      setState(() => _isLoading = false);
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
      print('[CreateChatRoomScreen] 채팅방 생성 에러: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '채팅방 생성에 실패했습니다: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser?.chatUserId ?? '';

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '새 채팅방',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        foregroundColor: AppSemanticColors.textPrimary,
        iconTheme: IconThemeData(color: AppSemanticColors.textPrimary),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space2),
            child: SeedButton(
              label: '만들기',
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.small,
              isDisabled: _isLoading,
              onPressed: _isLoading ? null : _createChatRoom,
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
                        style: AppTypography.labelLarge.copyWith(
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
                          variant: SeedButtonVariant.neutralWeak,
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
                            final meta = [
                              if (memberPosition.isNotEmpty) memberPosition,
                              if (memberRole.isNotEmpty)
                                _getRoleText(memberRole),
                            ].join(' • ');

                            return SeedListCell(
                              leading: SeedAvatar(
                                name: memberName,
                                // 사진을 안 넘기면 등록돼 있어도 이름 첫 글자만 나온다
                                imageUrl:
                                    member['profileImageUrl']?.toString(),
                                size: SeedAvatarSize.medium,
                              ),
                              title: memberName + (isCurrentUser ? ' (나)' : ''),
                              description: meta.isNotEmpty ? meta : null,
                              showChevron: false,
                              trailing: isCurrentUser
                                  ? Icon(
                                      Icons.check_circle,
                                      color: AppSemanticColors.textDisabled,
                                    )
                                  : Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedParticipantIds.add(
                                              memberId,
                                            );
                                          } else {
                                            _selectedParticipantIds.remove(
                                              memberId,
                                            );
                                          }
                                        });
                                      },
                                      activeColor: AppSemanticColors
                                          .interactivePrimaryDefault,
                                    ),
                              onTap: isCurrentUser
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedParticipantIds.remove(
                                            memberId,
                                          );
                                        } else {
                                          _selectedParticipantIds.add(
                                            memberId,
                                          );
                                        }
                                      });
                                    },
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
