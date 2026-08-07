# 앱(frontend-app) UI Seed 폴리시 전수조사 체크리스트

> **조사 완료.** 5개 병렬 조사 에이전트(홈 대시보드 / 관리자 화면 / 직원·채팅·캘린더 / 공지·플라자·인증 / 공용 위젯) + 리더·조사자 직접 검증(critical 버튼 12건 라인 단위, 홈 대시보드 구조·레이아웃 재확인)을 종합했다. `SeedButtonVariant.critical` 부당 사용 6건은 조사 중 리더가 커밋 `3d775cb`로 이미 직접 수정 완료 — 본 문서는 그 결과를 반영한 최종본이다.
> 갱신: 2026-08-07
> 조사 범위: `lib/` 전체 UI(115 dart 파일 중 screens 30 + widgets 실질 29 = 59개 파일 실사, approval 계열 8개+screens 3개는 조사만 하고 표에 "양식작업중"으로 별도 표시)
> **lib/ 코드는 이 조사 문서 작성 과정에서 (critical 버튼 6건을 리더가 직접 수정한 것을 제외하고는) 일절 수정하지 않았다.**

---

## 새 버튼 색상 정책 (이 기준으로 전수 판정)

- **`brandSolid`** — 주된 긍정 액션 (승인, 저장, 제출, 등록, 확인)
- **`neutralOutline` / `neutralWeak`** — 보조 액션 및 **비파괴적 부정 액션** (반려, 거절, 취소, 닫기, 나중에). **반려·거절은 파괴적 행위가 아니므로 절대 critical 금지.**
- **`critical`** — **되돌릴 수 없는 파괴적 행위에만** (삭제, 회원 탈퇴, 계정 삭제)
- 부정 상태(반려됨/미승인)는 버튼 색이 아니라 상태 뱃지/텍스트 토큰(`AppSemanticColors.statusError*`)으로 표현
- 빨강 배경 대면적 사용 금지, 경고성 강조는 `statusError` 텍스트/아이콘 수준으로만

배경: 최근 Seed 이식 과정에서 "반려·거절=critical(빨강)"으로 지시했던 것이 빨강 남용의 원인 — 본 조사에서 그 정책을 바로잡는다.

---

## 요약 통계 (조사 완료 · 최종)

| 항목 | 값 |
|---|---|
| `SeedButtonVariant.critical` 전체 사용 건수 | **12건** (검증 완료) |
| → 정당 (삭제/탈퇴 등 파괴적 행위) | **6건** — 수정 불필요 |
| → **부당 (반려/거절/나가기 등 비파괴적 행위에 critical 오용)** | **6건 — 전부 커밋 `3d775cb`로 수정 완료(neutralOutline 전환), 그룹B가 재검증함** |
| 조사 대상 파일 수 | 스크린 30(제외 3개 포함 33) + 위젯 실질 파일 29(approval 8개 제외) = **59개 파일 실사** |
| 5개 그룹 조사 진행 상태 | **전부 완료** (홈 대시보드 / 관리자화면 / 직원·채팅·캘린더 / 공지·플라자·인증 / 공용위젯) |
| 파일별 표 총 발견 항목 수 | **175건** (A40+B23+C53+D33+E26, "준수확인/정정/info" 표시 항목 13건 포함) |
| → high 우선순위 | **약 29건** |
| → medium 우선순위 | **약 72건** |
| → low 우선순위 | **약 61건** |
| → 준수확인/정정/참고(조치 불필요) | **13건** |
| 후속 발견 — critical 해소 후에도 남은 "빨강/상태색 대면적 오용" 계열 | 5건(A21/A33, B9, B15, C4/C29, E1/E2 등 — 상세는 각 그룹 요약 참고) |

---

## `SeedButtonVariant.critical` 전수 판정 (직접 라인 단위 검증 완료 → **6건 전부 리더가 커밋 `3d775cb`로 직접 수정 완료**)

| # | 파일 | 라인 | 버튼 라벨 | 판정 | 상태 |
|---|---|---|---|---|---|
| 1 | screens/my_vacation_screen.dart | 208 | 삭제 | ✅ 정당 | 유지(수정 불필요) |
| 2 | screens/chat_room_info_screen.dart | 219 | 채팅방 나가기 | ⚠️ 부당(경계선) | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |
| 3 | screens/admin_company_settings_screen.dart | 516 | 회원탈퇴 | ✅ 정당 | 유지(수정 불필요) |
| 4 | screens/admin_company_settings_screen.dart | 912 | 탈퇴하기 | ✅ 정당 | 유지(수정 불필요) |
| 5 | screens/profile_screen.dart | 662 | 탈퇴하기 | ✅ 정당 | 유지(수정 불필요) |
| 6 | screens/admin_vacation_management_screen.dart | 396 | 선택 항목 거절(일괄) | ❌ 부당 | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |
| 7 | screens/admin_vacation_management_screen.dart | 794 | 삭제 | ✅ 정당 | 유지(수정 불필요) |
| 8 | screens/admin_vacation_management_screen.dart | 805 | 거절(개별) | ❌ 부당 | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |
| 9 | screens/admin_user_management_screen.dart | 372 | 삭제 | ✅ 정당 | 유지(수정 불필요) |
| 10 | screens/admin_user_management_screen.dart | 673 | 거부(가입 승인 거절) | ❌ 부당 | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |
| 11 | screens/admin_approval_management_screen.dart | 643 | 선택 항목 거절(일괄) | ❌ 부당 | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |
| 12 | screens/admin_approval_management_screen.dart | 866 | 거절(개별) | ❌ 부당 | ✅ **수정 완료(3d775cb)** — `neutralOutline`로 전환 |

부당 사용 6건 모두 "반려/거절/나가기" 액션에 critical(빨강)을 적용한 케이스였으며, 사용자가 지적한 문제(승인함·휴무 승인/반려·결재 반려·가입 승인 거절)와 정확히 일치했다. 커밋 `3d775cb`(`거절·거부 버튼에서 빨강 걷어내기 — critical은 삭제·탈퇴에만`)로 전부 `neutralOutline`으로 전환 완료 — 그룹B 조사 에이전트가 재검증(직접 grep)해 6곳 모두 현재 `neutralOutline`임을 확인했다.

**⚠️ 후속 발견 — "빨강 남용"이 버튼에서 상태색/스낵바로 형태를 바꿔 잔존**: critical 버튼 자체는 해소됐지만, 조사 과정에서 같은 성격의 문제가 다른 곳에서 다수 발견됨:
- `admin_user_management_screen.dart:743` — 가입 **거부 완료** 스낵바가 여전히 `statusErrorIcon`(빨강) 사용. 거부가 비파괴 액션이 된 지금 완료 알림까지 에러색인 건 어색함 → 중립/경고 톤 권장
- `profile_screen.dart:1394-1397` — **로그아웃** 버튼이 SeedButton도 아닌 raw `FilledButton`+`statusErrorIcon`(빨강) 전체폭 블록. 로그아웃은 비파괴 액션 → `SeedButton(neutralOutline)`
- `menu_screen.dart:162-167` — 로그아웃 메뉴 항목이 `isDestructive:true`로 스타일링됨 → `false`로 변경
- `admin_vacation_add_dialog.dart:82,125,134,173` — 스낵바가 `statusErrorIcon`/`statusSuccessIcon`(진한 색) **전체 배경**으로 사용, "대면적 빨강 블록 금지" 원칙 위반 (이미 올바른 패턴인 `AppSnackBar.showError/showSuccess`가 같은 파일 트리에 존재)
- `admin_notice_management_screen.dart:233-241` — 공지 스와이프 삭제 배경이 `statusErrorIcon` 전체폭 솔리드 블록(삭제 액션과 결부되어 의미상 정당성은 있으나 문구상 "대면적 금지" 원칙과 상충)

> `statusError*` 토큰(텍스트/아이콘/배지 배경) 사용처는 lib/ 전역 약 150건 확인됨 — 대부분 상태 뱃지·에러 스낵바·유효성 검사 메시지 등 정책상 허용 범위(부정 상태 표현)로, 버튼 배경 대면적 오용 사례는 각 조사 에이전트의 상세 표에서 개별 확인 중.

