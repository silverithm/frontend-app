import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/schedule_provider.dart';
import '../providers/auth_provider.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';

class AdminScheduleCalendarScreen extends StatefulWidget {
  const AdminScheduleCalendarScreen({super.key});

  @override
  State<AdminScheduleCalendarScreen> createState() =>
      _AdminScheduleCalendarScreenState();
}

class _AdminScheduleCalendarScreenState
    extends State<AdminScheduleCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedules();
    });
  }

  Future<void> _loadSchedules() async {
    final authProvider = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '1';
    await scheduleProvider.loadCalendarData(_currentMonth, companyId: companyId);
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadSchedules();
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        child: Icon(Icons.add, color: AppSemanticColors.textInverse),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          return Column(
            children: [
              // 월 네비게이션
              _buildMonthNavigation(),
              // 요일 헤더
              _buildWeekdayHeader(),
              // 달력
              Expanded(
                child: scheduleProvider.isLoading
                    ? const Center(child: AppLoading())
                    : _buildCalendar(scheduleProvider),
              ),
              // 선택된 날짜의 일정 목록
              if (_selectedDate != null)
                _buildScheduleList(scheduleProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _goToPreviousMonth,
            icon: Icon(
              Icons.chevron_left,
              color: AppSemanticColors.textPrimary,
            ),
          ),
          Text(
            DateFormat('yyyy년 MM월').format(_currentMonth),
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: _goToNextMonth,
            icon: Icon(
              Icons.chevron_right,
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: weekdays.map((day) {
          final isWeekend = day == '일' || day == '토';
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: AppTypography.labelMedium.copyWith(
                  color: isWeekend
                      ? (day == '일'
                          ? AppSemanticColors.statusErrorIcon
                          : AppSemanticColors.statusInfoIcon)
                      : AppSemanticColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendar(ScheduleProvider scheduleProvider) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.space2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayOffset = index - firstWeekday;
        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, dayOffset + 1);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isSelected = _selectedDate != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;
        final hasSchedules = scheduleProvider.hasSchedulesOnDate(date);
        final isWeekend = index % 7 == 0 || index % 7 == 6;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppSemanticColors.interactivePrimaryDefault
                  : isToday
                      ? AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1)
                      : null,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dayOffset + 1}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppSemanticColors.textInverse
                        : isWeekend
                            ? (index % 7 == 0
                                ? AppSemanticColors.statusErrorIcon
                                : AppSemanticColors.statusInfoIcon)
                            : AppSemanticColors.textPrimary,
                    fontWeight: isToday || isSelected ? FontWeight.bold : null,
                  ),
                ),
                if (hasSchedules)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppSemanticColors.textInverse
                          : AppSemanticColors.statusInfoIcon,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleList(ScheduleProvider scheduleProvider) {
    final schedules = scheduleProvider.getSchedulesForDate(_selectedDate!);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          top: BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Row(
              children: [
                Text(
                  DateFormat('MM월 dd일 (E)', 'ko').format(_selectedDate!),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  '${schedules.length}건',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: schedules.isEmpty
                ? Center(
                    child: Text(
                      '등록된 일정이 없습니다',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                    ),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      return _buildScheduleItem(schedules[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 담당자 후보 (회사 직원)
  List<Map<String, dynamic>> _memberOptions = [];

  Future<void> _loadMemberOptions() async {
    if (_memberOptions.isNotEmpty) return;
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';
      final response = await ApiService().getCompanyMembers(companyId: companyId.toString());
      final members = (response['members'] as List?) ?? [];
      _memberOptions = members
          .whereType<Map>()
          .map((m) => {
                'id': m['id'] is int ? m['id'] : int.tryParse(m['id']?.toString() ?? ''),
                'name': m['name']?.toString() ?? '',
              })
          .where((m) => m['id'] != null && (m['name'] as String).isNotEmpty)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('담당자 후보 로드 실패: $e');
    }
  }

  void _showAddScheduleDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final locationController = TextEditingController();
    String selectedCategory = 'MEETING';
    DateTime startDate = _selectedDate ?? DateTime.now();
    DateTime endDate = _selectedDate ?? DateTime.now();
    bool isAllDay = true;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    bool sendNotification = false;
    int? selectedManagerId;

    _loadMemberOptions();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '일정 등록',
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppSemanticColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 제목
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '제목 *',
                        hintText: '일정 제목을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 내용
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        labelText: '내용',
                        hintText: '일정 내용을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 카테고리
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: '카테고리',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MEETING', child: Text('회의')),
                        DropdownMenuItem(value: 'EVENT', child: Text('행사')),
                        DropdownMenuItem(value: 'TRAINING', child: Text('교육')),
                        DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedCategory = value ?? 'MEETING';
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 장소
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: '장소',
                        hintText: '장소를 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 담당자 (참석자와 별개 — 일정 책임자)
                    DropdownButtonFormField<int?>(
                      initialValue: selectedManagerId,
                      decoration: InputDecoration(
                        labelText: '담당자',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('미지정')),
                        ..._memberOptions.map(
                          (m) => DropdownMenuItem<int?>(
                            value: m['id'] as int,
                            child: Text(m['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedManagerId = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 종일 여부
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '종일',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: isAllDay,
                          onChanged: (value) {
                            setModalState(() {
                              isAllDay = value;
                            });
                          },
                          activeTrackColor: AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),

                    // 시작일
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '시작일',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 종료일
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() {
                            endDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '종료일',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 시간 선택 (종일이 아닌 경우)
                    if (!isAllDay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '시작 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                  ),
                                  suffixIcon: const Icon(Icons.access_time),
                                ),
                                child: Text(
                                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '종료 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                  ),
                                  suffixIcon: const Icon(Icons.access_time),
                                ),
                                child: Text(
                                  '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                    ],

                    // 알림 발송
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '알림 발송',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: sendNotification,
                          onChanged: (value) {
                            setModalState(() {
                              sendNotification = value;
                            });
                          },
                          activeTrackColor: AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 등록 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('제목을 입력해주세요')),
                            );
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final scheduleProvider = context.read<ScheduleProvider>();
                          final companyId = authProvider.currentUser?.company?.id ?? '1';

                          final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
                          final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

                          final scheduleData = <String, dynamic>{
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim().isEmpty
                                ? null
                                : contentController.text.trim(),
                            'category': selectedCategory,
                            'location': locationController.text.trim().isEmpty
                                ? null
                                : locationController.text.trim(),
                            'startDate': startDateStr,
                            'endDate': endDateStr,
                            'isAllDay': isAllDay,
                            'sendNotification': sendNotification,
                            if (selectedManagerId != null) 'managerId': selectedManagerId,
                          };

                          if (!isAllDay) {
                            scheduleData['startTime'] =
                                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                            scheduleData['endTime'] =
                                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                          }

                          Navigator.pop(context);

                          final success = await scheduleProvider.createSchedule(
                            companyId: companyId.toString(),
                            scheduleData: scheduleData,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? '일정이 등록되었습니다' : '일정 등록에 실패했습니다'),
                                backgroundColor: success
                                    ? AppSemanticColors.statusSuccessIcon
                                    : AppSemanticColors.statusErrorIcon,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppSemanticColors.interactivePrimaryDefault,
                          foregroundColor: AppSemanticColors.textInverse,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                        ),
                        child: Text(
                          '등록',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppSemanticColors.textInverse,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final labelColor = schedule.label != null
        ? Color(int.parse(schedule.label!.color.replaceFirst('#', '0xFF')))
        : AppSemanticColors.statusInfoIcon;

    return GestureDetector(
      onTap: () => _showScheduleDetailSheet(schedule),
      onLongPress: () => _showDeleteScheduleDialog(schedule),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: AppSemanticColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border(
            left: BorderSide(
              color: labelColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (schedule.isCompleted) ...[
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppSemanticColors.statusSuccessIcon,
                        ),
                        const SizedBox(width: AppSpacing.space1),
                      ],
                      Expanded(
                        child: Text(
                          schedule.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            decoration: schedule.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space2,
                          vertical: AppSpacing.space0_5,
                        ),
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppBorderRadius.base),
                        ),
                        child: Text(
                          schedule.categoryText,
                          style: AppTypography.caption.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (schedule.timeText.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.space2),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppSemanticColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.space1),
                        Text(
                          schedule.timeText,
                          style: AppTypography.caption.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((schedule.authorName != null && schedule.authorName!.isNotEmpty) ||
                      schedule.managerName != null ||
                      schedule.taskTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.space1),
                      child: Wrap(
                        spacing: AppSpacing.space2,
                        children: [
                          if (schedule.managerName != null)
                            Text(
                              '담당: ${schedule.managerName}',
                              style: AppTypography.caption.copyWith(
                                color: AppSemanticColors.statusInfoIcon,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (schedule.taskTotal > 0)
                            Text(
                              '할 일 ${schedule.taskCompleted}/${schedule.taskTotal}',
                              style: AppTypography.caption.copyWith(
                                color: schedule.taskCompleted >= schedule.taskTotal
                                    ? AppSemanticColors.statusSuccessIcon
                                    : AppSemanticColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (schedule.authorName != null && schedule.authorName!.isNotEmpty)
                            Text(
                              '등록: ${schedule.authorName}',
                              style: AppTypography.caption.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showDeleteScheduleDialog(schedule),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 일정 상세: 수행완료 토글 + 할 일 관리 + 담당자/참석자
  void _showScheduleDetailSheet(Schedule schedule) {
    final taskController = TextEditingController();
    bool isCompleted = schedule.isCompleted;
    List<ScheduleTask> tasks = List.of(schedule.tasks);
    int? taskAssigneeId;
    bool isWorking = false;

    // 수행완료 권한: 담당자가 지정된 일정은 담당자 본인만,
    // 미지정 일정은 관리자/작성자만 (서버에서도 동일하게 강제)
    final currentUser = context.read<AuthProvider>().currentUser;
    final bool isAdminUser = currentUser?.role.toLowerCase() == 'admin';
    final int? myMemberId =
        isAdminUser ? null : int.tryParse(currentUser?.id ?? '');
    final bool canToggleCompletion = schedule.managerId != null
        ? (myMemberId != null && schedule.managerId == myMemberId)
        : (isAdminUser || (schedule.authorId != null && schedule.authorId == currentUser?.email));
    bool canCheckTask(ScheduleTask task) =>
        task.assigneeMemberId == null || task.assigneeMemberId == myMemberId;

    _loadMemberOptions();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshTasks() async {
              try {
                final response =
                    await ApiService().getScheduleTasks(scheduleId: schedule.id);
                final list = (response['tasks'] as List?) ?? [];
                setSheetState(() {
                  tasks = list
                      .whereType<Map>()
                      .map((t) => ScheduleTask.fromJson(Map<String, dynamic>.from(t)))
                      .toList();
                });
              } catch (e) {
                debugPrint('할 일 목록 갱신 실패: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            schedule.title,
                            style: AppTypography.heading5.copyWith(
                              color: AppSemanticColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppSemanticColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),

                    // 기본 정보
                    Wrap(
                      spacing: AppSpacing.space3,
                      runSpacing: AppSpacing.space1,
                      children: [
                        Text('분류: ${schedule.categoryText}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppSemanticColors.textSecondary)),
                        if (schedule.timeText.isNotEmpty)
                          Text('시간: ${schedule.timeText}',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppSemanticColors.textSecondary)),
                        if (schedule.managerName != null)
                          Text('담당자: ${schedule.managerName}',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.statusInfoIcon,
                                  fontWeight: FontWeight.w600)),
                        if (schedule.location != null && schedule.location!.isNotEmpty)
                          Text('장소: ${schedule.location}',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppSemanticColors.textSecondary)),
                      ],
                    ),
                    if (schedule.content != null && schedule.content!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Text(schedule.content!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppSemanticColors.textPrimary)),
                    ],
                    const SizedBox(height: AppSpacing.space4),

                    // 수행완료 토글
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3,
                        vertical: AppSpacing.space1,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppSemanticColors.statusSuccessBackground
                            : AppSemanticColors.backgroundTertiary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isCompleted
                                  ? '수행완료${schedule.completedByName != null ? ' · ${schedule.completedByName}' : ''}'
                                  : (!canToggleCompletion && schedule.managerName != null
                                      ? '진행 전/진행 중 · 담당자(${schedule.managerName})만 완료 처리'
                                      : '진행 전/진행 중'),
                              style: AppTypography.bodySmall.copyWith(
                                color: isCompleted
                                    ? AppSemanticColors.statusSuccessIcon
                                    : AppSemanticColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: isCompleted,
                            activeThumbColor: AppSemanticColors.statusSuccessIcon,
                            onChanged: (isWorking || !canToggleCompletion)
                                ? null
                                : (value) async {
                                    setSheetState(() => isWorking = true);
                                    try {
                                      await ApiService().updateScheduleCompletion(
                                        scheduleId: schedule.id,
                                        completed: value,
                                      );
                                      setSheetState(() => isCompleted = value);
                                      _loadSchedules();
                                    } catch (e) {
                                      debugPrint('수행완료 변경 실패: $e');
                                    } finally {
                                      setSheetState(() => isWorking = false);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 할 일 목록
                    Text(
                      '할 일 (${tasks.where((t) => t.isCompleted).length}/${tasks.length})',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    if (tasks.isEmpty)
                      Text('등록된 할 일이 없습니다.',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppSemanticColors.textTertiary)),
                    ...tasks.map(
                      (task) => Row(
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            activeColor: AppSemanticColors.statusSuccessIcon,
                            onChanged: !canCheckTask(task)
                                ? null
                                : (value) async {
                              try {
                                await ApiService().updateScheduleTaskCompletion(
                                  scheduleId: schedule.id,
                                  taskId: task.id,
                                  completed: value ?? false,
                                );
                                await refreshTasks();
                                _loadSchedules();
                              } catch (e) {
                                debugPrint('할 일 완료 변경 실패: $e');
                              }
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.content,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.assigneeName != null)
                                  Text(
                                    '담당: ${task.assigneeName}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppSemanticColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: AppSemanticColors.textTertiary),
                            onPressed: () async {
                              try {
                                await ApiService().deleteScheduleTask(
                                  scheduleId: schedule.id,
                                  taskId: task.id,
                                );
                                await refreshTasks();
                                _loadSchedules();
                              } catch (e) {
                                debugPrint('할 일 삭제 실패: $e');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),

                    // 할 일 추가
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: taskController,
                            decoration: InputDecoration(
                              hintText: '할 일 추가...',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<int?>(
                            initialValue: taskAssigneeId,
                            isDense: true,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              ),
                            ),
                            hint: const Text('담당', style: TextStyle(fontSize: 12)),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('미지정', style: TextStyle(fontSize: 12))),
                              ..._memberOptions.map(
                                (m) => DropdownMenuItem<int?>(
                                  value: m['id'] as int,
                                  child: Text(m['name'] as String,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => taskAssigneeId = value),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle,
                              color: AppSemanticColors.interactivePrimaryDefault),
                          onPressed: () async {
                            final content = taskController.text.trim();
                            if (content.isEmpty) return;
                            try {
                              await ApiService().createScheduleTask(
                                scheduleId: schedule.id,
                                content: content,
                                assigneeMemberId: taskAssigneeId,
                              );
                              taskController.clear();
                              await refreshTasks();
                              _loadSchedules();
                            } catch (e) {
                              debugPrint('할 일 추가 실패: $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteScheduleDialog(Schedule schedule) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        ),
        title: Text(
          '일정 삭제',
          style: AppTypography.heading6.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '\'${schedule.title}\' 일정을 삭제하시겠습니까?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              '취소',
              style: AppTypography.labelLarge.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider = context.read<AuthProvider>();
              final scheduleProvider = context.read<ScheduleProvider>();
              final companyId = authProvider.currentUser?.company?.id ?? '1';

              final success = await scheduleProvider.deleteSchedule(
                scheduleId: schedule.id,
                companyId: companyId.toString(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '일정이 삭제되었습니다' : '일정 삭제에 실패했습니다'),
                    backgroundColor: success
                        ? AppSemanticColors.statusSuccessIcon
                        : AppSemanticColors.statusErrorIcon,
                  ),
                );
              }
            },
            child: Text(
              '삭제',
              style: AppTypography.labelLarge.copyWith(
                color: AppSemanticColors.statusErrorIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
