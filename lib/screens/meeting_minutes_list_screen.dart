import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_tag.dart';
import 'meeting_minutes_detail_screen.dart';

/// 회의록 목록 — 서명 요청이 온 회의록을 확인하고 들어가서 서명한다.
class MeetingMinutesListScreen extends StatefulWidget {
  const MeetingMinutesListScreen({super.key});

  @override
  State<MeetingMinutesListScreen> createState() => _MeetingMinutesListScreenState();
}

class _MeetingMinutesListScreenState extends State<MeetingMinutesListScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId =
        context.read<AuthProvider>().currentUser?.company?.id.toString() ?? '';
    if (companyId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '소속 기관 정보를 확인할 수 없습니다.';
      });
      return;
    }

    try {
      final items = await ApiService().getMeetingMinutesList(companyId: companyId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '회의록을 불러오지 못했습니다.';
      });
    }
  }

  ({AppTagTone tone, String label}) _statusStyle(String status) {
    switch (status) {
      case 'COMPLETED':
        return (tone: AppTagTone.success, label: '완료');
      case 'REGISTERED':
        return (tone: AppTagTone.warning, label: '서명 수집 중');
      default:
        return (tone: AppTagTone.neutral, label: '작성 중');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(title: const Text('회의록')),
      body: AppRefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const _MeetingMinutesListSkeleton()
            : _error != null
                ? _message(_error!)
                : _items.isEmpty
                    ? _emptyState()
                    : AppListEntrance(
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenGutter,
                            AppSpacing.space3,
                            AppSpacing.screenGutter,
                            AppSpacing.space8,
                          ),
                          itemCount: _items.length,
                          // B안: 카드끼리는 선 대신 간격으로 나눈다
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.cardGap),
                          itemBuilder: (context, index) {
                            final item = _items[index] as Map<String, dynamic>;
                            final status = _statusStyle(item['status']?.toString() ?? '');
                            final startAt = item['meetingStartAt']?.toString() ?? '';
                            final when = startAt.length >= 16
                                ? '${startAt.substring(0, 10)} ${startAt.substring(11, 16)}'
                                : startAt;
                            final signed = item['signedCount'] ?? 0;
                            final total = item['attendeeCount'] ?? 0;

                            // B안: 회색 바탕 위 흰 카드(테두리 없음, 모서리 16, 안쪽 16)
                            return AppListEntranceItem(
                              index: index,
                              child: AppCard(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MeetingMinutesDetailScreen(
                                        minutesId: item['id'] as int,
                                      ),
                                    ),
                                  );
                                  _load();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['title']?.toString() ?? '',
                                            style: AppTypography.titleMedium.copyWith(
                                              color: AppSemanticColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.space2),
                                        AppTag(
                                          label: status.label,
                                          tone: status.tone,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.space1_5),
                                    Text(
                                      '$when · ${item['authorName'] ?? ''} · 서명 $signed/$total',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppSemanticColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _emptyState() {
    // RefreshIndicator가 동작하려면 스크롤 가능한 자식이 필요하다
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        AppEmptyState(
          icon: Icons.description_outlined,
          title: '아직 회의록이 없습니다',
          description: '서명 요청이 오면 여기에서 확인할 수 있어요',
        ),
      ],
    );
  }

  Widget _message(String text) {
    // B안 빈 화면 모양으로 — AppEmptyState 안의 스크롤이 당겨서 새로고침을 받는다
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: text,
    );
  }
}

/// 회의록 목록 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드(목록과 같은 여백·간격)
class _MeetingMinutesListSkeleton extends StatelessWidget {
  const _MeetingMinutesListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
          AppSpacing.screenGutter,
          AppSpacing.space8,
        ),
        children: List.generate(
          5,
          (_) => const AppSkeletonCard(
            standalone: false,
            margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
          ),
        ),
      ),
    );
  }
}