---

## 파일별 상세 표 (조사 완료)

아래 5개 그룹은 병렬 조사 에이전트가 파일을 전부 읽어 하드코딩 색상/리터럴 수치/타이포 미적용/구컴포넌트/카드중첩/이중헤더/그림자/그라디언트 등을 항목화한 결과다.

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

#### 홈 대시보드 구조·시각완성도 추가 검토 (직접 재확인, 리더 요청 반영 — 토큰이 아닌 레이아웃/정보구조/밀도 관점)

`lib/screens/home_screen.dart`를 라인 단위로 직접 재확인한 결과, 하드코딩 색상·원시 수치는 리더 판단대로 거의 없다(A1-A5 정도의 사소한 잔재뿐). 대신 다음 두 가지 **구조적** 이슈를 발견:

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| A39 | screens/home_screen.dart | 357-412 | **헤더 블록 과다 브랜드 배경** | 홈 상단이 `Container(color: interactivePrimaryDefault)`로 화면 폭 전체를 브랜드 틸 단색으로 채운 히어로 배너(제목"홈"+인사말+부제목, SafeArea 포함 실측 약 140~160px 높이) — 앱의 다른 대부분 화면(공지목록·채팅목록·메뉴 등, 그룹C/D 조사에서 확인)은 플랫 화이트 AppBar를 쓰는데 **홈만 유일하게 대면적 브랜드 색 블록**을 유지 중이다. `create_chat_room_screen.dart`/`chat_room_info_screen.dart`(그룹C에서 발견, high)의 "AppBar 브랜드 틸 풀칼라" 위반과 동일 계열 패턴 — 어쩌면 홈이 그 스타일의 원조일 가능성. Seed 원칙("배경 레이어 최소화", 대면적 색 블록 지양)에 비춰 톤다운(예: 배경은 흰색+얇은 보더 유지, 브랜드색은 아이콘/포인트에만 국한) 검토 필요. **사용자가 "홈에 미이관 디자인이 많다"고 느낀 가장 큰 단일 요인일 가능성이 높음** — 리더 판단 필요(의도된 히어로 디자인인지, 정리 대상인지) | high |
| A40 | screens/home_screen.dart | 432-466 | **섹션 리듬 불일치** | "빠른 작업"(휴무신청/결재/공지보기 3버튼 Row)만 유일하게 `_SectionHeader`(제목+부제목)도 `_SectionCard`(흰 표면 래핑)도 없이 카드 사이에 맨몸으로 배치됨. 페이지의 다른 모든 섹션(오늘 브리핑/대시보드/커뮤니티/공지사항/월간일정)은 전부 `_SectionCard`+`_SectionHeader` 패턴을 따르는데 이 섹션만 예외라 스크롤 시 시각적 리듬이 끊긴다. `_SectionHeader(title:'빠른 작업')` 추가 또는 동일 카드 패턴으로 통일 권장 | medium |

**결론**: 리더가 직접 확인한 대로 `home_screen.dart`의 토큰 미적용은 미미하다. 사용자가 체감한 "미이관/과한 브랜드색" 문제는 (1) 코드 사각지대였던 `app_dialog.dart`/`notification_bell.dart`(A7-A38), (2) 홈 헤더 자체의 대면적 브랜드 블록(A39, 이번에 새로 확인) 두 갈래로 나뉜다. 특히 A39는 "빨강 과다"와 같은 성격의 "특정 색 대면적 사용" 패턴이 브랜드색으로 반복된 사례라 리더 확인이 필요하다.

#### 홈 대시보드 심화 재검토 (사용자가 최신 정식 출시 빌드를 이미 쓰고 있음이 확인됨 — 토큰 문제 아닌 레이아웃·정보구조·시각완성도 관점, 코드 근거 있는 것만)

리더 지시에 따라 `home_screen.dart`(1229줄 전체)를 6개 관점으로 재검토. 아래는 전부 실제 코드 구조에서 확인한 것이며 추측은 배제했다.

