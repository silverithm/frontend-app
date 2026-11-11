import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// 움직임 토큰 — 시간·곡선·스프링을 한 곳에서 정한다.
///
/// 시간은 [AppTransitions]와 어긋나지 않게, 같은 값이면 그쪽을 가리킨다.
/// 새 값(누름 110·화면 넘김 320·숫자 400·막대 600 등)만 여기서 정의한다.
/// 기준표: frontend-admin/.unlazy/modern-1112/PLAN.md "움직임 (AppMotion)".
///
/// 기기에서 '동작 줄이기'(iOS 동작 줄이기 / Android 애니메이션 삭제)를 켰으면
/// 움직임(이동·크기)은 빼고 짧은 겹침만 남긴다 — [reduceMotion]·[durationOf]를 쓴다.
abstract final class AppMotion {
  // ── 시간 ──────────────────────────────────────────────────────────

  /// 눌러서 0.97로 줄어드는 시간. 돌아올 때는 [pressSpring]을 쓴다.
  static const Duration press = Duration(milliseconds: 110);

  /// 화면 넘김(오른쪽에서 밀려 들어옴). 뒤로 갈 때도 같다.
  static const Duration page = Duration(milliseconds: 320);

  /// 하단 탭 전환(겹쳐 바뀜, fade-through).
  static const Duration tabSwitch = AppTransitions.normal; // 200ms

  /// 목록 한 줄이 떠오르며 나타나는 시간.
  static const Duration listItem = AppTransitions.slow; // 300ms

  /// 목록 줄 사이 시차.
  static const Duration listStagger = Duration(milliseconds: 30);

  /// 시차를 주는 줄 수 — 그 아래 줄은 기다리지 않고 바로 보인다.
  static const int listStaggerMaxItems = 8;

  /// 목록 줄이 떠오르는 거리(아래 12px에서 제자리로).
  static const double listRise = AppSpacing.space3; // 12px

  /// 시트·대화상자 뒤가 어두워지는 시간.
  static const Duration scrim = Duration(milliseconds: 220);

  /// 시트가 올라오는 시간(스프링 기준 길이 — [sheetSpring]).
  static const Duration sheet = AppTransitions.slow; // 300ms

  /// 숫자 세어 올라가기.
  static const Duration number = Duration(milliseconds: 400);

  /// 진행 막대 차오름.
  static const Duration bar = Duration(milliseconds: 600);

  /// 배지가 값이 바뀔 때 톡 튀는 길이(스프링 기준 길이 — [badgeSpring]).
  static const Duration badgePop = AppTransitions.slow; // 300ms

  /// 완료 체크가 그려지는 시간(원 → 체크).
  static const Duration check = AppTransitions.slowest; // 500ms

  /// 줄이 접히며 사라지는 시간.
  static const Duration collapse = AppTransitions.slow; // 300ms

  /// '동작 줄이기'일 때 쓰는 단순 겹침.
  static const Duration fade = AppTransitions.fast; // 150ms

  /// 뼈대(skeleton) 위를 빛이 한 번 지나가는 주기.
  static const Duration shimmer = Duration(milliseconds: 1400);

  // ── 크기·거리 ────────────────────────────────────────────────────

  /// 눌렸을 때 크기.
  static const double pressedScale = 0.97;

  /// 배지가 튈 때 가장 커지는 배율.
  static const double badgePopScale = 1.2;

  /// 화면 넘김 때 뒤 화면이 어두워지는 정도(검정 알파). iOS 기본 넘김과 같은 0x18.
  static const double pageScrimOpacity = 0.094;

  // ── 곡선 ──────────────────────────────────────────────────────────

  /// 들어오는 것 — 빠르게 출발해 천천히 멈춘다(감속).
  static const Curve enterCurve = Curves.easeOutCubic;

  /// 나가는 것 — 천천히 출발해 빠르게 사라진다(가속).
  static const Curve exitCurve = Curves.easeInCubic;

  /// 제자리에서 바뀌는 것(색·겹침·크기).
  static const Curve standardCurve = Curves.easeInOutCubic;

  /// 눌러서 줄어들 때.
  static const Curve pressCurve = Curves.easeOut;

  /// 화면 넘김. CupertinoPageTransition이 안에서 쓰는 곡선과 같다 —
  /// 넘김은 iOS 뒤로 쓸기를 살리려고 그 위젯을 그대로 쓴다(app_page_transitions.dart).
  static const Curve pageCurve = Curves.fastEaseInToSlowEaseOut;

  /// 숫자·막대 — 끝에서 부드럽게 멈춘다.
  static const Curve countCurve = Curves.easeOutQuart;

  // ── 스프링 ────────────────────────────────────────────────────────
  // withDurationAndBounce는 SwiftUI spring(duration:bounce:)와 같은 값을 만든다.
  // bounce 0 = 튀지 않음, 0.3 이상이면 눈에 띄게 튄다.

  /// 누름에서 돌아올 때 — 아주 살짝만 넘친다.
  static final SpringDescription pressSpring =
      SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 280),
    bounce: 0.15,
  );

  /// 시트가 올라올 때 — 넘치지 않고 감속해서 선다.
  static final SpringDescription sheetSpring =
      SpringDescription.withDurationAndBounce(duration: sheet, bounce: 0.0);

  /// 배지가 톡 튈 때.
  static final SpringDescription badgeSpring =
      SpringDescription.withDurationAndBounce(duration: badgePop, bounce: 0.4);

  // ── 동작 줄이기 ───────────────────────────────────────────────────

  /// 기기에서 '동작 줄이기'를 켰는지. MediaQuery가 없으면(테스트 등) 꺼진 것으로 본다.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 평소엔 [normal], '동작 줄이기'면 [reduced](기본 [fade]).
  static Duration durationOf(
    BuildContext context,
    Duration normal, {
    Duration reduced = fade,
  }) =>
      reduceMotion(context) ? reduced : normal;

  /// 움직임(이동·크기·튐)이 들어간 연출을 할지. '동작 줄이기'면 false.
  static bool allowsMovement(BuildContext context) => !reduceMotion(context);
}
