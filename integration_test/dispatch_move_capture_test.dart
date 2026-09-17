import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;
import 'package:frontend_app/widgets/chat/chat_image_viewer.dart';
import 'package:frontend_app/widgets/seed/seed_list_cell.dart';

/// "다른 차량으로 이동" 기능 + 배차/달력/설정/채팅 검색·이미지저장 실기기 검증 캡처.
/// 체험 계정(company 153)으로만 실행한다 — 아니면 즉시 멈춘다.
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/dispatch_move_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  Future<void> settle(WidgetTester tester, {double seconds = 3}) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> waitFor(WidgetTester tester, Finder finder, {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('[STEP] $name');
    await settle(tester, seconds: 1.5);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 4);
  }

  testWidgets('배차 이동·배차표·달력·설정복사·채팅검색·이미지저장 캡처', (tester) async {
    app.main();
    var step = 'start';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      debugPrint('[ERROR@$step] $text');
      if (!text.contains('overflowed')) original?.call(details);
    };

    // ===================== 로그인 =====================
    step = 'login';
    final either = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, seconds: 1);
    if (find.text('전자결재').evaluate().isEmpty) {
      final adminToggle = find.text('관리자');
      if (adminToggle.evaluate().isNotEmpty) {
        await tester.tap(adminToggle.first);
        await settle(tester, seconds: 1);
      }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.pump(const Duration(milliseconds: 300));
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, seconds: 1.5);
      await tester.ensureVisible(find.text('로그인').last);
      await settle(tester, seconds: 0.5);
      await tester.tap(find.text('로그인').last);
      await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 4);
    final isDemo = await waitFor(tester, find.textContaining('체험 관리자'), maxSeconds: 20);
    expect(isDemo, isTrue, reason: '체험 계정(체험 관리자)으로만 캡처한다 — company 153이 아니면 중단');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }

    // ===================== 배차관리 진입 =====================
    // IndexedStack이 모든 탭 화면을 동시에 빌드해 두므로 find.text('전체')가
    // 화면 밖(예: 캘린더의 휴무 필터 "전체" 칩) 위젯을 집을 수 있다.
    // 하단 네비게이션 바 안으로 범위를 좁혀 탭한다.
    step = 'dispatch_entry';
    final navMenuTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('전체'),
    );
    debugPrint('[INFO] 하단 네비 "전체" 매칭 개수: ${navMenuTab.evaluate().length}');
    await tester.tap(navMenuTab.last, warnIfMissed: false);
    // 캘린더 탭이 IndexedStack에 함께 떠 있어 휴무 목록을 반복 계산하며 프레임을
    // 많이 잡아먹는다 — 메뉴 화면 전환이 자리잡을 시간을 넉넉히 준다.
    await settle(tester, seconds: 5);
    // 진단용 — 배차관리가 왜 안 뜨는지 보려고 메뉴 화면 상태를 우선 찍는다
    final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
    debugPrint('[INFO] 메뉴 화면 텍스트: ${allTexts.join(" | ")}');
    final dispatchEntry = find.text('배차관리');
    // 메뉴는 ListView라 화면 밖 항목은 아직 안 그려져 있다 — 보일 때까지 끌어올린다
    for (var i = 0; i < 12 && dispatchEntry.evaluate().isEmpty; i++) {
      final scrollable = find.byType(Scrollable).last;
      await tester.drag(scrollable, const Offset(0, -350), warnIfMissed: false);
      await settle(tester, seconds: 0.8);
    }
    expect(await waitFor(tester, dispatchEntry, maxSeconds: 10), isTrue);
    await tester.ensureVisible(dispatchEntry.first);
    await settle(tester, seconds: 0.5);
    await tester.tap(dispatchEntry.first, warnIfMissed: false);
    await settle(tester, seconds: 4);

    // 01 배차표 — 헤더(탑승·전체·미배정) + 출결 섹션
    step = '01_board';
    await shot(tester, '01_board');

    // 02 어르신 칩 탭 → 바텀시트(결석/개인등원/개인하원/사유/다른 차량으로 이동)
    step = '02_elder_sheet';
    // 배차표 칩은 트리에서 출결 목록보다 앞에 있으므로 .first가 칩이다 (서옥자는 탑승 중)
    const elderName = '서옥자';
    final elderChip = find.text(elderName);
    final hasElder = elderChip.evaluate().isNotEmpty;
    Future<void> closeSheetIfOpen() async {
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 1.5);
      }
    }
    Future<void> toggleAbsentInSheet() async {
      // 시트 안의 첫 체크박스가 결석이다 (시트는 오버레이라 트리 마지막)
      final sheetCheckbox = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Checkbox),
      );
      await tester.tap(sheetCheckbox.first, warnIfMissed: false);
      await settle(tester, seconds: 2.5);
    }
    if (hasElder) {
      await tester.tap(elderChip.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      debugPrint('[INFO] 시트 열림: ${find.byType(BottomSheet).evaluate().isNotEmpty}');
      await shot(tester, '02_elder_sheet');

      // 03 결석 토글 → 헤더 인원 감소, 실패 스낵바 없음
      step = '03_toggle_absent';
      await toggleAbsentInSheet();
      final failSnack = find.textContaining('실패');
      debugPrint('[INFO] 결석 처리 후 실패 문구 노출: ${failSnack.evaluate().isNotEmpty}');
      await closeSheetIfOpen();
      await settle(tester, seconds: 1);
      await shot(tester, '03_after_absent_toggle');
      // 결석 되돌리기(체험 데이터 원복) — 새 디자인은 행이 남아 있으므로 다시 탭해 시트에서 푼다
      final rowAgain = find.text(elderName);
      if (rowAgain.evaluate().isNotEmpty) {
        await tester.ensureVisible(rowAgain.first);
        await settle(tester, seconds: 0.5);
        await tester.tap(rowAgain.first, warnIfMissed: false);
        await settle(tester, seconds: 2);
        if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          await toggleAbsentInSheet();
          await closeSheetIfOpen();
        }
      }
      // 목록 맨 위로
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500), warnIfMissed: false);
      await settle(tester, seconds: 1);
    } else {
      debugPrint('[WARN] $elderName 칩을 찾지 못해 02/03 캡처를 건너뜀');
    }

    // 04 미배정 칩 탭 → 이름들
    step = '04_unassigned';
    final unassignedChip = find.textContaining('미배정');
    if (unassignedChip.evaluate().isNotEmpty) {
      await tester.tap(unassignedChip.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      await shot(tester, '04_unassigned');
      await tester.binding.handlePopRoute();
      await settle(tester, seconds: 2);
    } else {
      debugPrint('[WARN] 미배정 칩이 없어 04 캡처를 건너뜀');
    }

    // 05/06 다른 차량으로 이동
    step = '05_move_picker';
    if (hasElder) {
      await tester.tap(find.text(elderName).first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      final moveButton = find.text('다른 차량으로 이동');
      if (moveButton.evaluate().isNotEmpty) {
        await tester.tap(moveButton.first, warnIfMissed: false);
        await settle(tester, seconds: 2);
        await shot(tester, '05_move_picker');
        // B노선(회차 있는 노선) 선택
        final routeB = find.text('B');
        if (routeB.evaluate().isNotEmpty) {
          await tester.tap(routeB.first, warnIfMissed: false);
          await settle(tester, seconds: 2);
          // 회차 선택 시트가 뜨면 1차를 고른다
          final trip1 = find.text('1차');
          if (trip1.evaluate().isNotEmpty) {
            await tester.tap(trip1.first, warnIfMissed: false);
            await settle(tester, seconds: 2);
          }
          step = '06_after_move';
          await shot(tester, '06_after_move');
        } else {
          debugPrint('[WARN] B노선을 찾지 못해 이동을 완료하지 못함');
          await tester.binding.handlePopRoute();
          await settle(tester, seconds: 1);
        }
      } else {
        debugPrint('[WARN] "다른 차량으로 이동" 버튼을 찾지 못함');
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 1);
      }
    }

    // ===================== 달력 =====================
    step = '07_calendar';
    final calendarTab = find.text('달력');
    if (calendarTab.evaluate().isNotEmpty) {
      await tester.tap(calendarTab.first, warnIfMissed: false);
      await settle(tester, seconds: 3);
      await shot(tester, '07_calendar');

      step = '08_after_day_tap';
      // 오늘이 아닌 다른 날짜 칸을 탭 — 흔히 있는 '10' 같은 숫자를 시도
      final day10 = find.text('10');
      if (day10.evaluate().isNotEmpty) {
        await tester.tap(day10.first, warnIfMissed: false);
        await settle(tester, seconds: 3);
        await shot(tester, '08_after_day_tap');
      } else {
        debugPrint('[WARN] 달력에서 10일을 찾지 못해 08 캡처를 건너뜀');
      }
    } else {
      debugPrint('[WARN] 달력 탭을 찾지 못함');
    }

    // ===================== 배차 설정 =====================
    // 체험 데이터에 등원·하원 노선이 이미 둘 다 있다(웹 테스트가 복사해둠).
    // 그래서 복사는 실행하지 않고 취소만 확인하고, 대신 이미 있는 하원 노선의
    // 주운전자를 같은 사람으로 다시 골라 성공(충돌 없음)하는 것과 미배정 배너를 캡처한다.
    step = '09_settings';
    final settingsIcon = find.byTooltip('배차 설정');
    if (settingsIcon.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon.first, warnIfMissed: false);
      await settle(tester, seconds: 3);

      // 미배정 배너 + 하원 노선의 주운전자 재선택 성공을 한 화면에 담는다
      step = '09_same_driver_ok';
      final homeChip = find.text('하원');
      if (homeChip.evaluate().isNotEmpty) {
        final routeCard = find
            .ancestor(of: homeChip.first, matching: find.byType(Column))
            .first;
        final driverInkWell = find
            .descendant(of: routeCard, matching: find.byType(InkWell))
            .first;
        if (driverInkWell.evaluate().isNotEmpty) {
          final driverNameFinder =
              find.descendant(of: driverInkWell, matching: find.byType(Text));
          String? driverName;
          if (driverNameFinder.evaluate().isNotEmpty) {
            final w = driverNameFinder.evaluate().first.widget as Text;
            driverName = w.data;
          }
          debugPrint('[INFO] 하원 노선 주운전자: $driverName');
          await tester.ensureVisible(driverInkWell);
          await settle(tester, seconds: 1);
          await tester.tap(driverInkWell, warnIfMissed: false);
          await settle(tester, seconds: 2);
          if (driverName != null && driverName != '직원 선택') {
            final pickSameName = find.text(driverName);
            if (pickSameName.evaluate().isNotEmpty) {
              await tester.tap(pickSameName.last, warnIfMissed: false);
              await settle(tester, seconds: 2);
              final conflictError = find.textContaining('동시에 맡을 수 없습니다');
              debugPrint(
                  '[INFO] 같은 주운전자 재선택 후 충돌 에러 노출: ${conflictError.evaluate().isNotEmpty}');
            } else {
              debugPrint('[WARN] 운전자 선택 시트에서 $driverName를 다시 찾지 못함');
            }
          } else {
            debugPrint('[WARN] 하원 노선에 배정된 주운전자를 찾지 못함');
          }
          // 목록을 맨 위로 올려 미배정 배너가 같이 보이게 한다
          final list = find.byType(Scrollable).first;
          if (list.evaluate().isNotEmpty) {
            await tester.drag(list, const Offset(0, 2000), warnIfMissed: false);
            await settle(tester, seconds: 1);
          }
          await shot(tester, '09_same_driver_ok');
        } else {
          debugPrint('[WARN] 하원 노선에서 주운전자 탭 대상을 찾지 못함');
        }
      } else {
        debugPrint('[WARN] 하원 노선 칩을 찾지 못해 09 주운전자 재선택을 건너뜀');
      }

      // 노선 복사 메뉴 → 확인 다이얼로그 → 취소 (이미 하원 노선이 있어 실제 복사는 하지 않는다)
      step = '09_copy_confirm';
      final moreVert = find.byIcon(Icons.more_vert);
      if (moreVert.evaluate().isNotEmpty) {
        await tester.tap(moreVert.first, warnIfMissed: false);
        await settle(tester, seconds: 1);
        final copyToHome = find.text('등원 노선을 하원으로 복사');
        if (copyToHome.evaluate().isNotEmpty) {
          await tester.tap(copyToHome.first, warnIfMissed: false);
          await settle(tester, seconds: 2);
          await shot(tester, '09_copy_confirm');
          final cancelBtn = find.text('취소');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn.last, warnIfMissed: false);
            await settle(tester, seconds: 2);
          } else {
            debugPrint('[WARN] 복사 확인 다이얼로그의 취소 버튼을 찾지 못함');
            await tester.binding.handlePopRoute();
            await settle(tester, seconds: 1);
          }
        } else {
          debugPrint('[WARN] "등원 노선을 하원으로 복사" 메뉴를 찾지 못함');
        }
      } else {
        debugPrint('[WARN] 배차 설정의 더보기(⋮) 버튼을 찾지 못함');
      }
      await tester.binding.handlePopRoute();
      await settle(tester, seconds: 2);
    } else {
      debugPrint('[WARN] 배차 설정 아이콘을 찾지 못함');
    }

    // ===================== 채팅 검색 → 결과 탭 → 하이라이트 =====================
    step = '12_search_jump';
    await tester.binding.handlePopRoute(); // 배차관리 화면에서 뒤로
    await settle(tester, seconds: 2);
    final navChatTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('채팅'),
    );
    await tester.tap(navChatTab.last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final room = find.text('전체 공지방');
    if (await waitFor(tester, room, maxSeconds: 20)) {
      await tester.tap(room.first, warnIfMissed: false);
      await settle(tester, seconds: 4);

      final moreBtn = find.byTooltip('더보기');
      if (moreBtn.evaluate().isNotEmpty) {
        await tester.tap(moreBtn.last, warnIfMissed: false);
        await settle(tester, seconds: 2);
        final searchMenu = find.text('대화 내용 검색');
        if (searchMenu.evaluate().isNotEmpty) {
          await tester.tap(searchMenu.last, warnIfMissed: false);
          await settle(tester, seconds: 2);
          final searchField = find.byType(TextField).last;
          await tester.enterText(searchField, '혈압');
          await settle(tester, seconds: 1);
          final searchBtn = find.text('검색');
          if (searchBtn.evaluate().isNotEmpty) {
            await tester.tap(searchBtn.last, warnIfMissed: false);
            // 검색창의 글자도 '혈압'이라 textContaining으로 고르면 입력칸을 누른다 — 결과 셀만 센다
            final resultTile = find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(SeedListCell),
            );
            await waitFor(tester, resultTile, maxSeconds: 15);
            debugPrint('[INFO] 검색 결과 개수: ${resultTile.evaluate().length}');
            if (resultTile.evaluate().isNotEmpty) {
              await tester.tap(resultTile.first, warnIfMissed: false);
              await settle(tester, seconds: 4);
              await shot(tester, '12_search_jump');
            } else {
              debugPrint('[WARN] 검색 결과가 없어 12 캡처를 건너뜀');
            }
          }
        } else {
          debugPrint('[WARN] "대화 내용 검색" 메뉴를 찾지 못함');
        }
      } else {
        debugPrint('[WARN] 채팅방 더보기 버튼을 찾지 못함');
      }

      // ===================== 이미지 저장 =====================
      step = '13_image_save';
      final images = find.byWidgetPredicate((w) => w is Image);
      Element? tallest;
      double best = 0;
      for (final e in images.evaluate()) {
        final box = e.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final ratio = box.size.height / (box.size.width == 0 ? 1 : box.size.width);
        if (ratio > best && box.size.height > 40) {
          best = ratio;
          tallest = e;
        }
      }
      if (tallest != null) {
        final box = tallest.renderObject! as RenderBox;
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        final topLeft = box.localToGlobal(Offset.zero);
        final visibleTop = topLeft.dy.clamp(120.0, screen.height - 200);
        final visibleBottom = (topLeft.dy + box.size.height).clamp(120.0, screen.height - 200);
        final tapPoint = Offset(topLeft.dx + box.size.width / 2, (visibleTop + visibleBottom) / 2);
        await tester.tapAt(tapPoint);
        await settle(tester, seconds: 3);
        final viewerOpen = find.byType(ChatImageViewer).evaluate().isNotEmpty;
        debugPrint('[INFO] 이미지 뷰어 열림: $viewerOpen');
        if (viewerOpen) {
          final saveBtn = find.byTooltip('저장');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn.first, warnIfMissed: false);
            await settle(tester, seconds: 2);
            if (Platform.isAndroid) {
              // 14 폴더 선택 시트 (사진첩/폴더 선택 고르는 화면)
              step = '14_folder_picker';
              final folderChoice = find.text('폴더 선택해 저장');
              if (folderChoice.evaluate().isNotEmpty) {
                await shot(tester, '14_folder_picker');
                await tester.tap(find.textContaining("사진첩").first, warnIfMissed: false);
                await settle(tester, seconds: 2);
              }
            }
            step = '13_image_save';
            await shot(tester, '13_image_save_success');
            await tester.binding.handlePopRoute();
            await settle(tester, seconds: 2);
          } else {
            debugPrint('[WARN] 저장 버튼(tooltip)을 찾지 못함');
          }
        } else {
          debugPrint('[WARN] 이미지 뷰어가 열리지 않아 저장 캡처를 건너뜀');
        }
      } else {
        debugPrint('[WARN] 방에 저장할 이미지가 없어 13/14 캡처를 건너뜀');
      }
    } else {
      debugPrint('[WARN] 전체 공지방을 찾지 못함');
    }

    // ===================== 뒷정리 — 05/06에서 만든 이동 되돌리기 =====================
    step = 'cleanup';
    final navAllTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('전체'),
    );
    if (navAllTab.evaluate().isNotEmpty) {
      await tester.tap(navAllTab.last, warnIfMissed: false);
      await settle(tester, seconds: 2);
      final dispatchEntryAgain = find.text('배차관리');
      if (await waitFor(tester, dispatchEntryAgain, maxSeconds: 10)) {
        await tester.tap(dispatchEntryAgain.first, warnIfMissed: false);
        await settle(tester, seconds: 3);
        final resetBtn = find.text('원래대로');
        if (resetBtn.evaluate().isNotEmpty) {
          await tester.tap(resetBtn.first, warnIfMissed: false);
          await settle(tester, seconds: 2);
          debugPrint('[INFO] 배차 이동 되돌리기 완료');
        } else {
          debugPrint('[INFO] 되돌릴 "원래대로" 버튼이 없음(이동이 반영되지 않았을 수 있음)');
        }
      }
    }

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
