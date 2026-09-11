import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/elder_care_profile.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';
import 'elder_care_detail_screen.dart';

/// 어르신 정보 — 등급·식사·투약·자리 같은 케어 기준을 현장에서 바로 찾아본다.
/// 이름 검색 + 층 필터(전체/1층/2층)로 좁힌다.
class ElderCareListScreen extends StatefulWidget {
  const ElderCareListScreen({super.key});

  @override
  State<ElderCareListScreen> createState() => _ElderCareListScreenState();
}

class _ElderCareListScreenState extends State<ElderCareListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ElderInfo> _elders = [];
  bool _isLoading = true;
  String? _error;
  String _keyword = '';
  int? _floorFilter; // null = 전체

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId =
        context.read<AuthProvider>().currentUser?.company?.id.toString() ?? '';
    if (companyId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '소속 기관 정보를 확인할 수 없습니다.';
      });
      return;
    }

    try {
      final elders = await ApiService().getCompanyEldersWithCare(
        companyId: companyId,
      );
      if (!mounted) return;
      setState(() {
        _elders = elders;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '어르신 정보를 불러오지 못했습니다.';
      });
    }
  }

  /// 목록에 실제로 존재하는 층만 칩으로 낸다 — 2층이 없는 기관에 2층 칩을 보일 이유가 없다.
  List<int> get _floors {
    final set = <int>{};
    for (final elder in _elders) {
      final floor = elder.careProfile?.floor;
      if (floor != null) set.add(floor);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<ElderInfo> get _filtered {
    return _elders.where((elder) {
      if (_keyword.isNotEmpty && !elder.name.contains(_keyword)) return false;
      if (_floorFilter != null && elder.careProfile?.floor != _floorFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openDetail(ElderInfo elder) async {
    final updated = await Navigator.of(context).push<ElderCareProfile>(
      MaterialPageRoute(builder: (_) => ElderCareDetailScreen(elder: elder)),
    );
    if (!mounted) return;
    if (updated != null) {
      // 수정하고 돌아왔으면 목록도 새 값으로 맞춘다(재요청 없이 그 자리만 교체).
      setState(() {
        _elders = _elders
            .map((e) => e.id == elder.id ? e.copyWith(careProfile: updated) : e)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('어르신 정보', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: AppLoading())
                  : _error != null
                  ? _message(_error!, retry: true)
                  : items.isEmpty
                  ? _message(
                      _elders.isEmpty
                          ? '등록된 어르신이 없습니다.\n기관 관리에서 어르신을 먼저 등록해 주세요.'
                          : '조건에 맞는 어르신이 없습니다.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.space4,
                        AppSpacing.space2,
                        AppSpacing.space4,
                        AppSpacing.space8,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.space2),
                      itemBuilder: (context, index) =>
                          _ElderRow(elder: items[index], onTap: _openDetail),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final floors = _floors;

    return Container(
      color: AppSemanticColors.backgroundPrimary,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        AppSpacing.space3,
      ),
      child: Column(
        children: [
          SeedTextField(
            // 라벨은 앱바 제목이 이미 맥락을 주므로 화면에는 감추고 접근성용으로만 남긴다.
            label: '어르신 이름 검색',
            showLabel: false,
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v.trim()),
            placeholder: '이름으로 찾기',
            prefixIcon: Icons.search,
            suffixIcon: _keyword.isNotEmpty ? Icons.clear : null,
            onSuffixIconTap: _keyword.isNotEmpty
                ? () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  }
                : null,
          ),
          if (floors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: [
                SeedChip(
                  label: '전체',
                  selected: _floorFilter == null,
                  onTap: () => setState(() => _floorFilter = null),
                ),
                for (final floor in floors) ...[
                  const SizedBox(width: AppSpacing.space2),
                  SeedChip(
                    label: '$floor층',
                    selected: _floorFilter == floor,
                    onTap: () => setState(() => _floorFilter = floor),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) {
    // RefreshIndicator가 동작하려면 스크롤 가능한 자식이 필요하다
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.space20 + AppSpacing.space10,
          ),
          child: Center(
            child: Column(
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
                if (retry) ...[
                  const SizedBox(height: AppSpacing.space4),
                  SeedButton(
                    label: '다시 시도',
                    variant: SeedButtonVariant.neutralWeak,
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 목록 한 줄 — 이름·나이/성별·등급·자리 + 낙상/욕창/기저귀/투약 태그
class _ElderRow extends StatelessWidget {
  final ElderInfo elder;
  final ValueChanged<ElderInfo> onTap;

  const _ElderRow({required this.elder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profile = elder.careProfile;
    final subtitleParts = <String>[
      if (profile != null && profile.ageGenderSummary.isNotEmpty)
        profile.ageGenderSummary,
      if (profile != null) profile.careGradeLabel,
    ];

    return Material(
      color: AppSemanticColors.surfaceDefault,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        onTap: () => onTap(elder),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: AppSemanticColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          elder.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        if (profile != null) ...[
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            profile.seatSummary,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space0_5),
                    Text(
                      profile == null ? '케어 정보 미등록' : subtitleParts.join(' · '),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                    if (profile != null && profile.riskTags.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Wrap(
                        spacing: AppSpacing.space1,
                        runSpacing: AppSpacing.space1,
                        children: [
                          for (final tag in profile.riskTags) _Tag(label: tag),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                // 공용 SeedListCell의 chevron과 같은 크기
                size: 18,
                color: AppSemanticColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 작은 상태 태그. 낙상·욕창은 주의 색, 나머지는 중립 색으로 구분한다.
class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final isAlert = label == '낙상' || label == '욕창';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: isAlert
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: isAlert
              ? AppSemanticColors.statusWarningText
              : AppSemanticColors.textSecondary,
        ),
      ),
    );
  }
}
