import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/notice/notice_card.dart';
import '../widgets/common/app_loading.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatefulWidget {
  final bool showAppBar;

  const NoticeListScreen({super.key, this.showAppBar = true});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotices(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNotices();
    }
  }

  Future<void> _loadNotices({bool refresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    final noticeProvider = context.read<NoticeProvider>();

    final companyId = authProvider.currentUser?.company?.id ?? '1';

    await noticeProvider.loadPublishedNotices(
      companyId: companyId,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                '공지사항',
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              backgroundColor: AppSemanticColors.backgroundPrimary,
              elevation: 0,
              centerTitle: true,
            )
          : null,
      body: Consumer<NoticeProvider>(
        builder: (context, noticeProvider, child) {
          if (noticeProvider.isLoading && noticeProvider.publishedNotices.isEmpty) {
            return const Center(child: AppLoading());
          }

          if (noticeProvider.errorMessage.isNotEmpty &&
              noticeProvider.publishedNotices.isEmpty) {
            return _buildErrorState(noticeProvider.errorMessage);
          }

          if (noticeProvider.publishedNotices.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => _loadNotices(refresh: true),
            color: AppSemanticColors.interactivePrimaryDefault,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              itemCount: noticeProvider.publishedNotices.length +
                  (noticeProvider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == noticeProvider.publishedNotices.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.space4),
                    child: Center(child: AppLoading(size: 24)),
                  );
                }

                final notice = noticeProvider.publishedNotices[index];
                return NoticeCard(
                  notice: notice,
                  onTap: () => _navigateToDetail(notice),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: AppSemanticColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '공지사항이 없습니다',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '새로운 공지사항이 등록되면 여기에 표시됩니다',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '오류가 발생했습니다',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          shadcn.PrimaryButton(
            onPressed: () => _loadNotices(refresh: true),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(Notice notice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(noticeId: notice.id),
      ),
    );
  }
}
