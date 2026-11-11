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
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/common/app_tag.dart';

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
    // B안: 옅은 회색 바탕 위 흰 카드(날짜별), 머리 줄·역할 칩은 바탕 위에 선 없이
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      // 슬림 타이틀 — 형제 화면(admin_unified_approval/admin_user_management)과 동일하게
      // 아이콘뱃지+서브텍스트+"ADMIN"배지로 제목을 세 번 반복하지 않는다 (중복 강조 정리)
      appBar: const CareVAppBar(title: '휴무 제한 설정'),
      // 불러오는 동안(처음·달 바꿈 — 칸을 비우고 새로 채운다)은 날짜 카드 뼈대
      body: _isLoading
          ? const _VacationLimitsSkeleton()
          : Column(
              children: [
                // 월 선택 헤더 — 회색 바탕 위에 선 없이
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space2,
                    AppSpacing.space2,
                    AppSpacing.space2,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: '이전 달',
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: Text(
                          _formatYearMonth(_selectedDate),
                          style: AppTypography.heading5,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: '다음 달',
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),

                // 역할 필터 칩 — 회색 바탕 위 흰 칩(고르면 틸), 머리띠·선 없음
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.space1,
                      AppSpacing.screenGutter,
                      AppSpacing.space1,
                    ),
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

                // 저장 버튼 — 아래 흰 띠(선 없이 바탕색 차이로 나눈다)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: const BoxDecoration(
                    color: AppSemanticColors.surfaceCard,
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
      onCanvas: true,
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
            '설정할 역할이 없습니다.\n웹 회원관리 > 종사자 관리의 \'역할 관리\'에서 역할을 먼저 등록해주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space2,
        AppSpacing.screenGutter,
        AppSpacing.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 텍스트 — 테두리 없는 옅은 파랑 칸
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusInfoBackground,
              borderRadius: BorderRadius.circular(AppBorderRadius.control),
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

    // 주말은 날짜 글자만 빨강(달력 관례). 테두리·바탕·꼬리표까지 빨갛게 하면
    // 잘못 입력한 칸처럼 보여서(4차 점검 2026-11-08) 카드·꼬리표는 평일과 같게 둔다.
    final Color headerTextColor = isWeekend
        ? AppSemanticColors.statusErrorText
        : AppSemanticColors.textPrimary;

    // B안 카드 — 흰 바탕, 테두리 없음, 모서리 20, 카드 사이 간격 12
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 헤더 — 회색 알약 없이 카드 맨 위 제목 글자 + 요일 꼬리표
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${date.month}월 ${date.day}일',
                  style: AppTypography.titleMedium.copyWith(
                    color: headerTextColor,
                  ),
                ),
                AppTag(
                  label: '$weekdayName요일',
                  tone: AppTagTone.neutral,
                ),
              ],
            ),

            // 구분선 대신 간격
            const SizedBox(height: AppSpacing.space4),

            // 인원 수 설정 — 카드중첩 없이 평면 레이아웃
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
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
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
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            // B안 입력칸 — 회색 채움, 테두리 없음(누르면 틸 2px). 높이를 못 박지 않아 글자가 커져도 안 잘린다
            SizedBox(
              width: 72,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                    borderSide: BorderSide(
                      color: AppSemanticColors.borderFocus,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: AppSpacing.space3,
                  ),
                  filled: true,
                  fillColor: AppSemanticColors.fillDefault,
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
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 휴무 제한 첫 불러오기 뼈대 — 월 머리 줄·역할 칩 줄 자리 + 회색 바탕 위 흰 날짜 카드(같은 여백·간격)
class _VacationLimitsSkeleton extends StatelessWidget {
  const _VacationLimitsSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          // 월 머리 줄(위 8 + 단추 48) + 역할 칩 줄(위아래 4 + 칩 44) 만큼 비워 둔다
          AppSpacing.space2 + 48 + AppSpacing.space1 * 2 + 44 +
              AppSpacing.space2,
          AppSpacing.screenGutter,
          AppSpacing.space6,
        ),
        children: List.generate(
          4,
          (_) => const AppSkeletonCard(
            standalone: false,
            margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
          ),
        ),
      ),
    );
  }
}
