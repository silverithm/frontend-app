import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/dispatch.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dispatch_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../../utils/dispatch_board_text.dart';
import '../common/app_dialog.dart';
import 'dispatch_attendance_section.dart';
import 'dispatch_status_style.dart';

const _titleWeekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// "9월 16일 (수)" — 화면 제목용. 카톡 공지 문구(formatBoardDate)와는 별개다.
String _formatTitleDate(DateTime date) {
  return '${date.month}월 ${date.day}일 (${_titleWeekdayNames[date.weekday - 1]})';
}

/// 노선배차표 — 하루치 배차를 한 화면에 본다.
///
/// 센터장이 매일 카톡방에 올리던 표를 그대로 옮긴 화면이다. 선생님들이 앱에서
/// "오늘 우리 차 누가 타지"를 스크롤 없이 확인하는 것이 목적이라, 노선 목록이 아니라
/// 차량 카드 한 덩어리로 조밀하게 보여준다. 차량 카드 안 어르신 한 줄마다 탑승/결석/
/// 개인등하원 상태를 바로 보여주므로, 예전처럼 같은 이름이 출결 섹션에 또 나오지 않는다.
///
/// 규칙과 문구는 관리자 웹(DispatchBoard.tsx / dispatchBoardText.ts)과 같다.
class DispatchBoardView extends StatefulWidget {
  /// 달력에서 날짜를 골라 넘어온 경우의 초기 날짜. 없으면 오늘.
  final DateTime? initialDate;

  const DispatchBoardView({super.key, this.initialDate});

  @override
  State<DispatchBoardView> createState() => _DispatchBoardViewState();
}

class _DispatchBoardViewState extends State<DispatchBoardView> {
  late DateTime _date;
  String _routeType = RouteType.toWork;

  bool _isCapturing = false;