| # | 라인 | 관점 | 무엇이 왜 어긋났는지 | 어떻게 고칠지 | 우선순위 |
|---|---|---|---|---|---|
| A41 | 357-412 | 헤더 색면 | `Container(color: interactivePrimaryDefault)`가 `BorderRadius`/그라디언트/페이드 없이 화면 폭 전체를 완전한 직사각형으로 채우고, 바로 아래(L419-425 `SliverPadding`)부터 흰 배경 `_SectionCard`(L813-816, `borderRadius: xl2` 1px 보더)가 시작 — 브랜드색 면이 아무 전환 없이 흰 카드와 90도로 맞닿는다. 나머지 화면 대부분(그룹C/D에서 확인된 notice_list/chat_room_list/menu_screen 등)은 플랫 화이트 AppBar를 쓰므로, 홈의 이 "각진 단색 배너" 패턴이 앱 전체에서 시각적으로 가장 튀는 지점 — 옛 Material 스타일의 "브랜드색 AppBar" 잔재처럼 읽힌다. | 헤더 컨테이너 하단에 `BorderRadius.only(bottomLeft/bottomRight: Radius.circular(AppBorderRadius.xl2))`를 줘서 아래 카드 라운드와 시각적으로 이어지게 하거나, 브랜드색 배경 자체를 걷어내고(흰 배경 유지) "홈"/인사말 텍스트만 남기고 포인트는 아이콘색 정도로 축소 | high |
| A42 | 1211 vs 815 | 라운드 스케일 불일치 | `_QuickActionButton`(L1175-1229, "빠른 작업" 3버튼)은 `BorderRadius.circular(AppBorderRadius.lg)`(=8, 코드 주석상 "r2")를 쓰는데, 같은 페이지의 최상위 콘텐츠 블록인 `_SectionCard`(L799-821)는 `AppBorderRadius.xl2`(=16)를 쓴다. 같은 위계(페이지 최상단 콘텐츠 블록)인데 라운드 값이 2배 차이 나 "빠른 작업" 줄만 다른 컴포넌트 체계처럼 보임 | 빠른 작업 버튼도 `AppBorderRadius.xl2`로 통일하거나, 버튼류는 의도적으로 작은 라운드를 쓰는 게 앱 전역 컨벤션인지 교차 확인(SeedButton 자체의 medium 라운드도 `lg`=8이라 버튼류는 lg가 맞을 수 있음 — 다만 그렇다면 "카드처럼 보이는" 현재 시각적 무게와 안 맞으므로 컴포넌트 성격 자체를 재검토) | medium |
| A43 | 432-466 | 섹션 리듬(재확인, A40과 동일 근본원인) | "빠른 작업" 행만 유일하게 `_SectionCard`도 `_SectionHeader`도 없이 카드 사이에 맨몸으로 끼어 있다 — 스크롤하면 카드→맨몸버튼행→카드→카드→카드→카드 순서로 리듬이 한 번 끊긴다 | A40과 동일: `_SectionHeader(title:'빠른 작업')` 추가 또는 `_SectionCard`로 감싸 카드 패턴 통일 | medium |
| A44 | 1046-1122 vs 977-1044 | **탭 가능 여부의 시각적/실제 불일치** | `_SchedulePreviewTile`(월간일정 미리보기 행, L1046-1122)은 `Padding`→`Row`만 있고 `InkWell`/`GestureDetector`/`onTap`이 전혀 없어 **실제로 탭이 안 된다.** 바로 위 `_NoticePreviewTile`(공지 미리보기 행, L977-1044)은 `Material`+`InkWell(onTap:...)`로 감싸 탭하면 상세화면으로 이동한다. 두 위젯은 구조가 거의 동일(아이콘/텍스트 2단 Row)해서 사용자는 일정 행도 눌리는 것으로 기대하기 쉬운데 아무 반응이 없다 — "덜 만들어진 것처럼 보이는" 구체적 실체 중 하나 | `_SchedulePreviewTile`에 `Material`+`InkWell(onTap: () => ...)`를 추가해 캘린더 해당 날짜로 이동시키거나 일정 상세를 열도록 구현(현재 onTap 콜백 자체가 없음 — 상위 `_SchedulePreviewTile(schedule: entry.value)` 호출부 L633도 onTap을 넘기지 않음) | high |
| A45 | 977-1044, 509-552 | 탭 어포던스 신호 불일치 | "케어브이 커뮤니티" 진입 카드(L509-552)는 탭 가능함을 `Icon(Icons.chevron_right)`(L547-548)로 명시적으로 알려주는데, 바로 아래 공지사항 미리보기 행(`_NoticePreviewTile`, 실제로 탭 가능·상세 이동)은 화살표/셰브런 등 어떤 시각적 신호도 없이 순수 리플만으로 탭 가능함을 암시 — 같은 화면 안에서 "탭 가능=화살표 표시" 규칙이 카드 단위로만 지켜지고 리스트 행 단위에서는 빠져 있음 | 공지/일정 미리보기 행에도 우측에 작은 `chevron_right` 아이콘을 일관되게 추가하거나(대신 화면이 더 번잡해질 수 있음), "리스트 행은 화살표 없이도 암묵적으로 탭 가능"이라는 규칙을 앱 전체 컨벤션으로 명문화하고 그 규칙에 맞게 커뮤니티 카드의 화살표를 제거하는 방향도 검토 | low |
| A46 | 372-406 | 헤더 내 텍스트 위계 중첩 | 브랜드색 헤더 블록 안에 `heading5`(L377, "홈") → `heading6`(L391, "OOO님, 반갑습니다.") → `bodySmall`(L397, 부제 안내문) 3단 텍스트가 쌓여 있다. "홈"은 이미 하단 탭바에 동일 라벨이 있어 화면 안에서 다시 강조할 실익이 적고, 파운데이션 문서의 "화면당 heading 1개" 원칙과도 결이 다르다(엄밀한 위반은 아니고 인사말형 홈 화면에서 흔한 패턴이라 절대적 문제는 아님) | "홈" 라벨을 제거하거나 작은 라벨(예: overline/캡션 톤)로 낮추고, 인사말(`heading6`)을 유일한 헤더 타이틀로 승격 — 헤더 안 텍스트 위계를 1단으로 단순화 | low |
| A47 | 862-881 | Seed 비대응 컴포넌트 | "전체보기" 텍스트버튼(`_SectionHeader` 내부, L862-881)이 raw Flutter `TextButton`+`styleFrom` 수동 스타일링으로 구현되어 있고, 앱 전체를 grep해도 이 두 곳(L562, L612 호출부)이 "전체보기/더보기" 패턴의 유일한 사용처다 — 즉 비교 대상이 없는 고립된 구현이라 일관성 검증 자체가 불가능한 상태. `lib/widgets/seed/*`에도 이런 "인라인 텍스트 링크 버튼"에 대응하는 컴포넌트가 없다(seed_button.dart의 5개 variant는 전부 박스형 버튼) | Seed 컴포넌트 셋에 텍스트-링크 버튼(ghost/text variant)이 없다는 자체가 이번 조사에서 드러난 시스템 공백 — 임시로는 현재 raw TextButton 스타일을 `AppTypography.labelMedium`+`interactivePrimaryDefault`(이미 적용됨, L876-878)로 유지하되 컴포넌트화(`SeedTextLink` 등) 검토를 디자인시스템 백로그에 등재 | low |
| A48 | 469-639 (섹션 순서 전체) | 정보 우선순위(참고, 판단 필요) | 페이지 순서가 오늘 브리핑(L429) → 빠른 작업(L433) → **대시보드 지표 4개**(L469, 승인대기/공지/휴무/일정 카운트) → 커뮤니티(L509) → 공지사항(L555) → 월간일정(L605). 화면 자체가 "대시보드"인데 정작 정량 지표 블록이 6개 섹션 중 3번째이고, 화면을 열자마자 보이는 건 오늘 일정 텍스트 목록뿐이다 — 승인 대기 건수처럼 즉시 조치가 필요한 숫자가 스크롤 없이는 지표 카드 형태로 안 보임 | 지표 그리드를 오늘 브리핑과 순서를 바꿔 최상단으로 올리거나, 오늘 브리핑 카드 안에 지표 배지를 요약 삽입하는 방안 검토(리더 판단 필요 — 기능적으로 틀린 건 아니고 우선순위 취향 문제) | low |
| A49 | 572-577, 616-621 | 빈 상태 문구 품질(확인, 문제 없음) | `_EmptySectionState` 문구("등록된 공지사항이 없습니다"/"새 공지가 올라오면 이곳에 표시됩니다.", "이번 달 등록된 일정이 없습니다"/"근무조정 탭에서 일정과 휴무 달력을 확인할 수 있습니다.")는 구체적이고 다음 행동을 안내함 — 리더 우려와 달리 이 항목은 **양호**, 수정 불필요 | — | — |
| A50 | 349-646 전체 | 중복 레이어(확인, 문제 없음) | 배경 레이어는 화면 bg(흰색, `backgroundPrimary`) 1단 + 헤더 브랜드블록 1단(A41이 이미 지적) 뿐이고, `_SectionCard`의 배경색도 `backgroundPrimary`로 화면과 동일해 카드가 "배경색 블록"이 아니라 보더로만 구분됨(L813-816) — 파운데이션의 "배경 레이어 최대 2단" 원칙은 지켜지고 있고, 이중 AppBar나 섹션 타이틀 중복도 없음(각 카드 title/subtitle 텍스트 전부 고유). 이 항목은 **양호** | — | — |

**종합**: 토큰화는 리더 말대로 끝나 있다. 실제 "덜 된 것처럼 보이는" 지점은 셋으로 좁혀진다 — **(1) A41 헤더의 각진 브랜드 색면**(가장 시각적으로 두드러짐), **(2) A44 일정 미리보기 행이 실제로 탭이 안 되는 기능적 미완성**(단순 스타일이 아니라 onTap 콜백 자체가 없는 코드 결함), **(3) A42/A43 "빠른 작업" 행의 라운드·리듬 불일치**. 나머지(A45-A48)는 경미하거나 취향 판단 영역, A49-A50은 문제 없음으로 확인됨.

### 그룹 B — 관리자 화면 ✅ 조사 완료

