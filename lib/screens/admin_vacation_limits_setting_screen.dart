import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/position_option.dart';
import '../models/vacation_limit.dart';
import '../utils/role_utils.dart';
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
  static const int _defaultMaxPeople = 3;

  DateTime _selectedDate = DateTime.now();

  /// 기관이 등록한 직책에서 만들어지는 탭. 웹(AdminPanel)과 같은 목록이어야 한다.
  List<String> _roleNames = [];
  String _selectedRole = '';
  Map<String, Map<String, VacationLimit>> _limitsData =
      {}; // date -> role -> limit
  bool _isLoading = false;
  bool _isSaving = false;

  /// date -> role -> controller. 역할 이름이 기관마다 자유 문자열이라
  /// 'date_role' 한 줄로 합치면 이름에 '_'가 들어갈 때 갈라지므로 중첩 맵으로 둔다.
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadVacationLimits();
  }

  void _disposeControllers() {
    for (final byRole in _controllers.values) {
      for (final controller in byRole.values) {
        controller.dispose();
      }
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<DateTime> _daysOfSelectedMonth() {
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
    return days;
  }

  /// 기관이 등록한 직책 목록을 받아온다. 실패하거나 한 곳도 등록이 없으면
  /// 저장된 한도에 남아 있는 역할로, 그것도 없으면 예전 두 분류로 되돌린다.
  Future<List<PositionOption>> _loadPositions(String companyId) async {
    if (companyId.isEmpty) {
      return const [];
    }
    try {
      final result = await ApiService().getPositions(companyId: companyId);
      final raw = result['positions'];
      if (raw is! List) {
        return const [];
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PositionOption.fromJson)
          .toList();
    } catch (e) {
      print('[VacationLimits] 직책 목록 로드 실패: $e');
      return const [];
    }
  }

  Future<void> _loadVacationLimits() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

      // 선택된 달의 첫째 날과 마지막 날 계산
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final results = await Future.wait([
        ApiService().getVacationLimits(
          start: _formatDate(firstDay),
          end: _formatDate(lastDay),
          companyId: companyId,
        ),
        _loadPositions(companyId),
      ]);

      final result = results[0] as Map<String, dynamic>;
      final positions = results[1] as List<PositionOption>;

      print('[VacationLimits] API 응답: $result');

      final limitsData = <String, Map<String, VacationLimit>>{};
      final rolesInLimits = <String>[];

      final limitsList = result['limits'];
      if (limitsList is List) {
        // 응답 데이터 파싱 - 배열 형태의 데이터를 날짜별로 그룹화
        for (final limitItem in limitsList) {
          if (limitItem is! Map) continue;
          final limitMap = Map<String, dynamic>.from(limitItem);
          final date = limitMap['date']?.toString();
          if (date == null || date.isEmpty) continue;

          // 대문자로 올리지 않는다 — 기관이 만든 직책 이름은 원문 그대로가 키다.
          final role = RoleUtils.normalize(limitMap['role']?.toString());
          if (role.isEmpty) continue;

          rolesInLimits.add(role);

          limitsData.putIfAbsent(date, () => {});
          limitsData[date]![role] = VacationLimit.fromJson({
            'id': limitMap['id'],
            'date': date,
            'role': role,
            'maxPeople': limitMap['maxPeople'],
          });
        }
      }

      final roleNames = RoleUtils.buildRoleNames(
        positions: positions,
        extraRoles: rolesInLimits,
      );

      setState(() {
        _limitsData = limitsData;
        _roleNames = roleNames;
        if (!roleNames.contains(_selectedRole)) {
          _selectedRole = roleNames.isEmpty ? '' : roleNames.first;
        }
        _initializeControllers();
      });
    } catch (e) {
      print('[VacationLimits] 로드 실패: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '휴무 제한 데이터 로드 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeControllers() {
    _disposeControllers();

    for (final date in _daysOfSelectedMonth()) {
      final dateKey = _formatDate(date);
      final byRole = <String, TextEditingController>{};
      for (final role in _roleNames) {
        final maxPeople =
            _limitsData[dateKey]?[role]?.maxPeople ?? _defaultMaxPeople;
        byRole[role] = TextEditingController(text: maxPeople.toString());
      }
      _controllers[dateKey] = byRole;
    }
  }

  Future<void> _saveVacationLimits() async {
    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

      // 변경된 데이터 수집
      final limitsToSave = <Map<String, dynamic>>[];

      for (final dateEntry in _controllers.entries) {
        for (final roleEntry in dateEntry.value.entries) {
          final maxPeople = int.tryParse(roleEntry.value.text) ?? 0;
          limitsToSave.add({
            'date': dateEntry.key,
            'maxPeople': maxPeople,
            'role': roleEntry.key,
          });
        }
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
    setState(() {
      _disposeControllers();
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
    _loadVacationLimits();
  }

  void _nextMonth() {
    setState(() {
      _disposeControllers();
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
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
                        tooltip: '이전 달',
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        _formatYearMonth(_selectedDate),
                        style: AppTypography.heading5,
                      ),
                      IconButton(
                        tooltip: '다음 달',
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final role in _roleNames) ...[
                          _buildRoleTab(RoleUtils.displayName(role), role),
                          const SizedBox(width: AppSpacing.space2),
                        ],
                      ],
                    ),
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
    final days = _daysOfSelectedMonth();

    if (_roleNames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Text(
            '설정할 역할이 없습니다.\n회원관리의 역할관리에서 역할을 먼저 등록해주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
      );
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
          ...days.map(_buildDateCard),
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
            _buildLimitInputCard(
              RoleUtils.displayName(_selectedRole),
              dateKey,
              _selectedRole,
              _roleIcon(_selectedRole),
            ),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'caregiver':
        return Icons.favorite;
      case 'office':
        return Icons.business;
      default:
        return Icons.badge_outlined;
    }
  }

  Widget _buildLimitInputCard(
    String title,
    String dateKey,
    String role,
    IconData icon,
  ) {
    final controller = _controllers[dateKey]?[role];
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
