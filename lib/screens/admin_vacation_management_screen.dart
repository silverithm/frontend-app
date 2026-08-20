import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/role_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart' show AppStatusType;
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';

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
        setState(() {
          _vacationRequests = requestsList;
        });
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
        setState(() {
          _positions = positionsList
              .whereType<Map>()
              .map((position) => position['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        });
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

      if (limitsResult['success'] == true) {
        setState(() {
          _vacationLimits = limitsResult['data'] ?? {};
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '데이터 로드 실패: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVacationListWithFilters();
    }

    // 슬림 상단: 타이틀 1개만 (아이콘 배지·ADMIN 배지로 이중 강조하지 않는다).
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('휴무 관리', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: _isLoading
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // 필터 섹션
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: AppSemanticColors.surfaceDefault,
                border: Border(
                  bottom: BorderSide(
                    color: AppSemanticColors.borderSubtle,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 필터
                  Text(
                    '상태',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
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

                  // 직무 필터
                  Text(
                    '직무',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleFilterChip('전체', RoleUtils.allRole),
                        for (final role in _roleFilterOptions) ...[
                          const SizedBox(width: AppSpacing.space2),
                          _buildRoleFilterChip(
                            RoleUtils.displayName(role),
                            role,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // 정렬 옵션
                  Text(
                    '정렬',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortFilterChip('신청순', 'application'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildSortFilterChip('최신순', 'latest'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildSortFilterChip('오래된순', 'oldest'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildSortFilterChip('이름순', 'name'),
                        const SizedBox(width: AppSpacing.space2),
                        _buildSortFilterChip('직무순', 'role'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),

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

          // 일괄 처리 버튼 (승인 대기 상태일 때만 표시)
          if (_statusFilter == 'pending' && filteredRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space2,
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
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space2,
                            vertical: AppSpacing.space0_5,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedRequests.isNotEmpty
                                ? AppSemanticColors.interactiveSecondaryDefault
                                      .withValues(alpha: 0.1)
                                : AppSemanticColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.xl,
                            ),
                          ),
                          child: Text(
                            '${_selectedRequests.length}/${filteredRequests.length}',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _selectedRequests.isNotEmpty
                                  ? AppSemanticColors.textPrimary
                                  : AppSemanticColors.textSecondary,
                            ),
                          ),
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
                              variant: SeedButtonVariant.neutralOutline,
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
                    ],
                    const SizedBox(height: AppSpacing.space2),
                    const Divider(),
                  ],
                ),
              ),
            ),

          // 휴무 목록
          if (filteredRequests.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 64,
                      color: AppSemanticColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      '휴무 요청이 없습니다',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space2,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final request = filteredRequests[index];
                  return _buildVacationCardWithCheckbox(request);
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

    // 정적 리스트 카드 — 그림자 대신 보더만 (Seed 레이아웃 원칙)
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppSemanticColors.brandWeak
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: isSelected
              ? AppSemanticColors.brandDefault
              : AppSemanticColors.borderSubtle,
          width: isSelected ? 1.5 : 1,
        ),
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
        onLongPress: isPending
            ? () {
                setState(() {
                  _selectedRequests.add(requestId);
                  _isSelectMode = true;
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space3),
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
    );
  }

  Widget _buildVacationCardHeader(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    Color statusBackground;
    if (isApproved) {
      statusColor = AppSemanticColors.statusSuccessText;
      statusBackground = AppSemanticColors.statusSuccessBackground;
      statusIcon = Icons.check_circle;
      statusText = '승인됨';
    } else if (isPending) {
      statusColor = AppSemanticColors.statusWarningText;
      statusBackground = AppSemanticColors.statusWarningBackground;
      statusIcon = Icons.pending;
      statusText = '대기중';
    } else {
      statusColor = AppSemanticColors.statusErrorText;
      statusBackground = AppSemanticColors.statusErrorBackground;
      statusIcon = Icons.cancel;
      statusText = '거절됨';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: statusBackground,
          child: Icon(statusIcon, color: statusColor, size: 20),
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
                      style: AppTypography.heading6,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Text(
                      statusText,
                      style: AppTypography.labelMedium.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space1),
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
                style: AppTypography.labelSmall.copyWith(
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
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.message, size: 16, color: AppSemanticColors.textSecondary),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Text(
              reason,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 휴무 신청 상세 — 카드에서 줄여 보여주던 사유 전문과 신청 정보를 한 시트로.
  void _showVacationDetail(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isPending = status == 'pending';
    final bool isApproved = status == 'approved';
    final Color statusColor = isApproved
        ? AppSemanticColors.statusSuccessText
        : isPending
            ? AppSemanticColors.statusWarningText
            : AppSemanticColors.statusErrorText;
    final Color statusBackground = isApproved
        ? AppSemanticColors.statusSuccessBackground
        : isPending
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.statusErrorBackground;
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space1,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: Text(
                        statusText,
                        style: AppTypography.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                    style: AppTypography.labelMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                          variant: SeedButtonVariant.neutralOutline,
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
            width: 64,
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
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
    return Row(
      children: [
        // 삭제 버튼 (모든 상태에 대해 표시)
        Expanded(
          child: SeedButton(
            label: '삭제',
            variant: SeedButtonVariant.critical,
            size: SeedButtonSize.small,
            prefixIcon: Icons.delete,
            onPressed: () => _showDeleteDialog(request['id'].toString()),
          ),
        ),
        if (isPending) ...[
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: SeedButton(
              label: _rejectingRequests.contains(request['id'].toString())
                  ? '처리중...'
                  : '거절',
              variant: SeedButtonVariant.neutralOutline,
              size: SeedButtonSize.small,
              isLoading: _rejectingRequests.contains(request['id'].toString()),
              prefixIcon: Icons.close,
              onPressed:
                  _rejectingRequests.contains(request['id'].toString()) ||
                      _approvingRequests.contains(request['id'].toString())
                  ? null
                  : () => _rejectRequest(request['id'].toString()),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: SeedButton(
              label: _approvingRequests.contains(request['id'].toString())
                  ? '처리중...'
                  : '승인',
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.small,
              isLoading: _approvingRequests.contains(request['id'].toString()),
              prefixIcon: Icons.check,
              onPressed:
                  _approvingRequests.contains(request['id'].toString()) ||
                      _rejectingRequests.contains(request['id'].toString())
                  ? null
                  : () => _approveRequest(request['id'].toString()),
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

    setState(() {
      _isBulkProcessing = true;
    });

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
    );

    if (confirmed != true) return;

    setState(() {
      _isBulkProcessing = true;
    });

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
