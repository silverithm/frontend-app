import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/vacation_limit.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';

class AdminVacationLimitsSettingScreen extends StatefulWidget {
  const AdminVacationLimitsSettingScreen({super.key});

  @override
  State<AdminVacationLimitsSettingScreen> createState() =>
      _AdminVacationLimitsSettingScreenState();
}

class _AdminVacationLimitsSettingScreenState
    extends State<AdminVacationLimitsSettingScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedRole = 'CAREGIVER'; // 'CAREGIVER', 'OFFICE', 'all'
  Map<String, Map<String, VacationLimit>> _limitsData =
      {}; // date -> role -> limit
  bool _isLoading = false;
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  void _initializeControllersForCurrentMonth() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    for (
      var date = firstDay;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey = _formatDate(date);

      // CAREGIVER 컨트롤러 - 기본값 3으로 설정 (API에서 로드될 때까지)
      final caregiverKey = '${dateKey}_CAREGIVER';
      _controllers[caregiverKey] = TextEditingController(text: '3');

      // OFFICE 컨트롤러 - 기본값 3으로 설정 (API에서 로드될 때까지)
      final officeKey = '${dateKey}_OFFICE';
      _controllers[officeKey] = TextEditingController(text: '3');
    }
  }

  @override
  void dispose() {
    // TextEditingController들 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVacationLimits() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

      // 선택된 달의 첫째 날과 마지막 날 계산
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final result = await ApiService().getVacationLimits(
        start: _formatDate(firstDay),
        end: _formatDate(lastDay),
        companyId: companyId,
      );

      print('[VacationLimits] API 응답: $result');

      if (result['limits'] != null) {
        final limitsData = <String, Map<String, VacationLimit>>{};
        final limitsList = result['limits'] as List<dynamic>;

        // 응답 데이터 파싱 - 배열 형태의 데이터를 날짜별로 그룹화
        for (final limitItem in limitsList) {
          final limitMap = limitItem as Map<String, dynamic>;
          final date = limitMap['date'] as String;
          final role = (limitMap['role'] as String).toUpperCase();

          if (limitsData[date] == null) {
            limitsData[date] = {};
          }

          limitsData[date]![role] = VacationLimit.fromJson({
            'id': limitMap['id'],
            'date': date,
            'role': role,
            'maxPeople': limitMap['maxPeople'],
          });
        }

        setState(() {
          _limitsData = limitsData;
          _initializeControllers();
        });
      }
    } catch (e) {
      print('[VacationLimits] 로드 실패: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '휴무 제한 데이터 로드 실패: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    // 기존 컨트롤러들 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    // 새 컨트롤러들 생성
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    for (
      var date = firstDay;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey = _formatDate(date);

      // CAREGIVER 컨트롤러
      final caregiverKey = '${dateKey}_CAREGIVER';
      final caregiverLimit = _limitsData[dateKey]?['CAREGIVER']?.maxPeople ?? 3;
      _controllers[caregiverKey] = TextEditingController(
        text: caregiverLimit.toString(),
      );

      // OFFICE 컨트롤러
      final officeKey = '${dateKey}_OFFICE';
      final officeLimit = _limitsData[dateKey]?['OFFICE']?.maxPeople ?? 3;
      _controllers[officeKey] = TextEditingController(
        text: officeLimit.toString(),
      );
    }
  }

  Future<void> _saveVacationLimits() async {
    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

      // 변경된 데이터 수집
      final limitsToSave = <Map<String, dynamic>>[];

      for (final entry in _controllers.entries) {
        final parts = entry.key.split('_');
        if (parts.length != 2) continue;

        final date = parts[0];
        final role = parts[1];
        final maxPeople = int.tryParse(entry.value.text) ?? 0;

        limitsToSave.add({'date': date, 'maxPeople': maxPeople, 'role': role});
      }

      print('[VacationLimits] 저장할 데이터: $limitsToSave');

      final result = await ApiService().saveVacationLimits(
        companyId: companyId,
        limits: limitsToSave,
      );

      if (result['success'] == true) {
        if (mounted) {
          AppSnackBar.showSuccess(context, message: '휴무 제한이 성공적으로 저장되었습니다');
        }
        // 데이터 다시 로드
        await _loadVacationLimits();
      } else {
        throw Exception(result['message'] ?? '저장 실패');
      }
    } catch (e) {
      print('[VacationLimits] 저장 실패: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '휴무 제한 저장 실패: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatYearMonth(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }

  void _previousMonth() {
    // 기존 컨트롤러 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  void _nextMonth() {
    // 기존 컨트롤러 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      // 슬림 타이틀 — 형제 화면(admin_unified_approval/admin_user_management)과 동일하게
      // 아이콘뱃지+서브텍스트+"ADMIN"배지로 제목을 세 번 반복하지 않는다 (중복 강조 정리)
      appBar: AppBar(
        title: Text(
          '휴무 제한 설정',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 월 선택 헤더 — 정적 표면은 그림자 대신 보더만 (Seed 레이아웃 원칙)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    border: Border(
                      bottom: BorderSide(color: AppSemanticColors.borderSubtle),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        _formatYearMonth(_selectedDate),
                        style: AppTypography.heading5,
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),

                // 역할 필터 탭
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.backgroundSecondary,
                    border: Border(
                      bottom: BorderSide(color: AppSemanticColors.borderSubtle),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildRoleTab('요양보호사', 'CAREGIVER')),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(child: _buildRoleTab('사무실', 'OFFICE')),
                    ],
                  ),
                ),

                // 제한 설정 테이블
                Expanded(child: _buildLimitsTable()),

                // 저장 버튼을 아래로 이동 — 정적 표면은 그림자 대신 보더만 (Seed 레이아웃 원칙)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    border: Border(
                      top: BorderSide(color: AppSemanticColors.borderSubtle),
                    ),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: SeedButton(
                        label: _isSaving ? '저장 중...' : '휴무 제한 저장하기',
                        variant: SeedButtonVariant.brandSolid,
                        size: SeedButtonSize.large,
                        isLoading: _isSaving,
                        prefixIcon: Icons.save,
                        onPressed: _isSaving ? null : _saveVacationLimits,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRoleTab(String label, String role) {
    final isSelected = _selectedRole == role;
    return SeedChip(
      label: label,
      selected: isSelected,
      onTap: () => setState(() => _selectedRole = role),
    );
  }

  Widget _buildLimitsTable() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final days = <DateTime>[];

    for (
      var date = firstDay;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      days.add(date);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 텍스트
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            margin: const EdgeInsets.only(bottom: AppSpacing.space4),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusInfoBackground,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(color: AppSemanticColors.statusInfoBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppSemanticColors.statusInfoIcon,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text(
                    '각 날짜별로 최대 휴무 가능 인원을 설정하세요.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.statusInfoText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 날짜별 카드 리스트
          ...days.map((date) => _buildDateCard(date)).toList(),
        ],
      ),
    );
  }

  Widget _buildDateCard(DateTime date) {
    final dateKey = _formatDate(date);
    final isSunday = date.weekday == DateTime.sunday;
    final isSaturday = date.weekday == DateTime.saturday;
    final isWeekend = isSunday || isSaturday;
    final weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    final weekdayName = weekdayNames[date.weekday];

    print('[_buildDateCard] dateKey: $dateKey, selectedRole: $_selectedRole');
    print('[_buildDateCard] controllers: ${_controllers.keys.toList()}');

    // 색상 결정
    Color borderColor;
    Color headerColor;
    Color headerTextColor;
    Color weekdayBgColor;
    Color weekdayTextColor;

    if (isSunday) {
      // 일요일 - 빨간색
      borderColor = AppSemanticColors.statusErrorBorder;
      headerColor = AppSemanticColors.statusErrorBackground;
      headerTextColor = AppSemanticColors.statusErrorText;
      weekdayBgColor = AppSemanticColors.statusErrorBackground;
      weekdayTextColor = AppSemanticColors.statusErrorIcon;
    } else if (isSaturday) {
      // 토요일 - 파란색
      borderColor = AppSemanticColors.statusInfoBorder;
      headerColor = AppSemanticColors.statusInfoBackground;
      headerTextColor = AppSemanticColors.statusInfoText;
      weekdayBgColor = AppSemanticColors.statusInfoBackground;
      weekdayTextColor = AppSemanticColors.statusInfoIcon;
    } else {
      // 평일 - 회색
      borderColor = AppSemanticColors.borderSubtle;
      headerColor = AppSemanticColors.backgroundSecondary;
      headerTextColor = AppSemanticColors.textPrimary;
      weekdayBgColor = AppSemanticColors.backgroundSecondary;
      weekdayTextColor = AppSemanticColors.textSecondary;
    }

    // 정적 리스트 카드 — 그림자 대신 보더만 (Seed 레이아웃 원칙)
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: borderColor, width: isWeekend ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3,
                    vertical: AppSpacing.space1_5,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  ),
                  child: Text(
                    '${date.month}월 ${date.day}일',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: AppSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: weekdayBgColor,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Text(
                    '$weekdayName요일',
                    style: AppTypography.labelSmall.copyWith(
                      color: weekdayTextColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.space3),
            Divider(height: 1, color: AppSemanticColors.borderSubtle),
            const SizedBox(height: AppSpacing.space3),

            // 인원 수 설정 — 카드중첩 없이 구분선 아래 평면 레이아웃 (Seed 레이아웃 원칙)
            if (_selectedRole == 'CAREGIVER') ...[
              // 요양보호사 모드
              _buildLimitInputCard(
                '요양보호사',
                '${dateKey}_CAREGIVER',
                Icons.favorite,
              ),
            ] else if (_selectedRole == 'OFFICE') ...[
              // 사무실 모드
              _buildLimitInputCard('사무실', '${dateKey}_OFFICE', Icons.business),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitInputCard(String title, String key, IconData icon) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppSemanticColors.textSecondary),
            const SizedBox(width: AppSpacing.space1_5),
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '최대',
              style: AppTypography.labelSmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            SizedBox(
              width: AppSpacing.space14,
              height: AppSpacing.space9,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    borderSide: BorderSide(
                      color: AppSemanticColors.borderSubtle,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    borderSide: BorderSide(
                      color: AppSemanticColors.borderFocus,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppSemanticColors.backgroundSecondary,
                ),
                onChanged: (value) {
                  // 빈 문자열이면 0으로 설정
                  if (value.isEmpty) {
                    return;
                  }

                  // 숫자만 허용하고 음수 방지
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    // 이전 값을 유지하되, 잘못된 입력은 제거
                    final validText = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (validText.isNotEmpty) {
                      controller.value = TextEditingValue(
                        text: validText,
                        selection: TextSelection.fromPosition(
                          TextPosition(offset: validText.length),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              '명',
              style: AppTypography.labelSmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
