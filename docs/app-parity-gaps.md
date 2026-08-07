# 앱(frontend-app) 기능 격차 조사 — 2026-08-07

백엔드(`api-server`)·관리자 웹(`frontend-admin`)의 2026-08-05 이후 커밋과 앱(`frontend-app`)의 `lib/` 코드를 대조해,
웹/백엔드에는 있는데 앱에 반영되지 않은 기능을 실제 코드(grep 결과·파일:라인) 근거로 판정했다.
**이 문서는 조사 결과이며 `lib/` 코드는 수정하지 않았다.**

조사 대상 커밋:
- 백엔드: `eacaa6d`, `54e0adf`, `ddda634`, `cfdbaaa`/`cdbe5b6`, `9ac9a70`, `bbfe702`/`c291e89`, `d578b5d`, `d1ce9dc`, `b27e613`, `c48d9f4`, `6f17dfd`, `324acb4`, `d9d68a6`(VoiceBox, 8/5 이전 생성이나 최근 변경 이어짐), `e45baca`(직권 승인, 8/4)
- 웹: `6b42eb8`, `736e167`, `cae1496`, `3a4f512`, `0048131`, `278127b`, `5684836`, `1d56050`, `6117848`, `0629f33`, `9d66e9f`, `7cd9f06`, `a29b6ed`, `b413841`

---

## 대조 결과

