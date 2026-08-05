# 당근 Seed 디자인 시스템 — 컴포넌트 스펙 수집

> 출처: https://seed-design.io/components/* (WebFetch로 수집, 2026-08-05)
> 목적: Flutter 앱에 Seed 스타일 컴포넌트를 구현하기 위한 레퍼런스. 브랜드 색(carrot 계열)은 케어브이 틸(`#20C997`)로 치환 예정이므로, 색상은 원본 토큰 이름(`$color.bg.brand-solid` 등)으로 기록했다. 실제 값은 seed-design.io 원본 또는 Figma에서 재확인 필요 — 이 문서는 AI 보조 추출 결과이며 수치 오기가 있을 수 있다.
>
> 표기: `$dimension.xN`은 Seed 스페이싱 스케일(대략 N×2px, 컴포넌트별 실측 필요), `$font-size.tN` / `$line-height.tN`은 타이포 스케일 토큰, `$radius.rN`은 라운드 스케일, `$duration.dN`은 모션 지속시간 스케일이다.

---

## 1. Action Button

**Variant (강조도순):** Brand Solid(High) · Neutral Solid(High) · Critical Solid(High) · Neutral Weak(Medium) · Brand Outline(Low) · Neutral Outline(Low) · Ghost(Low)

| Size | Height | Padding X/Y | Radius | Font-size | Icon |
|---|---|---|---|---|---|
| XSmall | `$dimension.x8` | 3.5 / 1.5 | `$radius.full` | t3 | 3.5(14px) |
| Small | `$dimension.x9` | 3.5 / 2 | `$radius.r2` | t4 | 3.5(14px) |
| Medium | `$dimension.x10` | 4 / 2.5 | `$radius.r2` | t4 | 4(18px) |
| Large | `$dimension.x13` | 5 / 3.5 | `$radius.r3` | t6 | 22px |

Font-weight 전 사이즈 공통: `$font-weight.bold`

**상태별 색상**

| Variant | Enabled BG | Pressed BG | Disabled BG | Text/Icon |
|---|---|---|---|---|
| Brand Solid | `$color.bg.brand-solid` | `$color.bg.brand-solid-pressed` | `$color.bg.disabled` | `$color.palette.static-white` (disabled: `$color.fg.disabled`) |
| Neutral Solid | `$color.bg.neutral-inverted` | `$color.bg.neutral-inverted-pressed` | `$color.bg.disabled` | `$color.fg.neutral-inverted` |
| Critical Solid | `$color.bg.critical-solid` | `$color.bg.critical-solid-pressed` | `$color.bg.disabled` | `static-white` |
| Outline (Brand/Neutral) | `$color.bg.transparent` (border `$color.stroke.neutral-muted` 1px) | `$color.bg.transparent-pressed` | transparent (border 유지) | `$color.fg.neutral` |
| Loading | Solid의 pressed 배경과 동일 | — | — | Progress circle 14–18px, 두께 2px |

**레이아웃**
- 아이콘-텍스트 gap: XSmall/Small `$dimension.x1`, Medium `$dimension.x1_5`, Large `$dimension.x2`
- Pressed 시 scale: XSmall 0.95 / Small·Medium 0.97 / Large 0.98
- 제약: 한 화면에 High emphasis 버튼 1개 권장, Icon-only는 접근성 라벨 필수, 3개 이상 나란히 배치 비권장, prefix/suffix 아이콘 동시 사용 불가

---

## 2. Text Input (Textarea 포함)

**Variant:** Outline(기본) · Underline(화면에 입력이 하나뿐일 때 권장)

| 속성 | Outline Large | Outline Medium | Underline Large | Underline Medium |
|---|---|---|---|---|
| minHeight | `$dimension.x13` | `$dimension.x10` | `$dimension.x10` | 34px |
| Padding X | `$dimension.x4` | `$dimension.x3_5` | – | – |
| Padding Y | – | – | `$dimension.x2` | `$dimension.x1_5` |
| Radius | `$radius.r3` | `$radius.r2` | – | – |
| Gap(아이콘 등) | `$dimension.x2_5` | `$dimension.x2` | `$dimension.x2_5` | `$dimension.x2` |
| Font-size | t5 | t4 | t6 | t5 |

**상태별 색상**

