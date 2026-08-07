# 앱(frontend-app) UI Seed 폴리시 전수조사 체크리스트

> 작성 중 — 5개 병렬 조사 에이전트(홈 대시보드 / 관리자 화면 / 직원·채팅·캘린더 / 공지·플라자·인증 / 공용 위젯)가 실행 중이며, 결과 도착 즉시 파일별 표를 채운다. 이 버전은 **직접 검증을 마친 버튼 색상 정책 위반 전수(critical 사용 12건 전체)** 를 우선 반영한 중간본이다.
> 갱신: 2026-08-07 (조사 진행 중)
> 조사 범위: `lib/` 전체 UI(115 dart 파일: screens 33 + widgets ~30 + 나머지 provider/model/service 등은 UI 조사 대상 아님)
> **lib/ 코드는 이 조사에서 일절 수정하지 않았다.**

---

## 새 버튼 색상 정책 (이 기준으로 전수 판정)

- **`brandSolid`** — 주된 긍정 액션 (승인, 저장, 제출, 등록, 확인)
- **`neutralOutline` / `neutralWeak`** — 보조 액션 및 **비파괴적 부정 액션** (반려, 거절, 취소, 닫기, 나중에). **반려·거절은 파괴적 행위가 아니므로 절대 critical 금지.**
- **`critical`** — **되돌릴 수 없는 파괴적 행위에만** (삭제, 회원 탈퇴, 계정 삭제)
- 부정 상태(반려됨/미승인)는 버튼 색이 아니라 상태 뱃지/텍스트 토큰(`AppSemanticColors.statusError*`)으로 표현
- 빨강 배경 대면적 사용 금지, 경고성 강조는 `statusError` 텍스트/아이콘 수준으로만

배경: 최근 Seed 이식 과정에서 "반려·거절=critical(빨강)"으로 지시했던 것이 빨강 남용의 원인 — 본 조사에서 그 정책을 바로잡는다.

---

## 요약 통계 (중간 집계 — 조사 완료 후 갱신 예정)

| 항목 | 값 |
|---|---|
| `SeedButtonVariant.critical` 전체 사용 건수 | **12건** (검증 완료) |
| → 정당 (삭제/탈퇴 등 파괴적 행위) | **6건** |
| → **부당 (반려/거절/나가기 등 비파괴적 행위에 critical 오용)** | **6건** |
| 조사 대상 파일 수 | 스크린 33 + 위젯 실질 파일 약 30 (approval 계열 8개 제외) |
| 파일별 상세 표 진행 상태 | 5개 조사 에이전트 실행 중 — 결과 도착 시 갱신 |

---

## `SeedButtonVariant.critical` 전수 판정 (직접 라인 단위 검증 완료)

| # | 파일 | 라인 | 버튼 라벨 | 판정 | 권장 조치 |
|---|---|---|---|---|---|
| 1 | screens/my_vacation_screen.dart | 208 | 삭제 | ✅ 정당 | 유지 |
| 2 | screens/chat_room_info_screen.dart | 219 | 채팅방 나가기 | ⚠️ 부당(경계선) | `neutralOutline`로 다운그레이드 권장(엄밀히 삭제/탈퇴가 아님, 재초대 가능) — 리더 최종 확인 필요 |
| 3 | screens/admin_company_settings_screen.dart | 516 | 회원탈퇴 | ✅ 정당 | 유지 |
| 4 | screens/admin_company_settings_screen.dart | 912 | 탈퇴하기 | ✅ 정당 | 유지 |
| 5 | screens/profile_screen.dart | 662 | 탈퇴하기 | ✅ 정당 | 유지 |
| 6 | screens/admin_vacation_management_screen.dart | 396 | 선택 항목 거절(일괄) | ❌ **부당** | `neutralOutline` 또는 `neutralWeak`로 교체 |
| 7 | screens/admin_vacation_management_screen.dart | 794 | 삭제 | ✅ 정당 | 유지 |
| 8 | screens/admin_vacation_management_screen.dart | 805 | 거절(개별) | ❌ **부당** | `neutralOutline` 또는 `neutralWeak`로 교체 |
| 9 | screens/admin_user_management_screen.dart | 372 | 삭제 | ✅ 정당 | 유지 |
| 10 | screens/admin_user_management_screen.dart | 673 | 거부(가입 승인 거절) | ❌ **부당** | `neutralOutline` 또는 `neutralWeak`로 교체 |
| 11 | screens/admin_approval_management_screen.dart | 643 | 선택 항목 거절(일괄) | ❌ **부당** | `neutralOutline` 또는 `neutralWeak`로 교체 |
| 12 | screens/admin_approval_management_screen.dart | 866 | 거절(개별) | ❌ **부당** | `neutralOutline` 또는 `neutralWeak`로 교체 |