**정정 확인**: 사전 보고된 critical 오용 5건(admin_approval_management_screen.dart:643·866, admin_vacation_management_screen.dart:396·805, admin_user_management_screen.dart:673)을 그룹B 에이전트가 직접 재-grep, **전부 `neutralOutline`으로 이미 수정되어 있음을 재확인**(=리더의 3d775cb 커밋과 일치). 순수 `Colors.*`/raw hex, 그라디언트, 정적그림자, shadcn 버튼은 10개 파일 전체에서 0건 — 이전 자체감사 체크리스트의 "완료" 주장이 대체로 실측과 일치한다. 남은 잔재는 리터럴 spacing/radius, 산발적 raw TextStyle, **상태색(빨강/경고색) 시맨틱 매핑의 미세한 오용**에 집중.

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| B1 | admin_approval_management_screen.dart | 643,866 | 정정 | 거절 버튼 2곳 이미 `neutralOutline` 수정 완료 | info |
| B2 | admin_approval_management_screen.dart | 708-709,519 | 리터럴/타이포 | 체크박스 `24×24` 리터럴, 검색바 hintStyle raw | low |
| B3 | admin_company_settings_screen.dart | 731 | **시맨틱토큰 오용** | 결제실패 카드 `Border.all(color: statusErrorBackground)` — Border 자리에 Background 롤 토큰 사용(대비 약함) → `statusErrorBorder`로 교체 | medium |
| B4 | admin_company_settings_screen.dart | 566 | 시맨틱토큰 오용 | 로그아웃 실패 스낵바 `statusWarningIcon`(경고색) — 에러 상황인데 Warning 톤 → `statusErrorIcon` | medium |
| B5 | admin_company_settings_screen.dart | 97-98,279-280 | 리터럴수치 | 로고 `80×80`, `_buildInfoRow` 아이콘배지 `40×40`(5회 반복) → space20/space10 | medium |
| B6 | admin_company_settings_screen.dart | 872 | 스타일일관성 | "⚠️" raw emoji 문자 — 다른 곳은 `Icon(statusErrorIcon)` 패턴 | low |
| B7 | admin_company_settings_screen.dart | 83-537 | one-surface(경미) | 상세정보/관리자정보/구독정보/계정관리 4곳이 각각 독립 흰카드 — 그림자 없어 경미 | low |
| B8 | admin_notice_form_screen.dart | — | 준수확인 | 저장=brandSolid 등 정책 일치, 그라디언트/그림자/하드코딩/shadcn 전부 0 — 사실상 완료 | — |
| B9 | admin_notice_management_screen.dart | 233-241 | **대면적 색 블록(경계)** | 스와이프삭제 배경 `statusErrorIcon` 전체폭 솔리드 — 삭제(파괴적) 액션과 결부돼 의미상 정당성 있으나 "대면적 빨강 금지" 문구와 상충. 아이콘만 강조하는 절제된 처리 검토 | medium |
| B10 | admin_notice_management_screen.dart | 248-257,100 | 컴포넌트/리터럴 | 공지카드 native `Card` 사용(위반 아니나 불일치), AppBar 높이 `70`(스케일 밖) | low |
| B11 | admin_payment_screen.dart | 112-113,273-274 | 리터럴수치 | 플랜아이콘 `50×50`(스케일 밖), 약관박스 `height:150`(스케일 밖) | medium |
| B12 | admin_payment_screen.dart | 316-318,679-681,516-594 | 리터럴/범위외 | 체크박스 `24×24`, 완료다이얼로그 원 `80×80`, WebView 인라인CSS `#f3f3f3`/`#3498db`(Flutter 범위 밖, 브랜드 틸 아닌 임의 파랑) | low |
| B13 | admin_unified_approval_screen.dart | — | 준수확인(모범) | 이중헤더 없음, 하위 4탭 자체 AppBar 없음. 리터럴 2곳(`Size.fromHeight(48)`, `indicatorWeight 2 vs 3` 불일치)만 low | low |
| B14 | admin_user_management_screen.dart | 673 | 정정 | "거부" 이미 `neutralOutline` 수정 완료 | info |
| B15 | admin_user_management_screen.dart | 743 | **상태색 정책(신규 발견)** | 가입거부 완료 스낵바가 `statusErrorIcon`(빨강) — 거부가 비파괴 액션이 됐는데 완료알림이 에러색. 같은파일 비활성화완료(L413-415)는 `statusWarningIcon`이라 불일치. 중립/경고 톤 권장 | medium |
| B16 | admin_user_management_screen.dart | 210,540 | 버튼컨벤션 | "다시 시도" 버튼이 `brandSolid` — 타화면(notice_management 등)은 재시도에 `neutralWeak` 확립. brandSolid는 1차 긍정액션 전용 권장 | medium |
| B17 | admin_user_management_screen.dart | 242,335,277 | 레거시토큰/리터럴 | `Constants.defaultPadding`(구 상수클래스) → AppSpacing.space4, `width:44`(스케일밖), `radius:18` 리터럴 | medium |
| B18 | admin_vacation_limits_setting_screen.dart | 248-303 | **레이아웃원칙(중복강조)** | AppBar bottom에 아이콘뱃지+서브텍스트+"ADMIN"배지 3중 강조 — 형제화면(admin_unified_approval/admin_user_management)은 이미 슬림 타이틀로 정리됨, 이 화면만 구 패턴 잔존 → 슬림화 권장 | medium-high |
| B19 | admin_vacation_limits_setting_screen.dart | 254,585,9 | 리터럴/위생 | `Size.fromHeight(80)`, 입력필드 `width:60`(스케일밖), 미사용 import(`app_theme.dart`) | low-medium |
| B20 | admin_vacation_limits_setting_screen.dart | 460-481 | 참고 | 일요일=statusError/토요일=statusInfo를 달력 요일표시(비-에러 문맥)에 사용 — 한국 달력 관용이라 위반 아님, 참고 기록 | info |
| B21 | admin_vacation_management_screen.dart | 396,805 | 정정 | 거절 버튼 2곳 이미 `neutralOutline` 수정 완료(사전조사 대비 최우선 정정) | info |
| B22 | admin_vacation_management_screen.dart | 710-713,730-734 | 타이포미적용 | 신청자명 `TextStyle(bold,16)` 하드코딩, 상태뱃지 `TextStyle(fontSize:12,bold)` 하드코딩 → AppTypography 계열로 | medium |
| B23 | admin_vacation_management_screen.dart | 294,694,6,11 | 리터럴/위생 | 검색바hintStyle raw, `CircleAvatar(radius:20)`, 미사용 import 2곳 | low |

**파일 그룹 요약**: `admin_approval_template_screen.dart`/`admin_notice_form_screen.dart`/`admin_unified_approval_screen.dart`는 사실상 완료 상태(모범사례). `admin_company_settings_screen.dart`는 시맨틱 토큰 미세 오용 2건(B3,B4)과 리터럴 반복(B5)이 핵심. `admin_user_management_screen.dart`는 critical은 해소됐지만 **"빨강 남용"이 스낵바(B15)·버튼컨벤션(B16)으로 형태를 바꿔 잔존**하는 새 이슈 발견. `admin_vacation_limits_setting_screen.dart`는 AppBar 3중 강조(B18, medium-high)가 형제화면 대비 눈에 띄는 불일치.

### 그룹 C — 직원용/채팅/캘린더 화면 ✅ 조사 완료

