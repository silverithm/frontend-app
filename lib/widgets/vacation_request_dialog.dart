import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vacation_request.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

class VacationRequestDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback? onRequestSubmitted;

  const VacationRequestDialog({
    super.key,
    required this.selectedDate,
    this.onRequestSubmitted,
  });

  @override
  State<VacationRequestDialog> createState() => _VacationRequestDialogState();
}

class _VacationRequestDialogState extends State<VacationRequestDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  VacationType _selectedType = VacationType.personal;
  VacationDuration _selectedDuration = VacationDuration.fullDay;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late AnimationController _submitAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _submitAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _animationController.dispose();
    _submitAnimationController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final vacationProvider = context.read<VacationProvider>();

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그인이 필요합니다'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _submitAnimationController.forward();

    try {
      final success = await vacationProvider.createVacationRequest(
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.name,
        userRole: authProvider.currentUser!.role,
        date: widget.selectedDate,
        type: _selectedType,
        duration: _selectedDuration,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
        password: '',
        companyId: authProvider.currentUser!.company?.id ?? '1',
      );

      if (success && mounted) {
        // Analytics 휴무 신청 이벤트 기록
        await AnalyticsService().logVacationRequest(
          vacationType: _selectedType.toString().split('.').last,
          startDate: widget.selectedDate.toIso8601String().split('T')[0],
          endDate: widget.selectedDate.toIso8601String().split('T')[0],
        );

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_getDurationDisplayText(_selectedDuration)} 신청이 완료되었습니다',
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        widget.onRequestSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 실패: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _submitAnimationController.reverse();
      }
    }
  }

  String _formatSelectedDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  String _getDurationDisplayText(VacationDuration duration) {
    switch (duration) {
      case VacationDuration.fullDay:
        return '연차';
      case VacationDuration.halfDayAm:
        return '오전 반차';
      case VacationDuration.halfDayPm:
        return '오후 반차';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade300.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.event_note,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '휴무 신청',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 선택된 날짜 표시
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue.shade100, Colors.blue.shade50],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '선택된 날짜',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatSelectedDate(widget.selectedDate),
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 폼
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 휴무 기간 선택 (연차/반차)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100.withOpacity(
                                      0.5,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '휴무 기간',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                  ),
                                  const SizedBox(height: 12),

                                  // 한 줄로 3개 버튼 배치
                                  Row(
                                    children: [
                                      // 연차
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient:
                                                _selectedDuration ==
                                                    VacationDuration.fullDay
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.blue.shade50,
                                                      Colors.blue.shade100,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                _selectedDuration !=
                                                    VacationDuration.fullDay
                                                ? Colors.grey.shade50
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedDuration ==
                                                      VacationDuration.fullDay
                                                  ? Colors.blue.shade300
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedDuration =
                                                    VacationDuration.fullDay;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '연차',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                    color:
                                                        _selectedDuration ==
                                                            VacationDuration
                                                                .fullDay
                                                        ? Colors.blue.shade800
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // 오전 반차
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient:
                                                _selectedDuration ==
                                                    VacationDuration.halfDayAm
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.orange.shade50,
                                                      Colors.orange.shade100,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                _selectedDuration !=
                                                    VacationDuration.halfDayAm
                                                ? Colors.grey.shade50
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedDuration ==
                                                      VacationDuration.halfDayAm
                                                  ? Colors.orange.shade300
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedDuration =
                                                    VacationDuration.halfDayAm;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '오전\n반차',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                    height: 1.2,
                                                    color:
                                                        _selectedDuration ==
                                                            VacationDuration
                                                                .halfDayAm
                                                        ? Colors.orange.shade800
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // 오후 반차
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient:
                                                _selectedDuration ==
                                                    VacationDuration.halfDayPm
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.purple.shade50,
                                                      Colors.purple.shade100,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                _selectedDuration !=
                                                    VacationDuration.halfDayPm
                                                ? Colors.grey.shade50
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedDuration ==
                                                      VacationDuration.halfDayPm
                                                  ? Colors.purple.shade300
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedDuration =
                                                    VacationDuration.halfDayPm;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '오후\n반차',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                    height: 1.2,
                                                    color:
                                                        _selectedDuration ==
                                                            VacationDuration
                                                                .halfDayPm
                                                        ? Colors.purple.shade800
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 휴무 유형 선택 (한 줄로 변경)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100.withOpacity(
                                      0.5,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '휴무 유형',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                  ),
                                  const SizedBox(height: 12),

                                  // 한 줄로 배치
                                  Row(
                                    children: [
                                      // 일반 휴무
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient:
                                                _selectedType ==
                                                    VacationType.personal
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.blue.shade50,
                                                      Colors.blue.shade100,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                _selectedType !=
                                                    VacationType.personal
                                                ? Colors.grey.shade50
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedType ==
                                                      VacationType.personal
                                                  ? Colors.blue.shade300
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedType =
                                                    VacationType.personal;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 8,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '일반',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color:
                                                        _selectedType ==
                                                            VacationType
                                                                .personal
                                                        ? Colors.blue.shade800
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // 필수 휴무
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient:
                                                _selectedType ==
                                                    VacationType.mandatory
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.red.shade50,
                                                      Colors.red.shade100,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                _selectedType !=
                                                    VacationType.mandatory
                                                ? Colors.grey.shade50
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _selectedType ==
                                                      VacationType.mandatory
                                                  ? Colors.red.shade300
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedType =
                                                    VacationType.mandatory;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 8,
                                                  ),
                                              child: Center(
                                                child: Text(
                                                  '필수',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color:
                                                        _selectedType ==
                                                            VacationType
                                                                .mandatory
                                                        ? Colors.red.shade800
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // 사유 입력 (더 크게)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100.withOpacity(
                                      0.5,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '휴무 사유',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                              fontSize: 16,
                                            ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _selectedType ==
                                                  VacationType.mandatory
                                              ? Colors.red.shade100
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _selectedType ==
                                                  VacationType.mandatory
                                              ? '필수'
                                              : '선택사항',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                _selectedType ==
                                                    VacationType.mandatory
                                                ? Colors.red.shade600
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _reasonController,
                                    maxLines: 6,
                                    maxLength: 200,
                                    validator: (value) {
                                      if (_selectedType ==
                                              VacationType.mandatory &&
                                          (value == null ||
                                              value.trim().isEmpty)) {
                                        return '필수 휴무는 사유를 반드시 입력해주세요';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText:
                                          _selectedType ==
                                              VacationType.mandatory
                                          ? '필수 휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 정기 교육 참석\n• 건강검진\n• 회사 행사 등'
                                          : '휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 개인 사정\n• 병원 진료\n• 가족 행사 등',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color:
                                              _selectedType ==
                                                  VacationType.mandatory
                                              ? Colors.red.shade400
                                              : Colors.blue.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color:
                                              _selectedType ==
                                                  VacationType.mandatory
                                              ? Colors.red.shade200
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.red.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.red.shade600,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor:
                                          _selectedType ==
                                              VacationType.mandatory
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(20),
                                      counterStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 제출 버튼
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                    Colors.blue.shade800,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade300.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '신청 중...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '휴무 신청하기',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
