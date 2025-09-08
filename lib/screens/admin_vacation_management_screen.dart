import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'admin_vacation_limits_setting_screen.dart';

class AdminVacationManagementScreen extends StatefulWidget {
  const AdminVacationManagementScreen({super.key});

  @override
  State<AdminVacationManagementScreen> createState() => _AdminVacationManagementScreenState();
}

class _AdminVacationManagementScreenState extends State<AdminVacationManagementScreen> {
  List<Map<String, dynamic>> _vacationRequests = [];
  Map<String, dynamic> _vacationLimits = {};
  bool _isLoading = false;
  String _statusFilter = 'pending'; // all, pending, approved, rejected - 초기값을 승인 대기로 설정
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
      print('[AdminVacationManagement] containsKey requests: ${vacationResult.containsKey('requests')}');
      
      if (vacationResult.containsKey('requests')) {
        final requestsList = List<Map<String, dynamic>>.from(vacationResult['requests'] ?? []);
        print('[AdminVacationManagement] 로드된 휴무 요청 수: ${requestsList.length}');
        if (requestsList.isNotEmpty) {
          print('[AdminVacationManagement] 첫 번째 요청 샘플: ${requestsList.first}');
        }
        setState(() {
          _vacationRequests = requestsList;
        });
        print('[AdminVacationManagement] setState 완료, _vacationRequests.length: ${_vacationRequests.length}');
      } else {
        print('[AdminVacationManagement] API 응답에 requests 키가 없음: ${vacationResult.keys}');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('휴무 관리', style: TextStyle(color: Colors.white),),
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '휴무 승인 관리',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVacationListWithFilters(),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppSemanticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: AppSemanticColors.interactiveSecondaryDefault,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildRoleFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppSemanticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _roleFilter = value;
        });
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: Colors.blue.shade600,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildSortFilterChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppSemanticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _sortBy = value;
        });
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: Colors.green.shade600,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildVacationListWithFilters() {
    print('[AdminVacationManagement] _buildVacationListWithFilters 호출');
    print('[AdminVacationManagement] _vacationRequests.length: ${_vacationRequests.length}');
    print('[AdminVacationManagement] _statusFilter: $_statusFilter');
    
    final filteredRequests = _getFilteredRequests();
    print('[AdminVacationManagement] filteredRequests.length: ${filteredRequests.length}');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
        // 필터 섹션
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 필터
                Text('상태', style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('전체', 'all'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('승인 대기', 'pending'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('승인됨', 'approved'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('거절됨', 'rejected'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 직무 필터
                Text('직무', style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoleFilterChip('전체', 'all'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('요양보호사', 'caregiver'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('사무실', 'office'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 정렬 옵션
                Text('정렬', style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortFilterChip('신청순', 'application'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('최신순', 'latest'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('오래된순', 'oldest'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('이름순', 'name'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('직무순', 'role'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 검색 필드
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '이름, 직무로 검색...',
                    hintStyle: TextStyle(color: AppSemanticColors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppSemanticColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: Icon(Icons.clear, color: AppSemanticColors.textSecondary),
                          )
                        : null,
                    filled: true,
                    fillColor: AppSemanticColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppSemanticColors.interactiveSecondaryDefault,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 일괄 처리 버튼 (승인 대기 상태일 때만 표시)
        if (_statusFilter == 'pending' && filteredRequests.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 전체 선택 체크박스
                  Row(
                    children: [
                      Checkbox(
                        value: _selectedRequests.length == filteredRequests.length && 
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
                        activeColor: AppSemanticColors.interactiveSecondaryDefault,
                      ),
                      Text(
                        '전체 선택',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedRequests.isNotEmpty 
                              ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedRequests.length}/${filteredRequests.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedRequests.isNotEmpty 
                                ? AppSemanticColors.interactiveSecondaryDefault
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 일괄 처리 버튼들
                  if (_selectedRequests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBulkProcessing ? null : _bulkReject,
                            icon: _isBulkProcessing 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.close, size: 18),
                            label: Text(
                              _isBulkProcessing ? '처리중...' : '선택 항목 거절',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade600,
                              side: BorderSide(color: Colors.orange.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBulkProcessing ? null : _bulkApprove,
                            icon: _isBulkProcessing 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(
                              _isBulkProcessing ? '처리중...' : '선택 항목 승인',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
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
                  Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '휴무 요청이 없습니다',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final request = filteredRequests[index];
                  return _buildVacationCardWithCheckbox(request);
                },
                childCount: filteredRequests.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationList() {
    print('[AdminVacationManagement] _buildVacationList 호출');
    print('[AdminVacationManagement] _vacationRequests.length: ${_vacationRequests.length}');
    print('[AdminVacationManagement] _statusFilter: $_statusFilter');
    
    final filteredRequests = _getFilteredRequests();
    print('[AdminVacationManagement] filteredRequests.length: ${filteredRequests.length}');

    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '휴무 요청이 없습니다',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return _buildVacationCard(request);
      },
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'caregiver':
        return '요양보호사';
      case 'office':
        return '사무실';
      default:
        return role;
    }
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
    if (_roleFilter != 'all') {
      filteredRequests = filteredRequests
          .where((request) => request['role']?.toLowerCase() == _roleFilter)
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
        filteredRequests.sort((a, b) => 
          (a['userName'] ?? '').compareTo(b['userName'] ?? ''));
        break;
      case 'role':
        filteredRequests.sort((a, b) => 
          (a['role'] ?? '').compareTo(b['role'] ?? ''));
        break;
      case 'application':
        // 신청순: 생성일(createdAt)이 늦은 순 (내림차순) - 최근 신청부터
        filteredRequests.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
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
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 2,
      color: isSelected 
          ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.05) 
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(
                color: AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.3),
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isPending ? () {
          setState(() {
            if (_selectedRequests.contains(requestId)) {
              _selectedRequests.remove(requestId);
            } else {
              _selectedRequests.add(requestId);
            }
            _isSelectMode = _selectedRequests.isNotEmpty;
          });
        } : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPending)
                    SizedBox(
                      width: 24,
                      height: 24,
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
                        activeColor: AppSemanticColors.interactiveSecondaryDefault,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isPending) const SizedBox(width: 12),
                  Expanded(
                    child: _buildVacationCardHeader(request),
                  ),
                ],
              ),
              if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildReasonSection(request['reason']),
              ],
              if (!_isSelectMode) ...[
                const SizedBox(height: 12),
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

    if (isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '승인됨';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = '대기중';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = '거절됨';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_getRoleDisplayName(request['role'] ?? '')} • 휴무일: ${request['date'] ?? ''}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                '신청일: ${_formatDate(request['createdAt'])}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.message, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(color: Colors.grey.shade700),
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
          child: OutlinedButton.icon(
            onPressed: () => _showDeleteDialog(request['id'].toString()),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('삭제', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        ),
        if (isPending) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _rejectingRequests.contains(request['id'].toString()) || _approvingRequests.contains(request['id'].toString())
                  ? null 
                  : () => _rejectRequest(request['id'].toString()),
              icon: _rejectingRequests.contains(request['id'].toString())
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                      ),
                    )
                  : const Icon(Icons.close, size: 16),
              label: Text(
                _rejectingRequests.contains(request['id'].toString()) ? '처리중...' : '거절',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade600,
                side: BorderSide(color: Colors.orange.shade300),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _approvingRequests.contains(request['id'].toString()) || _rejectingRequests.contains(request['id'].toString())
                  ? null 
                  : () => _approveRequest(request['id'].toString()),
              icon: _approvingRequests.contains(request['id'].toString())
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(
                _approvingRequests.contains(request['id'].toString()) ? '처리중...' : '승인',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 이제 이 메서드는 사용하지 않음 (_buildVacationCardHeader로 대체)

  Widget _buildVacationCard(Map<String, dynamic> request) {
    final status = request['status'] ?? '';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '승인됨';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = '대기중';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = '거절됨';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['userName'] ?? '알 수 없음',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_getRoleDisplayName(request['role'] ?? '')} • 휴무일: ${request['date'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '신청일: ${_formatDate(request['createdAt'])}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.message, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request['reason'],
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // 삭제 버튼 (모든 상태에 대해 표시)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(request['id'].toString()),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('삭제', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejectingRequests.contains(request['id'].toString()) || _approvingRequests.contains(request['id'].toString())
                          ? null 
                          : () => _rejectRequest(request['id'].toString()),
                      icon: _rejectingRequests.contains(request['id'].toString())
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                              ),
                            )
                          : const Icon(Icons.close, size: 16),
                      label: Text(
                        _rejectingRequests.contains(request['id'].toString()) ? '처리중...' : '거절',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade600,
                        side: BorderSide(color: Colors.orange.shade300),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _approvingRequests.contains(request['id'].toString()) || _rejectingRequests.contains(request['id'].toString())
                          ? null 
                          : () => _approveRequest(request['id'].toString()),
                      icon: _approvingRequests.contains(request['id'].toString())
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _approvingRequests.contains(request['id'].toString()) ? '처리중...' : '승인',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalTab() {
    final pendingRequests = _vacationRequests
        .where((request) => request['status'] == 'pending')
        .toList();

    if (pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '승인 대기 중인 휴무 요청이 없습니다',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: pendingRequests.length,
      itemBuilder: (context, index) {
        final request = pendingRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(
                        (request['user']?['name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['user']?['name'] ?? '알 수 없음',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            request['user']?['role'] ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '대기중',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            '${request['startDate']} ~ ${request['endDate']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (request['reason'] != null && request['reason'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.message, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                request['reason'],
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rejectingRequests.contains(request['id'].toString()) || _approvingRequests.contains(request['id'].toString())
                            ? null 
                            : () => _rejectRequest(request['id'].toString()),
                        icon: _rejectingRequests.contains(request['id'].toString())
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                                ),
                              )
                            : const Icon(Icons.close),
                        label: Text(_rejectingRequests.contains(request['id'].toString()) ? '처리중...' : '거절'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _approvingRequests.contains(request['id'].toString()) || _rejectingRequests.contains(request['id'].toString())
                            ? null 
                            : () => _approveRequest(request['id'].toString()),
                        icon: _approvingRequests.contains(request['id'].toString())
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_approvingRequests.contains(request['id'].toString()) ? '처리중...' : '승인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLimitsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        '일일 휴무 한도 설정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '각 날짜별로 승인 가능한 최대 휴무 인원을 설정할 수 있습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showLimitSettingDialog,
                    icon: const Icon(Icons.settings),
                    label: const Text('한도 설정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_vacationLimits.isNotEmpty) ...[
            const Text(
              '현재 설정된 한도',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _vacationLimits.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final approvedRequests = _vacationRequests
        .where((request) => request['status'] != 'pending')
        .toList();

    if (approvedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '휴무 내역이 없습니다',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: approvedRequests.length,
      itemBuilder: (context, index) {
        final request = approvedRequests[index];
        final isApproved = request['status'] == 'approved';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isApproved ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isApproved ? Icons.check : Icons.close,
                        color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['user']?['name'] ?? '알 수 없음',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${request['startDate']} ~ ${request['endDate']}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isApproved ? '승인됨' : '거절됨',
                        style: TextStyle(
                          color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (request['reason'] != null && request['reason'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.message, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['reason'],
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() {
      _approvingRequests.add(requestId);
    });
    
    try {
      print('[AdminVacation] 승인 요청 시작 - requestId: $requestId');
      final result = await ApiService().approveVacationRequest(vacationId: requestId);
      print('[AdminVacation] 승인 API 응답: $result');
      
      // 성공 판단: success가 true이거나, message가 있고 에러가 없으면 성공으로 처리
      bool isSuccess = result['success'] == true || 
                      (result['message'] != null && result['error'] == null) ||
                      (result.isNotEmpty && result['error'] == null);
      
      if (isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴무 요청이 승인되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
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
        String errorMessage = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 실패: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
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
      final result = await ApiService().rejectVacationRequest(vacationId: requestId);
      print('[AdminVacation] 거절 API 응답: $result');
      
      // 성공 판단: success가 true이거나, message가 있고 에러가 없으면 성공으로 처리
      bool isSuccess = result['success'] == true || 
                      (result['message'] != null && result['error'] == null) ||
                      (result.isNotEmpty && result['error'] == null);
      
      if (isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴무 요청이 거절되었습니다'),
              backgroundColor: Colors.orange,
            ),
          );
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
        String errorMessage = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거절 실패: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _rejectingRequests.remove(requestId);
        });
      }
    }
  }

  void _showLimitSettingDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminVacationLimitsSettingScreen(),
      ),
    );
  }

  void _showDeleteDialog(String vacationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('휴무 삭제'),
          content: const Text('이 휴무를 영구적으로 삭제하시겠습니까?\n삭제된 휴무는 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteVacation(vacationId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVacation(String vacationId) async {
    try {
      print('[AdminVacationManagement] 휴무 삭제 요청 시작 - vacationId: $vacationId');
      
      final result = await ApiService().deleteVacationByAdmin(
        vacationId: vacationId,
      );
      
      print('[AdminVacationManagement] 휴무 삭제 API 응답: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('휴무가 성공적으로 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 목록 새로고침
        await _loadData();
      }
    } catch (e) {
      print('[AdminVacationManagement] 휴무 삭제 실패: $e');
      
      if (mounted) {
        String errorMessage = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴무 삭제 실패: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _bulkApprove() async {
    if (_selectedRequests.isEmpty) return;
    
    final selectedList = _selectedRequests.toList();
    
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일괄 승인'),
        content: Text('선택한 ${selectedList.length}개의 휴무 요청을 모두 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('승인'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isBulkProcessing = true;
    });
    
    try {
      print('[AdminVacation] 일괄 승인 요청 시작 - ${selectedList.length}개');
      final result = await ApiService().bulkApproveVacations(vacationIds: selectedList);
      print('[AdminVacation] 일괄 승인 API 응답: $result');
      
      final successCount = result['successCount'] ?? 0;
      final failureCount = result['failureCount'] ?? 0;
      
      if (mounted) {
        String message;
        Color bgColor;
        
        if (failureCount == 0) {
          message = '$successCount개의 휴무가 승인되었습니다';
          bgColor = Colors.green;
        } else if (successCount == 0) {
          message = '일괄 승인에 실패했습니다';
          bgColor = Colors.red;
        } else {
          message = '$successCount개 승인 성공, $failureCount개 실패';
          bgColor = Colors.orange;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );
        
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일괄 승인 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일괄 거절'),
        content: Text('선택한 ${selectedList.length}개의 휴무 요청을 모두 거절하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isBulkProcessing = true;
    });
    
    try {
      print('[AdminVacation] 일괄 거절 요청 시작 - ${selectedList.length}개');
      final result = await ApiService().bulkRejectVacations(vacationIds: selectedList);
      print('[AdminVacation] 일괄 거절 API 응답: $result');
      
      final successCount = result['successCount'] ?? 0;
      final failureCount = result['failureCount'] ?? 0;
      
      if (mounted) {
        String message;
        Color bgColor;
        
        if (failureCount == 0) {
          message = '$successCount개의 휴무가 거절되었습니다';
          bgColor = Colors.orange;
        } else if (successCount == 0) {
          message = '일괄 거절에 실패했습니다';
          bgColor = Colors.red;
        } else {
          message = '$successCount개 거절 성공, $failureCount개 실패';
          bgColor = Colors.orange;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );
        
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일괄 거절 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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