| 상태 | Stroke | Text | Placeholder | Background |
|---|---|---|---|---|
| Enabled | `$color.stroke.neutral-weak` (1px) | `$color.fg.neutral` | `$color.fg.placeholder` | – |
| Focused | `$color.stroke.neutral-contrast` (2px) | – | – | – |
| Error/Invalid | `$color.stroke.critical-solid` (2px) | – | – | – |
| Disabled | – | `$color.fg.disabled` | `$color.fg.disabled` | `$color.bg.disabled` |
| Read Only | – | – | – | `$color.bg.disabled` |

Prefix/Suffix Text: `$color.fg.neutral-subtle`, Prefix/Suffix Icon: `$color.fg.neutral-muted`. Stroke 전환 duration 0.1s.

---

## 3. List

**Variant:** List Item / List Header(mediumWeak, boldSolid)

**List Item**

| 항목 | 값 |
|---|---|
| Root Padding Y | `$dimension.x3` |
| Root Padding X | `$dimension.spacing-x.global-gutter`(16px) |
| Body Gap | `$dimension.x0_5` |
| Body Padding Right | `$dimension.x2_5` |
| Prefix Padding Right | `$dimension.x3` |
| Suffix Gap | `$dimension.x1` |
| Title | font-size t5 / line-height t5 |
| Detail | font-size t3 / line-height t3 |
| Prefix Icon | 22px |
| Suffix Icon | 18px |

**상태별 색상**

| 상태 | Root BG | Title | Detail | Icon |
|---|---|---|---|---|
| Enabled | `$color.bg.transparent` | `$color.fg.neutral` | `$color.fg.neutral-subtle` | prefix `$color.fg.neutral` / suffix `$color.fg.neutral-subtle` |
| Pressed | `$color.bg.transparent-pressed` (margin-x `$dimension.x1_5`, radius `$dimension.x2_5`, scale `$scale.s97`) | – | – | – |
| Highlighted | `$color.bg.brand-weak` (pressed: `$color.bg.brand-weak-pressed`) | – | – | – |
| Disabled | – | `$color.fg.disabled` | `$color.fg.disabled` | `$color.fg.disabled` |

**List Header:** Padding X `global-gutter`, Padding Y `$dimension.x2`, Gap `$dimension.x2_5`, Font-size t4. mediumWeak = `$font-weight.medium`, boldSolid = `$font-weight.bold`.

Duration: 색상 전환 `$duration.color-transition`, margin/radius `$duration.d3`, pressed scale `$duration.pressed-scale`.

---

## 4. Bottom Navigation

문서에 구체적 색상 토큰명이 명시되지 않음 (선택/비선택은 "컬러 톤으로 구분"이라고만 서술).

| 항목 | 값 |
|---|---|
| 최대 너비(Android) | 480px |
| 상단 Divider | 0.33px(@3x) / iOS 0.5pt |
| Badge | Small(도트) / Large(숫자 1–99, 100+시 "99+") |
| 아이콘 스타일 | Fill |

레이아웃 규칙: 탭 5개 이하 권장, 라벨 한글 5자/영문 10자 이내, 폰트 스케일링 미적용, Badge는 3개 이상 탭에 동시 표시 비권장.

---

## 5. Tabs

**Variant:** Line(Fill/Hug) · Chip(Solid/Outline)

| 속성 | Line Medium | Line Small | Chip Large | Chip Medium |
|---|---|---|---|---|
| Height | 44px | 40px | – | – |
| Padding X/Y | `$dimension.x2_5` | `$dimension.x2_5` | `$dimension.x4` | `$dimension.x4` |
| Font-size | t5 | t4 | – | – |
| Gap | – | – | 8px | 8px |

Font-weight 공통 `$font-weight.bold`.

**색상:** Enabled label `$color.fg.neutral-subtle` → Selected `$color.fg.neutral` → Disabled `$color.fg.disabled`. Indicator height 2px, color `$color.fg.neutral`. Base border `$color.stroke.neutral-muted`.

**레이아웃:** Hug는 padding-x `global-gutter` + indicator inset 0px / Fill은 padding-x 0px + indicator inset `global-gutter`. Chip tablist gap 8px. Indicator transform duration `$duration.d4`, easing `$timing-function.easing`.

---

## 6. Segmented Control

