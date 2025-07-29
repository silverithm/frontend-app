import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/common/index.dart';
import '../utils/admin_utils.dart';
import 'login_screen.dart';

class AdminCompanySettingsScreen extends StatefulWidget {
  const AdminCompanySettingsScreen({super.key});

  @override
  State<AdminCompanySettingsScreen> createState() => _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState extends State<AdminCompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  Map<String, dynamic>? _companyProfile;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService().getCompanyProfile();
      
      if (result['success'] == true) {
        setState(() {
          _companyProfile = result['data'];
          _populateFields();
        });
      } else {
        throw Exception(result['message'] ?? '회사 정보 로드 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회사 정보 로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateFields() {
    if (_companyProfile != null) {
      _nameController.text = _companyProfile!['name'] ?? '';
      _addressController.text = _companyProfile!['address'] ?? '';
      _phoneController.text = _companyProfile!['phone'] ?? '';
      _emailController.text = _companyProfile!['email'] ?? '';
      _descriptionController.text = _companyProfile!['description'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        return Scaffold(
          backgroundColor: AppSemanticColors.backgroundPrimary,
          appBar: AppBar(
            title: const Text('회사정보',style: TextStyle(color:Colors.white),),
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
                        Icons.business_center,
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
                            '회사 정보 및 관리자 설정',
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.space6),
                  child: Column(
                    children: [
                      // 개인 정보 섹션
                      _buildProfileSection(user),
                      const SizedBox(height: AppSpacing.space6),
                      
                      // 회사 정보 섹션
                      _buildCompanySection(),
                      const SizedBox(height: AppSpacing.space6),
                      
                      // 설정 섹션
                      _buildSettingsSection(context),
                      const SizedBox(height: AppSpacing.space8),
                      
                      // 로그아웃 버튼
                      _buildLogoutButton(context),
                      const SizedBox(height: AppSpacing.space8),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfileSection(user) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              Icon(
                Icons.person,
                color: AppSemanticColors.interactiveSecondaryDefault,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '내 정보',
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          
          // 개인 정보 목록
          if (user != null) ...[
            _buildInfoRow(
              icon: Icons.badge,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '이름',
              value: user.name ?? '',
            ),
            const SizedBox(height: AppSpacing.space3),
            _buildInfoRow(
              icon: Icons.email,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '이메일',
              value: user.email ?? '',
            ),
            const SizedBox(height: AppSpacing.space3),
            if (user.position != null)
              _buildInfoRow(
                icon: Icons.work,
                iconColor: AppSemanticColors.interactiveSecondaryDefault,
                title: '직책',
                value: user.position!,
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompanySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              Icon(
                Icons.business,
                color: AppSemanticColors.interactiveSecondaryDefault,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '회사 정보',
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                AppButton(
                  text: _isSaving ? '저장 중...' : '수정',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : () => _showCompanyEditDialog(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          
          // 회사 정보 목록
          if (_companyProfile != null) ...[
            _buildInfoRow(
              icon: Icons.business,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '회사명',
              value: _companyProfile!['name'] ?? '',
            ),
            const SizedBox(height: AppSpacing.space3),
            _buildInfoRow(
              icon: Icons.location_on,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '주소',
              value: _companyProfile!['address'] ?? '',
            ),
            const SizedBox(height: AppSpacing.space3),
            _buildInfoRow(
              icon: Icons.phone,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '전화번호',
              value: _companyProfile!['phone'] ?? '',
            ),
            const SizedBox(height: AppSpacing.space3),
            _buildInfoRow(
              icon: Icons.email,
              iconColor: AppSemanticColors.interactiveSecondaryDefault,
              title: '이메일',
              value: _companyProfile!['email'] ?? '',
            ),
          ] else ...[
            const Center(
              child: Text('회사 정보를 불러오는 중...'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSettingsSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              Icon(
                Icons.settings,
                color: AppSemanticColors.interactiveSecondaryDefault,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '설정',
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          
          // 설정 항목들
          _buildSettingItem(
            icon: Icons.info,
            iconColor: AppSemanticColors.interactivePrimaryDefault,
            title: '앱 정보',
            subtitle: '버전 및 개발자 정보',
            onTap: () => _showAppInfoDialog(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogoutButton(BuildContext context) {
    return AppButton(
      text: '로그아웃',
      variant: AppButtonVariant.outline,
      isFullWidth: true,
      onPressed: () => _showLogoutDialog(context),
      icon: const Icon(Icons.logout, size: 20),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: AppSpacing.space2),
        SizedBox(
          width: 60,
          child: Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.space3,
          horizontal: AppSpacing.space2,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.space2),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textPrimary,
                      fontWeight: AppTypography.fontWeightMedium,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppSemanticColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCompanyEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '회사 정보 수정',
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInput(
                  label: '회사명',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '회사명을 입력해주세요';
                    }
                    return null;
                  }
                ),
                const SizedBox(height: AppSpacing.space4),
                AppInput(
                  label: '주소',
                  controller: _addressController,
                ),
                const SizedBox(height: AppSpacing.space4),
                AppInput(
                  label: '전화번호',
                  controller: _phoneController,
                ),
                const SizedBox(height: AppSpacing.space4),
                AppInput(
                  label: '이메일',
                  controller: _emailController,
                ),
                const SizedBox(height: AppSpacing.space4),
                AppInput(
                  label: '회사 설명',
                  controller: _descriptionController,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            text: '취소',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton(
            text: '저장',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                _saveCompanyProfile();
              }
            },
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
      ),
    );
  }
  
  void _showLogoutDialog(BuildContext context) {
    AppDialog.showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
    ).then((confirmed) {
      if (confirmed == true) {
        _logout(context);
      }
    });
  }
  
  void _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
  
  void _showAppInfoDialog(BuildContext context) {
    AppDialog.showAlert(
      context,
      title: '앱 정보',
      message: '케어브이 관리자 앱\n버전: 1.0.0\n\n개발: 실버리듬',
    );
  }
  
  Future<void> _saveCompanyProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final result = await ApiService().updateCompanyProfile(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
      );
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('회사 정보가 성공적으로 저장되었습니다'),
              backgroundColor: AppSemanticColors.statusSuccessBackground,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          );
          // 저장 후 데이터 다시 로드
          await _loadCompanyProfile();
        }
      } else {
        throw Exception(result['message'] ?? '저장 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: AppSemanticColors.statusErrorBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}