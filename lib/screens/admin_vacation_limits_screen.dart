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
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class AdminVacationLimitsScreen extends StatefulWidget {
  const AdminVacationLimitsScreen({super.key});

  @override
  State<AdminVacationLimitsScreen> createState() => _AdminVacationLimitsScreenState();
}

class _AdminVacationLimitsScreenState extends State<AdminVacationLimitsScreen> {
  Map<String, dynamic> _vacationLimits = {};
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
        title: const Text('휴무 한도'),
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
                    Icons.event_available,
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
                        '일일 휴무 한도 설정',
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
          : _buildLimitsTab(),
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
                      Icon(Icons.info_outline, color: AppSemanticColors.statusInfoIcon),
                      const SizedBox(width: 8),
                      Text(
                        '일일 휴무 한도 설정',
                        style: AppTypography.heading5.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '각 날짜별로 승인 가능한 최대 휴무 인원을 설정할 수 있습니다.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  shadcn.PrimaryButton(
                    onPressed: _showLimitSettingDialog,
                    leading: const Icon(Icons.settings),
                    child: const Text('한도 설정'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_vacationLimits.isNotEmpty) ...[
            Text(
              '현재 설정된 한도',
              style: AppTypography.heading6.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _vacationLimits.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLimitSettingDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminVacationLimitsSettingScreen(),
      ),
    );
  }
}