명시적 variant 없음 (상태 기반: Selected-Enabled/Selected-Pressed/Pressed/Disabled/Selected-Disabled)

| 항목 | 값 |
|---|---|
| minHeight | 34px |
| minWidth | 86px |
| Padding X/Y | `$dimension.x6` / `$dimension.x1_5` |
| Radius | `$radius.full` |
| Segment gap | `$dimension.x1_5` |
| Font | t5 / bold |
| 컨테이너 padding | `$dimension.x1` |
| Border | 1px `$color.stroke.neutral-muted` |

**색상:** Enabled(비선택) BG `$color.bg.neutral-weak-alpha` / text `$color.fg.neutral-subtle`. Pressed BG `$color.bg.neutral-weak-pressed`. Selected indicator `$color.palette.gray-00` / text `$color.fg.neutral`. Disabled BG `$color.bg.disabled` / text `$color.fg.disabled`.

세그먼트 2~4개 권장. 색상 전환 `$duration.color-transition`, indicator transform `$duration.d4`.

---

## 7. Chip

**Variant:** Solid · Outline Strong · Outline Weak

| Size | Height | Padding X | Prefix Icon | Prefix Avatar |
|---|---|---|---|---|
| Small | 32px | x1.5 | x3.5 | x5 |
| Medium | 36px | x2 | x4 | x6 |
| Large | 40px | x2.5 | x4 | x7 |

공통: font-size t4, font-weight medium, radius full.

**색상**

| 상태 | Solid | Outline Strong/Weak |
|---|---|---|
| Enabled | BG `neutral-weak-alpha` / text `neutral` | transparent BG / border `neutral-muted` / text `neutral` |
| Selected | BG `neutral-inverted` / text `neutral-inverted` | Outline Weak: BG `neutral-weak`, border `neutral-contrast` |
| Pressed | BG `neutral-weak-alpha-pressed` | – |
| Disabled | opacity 0.5 | opacity 0.5 |

Prefix 아이콘 색: 기본 `neutral`, selected `neutral-inverted`. Label padding-x x1.5.

---

## 8. Callout

**Tone:** Neutral · Informative · Warning · Critical · Positive · Magic

| 항목 | 값 |
|---|---|
| Padding X/Y | `$dimension.x3_5` |
| Gap | `$dimension.x3` |
| Radius | `$radius.r2_5` |
| Min Height | 50px |
| Font | t4 (title bold / description·link regular) |
| Icon size | `$dimension.x4` (suffix target size `$dimension.x10`) |

**Tone별 색상** (배경 / 텍스트+아이콘 / pressed 배경)
- Neutral: `bg.neutral-weak` / `fg.neutral` / `bg.neutral-weak-pressed`
- Informative: `bg.informative-weak` / `fg.informative-contrast` / `bg.informative-weak-pressed`
- Positive: `bg.positive-weak` / `fg.positive-contrast` / `bg.positive-weak-pressed`
- Warning: `bg.warning-weak` / `fg.warning-contrast` / `bg.warning-weak-pressed`
- Critical: `bg.critical-weak` / `fg.critical-contrast` / `bg.critical-weak-pressed`
- Magic: `$gradient.glow-magic` / `fg.neutral` / `$gradient.glow-magic-pressed`

아이콘은 Fill 타입 권장.

---

## 9. Dialog

| 항목 | 값 |
|---|---|
| Medium 너비 | 480px |
| Large 너비 | 800px |
| 최대 높이 | 화면의 80% |
| 반응형 (md 미만, ~767px) | 화면 너비의 90% (좌우 5%씩 여백) |
| Elevation | Level 3 (Drawer/Bottom Sheet는 Level 2) |

※ 원본 페이지에 padding/radius/그림자 토큰/overlay 색이 명시되지 않음 — Alert Dialog 문서(§10)의 값이 사실상 Dialog 계열 공통값으로 추정되므로 그쪽을 참고할 것. 정확한 값은 Figma 리소스 확인 필요.

---

## 10. Alert Dialog

| 항목 | 값 |
|---|---|
| Corner Radius | `$radius.r5` |
| Max Width | Medium 480px / Large 800px |
| Content width (md 미만) | viewport width × 0.9 |
| Max Height | viewport height × 0.8 |

**Padding**

