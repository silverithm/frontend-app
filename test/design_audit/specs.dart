// 화면 캡처 목록. 두 역할이 공통으로 보는 화면은 commonSpecs, 역할별은 empSpecs / admSpecs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/approval_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/models/elder_care_profile.dart';
import 'package:frontend_app/models/notice.dart';
import 'package:frontend_app/models/subscription.dart';
import 'package:frontend_app/screens/admin_approval_template_screen.dart';
import 'package:frontend_app/screens/admin_company_settings_screen.dart';
import 'package:frontend_app/screens/admin_notice_form_screen.dart';
import 'package:frontend_app/screens/admin_payment_screen.dart';
import 'package:frontend_app/screens/admin_user_management_screen.dart';
import 'package:frontend_app/screens/admin_vacation_limits_setting_screen.dart';
import 'package:frontend_app/screens/admin_vacation_management_screen.dart';
import 'package:frontend_app/screens/admin_voice_box_screen.dart';
import 'package:frontend_app/screens/ai_post_writer_screen.dart';
import 'package:frontend_app/screens/approval_detail_screen.dart';
import 'package:frontend_app/screens/approval_form_screen.dart';
import 'package:frontend_app/screens/approval_hub_screen.dart';
import 'package:frontend_app/screens/approval_list_screen.dart';
import 'package:frontend_app/screens/approval_template_list_screen.dart';
import 'package:frontend_app/screens/approval_template_preview_screen.dart';
import 'package:frontend_app/screens/chat_room_info_screen.dart';
import 'package:frontend_app/screens/chat_room_screen.dart';
import 'package:frontend_app/screens/company_library_screen.dart';
import 'package:frontend_app/screens/create_chat_room_screen.dart';
import 'package:frontend_app/screens/dispatch_screen.dart';
import 'package:frontend_app/screens/elder_care_detail_screen.dart';
import 'package:frontend_app/screens/elder_care_list_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_detail_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_list_screen.dart';
import 'package:frontend_app/screens/my_vacation_screen.dart';
import 'package:frontend_app/screens/notice_detail_screen.dart';
import 'package:frontend_app/screens/notice_list_screen.dart';
import 'package:frontend_app/screens/notification_settings_screen.dart';
import 'package:frontend_app/screens/plaza_post_detail_screen.dart';
import 'package:frontend_app/screens/plaza_screen.dart';
import 'package:frontend_app/screens/profile_screen.dart';
import 'package:frontend_app/screens/signature_manage_screen.dart';
import 'package:frontend_app/screens/subscription_check_screen.dart';
import 'package:frontend_app/screens/text_size_settings_screen.dart';
import 'package:frontend_app/screens/voice_box_screen.dart';
import 'package:frontend_app/screens/voice_box_write_screen.dart';
import 'package:frontend_app/screens/work_task_list_screen.dart';
import 'package:frontend_app/widgets/common/app_action_sheet.dart';
import 'package:frontend_app/widgets/common/app_dialog.dart';

import 'fixtures.dart';
import 'fx_chat.dart' as chat;
import 'fx_docs.dart' as docs;
import 'fx_admin.dart' as adm;
import 'harness.dart';

/// 하단 탭 이름
Future<void> tapTab(AuditApp a, String label) async {
  final f = find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label));
  await a.tester.tap(f.last, warnIfMissed: false);
  await a.settle(seconds: 2.5);
}

Future<void> tapText(AuditApp a, String text, {int index = 0, double wait = 1.5}) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) throw 'text not found: $text';
  await a.tester.tap(f.at(index.clamp(0, f.evaluate().length - 1)), warnIfMissed: false);
  await a.settle(seconds: wait);
}

