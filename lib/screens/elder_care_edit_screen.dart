import 'package:flutter/material.dart';

import '../models/elder_care_profile.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_text_field.dart';

/// 어르신 케어 정보 수정.
///
/// 주민번호는 편집 대상이 아니다 — 요청에 residentNumber 키를 싣지 않으면
/// 서버가 기존 값을 그대로 둔다(계약). 앱에서 평문 주민번호를 다루지 않는 이유.
class ElderCareEditScreen extends StatefulWidget {
  final int elderId;
  final String elderName;
  final ElderCareProfile profile;

  const ElderCareEditScreen({
    super.key,
    required this.elderId,
    required this.elderName,
    required this.profile,
  });

  @override
  State<ElderCareEditScreen> createState() => _ElderCareEditScreenState();
}

class _ElderCareEditScreenState extends State<ElderCareEditScreen> {
  // 텍스트 입력은 컨트롤러로, 나머지는 상태 변수로 들고 있다가 저장 때 한 번에 조립한다.
  late final TextEditingController _birthDate;
  late final TextEditingController _fallNote;
  late final TextEditingController _pressureSoreNote;
  late final TextEditingController _cognitionNote;
  late final TextEditingController _mealNote;
  late final TextEditingController _bathTime;
  late final TextEditingController _bathNote;
  late final TextEditingController _medMorningTime;
  late final TextEditingController _medLunchTime;
  late final TextEditingController _medEveningTime;
  late final TextEditingController _medNote;
  late final TextEditingController _vehicleNote;
  late final TextEditingController _floor;
  late final TextEditingController _seatNote;
  late final TextEditingController _careNote;

  String? _gender;
  CareGrade? _careGrade;
  bool _fallRisk = false;
  bool _pressureSore = false;
  DiaperType? _diaperType;
  bool _diaperIntermittent = false;
  CognitionLevel? _cognitionLevel;
  MealType? _mealType;
  bool _morningSnack = true;
  bool _afternoonSnack = true;
  bool _dinner = true;
  bool _medMorning = false;
  bool _medLunch = false;
  bool _medEvening = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;

    _birthDate = TextEditingController(text: p.birthDate ?? '');
    _fallNote = TextEditingController(text: p.fallNote ?? '');
    _pressureSoreNote = TextEditingController(text: p.pressureSoreNote ?? '');
    _cognitionNote = TextEditingController(text: p.cognitionNote ?? '');
    _mealNote = TextEditingController(text: p.mealNote ?? '');
    _bathTime = TextEditingController(text: p.bathTime ?? '');
    _bathNote = TextEditingController(text: p.bathNote ?? '');
    _medMorningTime = TextEditingController(text: p.medMorningTime ?? '');
    _medLunchTime = TextEditingController(text: p.medLunchTime ?? '');
    _medEveningTime = TextEditingController(text: p.medEveningTime ?? '');
    _medNote = TextEditingController(text: p.medNote ?? '');
    _vehicleNote = TextEditingController(text: p.vehicleNote ?? '');
    _floor = TextEditingController(text: p.floor?.toString() ?? '');
    _seatNote = TextEditingController(text: p.seatNote ?? '');
    _careNote = TextEditingController(text: p.careNote ?? '');