**핵심 발견**: critical(빨강) 오용은 이 그룹에서 상대적으로 적으나(경계선 1건), 대신 **"닫기/로그아웃/나가기류 비파괴 액션에 red 또는 brandSolid를 잘못 붙이는 패턴"**, **구 AppButton/AppDialog/raw CircleAvatar 잔재**, **화면 간 AppBar 색상 불일치(브랜드 틸 풀칼라 vs 플랫 화이트)**, **카드/surface 중첩(캘린더 상세패널, 휴무현황)**이 두드러진다.

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| C1 | my_vacation_screen.dart | 208 | 준수 확인 | "삭제"=critical, legit | — |
| C2 | chat_room_info_screen.dart | 219 | **버튼정책위반(경계)** | "채팅방 나가기"=critical — 비가역 파괴행위 아님 → `neutralOutline` 권장(리더 확인 필요, 그룹A와 동일 항목) | medium-high |
| C3 | profile_screen.dart | 662 | 준수 확인 | "탈퇴하기"=critical, legit | — |
| C4 | profile_screen.dart | 1394-1397, 1416 | **버튼정책위반(high)** | 로그아웃 버튼이 SeedButton이 아닌 raw `FilledButton`+`backgroundColor: statusErrorIcon`(빨강) 전체폭 블록. 로그아웃은 비파괴 → `SeedButton(neutralOutline/neutralWeak)`로 교체 | high |
| C5 | profile_screen.dart | 111-118 | 구컴포넌트(high) | `_showLogoutDialog`가 `AppDialog.showConfirm`+구 `AppButtonVariant.primary` 사용. 파일 내 다른 다이얼로그는 `AppDialog.showCustom`+SeedButton — 통일 필요 | high |
| C6 | create_chat_room_screen.dart | 164-171 | **버튼정책위반(high)** | AppBar '만들기'(제출/등록류 positive)가 `neutralWeak` — `brandSolid`로 교체 | high |
| C7 | create_chat_room_screen.dart | 226-242 | 버튼정책 의심 | '전체 선택' 보조액션이 `brandWeak`(브랜드색) 사용 — secondary는 neutralOutline/neutralWeak여야 함, 주CTA와 무게 충돌 | medium |
| C8 | menu_screen.dart | 162-167 | **버튼정책위반** | `_MenuItem(logout, isDestructive:true)` — 로그아웃은 파괴 아님 → `isDestructive:false` | medium |
| C9 | chat_room_screen.dart | 805-812(L809) | **버튼정책위반(high)** | 리액션 목록 다이얼로그 "닫기"=`brandSolid` — 닫기는 neutralOutline/neutralWeak 대상 | high |
| C10 | chat_room_info_screen.dart | 209-213 | 토큰오용 | 구분선에 `borderDefault.withValues(alpha:0.1)`로 흉내 → 전용 `borderSubtle` 토큰 사용 | medium |
| C11 | menu_screen.dart | 9-10, 33-39 | 구컴포넌트(high) | 구 `app_button.dart`/`app_dialog.dart` import + `AppDialog.showConfirm(confirmVariant: AppButtonVariant.primary)` — 나머지는 SeedListCell 정상인데 로그아웃 흐름만 레거시 | high |
| C12 | create_chat_room_screen.dart | 150-160 | **화면간 일관성(high)** | AppBar 전체가 `interactivePrimaryDefault`(브랜드 틸) 풀칼라. approval_list/chat_room_list/menu_screen은 전부 플랫 화이트 AppBar — 통일 필요 | high |
| C13 | chat_room_info_screen.dart | 111-121 | **화면간 일관성(high)** | AppBar 브랜드 틸 풀칼라 — 연동화면 chat_room_screen.dart(플랫 화이트, elevation 0)와 상충 | high |
| C14 | calendar_screen.dart | 858-867, 988-1006 | **카드중첩(high)** | 휴무 상세 패널(카드) 안에 개별 휴무 항목도 동일 카드 스타일 — 내부 항목은 리스트 행으로 단순화 필요 | high |
| C15 | calendar_screen.dart | 482-488, 622-632 | **카드중첩(high)** | 일정 상세 패널 안 `_buildScheduleItem`도 동일 카드 스타일 반복 | high |
| C16 | my_vacation_screen.dart | 483-578, 750-790, 792-807 | **one-surface 위반(high)** | 신청현황 요약/섹션헤더3개/신청카드들이 각각 독립 흰색 border+radius 카드로 반복(floating shards) — 하나의 surface+Divider 구조로 재구성 필요 | high |
| C17 | calendar_screen.dart | 1470-1491 | 비-Seed 위젯(high) | '카테고리' 필드가 raw `DropdownButtonFormField`+`OutlineInputBorder` — 인접 필드는 SeedTextField, 이질적 | high |
| C18 | calendar_screen.dart | 1547-1676 | 비-Seed 위젯 | 시작/종료 일시 필드 4곳 raw `InkWell`+`InputDecorator`+`OutlineInputBorder` | medium |
| C19 | calendar_screen.dart | 1512-1521, 1774-1783 | 비-Seed 위젯 | '종일'/'알림발송' 토글 raw Material `Switch` 2곳(Seed `Switch` 컴포넌트 미사용) | medium |
| C20 | calendar_screen.dart | 1720-1754 | 비-Seed 위젯 | 참석자 선택 raw Material `CheckboxListTile` | medium |
| C21 | calendar_screen.dart | 1330-1356 | 그림자규칙 | 휴무추가 FAB `elevation:0` — floating 요소는 그림자 필요, 관리자 FAB(1321-1327)와도 불일치 | medium |
| C22 | approval_list_screen.dart | 552-573 | 그림자규칙 | FAB를 Container로 감싸고 `elevation:0`으로 완전 무그림자 | medium |
| C23 | chat_room_screen.dart | 940-946 | 레거시위젯(high) | 읽은사람 목록 raw `CircleAvatar` — 같은 파일 1205-1212는 `SeedAvatar` 정상 사용, 불일치 | high |
| C24 | create_chat_room_screen.dart | 291-367 | 레거시위젯 | 회원목록이 raw `ListTile`+`CircleAvatar`+`Checkbox` — 타 화면은 SeedListCell/SeedAvatar | medium |
| C25 | menu_screen.dart | 196-206 | 레거시위젯 | 프로필카드 아바타 raw `CircleAvatar(radius:24)` — chat_room_list_screen은 SeedAvatar | medium |
| C26 | profile_screen.dart | 1100-1106 | 레거시위젯 | '복사' 버튼 `TextButton.icon`(raw) — IconButton/SeedButton 아님 | medium |
| C27 | chat_room_screen.dart | 1530-1545 | 컴포넌트미사용 | 전송버튼 `GestureDetector`+`Container(40x40)` 수동구현 — SeedButton/IconButton 권장 | medium |
| C28 | my_vacation_screen.dart | 750-790, 851-943 | 컴포넌트미사용 | 섹션헤더/뱃지 직접 Container 구현 — 기존 `SeedSectionHeader`/`SeedChip` 미사용 중복구현 | medium |
| C29 | profile_screen.dart | 612-639 | **대면적 색 블록(정책 취지 위반)** | 회원탈퇴 안내박스가 `statusErrorBackground` 전체 배경(대형 빨강 블록) — 텍스트/아이콘 레벨로 축소 권장 | medium |
| C30 | profile_screen.dart | 471-496 | 대면적 색 블록 | 역할변경 경고박스 `statusWarningBackground` 전체+border — 텍스트/아이콘 레벨로 축소 권장 | low |
| C31 | my_vacation_screen.dart | 856-859 | 시맨틱토큰 오용 | 상태뱃지("거절됨") 배경에 텍스트전용 토큰(`statusErrorText`)을 배경 채우기로 사용 — 전용 배경토큰으로 교체 | medium |
| C32 | my_vacation_screen.dart | 907-913 | 시맨틱토큰 오용 | '필수' 배지 배경에 아이콘전용 토큰(`statusWarningIcon`) 재사용 | medium |
| C33 | profile_screen.dart | 904,913,967,408,933-935,1550 | 시맨틱토큰 오용 | `_buildInfoRow`/`_getRoleColor`가 실제 상태와 무관한 장식색에 statusInfo/Success/Warning/Error 광범위 재사용(**"요양보호사"=에러색(빨강)**은 특히 주의) — 중립/역할 전용 팔레트로 교체 | medium(역할=에러색 특히) |
| C34 | profile_screen.dart | 1054 | 시맨틱토큰 오용 | '회사코드' 헤더 아이콘에 `statusWarningIcon` — 경고 상태 아님 | low |
| C35 | menu_screen.dart | 212-215 | 토큰혼용 | 같은 EdgeInsets 내 horizontal=`AppSpacing.space2`, vertical=리터럴 `2` 혼용 | high |
| C36 | calendar_screen.dart | 640 | 리터럴radius | `BorderRadius.circular(2)` → `AppBorderRadius.sm` | medium |
| C37 | calendar_screen.dart | 156,1351,1438,1699 | 타이포미적용 | raw `FontWeight.normal/w600/bold` — `AppTypography.fontWeight*` 미사용 | medium |
| C38 | chat_room_screen.dart | 586-587,748,782 | 타이포미적용 | 이모지 텍스트 raw `TextStyle(fontSize:28/14/24)` 3곳 | medium |
| C39 | profile_screen.dart | 1662-1666,1671-1675,1734-1738,1762-1766 | 타이포미적용 | 구독정보 섹션 텍스트 4곳 raw `TextStyle`+`AppColors.white` 직접참조 → AppTypography/textInverse | medium |
| C40 | profile_screen.dart | 1095 | 타이포미적용 | `heading5.copyWith(letterSpacing:2)` 리터럴 | low |
| C41 | approval_list_screen.dart | 544 | 리터럴수치(high) | `SizedBox(height:100)` 바텀패딩 — 파일 전체가 토큰 잘 쓰는데 이 줄만 예외 | high |
| C42 | profile_screen.dart | 794,854-855,1444,1519,1643-1644,1715-1716,1876 | 리터럴수치 | `expandedHeight:56`, 프로필이미지`120×120`, `height:100`, 라벨`width:60`×2, 아이콘뱃지`40×40`×2 등 다수 | low |
| C43 | my_vacation_screen.dart | 917-919,925 | 리터럴수치 | `14×14` 다수 → `AppSpacing.space3_5` | low |
| C44 | chat_room_screen.dart | 749,1213,1355-1424,1439,1543 | 리터럴수치 | 아이콘/박스 크기 다수(4,32,12,100,18,20) 토큰 미사용 | low |
| C45 | approval_list_screen.dart | 219,269 | 리터럴수치 | 아이콘 `size:48/64` → space10/space14 | low |
| C46 | chat_room_list_screen.dart | 142,172 | 리터럴수치 | 아이콘 `size:64/48` | low |
| C47 | menu_screen.dart | 197,230 | 리터럴수치 | `CircleAvatar(radius:24)`,`Icon(size:18)` (197은 C25 SeedAvatar 전환 시 자연 해소) | low-medium |
| C48 | chat_room_info_screen.dart | 174-186 | one-surface 위반 | 프로필정보 블록·탭바가 모두 흰색이며 사이 구분선 없음 | medium |
| C49 | chat_room_screen.dart | 547-635 vs 183-190 | 일관성 | 메시지옵션/첨부옵션 바텀시트 스타일(배경/상단라운드) 불일치 | medium |
| C50 | chat_room_screen.dart | 1049-1059 | 스타일일관성 | "채팅 삭제"(파괴적) 메뉴가 plain Text, red강조/아이콘 없음 — 다른 삭제액션(616-624)과 톤 불일치 | low |
| C51 | calendar_screen.dart | 326,435 | 시맨틱오용(경미) | 토요일 색상에 브랜드강조색(`interactivePrimaryDefault`) 재사용 — 의미 혼용 | low |
| C52 | profile_screen.dart | 1172,1200,1223,1271 | 토큰사용방식 | 구분선에 `AppSemanticColors.*` 대신 `AppColors.transparent`(raw 팔레트) 직접 참조 | low |
| C53 | menu_screen.dart / my_vacation_screen.dart / chat_room_list_screen.dart / calendar_screen.dart | — | 준수 확인 | 하드코딩 `Colors.*`/raw hex 없음 — 색상 토큰화 자체는 양호 | — |

