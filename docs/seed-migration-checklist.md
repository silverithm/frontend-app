# Seed 이식 전수 체크리스트
갱신: 2026-08-06
## 사용법: 파일별로 전환 완료 시 [x] 표시. 발견 항목이 모두 해소되면 완료.

감사 범위: `lib/screens/*.dart` 전체(33개) + `lib/widgets/`(common/, approval/, seed/ 제외, 실질 파일 10개 — `widgets/chat/index.dart`, `widgets/notice/index.dart`는 3줄 export 배럴이라 감사 대상에서 제외).
감사 방법: grep으로 위치 특정 후 정독(context 확인)으로 판정. docs/seed-foundations.md(레이아웃/스페이싱/라운드/그림자 원칙) + docs/seed-component-specs.md(컴포넌트 스펙) 기준.

**중요 정정**: 초기 광범위 grep은 `Colors\.` 패턴이 `AppSemanticColors.*`/`AppColors.*`(정상 토큰 클래스)까지 오탐지했다. 정밀 재검증(`[^a-zA-Z.]Colors\.`) 결과 순수 Flutter `Colors.*` 하드코딩은 코드베이스 전체에서 사실상 없음(예외 3곳만, 아래 표에 명시). 색상 토큰화는 이미 전면적으로 잘 되어 있고, 남은 잔재는 주로 **그라디언트 / 정적 컨테이너 그림자 / 구 버튼(shadcn·AppButton) / 칩 패턴 / 임의 radius·padding 리터럴**에 집중되어 있다.

