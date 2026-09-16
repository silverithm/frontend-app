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

/// 노선배차표 — 하루치 배차를 한 화면에 본다.
///
/// 센터장이 매일 카톡방에 올리던 표를 그대로 옮긴 화면이다. 선생님들이 앱에서
/// "오늘 우리 차 누가 타지"를 스크롤 없이 확인하는 것이 목적이라, 노선 목록이 아니라
/// 차량-회차-명단 한 덩어리로 조밀하게 보여준다. 아래에는 출결 섹션이 바로 붙어서
/// 배차표를 보면서 결석을 바로 체크할 수 있다(예전의 "출결" 탭을 합친 것).
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

  void _showUnassignedNames(List<_ElderRef> unassigned) {
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
                '미배정 어르신 ${unassigned.length}명',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: unassigned
                    .map((e) => Chip(label: Text(e.name)))
                    .toList(),
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

    AppBottomSheet.show<void>(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DispatchElderAttendanceTile(
                senior: senior,
                routeType: routeType,
                dateStr: formatDate(_date),
              ),
              const SizedBox(height: AppSpacing.space2),
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
                  _buildHeader(
                    daily,
                    personal,
                    context.read<DispatchProvider>(),
                    _unassignedElders(context.read<DispatchProvider>()),
                  ),
                  for (final rd in dispatches) _RouteBlock(dispatch: rd),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final daily = provider.dispatchForDate(_date);
    final dispatches = selectRouteDispatches(daily, _routeType);
    final personal = _routeType == RouteType.toWork
        ? daily.personalPickupSeniors
        : daily.personalDropoffSeniors;
    final unassigned = _unassignedElders(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControls(daily, dispatches, personal),
        _buildHeader(daily, personal, provider, unassigned),
        Expanded(child: _buildRouteList(dispatches)),
      ],
    );
  }

  Widget _buildRouteList(List<RouteDispatch> dispatches) {
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
          DispatchAttendanceSection(date: _date),
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
      // 노선 카드들 다음에 출결 섹션을 한 항목 더 붙인다
      itemCount: dispatches.length + 1,
      itemBuilder: (_, index) {
        if (index == dispatches.length) {
          return DispatchAttendanceSection(date: _date);
        }
        return _RouteBlock(
          dispatch: dispatches[index],
          onSeniorTap: (senior) => _openElderSheet(senior, _routeType),
        );
      },
    );
  }

  Widget _buildControls(
    DailyDispatch daily,
    List<RouteDispatch> dispatches,
    List<Senior> personal,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(formatBoardDate(formatDate(_date))),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          _DirectionToggle(
            value: _routeType,
            onChanged: (value) => setState(() => _routeType = value),
          ),
          const SizedBox(width: AppSpacing.space2),
          IconButton(
            onPressed: () => _copyText(daily),
            icon: const Icon(Icons.copy_outlined),
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
            tooltip: '이미지로 공유',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    DailyDispatch daily,
    List<Senior> personal,
    DispatchProvider provider,
    List<_ElderRef> unassigned,
  ) {
    final personalLabel = _routeType == RouteType.toWork ? '개인등원' : '개인하원';
    final totalRegistered = provider.seniors.where((s) {
      final route = provider.routes.where((r) => r.id == s.routeId);
      return route.isNotEmpty && route.first.type == _routeType;
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${formatBoardDate(daily.date)} $_routeType',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '탑승 ${countAttending(daily, _routeType)}명 · 전체 $totalRegistered명',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.interactivePrimaryDefault,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              if (provider.hasOverridesForDate(_date)) ...[
                const Spacer(),
                TextButton(
                  onPressed: _resetOverrides,
                  child: const Text('원래대로'),
                ),
              ],
            ],
          ),
          if (unassigned.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space1),
            GestureDetector(
              onTap: () => _showUnassignedNames(unassigned),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusWarningBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: Text(
                  '미배정 ${unassigned.length}명',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.statusWarningText,
                    fontWeight: AppTypography.fontWeightMedium,
                  ),
                ),
              ),
            ),
          ],
          if (personal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space1),
            Text(
              '[$personalLabel : ${personal.map((s) => s.name).join(', ')}]',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
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

/// 차량 한 대 — 헤드라인 + 회차별 명단
class _RouteBlock extends StatelessWidget {
  final RouteDispatch dispatch;
  final ValueChanged<Senior>? onSeniorTap;

  const _RouteBlock({required this.dispatch, this.onSeniorTap});

  @override
  Widget build(BuildContext context) {
    final isOff =
        dispatch.status == DispatchStatus.noService ||
        dispatch.status == DispatchStatus.holiday;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: isOff
            ? AppSemanticColors.backgroundTertiary
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  buildRouteHeadline(dispatch),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
              ),
              if (!isOff)
                Text(
                  '${dispatch.passengers.length}명',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),

          if (isOff)
            Text(
              dispatch.reason ?? dispatch.status,
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else if (dispatch.tripGroups.isEmpty)
            Text(
              '탑승 없음',
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else
            ...dispatch.tripGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.tripOrder != null) ...[
                      Text(
                        '${group.tripOrder}차)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.interactivePrimaryDefault,
                          fontWeight: AppTypography.fontWeightSemibold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space1),
                    ],
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.space1,
                        children: group.seniors
                            .map(
                              (senior) => GestureDetector(
                                onTap: onSeniorTap == null
                                    ? null
                                    : () => onSeniorTap!(senior),
                                child: Text(
                                  senior.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textSecondary,
                                    decoration: onSeniorTap == null
                                        ? null
                                        : TextDecoration.underline,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