/// 하단 탭 + 홈 팝업 + 알림 시트 등 "셸" 캡처
Future<void> shellSpecs(AuditApp a, String r) async {
  final tester = a.tester;
  Future<void> step(String name, Future<void> Function() fn) async {
    currentShot = name;
    try {
      await fn();
    } catch (e, st) {
      renderFailed[name] = '$e\n$st';
    }
    a.flushFlutterErrors(name);
  }

  await step('$r-01-home-today-dialog', () async {
    await a.shot('$r-01-home-today-dialog'); // 부팅 직후 '오늘 일정' 팝업
  });
  await step('$r-02-home', () async {
    await tapText(a, '닫기');
    await a.shot('$r-02-home');
  });
  await step('$r-03-home-scrolled', () async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700), warnIfMissed: false);
    await a.settle(seconds: 1);
    await a.shot('$r-03-home-scrolled');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1400), warnIfMissed: false);
    await a.settle(seconds: 0.5);
  });
  await step('$r-04-notifications-sheet', () async {
    final bell = find.byTooltip('알림');
    final icon = bell.evaluate().isNotEmpty ? bell : find.byIcon(Icons.notifications_outlined);
    await tester.tap(icon.first, warnIfMissed: false);
    await a.settle(seconds: 2);
    await a.shot('$r-04-notifications-sheet');
    await a.tester.tapAt(const Offset(195, 60));
    await a.settle(seconds: 0.8);
    if (find.text('알림').evaluate().isNotEmpty) {
      a.nav.maybePop();
      await a.settle(seconds: 0.8);
    }
  });
  await step('$r-05-tab-chat', () async {
    await tapTab(a, '채팅');
    await a.shot('$r-05-tab-chat');
  });
  await step('$r-05b-tab-chat-staff', () async {
    await tapText(a, '직원', wait: 2);
    await a.shot('$r-05b-tab-chat-staff');
    await tapText(a, '대화', wait: 1);
  });
  await step('$r-06-tab-calendar', () async {
    await tapTab(a, '일정');
    await a.shot('$r-06-tab-calendar');
  });
  await step('$r-06b-calendar-day-selected', () async {
    await tapText(a, '28', index: 1, wait: 1.5);
    await a.tester.drag(find.byType(Scrollable).first, const Offset(0, -450), warnIfMissed: false);
    await a.settle(seconds: 1);
    await a.shot('$r-06b-calendar-day-selected');
    await a.tester.drag(find.byType(Scrollable).first, const Offset(0, 900), warnIfMissed: false);
    await a.settle(seconds: 0.5);
  });
  await step('$r-06c-calendar-fab-menu', () async {
    final fab = find.byType(FloatingActionButton);
    await a.tester.tap(fab.first, warnIfMissed: false);
    await a.settle(seconds: 2);
    await a.shot('$r-06c-calendar-fab-menu'); // 직원은 이 단계가 곧 신청 창
  });
  await step('$r-06d-vacation-request-dialog', () async {
    // 관리자는 FAB 메뉴에서 '휴무 추가', 직원은 FAB 이 곧바로 신청 창을 연다(아래 빈 줄 없음)
    if (find.text('휴무 추가').evaluate().isNotEmpty) {
      await tapText(a, '휴무 추가', wait: 2);
    }
    await a.shot('$r-06d-vacation-request-dialog');
    await a.popToRoot();
    a.nav.maybePop();
    await a.settle(seconds: 0.8);
  });
  await step('$r-06e-calendar-monthly-schedule', () async {
    if (find.text('월간일정').evaluate().isEmpty) {
      await a.tester.tapAt(const Offset(195, 400));
      await a.settle(seconds: 0.8);
    }
    await tapText(a, '월간일정', wait: 2.5);
    await a.shot('$r-06e-calendar-monthly-schedule');
  });
  await step('$r-06f-calendar-schedule-day', () async {
    await tapText(a, '27', wait: 1.5);
    await a.tester.drag(find.byType(Scrollable).first, const Offset(0, -450), warnIfMissed: false);
    await a.settle(seconds: 1);
    await a.shot('$r-06f-calendar-schedule-day');
  });
  await step('$r-07-tab-approval', () async {
    await tapTab(a, '전자결재');
    await a.shot('$r-07-tab-approval');
  });
  await step('$r-08-tab-menu', () async {
    await tapTab(a, '전체');
    await a.shot('$r-08-tab-menu');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900), warnIfMissed: false);
    await a.settle(seconds: 1);
    await a.shot('$r-09-tab-menu-scrolled');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 1800), warnIfMissed: false);
    await a.settle(seconds: 0.5);
  });
  await tapTab(a, '홈');
}

/// 화면 푸시 캡처 한 줄
Future<void> pushShot(AuditApp a, String name, Widget Function() build, {double wait = 2.5, Future<void> Function()? after}) async {
  await a.capture(name, build, wait: wait, after: after);
  a.flushFlutterErrors(name);
}