| 영역 | 값 |
|---|---|
| Header padding X | `$dimension.x6` |
| Header padding Top/Bottom | `$dimension.x6` / `$dimension.x4` |
| Body padding X | `$dimension.x6` |
| Body padding Bottom(스크롤 시) | `$dimension.x12` |
| Footer padding X | `$dimension.x6` |
| Footer padding Top/Bottom | `$dimension.x4` / `$dimension.x6` |
| Content margin X | `$dimension.x5` |
| Header gap | `$dimension.x1_5` |
| Close 버튼 위치 | top `$dimension.x7`, right `$dimension.x6` |

**타이포:** Title t8/bold, Description t5/regular.

**색상:** Backdrop `$color.bg.overlay`, Content BG `$color.bg.layer-floating`, Title `$color.fg.neutral`, Description `$color.fg.neutral-muted`, 스크롤 구분선 `$color.stroke.neutral-muted`(1px).

**모션:** Backdrop opacity 0→1, `$duration.d2` / `enter` easing. Content opacity 0→1 + scale 1.3→1, `$duration.d4` / `enter-expressive` easing.

Variant는 색상 변형(Neutral 기본 권장 / Brand / Critical)만 존재. "임의 변형 금지, 제공된 형태 그대로 사용" 명시.

---

## 11. Snackbar

**Variant:** Default · Positive · Critical

| 항목 | 값 |
|---|---|
| 최소 Height | 44px |
| 최대 너비 | 560px |
| Padding X/Y | `$dimension.x2_5` |
| Radius | `$radius.r2` |
| Font | t4, 메시지 regular / 액션 bold |
| Icon | 24px |

**색상:** BG `$color.bg.neutral-inverted`, Text `$color.fg.neutral-inverted`, Action `$color.fg.brand`, Positive icon `$color.fg.positive`, Critical icon `$color.fg.critical`.

**레이아웃:** 화면 하단 중앙, safe area 고려, z-index는 FAB보다 위, 표시시간 기본 4초, 동시 1개만(큐 방식), 진입 opacity 0→1 + scale 0.8→1 (`$duration.d3`), 종료 `$duration.d2`.

---

## 12. Top Navigation

**Variant:** Root(최상위 탭) · Standard(2-depth 이상)

| 항목 | iOS | Android |
|---|---|---|
| Height | 44px | 56px |
| Padding X | `$dimension.x4` | `$dimension.x4` (Main padding-left 16px) |

**타이포**

| 레이아웃 | 요소 | Font-size | Weight |
|---|---|---|---|
| titleOnly | title | t6 | bold |
| withSubtitle | title | t5 | bold |
| withSubtitle | subtitle | t2 | regular |

**색상(enabled):** root BG `$color.bg.layer-default`, title `$color.fg.neutral`, subtitle `$color.fg.neutral-muted`. 배경 투명(tone=transparent) 시 title/subtitle `$color.palette.static-white`.

**레이아웃:** 우측 아이콘버튼 최대 3개(권장 2개), 텍스트버튼 1개만, 스크롤 시 상단 고정, 배경 투명→스크롤 시 배경 채움 + gradient bleedBottom `$dimension.x5`.

---

## 13. Switch

| Size | Height | Width | Thumb | Radius |
|---|---|---|---|---|
| 32 | 32px | 52px | 26×26px | `$radius.full` |
| 24 | 24px | 38px | 20×20px | `$radius.full` |
| 16 | 16px | 26px | 12×12px | `$radius.full` |

Padding 전 사이즈 2–3px.

**색상**

| 상태 | Track | Thumb |
|---|---|---|
| Off | `$color.palette.gray-600` | `$color.fg.neutral-inverted` |
| On | `$color.bg.neutral-inverted` | `$color.fg.neutral-inverted` |
| Disabled Off | opacity 0.38 | – |
| Disabled On | `$color.palette.gray-600` | `$color.palette.static-black-alpha-700` |

**모션:** 색상 전환 `$duration.d1`(delay 20ms), thumb scale/translate `$duration.d3`, opacity `$duration.d1`, 전부 `$timing-function.easing`. Thumb scale off 0.8 → on 1.0.

---

## 14. Checkbox

| Size | Checkmark | Radius | 최소 높이 | 라벨 폰트 |
|---|---|---|---|---|
| Medium | 12px | `$radius.r1` | `$dimension.x5` | t4 |
| Large | 14px(Square)/18px(Ghost) | `$radius.r1` | `$dimension.x6` | t5 |