| # | 기능 | 백엔드 API/필드 | 웹 구현 | 앱 상태 | 근거 | 사용자 영향 | 우선순위 |
|---|---|---|---|---|---|---|---|
| 1 | 장기요양 소식(노인장기요양보험 공지·법령·평가·교육 자동 수집) | `GET /api/v1/external-notices?source=`, source=`LTC_NOTICE`/`LTC_LAW`/`LTC_EVAL`/`LTC_EDU` (`eacaa6d`) | `src/components/ExternalNoticeList.tsx`, `src/lib/externalNoticeApi.ts`, `NoticeManagement.tsx`·`EmployeeNotice.tsx`에 "장기요양 소식" 서브탭 | **없음** | `grep -rn "external-notices\|LTC_NOTICE\|LTC_LAW\|LTC_EVAL\|LTC_EDU\|장기요양" lib` → 0건 | 직원이 앱 공지 탭에서 요양기관 실무 필수 공지(급여기준·법령·평가매뉴얼·교육공지)를 못 본다. 웹 관리자 화면에 접속해야만 확인 가능 | 보통 |
| 2 | 커뮤니티 구인·구직 게시판 (board=`job_offer`/`job_seek`, 연락처 공개범위 `contactInfo`/`contactPublic`) | `PlazaPost.Board.JOB_OFFER/JOB_SEEK`, `POST/PUT /api/v1/plaza/posts`에 `contactInfo`,`contactPublic` 필드 (`54e0adf`, `PlazaController.java:117`) | `src/components/plaza/plazaStore.ts`,`PlazaBoard.tsx`,`PlazaHome.tsx`,`PlazaManagement.tsx`에 구인·구직 반영 | **없음** | `lib/screens/plaza_screen.dart:284-287` `_boards = [free, qna, review]` — job_offer/job_seek 탭 없음. `grep -rn "job_offer\|job_seek\|구인\|구직" lib` → 0건. 글쓰기 폼(`plaza_screen.dart:710-797`)에도 연락처 입력란 없음 | 직원(특히 구인난이 심한 요양보호사 채용)이 앱에서 구인·구직 글을 쓰거나 볼 수 없다. 웹에서만 가능 | 보통 |
| 3 | 결재 양식 대분류(category: 공문·교육·인사 등) | `ApprovalTemplate.category` (`ddda634`), `ApprovalTemplateDTO`/`CreateApprovalTemplateRequestDTO`에 필드 추가 | `ApprovalTemplateManager.tsx` 등에서 분류별 그룹 표시 (관리자 웹) | **없음** | `lib/screens/approval_template_list_screen.dart:52-68` — `ListView.builder`로 전체 템플릿을 평면 나열, category 그룹핑 없음. `grep -n "category" lib/models/approval.dart` → 0건(ApprovalTemplate 모델에 category 파싱 자체가 없음) | 결재 양식이 늘어날수록(공문/교육/인사 등 뒤섞여) 직원이 원하는 양식을 찾기 어렵다. 기능 차단은 아니고 탐색성 저하 수준 | 낮음 |
| 4 | 공문 하단 발신부(시행/접수, 우편번호·주소, 전화·전송·담당자메일, 공개구분) | `ApprovalRequestDTO.documentFooter`(`DocumentFooterDTO`), `Company`에 우편번호·전화·팩스·담당자메일·공개구분 컬럼 (`cfdbaaa`) | `frontend-admin`의 공문 인쇄/미리보기에 발신부 렌더링 (`7cd9f06`) | **없음** | `lib/widgets/approval/official_document_view.dart` 전체(419줄) 검토 — 레터헤드→문서번호→결재란→제목→본문→발신명의(직인)→붙임까지만 있고 발신부 없음. `grep -rn "documentFooter\|DocumentFooter" lib` → 0건 | 앱에서 결재 문서를 열람/인쇄할 때 기관 주소·연락처가 담긴 정식 공문 하단부가 빠진 채 보인다(체험기관 예시값 유출 방지 로직도 앱엔 무관). 실무상 공문은 주로 웹에서 발급하므로 영향은 제한적 | 낮음 |
| 5 | 휴무 "다음 달만 받기" on/off (`nextMonthOnly`) | `VacationDeadlineSetting.nextMonthOnly`, `VacationController` POST/GET `.../deadline-setting`에 `nextMonthOnly` 반영 (`9ac9a70`). 서버가 직원 신청 경로에 재검증 적용 | `VacationForm.tsx`/`vacationGuard.ts`에서 켜지면 배너로 안내, 날짜 클릭 차단, 달력 min/max 제한 (`0629f33`) | **없음** | `grep -rn "deadline" lib/services/api_service.dart` → 0건(마감일 설정 자체를 앱이 조회하지 않음). `grep -rn "nextMonthOnly" lib` → 0건 | 관리자가 "다음 달만 신청받기"를 켜도 앱 화면은 아무 안내 없이 날짜 선택을 허용한다. 직원은 신청 버튼을 누른 뒤에야(서버 400 응답으로) 막힌 이유를 알 수 있고, 에러 메시지도 UI에 맞게 다듬어지지 않았을 가능성이 높다. 휴무 마감일(`deadlineDay`) 자체도 앱은 전혀 조회하지 않아 더 넓은 기존 격차 | 높음 |
| 6 | 자료실 수정(제목/분류/설명) + 이용조건(자유게시판 글 1개 이상 작성자만) | `PUT /api/v1/plaza/library/{itemId}`(`c291e89`), `GET /library/access`, 403 `FREE_POST_REQUIRED`/`LOGIN_REQUIRED` 가드(`bbfe702`) | `PlazaManagement.tsx` 등에 수정 폼 + 이용조건 안내/잠금 UI | **부분** | 자료실 목록·업로드·다운로드는 있음(`lib/screens/plaza_screen.dart:609-940`, `ApiService.getPlazaLibrary/uploadPlazaLibraryItem/plazaLibraryDownloadUrl`). 그러나 (a) 수정 기능 없음 — `grep -n "PUT.*library\|editLibrary\|updateLibrary" lib` → 0건, (b) `library/access` 이용조건 사전 확인/안내 없음 — `grep -rn "library/access\|FREE_POST_REQUIRED" lib` → 0건. 업로드/다운로드 실패 시 그냥 "자료 다운로드에 실패했습니다"(`plaza_screen.dart:697`)만 뜨고 403 사유를 구분해 안내하지 않음 | 자유게시판에 글을 안 쓴 직원이 앱에서 자료를 받으려 하면 원인 모를 실패로만 보인다. 이미 올린 자료의 제목/분류/설명 오타도 앱에서 못 고친다(재업로드해야 함, 이력 초기화) | 보통 |
| 7 | 근무조정 개선 5건: 필수 숙지사항 배너, 마감일 날짜 지정(`deadline-dates`), 일괄 삭제(`bulk-delete`), 중요 행사(`events`), 공휴일 | `VacationPlanningController`: `PUT /api/vacation/bulk-delete`, `GET/POST /api/vacation/deadline-dates`, `GET/POST/PUT/DELETE /api/vacation/events` (`736e167`) | `VacationCalendar.tsx`/`EmployeeCalendar.tsx`에 ★마감일·📌행사 표시, `AdminPanel.tsx`에 일괄삭제, `holidays.ts`로 공휴일 표시, `vacationGuard.ts`의 "휴무 등록 전 필수 숙지 사항" 빨간 배너(관리자·직원·모달 3곳) | **부분(대부분 없음)** | `grep -rln "deadline-dates\|/vacation/events\|bulk-delete\|VacationEvent\|holiday\|공휴일" lib` → 0건. 필수 숙지사항 문구만 앱에 남아 있으나 옛 버전 — `lib/widgets/vacation_request_dialog.dart:96-101` "신청 전 확인해 주세요"(4개 항목, 회색 박스)로, 웹의 "휴무 등록 전 필수 숙지 사항"(빨간 Banner, 다른 4개 문구, `src/lib/vacationGuard.ts:9,29-34`)와 제목·강조·문구가 다름. 일괄 삭제는 앱에 승인대기 건 일괄 승인/거절만 있고(`admin_vacation_management_screen.dart:395-411`) 삭제 자체가 없음 | 직원은 앱 달력에서 이번 달 마감일이 며칠인지(★표시), 중요 행사(📌)가 있는지, 공휴일이 언제인지 전혀 볼 수 없다 — 이는 매일 쓰는 휴무 신청 화면의 핵심 컨텍스트다. 관리자도 앱에서 승인된 휴무를 포함한 일괄 삭제를 할 수 없다(웹으로 가야 함) | 높음 |
| 8 | 직권 승인(전결)/직권 반려 — `force` 파라미터, 남은 결재 단계 경고 | `ApprovalRequestController` approve/reject에 `force`(boolean, default false) 파라미터 (`e45baca`, `ApprovalRequestController.java:230,270`) | `ApprovalManagement.tsx:83-91` 남은 단계 경고 다이얼로그, `:218,235,629` `force:true` 전달, 버튼 라벨을 "직권 승인/직권 반려"로 전환 | **없음** | `lib/services/api_service.dart:2052-2081` `approveApprovalRequest`에 force 파라미터 자체가 없음. `lib/screens/admin_approval_management_screen.dart:228-234` `_isActionable`가 "내 차례일 때만 처리 가능"으로 되어 있고 `:891` "다른 결재자님의 차례입니다"만 표시 — 우회 UI 없음 | 관리자 역할 직원이 앱에서는 본인 차례가 아닌 결재 건을 급한 경우에도 대신 처리(전결)할 수 없다. 반드시 웹으로 가야 한다 | 보통 |
| 9 | 고충·신고/건의함(VoiceBox) | `POST/GET/PATCH /api/v1/voice-box` (`VoiceMessageController.java`, `d9d68a6`) | `VoiceBoxAdmin.tsx` 등 관리자 처리 화면 + 직원 제출 화면 (`0629f33`에서 안내 배너만 제거) | **없음** | `grep -rln "voice-box\|VoiceBox\|voiceBox\|고충\|건의함" lib` → 0건 | 직원이 앱에서 고충·신고나 건의사항을 제출할 방법이 아예 없다. 익명 제출 등 민감한 용도로 만들어진 기능인데 접근 채널 자체가 없는 것은 실질적 기능 부재 | 높음 |
| 10 | "광장" → "커뮤니티" 명칭 변경 | (프론트 전용, 백엔드 무관) | `frontend-admin` 전반에서 "커뮤니티"로 통일 | **반영됨(격차 아님)** | 사용자 노출 문구는 이미 "케어브이 커뮤니티" — `lib/screens/home_screen.dart:535`, `lib/screens/menu_screen.dart:112`, `lib/screens/plaza_screen.dart:52`. "광장"은 `plaza_screen.dart:23` 등 코드 주석·클래스명(`PlazaScreen`)에만 남아 있고 사용자에게는 노출되지 않음 | 없음 (내부 명명만 구식, UI 텍스트는 이미 최신) | — |
| 11 | 오늘의 동기부여 인사말(날짜별 로테이션, 노인인권/학대예방 문구 포함) | (프론트 전용) | `src/lib/dailyGreeting.ts` — 연중 일수 기준 30개 문구 로테이션 (동기부여 15 + 노인인권·학대예방 15) | **없음** | `grep -n "인사말\|greeting\|Greeting" lib/screens/home_screen.dart` → 0건. 앱 홈 화면은 `home_screen.dart:390` `'${user.name}님, 반갑습니다.'` 고정 문구만 표시 | 직원이 매일 앱을 열 때 동기부여 문구나 노인학대 예방 안내(신고전화 1577-1389 등)를 못 본다. 웹 대시보드에만 노출되는데 정작 현장 직원은 앱을 주로 씀 — 홍보 효과가 큰 채널이 비어 있음 | 보통 |
| 12a | 회원 프로필 사진(증명사진) 업로드/삭제 | `POST/DELETE /api/v1/members/{id}/profile-image` (`6f17dfd`) | `1d56050`에서 프로필 사진 업로드 UI + 채팅/회원목록 아바타 노출 | **부분** | 앱은 `profileImageUrl`을 받아 **표시만** 한다 — `lib/screens/profile_screen.dart:851-866`(Hero + Image), `lib/widgets/seed/seed_avatar.dart`, `lib/models/chat_participant.dart` 등. `grep -n "profile-image" lib/services/api_service.dart` → 0건(업로드/삭제 API 호출 자체가 없음) | 직원이 앱(주로 휴대폰 카메라를 쓰는 채널)에서 본인 증명사진을 찍어 올리거나 지울 수 없다. 웹에 접속해야만 프로필 사진을 바꿀 수 있음. 다만 `profile_screen.dart`는 현재 다른 에이전트가 작업 중이므로 실제 구현은 그 작업 완료 후 진행 필요 | 보통 |
| 12b | 커뮤니티 리치 텍스트 글쓰기(HTML 저장, DOMPurify 소독) | 광장 글 `content`가 HTML로 저장됨 (`6117848`) | `PlazaBoard.tsx` 등에서 리치 에디터로 작성 + HTML로 렌더 | **없음(표시 버그 유발)** | 앱은 `content`를 그대로 `Text` 위젯에 출력 — `lib/screens/plaza_post_detail_screen.dart:168` `Text(post['content']?.toString() ?? '')`. HTML 파서/렌더러 없음 | 웹에서 굵게·색상 등 서식을 넣어 쓴 글이 앱에서는 `<p>`,`<strong>` 같은 HTML 태그가 그대로 텍스트로 보인다 — 가독성 저하를 넘어 "앱이 고장난 것처럼" 보이는 표시 버그 | 보통 |