| # | 파일 | 상태 | 남은 잔재 (종류: 위치 대략) |
|---|---|---|---|
| 1 | screens/admin_approval_management_screen.dart | [ ] | shadcn버튼: L268,272,334,338,408,412,710,727,947,955 (OutlineButton/PrimaryButton/DestructiveButton, 승인/반려 포함) / shadcn.AlertDialog: L82,240,325,388 / `_buildStatusFilterChip` 5곳(L573-579, 칩 스타일 커스텀 위젯) / radius리터럴 7곳 |
| 2 | screens/admin_approval_template_screen.dart | [ ] | shadcn버튼 5곳(PrimaryButton/OutlineButton/GhostButton/DestructiveButton)+AlertDialog / radius9·padding7 리터럴 |
| 3 | screens/admin_company_settings_screen.dart | [ ] | **그라디언트+정적그림자**: L82-104 "회사 정보 카드"(LinearGradient+BoxShadow blurRadius20), L505-518 "로그아웃 섹션"(BoxShadow) / shadcn버튼 13곳+AlertDialog / radius18·padding13 리터럴 |
| 4 | screens/admin_notice_form_screen.dart | [x] | 그라디언트/그림자/shadcn/AppButton/칩/radius·padding 리터럴 전부 0. 완료 상태 |
| 5 | screens/admin_notice_management_screen.dart | [ ] | shadcn버튼 6곳+AlertDialog / `_buildFilterChip` 6곳(L521-598, 칩 UI 패턴 잔존) |
| 6 | screens/admin_payment_screen.dart | [ ] | **그라디언트+정적그림자**: L94-113 `_buildPlanSummary`(LinearGradient+BoxShadow blurRadius20) / shadcn버튼 3곳+AlertDialog / radius9·padding8 리터럴 |
| 7 | screens/admin_unified_approval_screen.dart | [x] | 단순 TabBar 셸(하위 화면에 위임). 전 카테고리 0. 완료 상태 |
| 8 | screens/admin_user_management_screen.dart | [ ] | shadcn버튼 14곳(ButtonSize 포함)+AlertDialog / **제목 중복**: AppBar 타이틀 "회원 관리"(L62 부근)와 헤더 블록 내부 텍스트 "회원 관리"(L118 부근)가 동일 문구 반복 / radius4·padding2 리터럴 |
| 9 | screens/admin_vacation_limits_setting_screen.dart | [ ] | **정적그림자**: "월 선택 헤더" Container(L308-320), "일별 카드"(L505-520) 모두 BoxShadow / shadcn.PrimaryButton 1곳 / radius9·padding10 리터럴 |
| 10 | screens/admin_vacation_management_screen.dart | [ ] | **최대 잔재 파일(66KB, 1770줄)**: shadcn버튼 17곳+AlertDialog / `_buildStatusFilterChip`/`_buildRoleFilterChip`/`_buildSortFilterChip` 등 칩 패턴 14곳 / Card( 계열 5곳 — 카드 중첩 의심(확인 필요) / **죽은 코드 의심**: `_buildVacationList()`(L473) 정의는 있으나 파일 내 호출부가 전무(자기 정의만 매칭) — 리팩터 후 잔존한 미사용 메서드로 추정, 삭제 검토 필요 / radius10·padding10 리터럴 |
| 11 | screens/approval_detail_screen.dart | [ ] | **승인/반려 확인 다이얼로그**: shadcn.OutlineButton/shadcn.DestructiveButton(L132,136) + shadcn.AlertDialog(L92) / radius5·padding2 리터럴 |
| 12 | screens/approval_form_screen.dart | [~] | shadcn.PrimaryButton 1곳만. 그 외 그라디언트/그림자/칩/AppButton 0 |
| 13 | screens/approval_list_screen.dart | [~] | shadcn.PrimaryButton 1곳만. radius4·padding5 리터럴 |
| 14 | screens/calendar_screen.dart | [ ] | **초대형 파일(83KB), 대부분 토큰화 완료되었으나 일부 잔재 남음**: raw TextButton L767,776 + raw ElevatedButton L1862(등록 버튼) / **정적그림자**: L1148-1158 "하단 통계 섹션"(관리자 전용, BoxShadow) — 단 날짜 그리드 셀 자체의 인라인 스타일(위치·색상 계산)은 프로젝트 관례상 정상이며 대부분 AppSpacing/AppSemanticColors 토큰 사용 중 |
| 15 | screens/chat_room_info_screen.dart | [ ] | shadcn버튼 6곳(OutlineButton/DestructiveButton)+AlertDialog |
| 16 | screens/chat_room_list_screen.dart | [~] | shadcn.PrimaryButton 1곳만(빈 상태 액션으로 추정) |
| 17 | screens/chat_room_screen.dart | [ ] | **정적그림자**: `_buildMessageInput` 하단 입력바 Container(L1443-1459, BoxShadow blurRadius10) — widgets/chat/message_input.dart와 완전히 동일한 구조를 중복 구현 / shadcn버튼 5곳+AlertDialog |
| 18 | screens/create_chat_room_screen.dart | [ ] | shadcn.GhostButton 3곳 |
| 19 | screens/home_screen.dart | [x] | 카드중첩 해소 완료: `_SectionCard`를 shadcn.Card→평평한 흰 표면(borderSubtle 1px+xl2 라운드)으로 교체(shadcn 의존 제거). `_DashboardMetricCard` 4타일은 틴트+보더 카드→아이콘 칩+숫자+라벨 평면 블록. `_NoticePreviewTile`/`_SchedulePreviewTile`/`_EmptySectionState`는 개별 보더 컨테이너→구분선(Divider) 리스트 아이템. `_SectionHeader`의 "전체보기" TextButton은 유지하되 styleFrom으로 토큰화. analyze 0. |
| 20 | screens/hwp_editor_screen.dart | [x] | raw AppColors 팔레트(teal600/teal50/teal700/teal500/gray100/gray500/gray400/red500)를 AppSemanticColors로 전환, 헤더/배너/로딩/에러 TextStyle 리터럴을 AppTypography로, 패딩 리터럴을 AppSpacing으로 토큰화. 저장 버튼(TextButton.icon)과 재시도 버튼(OutlinedButton)을 SeedButton으로 교체. analyze 0. |
| 21 | screens/login_screen.dart | 다른 작업자 진행 중 | 현재 스냅샷: shadcn버튼 2곳(OutlineButton/PrimaryButton)+AlertDialog, 그림자/그라디언트 0, Seed 컴포넌트(SeedButton 등) 8곳 사용 중 — 마이그레이션 상당 부분 진행됨 |
| 22 | screens/main_screen.dart | [~] | 하단 탭 셸, 자체 AppBar 없음(양호, 이중헤더 없음) / 배지로 추정되는 radius12(L231)+padding(L246, horizontal:4/vertical:1) 리터럴 소수 |
| 23 | screens/menu_screen.dart | [x] | Seed 컴포넌트 5곳 사용, 그 외 전 카테고리 0(초기 광범위 grep의 "AppButton" 1건은 실제 인스턴스화 없는 오탐으로 확인됨). 완료 상태 |
| 24 | screens/my_vacation_screen.dart | [x] | radius/padding 리터럴 전면 AppSpacing/AppBorderRadius 토큰화 완료. shadcn.OutlineButton/DestructiveButton/PrimaryButton 3곳 모두 SeedButton으로 교체, shadcn.AlertDialog(삭제 확인)는 AppDialog.showCustom+SeedButton 조합으로 교체, 카드 속 장식 박스(신청 현황/상태 배지 등) 라운드·간격 토큰화. 빈 상태 문구 "아직 휴무 신청 내역이 없어요" 톤 유지. analyze 0(info 3건은 기존부터 있던 async-context 패턴, 로직 변경 없음). |
| 25 | screens/notice_detail_screen.dart | [ ] | shadcn버튼 3곳(PrimaryButton/OutlineButton/DestructiveButton)+AlertDialog / radius6 리터럴 |
| 26 | screens/notice_list_screen.dart | [~] | shadcn.PrimaryButton 1곳만 |
| 27 | screens/payment_screen.dart | [ ] | **그라디언트+정적그림자**: `_buildPlanSummary`(L120-139, admin_payment_screen.dart와 거의 동일한 코드 — LinearGradient+BoxShadow) / shadcn버튼 3곳+AlertDialog / radius8·padding7 리터럴 |
| 28 | screens/plaza_post_detail_screen.dart | [~] | raw TextButton 2곳(L92,95, 삭제 확인 다이얼로그) / raw Colors.red 2곳(L97,190) |
| 29 | screens/plaza_screen.dart | [~] | raw ElevatedButton 2곳(L427,802) / Seed 컴포넌트 4곳 이미 사용 중 |
| 30 | screens/profile_screen.dart | [ ] | **초대형 파일(73KB), 잔재 다수**: shadcn버튼 4곳(AlertDialog/GhostButton/OutlineButton/PrimaryButton)+shadcn.Card 4곳 / 구 AppButton 5곳 / Card( 계열 4곳 — 카드 중첩 의심(확인 필요) / radius19·padding15 리터럴 |
| 31 | screens/register_screen.dart | 다른 작업자 진행 중 | 현재 스냅샷: 그라디언트 3곳+정적그림자 4곳(L603,681,1973,2025)+shadcn버튼 2곳+구 AppButton 2곳, Seed 컴포넌트(SeedButton 등) 9곳 사용 — 초대형 파일(112KB), 마이그레이션 중간 단계 |
| 32 | screens/signature_manage_screen.dart | [~] | raw ElevatedButton 1곳(L189) / raw Colors.white 1곳(L127) |
| 33 | screens/subscription_check_screen.dart | [ ] | **그라디언트 5곳(감사 대상 중 최다)+정적그림자 2곳** — 구독/결제 안내 화면, 프로모션 스타일 잔존 / shadcn버튼 3곳+AlertDialog |
| 34 | widgets/admin_vacation_add_dialog.dart | [~] | 다이얼로그(자체 그림자는 정상 범위). shadcn.GhostButton/PrimaryButton 2곳(footer 액션) |
| 35 | widgets/today_schedule_dialog.dart | [~] | 다이얼로그(자체 그림자 정상 범위). shadcn.OutlineButton/PrimaryButton 2곳 |
| 36 | widgets/update_dialog.dart | [~] | 소형 유틸리티 다이얼로그(강제 업데이트 안내, 노출 빈도 낮음). shadcn.AlertDialog+GhostButton+PrimaryButton |
| 37 | widgets/vacation_calendar_widget.dart | [~] | 그림자 7곳 — 대부분 캘린더 셀/상태점(dot)의 구조적 장식(선택 상태, 휴무유형 표시)으로 프로젝트 관례상 허용 범위. 단 L1348,1355(선택된 인원 필터 pill류)는 정적 그림자로 의심되어 확인 필요. 그라디언트/shadcn버튼/칩 없음 |
| 38 | widgets/vacation_request_dialog.dart | 다른 작업자 진행 중 | 현재 스냅샷: `Color(0x..)` 하드코딩 3곳(L52,57,65 — 다이얼로그 자체 그림자 상수 정의, 그림자 5곳도 여기서 파생되어 다이얼로그 스코프로는 허용 범위) / 구 AppButton 1곳 / Seed 컴포넌트 2곳 사용 중 |
| 39 | widgets/chat/chat_room_tile.dart | [x] | 전 카테고리 0, radius/색상 모두 AppBorderRadius·AppSemanticColors 토큰 사용. 완료 상태 |
| 40 | widgets/chat/message_bubble.dart | [x] | 전 카테고리 0, 말풍선 radius도 AppBorderRadius 토큰 사용(꼬리 반대쪽 xl, 꼬리쪽 base). 완료 상태 |
| 41 | widgets/chat/message_input.dart | [ ] | **정적그림자**: 하단 고정 입력바 Container(L26-38, BoxShadow) — chat_room_screen.dart의 자체 구현(#17)과 동일 패턴 중복 |
| 42 | widgets/notice/notice_card.dart | [~] | radius 리터럴 1곳(L217, `BorderRadius.circular(2)`) 외 대부분 AppBorderRadius/AppSpacing 토큰화 완료 |
| 43 | widgets/notice/notice_priority_badge.dart | [x] | 전 카테고리 0, AppBorderRadius 토큰 사용. 완료 상태 |

---

## 굵직한 옛 스타일 블록 상세

### 1. 홈 대시보드 지표 카드 (`home_screen.dart` `_DashboardMetricCard`, L868-934)
**평가: 이미 잘 전환됨.** `Material`+`InkWell`+`Container`(`BoxDecoration`) 구조이나:
- 그라디언트 없음, 그림자 없음(정적 카드 원칙 준수)
- `BorderRadius.circular(AppBorderRadius.xl)`, `EdgeInsets.all(AppSpacing.space4)` 등 전부 토큰 사용
- 배경/보더는 `metric.color.withValues(alpha: ...)` — 데이터 기반 시맨틱 색상, 하드코딩 아님
- 타이포는 `AppTypography.heading5`/`bodyMedium`/`bodySmall` 사용

**남은 이슈**: `_DashboardMetricCard`를 감싸는 상위 섹션 `_SectionCard`(L798-811)가 여전히 `shadcn.Card`를 사용 — 흰 표면(shadcn.Card) 안에 색상 틴트 보더 카드(`_DashboardMetricCard`, 2x2 그리드)가 들어가는 구조라 **경미한 카드 중첩 우려**가 있음(그림자는 없으므로 심각하지 않으나, `shadcn.Card` 자체를 Seed/Astryx 대응 컴포넌트로 교체 필요). 이 `_SectionCard`는 홈 화면 전체 섹션(공지, 대시보드, 커뮤니티 등)에서 반복 사용되므로 교체 시 영향 범위가 넓다.

### 2. 승인함 계열 승인/반려(거절) 버튼
- `admin_approval_management_screen.dart`: 목록 행(L947-955)과 일괄 처리 바(L710-727) 양쪽에 `shadcn.OutlineButton`(거절)+`shadcn.PrimaryButton`(승인) 페어가 반복 사용됨. 확인 다이얼로그도 `shadcn.AlertDialog`+`shadcn.OutlineButton`/`shadcn.DestructiveButton` 조합(L82-90, 325-340, 388-415).
- `approval_detail_screen.dart`: 상세 화면의 확인 다이얼로그(L92-136)도 동일하게 `shadcn.OutlineButton`/`shadcn.DestructiveButton`.
- `admin_vacation_management_screen.dart`, `admin_approval_template_screen.dart`, `admin_notice_management_screen.dart`, `chat_room_info_screen.dart`, `notice_detail_screen.dart` 등도 동일한 shadcn 확인 다이얼로그 패턴을 반복 사용 — **승인/삭제류 액션 확인 다이얼로그가 전체적으로 shadcn.AlertDialog + shadcn 버튼 조합에 묶여 있어, 이 패턴 하나를 SeedButton/Seed Dialog 조합으로 교체하면 다수 화면에 파급 효과가 있다.**

### 3. 정적 컨테이너 그라디언트+그림자 카드 (반복 패턴)
`admin_company_settings_screen.dart`(회사 정보 카드), `admin_payment_screen.dart`/`payment_screen.dart`(`_buildPlanSummary`)에서 거의 동일한 코드가 반복됨: `LinearGradient`(브랜드색 계열) + `BorderRadius.circular(20)` + `BoxShadow(blurRadius: 20, offset: Offset(0,10))`. 결제/플랜 요약 카드 스타일 하나를 표준화하면 3개 파일이 동시에 해소된다.

### 4. 하단 고정 채팅 입력바 그림자
`chat_room_screen.dart`(`_buildMessageInput`, L1443-1459)와 `widgets/chat/message_input.dart`(L26-38)가 **완전히 동일한 그림자+패딩 구조를 각자 중복 구현**하고 있다. 정적 컨테이너 그림자 규칙 위반이면서 동시에 코드 중복이므로, widgets/chat/message_input.dart 하나로 통합하며 그림자를 제거하는 것이 우선순위다.

---

## 우선순위 작업 큐 (사용자 노출 빈도 높은 순)

1. **admin_vacation_management_screen.dart** — "근무조정" 탭(관리자용, 앱 기본 선택 탭)의 핵심 화면. 감사 대상 중 최다 잔재(shadcn버튼 17, 칩패턴 14, 카드중첩 의심, 죽은 코드).
2. **my_vacation_screen.dart** — "근무조정" 탭(직원용, 기본 선택 탭). 임의 radius/padding 리터럴 최다(20/22).
3. **calendar_screen.dart** — "월간일정" 탭, 초대형 파일이지만 대부분 토큰화되어 있어 나머지 raw 버튼 3곳 + 정적 그림자 1곳만 잡으면 해소.
4. **chat_room_screen.dart** — "채팅" 탭, 메시지 화면은 진입 빈도 최상급. 하단 입력바 그림자(widgets/chat/message_input.dart와 중복) + shadcn 버튼 5곳.
5. **admin_approval_management_screen.dart** — "전자결재" 탭 승인 관리 핵심 화면. 승인/반려 버튼이 shadcn에 묶여 있어 승인 프로세스 전반에 영향.

(다음 순위: profile_screen.dart(정보관리, 잔재량은 상위권이나 노출 빈도는 위 5개보다 낮음) → admin_company_settings_screen.dart / payment_screen.dart / admin_payment_screen.dart(그라디언트·그림자 카드 패턴, 결제 관련) → admin_user_management_screen.dart(제목 중복 포함) / admin_notice_management_screen.dart / chat_room_info_screen.dart / notice_detail_screen.dart / subscription_check_screen.dart / admin_vacation_limits_setting_screen.dart / admin_approval_template_screen.dart 순. 마지막으로 widgets/admin_vacation_add_dialog.dart, widgets/today_schedule_dialog.dart, widgets/update_dialog.dart 등 다이얼로그류의 shadcn 버튼 교체.)

**진행 중 제외 파일**: login_screen.dart, register_screen.dart, widgets/vacation_request_dialog.dart는 다른 작업자가 현재 편집 중이므로 이번 감사에서는 스냅샷 상태만 기록하고 lib/ 코드는 일절 수정하지 않았다.
