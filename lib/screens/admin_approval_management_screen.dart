import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/approval/signature_confirm_sheet.dart';
import '../widgets/approval/approval_card.dart';
import '../widgets/approval/approval_status_badge.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../utils/document_open.dart';
import 'approval_detail_screen.dart';
import '../widgets/seed/seed_chip.dart';

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

  /// 첨부를 누르면 앱 안에서 바로 보여준다.
  /// 한글·워드·엑셀·슬라이드·글자 파일은 뷰어로, 그 밖(pdf 등)만 기기 앱에 넘긴다.
  Future<void> _openAttachment(String? url, String fileName) async {
    await openServerDocument(
      context,
      filePath: url,
      fileName: fileName,
      onDownloadFallback: () => _downloadAndOpenFile(url, fileName),
    );
  }

  // 파일 다운로드 및 열기
  Future<void> _downloadAndOpenFile(String? url, String fileName) async {
    print('[Download] 원본 URL: $url');
    print('[Download] 파일명: $fileName');

    if (url == null || url.isEmpty) {
      AppSnackBar.showError(context, message: '파일 URL이 없습니다');
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
    AppDialog.showCustom(
      context,
      barrierDismissible: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Text(
                '다운로드 중...\n$fileName',
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
        ),
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
        AppSnackBar.showError(context, message: '파일을 열 수 없습니다: ${result.message}');
      }
    } catch (e) {
      // 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      if (mounted) {
        AppSnackBar.showError(context, message: '다운로드 실패: $e');
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
        AppSnackBar.showError(context, message: '데이터 로드 실패: $e');
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

  Future<void> _approveRequest(int requestId, {bool force = false}) async {
    // 서명 확인 (등록 서명 또는 즉석 그리기)
    final signature = await showSignatureConfirmSheet(context);
    if (signature == null || !mounted) return;

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
      signatureBase64: signature.signatureBase64,
      force: force,
    );

    if (success && mounted) {
      AppSnackBar.showSuccess(
        context,
        message: force ? '직권 승인(전결) 처리되었습니다' : '결재가 승인되었습니다',
      );
    } else if (mounted) {
      // 결재선 차례가 아니고 직권 권한도 없으면 서버가 403으로 거부한다
      AppSnackBar.showError(
        context,
        message: approvalProvider.errorMessage.isNotEmpty
            ? approvalProvider.errorMessage
            : '결재 승인에 실패했습니다',
      );
    }
  }

  /// 결재선이 있으면 내 차례일 때만 처리 가능
  bool _isMyTurn(ApprovalRequest request) {
    if (request.approvalLine.isEmpty) return true; // legacy 단일 승인
    final currentStep = request.currentStep;
    if (currentStep == null) return false;
    final myId = context.read<AuthProvider>().currentUser?.id ?? '';
    return currentStep.approverId == myId;
  }

  /// 직권 승인/반려로 건너뛰게 될 남은 결재 단계 (내 차례 제외)
  String _remainingStepsText(ApprovalRequest request) {
    final myId = context.read<AuthProvider>().currentUser?.id ?? '';
    return request.approvalLine
        .where((step) => step.isPending && step.approverId != myId)
        .map((step) => '${step.roleText} ${step.approverName}')
        .join(' → ');
  }

  /// 직권 승인/반려 전 경고 — 건너뛰게 될 남은 결재 단계를 보여주고 확인받는다
  Future<bool> _confirmForceAction(ApprovalRequest request, {required String actionLabel}) async {
    final remaining = _remainingStepsText(request);
    final message = remaining.isEmpty
        ? '아직 처리되지 않은 결재 단계가 있습니다.\n남은 단계를 건너뛰고 즉시 $actionLabel합니다. 계속하시겠습니까?'
        : '아직 처리되지 않은 결재 단계가 남아 있습니다.\n남은 단계: $remaining\n\n남은 단계를 건너뛰고 즉시 $actionLabel합니다. 계속하시겠습니까?';
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '$actionLabel (전결)',
      message: message,
      confirmText: actionLabel,
      cancelText: '취소',
    );
    return confirmed == true;
  }

  Future<void> _rejectRequest(int requestId, {bool force = false}) async {
    final reasonInput = await AppDialog.showInput(
      context,
      title: '거절 사유',
      message: '거절 사유를 입력해주세요.',
      hintText: '거절 사유를 입력하세요',
      maxLines: 3,
      confirmText: '거절',
      cancelText: '취소',
    );

    if (reasonInput == null || !mounted) return;

    final reason = reasonInput.trim();
    if (reason.isEmpty) {
      AppSnackBar.showWarning(context, message: '거절 사유를 입력해주세요');
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
      force: force,
    );

    if (success && mounted) {
      // 거절은 비파괴적 부정 결과 — 경고 톤이지 오류가 아니다
      AppSnackBar.showWarning(
        context,
        message: force ? '직권 반려(전결) 처리되었습니다' : '결재가 거절되었습니다',
      );
    }
  }

  Future<void> _bulkApprove() async {
    if (_selectedRequests.isEmpty) return;

    final confirmed = await AppDialog.showConfirm(
      context,
      title: '일괄 승인',
      message: '선택한 ${_selectedRequests.length}개의 결재 요청을 모두 승인하시겠습니까?',
      confirmText: '승인',
      cancelText: '취소',
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
        AppSnackBar.showSuccess(
          context,
          message: '${_selectedRequests.length}개의 결재가 승인되었습니다',
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

    final reasonInput = await AppDialog.showInput(
      context,
      title: '일괄 거절',
      message: '선택한 ${_selectedRequests.length}개의 결재 요청을 모두 거절하시겠습니까?',
      hintText: '거절 사유를 입력하세요',
      maxLines: 3,
      confirmText: '거절',
      cancelText: '취소',
    );

    if (reasonInput == null) return;

    final reason = reasonInput.trim();
    if (reason.isEmpty) {
      AppSnackBar.showWarning(context, message: '거절 사유를 입력해주세요');
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
        AppSnackBar.showWarning(
          context,
          message: '${_selectedRequests.length}개의 결재가 거절되었습니다',
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
                        const SizedBox(height: AppSpacing.space4),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space2,
                  ),
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
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                borderSide: BorderSide(
                  color: AppSemanticColors.interactivePrimaryDefault,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space3,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildBulkActionSection(List<ApprovalRequest> filteredRequests) {
    final pendingRequests =
        filteredRequests.where((r) => r.status == ApprovalStatus.pending);

    return Container(
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
              const SizedBox(width: AppSpacing.space2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: AppSpacing.space0_5,
                ),
                decoration: BoxDecoration(
                  color: _selectedRequests.isNotEmpty
                      ? AppSemanticColors.interactivePrimaryDefault
                          .withValues(alpha: 0.1)
                      : AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
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
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: [
                Expanded(
                  child: SeedButton(
                    label: _isBulkProcessing ? '처리중...' : '선택 항목 거절',
                    onPressed: _isBulkProcessing ? null : _bulkReject,
                    variant: SeedButtonVariant.neutralOutline,
                    isLoading: _isBulkProcessing,
                    prefixIcon: Icons.close,
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: SeedButton(
                    label: _isBulkProcessing ? '처리중...' : '선택 항목 승인',
                    onPressed: _isBulkProcessing ? null : _bulkApprove,
                    variant: SeedButtonVariant.brandSolid,
                    isLoading: _isBulkProcessing,
                    prefixIcon: Icons.check,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.space2),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ApprovalRequest request) {
    final isPending = request.status == ApprovalStatus.pending;
    final isSelected = _selectedRequests.contains(request.id);

    // 정적 리스트 카드 — 그림자 대신 보더만 (Seed 레이아웃 원칙)
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      decoration: BoxDecoration(
        color: isSelected ? AppSemanticColors.brandWeak : AppSemanticColors.surfaceDefault,
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
        // 기본 탭은 문서 상세(공문 미리보기)로 간다. 일괄 선택은 길게 눌러 시작하고,
        // 선택 모드에서는 탭이 선택 토글이 된다 (대기 문서만 선택 대상).
        onTap: () {
          if (_isSelectMode && isPending) {
            setState(() {
              if (isSelected) {
                _selectedRequests.remove(request.id);
              } else {
                _selectedRequests.add(request.id);
              }
              _isSelectMode = _selectedRequests.isNotEmpty;
            });
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ApprovalDetailScreen(approval: request),
            ),
          );
        },
        onLongPress: isPending
            ? () {
                setState(() {
                  _selectedRequests.add(request.id);
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
                  if (isPending) const SizedBox(width: AppSpacing.space3),
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
                            const SizedBox(width: AppSpacing.space2),
                            ApprovalStatusBadge(
                              status: request.status,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          '요청자: ${request.requesterName}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space0_5),
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
                const SizedBox(height: AppSpacing.space2),
                GestureDetector(
                  onTap: () => _openAttachment(
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
                      const SizedBox(width: AppSpacing.space1),
                      Icon(
                        Icons.download,
                        size: 14,
                        color: AppSemanticColors.textLink,
                      ),
                      const SizedBox(width: AppSpacing.space1),
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
                const SizedBox(height: AppSpacing.space2),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space2),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusErrorBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppSemanticColors.statusErrorIcon,
                      ),
                      const SizedBox(width: AppSpacing.space1),
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
              // 결재선 진행 상태
              if (request.approvalLine.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space2),
                Row(
                  children: [
                    Icon(Icons.route,
                        size: 14, color: AppSemanticColors.statusInfoIcon),
                    const SizedBox(width: AppSpacing.space1),
                    Expanded(
                      child: Text(
                        '결재선 ${request.approvalLine.where((s) => s.isApproved).length}/${request.approvalLine.length}'
                        '${request.status == ApprovalStatus.pending && request.currentStep != null ? ' · 현재 차례: ${request.currentStep!.approverName}' : ''}',
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.statusInfoIcon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isPending && !_isSelectMode) ...[
                const SizedBox(height: AppSpacing.space3),
                if (_isMyTurn(request))
                  Row(
                    children: [
                      Expanded(
                        child: SeedButton(
                          label: '거절',
                          onPressed: () => _rejectRequest(request.id),
                          variant: SeedButtonVariant.neutralOutline,
                          prefixIcon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: SeedButton(
                          label: '승인',
                          onPressed: () => _approveRequest(request.id),
                          variant: SeedButtonVariant.brandSolid,
                          prefixIcon: Icons.check,
                        ),
                      ),
                    ],
                  )
                else if (AdminUtils.hasAdminPermission(
                    context.read<AuthProvider>().currentUser))
                  // 내 차례가 아니어도 기관 관리자는 직권 승인(전결)·직권 반려 가능
                  // (실제 권한 재검증은 서버가 하므로 여기서는 노출 조건만 담당)
                  Row(
                    children: [
                      Expanded(
                        child: SeedButton(
                          label: '직권 반려',
                          onPressed: () async {
                            if (await _confirmForceAction(request, actionLabel: '직권 반려')) {
                              _rejectRequest(request.id, force: true);
                            }
                          },
                          variant: SeedButtonVariant.neutralOutline,
                          prefixIcon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: SeedButton(
                          label: '직권 승인',
                          onPressed: () async {
                            if (await _confirmForceAction(request, actionLabel: '직권 승인')) {
                              _approveRequest(request.id, force: true);
                            }
                          },
                          variant: SeedButtonVariant.brandSolid,
                          prefixIcon: Icons.check,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Center(
                      child: Text(
                        '${request.currentStep?.approverName ?? '다른 결재자'}님의 차례입니다',
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
