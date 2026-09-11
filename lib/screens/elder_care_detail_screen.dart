import 'package:flutter/material.dart';

import '../models/elder_care_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'elder_care_edit_screen.dart';

/// 어르신 케어 정보 상세 — 기본·건강·식사·목욕·투약·차량·자리·메모를 섹션으로 읽는다.
///
/// 주민번호는 마스킹된 값만 보여준다. 전체 주민번호 조회 API는 관리자 웹 전용이고,
/// 앱에서는 아예 부르지 않는다(현장 단말에 평문이 남지 않도록).
class ElderCareDetailScreen extends StatefulWidget {
  final ElderInfo elder;

  const ElderCareDetailScreen({super.key, required this.elder});

  @override
  State<ElderCareDetailScreen> createState() => _ElderCareDetailScreenState();
}

class _ElderCareDetailScreenState extends State<ElderCareDetailScreen> {
  late ElderCareProfile _profile;

  /// 이 화면에서 실제로 저장이 일어났는지. 목록에 새 값을 돌려줄지 판단하는 유일한 근거다.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    // 프로필 미등록이면 빈 값으로 시작한다 — 바로 수정해서 채울 수 있어야 한다.
    _profile = widget.elder.careProfile ?? const ElderCareProfile();
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<ElderCareProfile>(
      MaterialPageRoute(
        builder: (_) => ElderCareEditScreen(
          elderId: widget.elder.id,
          elderName: widget.elder.name,
          profile: _profile,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _profile = updated;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return PopScope(
      // 수정했으면 목록이 새 값을 받아 갈 수 있도록 프로필을 들려 보낸다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed ? _profile : null);
      },
      child: Scaffold(
        backgroundColor: AppSemanticColors.backgroundSecondary,
        appBar: AppBar(
          title: Text(widget.elder.name, style: AppTypography.heading5),
          backgroundColor: AppSemanticColors.backgroundPrimary,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _edit,
              child: Text(
                '수정',
                style: AppTypography.buttonMedium.copyWith(
                  color: AppSemanticColors.brandDefault,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.space10,
          ),
          children: [
            _Section(
              title: '기본',
              rows: [
                _Row('주민번호', p.residentNumberMasked ?? '미등록'),
                _Row('생년월일', p.birthDate ?? '미등록'),
                _Row(
                  '나이 · 성별',
                  p.ageGenderSummary.isEmpty ? '미등록' : p.ageGenderSummary,
                ),
                _Row('장기요양등급', p.careGradeLabel),
                if (widget.elder.homeAddressName != null)
                  _Row('주소', widget.elder.homeAddressName!),
              ],
            ),
            _Section(
              title: '건강',
              rows: [
                _Row('낙상 위험', p.fallRisk ? '있음' : '없음', alert: p.fallRisk),
                if (p.fallNote != null) _Row('낙상 메모', p.fallNote!),
                _Row(
                  '욕창',
                  p.pressureSore ? '있음·위험' : '없음',
                  alert: p.pressureSore,
                ),
                if (p.pressureSoreNote != null)
                  _Row('욕창 메모', p.pressureSoreNote!),
                _Row('기저귀', p.diaperLabel),
                _Row('인지', p.cognitionLabel),
                if (p.cognitionNote != null) _Row('인지 메모', p.cognitionNote!),
              ],
            ),
            _Section(
              title: '식사',
              rows: [
                _Row('식사 형태', p.mealTypeLabel),
                _Row('제공', p.mealServingSummary),
                if (p.mealNote != null) _Row('특이사항', p.mealNote!),
              ],
            ),
            _Section(
              title: '목욕',
              rows: [
                _Row('목욕 시간', p.bathTime ?? '미지정'),
                if (p.bathNote != null) _Row('특이사항', p.bathNote!),
              ],
            ),
            _Section(
              title: '투약',
              rows: [
                _Row('투약 시간', p.medicationSummary),
                if (p.medNote != null) _Row('특이사항', p.medNote!),
              ],
            ),
            _Section(
              title: '차량',
              rows: [_Row('등하원 특이사항', p.vehicleNote ?? '없음')],
            ),
            _Section(title: '자리', rows: [_Row('위치', p.seatSummary)]),
            _Section(title: '메모', rows: [_Row('기타', p.careNote ?? '없음')]),
            if (p.updatedAt != null) ...[
              const SizedBox(height: AppSpacing.space3),
              Text(
                '최종 수정 ${_formatDateTime(p.updatedAt!)}',
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

  /// ISO 문자열을 "2026-09-11 14:30"까지만 잘라 쓴다(초·타임존은 현장에서 안 본다).
  String _formatDateTime(String iso) => iso.length >= 16
      ? '${iso.substring(0, 10)} ${iso.substring(11, 16)}'
      : iso;
}

class _Row {
  final String label;
  final String value;
  final bool alert;

  const _Row(this.label, this.value, {this.alert = false});
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.space1,
              bottom: AppSpacing.space2,
            ),
            child: Text(
              title,
              style: AppTypography.labelMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(color: AppSemanticColors.borderSubtle),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          // 라벨 열 폭도 글자 배율을 따라간다 — '아주 크게'에서 고정 폭이면
                          // '장기요양등급' 같은 라벨이 두 줄로 접힌다.
                          width: MediaQuery.textScalerOf(
                            context,
                          ).scale(AppSpacing.space20 + AppSpacing.space3),
                          child: Text(
                            row.label,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Expanded(
                          child: Text(
                            row.value,
                            style: AppTypography.bodyMedium.copyWith(
                              color: row.alert
                                  ? AppSemanticColors.statusWarningText
                                  : AppSemanticColors.textPrimary,
                              fontWeight: row.alert
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
