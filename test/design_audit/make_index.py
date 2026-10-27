#!/usr/bin/env python3
"""렌더 결과 폴더의 INDEX.md 를 만든다.  사용: make_index.py <png폴더>"""
import os, re, sys, glob
out = sys.argv[1]
D = {
 '01-home-today-dialog': ('MainScreen > HomeScreen + TodayScheduleDialog', '부팅 직후 홈 위에 뜨는 "오늘 일정 N건" 팝업'),
 '02-home': ('MainScreen(하단 탭 5개) > HomeScreen', '홈: 공지·전자결재·업무진행도 카드, 알림 뱃지 3'),
 '03-home-scrolled': ('HomeScreen', '홈 아래쪽: 업무진행도·오늘 일정·오늘 휴무'),
 '04-notifications-sheet': ('NotificationBell 알림 시트', '알림 목록(결재·업무·채팅·휴무·공지·일정·시스템)'),
 '05-tab-chat': ('ChatRoomListScreen (탭)', '채팅 탭 > 대화: 고정방·안읽음 뱃지·사진/파일 미리보기'),
 '05b-tab-chat-staff': ('ChatRoomListScreen (직원 탭)', '직원 목록 + 접속 상태'),
 '06-tab-calendar': ('CalendarScreen > 근무조정', '10월 휴무 달력(점 표시)·직무 필터·FAB'),
 '06b-calendar-day-selected': ('CalendarScreen', '휴무 달력에서 10/28 선택 — 그날 휴무자 목록'),
 '06c-calendar-fab-menu': ('CalendarScreen FAB', '관리자: "관리자 기능" 시트(휴무 추가/한도 설정) · 직원: 휴무 신청 창'),
 '06d-vacation-request-dialog': ('VacationRequestDialog / AdminVacationAddDialog', '휴무 신청(직원)·휴무 추가(관리자) 창'),
 '06e-calendar-monthly-schedule': ('CalendarScreen > 월간일정', '일정 달력(점 표시)'),
 '06f-calendar-schedule-day': ('CalendarScreen > 월간일정', '10/27 일정 3건 카드'),
 '07-tab-approval': ('ApprovalHubScreen (탭)', '전자결재 탭: 직원=결재 신청 현황, 관리자=내 차례 배너·결재 관리'),
 '08-tab-menu': ('MenuScreen (탭)', '전체 탭 맨 위'),
 '09-tab-menu-scrolled': ('MenuScreen', '전체 탭 스크롤: 기관 관리(관리자만)·계정·로그아웃'),
 '10-profile': ('ProfileScreen', '프로필'),
 '11-text-size': ('TextSizeSettingsScreen', '글자 크기(보통 선택)'),
 '12-notification-settings': ('NotificationSettingsScreen', '푸시 알림 켜짐'),
 '20-my-vacation': ('MyVacationScreen', '내 휴무: 신청 현황과 승인된 휴무'),
 '22-work-task-list': ('WorkTaskListScreen', '업무진행도 목록(진행 4·끝낸 1)'),
 '23-work-task-edit-sheet': ('WorkTaskEditSheet', '업무 수정 시트(담당자·기한·중요도·수행도)'),
 '24-work-task-new-sheet': ('WorkTaskEditSheet', '업무 등록 시트(빈 상태)'),
 '30-chat-room-team': ('ChatRoomScreen', '채팅방: 텍스트·사진·내 말풍선·읽음'),
 '31-chat-room-photo': ('ChatRoomScreen', '1:1 채팅방: 사진 메시지'),
 '32-chat-room-info': ('ChatRoomInfoScreen', '채팅방 정보: 고정 토글·참가자 13명'),
 '33-chat-create-room': ('CreateChatRoomScreen', '새 채팅방'),
 '40-notice-list': ('NoticeListScreen', '공지 목록(고정·긴급·일반)'),
 '41-notice-detail': ('NoticeDetailScreen', '공지 상세: 첨부·읽은 사람·댓글'),
 '50-approval-hub': ('ApprovalHubScreen', '전자결재 허브(단독 화면) — 결재 신청/관리 탭'),
 '51-approval-list': ('ApprovalListScreen', '내 결재 목록(관리자는 처음에 빈 상태로 보임 — 보고서 참고)'),
 '51b-approval-list-after-pull-refresh': ('ApprovalListScreen', '당겨서 새로고침(refresh:true) 뒤 목록'),
 '52-approval-detail-pending': ('ApprovalDetailScreen + OfficialDocumentView', '대기 중 문서·공문 보기·결재 의견'),
 '53-approval-detail-approved': ('ApprovalDetailScreen', '승인된 문서'),
 '54-approval-detail-rejected': ('ApprovalDetailScreen', '반려된 문서(반려 사유)'),
 '55-approval-form': ('ApprovalFormScreen', '결재 요청 작성(양식 미선택)'),
 '55b-approval-form-template-selected': ('ApprovalFormScreen', '지출결의서 양식 선택 후 온라인 양식'),
 '56-approval-template-list': ('ApprovalTemplateListScreen', '양식 선택 목록(분류 탭)'),
 '57-approval-template-preview': ('ApprovalTemplatePreviewScreen', '양식 미리보기'),
 '58-signature-manage': ('SignatureManageScreen', '결재 서명 관리(서명 없음)'),
 '60-elder-list': ('ElderCareListScreen', '어르신 정보 목록'),
 '61-elder-detail': ('ElderCareDetailScreen', '어르신 케어 상세'),
 '62-meeting-minutes-list': ('MeetingMinutesListScreen', '회의록 목록'),
 '63-meeting-minutes-detail': ('MeetingMinutesDetailScreen', '회의록 상세·참석자 서명'),
 '70-company-library': ('CompanyLibraryScreen', '기관 자료실'),
 '71-plaza': ('PlazaScreen > 요양 소식', '커뮤니티: 요양 소식'),
 '71b-plaza-board': ('PlazaScreen > 게시판', '커뮤니티: 게시판 목록'),
 '71c-plaza-library': ('PlazaScreen > 자료실', '커뮤니티: 자료실'),
 '72-plaza-post-detail': ('PlazaPostDetailScreen', '게시글 상세·댓글'),
 '73-voice-box': ('VoiceBoxScreen', '고충·건의함(내 제출 내역)'),
 '74-voice-box-write': ('VoiceBoxWriteScreen', '고충·건의 작성'),
 '75-ai-post-writer': ('AiPostWriterScreen', 'AI 글쓰기'),
 '80-notice-form-new': ('AdminNoticeFormScreen', '공지 작성'),
 '81-notice-form-edit': ('AdminNoticeFormScreen', '공지 수정'),
 '82-user-management': ('AdminUserManagementScreen', '종사자 관리: 승인 대기'),
 '83-vacation-management': ('AdminVacationManagementScreen', '휴무 관리(승인 대기)'),
 '84-vacation-limits': ('AdminVacationLimitsSettingScreen', '휴무 제한 설정'),
 '85-approval-template-admin': ('AdminApprovalTemplateScreen', '결재 양식 관리'),
 '86-company-settings': ('AdminCompanySettingsScreen', '회사 정보·구독'),
 '87-voice-box-admin': ('AdminVoiceBoxScreen', '고충·건의함 관리'),
 '88-payment-admin': ('AdminPaymentScreen', '구독 결제(Basic 활성)'),
 '89-dispatch': ('DispatchScreen', '배차관리 오늘'),
 '90-subscription-check': ('SubscriptionCheckScreen', '요금제 선택'),
 '95-dialog-confirm': ('AppDialog.showConfirm', '확인 다이얼로그(홈 위)'),
 '96-dialog-alert': ('AppDialog.showAlert', '알림 다이얼로그'),
 '97-action-sheet': ('showAppActionSheet', '액션 시트'),
 '01-login-employee': ('LoginScreen', '로그인 — 직원'),
 '02-login-admin': ('LoginScreen', '로그인 — 관리자'),
 '03-register-top': ('RegisterScreen', '회원가입 맨 위: 절차 안내'),
 '04-register-employee-code': ('RegisterScreen', '회원가입 1단계 — 직원(회사 코드)'),
 '05-register-employee-code-bottom': ('RegisterScreen', '회원가입 아래쪽: 약관 동의'),
 '06-register-admin': ('RegisterScreen', '회원가입 — 관리자(회사명·주소)'),
 '08-update-dialog': ('UpdateDialog', '앱 업데이트 안내'),
}
rows = []
for f in sorted(glob.glob(os.path.join(out, '*.png'))):
    n = os.path.basename(f)[:-4]
    m = re.match(r'(emp|adm|common)-(.+)', n)
    key = m.group(2) if m else n
    cls, st = D.get(key, ('?', '?'))
    rows.append(f'| {n}.png | {cls} | {st} |')
with open(os.path.join(out, 'INDEX.md'), 'w') as fh:
    fh.write('# 앱 화면 캡처 목록\n\n390x844 논리 px @2x (780x1688). 햇살주간보호센터 가상 데이터, 날짜는 렌더 날 기준.\n\n| 파일 | 화면/위젯 | 보여주는 상태 |\n|---|---|---|\n')
    fh.write('\n'.join(rows) + '\n')
print(len(rows), 'rows')
