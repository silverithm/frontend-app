import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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
  String _sortBy = 'latest'; // latest, name, role
  
  // 개별 요청의 처리 상태 추적 (승인과 거절을 구분)
  Set<String> _approvingRequests = {};
  Set<String> _rejectingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      
      // 휴가 요청 목록 로드
      print('[AdminVacationManagement] API 호출 시작 - companyId: $companyId');
      final vacationResult = await ApiService().getVacationRequests(
        companyId: companyId,
      );
      print('[AdminVacationManagement] API 응답 키들: ${vacationResult.keys}');
      print('[AdminVacationManagement] containsKey requests: ${vacationResult.containsKey('requests')}');
      
      if (vacationResult.containsKey('requests')) {
        final requestsList = List<Map<String, dynamic>>.from(vacationResult['requests'] ?? []);
        print('[AdminVacationManagement] 로드된 휴가 요청 수: ${requestsList.length}');
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

      // 휴가 한도 로드
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
        title: const Text('휴가 관리', style: TextStyle(color: Colors.white),),
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
                        '휴가 승인 관리',
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

    return CustomScrollView(
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
                      _buildSortFilterChip('최신순', 'latest'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('이름순', 'name'),
                      const SizedBox(width: 8),
                      _buildSortFilterChip('직무순', 'role'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 휴가 목록
        if (filteredRequests.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '휴가 요청이 없습니다',
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
                  return _buildVacationCard(request);
                },
                childCount: filteredRequests.length,
              ),
            ),
          ),
      ],
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
              '휴가 요청이 없습니다',
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
      case 'latest':
      default:
        filteredRequests.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA); // 최신순 (내림차순)
        });
        break;
    }

    return filteredRequests;
  }

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
                        '${_getRoleDisplayName(request['role'] ?? '')} • ${request['date'] ?? ''}',
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
            if (isPending) ...[
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
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                              ),
                            )
                          : const Icon(Icons.close, size: 16),
                      label: Text(
                        _rejectingRequests.contains(request['id'].toString()) ? '처리중...' : '거절',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              ),
            ],
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
              '승인 대기 중인 휴가 요청이 없습니다',
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
                        '일일 휴가 한도 설정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '각 날짜별로 승인 가능한 최대 휴가 인원을 설정할 수 있습니다.',
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
              '휴가 내역이 없습니다',
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
              content: Text('휴가 요청이 승인되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          print('[AdminVacation] 승인 성공 - 데이터 새로고침 시작');
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
              content: Text('휴가 요청이 거절되었습니다'),
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
}