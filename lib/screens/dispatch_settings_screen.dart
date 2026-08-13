import 'package:flutter/material.dart';
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
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferenceData());
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
    context.read<DispatchProvider>().flushSave();
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
          '배차 설정',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
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
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRouteEditor,
        backgroundColor: AppSemanticColors.brandDefault,
        foregroundColor: AppSemanticColors.textInverse,
        icon: const Icon(Icons.add),
        label: const Text('노선 추가'),
      ),
      body: provider.routes.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space4,
                AppSpacing.space4,
                AppSpacing.space12,
              ),
              itemCount: provider.routes.length,
              itemBuilder: (context, index) =>
                  _buildRouteCard(provider, provider.routes[index]),
            ),
    );
  }

  Widget _buildEmpty() {
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
              '등록된 노선이 없습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '아래 버튼으로 첫 노선을 추가해주세요',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(DispatchProvider provider, DispatchRoute route) {
    final seniors = provider.seniorsOfRoute(route.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle),
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
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
              ),
              _typeChip(route.type),
              IconButton(
                onPressed: () => _openRouteEditor(route: route),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppSemanticColors.textTertiary,
                tooltip: '노선 수정',
              ),
              IconButton(
                onPressed: () => _confirmDeleteRoute(provider, route),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppSemanticColors.statusErrorIcon,
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addDriver(provider, route),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('부운전자 추가'),
              style: TextButton.styleFrom(
                foregroundColor: AppSemanticColors.textLink,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.space2),
          _sectionLabel('탑승 어르신 ${seniors.length}명'),
          if (seniors.isEmpty)
            _hint('아직 배정된 어르신이 없습니다')
          else
            ...seniors.asMap().entries.map(
              (entry) => _seniorRow(provider, route, entry.key, entry.value, seniors.length),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addSenior(provider, route),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('어르신 추가'),
              style: TextButton.styleFrom(
                foregroundColor: AppSemanticColors.textLink,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        type,
        style: AppTypography.bodySmall.copyWith(
          fontSize: 11,
          color: AppSemanticColors.textSecondary,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.space2,
        bottom: AppSpacing.space1,
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textTertiary,
          fontWeight: AppTypography.fontWeightMedium,
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textDisabled,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0
                  ? AppSemanticColors.brandWeak
                  : AppSemanticColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(AppBorderRadius.base),
            ),
            child: Text(
              roleLabel,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: index == 0
                    ? AppSemanticColors.brandDefault
                    : AppSemanticColors.textSecondary,
                fontWeight: AppTypography.fontWeightSemibold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: InkWell(
              onTap: () => _pickDriver(provider, route, index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                child: Text(
                  driver.driverName.isEmpty ? '직원 선택' : driver.driverName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: driver.driverName.isEmpty
                        ? AppSemanticColors.textDisabled
                        : AppSemanticColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${senior.boardingOrder}',
              style: AppTypography.bodySmall.copyWith(
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppSemanticColors.backgroundElevated,
          title: Text(
            route == null ? '노선 추가' : '노선 수정',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '노선 이름',
                  hintText: '예: A코스, 스타리아',
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: RouteType.toWork, label: Text('등원')),
                  ButtonSegment(value: RouteType.toHome, label: Text('하원')),
                ],
                selected: {type},
                onSelectionChanged: (selected) =>
                    setLocalState(() => type = selected.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('저장'),
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
      provider.addRoute(
        DispatchRoute(
          id: _newId(),
          name: name,
          type: type,
          // 새 노선은 주운전자 자리를 하나 비워둔 채 시작한다
          routeDrivers: const [RouteDriver()],
        ),
      );
    } else {
      provider.updateRoute(route.id, (r) => r.copyWith(name: name, type: type));
    }
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

    final picked = await showModalBottomSheet<User>(
      context: context,
      backgroundColor: AppSemanticColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Text(
                index == 0 ? '주운전자 선택' : '부$index운전자 선택',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
            ),
            ...members.map(
              (member) => ListTile(
                title: Text(member.name),
                subtitle: member.email.isEmpty ? null : Text(member.email),
                onTap: () => Navigator.of(sheetContext).pop(member),
              ),
            ),
          ],
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

    // 주운전자는 두 노선을 동시에 몰 수 없다. 부운전자는 여러 코스를 맡는 것이 정상이라 막지 않는다.
    if (index == 0) {
      final conflict = provider.primaryDriverConflict(
        picked.name,
        exceptRouteId: route.id,
      );
      if (conflict != null) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message:
                '${picked.name} 선생님은 이미 ${conflict.name}(${conflict.type}) 주운전자입니다',
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppSemanticColors.backgroundElevated,
        title: Text(
          '차량명',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 스타리아, 카니발'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('저장'),
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

    // 이미 이 노선에 탄 분은 후보에서 뺀다
    final assigned = provider
        .seniorsOfRoute(route.id)
        .map((s) => s.name)
        .toSet();
    final candidates = _elders
        .where((e) => !assigned.contains(e.name))
        .toList();

    final picked = await showModalBottomSheet<_ElderOption>(
      context: context,
      backgroundColor: AppSemanticColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: candidates.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.space6),
                child: Text(
                  _elders.isEmpty
                      ? '등록된 어르신이 없습니다.\n회원관리에서 먼저 등록해주세요.'
                      : '이 노선에 더 추가할 어르신이 없습니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.space4),
                    child: Text(
                      '어르신 선택',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: AppTypography.fontWeightSemibold,
                      ),
                    ),
                  ),
                  ...candidates.map(
                    (elder) => ListTile(
                      title: Text(elder.name),
                      subtitle: elder.address.isEmpty
                          ? null
                          : Text(
                              elder.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => Navigator.of(sheetContext).pop(elder),
                    ),
                  ),
                ],
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