Future<void> commonSpecs(AuditApp a, String r) async {
  final role = FixtureRouter.role;
  final approvalsJson = docs.approvals();

  // 계정
  await pushShot(a, '$r-10-profile', () => const ProfileScreen());
  await pushShot(a, '$r-11-text-size', () => const TextSizeSettingsScreen());
  await pushShot(a, '$r-12-notification-settings', () => const NotificationSettingsScreen());

  // 휴무·업무
  await pushShot(a, '$r-20-my-vacation', () => const MyVacationScreen());
  await pushShot(a, '$r-22-work-task-list', () => const WorkTaskListScreen());
  await pushShot(a, '$r-23-work-task-edit-sheet', () => const WorkTaskListScreen(), after: () async {
    // 첫 업무를 눌러 수정(또는 읽기 전용) 시트를 연다
    await tapText(a, '10월 보호자 간담회 안내문 발송', wait: 2);
  });
  await pushShot(a, '$r-24-work-task-new-sheet', () => const WorkTaskListScreen(), after: () async {
    final add = find.byIcon(Icons.add);
    if (add.evaluate().isNotEmpty) {
      await a.tester.tap(add.first, warnIfMissed: false);
    } else {
      await tapText(a, '업무 등록');
    }
    await a.settle(seconds: 2);
  });

  // 채팅
  final rooms = chat.roomsForSpec();
  await pushShot(a, '$r-30-chat-room-team', () => ChatRoomScreen(room: ChatRoom.fromJson(rooms[3])), wait: 3);
  await pushShot(a, '$r-31-chat-room-photo', () => ChatRoomScreen(room: ChatRoom.fromJson(rooms[1])), wait: 3);
  await pushShot(a, '$r-32-chat-room-info', () => ChatRoomInfoScreen(room: ChatRoom.fromJson(rooms[0])), wait: 3);
  await pushShot(a, '$r-33-chat-create-room', () => const CreateChatRoomScreen());

  // 공지
  await pushShot(a, '$r-40-notice-list', () => const NoticeListScreen());
  await pushShot(a, '$r-41-notice-detail', () => const NoticeDetailScreen(noticeId: 1), wait: 3);

  // 결재
  await pushShot(a, '$r-50-approval-hub', () => const ApprovalHubScreen());
  await pushShot(a, '$r-51-approval-list', () => const ApprovalListScreen());
  await pushShot(a, '$r-51b-approval-list-after-pull-refresh', () => const ApprovalListScreen(), after: () async {
    // 당겨서 새로고침과 같은 경로(refresh: true)
    final ctx = a.tester.element(find.byType(ApprovalListScreen));
    final uid = ctx.read<AuthProvider>().currentUser!.id;
    await ctx.read<ApprovalProvider>().loadMyApprovalRequests(requesterId: uid, refresh: true);
    await a.settle(seconds: 2);
  });
  await pushShot(a, '$r-52-approval-detail-pending', () => ApprovalDetailScreen(approval: ApprovalRequest.fromJson(approvalsJson[1])), wait: 3);
  await pushShot(a, '$r-53-approval-detail-approved', () => ApprovalDetailScreen(approval: ApprovalRequest.fromJson(approvalsJson[2])), wait: 3);
  await pushShot(a, '$r-54-approval-detail-rejected', () => ApprovalDetailScreen(approval: ApprovalRequest.fromJson(approvalsJson[3])), wait: 3);
  await pushShot(a, '$r-55-approval-form', () => const ApprovalFormScreen());
  await pushShot(a, '$r-55b-approval-form-template-selected', () => const ApprovalFormScreen(), after: () async {
    await tapText(a, '결재 양식을 선택하세요', wait: 2);
    await tapText(a, '지출결의서', wait: 2);
    if (find.text('이 양식으로 작성').evaluate().isNotEmpty) await tapText(a, '이 양식으로 작성', wait: 2);
  });
  final tpls = docs.templates().map(ApprovalTemplate.fromJson).toList();
  await pushShot(a, '$r-56-approval-template-list', () => ApprovalTemplateListScreen(templates: tpls.where((t) => t.isActive).toList()));
  await pushShot(a, '$r-57-approval-template-preview', () => ApprovalTemplatePreviewScreen(template: tpls[1]));
  await pushShot(a, '$r-58-signature-manage', () => const SignatureManageScreen());

  // 기관 정보 열람
  await pushShot(a, '$r-60-elder-list', () => const ElderCareListScreen());
  await pushShot(a, '$r-62-meeting-minutes-list', () => const MeetingMinutesListScreen());
  await pushShot(a, '$r-63-meeting-minutes-detail', () => const MeetingMinutesDetailScreen(minutesId: 2), wait: 3);
  await pushShot(a, '$r-70-company-library', () => const CompanyLibraryScreen());
  await pushShot(a, '$r-71-plaza', () => const PlazaScreen(), wait: 3);
  await pushShot(a, '$r-71b-plaza-board', () => const PlazaScreen(), wait: 3, after: () async {
    await tapText(a, '게시판', wait: 2.5);
  });
  await pushShot(a, '$r-71c-plaza-library', () => const PlazaScreen(), wait: 3, after: () async {
    await tapText(a, '자료실', wait: 2.5);
  });
  await pushShot(a, '$r-72-plaza-post-detail', () => const PlazaPostDetailScreen(postId: 1), wait: 3);
  await pushShot(a, '$r-73-voice-box', () => const VoiceBoxScreen());
  await pushShot(a, '$r-74-voice-box-write', () => const VoiceBoxWriteScreen());
  await pushShot(a, '$r-75-ai-post-writer', () => const AiPostWriterScreen());
  final elder = ElderInfo.fromJson(adm.elders().first);
  await pushShot(a, '$r-61-elder-detail', () => ElderCareDetailScreen(elder: elder), wait: 3);
  if (role == Role.emp) {} // 역할별 차이는 empSpecs/admSpecs
}

