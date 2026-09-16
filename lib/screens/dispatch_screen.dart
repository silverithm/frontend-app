import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/dispatch.dart';
import '../providers/dispatch_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dispatch/dispatch_board_view.dart';
import '../widgets/dispatch/dispatch_calendar_view.dart';
import '../widgets/seed/seed_button.dart';
import 'dispatch_settings_screen.dart';

/// 배차관리 — 배차표 / 달력 두 화면과 설정 진입.
///
/// 기본은 배차표다. 선생님들이 가장 자주 확인하는 것이 "오늘 우리 차 명단"이라
/// 앱을 열면 그것부터 보이게 한다. 예전엔 목록/출결 탭이 따로 있었지만, 출결은
/// 배차표를 보면서 바로 체크하는 게 현장 흐름이라 배차표 화면에 합쳤고, 목록은
/// 배차표와 겹치는 정보라 없앴다.
///
/// 관리자 웹의 배차관리 탭과 같은 구성이다. 설정은 서버 한 곳에 있어서
/// 웹에서 짠 노선이 앱에 그대로 보이고, 앱에서 고치면 웹에도 반영된다.
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  int _tabIndex = 0;
  late DateTime _month;

  /// 달력에서 날짜를 골라 배차표로 넘어온 경우의 날짜. ValueKey로 배차표를
  /// 새로 만들어 그 날짜부터 보여준다.
  DateTime? _boardJumpDate;

  /// 달력 펼쳐보기. 접힌 상태가 기본이라 한 달이 한 화면에 들어온다.
  bool _calendarExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<AuthProvider>().currentUser?.company?.id;
    if (companyId == null || companyId.isEmpty) return;
    await context.read<DispatchProvider>().load(companyId: companyId);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DispatchSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
          '배차관리',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '배차 설정',
          ),
        ],
      ),
      body: SafeArea(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTabs(),
                  if (provider.isEmpty)
                    Expanded(child: _buildSetupGuide())
                  else
                    Expanded(child: _buildBody(provider)),
                ],
              ),
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['배차표', '달력'];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space3,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      padding: const EdgeInsets.all(AppSpacing.space1),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _tabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space2,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppSemanticColors.surfaceDefault
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Text(
                  labels[index],
                  style: AppTypography.bodySmall.copyWith(
                    color: selected
                        ? AppSemanticColors.textPrimary
                        : AppSemanticColors.textTertiary,
                    fontWeight: selected
                        ? AppTypography.fontWeightSemibold
                        : AppTypography.fontWeightMedium,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody(DispatchProvider provider) {
    switch (_tabIndex) {
      case 0:
        // ValueKey로 날짜가 바뀔 때마다 새로 만들어야 달력에서 고른 날짜부터
        // 보여준다 — 배차표는 자기 날짜를 내부 상태로 들고 있어서다.
        return DispatchBoardView(
          key: ValueKey(_boardJumpDate),
          initialDate: _boardJumpDate,
        );
      default:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              AppSpacing.space2,
              AppSpacing.space4,
              AppSpacing.space6,
            ),
            children: [
              DispatchCalendarView(
                month: _month,
                summary: provider.summaryForMonth(_month.year, _month.month),
                // 노선·어르신 수는 매일 보는 값이 아니라, 달력 제목 옆에 무채색
                // 보조 문구로만 붙인다(달력이 한 화면에 들어오는 쪽이 우선이다).
                subtitle: _summaryText(provider),
                // 날짜를 고르면 배차표 탭으로 넘어가 그 날짜를 바로 보여준다.
                // 예전엔 여기서 DispatchDaySheet(요약 바텀시트)를 띄웠지만,
                // 배차표가 같은 정보를 더 자세히 보여주므로 없앴다.
                onDateSelected: (date) => setState(() {
                  _boardJumpDate = date;
                  _tabIndex = 0;
                }),
                onPreviousMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNextMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                onToday: () {
                  final now = DateTime.now();
                  setState(() => _month = DateTime(now.year, now.month));
                },
                isExpanded: _calendarExpanded,
                onToggleExpanded: () =>
                    setState(() => _calendarExpanded = !_calendarExpanded),
              ),
            ],
          ),
        );
    }
  }

  /// 등원 N · 하원 N · 어르신 N — 달력 제목 옆 보조 문구
  String _summaryText(DispatchProvider provider) {
    // 등원·하원 노선을 따로 세고, 어르신은 두 방향에 같은 분이 겹치므로 사람 수로 센다
    return '등원 ${provider.routes.where((r) => r.type == RouteType.toWork).length}'
        ' · 하원 ${provider.routes.where((r) => r.type == RouteType.toHome).length}'
        ' · 어르신 ${provider.seniors.map((s) => s.elderlyId ?? s.name).toSet().length}';
  }

  Widget _buildSetupGuide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 44,
              color: AppSemanticColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              '배차 설정이 필요합니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
                fontWeight: AppTypography.fontWeightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '노선과 운전자를 먼저 등록해주세요',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            SeedButton(
              label: '설정하러 가기',
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
    );
  }
}