  /// 회원관리에 등록된 어르신 (미배정 계산용) — 배차 설정 화면과 같은 API를 쓴다.
  final ApiService _apiService = ApiService();
  List<_ElderRef> _companyElders = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCompanyElders());
  }

  Future<void> _loadCompanyElders() async {
    final companyId = context.read<AuthProvider>().currentUser?.company?.id;
    if (companyId == null || companyId.isEmpty) return;
    try {
      final response = await _apiService.getCompanyElders(companyId: companyId);
      final raw = response['elders'] ?? response['data'] ?? response['content'];
      if (raw is List && mounted) {
        setState(() {
          _companyElders = raw
              .whereType<Map>()
              .map((e) => _ElderRef.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.id != null && e.name.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[배차표] 어르신 목록 조회 실패: $e');
    }
  }

  /// 지금 보는 방향(등원/하원) 노선 어디에도 없는 어르신
  List<_ElderRef> _unassignedElders(DispatchProvider provider) {
    final assignedIds = <int>{};
    for (final senior in provider.seniors) {
      final route = provider.routes.where((r) => r.id == senior.routeId);
      if (route.isEmpty || route.first.type != _routeType) continue;
      final id = senior.elderlyId;
      if (id != null) assignedIds.add(id);
    }
    return _companyElders.where((e) => !assignedIds.contains(e.id)).toList();
  }

  /// 지금 보는 방향에서 결석 처리된 어르신
  List<Senior> _absentSeniors(DispatchProvider provider) {
    final dateStr = formatDate(_date);
    return provider.seniors.where((senior) {
      final route = provider.routes.where((r) => r.id == senior.routeId);
      if (route.isEmpty || route.first.type != _routeType) return false;
      return attendanceStateOf(provider, senior, dateStr).isAbsent;
    }).toList();
  }

  void _showNamesSheet(String title, List<String> names) {
    AppBottomSheet.show<void>(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: names.map((name) => Chip(label: Text(name))).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 어르신 하나를 탭했을 때 — 결석/개인등하원/사유를 바로 손보고, 다른 차로 옮길 수도 있다.
  void _openElderSheet(Senior senior, String routeType) {
    if (senior.elderlyId == null) return; // 회원관리 연결 필요 — 손볼 데이터가 없다

    final provider = context.read<DispatchProvider>();
    final route = provider.routes.where((r) => r.id == senior.routeId);
    final vehicleName = route.isEmpty
        ? ''
        : (route.first.routeDrivers.isNotEmpty &&
                route.first.routeDrivers.first.vehicleName.trim().isNotEmpty
            ? route.first.routeDrivers.first.vehicleName.trim()
            : route.first.name);

    AppBottomSheet.show<void>(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                senior.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              if (vehicleName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  vehicleName,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space3),
              DispatchElderAttendanceTile(
                senior: senior,
                routeType: routeType,
                dateStr: formatDate(_date),
              ),
              const SizedBox(height: AppSpacing.space3),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showMoveVehiclePicker(senior, routeType);
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('다른 차량으로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "다른 차량으로 이동" — 같은 방향(등원/하원)의 다른 노선과, 그 노선이 회차를
  /// 쓴다면 회차까지 골라 그날 수정본으로 저장한다. 정확한 자리는 맨 뒤로 붙인다
  /// (관리자 웹의 드래그 위치 지정과 달리, 여기서는 차/회차만 고른다).
  Future<void> _showMoveVehiclePicker(Senior senior, String routeType) async {
    final provider = context.read<DispatchProvider>();
    final daily = provider.dispatchForDate(_date);
    final candidates = provider.routes
        .where((r) => r.type == routeType && r.id != senior.routeId)
        .toList();

    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('같은 방향의 다른 노선이 없습니다')),
      );
      return;
    }

    final targetRoute = await AppBottomSheet.show<DispatchRoute>(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${senior.name}님을 옮길 차량',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              for (final route in candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(route.name),
                  subtitle: route.routeDrivers.isEmpty
                      ? null
                      : Text(route.routeDrivers.first.driverName),
                  onTap: () => Navigator.of(context).pop(route),
                ),
            ],
          ),
        ),
      ),
    );
    if (targetRoute == null || !mounted) return;

    // 그 노선이 회차를 쓰는지(이미 탑승 중인 누군가에게 tripOrder가 있는지) 본다
    final targetDispatch = daily.routeDispatches
        .where((rd) => rd.routeId == targetRoute.id);
    final usesTrip = targetDispatch.isNotEmpty &&
        targetDispatch.first.tripGroups.any((g) => g.tripOrder != null);

    int? targetTripOrder;
    if (usesTrip) {
      if (!mounted) return;
      targetTripOrder = await AppBottomSheet.show<int>(
        context,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${targetRoute.name} — 몇 회차',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                for (final trip in const [1, 2])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$trip차'),
                    onTap: () => Navigator.of(context).pop(trip),
                  ),
              ],
            ),
          ),
        ),
      );
      if (targetTripOrder == null || !mounted) return;
    }

    final ok = await provider.moveSeniorOverride(
      date: _date,
      seniorId: senior.id,
      targetRouteId: targetRoute.id,
      targetTripOrder: targetTripOrder,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '${senior.name}님을 ${targetRoute.name}(으)로 옮겼습니다' : '이동을 저장하지 못했습니다. 다시 시도해 주세요',
        ),
      ),
    );
  }

  Future<void> _resetOverrides() async {
    final provider = context.read<DispatchProvider>();
    final ok = await provider.resetOverridesForDate(_date);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '오늘 배차를 설정대로 되돌렸습니다' : '되돌리기에 실패했습니다')),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
      locale: const Locale('ko'),
    );
    if (picked == null || !mounted) return;

    // 달이 바뀌었는지는 상태를 바꾸기 전에 봐야 한다
    final movedToAnotherMonth =
        picked.month != _date.month || picked.year != _date.year;

    setState(() => _date = picked);

    if (movedToAnotherMonth) {
      await context.read<DispatchProvider>().loadAttendancesForMonth(picked);
    }
  }

  Future<void> _copyText(DailyDispatch daily) async {
    await Clipboard.setData(
      ClipboardData(text: buildDispatchBoardText(daily, _routeType)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배차표를 복사했습니다')),
    );
  }

  /// 배차표를 그림으로 만들어 공유 시트로 넘긴다.
  /// 카톡방에 올리는 것이 목적이라 앨범 저장이 아니라 바로 공유로 간다.
  ///
  /// 화면에 보이는 부분만 떠서는 안 된다. 차가 열세 대면 리스트는 여섯 대만
  /// 그려 두므로, 화면을 그대로 찍으면 나머지가 잘린 그림이 나간다.
  /// 그래서 화면과 별개로 표 전체를 한 번 그려서(captureFromLongWidget) 찍는다.
  Future<void> _shareImage(DailyDispatch daily, List<RouteDispatch> dispatches,
      List<Senior> personal) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final bytes = await ScreenshotController().captureFromLongWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              width: 720,
              // 배경을 주지 않으면 투명 PNG가 나와 카톡에서 글자가 안 보인다
              color: AppSemanticColors.backgroundSecondary,
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final rd in dispatches)
                    _RouteBlock(
                      dispatch: rd,
                      routeSeniors: _routeSeniorsOf(
                        context.read<DispatchProvider>(),
                        rd.routeId,
                      ),
                      provider: context.read<DispatchProvider>(),
                      dateStr: formatDate(_date),
                    ),
                ],
              ),
            ),
          ),
        ),
        pixelRatio: 2,
        context: context,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/배차표_${formatDate(_date)}_$_routeType.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${formatBoardDate(formatDate(_date))} $_routeType 배차표',
        ),
      );
    } catch (e) {
      debugPrint('[배차표] 이미지 공유 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 만들지 못했습니다. 텍스트 복사를 이용해 주세요')),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  List<Senior> _routeSeniorsOf(DispatchProvider provider, String routeId) {
    return provider.seniors.where((s) => s.routeId == routeId).toList()
      ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final daily = provider.dispatchForDate(_date);
    final dispatches = selectRouteDispatches(daily, _routeType);
    final personal = _routeType == RouteType.toWork
        ? daily.personalPickupSeniors
        : daily.personalDropoffSeniors;
    final unassigned = _unassignedElders(provider);
    final absent = _absentSeniors(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopSection(daily, dispatches, personal, provider, unassigned, absent),
        Expanded(child: _buildRouteList(dispatches, provider)),
      ],
    );
  }

  Widget _buildRouteList(List<RouteDispatch> dispatches, DispatchProvider provider) {
    if (dispatches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          0,
          AppSpacing.space4,
          AppSpacing.space4,
        ),
        children: [
          Center(
            child: Text(
              '$_routeType 노선이 없습니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      itemCount: dispatches.length,
      itemBuilder: (_, index) {
        final dispatch = dispatches[index];
        return _RouteBlock(
          dispatch: dispatch,
          routeSeniors: _routeSeniorsOf(provider, dispatch.routeId),
          provider: provider,
          dateStr: formatDate(_date),
          onSeniorTap: (senior) => _openElderSheet(senior, _routeType),
        );
      },
    );
  }

  /// 헤더 한 덩어리 — 날짜/제목 줄, 등원·하원 전환, 상태 요약 칩들.
  /// 카드 A/B/C처럼 정보 세 종류를 한 줄에 욱여넣던 예전 헤더를 세 줄로 풀었다.
  Widget _buildTopSection(
    DailyDispatch daily,
    List<RouteDispatch> dispatches,
    List<Senior> personal,
    DispatchProvider provider,
    List<_ElderRef> unassigned,
    List<Senior> absent,
  ) {
    final personalLabel = _routeType == RouteType.toWork ? '개인등원' : '개인하원';
    final carCount = countPassengers(dispatches);
    final hasOverrides = provider.hasOverridesForDate(_date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space3,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppSemanticColors.interactivePrimaryDefault,
                      ),
                      const SizedBox(width: AppSpacing.space1_5),
                      Text(
                        _formatTitleDate(_date),
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: AppTypography.fontWeightBold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyText(daily),
                icon: const Icon(Icons.copy_outlined),
                iconSize: 20,
                tooltip: '텍스트 복사',
              ),
              IconButton(
                onPressed: _isCapturing
                    ? null
                    : () => _shareImage(daily, dispatches, personal),
                icon: _isCapturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                iconSize: 20,
                tooltip: '이미지로 공유',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            children: [
              _DirectionToggle(
                value: _routeType,
                onChanged: (value) => setState(() => _routeType = value),
              ),
              const Spacer(),
              if (hasOverrides)
                TextButton(
                  onPressed: _resetOverrides,
                  child: const Text('원래대로'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space1_5,
            children: [
              _StatChip(label: '탑승', count: carCount),
              _StatChip(
                label: '결석',
                count: absent.length,
                tone: _StatTone.warning,
                onTap: absent.isEmpty
                    ? null
                    : () => _showNamesSheet(
                        '결석 ${absent.length}명',
                        absent.map((s) => s.name).toList(),
                      ),
              ),
              _StatChip(
                label: personalLabel,
                count: personal.length,
                tone: _StatTone.info,
                onTap: personal.isEmpty
                    ? null
                    : () => _showNamesSheet(
                        '$personalLabel ${personal.length}명',
                        personal.map((s) => s.name).toList(),
                      ),
              ),
              _StatChip(
                label: '미배정',
                count: unassigned.length,
                tone: _StatTone.warning,
                onTap: unassigned.isEmpty
                    ? null
                    : () => _showNamesSheet(
                        '미배정 어르신 ${unassigned.length}명',
                        unassigned.map((e) => e.name).toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 회원관리에 등록된 어르신 (미배정 계산용)
class _ElderRef {
  final int? id;
  final String name;

  const _ElderRef({this.id, required this.name});

  factory _ElderRef.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return _ElderRef(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
    );
  }
}

/// 등원/하원 전환
class _DirectionToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DirectionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RouteType.values.map((type) {
          final selected = value == type;
          return GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppSemanticColors.surfaceDefault
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Text(
                type,
                style: AppTypography.bodySmall.copyWith(
                  color: selected
                      ? AppSemanticColors.textPrimary
                      : AppSemanticColors.textTertiary,
                  fontWeight: selected
                      ? AppTypography.fontWeightSemibold
                      : AppTypography.fontWeightNormal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _StatTone { neutral, warning, info }

/// 요약 줄의 작은 통계 칩. 0명이어도 자리를 지켜서 매일 같은 위치에서 읽힌다.
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final _StatTone tone;
  final VoidCallback? onTap;

  const _StatChip({
    required this.label,
    required this.count,
    this.tone = _StatTone.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    Color background;
    Color foreground;
    switch (tone) {
      case _StatTone.warning:
        background = active
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.backgroundTertiary;
        foreground = active
            ? AppSemanticColors.statusWarningText
            : AppSemanticColors.textTertiary;
        break;
      case _StatTone.info:
        background = active
            ? AppSemanticColors.brandWeak
            : AppSemanticColors.backgroundTertiary;
        foreground = active
            ? AppSemanticColors.brandPressed
            : AppSemanticColors.textTertiary;
        break;
      case _StatTone.neutral:
        background = AppSemanticColors.backgroundTertiary;
        foreground = AppSemanticColors.textSecondary;
        break;
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2_5,
        vertical: AppSpacing.space1_5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        '$label $count명',
        style: AppTypography.caption.copyWith(
          color: foreground,
          fontWeight: AppTypography.fontWeightMedium,
        ),
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// 차량 한 대 — 차량 이름 + 승차정원, 운전자 칩, 상태 배지, 어르신 한 줄씩.
/// [routeSeniors]는 그 노선에 설정된 전체 어르신(오늘 탑승 여부와 무관)이다.
/// 탑승/결석/개인등하원을 한 줄에서 상태 배지로 구분해서 보여주므로,
/// 예전처럼 출결만 따로 모은 섹션이 필요 없다.
class _RouteBlock extends StatelessWidget {
  final RouteDispatch dispatch;
  final List<Senior> routeSeniors;
  final DispatchProvider provider;
  final String dateStr;
  final ValueChanged<Senior>? onSeniorTap;

  const _RouteBlock({
    required this.dispatch,
    required this.routeSeniors,
    required this.provider,
    required this.dateStr,
    this.onSeniorTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOff = dispatch.status == DispatchStatus.noService ||
        dispatch.status == DispatchStatus.holiday;
    final style = DispatchStatusStyle.of(dispatch.status);

    final vehicleName = (dispatch.driver?.vehicleName.trim().isNotEmpty ?? false)
        ? dispatch.driver!.vehicleName.trim()
        : dispatch.routeName;
    final showRouteNameHint = vehicleName != dispatch.routeName;
    final capacity = dispatch.driver?.vehicleCapacity ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: isOff
            ? AppSemanticColors.backgroundTertiary
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            vehicleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                              fontWeight: AppTypography.fontWeightSemibold,
                            ),
                          ),
                        ),
                        if (capacity > 0) ...[
                          const SizedBox(width: AppSpacing.space1_5),
                          Text(
                            '$capacity인승',
                            style: AppTypography.caption.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showRouteNameHint) ...[
                      const SizedBox(height: 2),
                      Text(
                        dispatch.routeName,
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              _StatusBadge(style: style),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          if (isOff)
            Text(
              dispatch.reason ?? dispatch.status,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else ...[
            _DriverChip(dispatch: dispatch),
            const SizedBox(height: AppSpacing.space2),
            Divider(height: 1, color: AppSemanticColors.borderSubtle),
            if (routeSeniors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                child: Text(
                  '탑승 없음',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              )
            else
              ..._buildTripGroups(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTripGroups() {
    final groups = groupPassengersByTrip(routeSeniors);
    final widgets = <Widget>[];
    for (final group in groups) {
      if (group.tripOrder != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space1_5, bottom: 2),
            child: Text(
              '${group.tripOrder}차 · ${group.seniors.length}명',
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.interactivePrimaryDefault,
                fontWeight: AppTypography.fontWeightSemibold,
              ),
            ),
          ),
        );
      }
      for (final senior in group.seniors) {
        widgets.add(
          _ElderRow(
            senior: senior,
            provider: provider,
            dateStr: dateStr,
            routeType: dispatch.routeType,
            onTap: onSeniorTap,
          ),
        );
      }
    }
    return widgets;
  }
}

class _StatusBadge extends StatelessWidget {
  final DispatchStatusStyle style;

  const _StatusBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.foreground),
          const SizedBox(width: AppSpacing.space1),
          Text(
            style.label,
            style: AppTypography.caption.copyWith(
              color: style.foreground,
              fontWeight: AppTypography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 운전자 칩 — 대체 운행이면 경고 톤으로 바뀌고, 탭하면 사유를 보여준다.
class _DriverChip extends StatelessWidget {
  final RouteDispatch dispatch;

  const _DriverChip({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final driver = dispatch.driver;
    if (driver == null) {
      return Text(
        dispatch.reason ?? '운행 정보 없음',
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textTertiary,
        ),
      );
    }

    final isSubstitute = dispatch.status == DispatchStatus.substitute;
    final label = isSubstitute
        ? '대체 · ${dispatch.driverRole ?? ''} ${driver.driverName}'
        : '${dispatch.driverRole ?? '운전자'} ${driver.driverName}';

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2_5,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: isSubstitute
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 14,
            color: isSubstitute
                ? AppSemanticColors.statusWarningText
                : AppSemanticColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.space1),
          Text(
            label.trim(),
            style: AppTypography.bodySmall.copyWith(
              color: isSubstitute
                  ? AppSemanticColors.statusWarningText
                  : AppSemanticColors.textSecondary,
              fontWeight: AppTypography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );

    if (!isSubstitute || dispatch.reason == null) return chip;

    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dispatch.reason!)),
      ),
      child: chip,
    );
  }
}

/// 어르신 한 줄 — 이름 + 상태 배지(탑승은 배지 없음) + 화살표.
class _ElderRow extends StatelessWidget {
  final Senior senior;
  final DispatchProvider provider;
  final String dateStr;
  final String routeType;
  final ValueChanged<Senior>? onTap;

  const _ElderRow({
    required this.senior,
    required this.provider,
    required this.dateStr,
    required this.routeType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (senior.elderlyId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1_5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                senior.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
            Text(
              '회원관리 연결 필요',
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final state = attendanceStateOf(provider, senior, dateStr);
    final isPickupRoute = routeType == RouteType.toWork;
    final personalChecked = isPickupRoute ? state.personalPickup : state.personalDropoff;
    final personalLabel = isPickupRoute ? '개인등원' : '개인하원';

    Widget? pill;
    if (state.isAbsent) {
      pill = const _StatusPill(
        label: '결석',
        foreground: AppSemanticColors.statusErrorText,
        background: AppSemanticColors.statusErrorBackground,
      );
    } else if (personalChecked) {
      pill = _StatusPill(
        label: personalLabel,
        foreground: AppSemanticColors.interactivePrimaryDefault,
        outlined: true,
      );
    }

    final interactive = onTap != null;

    return InkWell(
      onTap: interactive ? () => onTap!(senior) : null,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1_5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                senior.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textPrimary,
                  decoration: state.isAbsent ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (pill != null) ...[pill, const SizedBox(width: AppSpacing.space1)],
            if (interactive)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppSemanticColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color? background;
  final bool outlined;

  const _StatusPill({
    required this.label,
    required this.foreground,
    this.background,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: outlined ? Border.all(color: foreground) : null,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: foreground,
          fontWeight: AppTypography.fontWeightMedium,
        ),
      ),
    );
  }
}