---

## 요약

- 총 대조 기능: 12건 (지정 11건 + 조사 중 발견 2건, #12a/#12b)
- **격차 없음**: 1건 (#10, 명칭은 이미 최신)
- **누락(없음/부분)**: 11건
- **우선순위 높음**: #5(휴무 다음 달만 제한), #7(근무조정 개선 5건 — 특히 마감일 지정·중요행사·공휴일), #9(VoiceBox 고충·건의함)
- **우선순위 보통**: #1(장기요양 소식), #2(구인구직 게시판), #6(자료실 수정·이용조건), #8(직권 승인), #11(오늘의 인사말), #12a(프로필 사진 업로드), #12b(리치텍스트 렌더링)
- **우선순위 낮음**: #3(양식 대분류), #4(공문 발신부)

---

## 구현 배치 제안 (파일 겹치지 않게 4묶음)

### 배치 A — 휴무(Vacation) 컨텍스트 보강 [우선순위 높음, 규모: 중~대 (3~4일)]
휴무 신청은 앱에서 가장 자주 쓰이는 화면이라 우선순위가 가장 높다.
- `nextMonthOnly` 가드 + 배너, 마감일 조회(`deadlineDay` 자체도 앱에 없음 — 함께 처리), 월별 마감일 지정(`deadline-dates`, ★표시), 중요 행사(`events`, 📌배지), 공휴일 표시, 필수 숙지사항 배너 문구/스타일을 웹과 통일
- 대상 파일: `lib/widgets/vacation_request_dialog.dart`, `lib/screens/my_vacation_screen.dart`, `lib/widgets/vacation_calendar_widget.dart`, `lib/providers/vacation_provider.dart`(신규 provider 필요할 수 있음), `lib/services/api_service.dart`(엔드포인트 추가), 신규 `lib/models/vacation_event.dart` 등
- `admin_vacation_management_screen.dart`의 일괄 삭제는 관리자 전용이라 이 배치에서 곁가지로 함께 처리 가능(작업량 소폭 증가)

### 배치 B — 커뮤니티(Community) 확장 [우선순위 보통, 규모: 대 (1주 이상)]
- 구인·구직 게시판(board 추가 + 연락처 공개범위 UI), 자료실 수정 폼 + 이용조건 가드/안내, 리치텍스트(HTML) 렌더링(예: `flutter_html`로 표시만), 장기요양 소식 신규 탭 신설
- 대상 파일: `lib/screens/plaza_screen.dart`, `lib/screens/plaza_post_detail_screen.dart`, 신규 `lib/screens/external_notice_list_screen.dart`(또는 공지 탭에 통합), `lib/services/api_service.dart`
- 배치 A와 `api_service.dart`를 공유하므로 순서상 병렬 진행 시 해당 파일만 조율 필요(엔드포인트 함수 단위라 실질 충돌은 적음)

### 배치 C — 결재(Approval) 보강 [우선순위 보통~낮음, 규모: 중 (3~4일)]
- 양식 대분류(category) 그룹핑, 공문 하단 발신부 렌더링, 직권 승인/반려(force) UI + API
- 대상 파일: `lib/screens/approval_template_list_screen.dart`, `lib/models/approval.dart`, `lib/widgets/approval/official_document_view.dart`, `lib/screens/admin_approval_management_screen.dart`(또는 `admin_unified_approval_screen.dart`), `lib/services/api_service.dart`

### 배치 D — 프로필·건의함(Profile & VoiceBox) [우선순위 높음~보통, 규모: 중 (2~3일)]
- VoiceBox(고충·신고/건의함) 신규 화면, 오늘의 인사말 로테이션 동기화, 프로필 사진 업로드/삭제
- 대상 파일: 신규 `lib/screens/voice_box_screen.dart`, `lib/screens/home_screen.dart`(인사말), `lib/screens/profile_screen.dart`(프로필 사진 업로드/삭제)
- **주의**: `lib/screens/profile_screen.dart`와 `lib/widgets/common/app_dialog.dart`(및 그 호출처)는 현재 다른 에이전트가 수정 중 — 이 배치의 프로필 사진 부분은 해당 작업 완료 확인 후 착수할 것
