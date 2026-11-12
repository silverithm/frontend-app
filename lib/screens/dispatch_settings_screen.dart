import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../models/dispatch.dart';
import '../models/user.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_fab.dart';
import '../widgets/common/app_sheet_frame.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';

/// 배차 설정 — 노선을 만들고 운전자와 어르신을 붙인다.
///
/// 관리자 웹의 '배차 설정' 모달과 같은 일을 한다. 저장은 서버 한 곳이므로
/// 여기서 고친 내용이 웹에도 그대로 보인다.
class DispatchSettingsScreen extends StatefulWidget {
  const DispatchSettingsScreen({super.key});

  @override
  State<DispatchSettingsScreen> createState() => _DispatchSettingsScreenState();
}

class _DispatchSettingsScreenState extends State<DispatchSettingsScreen> {
  final ApiService _apiService = ApiService();

  /// 기관에 등록된 어르신 (배차에 태울 후보)
  List<_ElderOption> _elders = [];
  bool _loadingElders = false;

  /// 목록을 아래로 밀면 '노선 추가' 단추의 글자를 접는다(B안 FAB)
  bool _fabCollapsed = false;

  /// dispose에서는 context로 provider를 찾을 수 없다(위젯이 이미 트리에서 빠진 뒤다).
  /// 화면을 떠날 때 남은 변경분을 저장해야 하므로 미리 붙잡아 둔다.
  DispatchProvider? _dispatchProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferenceData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dispatchProvider = context.read<DispatchProvider>();
  }

  Future<void> _loadReferenceData() async {
    final companyId = context.read<AuthProvider>().currentUser?.company?.id;
    if (companyId == null || companyId.isEmpty) return;

    // 운전자로 고를 직원 목록
    context.read<AdminProvider>().loadCompanyMembers(companyId);

    setState(() => _loadingElders = true);
    try {
      final response = await _apiService.getCompanyElders(companyId: companyId);
      final raw = response['elders'] ?? response['data'] ?? response['content'];
      if (raw is List) {
        _elders = raw
            .whereType<Map>()
            .map((e) => _ElderOption.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.name.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[배차설정] 어르신 목록 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingElders = false);
    }
  }

  @override
  void dispose() {
    // 화면을 떠날 때 모아둔 변경분이 남아 있으면 마저 저장한다
    _dispatchProvider?.flushSave();
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// 회원관리에 등록됐지만 어느 노선에도 배정되지 않은 어르신
  List<_ElderOption> _unassignedElders(DispatchProvider provider) {
    final assignedElderlyIds = provider.seniors
        .map((s) => s.elderlyId)
        .whereType<int>()
        .toSet();
    return _elders.where((e) => e.id != null && !assignedElderlyIds.contains(e.id)).toList();
  }

  Future<void> _copyRoutes(DispatchProvider provider, String sourceType) async {
    final targetType = sourceType == RouteType.toWork ? RouteType.toHome : RouteType.toWork;
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '$targetType 노선으로 복사',
      message:
          '$sourceType 노선 중 아직 $targetType에 같은 이름의 노선이 없는 것만 운전자·어르신을 그대로 복사합니다.',
      confirmText: '복사',
      cancelText: '취소',
    );
    if (confirmed != true) return;

    final result = provider.copyRoutesToOtherType(sourceType);
    if (!mounted) return;
    if (result.routeCount == 0) {
      AppSnackBar.showInfo(context, message: '복사할 $sourceType 노선이 없습니다 (이미 $targetType에 같은 이름이 있습니다)');
      return;
    }
    AppSnackBar.showSuccess(
      context,
      message: '$targetType 노선 ${result.routeCount}개, 어르신 ${result.seniorCount}명 복사',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(
        title: Text(
          '배차 설정',
          style: AppTypography.appBarTitle,
        ),
        elevation: 0,
        actions: [
          if (provider.isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppSemanticColors.headerForeground,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _copyRoutes(provider, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: RouteType.toWork,
                child: Text('등원 노선을 하원으로 복사'),
              ),
              PopupMenuItem(
                value: RouteType.toHome,
                child: Text('하원 노선을 등원으로 복사'),
              ),
            ],
          ),
        ],
      ),
      // B안 알약 FAB
      floatingActionButton: AppFab(
        icon: Icons.add,
        label: '노선 추가',
        collapsed: _fabCollapsed,
        onPressed: _openRouteEditor,
      ),
      body: provider.routes.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                if (_unassignedElders(provider).isNotEmpty)
                  // B안 안내 상자(옅은 노랑·모서리 14·테두리 없음)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.space4,
                      AppSpacing.screenGutter,
                      0,
                    ),
                    child: SeedCallout(
                      variant: SeedCalloutVariant.warning,
                      icon: Icons.info_outline,
                      title:
                          '미배정 어르신 ${_unassignedElders(provider).length}명 · ${_unassignedElders(provider).map((e) => e.name).join(', ')}',
                    ),
                  ),
                Expanded(
                  // 아래로 밀면 FAB 글자를 접고, 위로 올리면 다시 편다
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      final collapse = switch (notification.direction) {
                        ScrollDirection.reverse => true,
                        ScrollDirection.forward => false,
                        ScrollDirection.idle => _fabCollapsed,
                      };
                      if (collapse != _fabCollapsed) {
                        setState(() => _fabCollapsed = collapse);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      // 떠 있는 '노선 추가' 버튼이 마지막 카드의 '어르신 추가'를 가리지 않게 —
                      // 48로는 버튼 높이보다 작았다. 휴무 달력과 같은 96.
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        AppSpacing.space4,
                        AppSpacing.screenGutter,
                        96,
                      ),
                      itemCount: provider.routes.length,
                      itemBuilder: (context, index) =>
                          _buildRouteCard(provider, provider.routes[index]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    // B안 빈 화면 — 옅은 틸 원 아이콘 + 19 제목 + 14 설명
    return const AppEmptyState(
      icon: Icons.directions_bus_outlined,
      title: '등록된 노선이 없습니다',
      description: '아래 버튼으로 첫 노선을 추가해주세요',
    );
  }

  Widget _buildRouteCard(DispatchProvider provider, DispatchRoute route) {
    final seniors = provider.seniorsOfRoute(route.id);

    // B안 카드 — 테두리 없는 흰 상자, 모서리 20, 안쪽 20, 카드끼리 간격 12
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.space3,
        AppSpacing.space2,
        AppSpacing.cardPadding,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 카드 제목 줄(B안 16/w600)
                  style: AppTypography.titleMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
              // 이름에 이미 '(등원)'처럼 들어 있으면 같은 말을 꼬리표로 또 달지 않는다
              if (!route.name.contains(route.type)) _typeChip(route.type),
              IconButton(
                onPressed: () => _openRouteEditor(route: route),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppSemanticColors.textTertiary,
                tooltip: '노선 수정',
              ),
              IconButton(
                onPressed: () => _confirmDeleteRoute(provider, route),
                // 카드마다 빨간 휴지통이 화면에서 가장 셌다 — 수정 연필과 같은 회색, 누르면 확인 창
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppSemanticColors.textTertiary,
                tooltip: '노선 삭제',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),

          _sectionLabel('운전자 ${route.routeDrivers.length}명'),
          if (route.routeDrivers.isEmpty)
            _hint('운전자를 배정해주세요')
          else
            ...route.routeDrivers.asMap().entries.map(
              (entry) => _driverRow(provider, route, entry.key, entry.value),
            ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space1,
              right: AppSpacing.space3,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SeedButton(
                label: '부운전자 추가',
                onPressed: () => _addDriver(provider, route),
                variant: SeedButtonVariant.brandWeak,
                size: SeedButtonSize.small,
                prefixIcon: Icons.person_add_alt_1_outlined,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.space3),
          _sectionLabel('탑승 어르신 ${seniors.length}명'),
          if (seniors.isEmpty)
            _hint('아직 배정된 어르신이 없습니다')
          else
            ...seniors.asMap().entries.map(
              (entry) => _seniorRow(provider, route, entry.key, entry.value, seniors.length),
            ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space1,
              right: AppSpacing.space3,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SeedButton(
                label: '어르신 추가',
                onPressed: () => _addSenior(provider, route),
                variant: SeedButtonVariant.brandWeak,
                size: SeedButtonSize.small,
                prefixIcon: Icons.group_add_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // B안 꼬리표 — 테두리 없는 옅은 알약(12/w600)
  Widget _typeChip(String type) => AppTag(label: type);

  // 카드 안 소제목(B안 14/w600)
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.space2,
        bottom: AppSpacing.space1,
      ),
      child: Text(
        text,
        style: AppTypography.titleSmall.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textTertiary,
        ),
      ),
    );
  }

  Widget _driverRow(
    DispatchProvider provider,
    DispatchRoute route,
    int index,
    RouteDriver driver,
  ) {
    final roleLabel = index == 0 ? '주' : '부$index';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space0_5),
      child: Row(
        children: [
          // 역할 꼬리표 — 예전엔 28×24로 높이를 못 박아 글자를 키우면 잘렸다.
          // 높이는 꼬리표가 정하고(최소 26), 칸 폭만 글자 배율을 따라 맞춰 이름 시작점을 줄마다 같게 둔다.
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(36),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppTag(
                label: roleLabel,
                tone: index == 0 ? AppTagTone.accent : AppTagTone.neutral,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: InkWell(
              onTap: () => _pickDriver(provider, route, index),
              borderRadius: BorderRadius.circular(AppBorderRadius.control),
              child: ConstrainedBox(
                // 이름을 눌러 운전자를 고른다 — 누를 자리 48
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTouchTarget,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                  driver.driverName.isEmpty ? '직원 선택' : driver.driverName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: driver.driverName.isEmpty
                        ? AppSemanticColors.textTertiary
                        : AppSemanticColors.textPrimary,
                  ),
                ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              driver.vehicleName.isEmpty ? '차량 미지정' : driver.vehicleName,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _editVehicle(provider, route, index),
            icon: const Icon(Icons.directions_bus_outlined, size: 18),
            color: AppSemanticColors.textTertiary,
            tooltip: '차량명 입력',
            visualDensity: VisualDensity.compact,
          ),
          if (route.routeDrivers.length > 1)
            IconButton(
              onPressed: () => _removeDriver(provider, route, index),
              icon: const Icon(Icons.close, size: 18),
              color: AppSemanticColors.textTertiary,
              tooltip: '운전자 삭제',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _seniorRow(
    DispatchProvider provider,
    DispatchRoute route,
    int index,
    Senior senior,
    int total,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space0_5),
      child: Row(
        children: [
          SizedBox(
            // 탑승 순서 칸도 글자 배율을 따라 넓힌다(두 자리 순서가 접히지 않게)
            width: MediaQuery.textScalerOf(context).scale(28),
            child: Text(
              '${senior.boardingOrder}',
              maxLines: 1,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              senior.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: index == 0
                ? null
                : () => provider.moveSenior(route.id, index, index - 1),
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            color: AppSemanticColors.textTertiary,
            tooltip: '앞으로',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: index == total - 1
                ? null
                : () => provider.moveSenior(route.id, index, index + 1),
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            color: AppSemanticColors.textTertiary,
            tooltip: '뒤로',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => provider.deleteSenior(senior.id),
            icon: const Icon(Icons.close, size: 18),
            color: AppSemanticColors.textTertiary,
            tooltip: '어르신 삭제',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ================== 동작 ==================

  Future<void> _openRouteEditor({DispatchRoute? route}) async {
    final provider = context.read<DispatchProvider>();
    final nameController = TextEditingController(text: route?.name ?? '');
    var type = route?.type ?? RouteType.toWork;

    // B안: 가운데 창 대신 아래에서 올라오는 시트(손잡이·제목 21·큰 단추 취소 1 : 저장 1.7)
    final saved = await showAppSheet<bool>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocalState) => AppSheetFrame(
          title: route == null ? '노선 추가' : '노선 수정',
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.large,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
            confirm: SeedButton(
              label: '저장',
              size: SeedButtonSize.large,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
          children: [
            const SizedBox(height: AppSpacing.space5),
            SeedTextField(
              label: '노선 이름',
              placeholder: '예: A코스, 스타리아',
              controller: nameController,
            ),
            const SizedBox(height: AppSpacing.space4),
            // 등원/하원 하나만 고른다 — B안 칩(고르면 틸 + 흰 글자, selection 햅틱)
            Wrap(
              spacing: AppSpacing.space2,
              children: [
                for (final option in const [RouteType.toWork, RouteType.toHome])
                  SeedChip(
                    label: option == RouteType.toWork ? '등원' : '하원',
                    selected: type == option,
                    onTap: () => setLocalState(() => type = option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(context, message: '노선 이름을 입력해주세요');
      }
      return;
    }

    if (route == null) {
      // 웹(handleAddRoute)과 같은 규칙: 노선을 만들려면 운전자가 최소 1명 있어야 한다.
      // 여기서 주운전자를 바로 고르게 해서, 아무도 안 고른 빈 노선이 만들어지는
      // 걸 막는다.
      final driver = await _pickNewRouteMainDriver(provider, type);
      if (driver == null) return;

      provider.addRoute(
        DispatchRoute(
          id: _newId(),
          name: name,
          type: type,
          routeDrivers: [
            RouteDriver(driverId: driver.id, driverName: driver.name),
          ],
        ),
      );
    } else {
      provider.updateRoute(route.id, (r) => r.copyWith(name: name, type: type));
    }
  }

  /// 새 노선의 주운전자를 고른다. 취소하거나 아무도 안 고르면 null을 돌려주고,
  /// 웹 handleAddRoute와 같은 문구("최소 1명의 운전자를 입력해주세요.")로 안내한다.
  Future<User?> _pickNewRouteMainDriver(
    DispatchProvider provider,
    String routeType,
  ) async {
    final members = context.read<AdminProvider>().companyMembers;
    if (members.isEmpty) {
      if (mounted) {
        AppSnackBar.showInfo(context, message: '직원 목록을 불러오는 중입니다');
      }
      return null;
    }

    final picked = await AppBottomSheet.show<User>(
      context,
      title: '주운전자 선택',
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            // 시트 여백 8 + 줄 안쪽 12 = 제목과 같은 20에서 이름이 시작한다(B안 목록 줄)
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space2,
              0,
              AppSpacing.space2,
              AppSpacing.space4,
            ),
            children: [
              ...members.map(
                (member) => SeedListCell(
                  title: member.name,
                  description: member.email.isEmpty ? null : member.email,
                  showChevron: false,
                  onTap: () => Navigator.of(sheetContext).pop(member),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) {
      if (mounted) {
        AppSnackBar.showError(context, message: '최소 1명의 운전자를 입력해주세요.');
      }
      return null;
    }

    // 주운전자는 같은 방향(등원/하원)의 두 노선을 동시에 몰 수 없다 (부운전자 배정과 같은 규칙).
    final conflict = provider.primaryDriverConflict(picked.name, routeType: routeType);
    if (conflict != null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message:
              '${picked.name} 선생님은 이미 ${conflict.name}(${conflict.type}) 주운전자입니다. 같은 방향의 두 노선을 동시에 맡을 수 없습니다.',
        );
      }
      return null;
    }

    return picked;
  }

  Future<void> _confirmDeleteRoute(
    DispatchProvider provider,
    DispatchRoute route,
  ) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '노선 삭제',
      message: '"${route.name}" 노선을 삭제할까요?\n배정된 어르신도 함께 지워집니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );
    if (confirmed != true) return;

    provider.deleteRoute(route.id);
    if (mounted) {
      AppSnackBar.showSuccess(context, message: '노선을 삭제했습니다');
    }
  }

  void _addDriver(DispatchProvider provider, DispatchRoute route) {
    provider.updateRoute(
      route.id,
      (r) => r.copyWith(routeDrivers: [...r.routeDrivers, const RouteDriver()]),
    );
  }

  void _removeDriver(
    DispatchProvider provider,
    DispatchRoute route,
    int index,
  ) {
    final drivers = [...route.routeDrivers]..removeAt(index);
    provider.updateRoute(route.id, (r) => r.copyWith(routeDrivers: drivers));
  }

  Future<void> _pickDriver(
    DispatchProvider provider,
    DispatchRoute route,
    int index,
  ) async {
    final members = context.read<AdminProvider>().companyMembers;
    if (members.isEmpty) {
      AppSnackBar.showInfo(context, message: '직원 목록을 불러오는 중입니다');
      return;
    }

    final picked = await AppBottomSheet.show<User>(
      context,
      title: index == 0 ? '주운전자 선택' : '부$index운전자 선택',
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            // 시트 여백 8 + 줄 안쪽 12 = 제목과 같은 20에서 이름이 시작한다(B안 목록 줄)
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space2,
              0,
              AppSpacing.space2,
              AppSpacing.space4,
            ),
            children: [
              ...members.map(
                (member) => SeedListCell(
                  title: member.name,
                  description: member.email.isEmpty ? null : member.email,
                  showChevron: false,
                  onTap: () => Navigator.of(sheetContext).pop(member),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;

    // 같은 노선 안에서 같은 사람이 두 자리를 차지하면 대체가 성립하지 않는다
    final duplicatedHere = route.routeDrivers.asMap().entries.any(
      (e) => e.key != index && e.value.driverName.trim() == picked.name.trim(),
    );
    if (duplicatedHere) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: '${picked.name} 선생님은 이 노선에 이미 지정돼 있습니다',
        );
      }
      return;
    }

    // 주운전자는 같은 방향(등원/하원)의 두 노선을 동시에 몰 수 없다. 부운전자는 여러 코스를 맡는 것이 정상이라 막지 않는다.
    if (index == 0) {
      final conflict = provider.primaryDriverConflict(
        picked.name,
        exceptRouteId: route.id,
        routeType: route.type,
      );
      if (conflict != null) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message:
                '${picked.name} 선생님은 이미 ${conflict.name}(${conflict.type}) 주운전자입니다. 같은 방향의 두 노선을 동시에 맡을 수 없습니다.',
          );
        }
        return;
      }
    }

    final drivers = [...route.routeDrivers];
    drivers[index] = drivers[index].copyWith(
      driverId: picked.id,
      driverName: picked.name,
    );
    provider.updateRoute(route.id, (r) => r.copyWith(routeDrivers: drivers));
  }

  Future<void> _editVehicle(
    DispatchProvider provider,
    DispatchRoute route,
    int index,
  ) async {
    final controller = TextEditingController(
      text: route.routeDrivers[index].vehicleName,
    );

    // B안: 가운데 창 대신 아래에서 올라오는 시트
    final saved = await showAppSheet<bool>(
      context,
      builder: (sheetContext) => AppSheetFrame(
        title: '차량명',
        actions: AppSheetActions(
          cancel: SeedButton(
            label: '취소',
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.large,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
          confirm: SeedButton(
            label: '저장',
            size: SeedButtonSize.large,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
        children: [
          const SizedBox(height: AppSpacing.space4),
          SeedTextField(
            label: '차량명',
            showLabel: false,
            placeholder: '예: 스타리아, 카니발',
            controller: controller,
          ),
        ],
      ),
    );

    if (saved != true) return;

    final drivers = [...route.routeDrivers];
    drivers[index] = drivers[index].copyWith(
      vehicleName: controller.text.trim(),
    );
    provider.updateRoute(route.id, (r) => r.copyWith(routeDrivers: drivers));
  }

  Future<void> _addSenior(
    DispatchProvider provider,
    DispatchRoute route,
  ) async {
    if (_loadingElders) {
      AppSnackBar.showInfo(context, message: '어르신 목록을 불러오는 중입니다');
      return;
    }

    // 이미 이 노선에 탄 분은 후보에서 뺀다 — 이름이 아니라 elderlyId로 판정한다.
    // 이름으로 비교하면 동명이인 어르신을 같은 노선에 못 태운다(관리자 웹의
    // assignedElderlyIds와 같은 기준).
    final assignedElderlyIds = provider
        .seniorsOfRoute(route.id)
        .where((s) => s.elderlyId != null)
        .map((s) => s.elderlyId)
        .toSet();
    final candidates = _elders
        .where((e) => e.id == null || !assignedElderlyIds.contains(e.id))
        .toList();

    final picked = await AppBottomSheet.show<_ElderOption>(
      context,
      title: '어르신 선택',
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.space6),
                  child: Text(
                    _elders.isEmpty
                        ? '등록된 어르신이 없습니다.\n회원관리 > 수급자 관리에서 먼저 등록해주세요.'
                        : '이 노선에 더 추가할 어르신이 없습니다.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space2,
                    0,
                    AppSpacing.space2,
                    AppSpacing.space4,
                  ),
                  children: [
                    ...candidates.map(
                      (elder) => SeedListCell(
                        title: elder.name,
                        description: elder.address.isEmpty ? null : elder.address,
                        showChevron: false,
                        onTap: () => Navigator.of(sheetContext).pop(elder),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (picked == null) return;

    final nextOrder = provider.seniorsOfRoute(route.id).length + 1;
    provider.addSenior(
      Senior(
        id: _newId(),
        name: picked.name,
        routeId: route.id,
        boardingOrder: nextOrder,
        elderlyId: picked.id,
      ),
    );
  }
}

/// 배차에 태울 어르신 후보 (회원관리의 Elderly)
class _ElderOption {
  final int? id;
  final String name;
  final String address;

  const _ElderOption({this.id, required this.name, this.address = ''});

  factory _ElderOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return _ElderOption(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      address: json['homeAddress']?.toString() ?? json['address']?.toString() ?? '',
    );
  }
}
