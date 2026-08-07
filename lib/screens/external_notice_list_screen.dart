import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/external_notice.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';

/// 장기요양 소식 — 노인장기요양보험(longtermcare.or.kr) 공지·법령·평가·교육 자료.
/// GET /api/v1/external-notices (전 기관 공용, 인증 필요) — ExternalNoticeController.
class ExternalNoticeListScreen extends StatefulWidget {
  const ExternalNoticeListScreen({super.key});

  @override
  State<ExternalNoticeListScreen> createState() => _ExternalNoticeListScreenState();
}

class _ExternalNoticeListScreenState extends State<ExternalNoticeListScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<ExternalNotice> _notices = [];

  String? _selectedSource; // null = 전체
  int _page = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotices(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNotices();
    }
  }

  Future<void> _loadNotices({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _page = 0;
        _hasMore = true;
        _errorMessage = null;
        _isInitialLoad = true;
      }
    });

    try {
      final response = await ApiService().getExternalNotices(
        source: _selectedSource,
        page: refresh ? 0 : _page,
        size: _pageSize,
      );

      final content = response['content'];
      final list = content is List ? content : <dynamic>[];
      final notices = list
          .whereType<Map<String, dynamic>>()
          .map(ExternalNotice.fromJson)
          .toList();

      final last = response['last'] == true;
      final totalPages = response['totalPages'];
      final nextPage = (refresh ? 0 : _page) + 1;
      final hasMore = !last && (totalPages is! int || nextPage < totalPages);

      if (!mounted) return;
      setState(() {
        if (refresh) _notices.clear();
        _notices.addAll(notices);
        _page = nextPage;
        _hasMore = hasMore;
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        if (refresh || _notices.isEmpty) {
          _errorMessage = '소식을 불러오지 못했습니다';
        }
      });
    }
  }

  void _selectSource(String? source) {
    if (_selectedSource == source) return;
    setState(() => _selectedSource = source);
    _loadNotices(refresh: true);
  }

  Future<void> _openNotice(ExternalNotice notice) async {
    if (notice.url.isEmpty) return;
    final uri = Uri.tryParse(notice.url);
    if (uri == null) return;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppSnackBar.showError(context, message: '링크를 열 수 없습니다');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: '링크를 여는 중 오류가 발생했습니다');
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('장기요양 소식', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppSemanticColors.backgroundPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SeedChip(
                    label: '전체',
                    selected: _selectedSource == null,
                    onTap: () => _selectSource(null),
                  ),
                  for (final source in ExternalNoticeSource.all) ...[
                    const SizedBox(width: AppSpacing.space2),
                    SeedChip(
                      label: source.label,
                      selected: _selectedSource == source.value,
                      onTap: () => _selectSource(source.value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoad) {
      return const AppLoading();
    }

    if (_errorMessage != null && _notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(height: AppSpacing.space3),
            Text(
              _errorMessage!,
              style: AppTypography.bodyMedium.copyWith(color: AppSemanticColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.space3),
            SeedButton(
              label: '다시 시도',
              variant: SeedButtonVariant.neutralWeak,
              onPressed: () => _loadNotices(refresh: true),
            ),
          ],
        ),
      );
    }

    if (_notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: AppSemanticColors.textTertiary),
            const SizedBox(height: AppSpacing.space3),
            Text(
              '표시할 소식이 없어요',
              style: AppTypography.bodyMedium.copyWith(color: AppSemanticColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotices(refresh: true),
      color: AppSemanticColors.interactivePrimaryDefault,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.space4),
        itemCount: _notices.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.space2),
        itemBuilder: (context, index) {
          if (index == _notices.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
              child: Center(child: AppLoading(size: 24)),
            );
          }

          final notice = _notices[index];
          return _NoticeCard(
            notice: notice,
            dateLabel: _formatDate(notice.postedDate),
            onTap: () => _openNotice(notice),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final ExternalNotice notice;
  final String dateLabel;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.notice,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(color: AppSemanticColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.brandWeak,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  ),
                  child: Text(
                    notice.sourceLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.brandPressed,
                    ),
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    dateLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    notice.title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Icon(Icons.open_in_new, size: 16, color: AppSemanticColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
