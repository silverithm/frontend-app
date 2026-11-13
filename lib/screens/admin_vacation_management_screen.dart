import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/role_utils.dart';
import '../utils/app_haptics.dart';
import '../theme/app_colors.dart';
import '../theme/app_lines.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart' show AppCard, AppStatusType;
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';
import '../widgets/common/app_tag.dart';

class AdminVacationManagementScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminVacationManagementScreen({super.key, this.showAppBar = true});

  @override
  State<AdminVacationManagementScreen> createState() =>
      _AdminVacationManagementScreenState();
}

class _AdminVacationManagementScreenState
    extends State<AdminVacationManagementScreen> {
  List<Map<String, dynamic>> _vacationRequests = [];
  List<String> _positions = [];
  Map<String, dynamic> _vacationLimits = {};
  bool _isLoading = false;
  String _statusFilter =
      'pending'; // all, pending, approved, rejected - 초기값을 승인 대기로 설정
  String _roleFilter = 'all'; // all, caregiver, office
  String _sortBy = 'application'; // application, latest, name, role
  String _searchQuery = ''; // 검색어
  final TextEditingController _searchController = TextEditingController();

  // 개별 요청의 처리 상태 추적 (승인과 거절을 구분)
  Set<String> _approvingRequests = {};
  Set<String> _rejectingRequests = {};

  // 체크박스 선택 관리
  Set<String> _selectedRequests = {};
  bool _isSelectMode = false;
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

      // 휴무 요청 목록 로드
      print('[AdminVacationManagement] API 호출 시작 - companyId: $companyId');
      final vacationResult = await ApiService().getVacationRequests(
        companyId: companyId,
      );
      print('[AdminVacationManagement] API 응답 키들: ${vacationResult.keys}');
      print(
        '[AdminVacationManagement] containsKey requests: ${vacationResult.containsKey('requests')}',
      );

      if (vacationResult.containsKey('requests')) {
        final requestsList = List<Map<String, dynamic>>.from(
          vacationResult['requests'] ?? [],
        );
        print('[AdminVacationManagement] 로드된 휴무 요청 수: ${requestsList.length}');
        if (requestsList.isNotEmpty) {
          print('[AdminVacationManagement] 첫 번째 요청 샘플: ${requestsList.first}');
        }
        // 화면을 벗어난 뒤 응답이 오면 dispose된 State에 setState하게 되어 크래시한다
        if (mounted) {
          setState(() {
            _vacationRequests = requestsList;
          });
        }
        print(
          '[AdminVacationManagement] setState 완료, _vacationRequests.length: ${_vacationRequests.length}',
        );
      } else {
        print(
          '[AdminVacationManagement] API 응답에 requests 키가 없음: ${vacationResult.keys}',
        );
      }

      // 등록된 역할 목록 로드 (필터에 그대로 노출)
      try {
        final positionsResult = await ApiService().getPositions(
          companyId: companyId,
        );
        final positionsList = (positionsResult['positions'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _positions = positionsList
                .whereType<Map>()
                .map((position) => position['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList();
          });
        }
      } catch (e) {
        print('[AdminVacationManagement] 역할 목록 로드 실패: $e');
      }

      // 휴무 한도 로드
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);

      final limitsResult = await ApiService().getVacationLimits(
        start: start.toIso8601String().split('T')[0],
        end: end.toIso8601String().split('T')[0],
        companyId: companyId,
      );

      if (limitsResult['success'] == true && mounted) {
        setState(() {
          _vacationLimits = limitsResult['data'] ?? {};
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '데이터 로드 실패: $e');
      }
    } finally {
      // 로드 중 화면을 벗어나면(탭 전환 등) dispose 뒤 setState로 크래시한다
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildBody();
    }

    // 슬림 상단: 타이틀 1개만 (아이콘 배지·ADMIN 배지로 이중 강조하지 않는다).
    // B안: 옅은 회색 바탕 위 흰 카드(거르기 · 일괄 처리 · 신청 카드)
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(
        title: Text('휴무 관리', style: AppTypography.appBarTitle),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  /// 처음 불러올 때(아직 보일 신청이 없을 때)만 뼈대 — 신청이 있는 채로 다시 불러올 때는 예전 스피너.
  /// 카드 등장 연출은 처음 한 번만 — 다시 불러와도 다시 떠오르지 않게 바깥에 둔다.
  Widget _buildBody() {
    return AppListEntrance(
      child: _isLoading && _vacationRequests.isEmpty
          ? const _VacationManagementSkeleton()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVacationListWithFilters(),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return SeedChip(
      label: label,
      selected: isSelected,
      size: SeedChipSize.small,
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildRoleFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return SeedChip(
      label: label,
      selected: isSelected,
      size: SeedChipSize.small,
      onTap: () {
        setState(() {
          _roleFilter = value;
        });
      },
    );
  }

  Widget _buildSortFilterChip(String label, String value) {
    final isSelected = _sortBy == value;
    return SeedChip(
      label: label,
      selected: isSelected,
      size: SeedChipSize.small,
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
    );
  }

  Widget _buildVacationListWithFilters() {
    print('[AdminVacationManagement] _buildVacationListWithFilters 호출');
    print(
      '[AdminVacationManagement] _vacationRequests.length: ${_vacationRequests.length}',
    );
    print('[AdminVacationManagement] _statusFilter: $_statusFilter');

    final filteredRequests = _getFilteredRequests();
    print(
      '[AdminVacationManagement] filteredRequests.length: ${filteredRequests.length}',
    );

    return AppRefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // 필터 섹션 — 머리띠(연한 틸 면 + 선) 대신 흰 카드 한 장
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space3,
                AppSpacing.screenGutter,
                0,
              ),
              child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 필터
                  Text(
                    '상태',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilterChip('전체', 'all'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildStatusFilterChip('승인 대기', 'pending'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildStatusFilterChip('승인됨', 'approved'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildStatusFilterChip('거절됨', 'rejected'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // 직무·정렬은 자주 안 바꾸므로 한 줄 요약 버튼으로 접고, 누르면 시트에서 고른다 (D12)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterSummaryChip(
                          label: '직무 · ${_roleFilterLabel()}',
                          onTap: _openRoleFilterSheet,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        _buildFilterSummaryChip(
                          label: '정렬 · ${_sortLabel()}',
                          onTap: _openSortFilterSheet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2_5),

                  // 검색 필드
                  SeedTextField(
                    label: '검색',
                    // 섹션 자체가 이미 카드/필터 묶음 안에 있어 별도 라벨 없이 쓰던 필드
                    showLabel: false,
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    placeholder: '이름, 직무로 검색...',
                    prefixIcon: Icons.search,
                    suffixIcon: _searchQuery.isNotEmpty ? Icons.clear : null,
                    onSuffixIconTap: _searchQuery.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          }
                        : null,
                  ),
                ],
              ),
              ),
            ),
          ),

          // 일괄 처리 버튼 (승인 대기 상태일 때만 표시) — 흰 카드, 아래 구분선 없음
          if (_statusFilter == 'pending' && filteredRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.cardGap,
                  AppSpacing.screenGutter,
                  0,
                ),
                child: AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space2,
                  AppSpacing.space2,
                  AppSpacing.space4,
                  AppSpacing.space2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 전체 선택 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value:
                              _selectedRequests.length ==
                                  filteredRequests.length &&
                              filteredRequests.isNotEmpty,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                // 전체 선택
                                _selectedRequests = filteredRequests
                                    .map((r) => r['id'].toString())
                                    .toSet();
                              } else {
                                // 전체 해제
                                _selectedRequests.clear();
                              }
                              _isSelectMode = _selectedRequests.isNotEmpty;
                            });
                          },
                          activeColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                        Text(
                          '전체 선택',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        // 고른 건수 — 공통 꼬리표(고른 게 있으면 옅은 틸)
                        AppTag(
                          label:
                              '${_selectedRequests.length}/${filteredRequests.length}',
                          tone: _selectedRequests.isNotEmpty
                              ? AppTagTone.accent
                              : AppTagTone.neutral,
                        ),
                      ],
                    ),
                    // 일괄 처리 버튼들
                    if (_selectedRequests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space3),
                      Row(
                        children: [
                          Expanded(
                            child: SeedButton(
                              label: _isBulkProcessing ? '처리중...' : '선택 항목 거절',
                              variant: SeedButtonVariant.neutralWeak,
                              isLoading: _isBulkProcessing,
                              prefixIcon: Icons.close,
                              onPressed: _isBulkProcessing ? null : _bulkReject,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: SeedButton(
                              label: _isBulkProcessing ? '처리중...' : '선택 항목 승인',
                              variant: SeedButtonVariant.brandSolid,
                              isLoading: _isBulkProcessing,
                              prefixIcon: Icons.check,
                              onPressed: _isBulkProcessing
                                  ? null
                                  : _bulkApprove,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space2),
                    ],
                  ],
                ),
                ),
              ),
            ),

          // 휴무 목록
          if (filteredRequests.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              // 공통 빈 화면 — 옅은 틸 원 안 아이콘 + 제목(글자 그대로)
              child: AppEmptyState(
                icon: Icons.event_available,
                title: '휴무 요청이 없습니다',
                topSpacing: AppSpacing.space8,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.cardGap,
                AppSpacing.screenGutter,
                AppSpacing.space6,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final request = filteredRequests[index];
                  return AppListEntranceItem(
                    index: index,
                    child: _buildVacationCardWithCheckbox(request),
                  );
                }, childCount: filteredRequests.length),
              ),
            ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    return RoleUtils.displayName(role);
  }

  /// 등록된 역할 + 실제 신청에 나타난 역할로 필터 목록을 만든다
  static const Map<String, String> _sortLabels = {
    'application': '신청순',
    'latest': '최신순',
    'oldest': '오래된순',
    'name': '이름순',
    'role': '직무순',
  };

  String _sortLabel() => _sortLabels[_sortBy] ?? '신청순';

  String _roleFilterLabel() =>
      _roleFilter == RoleUtils.allRole ? '전체' : RoleUtils.displayName(_roleFilter);

  /// 접힌 필터 한 개 — "직무 · 전체 ▾" 같은 요약 칩. 누르면 시트가 열린다.
  Widget _buildFilterSummaryChip({required String label, required VoidCallback onTap}) {
    // 흰 카드 안 회색 알약(SeedChip 작은 것과 같은 높이 36·글자 14/w600)
    return Material(
      color: AppSemanticColors.fillDefault,
      borderRadius: BorderRadius.circular(AppBorderRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.space9),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.space0_5),
                Icon(Icons.expand_more, size: 18, color: AppSemanticColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFilterSheet(String title, List<Widget> Function() chips) {
    AppBottomSheet.show<void>(
      context,
      title: title,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: chips(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 시트 안에서 고르면 화면에 반영하고 시트를 닫는다
  Widget _sheetChip(String label, bool selected, VoidCallback onPick) {
    return SeedChip(
      label: label,
      selected: selected,
      size: SeedChipSize.small,
      onTap: () {
        onPick();
        Navigator.of(context).pop();
      },
    );
  }

  void _openRoleFilterSheet() {
    _openFilterSheet('직무', () => [
      _sheetChip('전체', _roleFilter == RoleUtils.allRole,
          () => setState(() => _roleFilter = RoleUtils.allRole)),
      for (final role in _roleFilterOptions)
        _sheetChip(RoleUtils.displayName(role), _roleFilter == role,
            () => setState(() => _roleFilter = role)),
    ]);
  }

  void _openSortFilterSheet() {
    _openFilterSheet('정렬', () => [
      for (final entry in _sortLabels.entries)
        _sheetChip(entry.value, _sortBy == entry.key,
            () => setState(() => _sortBy = entry.key)),
    ]);
  }

  List<String> get _roleFilterOptions {
    final roles = <String>[];
    final seen = <String>{};

    void addRole(String? value) {
      final normalizedRole = RoleUtils.normalize(value);
      if (normalizedRole.isEmpty ||
          normalizedRole == RoleUtils.allRole ||
          normalizedRole == 'admin' ||
          normalizedRole == 'employee' ||
          !seen.add(normalizedRole)) {
        return;
      }

      roles.add(normalizedRole);
    }

    for (final position in _positions) {
      addRole(position);
    }
    for (final request in _vacationRequests) {
      addRole(request['role']?.toString());
    }

    if (roles.isEmpty) {
      addRole('caregiver');
      addRole('office');
    }

    return roles;
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '알 수 없음';

    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '알 수 없음';
    }
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    var filteredRequests = _vacationRequests.toList();

    // 상태 필터링
    if (_statusFilter != 'all') {
      filteredRequests = filteredRequests
          .where((request) => request['status'] == _statusFilter)
          .toList();
    }

    // 직무 필터링
    if (_roleFilter != RoleUtils.allRole) {
      filteredRequests = filteredRequests
          .where(
            (request) =>
                RoleUtils.matches(request['role']?.toString(), _roleFilter),
          )
          .toList();
    }

    // 검색 필터링
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      filteredRequests = filteredRequests.where((request) {
        final userName = (request['userName'] ?? '').toLowerCase();
        final role = _getRoleDisplayName(request['role'] ?? '').toLowerCase();
        return userName.contains(searchLower) || role.contains(searchLower);
      }).toList();
    }

    // 정렬
    switch (_sortBy) {
      case 'name':
        filteredRequests.sort(
          (a, b) => (a['userName'] ?? '').compareTo(b['userName'] ?? ''),
        );
        break;
      case 'role':
        filteredRequests.sort(
          (a, b) => (a['role'] ?? '').compareTo(b['role'] ?? ''),
        );
        break;
      case 'application':
        // 신청순: 생성일(createdAt)이 늦은 순 (내림차순) - 최근 신청부터
        filteredRequests.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA); // 생성일 늦은 순 (최근 신청부터)
        });
        break;
      case 'latest':
        // 최신순: 휴무 사용일(date)이 늦은 순 (내림차순) - 가까운 휴무부터
        filteredRequests.sort((a, b) {
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA); // 휴무 사용일 늦은 순 (가까운 휴무부터)
        });
        break;
      case 'oldest':
        // 오래된순: 휴무 사용일(date)이 빠른 순 (오름차순) - 오래된 휴무부터
        filteredRequests.sort((a, b) {
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB); // 휴무 사용일 빠른 순 (오래된 휴무부터)
        });
        break;
      default:
        // 기본값은 신청순
        filteredRequests.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        break;
    }

    return filteredRequests;
  }

  Widget _buildVacationCardWithCheckbox(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isPending = status == 'pending';
    final requestId = request['id'].toString();
    final isSelected = _selectedRequests.contains(requestId);

    // B안 카드 — 흰 바탕, 테두리 없음, 모서리 16, 카드 사이 간격 10.
    // 일괄 선택으로 고른 카드만 옅은 틸 바탕 + 틸 2px 둘레(고름 표시).
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Material(
      color: isSelected
          ? AppSemanticColors.brandWeak
          : AppSemanticColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        side: isSelected
            ? const BorderSide(color: AppSemanticColors.brandDefault, width: 2)
            : AppLines.cardSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 기본 탭은 상세 시트를 연다. 일괄 선택은 길게 눌러 시작하고,
        // 선택 모드에서는 탭이 선택 토글이 된다 (대기 건만 선택 대상).
        onTap: () {
          if (_isSelectMode && isPending) {
            setState(() {
              if (_selectedRequests.contains(requestId)) {
                _selectedRequests.remove(requestId);
              } else {
                _selectedRequests.add(requestId);
              }
              _isSelectMode = _selectedRequests.isNotEmpty;
            });
            return;
          }
          _showVacationDetail(request);
        },
        // 길게 눌러 일괄 선택이 시작되는 순간 impact 진동 한 번 — InkWell 자체 길게 누르기 진동(Android)은
        // 꺼서 두 번 울리지 않게 하고, '진동 반응' 스위치를 따르는 AppHaptics로만 울린다
        enableFeedback: false,
        onLongPress: isPending
            ? () {
                AppHaptics.impact();
                setState(() {
                  _selectedRequests.add(requestId);
                  _isSelectMode = true;
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPending)
                    SizedBox(
                      width: AppSpacing.space6,
                      height: AppSpacing.space6,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedRequests.add(requestId);
                            } else {
                              _selectedRequests.remove(requestId);
                            }
                            _isSelectMode = _selectedRequests.isNotEmpty;
                          });
                        },
                        activeColor:
                            AppSemanticColors.interactivePrimaryDefault,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isPending) const SizedBox(width: AppSpacing.space3),
                  Expanded(child: _buildVacationCardHeader(request)),
                ],
              ),
              if (request['reason'] != null &&
                  request['reason'].toString().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                _buildReasonSection(request['reason']),
              ],
              if (!_isSelectMode) ...[
                const SizedBox(height: AppSpacing.space3),
                _buildActionButtons(request, isPending),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildVacationCardHeader(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';

    final AppTagTone statusTone = isApproved
        ? AppTagTone.success
        : isPending
            ? AppTagTone.warning
            : AppTagTone.error;
    final String statusText = isApproved
        ? '승인됨'
        : isPending
            ? '대기중'
            : '거절됨';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 종사자 관리 카드와 같은 옅은 틸 원 40 — 상태는 오른쪽 꼬리표 하나로만 말한다
        const CircleAvatar(
          radius: AppSpacing.iconCircle / 2,
          backgroundColor: AppSemanticColors.brandWeak,
          child: Icon(
            Icons.person,
            color: AppSemanticColors.brandDefault,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request['userName'] ?? '알 수 없음',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  AppTag(label: statusText, tone: statusTone),
                ],
              ),
              const SizedBox(height: AppSpacing.space0_5),
              Text(
                '${_getRoleDisplayName(request['role'] ?? '')} • 휴무일: ${request['date'] ?? ''}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: AppSpacing.space0_5),
              Text(
                '신청일: ${_formatDate(request['createdAt'])}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.fillDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Text(
        reason,
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
      ),
    );
  }

  /// 휴무 신청 상세 — 카드에서 줄여 보여주던 사유 전문과 신청 정보를 한 시트로.
  void _showVacationDetail(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isPending = status == 'pending';
    final bool isApproved = status == 'approved';
    // 상태 색의 뜻은 그대로: 승인=초록, 대기=노랑, 거절=빨강(카드의 꼬리표와 같다)
    final AppTagTone statusTone = isApproved
        ? AppTagTone.success
        : isPending
            ? AppTagTone.warning
            : AppTagTone.error;
    final String statusText = isApproved
        ? '승인됨'
        : isPending
            ? '대기중'
            : '거절됨';
    final String reason = (request['reason'] ?? '').toString();

    AppBottomSheet.show(
      context,
      // 내용이 길어질 수 있는 상세 시트 — 절반 높이 제약을 받지 않게 한다
      isScrollControlled: true,
      child: Builder(
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request['userName'] ?? '알 수 없음',
                        style: AppTypography.heading5.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    AppTag(label: statusText, tone: statusTone),
                  ],
                ),
                const SizedBox(height: AppSpacing.space4),
                _detailRow('역할', _getRoleDisplayName(request['role'] ?? '')),
                _detailRow('휴무일', (request['date'] ?? '').toString()),
                _detailRow('신청일', _formatDate(request['createdAt'])),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    '사유',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.fillDefault,
                        borderRadius: BorderRadius.circular(AppBorderRadius.control),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          reason,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: AppSpacing.space5),
                  Row(
                    children: [
                      Expanded(
                        child: SeedButton(
                          label: '거절',
                          size: SeedButtonSize.large,
                          variant: SeedButtonVariant.neutralWeak,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _rejectRequest(request['id'].toString());
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: SeedButton(
                          label: '승인',
                          size: SeedButtonSize.large,
                          variant: SeedButtonVariant.brandSolid,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _approveRequest(request['id'].toString());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> request, bool isPending) {
    final id = request['id'].toString();
    final isRejecting = _rejectingRequests.contains(id);
    final isApproving = _approvingRequests.contains(id);
    // 거절·승인 둘만 같은 크기로 나란히 두고, 파괴 행동인 삭제는 글자 단추로 낮춰 한쪽으로 뺀다
    return Row(
      children: [
        TextButton(
          onPressed: () => _showDeleteDialog(id),
          style: TextButton.styleFrom(
            foregroundColor: AppSemanticColors.statusErrorText,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space2,
            ),
            minimumSize: const Size(0, 36),
          ),
          child: Text('삭제', style: AppTypography.buttonSmall),
        ),
        if (isPending) ...[
          const Spacer(),
          SizedBox(
            width: 96,
            child: SeedButton(
              label: isRejecting ? '처리중...' : '거절',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.small,
              isLoading: isRejecting,
              onPressed: isRejecting || isApproving
                  ? null
                  : () => _rejectRequest(id),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          SizedBox(
            width: 96,
            child: SeedButton(
              label: isApproving ? '처리중...' : '승인',
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.small,
              isLoading: isApproving,
              onPressed: isApproving || isRejecting
                  ? null
                  : () => _approveRequest(id),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() {
      _approvingRequests.add(requestId);
    });

    try {
      print('[AdminVacation] 승인 요청 시작 - requestId: $requestId');
      final result = await ApiService().approveVacationRequest(
        vacationId: requestId,
      );
      print('[AdminVacation] 승인 API 응답: $result');

      // 성공 판단: success가 true이거나, message가 있고 에러가 없으면 성공으로 처리
      bool isSuccess =
          result['success'] == true ||
          (result['message'] != null && result['error'] == null) ||
          (result.isNotEmpty && result['error'] == null);

      if (isSuccess) {
        if (mounted) {
          AppSnackBar.showSuccess(context, message: '휴무 요청이 승인되었습니다');
          print('[AdminVacation] 승인 성공 - 데이터 새로고침 시작');

          // 휴무 승인 카운트 증가 (인앱 리뷰 트리거)
          await InAppReviewService().incrementVacationApprovalCount();

          await _loadData(); // 목록 새로고침
          print('[AdminVacation] 데이터 새로고침 완료');
        }
      } else {
        throw Exception(result['message'] ?? result['error'] ?? '승인 실패');
      }
    } catch (e) {
      print('[AdminVacation] 승인 중 오류: $e');
      if (mounted) {
        // Exception: 접두사 제거
        String errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        AppSnackBar.showError(context, message: '승인 실패: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() {
          _approvingRequests.remove(requestId);
        });
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    setState(() {
      _rejectingRequests.add(requestId);
    });

    try {
      print('[AdminVacation] 거절 요청 시작 - requestId: $requestId');
      final result = await ApiService().rejectVacationRequest(
        vacationId: requestId,
      );
      print('[AdminVacation] 거절 API 응답: $result');

      // 성공 판단: success가 true이거나, message가 있고 에러가 없으면 성공으로 처리
      bool isSuccess =
          result['success'] == true ||
          (result['message'] != null && result['error'] == null) ||
          (result.isNotEmpty && result['error'] == null);

      if (isSuccess) {
        if (mounted) {
          // 거절은 실패가 아니라 정상 처리 결과다 — 회원관리 화면과 같은 톤(warning)으로 통일
          AppSnackBar.showWarning(context, message: '휴무 요청이 거절되었습니다');
          print('[AdminVacation] 거절 성공 - 데이터 새로고침 시작');
          await _loadData(); // 목록 새로고침
          print('[AdminVacation] 데이터 새로고침 완료');
        }
      } else {
        throw Exception(result['message'] ?? result['error'] ?? '거절 실패');
      }
    } catch (e) {
      print('[AdminVacation] 거절 중 오류: $e');
      if (mounted) {
        // Exception: 접두사 제거
        String errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        AppSnackBar.showError(context, message: '거절 실패: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() {
          _rejectingRequests.remove(requestId);
        });
      }
    }
  }

  Future<void> _showDeleteDialog(String vacationId) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '휴무 삭제',
      message: '이 휴무를 영구적으로 삭제하시겠습니까?\n삭제된 휴무는 복구할 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed == true) {
      _deleteVacation(vacationId);
    }
  }

  Future<void> _deleteVacation(String vacationId) async {
    try {
      print('[AdminVacationManagement] 휴무 삭제 요청 시작 - vacationId: $vacationId');

      final result = await ApiService().deleteVacationByAdmin(
        vacationId: vacationId,
      );

      print('[AdminVacationManagement] 휴무 삭제 API 응답: $result');

      if (mounted) {
        AppSnackBar.showSuccess(context, message: '휴무가 성공적으로 삭제되었습니다');

        // 목록 새로고침
        await _loadData();
      }
    } catch (e) {
      print('[AdminVacationManagement] 휴무 삭제 실패: $e');

      if (mounted) {
        String errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');

        AppSnackBar.showError(context, message: '휴무 삭제 실패: $errorMessage');
      }
    }
  }

  Future<void> _bulkApprove() async {
    if (_selectedRequests.isEmpty) return;

    final selectedList = _selectedRequests.toList();

    // 확인 다이얼로그 표시
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '일괄 승인',
      message: '선택한 ${selectedList.length}개의 휴무 요청을 모두 승인하시겠습니까?',
      confirmText: '승인',
      cancelText: '취소',
    );

    if (confirmed != true) return;

    // 확인 대화상자가 떠 있는 동안 화면을 벗어났을 수 있다
    if (mounted) {
      setState(() {
        _isBulkProcessing = true;
      });
    }

    try {
      print('[AdminVacation] 일괄 승인 요청 시작 - ${selectedList.length}개');
      final result = await ApiService().bulkApproveVacations(
        vacationIds: selectedList,
      );
      print('[AdminVacation] 일괄 승인 API 응답: $result');

      final successCount = result['successCount'] ?? 0;
      final failureCount = result['failureCount'] ?? 0;

      if (mounted) {
        String message;
        AppStatusType type;

        if (failureCount == 0) {
          message = '$successCount개의 휴무가 승인되었습니다';
          type = AppStatusType.success;
        } else if (successCount == 0) {
          message = '일괄 승인에 실패했습니다';
          type = AppStatusType.error;
        } else {
          message = '$successCount개 승인 성공, $failureCount개 실패';
          type = AppStatusType.warning;
        }

        AppSnackBar.show(context, message: message, type: type);

        // 선택 초기화 및 목록 새로고침
        setState(() {
          _selectedRequests.clear();
          _isSelectMode = false;
        });
        await _loadData();
      }
    } catch (e) {
      print('[AdminVacation] 일괄 승인 중 오류: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '일괄 승인 실패: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkProcessing = false;
        });
      }
    }
  }

  Future<void> _bulkReject() async {
    if (_selectedRequests.isEmpty) return;

    final selectedList = _selectedRequests.toList();

    // 확인 다이얼로그 표시
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '일괄 거절',
      message: '선택한 ${selectedList.length}개의 휴무 요청을 모두 거절하시겠습니까?',
      confirmText: '거절',
      cancelText: '취소',
      haptic: AppHapticKind.warning,
    );

    if (confirmed != true) return;

    // 확인 대화상자가 떠 있는 동안 화면을 벗어났을 수 있다
    if (mounted) {
      setState(() {
        _isBulkProcessing = true;
      });
    }

    try {
      print('[AdminVacation] 일괄 거절 요청 시작 - ${selectedList.length}개');
      final result = await ApiService().bulkRejectVacations(
        vacationIds: selectedList,
      );
      print('[AdminVacation] 일괄 거절 API 응답: $result');

      final successCount = result['successCount'] ?? 0;
      final failureCount = result['failureCount'] ?? 0;

      if (mounted) {
        String message;
        AppStatusType type;

        if (failureCount == 0) {
          // 거절은 실패가 아니라 정상 처리 결과다 — warning 톤 유지(빨강 아님)
          message = '$successCount개의 휴무가 거절되었습니다';
          type = AppStatusType.warning;
        } else if (successCount == 0) {
          message = '일괄 거절에 실패했습니다';
          type = AppStatusType.error;
        } else {
          message = '$successCount개 거절 성공, $failureCount개 실패';
          type = AppStatusType.warning;
        }

        AppSnackBar.show(context, message: message, type: type);

        // 선택 초기화 및 목록 새로고침
        setState(() {
          _selectedRequests.clear();
          _isSelectMode = false;
        });
        await _loadData();
      }
    } catch (e) {
      print('[AdminVacation] 일괄 거절 중 오류: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '일괄 거절 실패: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkProcessing = false;
        });
      }
    }
  }
}

/// 휴무 관리 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드(거르기 카드 + 신청 카드, 같은 여백·간격)
class _VacationManagementSkeleton extends StatelessWidget {
  const _VacationManagementSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
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