Future<void> admSpecs(AuditApp a, String r) async {
  final notice = Notice.fromJson(docs.notices().first);
  await pushShot(a, '$r-80-notice-form-new', () => const AdminNoticeFormScreen());
  await pushShot(a, '$r-81-notice-form-edit', () => AdminNoticeFormScreen(notice: notice));
  await pushShot(a, '$r-82-user-management', () => const AdminUserManagementScreen());
  await pushShot(a, '$r-83-vacation-management', () => const AdminVacationManagementScreen());
  await pushShot(a, '$r-84-vacation-limits', () => const AdminVacationLimitsSettingScreen());
  await pushShot(a, '$r-85-approval-template-admin', () => const AdminApprovalTemplateScreen());
  await pushShot(a, '$r-86-company-settings', () => const AdminCompanySettingsScreen());
  await pushShot(a, '$r-87-voice-box-admin', () => const AdminVoiceBoxScreen());
  await pushShot(a, '$r-88-payment-admin', () => const AdminPaymentScreen());
  await pushShot(a, '$r-89-dispatch', () => const DispatchScreen(), wait: 3.5);
  await pushShot(a, '$r-90-subscription-check', () => const SubscriptionCheckScreen(isAdmin: true));
}

Future<void> sheetSpecs(AuditApp a, String r) async {
  // 공용 다이얼로그/시트 — 대표 사용례
  Future<void> overlay(String name, Future<void> Function(BuildContext) open) async {
    currentShot = name;
    try {
      final ctx = a.tester.element(find.byType(Scaffold).first);
      open(ctx); // 닫힐 때까지 기다리지 않는다
      await a.settle(seconds: 1.5);
      await a.shot(name);
      a.nav.pop();
      await a.settle(seconds: 0.8);
    } catch (e, st) {
      renderFailed[name] = '$e\n$st';
    }
    a.flushFlutterErrors(name);
  }

  await overlay('$r-95-dialog-confirm', (c) => AppDialog.showConfirm(c, title: '결재 반려', message: '이 문서를 반려하시겠습니까? 반려 사유는 기안자에게 전달됩니다.', confirmText: '반려'));
  await overlay('$r-96-dialog-alert', (c) => AppDialog.showAlert(c, title: '저장 완료', message: '변경 내용이 저장되었습니다.'));
  await overlay('$r-97-action-sheet', (c) => showAppActionSheet(c, title: '메시지', actions: [
        AppSheetAction(icon: Icons.reply_rounded, label: '답장', onSelected: () {}),
        AppSheetAction(icon: Icons.copy_rounded, label: '복사', onSelected: () {}),
        AppSheetAction(icon: Icons.push_pin_outlined, label: '공지로 등록', onSelected: () {}),
        AppSheetAction(icon: Icons.delete_outline_rounded, label: '삭제', isDestructive: true, onSelected: () {}),
      ]));
}