**파일별 한줄평**: `chat_room_list_screen.dart`가 9개 중 가장 깨끗함(critical 오용·레거시·하드코딩 전무). `calendar_screen.dart`는 색상은 양호하나 카드중첩 2곳(high) + 등록 모달 raw Material 필드 다수가 문제. `create_chat_room_screen.dart`가 이 그룹에서 문제 최다(AppBar 풀칼라+positive액션 정책위반+raw리스트, 전부 high/medium). `profile_screen.dart`는 로그아웃 버튼 red 오용(high)과 status 토큰 장식용 오남용이 핵심.

### 그룹 D — 공지/플라자/결제/인증 화면 ✅ 조사 완료

**핵심 발견(그룹A와 교차 확인됨)**: 이 9개 파일 자체에는 critical 오남용(반려/거절에 빨강)이 **없다** — 오히려 반대 문제: `notice_detail_screen.dart`·`plaza_post_detail_screen.dart`의 삭제 확인이 공용 `AppDialog.showConfirm`(=그룹A에서 발견한 shadcn 기반 구컴포넌트, app_dialog.dart)을 경유해 **진짜 삭제인데도 critical 스타일이 전혀 적용 안 됨**. `register_screen.dart`는 9개 중 잔재 최다(체크리스트가 "다른 작업자 편집중이라 스냅샷만"이라 명시한 파일, 실제 상당부분 미완료).

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| D1 | notice_detail_screen.dart | 100-106 | **구컴포넌트(high, 공용파급)** | 댓글삭제 확인이 `AppDialog.showConfirm` 경유 → 내부 `shadcn.OutlineButton/PrimaryButton` 렌더(=그룹A A34와 동일 근본원인). `confirmVariant`도 없어 critical 지정 불가 | high |
| D2 | plaza_post_detail_screen.dart | 87-93 | **구컴포넌트(high)** | 게시글 삭제 확인 동일 이슈(D1과 동일 근본원인) | high |
| D3 | login_screen.dart | 185-191 | 구컴포넌트 | 비밀번호찾기 다이얼로그 이메일 입력에 레거시 `AppInput` — 본문 폼은 SeedTextField(L340,360) 사용, 다이얼로그만 불일치 | medium |
| D4 | login_screen.dart | 619-642, 495, 539 | 리터럴수치 | 구분선 `height:12`, 아이콘 `size:20` 등 스케일값인데 리터럴 | low |
| D5 | notice_detail_screen.dart | 313-314,413-414,531-532,539-540,606-607,767 | 리터럴수치 | 아바타/전송버튼/원형아이콘 `width/height`(28/24/36/16/40/64) 스케일값 미토큰화 | low |
| D6 | notice_list_screen.dart | — | 준수 확인 | 위반 없음 — 9개 중 가장 깨끗 | — |
| D7 | payment_screen.dart | 136-137 | 리터럴수치 | 플랜아이콘 `50×50` — AppSpacing 스케일(48/52) 어디에도 없는 임의값 | medium |
| D8 | payment_screen.dart | 303-304,629-630 | 리터럴수치 | 결제수단아이콘`40×40`(space10), 성공배지`80×80`(space20) 미토큰화 | low |
| D9 | payment_screen.dart | 297 | 기타 | 선택된 결제수단 카드 `border width:2` — "정적 컨테이너 1px 보더" 원칙과 어긋남 | low |
| D10 | plaza_post_detail_screen.dart:240, plaza_screen.dart:534,891 | — | **토큰오용(spacing→radius)** | `BorderRadius.circular(AppSpacing.space3)` — 그룹A A3/A27과 동일 패턴, 전역 반복 이슈로 보임 | medium |
| D11 | plaza_post_detail_screen.dart | 133-136 | 참고 | 게시글삭제 `IconButton(delete_outline)` — SeedButton 대상은 아니나 유일 삭제 진입점치고 시인성 약함 | low |
| D12 | plaza_screen.dart | 190,463,835 | 리터럴수치 | 카테고리 칩바 `height:48`(=space12) 리터럴, 3개 탭 공통 | low |
| D13 | plaza_screen.dart | 563,570 | 리터럴수치 | 핀/채택 아이콘 앞 `width:4` → space1 | low |
| D14 | plaza_screen.dart | 768-779 | 구컴포넌트 | 자료업로드 시트 파일선택 버튼 raw `OutlinedButton.icon` — 같은 시트 다른 버튼은 SeedButton | medium |
| D15 | signature_manage_screen.dart | 145-153 | **버튼정책위반+구컴포넌트(high)** | "서명 삭제"가 SeedButton 아닌 raw `TextButton.icon`+수동 `statusErrorIcon` 색상 지정 — 진짜 critical 대상인데 컴포넌트 표준 밖이라 정책 변경에 반영 안 됨. `SeedButton(critical, small)`로 교체 | high |
| D16 | signature_manage_screen.dart | 150-152 | 타이포미적용 | 위 버튼 라벨 raw `fontSize:13`(스케일 밖 값) | medium |
| D17 | signature_manage_screen.dart | 130,162,125 | 토큰오용/리터럴 | `BorderRadius.circular(AppSpacing.space3)`(D10과 동일패턴), 미리보기 `height:130`(스케일 밖) | low |
| D18 | subscription_check_screen.dart | 182-183,527 | 리터럴수치 | 환영섹션 원 `80×80`(토큰화가능), 성공다이얼로그 원 `60×60`(**스케일에 없는 값**) | medium |
| D19 | subscription_check_screen.dart | 242-255 | 기타 | `_buildPlanCard`가 raw Material `Card`(그림자 없음, 위반은 아니나) — 타 화면은 Container+border 패턴 통일, 이 화면만 예외 | low |
| D20 | subscription_check_screen.dart | 246-254 | 기타 | 인기플랜 카드 `BorderSide(width:2)` — D9와 동일 패턴 | low |
| D21 | register_screen.dart | 587-695 | 리터럴수치 | 가입절차 안내 카드 전체(SizedBox/EdgeInsets/BorderRadius 다수) AppSpacing/AppBorderRadius 미사용 | medium |
| D22 | register_screen.dart | 572,582,608-613 | **타이포미적용(high)** | 헤더가 `Theme.of(context).textTheme.headlineMedium/bodyMedium`(Flutter 기본 테마) 사용 — AppTypography 완전 미사용 | high |
| D23 | register_screen.dart | 577,1430,1762 | 레거시토큰 | `Constants.smallPadding/largePadding` — Seed 이전 레거시 상수 클래스, AppSpacing로 전환 필요 | medium |
| D24 | register_screen.dart | 691-855 | 리터럴수치+타이포미적용 | "가입 유형 선택"(관리자/직원) 카드 2개: padding/radius/border/아이콘/라벨 6곳 전부 raw | medium |
| D25 | register_screen.dart | 901-1057 | 리터럴수치+타이포미적용 | "회사 연결 방식" 카드 2개 동일 패턴 반복 | medium |
| D26 | register_screen.dart | 1090-1300 | 리터럴수치+구컴포넌트 | 회사선택/역할선택/기본분류 `DropdownButtonFormField` 3곳 — radius 리터럴 다수+항목텍스트 raw | medium |
| D27 | register_screen.dart | 1433-1761 | **리터럴+타이포(high, 사실상 미마이그레이션)** | "약관 동의" 섹션 전체 — padding/radius/체크인디케이터/라벨 9곳 전부 raw, 사실상 미이관 상태 | high |
| D28 | register_screen.dart | 1791-1821 | 구컴포넌트 | 회원가입 에러배너 직접 Container 구현 — login_screen은 동일용도에 `SeedCallout(danger)` 사용, 통일 필요 | medium |
| D29 | register_screen.dart | 254,290 | 구컴포넌트 | 가입대기 안내 다이얼로그에서 `AppStatusCard`(app_card.dart, 그룹E E10과 동일 레거시) 2곳 사용 | medium |
| D30 | register_screen.dart | 1838-1884 | 죽은코드 | `_buildProcessStep` 호출부 없음(죽은 코드, 리터럴 포함하나 미사용) | low |
| D31 | register_screen.dart | 1886-1964 | 리터럴+타이포 | `_buildProcessCard`(가입절차4단계): padding/radius/사이즈/텍스트 5곳 raw | medium |
| D32 | register_screen.dart | 1966-1994 | 참고(기능영향없음) | `_getGradientColors`가 그라디언트 클래스명 문자열을 키로 쓰지만 실제로는 단색 렌더링(그라디언트 아님) — 네이밍 오해 소지, 낮은 우선순위 | low |
| D33 | register_screen.dart | 2291 | 타이포미적용 | 주소검색 화면 AppBar 제목 raw TextStyle | low |

