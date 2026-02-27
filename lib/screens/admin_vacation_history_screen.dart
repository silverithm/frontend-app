import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';

class AdminVacationHistoryScreen extends StatefulWidget {
  const AdminVacationHistoryScreen({super.key});

  @override
  State<AdminVacationHistoryScreen> createState() => _AdminVacationHistoryScreenState();
}

class _AdminVacationHistoryScreenState extends State<AdminVacationHistoryScreen> {
  List<Map<String, dynamic>> _vacationRequests = [];
  bool _isLoading = false;

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
      
      // 휴무 요청 목록 로드
      final vacationResult = await ApiService().getVacationRequests(companyId: companyId);
      if (vacationResult['success'] == true) {
        setState(() {
          _vacationRequests = List<Map<String, dynamic>>.from(vacationResult['data'] ?? []);
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
        title: const Text('휴무 내역'),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppSemanticColors.textInverse),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history,
                    color: AppSemanticColors.textInverse,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 휴무 내역 조회',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
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
          : _buildHistoryTab(),
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
            Icon(Icons.history, size: 64, color: AppSemanticColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              '휴무 내역이 없습니다',
              style: AppTypography.bodyLarge.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: approvedRequests.length,
      itemBuilder: (context, index) {
        final request = approvedRequests[index];
        final isApproved = request['status'] == 'approved';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isApproved ? AppSemanticColors.statusSuccessBackground : AppSemanticColors.statusErrorBackground,
                      child: Icon(
                        isApproved ? Icons.check : Icons.close,
                        color: isApproved ? AppSemanticColors.statusSuccessText : AppSemanticColors.statusErrorText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['user']?['name'] ?? '알 수 없음',
                            style: AppTypography.heading6.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${request['startDate']} ~ ${request['endDate']}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? AppSemanticColors.statusSuccessBackground : AppSemanticColors.statusErrorBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isApproved ? '승인됨' : '거절됨',
                        style: AppTypography.labelMedium.copyWith(
                          color: isApproved ? AppSemanticColors.statusSuccessText : AppSemanticColors.statusErrorText,
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
                      color: AppSemanticColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.message, size: 16, color: AppSemanticColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['reason'],
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
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
}