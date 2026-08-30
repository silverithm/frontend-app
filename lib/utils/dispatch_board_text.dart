/// 노선배차표 -> 카톡 공지용 텍스트.
///
/// 관리자 웹(src/lib/dispatchBoardText.ts)과 글자 단위로 같아야 한다.
/// 같은 날 같은 배차인데 앱과 웹이 다른 문구를 내놓으면 현장에서 신뢰를 잃는다.
///
///   8/31 (월) 등원   [개인등원 : 장치분, 최손분, 하금선]
///   총 73명
///   - 레이2/이광성팀장
///   1차) 강문자 조복수 이종술 유임생
///   2차) 김태선 이옥자2 박옥자
library;

import '../models/dispatch.dart';

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// "8/31 (월)"
String formatBoardDate(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return '${parsed.month}/${parsed.day} (${_weekdayNames[parsed.weekday - 1]})';
}

/// 차량/인력 줄: "스타리아/황인후 박성은팀장"
String buildRouteHeadline(RouteDispatch rd) {
  final vehicle = (rd.driver?.vehicleName.trim().isNotEmpty ?? false)
      ? rd.driver!.vehicleName.trim()
      : rd.routeName;

  final names = rd.crew.isNotEmpty
      ? rd.crew.map((d) => d.driverName).toList()
      : (rd.driver != null ? [rd.driver!.driverName] : <String>[]);

  if (names.isEmpty) return vehicle;

  final substitute = rd.status == DispatchStatus.substitute ? ' (대체)' : '';
  return '$vehicle/${names.join(' ')}$substitute';
}

/// 노선 한 덩어리: 헤드라인 + 회차 라인들
List<String> buildRouteBlock(RouteDispatch rd) {
  final lines = ['- ${buildRouteHeadline(rd)}'];

  if (rd.status == DispatchStatus.noService ||
      rd.status == DispatchStatus.holiday) {
    lines.add(rd.reason ?? rd.status);
    return lines;
  }

  if (rd.tripGroups.isEmpty) {
    lines.add('(탑승 없음)');
    return lines;
  }

  for (final group in rd.tripGroups) {
    final names = group.seniors.map((s) => s.name).join(' ');
    lines.add(group.tripOrder != null ? '${group.tripOrder}차) $names' : names);
  }

  return lines;
}

/// 그 방향의 노선만
List<RouteDispatch> selectRouteDispatches(
  DailyDispatch daily,
  String routeType,
) {
  return daily.routeDispatches.where((rd) => rd.routeType == routeType).toList();
}

/// 그 방향 차량 탑승 인원
int countPassengers(List<RouteDispatch> dispatches) {
  return dispatches.fold(0, (sum, rd) => sum + rd.passengers.length);
}

/// 헤더에 적는 "총 N명" - 그날 센터에 오는 인원.
/// 차량 탑승자 + 개인등하원이고, 결석자는 빠진다.
int countAttending(DailyDispatch daily, String routeType) {
  final personal = routeType == RouteType.toWork
      ? daily.personalPickupSeniors
      : daily.personalDropoffSeniors;
  return countPassengers(selectRouteDispatches(daily, routeType)) +
      personal.length;
}

String buildDispatchBoardText(DailyDispatch daily, String routeType) {
  final dispatches = selectRouteDispatches(daily, routeType);
  final personal = routeType == RouteType.toWork
      ? daily.personalPickupSeniors
      : daily.personalDropoffSeniors;

  final personalLabel = routeType == RouteType.toWork ? '개인등원' : '개인하원';
  final personalPart = personal.isNotEmpty
      ? '   [$personalLabel : ${personal.map((s) => s.name).join(', ')}]'
      : '';

  final lines = <String>[
    '${formatBoardDate(daily.date)} $routeType$personalPart',
    '총 ${countAttending(daily, routeType)}명',
  ];

  for (final rd in dispatches) {
    lines.addAll(buildRouteBlock(rd));
  }

  return lines.join('\n');
}