**부당 사용 6건 모두 "반려/거절" 액션에 critical(빨강)을 적용한 케이스**로, 사용자가 지적한 문제(승인함·휴무 승인/반려·결재 반려·가입 승인 거절)와 정확히 일치한다. 상위 파일: `admin_vacation_management_screen.dart`(2건), `admin_approval_management_screen.dart`(2건), `admin_user_management_screen.dart`(1건), `chat_room_info_screen.dart`(1건, 경계선).

> `statusError*` 토큰(텍스트/아이콘/배지 배경) 사용처는 lib/ 전역 약 150건 확인됨 — 대부분 상태 뱃지·에러 스낵바·유효성 검사 메시지 등 정책상 허용 범위(부정 상태 표현)로, 버튼 배경 대면적 오용 사례는 각 조사 에이전트의 상세 표에서 개별 확인 중.

---

## 파일별 상세 표 — 조사 진행 중 (플레이스홀더)

아래 5개 그룹은 병렬 조사 에이전트가 파일을 전부 읽어 하드코딩 색상/리터럴 수치/타이포 미적용/구컴포넌트/카드중첩/이중헤더/그림자/그라디언트 등을 항목화하는 중이다. 결과 도착 즉시 이 섹션을 표로 교체한다.

### 그룹 A — 홈 대시보드 (최우선) ✅ 조사 완료