**색상(Square 기준)**

| 상태 | 배경 | 테두리 | 체크마크 |
|---|---|---|---|
| Unchecked | – | `$color.stroke.neutral-weak` | – |
| Checked | `$color.bg.brand-solid` | – | `$color.palette.static-white` |
| Pressed(selected) | `$color.bg.brand-solid-pressed` | – | – |
| Disabled | `$color.bg.disabled` | `$color.stroke.neutral-muted` | `$color.fg.disabled` |

**레이아웃:** 루트 간격 `$dimension.x2`, 그룹 간격(Y) `$dimension.x1`. 라벨색 활성 `$color.fg.neutral` / 비활성 `$color.fg.disabled`.

---

## 15. Avatar

| Size | 값 | Radius | Stroke |
|---|---|---|---|
| 20/24/36/42/48/56/64/80/96/108px | 각 크기 | `$radius.full` | 1px |

대표 사용처: 20px 댓글사용자, 24px 답글, 36px 댓글프로필, 42px 게시글상세, 48/56px 리스트, 64px 프로필상세·캐러셀, 108px 프로필수정.

**색상:** Stroke `$color.stroke.neutral-subtle`, Avatar Stack 배경 `$color.bg.layer-default`, 이미지 없을 시 Identity Placeholder.

**배지(Badge, 20px는 미지원, 타입 Circle/Shield/Flower)**

| Avatar Size | BadgeMask 크기/오프셋 | Badge 크기/오프셋 |
|---|---|---|
| 24 | 12 / 14 | 10 / 15 |
| 36 | 18 / 20 | 14 / 22 |
| 42 | 20 / 24 | 16 / 26 |
| 48 | 22 / 28 | 18 / 30 |
| 56 | 24 / 34 | 20 / 36 |
| 64 | 26 / 40 | 22 / 42 |
| 80 | 32 / 52 | 28 / 54 |
| 96 | 38 / 62 | 32 / 65 |
| 108 | 44 / 70 | 36 / 74 |

---

## 16. Badge

**Variant:** Solid(복잡한 배경/이미지 위) · Outline(중간 주목도) · Weak(반복 구조)

| 속성 | Large | Medium |
|---|---|---|
| minHeight | `$dimension.x6` | `$dimension.x5` |
| maxWidth | 108px | 120px |
| Padding X/Y | `$dimension.x2`/`$dimension.x1` | `$dimension.x1_5`/`$dimension.x0_5` |
| Radius | `$radius.r1_5` | `$radius.r1` |
| Font | t2 | t1 |

Font-weight: Weak `medium`, Solid/Outline `bold`(Outline strokeWidth 1px).

**Neutral tone 예시:** Weak BG `$color.bg.neutral-weak` / text `$color.fg.neutral-muted`. Solid BG `$color.palette.gray-800` / text `$color.fg.neutral-inverted`. Outline text `$color.fg.neutral-muted`.
(Brand/Informative/Positive/Warning/Critical도 동일 구조로 각 tone 토큰 존재 — 원본 문서 표 참고)

---

## 17. Contextual Floating Button

**Variant:** Solid(고강조) · Layer(저강조, 인라인에 자연스럽게 녹아듦)

| 항목 | 값 |
|---|---|
| Radius | `$radius.full` |
| Shadow | `$shadow.s3` |
| minHeight(withText) | 36px |
| Padding X/Y(withText) | `$dimension.x3_5` / `$dimension.x2` |
| Gap | `$dimension.x1` |
| Font | t4 / medium |
| Icon-only 크기 | 44px |
| Progress circle | 16px, 두께 2px |

**색상**

| 상태 | Solid BG | Layer BG | Text/Icon |
|---|---|---|---|
| Enabled | `$color.bg.neutral-inverted` | `$color.bg.layer-floating` | Solid: `neutral-inverted` / Layer: `$color.fg.neutral` |
| Pressed | `-pressed` 변형 | `-pressed` 변형 | – |
| Disabled | `$color.bg.disabled` | `$color.bg.disabled` | `$color.fg.disabled` |
| Loading | pressed와 동일 | pressed와 동일 | – |

