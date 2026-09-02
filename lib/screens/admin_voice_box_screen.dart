import 'package:flutter/material.dart';

import '../models/voice_message.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';

/// 고충·건의함 관리 — 웹(frontend-admin의 VoiceBoxAdmin.tsx)과 같은 기능.
///
/// 직원용 [VoiceBoxScreen]이 제출과 내 내역만 다루는 것과 달리, 이 화면은 기관에
/// 접수된 전체 목록을 보고 상태를 바꾸거나 답변을 남긴다.
///
/// **익명 보호**: 익명으로 제출된 글은 서버(VoiceMessageService.listForAdmin →
/// toDTO(maskAnonymous: true))가 authorName을 '익명'으로 바꿔서 내려준다. 앱은
/// 내려온 authorName을 그대로 보여줄 뿐, 작성자를 따로 조회하지 않는다.
/// 여기에 작성자 추적용 조회를 절대 붙이지 말 것.
class AdminVoiceBoxScreen extends StatefulWidget {
  const AdminVoiceBoxScreen({super.key});

  @override
  State<AdminVoiceBoxScreen> createState() => _AdminVoiceBoxScreenState();
}

/// 유형 필터. null(전체)은 서버에 type 파라미터를 보내지 않는다.
enum _TypeFilter {
  all,
  grievance,
  suggestion;

  String? get apiValue {
    switch (this) {
      case _TypeFilter.all:
        return null;
      case _TypeFilter.grievance:
        return 'GRIEVANCE';
      case _TypeFilter.suggestion:
        return 'SUGGESTION';
    }
  }

  String get label {
    switch (this) {
      case _TypeFilter.all:
        return '전체';
      case _TypeFilter.grievance:
        return '고충·신고';
      case _TypeFilter.suggestion:
        return '건의';
    }
  }
}

/// 백엔드 VoiceMessage.VoiceStatus 이름. 모델에 fromApi는 있지만 반대 방향이 없어서 여기 둔다.
String _statusApiValue(VoiceMessageStatus status) {
  switch (status) {
    case VoiceMessageStatus.received:
      return 'RECEIVED';
    case VoiceMessageStatus.inReview:
      return 'IN_REVIEW';
    case VoiceMessageStatus.resolved:
      return 'RESOLVED';
    case VoiceMessageStatus.onHold:
      return 'ON_HOLD';
  }
}

/// 상태 표시 문구. 웹과 같이 '처리완료'는 건의일 때 '반영됨'으로 바꿔 부른다.
String _statusLabelFor(VoiceMessageStatus status, VoiceMessageType type) {
  if (status == VoiceMessageStatus.resolved) {
    return type == VoiceMessageType.suggestion ? '반영됨' : '조치완료';
  }
  return status.label;
}