**핵심 발견**: 이전 자체감사(`docs/seed-migration-checklist.md`)는 `widgets/common/`을 감사 범위에서 명시적으로 제외했다. 그런데 홈에서 실제 사용되는 `notification_bell.dart`·`app_dialog.dart`가 바로 그 사각지대에 있었다 — 사용자가 체감한 "홈에 미이관 잔재가 많다"는 문제는 `home_screen.dart` 자체보다 **이 사각지대(공용 다이얼로그·알림벨)**에서 비롯된 것으로 확인됐다. `home_screen.dart` 자체는 카드중첩·그라디언트·그림자·이중헤더·shadcn 잔재가 전혀 없어 실제로는 상당히 잘 이관되어 있다(리터럴 수치 몇 개만 잔존).

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| A1 | screens/home_screen.dart | 189-194 | 리터럴수치 | 오늘 일정 dot `width:6,height:6` → `AppSpacing.space1_5` | low |
| A2 | screens/home_screen.dart | 197-198 | 리터럴수치 | 시간 라벨 `SizedBox(width:40)` → `AppSpacing.space10` | low |
| A3 | screens/home_screen.dart | 514, 523 | 토큰오용 | 커뮤니티 진입 카드 `BorderRadius.circular(AppSpacing.space3)` — spacing 토큰을 radius로 오용 → `AppBorderRadius.xl` | medium |
| A4 | screens/home_screen.dart | 538 | 타이포미적용 | "케어브이 커뮤니티" 제목 raw `FontWeight.w700` — 파일 내 다른 곳처럼 `AppTypography.fontWeightBold` 상수 사용 필요 | low |
| A5 | screens/home_screen.dart | 494 | 리터럴수치 | 대시보드 그리드 `mainAxisExtent: 156` 매직넘버 | low |
| A6 | screens/main_screen.dart | 48-50 | 참고 | 네비 아이콘/뱃지 크기용 화면 전용 명명 상수 — 이전 감사에서 이미 사유 명시됨, 재작업 불요 | low |
| A7 | widgets/common/notification_bell.dart | 23 | 리터럴수치 | `EdgeInsets.only(top:4,right:4)` → `AppSpacing.space1` | low |
| A8 | widgets/common/notification_bell.dart | 68-74 | 그림자 | 벨 아이콘 미확인 뱃지에 `BoxShadow` — 부착형 정적 요소는 보더만 써야 함(Seed 원칙: 그림자는 FAB/다이얼로그/바텀시트 한정) → 제거 | medium |
| A9 | widgets/common/notification_bell.dart | 85 | 타이포미적용 | `AppTypography.overline.copyWith(fontSize:10)` raw 오버라이드 | low |
| A10 | widgets/common/notification_bell.dart | 253 | 리터럴수치 | 알림 리스트 `EdgeInsets.all(16)` → `AppSpacing.space4` | medium |
| A11 | widgets/common/notification_bell.dart | 217, 240 | 리터럴수치 | 에러/빈 상태 `SizedBox(height:16)` ×2 → `AppSpacing.space4` | low |
| A12 | widgets/common/notification_bell.dart | 318-319 | 리터럴수치 | 알림 아이템 `margin:bottom 12`, `padding:all 16` → `space3`/`space4` | medium |
| A13 | widgets/common/notification_bell.dart | 324 | 리터럴수치 | 알림 카드 `BorderRadius.circular(16)` → `AppBorderRadius.xl2` | medium |
| A14 | widgets/common/notification_bell.dart | 336 | 리터럴수치 | 아이콘 배경 `EdgeInsets.all(8)` → `AppSpacing.space2` | low |
| A15 | widgets/common/notification_bell.dart | 339 | 리터럴수치 | 아이콘 배경 `BorderRadius.circular(10)` — 정확 대응 토큰 없음(lg=8/xl=12 중 선택 필요) | medium |
| A16 | widgets/common/notification_bell.dart | 343,360-361,369,377 | 리터럴수치 | `width:12`, unread dot `8×8`, `height:4`, `height:8` 등 다수 → space3/space2/space1/space2 | low |
| A17 | widgets/today_schedule_dialog.dart | 61-62 | 리터럴수치 | 일정 dot `8×8` → `AppSpacing.space2` | low |
| A18 | widgets/today_schedule_dialog.dart | 70 | 리터럴수치 | 시간 라벨 `SizedBox(width:44)` — 대응 토큰 없음(space10=40/space12=48 사이 갭) | low |
| A19 | widgets/vacation_request_dialog.dart | 14 | 구컴포넌트 | `import 'common/app_button.dart'` — 구 `AppButtonVariant` 열거형 의존, SeedButtonVariant로 완전 대체 필요 | medium |
| A20 | widgets/vacation_request_dialog.dart | 126-131,143,148-153 | 타이포미적용 | 안내 헤더/불릿 텍스트 raw `TextStyle(fontSize:13-14,...)` | medium |
| A21 | widgets/vacation_request_dialog.dart | 226-237(235) | **버튼정책위반(연쇄)** | 홈 "휴무 신청" 빠른작업에서 배차 충돌 시 뜨는 확인 다이얼로그가 `AppDialog.showConfirm(confirmVariant: AppButtonVariant.primary)` 경유 → 아래 A35 문제로 실제로는 **shadcn 기본 버튼**으로 렌더링, Seed 색상 정책 전혀 미적용. 홈에서 바로 도달 가능한 경로라 **high** | high |
| A22 | widgets/vacation_request_dialog.dart | 379-386(~10회) | 타이포미적용 | 토글 옵션 라벨 전부 raw `TextStyle(fontWeight:w600,fontSize:13,...)` | medium |
| A23 | widgets/vacation_request_dialog.dart | 405-419 | 하드코딩색 | 다이얼로그 표면 `BoxShadow(color: Color(0x40000000))` — 그림자 자체는 플로팅이라 허용되나 raw hex 색상 | medium |
| A24 | widgets/vacation_request_dialog.dart | 435-436 | 리터럴수치 | 헤더 아이콘 `48×48` → `AppSpacing.space12` | low |
| A25 | widgets/vacation_request_dialog.dart | 453-459 | 타이포미적용 | "휴무 신청" 타이틀 raw `fontSize:20,w600` → `AppTypography.heading5/6` | medium |
| A26 | widgets/vacation_request_dialog.dart | 462-486 | 리터럴수치+토큰오용 | 닫기 버튼 `40×40` 리터럴 + `BorderRadius.circular(AppSpacing.space2)`(spacing→radius 오용) | medium |
| A27 | widgets/vacation_request_dialog.dart | 493-503 | 토큰오용 | "선택된 날짜" 박스 `BorderRadius.circular(AppSpacing.space4)` — spacing을 radius로 오용 | medium |
| A28 | widgets/vacation_request_dialog.dart | 508-520,530-547 | 리터럴수치+타이포미적용 | 날짜 아이콘 `40×40` 리터럴, 라벨/값 raw `fontSize:12/16` ×2 | medium |
| A29 | widgets/vacation_request_dialog.dart | 583-591,654-662,753-761,915-923 | 타이포미적용 | "연차 사용여부/유형", "휴무 유형/사유" 섹션 헤더 4곳 전부 raw `TextStyle` | medium |
| A30 | widgets/vacation_request_dialog.dart | 843-884 | 리터럴수치+타이포미적용 | "세부 유형" 칩 `BorderRadius.circular(20)` 리터럴 + raw `fontSize:12` — SeedChip 대체 검토 | medium |
| A31 | widgets/vacation_request_dialog.dart | 788-803,924-961 | **정책 취지 위반** | "필수" 휴무 유형 선택 버튼·배지가 `statusError*`(빨강 계열) 사용 — "필수"는 오류/파괴가 아닌 단순 강조인데 red 톤 사용. warning/brand 톤으로 교체 권장 | medium |
| A32 | widgets/vacation_request_dialog.dart | 569-987 | 카드중첩(유사) | 다이얼로그(이미 보더+그림자 표면) 내부에 보더+라운드 박스 4개 반복 배치 — 한 표면 내부는 구분선/여백 권장 | low |
| A33 | widgets/common/app_dialog.dart | 2 | **구컴포넌트(high)** | `import shadcn_flutter as shadcn` — 홈에서 쓰이는 공용 다이얼로그 셸 전체가 여전히 shadcn 의존. 이전 자체감사가 `widgets/common/`을 범위에서 제외해 미이관 상태로 방치됨 | high |
| A34 | widgets/common/app_dialog.dart | 50,57 (`showConfirm`) | **구컴포넌트/버튼정책위반(high)** | 확인/취소 버튼이 `shadcn.OutlineButton`/`shadcn.PrimaryButton` — SeedButton 미사용. `confirmVariant`/`cancelVariant` 파라미터를 받지만 실제 렌더링에 전혀 반영 안 됨 → **critical/neutral 구분 자체가 불가능한 구조적 결함**. 홈의 배차충돌 다이얼로그(A21)가 이 경로를 탐 | high |
| A35 | widgets/common/app_dialog.dart | 16-17,76 | 기타 | `AppButtonVariant confirmVariant/cancelVariant/buttonVariant` 파라미터가 정의만 되고 미사용인 죽은 코드 — 호출부가 정책이 반영된다고 오인하게 만듦 | medium |
| A36 | widgets/common/app_dialog.dart | 108 (`showAlert`) | 구컴포넌트(high) | `shadcn.PrimaryButton` 사용 | high |
| A37 | widgets/common/app_dialog.dart | 187,194 (`showInput`) | 구컴포넌트(high) | `shadcn.OutlineButton`/`shadcn.PrimaryButton` 사용 | high |
| A38 | widgets/common/app_dialog.dart | 260-261 | 리터럴수치 | 바텀시트 핸들 `36×4` 리터럴 | low |