고정 위치 없이 콘텐츠 근처 자유 배치, 한 화면에 여러 개 가능, 라벨은 한 줄 유지 권장.

---

## 18. Select Box

**Variant:** Single Column · Multiple Columns(2~3열) · Horizontal(항상 단일 컬럼) · Vertical(폭에 따라 2~3열)

| 항목 | 값 |
|---|---|
| Radius | `$radius.r3` |
| Prefix Icon | 22px |
| Checkmark | `$dimension.x5`(20px), 아이콘 15px |
| Padding(Horizontal layout) | L/R `$dimension.x5`/`$dimension.x4`, Y `$dimension.x4` |
| Padding(Vertical layout) | X `$dimension.x4`, Y `$dimension.x5` |
| Label | t5 / medium |
| Description | t3 / regular |

**색상**

| 상태 | Border | Label/Icon | Description |
|---|---|---|---|
| Enabled | `$color.stroke.neutral-muted`(1px) | `$color.fg.neutral` | `$color.fg.neutral-muted` |
| Selected | `$color.stroke.neutral-contrast`(2px) | – | – |
| Pressed | BG `$color.bg.transparent-pressed` | – | – |
| Disabled | `$color.fg.disabled` | `$color.fg.disabled` | – |

박스 전체가 터치 타겟. Multiple Columns는 최장 콘텐츠 기준 높이 통일. 그룹 간격 X `$dimension.x3`, Y `$dimension.spacing-y.component-default`.

---

## 19. Bottom Sheet

Property 조합 방식 (variant 명시 없음): Header Layout(left/center) · Show Handle · Show Close Button · Show Description · Show Footer

| 항목 | 값 |
|---|---|
| Content 상단 radius | `$radius.r6` |
| Header padding Top/Bottom | `$dimension.x6` / `$dimension.x4` |
| Body/Footer padding X | `$dimension.spacing-x.global-gutter` |
| Footer padding Top/Bottom | `$dimension.x3` / `$dimension.x4` |
| Handle 크기 | 36×4px, top offset 6px, 터치영역 44×44px |
| Close 버튼 터치 타겟 | 40×40px |

**색상:** Backdrop `$color.bg.overlay`, Content BG `$color.bg.layer-floating`, Handle `$color.palette.gray-400`(pressed `gray-500`).

**레이아웃:** 최대 너비 640px, 최대 높이는 화면의 90% 초과 금지(초과 시 페이지 전환 권장). Snap point 최소 2개(최대/중간)~최대 3개(90%/50%/10%). 콘텐츠 스크롤은 Content Area 내부로 한정, Scroll Fog 표시.

---

## 20. Menu Sheet

**Variant:** Layout(Text Only / Text with Icon) · Tone(Neutral / Critical) · Header(표시/숨김) · Item Description(표시/숨김)

| 항목 | 값 |
|---|---|
| Item Height | 52px(minHeight) |
| Padding X/Y | `$dimension.x4` / `$dimension.x3_5` |
| Label | t5 / regular |
| Description | t3 / medium |
| Icon 크기 | 22px |
| Icon-Text gap | `$dimension.x3_5` |
| Label-Description gap | `$dimension.x0_5` |
| 그룹 간 간격 | `$dimension.x2_5` |
| Header 하단 padding | `$dimension.x4` |
| Close 버튼 높이 | 52px |

**색상**

| 상태 | 배경 | 텍스트/아이콘 |
|---|---|---|
| Enabled(Neutral) | `$color.bg.neutral-weak` | `$color.fg.neutral` |
| Pressed(Neutral) | `$color.bg.neutral-weak-pressed` | – |
| Enabled(Critical) | – | `$color.fg.critical` |
| Description | – | `$color.fg.neutral-subtle` |

제약: 아이콘 포함 시 좌측 정렬 필수, 최대 3개 그룹, 시트 내부 스크롤 없도록 항목 수 관리.

---

## 공통 규칙 요약

### Radius 스케일 (관찰된 값)
- `$radius.r1` (Checkbox 등 작은 요소) < `$radius.r1_5` (Badge Large) < `$radius.r2` (Chip/Input Medium, Snackbar) < `$radius.r2_5` (Callout, List pressed) < `$radius.r3` (Button Large, Input Large, Select Box) < `$radius.r5` (Alert Dialog) < `$radius.r6` (Bottom Sheet 상단)
- `$radius.full` = pill/circle: Action Button XSmall, Segmented Control, Chip, Switch, Avatar, Checkbox indicator(원형 계열), Contextual Floating Button