class _AdminVoiceBoxScreenState extends State<AdminVoiceBoxScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<VoiceMessage> _messages = [];
  _TypeFilter _filter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService().getVoiceBoxMessagesForAdmin(
        type: _filter.apiValue,
      );
      // 응답은 래퍼 객체({messages: [...]})다. 배열이 그대로 오지 않는다.
      final raw = response['messages'];
      final list = raw is List ? raw : (response['content'] ?? response['data']);
      final messages = (list is List ? list : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(VoiceMessage.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      final message = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isNotEmpty ? message : '목록을 불러오지 못했습니다';
        _isLoading = false;
      });
    }
  }

  void _setFilter(_TypeFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _load();
  }

  int _countOf(VoiceMessageType type) =>
      _messages.where((m) => m.type == type).length;

  /// 처리 시트 — 상태와 답변을 고쳐 저장한다.
  Future<void> _openHandleSheet(VoiceMessage message) async {
    final replyController =
        TextEditingController(text: message.adminReply ?? '');
    var status = message.status;
    var isSaving = false;

    final saved = await AppBottomSheet.show<bool>(
      context,
      height: MediaQuery.of(context).size.height * 0.9,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> save() async {
            setSheetState(() => isSaving = true);
            try {
              await ApiService().updateVoiceBoxMessage(
                id: message.id,
                status: _statusApiValue(status),
                adminReply: replyController.text.trim(),
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop(true);
            } catch (e) {
              final msg = e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('ApiException: ', '');
              if (!sheetContext.mounted) return;
              setSheetState(() => isSaving = false);
              AppSnackBar.showError(
                sheetContext,
                message: msg.isNotEmpty ? msg : '저장에 실패했습니다',
              );
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(status: message.status, type: message.type),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          message.type.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                        if (message.isAnonymous) ...[
                          const SizedBox(width: AppSpacing.space2),
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 14,
                            color: AppSemanticColors.textTertiary,
                          ),
                          const SizedBox(width: AppSpacing.space1),
                          Text(
                            '익명',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      message.title,
                      style: AppTypography.heading6.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      // 익명 글이면 서버가 이미 '익명'으로 내려준 값이다.
                      '${message.authorName} · ${_formatDate(message.createdAt)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    SelectableText(
                      message.content,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.space6),
                    Text(
                      '처리 상태',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space2,
                      children: [
                        for (final option in VoiceMessageStatus.values)
                          SeedChip(
                            label: _statusLabelFor(option, message.type),
                            selected: status == option,
                            isDisabled: isSaving,
                            onTap: () =>
                                setSheetState(() => status = option),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.space5),
                    SeedTextField(
                      label: '답변',
                      placeholder: '처리 결과나 답변을 남겨주세요',
                      helperText: '작성자에게 그대로 표시됩니다.',
                      controller: replyController,
                      maxLines: 5,
                      isDisabled: isSaving,
                    ),

                    const SizedBox(height: AppSpacing.space5),
                    SizedBox(
                      width: double.infinity,
                      child: SeedButton(
                        label: '저장하기',
                        size: SeedButtonSize.large,
                        isLoading: isSaving,
                        isDisabled: isSaving,
                        onPressed: save,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    replyController.dispose();

    if (saved == true) {
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: '처리 내용을 저장했어요. 작성자가 상태와 답변을 볼 수 있습니다',
      );
      await _load();
    }
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '${date.year}.$mm.$dd $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('고충·건의함 관리', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            children: [
              const SeedCallout(
                variant: SeedCalloutVariant.info,
                title: '직원들이 남긴 고충·건의를 처리해요',
                description:
                    '익명으로 제출된 글은 작성자가 "익명"으로만 표시돼 누가 썼는지 알 수 없어요. 상태를 바꾸거나 답변을 남기면 작성자가 자기 내역에서 확인할 수 있습니다.',
              ),
              const SizedBox(height: AppSpacing.space4),

              Row(
                children: [
                  for (final filter in _TypeFilter.values) ...[
                    SeedChip(
                      label: _filter == _TypeFilter.all &&
                              filter != _TypeFilter.all
                          ? '${filter.label} (${_countOf(filter == _TypeFilter.grievance ? VoiceMessageType.grievance : VoiceMessageType.suggestion)})'
                          : filter.label,
                      selected: _filter == filter,
                      isDisabled: _isLoading,
                      onTap: () => _setFilter(filter),
                    ),
                    if (filter != _TypeFilter.values.last)
                      const SizedBox(width: AppSpacing.space2),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.space4),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.space8),
                  child: AppLoading(),
                )
              else if (_errorMessage != null)
                _buildErrorState(_errorMessage!)
              else if (_messages.isEmpty)
                _buildEmptyState()
              else
                SeedListSection(
                  children: [
                    for (final message in _messages)
                      SeedListCell(
                        leadingIcon:
                            message.type == VoiceMessageType.grievance
                                ? Icons.report_gmailerrorred_outlined
                                : Icons.lightbulb_outline,
                        title: message.title,
                        description:
                            '${message.authorName} · ${_formatDate(message.createdAt)}${message.hasReply ? ' · 답변함' : ''}',
                        trailing: _StatusBadge(
                          status: message.status,
                          type: message.type,
                        ),
                        onTap: () => _openHandleSheet(message),
                      ),
                  ],
                ),

              const SizedBox(height: AppSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space8),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppSemanticColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '접수된 항목이 없어요',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space8),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            onPressed: _load,
          ),
        ],
      ),
    );
  }
}

/// 상태 알약. 직원 화면(voice_box_screen.dart)의 것과 같은 모양이되,
/// 건의 글의 '처리완료'를 '반영됨'으로 부르기 위해 type을 함께 받는다.
class _StatusBadge extends StatelessWidget {
  final VoiceMessageStatus status;
  final VoiceMessageType type;

  const _StatusBadge({required this.status, required this.type});

  Color get _color {
    switch (status) {
      case VoiceMessageStatus.received:
        return AppSemanticColors.statusInfoText;
      case VoiceMessageStatus.inReview:
        return AppSemanticColors.statusWarningText;
      case VoiceMessageStatus.resolved:
        return AppSemanticColors.statusSuccessText;
      case VoiceMessageStatus.onHold:
        return AppSemanticColors.textTertiary;
    }
  }

  Color get _background {
    switch (status) {
      case VoiceMessageStatus.received:
        return AppSemanticColors.statusInfoBackground;
      case VoiceMessageStatus.inReview:
        return AppSemanticColors.statusWarningBackground;
      case VoiceMessageStatus.resolved:
        return AppSemanticColors.statusSuccessBackground;
      case VoiceMessageStatus.onHold:
        return AppSemanticColors.backgroundTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        _statusLabelFor(status, type),
        style: AppTypography.labelSmall.copyWith(color: _color),
      ),
    );
  }
}
