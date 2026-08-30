import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/dispatch/dispatch_board_view.dart';
import '../widgets/dispatch/dispatch_calendar_view.dart';
import '../widgets/dispatch/dispatch_day_sheet.dart';
import '../widgets/dispatch/dispatch_list_view.dart';
import '../widgets/dispatch/senior_absence_view.dart';
import '../widgets/seed/seed_button.dart';
import 'dispatch_settings_screen.dart';

/// 배차관리 — 배차표 / 달력 / 목록 / 출결 네 화면과 설정 진입.
///
/// 기본은 배차표다. 선생님들이 가장 자주 확인하는 것이 "오늘 우리 차 명단"이라
/// 앱을 열면 그것부터 보이게 한다. 나머지 화면은 그대로 남겨 뒀다.
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
    const labels = ['배차표', '달력', '목록', '출결'];

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
        return const DispatchBoardView();
      case 2:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: DispatchListView(
            settings: provider.settings,
            vacations: provider.vacations,
            attendances: provider.attendances,
          ),
        );
      case 3:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: SeniorAbsenceView(),
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
              _buildSummaryRow(provider),
              const SizedBox(height: AppSpacing.space4),
              DispatchCalendarView(
                month: _month,
                summary: provider.summaryForMonth(_month.year, _month.month),
                onDateSelected: (date) => DispatchDaySheet.show(
                  context,
                  date: date,
                  dispatch: provider.dispatchForDate(date),
                ),
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
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSummaryRow(DispatchProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            value: '${provider.routes.length}',
            label: '노선',
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: _SummaryTile(
            value: '${provider.seniors.length}',
            label: '어르신',
          ),
        ),
      ],
    );
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

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.heading5.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: AppTypography.fontWeightBold,
            ),
          ),
          const SizedBox(height: AppSpacing.space0_5),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