### 상태 오버레이(색) 규칙
공통 패턴은 **"기본 토큰 + `-pressed` 접미사"** 조합으로 pressed 상태를 표현한다:
- `$color.bg.brand-solid` → `$color.bg.brand-solid-pressed`
- `$color.bg.neutral-inverted` → `$color.bg.neutral-inverted-pressed`
- `$color.bg.neutral-weak` → `$color.bg.neutral-weak-pressed`
- `$color.bg.transparent` → `$color.bg.transparent-pressed`
- `$color.bg.layer-floating` → `$color.bg.layer-floating-pressed`
- `$color.bg.critical-solid` → `$color.bg.critical-solid-pressed`

**Disabled**는 대부분 두 방식 중 하나:
1. 전용 토큰 사용: 배경 `$color.bg.disabled`, 텍스트/아이콘 `$color.fg.disabled`
2. opacity 낮춤: Chip/Switch 등 일부는 `opacity: 0.38~0.5` 적용

**Pressed 시 스케일 다운**(버튼류 공통): 0.95~0.98 (컴포넌트/사이즈별 상이), List item pressed는 `$scale.s97` + margin-x 축소 + radius 부여.

### 타이포 스케일
`$font-size.t1`(최소, Badge Medium) ~ `$font-size.t8`(최대, Alert Dialog Title)까지 관찰됨. `$line-height.tN`은 항상 동일 인덱스의 `$font-size.tN`과 짝을 이룬다.
Font-weight는 `regular` < `medium` < `bold` 3단계로 대부분의 컴포넌트가 표현되며, 강조 텍스트(버튼 라벨, 다이얼로그 타이틀, 탭 선택 라벨)는 거의 항상 `bold`를 사용한다.

### 모션(Duration) 스케일
`$duration.d1`(가장 짧음, 색상 전환) < `$duration.d2`(backdrop enter/snackbar exit) < `$duration.d3`(scale/translate, list pressed) < `$duration.d4`(indicator transform, dialog content enter). 색상 전환 전용 별칭 `$duration.color-transition`도 존재. Easing은 `$timing-function.easing`(기본), `enter`/`enter-expressive`(모달류 진입) 구분.

### Overlay / Elevation
- Backdrop(Dialog/Alert Dialog/Bottom Sheet 공통): `$color.bg.overlay`
- 플로팅 표면(Dialog content, Bottom Sheet content, Contextual Floating Button Layer variant): `$color.bg.layer-floating`
- Elevation 계층: Dialog(Level 3) > Drawer/Bottom Sheet(Level 2). 그림자는 `$shadow.sN` 스케일(관찰된 값: Contextual Floating Button = `$shadow.s3`)

### 간격(Spacing) 관례
- 화면 좌우 여백은 `$dimension.spacing-x.global-gutter`(16px)로 통일 (List, Top Navigation, Tabs Hug, Bottom Sheet body/footer)
- 아이콘-텍스트 간격은 컴포넌트 크기에 비례해 `$dimension.x1`~`x3_5` 범위에서 증가

---

## 수집 결과

**대상 URL:** https://seed-design.io/components/{action-button, text-input, list, bottom-navigation, tabs, segmented-control, chip, callout, dialog, alert-dialog, snackbar, top-navigation, switch, checkbox, avatar, badge, contextual-floating-button, select-box, bottom-sheet, menu-sheet}

**성공 (20/20 — 404 없음):**
action-button, text-input, list, bottom-navigation, tabs, segmented-control, chip, callout, dialog, alert-dialog, snackbar, top-navigation, switch, checkbox, avatar, badge, contextual-floating-button, select-box, bottom-sheet, menu-sheet

**비고:**
- `bottom-navigation`: 구체적 색상 토큰명이 원본 페이지에 명시되지 않아 정성적 설명("컬러 톤으로 구분")만 기록됨.
- `dialog`: padding/radius/shadow/overlay 값이 원본 페이지에 없어 크기·반응형 규칙만 기록. 상세값은 구조가 유사한 `alert-dialog` 섹션(§10)을 참고하거나 Figma 원본 확인 필요.
