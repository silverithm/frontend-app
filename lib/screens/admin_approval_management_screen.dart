import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/approval_card.dart';
import '../widgets/approval/approval_status_badge.dart';

class AdminApprovalManagementScreen extends StatefulWidget {
  const AdminApprovalManagementScreen({super.key});

  @override
  State<AdminApprovalManagementScreen> createState() =>
      _AdminApprovalManagementScreenState();
}

class _AdminApprovalManagementScreenState
    extends State<AdminApprovalManagementScreen> {
  bool _isLoading = false;
  String _statusFilter = 'pending';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 선택 관리
  Set<int> _selectedRequests = {};
  bool _isSelectMode = false;
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    // 빌드 완료 후 데이터 로드 (setState during build 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 파일 다운로드 및 열기
  Future<void> _downloadAndOpenFile(String? url, String fileName) async {
    print('[Download] 원본 URL: $url');
    print('[Download] 파일명: $fileName');

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 URL이 없습니다')),
      );
      return;
    }

    // 상대 경로인 경우 baseUrl 추가
    String fullUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // /로 시작하지 않으면 / 추가
      if (!url.startsWith('/')) {
        fullUrl = 'https://silverithm.site/$url';
      } else {
        fullUrl = 'https://silverithm.site$url';
      }
    }

    print('[Download] 최종 URL: $fullUrl');

    // 다운로드 진행 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => shadcn.AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: AppSpacing.space4),
                Expanded(child: Text('다운로드 중...\n$fileName')),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );

    try {
      // 저장 경로 설정
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // 파일 다운로드
      final dioClient = dio.Dio();
      await dioClient.download(fullUrl, filePath);

      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      // 파일 열기
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 열 수 없습니다: ${result.message}')),
        );
      }
    } catch (e) {
      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final approvalProvider = context.read<ApprovalProvider>();

      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      await approvalProvider.loadApprovalRequests(companyId: companyId);
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

  List<ApprovalRequest> _getFilteredRequests(List<ApprovalRequest> requests) {
    var filtered = requests.toList();

    // 상태 필터링
    if (_statusFilter != 'all') {
      filtered = filtered.where((r) {
        switch (_statusFilter) {
          case 'pending':
            return r.status == ApprovalStatus.pending;
          case 'approved':
            return r.status == ApprovalStatus.approved;
          case 'rejected':
            return r.status == ApprovalStatus.rejected;
          default:
            return true;
        }
      }).toList();
    }

    // 검색 필터링
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(searchLower) ||
            r.requesterName.toLowerCase().contains(searchLower);
      }).toList();
    }

    // 최신순 정렬
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Future<void> _approveRequest(int requestId) async {
    final approvalProvider = context.read<ApprovalProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final companyId = currentUser?.company?.id?.toString() ?? '';
    final processedBy = currentUser?.id ?? '';
    final processedByName = currentUser?.name ?? '';
    final success = await approvalProvider.approveApprovalRequest(
      approvalId: requestId,
      companyId: companyId,
      processedBy: processedBy,
      processedByName: processedByName,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('결재가 승인되었습니다'),
          backgroundColor: AppSemanticColors.statusSuccessIcon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Text(
          '거절 사유',
          style: AppTypography.heading6,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '거절 사유를 입력해주세요.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '거절 사유를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('거절 사유를 입력해주세요'),
            backgroundColor: AppSemanticColors.statusWarningIcon,
          ),
        );
        return;
      }

      final approvalProvider = context.read<ApprovalProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      final companyId = currentUser?.company?.id?.toString() ?? '';
      final processedBy = currentUser?.id ?? '';
      final processedByName = currentUser?.name ?? '';
      final success = await approvalProvider.rejectApprovalRequest(
        approvalId: requestId,
        reason: reason,
        companyId: companyId,
        processedBy: processedBy,
        processedByName: processedByName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('결재가 거절되었습니다'),
            backgroundColor: AppSemanticColors.statusWarningIcon,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    reasonController.dispose();
  }

  Future<void> _bulkApprove() async {
    if (_selectedRequests.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('일괄 승인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('선택한 ${_selectedRequests.length}개의 결재 요청을 모두 승인하시겠습니까?'),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.PrimaryButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('승인'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);

    try {
      final approvalProvider = context.read<ApprovalProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      final companyId = currentUser?.company?.id?.toString() ?? '';
      final processedBy = currentUser?.id ?? '';
      final processedByName = currentUser?.name ?? '';
      final success = await approvalProvider.bulkApproveApprovalRequests(
        approvalIds: _selectedRequests.toList(),
        companyId: companyId,
        processedBy: processedBy,
        processedByName: processedByName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedRequests.length}개의 결재가 승인되었습니다'),
            backgroundColor: AppSemanticColors.statusSuccessIcon,
          ),
        );
        setState(() {
          _selectedRequests.clear();
          _isSelectMode = false;
        });
      }
    } finally {
      setState(() => _isBulkProcessing = false);
    }
  }

  Future<void> _bulkReject() async {
    if (_selectedRequests.isEmpty) return;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('일괄 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('선택한 ${_selectedRequests.length}개의 결재 요청을 모두 거절하시겠습니까?'),
            const SizedBox(height: AppSpacing.space4),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '거절 사유를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('거절 사유를 입력해주세요'),
          backgroundColor: AppSemanticColors.statusWarningIcon,
        ),
      );
      reasonController.dispose();
      return;
    }

    setState(() => _isBulkProcessing = true);

    try {
      final approvalProvider = context.read<ApprovalProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      final companyId = currentUser?.company?.id?.toString() ?? '';
      final processedBy = currentUser?.id ?? '';
      final processedByName = currentUser?.name ?? '';
      final success = await approvalProvider.bulkRejectApprovalRequests(
        approvalIds: _selectedRequests.toList(),
        reason: reason,
        companyId: companyId,
        processedBy: processedBy,
        processedByName: processedByName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedRequests.length}개의 결재가 거절되었습니다'),
            backgroundColor: AppSemanticColors.statusWarningIcon,
          ),
        );
        setState(() {
          _selectedRequests.clear();
          _isSelectMode = false;
        });
      }
    } finally {
      setState(() => _isBulkProcessing = false);
    }

    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Consumer<ApprovalProvider>(
      builder: (context, approvalProvider, child) {
        final filteredRequests =
            _getFilteredRequests(approvalProvider.approvalRequests);

        return RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // 필터 섹션
              SliverToBoxAdapter(
                child: _buildFilterSection(),
              ),

              // 일괄 처리 버튼
              if (_statusFilter == 'pending' && filteredRequests.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildBulkActionSection(filteredRequests),
                ),

              // 결재 목록
              if (filteredRequests.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: AppSemanticColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '결재 요청이 없습니다',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final request = filteredRequests[index];
                        return _buildRequestCard(request);
                      },
                      childCount: filteredRequests.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

          // 검색 필드
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: '제목, 요청자로 검색...',
              hintStyle: TextStyle(color: AppSemanticColors.textSecondary),
              prefixIcon:
                  Icon(Icons.search, color: AppSemanticColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: Icon(Icons.clear,
                          color: AppSemanticColors.textSecondary),
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
                  color: AppSemanticColors.interactivePrimaryDefault,
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
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: isSelected
              ? AppSemanticColors.textInverse
              : AppSemanticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: AppSemanticColors.interactivePrimaryDefault,
      checkmarkColor: AppSemanticColors.textInverse,
    );
  }

  Widget _buildBulkActionSection(List<ApprovalRequest> filteredRequests) {
    final pendingRequests =
        filteredRequests.where((r) => r.status == ApprovalStatus.pending);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전체 선택 체크박스
          Row(
            children: [
              Checkbox(
                value: _selectedRequests.length == pendingRequests.length &&
                    pendingRequests.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedRequests =
                          pendingRequests.map((r) => r.id).toSet();
                    } else {
                      _selectedRequests.clear();
                    }
                    _isSelectMode = _selectedRequests.isNotEmpty;
                  });
                },
                activeColor: AppSemanticColors.interactivePrimaryDefault,
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
                      ? AppSemanticColors.interactivePrimaryDefault
                          .withValues(alpha: 0.1)
                      : AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedRequests.length}/${pendingRequests.length}',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _selectedRequests.isNotEmpty
                        ? AppSemanticColors.interactivePrimaryDefault
                        : AppSemanticColors.textSecondary,
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
                  child: shadcn.OutlineButton(
                    onPressed: _isBulkProcessing ? null : _bulkReject,
                    leading: _isBulkProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
                    child: Text(
                      _isBulkProcessing ? '처리중...' : '선택 항목 거절',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: shadcn.PrimaryButton(
                    onPressed: _isBulkProcessing ? null : _bulkApprove,
                    leading: _isBulkProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    child: Text(
                      _isBulkProcessing ? '처리중...' : '선택 항목 승인',
                      style: AppTypography.bodyMedium,
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
    );
  }

  Widget _buildRequestCard(ApprovalRequest request) {
    final isPending = request.status == ApprovalStatus.pending;
    final isSelected = _selectedRequests.contains(request.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 2,
      color: isSelected
          ? AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.05)
          : AppSemanticColors.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: AppSemanticColors.interactivePrimaryDefault
                    .withValues(alpha: 0.3),
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isPending
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedRequests.remove(request.id);
                  } else {
                    _selectedRequests.add(request.id);
                  }
                  _isSelectMode = _selectedRequests.isNotEmpty;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              _selectedRequests.add(request.id);
                            } else {
                              _selectedRequests.remove(request.id);
                            }
                            _isSelectMode = _selectedRequests.isNotEmpty;
                          });
                        },
                        activeColor:
                            AppSemanticColors.interactivePrimaryDefault,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isPending) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.title,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ApprovalStatusBadge(
                              status: request.status,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '요청자: ${request.requesterName}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '요청일: ${_formatDate(request.createdAt)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (request.attachmentFileName != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _downloadAndOpenFile(
                    request.attachmentUrl,
                    request.attachmentFileName!,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: AppSemanticColors.textLink,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.download,
                        size: 14,
                        color: AppSemanticColors.textLink,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.attachmentFileName!,
                          style: AppTypography.caption.copyWith(
                            color: AppSemanticColors.textLink,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (request.rejectReason != null &&
                  request.status == ApprovalStatus.rejected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusErrorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppSemanticColors.statusErrorIcon,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.rejectReason!,
                          style: AppTypography.caption.copyWith(
                            color: AppSemanticColors.statusErrorText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isPending && !_isSelectMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: shadcn.OutlineButton(
                        onPressed: () => _rejectRequest(request.id),
                        leading: const Icon(Icons.close, size: 16),
                        child: const Text('거절'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: shadcn.PrimaryButton(
                        onPressed: () => _approveRequest(request.id),
                        leading: const Icon(Icons.check, size: 16),
                        child: const Text('승인'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