    _gender = p.gender;
    _careGrade = p.careGrade;
    _fallRisk = p.fallRisk;
    _pressureSore = p.pressureSore;
    _diaperType = p.diaperType;
    _diaperIntermittent = p.diaperIntermittent;
    _cognitionLevel = p.cognitionLevel;
    _mealType = p.mealType;
    _morningSnack = p.morningSnack;
    _afternoonSnack = p.afternoonSnack;
    _dinner = p.dinner;
    _medMorning = p.medMorning;
    _medLunch = p.medLunch;
    _medEvening = p.medEvening;
  }

  @override
  void dispose() {
    for (final c in [
      _birthDate,
      _fallNote,
      _pressureSoreNote,
      _cognitionNote,
      _mealNote,
      _bathTime,
      _bathNote,
      _medMorningTime,
      _medLunchTime,
      _medEveningTime,
      _medNote,
      _vehicleNote,
      _floor,
      _seatNote,
      _careNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 빈 문자열은 null로 보낸다 — 서버에서 "값 없음"과 공백 문자열을 구분해야 한다.
  String? _nullable(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    // 비운 칸은 null로 보내야 하므로 copyWith(null=유지) 대신 새 인스턴스를 조립한다.
    final payload = _withCleared(widget.profile);

    try {
      final updated = await ApiService().updateElderCareProfile(
        widget.elderId,
        payload,
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '케어 정보를 저장했습니다.');
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.showError(context, message: '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  /// 입력칸을 비운 항목은 null이어야 한다. copyWith로는 지울 수 없어 새 인스턴스로 만든다.
  ElderCareProfile _withCleared(ElderCareProfile base) {
    return ElderCareProfile(
      residentNumberMasked: base.residentNumberMasked,
      birthDate: _nullable(_birthDate),
      gender: _gender,
      age: base.age,
      careGrade: _careGrade,
      fallRisk: _fallRisk,
      fallNote: _nullable(_fallNote),
      pressureSore: _pressureSore,
      pressureSoreNote: _nullable(_pressureSoreNote),
      diaperType: _diaperType,
      diaperIntermittent: _diaperIntermittent,
      cognitionLevel: _cognitionLevel,
      cognitionNote: _nullable(_cognitionNote),
      mealType: _mealType,
      morningSnack: _morningSnack,
      afternoonSnack: _afternoonSnack,
      dinner: _dinner,
      mealNote: _nullable(_mealNote),
      bathTime: _nullable(_bathTime),
      bathNote: _nullable(_bathNote),
      medMorning: _medMorning,
      medMorningTime: _nullable(_medMorningTime),
      medLunch: _medLunch,
      medLunchTime: _nullable(_medLunchTime),
      medEvening: _medEvening,
      medEveningTime: _nullable(_medEveningTime),
      medNote: _nullable(_medNote),
      vehicleNote: _nullable(_vehicleNote),
      floor: int.tryParse(_floor.text.trim()),
      seatNote: _nullable(_seatNote),
      careNote: _nullable(_careNote),
      updatedAt: base.updatedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('${widget.elderName} 정보 수정', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          AppSpacing.space4,
          AppSpacing.space4,
          AppSpacing.space10,
        ),
        children: [
          _card('기본', [
            // 주민번호는 편집 대상이 아니다 — 읽기 전용 안내만 둔다.
            _readOnlyRow(
              '주민번호',
              widget.profile.residentNumberMasked ?? '미등록',
              '주민번호는 관리자 웹에서만 등록·수정할 수 있습니다.',
            ),
            _textField(_birthDate, '생년월일', hint: '2026-01-31'),
            _dropdown<String>(
              label: '성별',
              value: _gender,
              items: const {'MALE': '남', 'FEMALE': '여'},
              onChanged: (v) => setState(() => _gender = v),
            ),
            _dropdown<CareGrade>(
              label: '장기요양등급',
              value: _careGrade,
              items: ElderCareEnums.careGradeLabel,
              onChanged: (v) => setState(() => _careGrade = v),
            ),
          ]),
          _card('건강', [
            _switch('낙상 위험', _fallRisk, (v) => setState(() => _fallRisk = v)),
            _textField(_fallNote, '낙상 메모', maxLines: 2),
            _switch(
              '욕창 (있음·위험)',
              _pressureSore,
              (v) => setState(() => _pressureSore = v),
            ),
            _textField(_pressureSoreNote, '욕창 메모', maxLines: 2),
            _dropdown<DiaperType>(
              label: '기저귀',
              value: _diaperType,
              items: ElderCareEnums.diaperTypeLabel,
              onChanged: (v) => setState(() => _diaperType = v),
            ),
            _switch(
              '기저귀 간헐적 사용',
              _diaperIntermittent,
              (v) => setState(() => _diaperIntermittent = v),
            ),
            _dropdown<CognitionLevel>(
              label: '인지',
              value: _cognitionLevel,
              items: ElderCareEnums.cognitionLevelLabel,
              onChanged: (v) => setState(() => _cognitionLevel = v),
            ),
            _textField(_cognitionNote, '인지 메모', maxLines: 2),
          ]),
          _card('식사', [
            _dropdown<MealType>(
              label: '식사 형태',
              value: _mealType,
              items: ElderCareEnums.mealTypeLabel,
              onChanged: (v) => setState(() => _mealType = v),
            ),
            _switch(
              '오전간식',
              _morningSnack,
              (v) => setState(() => _morningSnack = v),
            ),
            _switch(
              '오후간식',
              _afternoonSnack,
              (v) => setState(() => _afternoonSnack = v),
            ),
            _switch('저녁식사', _dinner, (v) => setState(() => _dinner = v)),
            _textField(
              _mealNote,
              '식사 특이사항',
              hint: '기피식품 · 대체식품 · 기간 조건',
              maxLines: 3,
            ),
          ]),
          _card('목욕', [
            _textField(_bathTime, '목욕 시간', hint: '9:40-50'),
            _textField(
              _bathNote,
              '목욕 특이사항',
              hint: '방문목욕으로 1,3째주 센터 내 목욕 안 함',
              maxLines: 2,
            ),
          ]),
          _card('투약', [
            _switch(
              '아침 투약',
              _medMorning,
              (v) => setState(() => _medMorning = v),
            ),
            _textField(_medMorningTime, '아침 투약 시간', hint: '10시'),
            _switch('점심 투약', _medLunch, (v) => setState(() => _medLunch = v)),
            _textField(_medLunchTime, '점심 투약 시간'),
            _switch(
              '저녁 투약',
              _medEvening,
              (v) => setState(() => _medEvening = v),
            ),
            _textField(_medEveningTime, '저녁 투약 시간'),
            _textField(_medNote, '투약 특이사항', maxLines: 2),
          ]),
          _card('차량', [
            _textField(
              _vehicleNote,
              '등하원 특이사항',
              hint: '이용 차량 · 등하원 시 주의사항',
              maxLines: 2,
            ),
          ]),
          _card('자리', [
            _textField(
              _floor,
              '층',
              hint: '1',
              keyboardType: TextInputType.number,
            ),
            _textField(_seatNote, '자리 위치', hint: 'TV 앞 좌측'),
          ]),
          _card('메모', [_textField(_careNote, '기타 메모', maxLines: 4)]),
          const SizedBox(height: AppSpacing.space2),
          SeedButton(
            label: '저장',
            size: SeedButtonSize.large,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
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
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.space3),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 입력 필드 라벨. SeedTextField가 그리는 라벨과 같은 모양이어야
  /// 드롭다운·읽기전용 줄이 입력칸들 사이에서 따로 놀지 않는다.
  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.labelMedium.copyWith(
        color: AppSemanticColors.textSecondary,
      ),
    );
  }

  Widget _readOnlyRow(String label, String value, String helper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: AppSpacing.space0_5),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space0_5),
        Text(
          helper,
          style: AppTypography.labelSmall.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    // 공용 SeedTextField. placeholder는 이 컴포넌트가 이미 textTertiary로 흐리게 그린다 —
    // 힌트가 본문과 같은 색이면 예시 문구를 그 어르신의 실제 지시사항으로 읽는다
    // ("방문목욕으로 1,3째주 …"). 케어 기준 화면에서 이건 그냥 오독이 아니라 사고다.
    return SeedTextField(
      label: label,
      controller: controller,
      placeholder: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppSemanticColors.brandDefault,
        ),
      ],
    );
  }

  /// 값을 고르지 않은 상태(null)를 '미지정' 항목으로 명시해 되돌릴 수 있게 한다.
  Widget _dropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: AppSpacing.space1_5),
        DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3_5,
              vertical: AppSpacing.space2_5,
            ),
            // SeedTextField(medium)의 테두리와 같은 모양 — 같은 카드 안에서
            // 입력칸과 드롭다운이 다른 컴포넌트처럼 보이면 안 된다.
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              borderSide: const BorderSide(
                color: AppSemanticColors.borderDefault,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              borderSide: const BorderSide(
                color: AppSemanticColors.borderDefault,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              borderSide: const BorderSide(
                color: AppSemanticColors.borderFocus,
                width: 2,
              ),
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('미지정')),
            for (final entry in items.entries)
              DropdownMenuItem<T?>(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