**요약**: `login_screen.dart`/`notice_list_screen.dart`는 가장 잘 이관됨. `register_screen.dart`가 이 그룹(및 전체 조사)에서 **잔재 최다** — 그라디언트/그림자/shadcn/`AppButton(` 인스턴스는 없지만 사용자유형·가입방식 선택 카드, 드롭다운 3곳, 약관동의 섹션(사실상 미이관), 절차안내 카드가 전부 raw TextStyle·리터럴·레거시 `Constants.*`·`Theme.of(context).textTheme`로 구성돼 있다. `signature_manage_screen.dart`의 서명삭제 버튼도 critical 대상인데 SeedButton 밖에 있어 즉시 수정 필요.

### 그룹 E — 공용 위젯 ✅ 조사 완료

버튼 색상 정책(승인=brandSolid/반려·취소=neutralOutline·neutralWeak/파괴적=critical) 자체는 이 19개 파일 전체에서 위반 없음 — `admin_vacation_add_dialog.dart`, `update_dialog.dart` 모두 정확히 준수. 대신 **"대면적 색 블록 금지" 원칙 위반**(스낵바 배경에 statusError/statusSuccess 진한색 전체 사용)과 **구 카드 컴포넌트(`AppStatusCard`) 잔존**이 핵심 발견.

| # | 파일 | 라인 | 종류 | 발견 내용과 권장 수정 | 우선순위 |
|---|---|---|---|---|---|
| E1 | widgets/admin_vacation_add_dialog.dart | 82,125,134,173 | **대면적 색 블록** | `SnackBar(backgroundColor: AppSemanticColors.statusErrorIcon)` — 진한 red600을 스낵바 **전체 배경**으로 사용(같은 파일 트리에 옅은배경+보더+텍스트색인 올바른 `AppSnackBar.showError` 존재) → 그것으로 교체 | high |
| E2 | widgets/admin_vacation_add_dialog.dart | 161 | 대면적 색 블록 | 성공 스낵바도 `statusSuccessIcon`(진한 초록) 전체 배경 → `AppSnackBar.showSuccess` 사용 | medium |
| E3 | widgets/admin_vacation_add_dialog.dart | 200 | 매직넘버 | `BoxConstraints(maxWidth:480)` 리터럴, 명명 상수화 권장 | low |
| E4 | widgets/admin_vacation_add_dialog.dart | 214,315 | 매직넘버 | 아이콘 사이즈 `28`/`20` 리터럴 | low |
| E5 | widgets/chat/chat_room_tile.dart | 57-58 | 매직넘버 | 아바타 `52×52` — AppSpacing 스케일(48/56)에 없는 리터럴 | low |
| E6 | widgets/chat/message_bubble.dart | 163-166,171-172 | 매직넘버 | 이미지 로딩/에러 플레이스홀더 `100×100` 리터럴 | low |
| E7 | widgets/chat/message_input.dart | 86-87 | 리터럴→토큰 | 전송버튼 `40×40` — `AppSpacing.space10` 존재하는데 리터럴 | low |
| E8 | widgets/common/app_button.dart | 전체 | 구컴포넌트(죽은코드) | shadcn 기반, **직접 인스턴스화 0건** — 사실상 죽은 코드. `AppButtonVariant`/`Size` enum만 app_dialog.dart/menu_screen.dart/profile_screen.dart/vacation_request_dialog.dart에서 타입으로 재사용 중. 삭제 검토 가능 | low |
| E9 | widgets/common/app_card.dart | 43,80 | 하드코딩색 | `Colors.transparent` raw 2곳 → `AppColors.transparent` | medium |
| E10 | widgets/common/app_card.dart | 전체 | **구컴포넌트(high)** | shadcn.Card 기반. `AppCard(` 직접 사용 0건이나 서브클래스 `AppStatusCard(`가 **profile_screen.dart:212, register_screen.dart:254·290** 3곳에서 실사용 중 — 이 3곳은 여전히 shadcn 카드 렌더링 | high |
| E11 | widgets/common/app_input.dart | 전체 | 아키텍처 중복(정보) | 토큰 위반은 없으나 `SeedTextField`와 별개로 존재, profile_screen/login_screen/app_dialog.dart에서 병행 사용 중 — 후속 통합 검토(디자인 위반은 아님) | low |
| E12 | widgets/common/app_loading.dart | 전체 | 준수 확인 | 위반 없음 | — |
| E13 | widgets/common/app_snackbar.dart | 전체 | 모범 사례 | status 색상을 옅은배경+보더+텍스트로 올바르게 분리 — 다른 파일들이 이걸 안 쓰고 재구현하는 게 문제(E1/E2 참고) | — |
| E14 | widgets/notice/notice_card.dart, notice_priority_badge.dart | — | 준수 확인 | 위반 없음(이전 감사에서 이미 정리됨) | — |
| E15 | widgets/seed/seed_avatar.dart | 29-35 | 리터럴→토큰 | `_diameter` 32/40/56 — 값은 AppSpacing.space8/10/14와 일치하나 토큰 미참조 | low |
| E16 | widgets/seed/seed_callout.dart | 72 | **토큰 오용(spacing→radius)** | `BorderRadius.circular(AppSpacing.space2_5)` — 간격 토큰을 라운드에 전용. `AppBorderRadius`에 10px 매칭 없어 lg(8)로 근사 통일 권장 | medium |
| E17 | widgets/seed/seed_chip.dart | 31,38 | 리터럴→토큰 | `_height`(32/36), `_iconSize`(14/16) 리터럴 | low |
| E18 | widgets/seed/seed_list_cell.dart | 62-63,83 | 토큰오용/리터럴 | leading 아이콘 배경 `36×36` 리터럴 + `BorderRadius.circular(AppSpacing.space2_5)`(spacing→radius 오용, E16과 동일 패턴) | medium |
| E19 | widgets/seed/seed_list_cell.dart | 101,112 | 타이포미적용 | title `fontSize:15`, description `fontSize:13` raw — AppTypography 스케일(14/16)과도 어긋남 | medium |
| E20 | widgets/seed/seed_text_field.dart | 116,129 | 리터럴 | `_minHeight` 52/40, large `_fontSize:15` 일부 리터럴(40은 space10과 일치) | low |
| E21 | widgets/update_dialog.dart | 전체 | 모범 사례 | "나중에"=neutralWeak/"업데이트"=brandSolid 정책 완전 준수, shadcn 없음 | — |
| E22 | widgets/vacation_calendar_widget.dart | 379,536-537,541-544,659,691,693,756,840,900 | 매직넘버 다수 | 패딩/라운드 리터럴 다수(16/20/10/16/8/4/3 등) — 토큰 대응 가능한 것부터 우선 정리 | low |
| E23 | widgets/vacation_calendar_widget.dart | 709,795,1213,1252,1283,1294,1358 | 타이포미적용 | 캘린더 셀/범례/필터 텍스트 `fontSize:4~13` raw 다수(초소형 배지는 스케일 밖이라 불가피할 수 있음) | medium |
| E24 | widgets/vacation_calendar_widget.dart | 1314-1369 | 컴포넌트 중복 | 인원 필터 pill을 `SeedChip` 대신 커스텀 재구현(admin_vacation_add_dialog.dart는 동일 목적에 SeedChip 사용) → 통합 권장 | medium |
| E25 | widgets/vacation_calendar_widget.dart | 677-687,901-909,992-1000,1031-1039,1073-1081 | 그림자(경계) | 선택 셀/휴무자 dot에 BoxShadow 5곳 — 원칙상 정적요소는 보더만이나, 그리드 셀 선택 상태 표현이라는 성격상 이전 감사도 "허용 범위"로 판단. 엄격 적용 시 보더/대비로 대체 가능 | low |
| E26 | widgets/seed/seed_section_header.dart | 42 | 매직넘버 | `SizedBox(height:2)` → `AppSpacing.space0_5` | low |

