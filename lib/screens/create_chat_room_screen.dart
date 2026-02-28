import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../services/api_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
      final response = await ApiService().getCompanyMembers(companyId: companyId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createChatRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅방 이름을 입력해주세요')),
      );
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참가자를 1명 이상 선택해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';
      final userId = authProvider.currentUser?.id ?? '';
      final userName = authProvider.currentUser?.name ?? '';

      // 자신도 참가자에 포함
      final participantIds = [..._selectedParticipantIds, userId].toSet().toList();

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
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 생성에 실패했습니다')),
        );
      }
    } catch (e) {
      print('[CreateChatRoomScreen] 채팅방 생성 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅방 생성에 실패했습니다: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '새 채팅방',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        actions: [
          shadcn.GhostButton(
            onPressed: _isLoading ? null : _createChatRoom,
            child: Text(
              '만들기',
              style: AppTypography.labelLarge.copyWith(
                color: AppSemanticColors.textInverse,
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
                  Text(
                    '채팅방 이름',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '채팅방 이름을 입력하세요',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppSemanticColors.surfaceDefault,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(AppSpacing.space4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // 채팅방 설명 (선택)
                  Text(
                    '설명 (선택)',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '채팅방 설명을 입력하세요',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppSemanticColors.surfaceDefault,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(AppSpacing.space4),
                    ),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                    child: Row(
                      children: [
                        shadcn.GhostButton(
                          onPressed: () {
                            setState(() {
                              _selectedParticipantIds.clear();
                              for (final member in _members) {
                                final memberId = member['id']?.toString() ?? '';
                                if (memberId.isNotEmpty && memberId != currentUserId) {
                                  _selectedParticipantIds.add(memberId);
                                }
                              }
                            });
                          },
                          child: Text(
                            '전체 선택',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppSemanticColors.interactivePrimaryDefault,
                            ),
                          ),
                        ),
                        shadcn.GhostButton(
                          onPressed: () {
                            setState(() {
                              _selectedParticipantIds.clear();
                            });
                          },
                          child: Text(
                            '선택 해제',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 회원 목록
                  Container(
                    decoration: BoxDecoration(
                      color: AppSemanticColors.surfaceDefault,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: _members.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.space4),
                            child: Text(
                              '회원이 없습니다',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              final memberId = member['id']?.toString() ?? '';
                              final memberName = member['name']?.toString() ?? '알 수 없음';
                              final memberRole = member['role']?.toString() ?? '';
                              final isCurrentUser = memberId == currentUserId;
                              final isSelected = _selectedParticipantIds.contains(memberId);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAdmin
                                      ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                                      : AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                                  child: Text(
                                    memberName.isNotEmpty ? memberName[0] : '?',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppSemanticColors.interactivePrimaryDefault,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  memberName + (isCurrentUser ? ' (나)' : ''),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                                subtitle: memberRole.isNotEmpty
                                    ? Text(
                                        _getRoleText(memberRole),
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppSemanticColors.textTertiary,
                                        ),
                                      )
                                    : null,
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
                                              _selectedParticipantIds.add(memberId);
                                            } else {
                                              _selectedParticipantIds.remove(memberId);
                                            }
                                          });
                                        },
                                        activeColor: AppSemanticColors.interactivePrimaryDefault,
                                      ),
                                onTap: isCurrentUser
                                    ? null
                                    : () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedParticipantIds.remove(memberId);
                                          } else {
                                            _selectedParticipantIds.add(memberId);
                                          }
                                        });
                                      },
                              );
                            },
                          ),
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