**요약**: `home_screen.dart` 자체는 잘 이관되어 있음(A1-A5만, 전부 low/medium 사소한 잔재). 문제의 핵심은 **`app_dialog.dart`가 파일 전체 shadcn 의존이고 색상 정책 파라미터가 죽은 코드라는 것**(A33-A37, high 다수) — 이게 홈 "휴무 신청" 빠른작업의 배차충돌 확인창(A21)까지 오염시킨다. `notification_bell.dart`도 리터럴 수치가 다수 잔존(A7-A16). `vacation_request_dialog.dart`는 SeedButton은 일부 도입했지만 내부 텍스트가 대부분 raw TextStyle이고 "필수" 강조에 red 톤을 쓰고 있어(A31) 새 정책 취지와 어긋난다.

### 그룹 B — 관리자 화면
- 대상: `admin_approval_management_screen.dart`, `admin_approval_template_screen.dart`, `admin_company_settings_screen.dart`, `admin_notice_form_screen.dart`, `admin_notice_management_screen.dart`, `admin_payment_screen.dart`, `admin_unified_approval_screen.dart`, `admin_user_management_screen.dart`, `admin_vacation_limits_setting_screen.dart`, `admin_vacation_management_screen.dart`
- 상태: 🔄 조사 중

### 그룹 C — 직원용/채팅/캘린더 화면
- 대상: `approval_list_screen.dart`, `calendar_screen.dart`, `chat_room_info_screen.dart`, `chat_room_list_screen.dart`, `chat_room_screen.dart`, `create_chat_room_screen.dart`, `my_vacation_screen.dart`, `menu_screen.dart`, `profile_screen.dart`
- 상태: 🔄 조사 중