**참고**: `AppButton(`/`AppCard(` 직접 인스턴스화는 전체 코드베이스에서 0건(죽은 코드)이지만, `AppStatusCard`(AppCard 서브클래스)는 3곳에서 살아있어 배치 제안에 반영 필요(profile_screen.dart, register_screen.dart).

### 그룹 F — 전자결재 양식·미리보기 기능 (커밋 9628417로 완료, 신규 해제) 🔄 조사 중
- 대상: `screens/approval_form_screen.dart`, `screens/approval_template_list_screen.dart`(신규), `screens/approval_template_preview_screen.dart`(신규), `widgets/approval/approval_card.dart`, `widgets/approval/approval_status_badge.dart`, `widgets/approval/document_form_fields.dart`(신규), `widgets/approval/dynamic_form_fields.dart`, `widgets/approval/hwp_editor_view.dart`, `widgets/approval/official_document_view.dart`, `widgets/approval/signature_confirm_sheet.dart`, `widgets/approval/signature_pad.dart`, `widgets/approval/template_card.dart`
- 상태: 🔄 조사 에이전트 실행 중 — 결과 도착 시 갱신

### 조사 제외(여전히 양식작업중, 이번에도 미해제) — 표 대상에서만 제외, 배치 제안에서도 제외
- `lib/screens/approval_detail_screen.dart`
- `lib/screens/hwp_editor_screen.dart`
- `lib/models/approval.dart`

---

## 수정 배치 제안 (최종 — 파일 겹침 없음, 홈 대시보드 최우선)

`SeedButtonVariant.critical` 부당 사용 6건은 이미 수정 완료(3d775cb)라 별도 배치가 필요 없다. 아래 4묶음은 그 후속 발견 사항을 정리한 것이며, 서로 파일이 겹치지 않는다. `approval_form_screen.dart`/`approval_detail_screen.dart`/`widgets/approval/*`/`hwp_editor_screen.dart`/`models/approval.dart`는 모든 배치에서 계속 제외.

### 배치 1 — 홈 대시보드 (최우선, 사용자가 직접 지적한 영역)
`home_screen.dart`, `main_screen.dart`, `widgets/common/app_dialog.dart`, `widgets/common/notification_bell.dart`, `widgets/today_schedule_dialog.dart`, `widgets/vacation_request_dialog.dart`
- 핵심: 헤더 대면적 브랜드블록 재검토(A39), "빠른작업" 섹션 리듬 통일(A40), **`app_dialog.dart` shadcn 완전 제거 + `confirmVariant`를 실제 SeedButton에 반영**(A33-A38, 공용 컴포넌트라 파급 큼 — 이 파일을 먼저 고쳐야 배치2의 D1/D2가 자연히 해소됨), notification_bell/vacation_request_dialog 리터럴·raw TextStyle 정리(A7-A32)

### 배치 2 — "빨강/상태색 대면적 오용" 후속 정리 (critical 정책과 같은 뿌리, 사용자 원 지적과 직결)
`profile_screen.dart`, `menu_screen.dart`, `admin_user_management_screen.dart`, `admin_notice_management_screen.dart`, `widgets/admin_vacation_add_dialog.dart`, `signature_manage_screen.dart`, `chat_room_screen.dart`, `chat_room_info_screen.dart`, `notice_detail_screen.dart`, `plaza_post_detail_screen.dart`
- 핵심: 로그아웃 버튼 red 대면적 블록(C4/C5, profile), 로그아웃 `isDestructive:true`(C8, menu), 가입거부완료 스낵바 red(B15), 공지 스와이프삭제 red 블록(B9), 스낵바 배경 전체 red/green(E1/E2), 서명삭제가 SeedButton 밖(D15), 리액션목록 "닫기"=brandSolid 오용(C9), AppBar 브랜드틸 풀칼라 불일치(C13), 삭제확인이 배치1의 app_dialog 수정에 의존(D1/D2 — **배치1 이후 진행 권장**)

### 배치 3 — 관리자 화면 잔여 토큰화
`admin_company_settings_screen.dart`, `admin_payment_screen.dart`, `admin_vacation_limits_setting_screen.dart`, `admin_vacation_management_screen.dart`, `admin_approval_management_screen.dart`, `admin_unified_approval_screen.dart`
- 핵심: 시맨틱토큰 오용(B3 Border/Background 롤 혼동, B4 Warning/Error 혼동), AppBar 3중강조 슬림화(B18, medium-high), 리터럴 아이콘뱃지/입력폭 다수(B5,B11,B19), 하드코딩 TextStyle(B22)

### 배치 4 — 직원·채팅·공지·플라자·인증 화면 + 공용/Seed 위젯 잔여 (낮은 우선순위 폴리시)
`calendar_screen.dart`, `my_vacation_screen.dart`, `approval_list_screen.dart`, `chat_room_list_screen.dart`, `create_chat_room_screen.dart`, `plaza_screen.dart`, `payment_screen.dart`, `subscription_check_screen.dart`, `register_screen.dart`, `login_screen.dart`, `widgets/chat/chat_room_tile.dart`, `widgets/chat/message_bubble.dart`, `widgets/chat/message_input.dart`, `widgets/common/app_card.dart`, `widgets/common/app_button.dart`, `widgets/common/app_input.dart`, `widgets/notice/notice_card.dart`, `widgets/notice/notice_priority_badge.dart`, `widgets/seed/seed_avatar.dart`, `widgets/seed/seed_callout.dart`, `widgets/seed/seed_chip.dart`, `widgets/seed/seed_list_cell.dart`, `widgets/seed/seed_text_field.dart`, `widgets/seed/seed_section_header.dart`, `widgets/vacation_calendar_widget.dart`
- 핵심: `calendar_screen.dart` 카드중첩 2곳(C14/C15, high) + raw Material 폼필드 다수, `create_chat_room_screen.dart` AppBar 풀칼라+positive액션 정책위반(C6/C12, high), `my_vacation_screen.dart` one-surface 위반(C16, high), `register_screen.dart` 약관동의 섹션 사실상 미이관(D27, high) — 9개 파일 중 잔재 최다, `AppStatusCard`(구 app_card.dart 서브클래스) 잔존 2곳(register_screen.dart:254·290, E10) 정리
- 이미 완료 확인(수정 불필요): `notice_list_screen.dart`, `admin_approval_template_screen.dart`, `admin_notice_form_screen.dart`, `widgets/update_dialog.dart`, `widgets/common/app_loading.dart`, `widgets/common/app_snackbar.dart`(모범사례)