### 그룹 D — 공지/플라자/결제/인증 화면
- 대상: `login_screen.dart`, `notice_detail_screen.dart`, `notice_list_screen.dart`, `payment_screen.dart`, `plaza_post_detail_screen.dart`, `plaza_screen.dart`, `register_screen.dart`, `signature_manage_screen.dart`, `subscription_check_screen.dart`
- 상태: 🔄 조사 중

### 그룹 E — 공용 위젯
- 대상: `widgets/admin_vacation_add_dialog.dart`, `widgets/chat/*`(3), `widgets/common/*`(app_button/app_card/app_input/app_loading/app_snackbar), `widgets/notice/*`(2), `widgets/seed/*`(avatar/callout/chip/list_cell/section_header/text_field), `widgets/update_dialog.dart`, `widgets/vacation_calendar_widget.dart`
- 상태: 🔄 조사 중

### 조사 제외(양식작업중) — 표 대상에서만 제외, 배치 제안에서도 제외
- `lib/screens/approval_form_screen.dart`
- `lib/screens/approval_detail_screen.dart`
- `lib/widgets/approval/*` (approval_card, approval_status_badge, dynamic_form_fields, hwp_editor_view, official_document_view, signature_confirm_sheet, signature_pad, template_card)
- `lib/screens/hwp_editor_screen.dart`
- `lib/models/approval.dart`

---

## 수정 배치 제안 (초안 — 상세 표 완성 후 최종 확정)

1. **배치 1(최우선·홈 대시보드)**: `home_screen.dart`, `main_screen.dart`, `widgets/common/notification_bell.dart`, `widgets/today_schedule_dialog.dart`, `widgets/vacation_request_dialog.dart`
2. **배치 2(critical 버튼 정책 위반 일괄 수정)**: `admin_vacation_management_screen.dart`, `admin_approval_management_screen.dart`, `admin_user_management_screen.dart` (+ 경계선 `chat_room_info_screen.dart` 리더 확인 후 포함)
3. **배치 3(관리자 화면 잔여)**: `admin_approval_template_screen.dart`, `admin_notice_form_screen.dart`, `admin_notice_management_screen.dart`, `admin_payment_screen.dart`, `admin_company_settings_screen.dart`, `admin_vacation_limits_setting_screen.dart`, `admin_unified_approval_screen.dart`
4. **배치 4(직원용/채팅/공지/플라자/인증 화면 + 공용 위젯)**: 그룹 C·D·E 전체 (파일 겹침 없음 확인 후 세분화 예정)

