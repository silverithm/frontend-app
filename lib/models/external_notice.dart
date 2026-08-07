/// 노인장기요양보험(longtermcare.or.kr) 공지 — 백엔드 ExternalNoticeDTO와 대응.
/// source: LTC_NOTICE(공지사항) / LTC_LAW(법령자료실) / LTC_EVAL(평가 매뉴얼) / LTC_EDU(기관종사자 교육)
class ExternalNotice {
  final int id;
  final String source;
  final String sourceLabel;
  final String title;
  final String url;
  final DateTime? postedDate;

  ExternalNotice({
    required this.id,
    required this.source,
    required this.sourceLabel,
    required this.title,
    required this.url,
    this.postedDate,
  });

  factory ExternalNotice.fromJson(Map<String, dynamic> json) {
    return ExternalNotice(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      source: json['source']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      postedDate: json['postedDate'] != null
          ? DateTime.tryParse(json['postedDate'].toString())
          : null,
    );
  }
}

/// 필터 칩에 쓰는 소스 목록 — 백엔드 ExternalNoticeCrawlerService.LtcBoard와 동일한 라벨.
class ExternalNoticeSource {
  final String value;
  final String label;

  const ExternalNoticeSource(this.value, this.label);

  static const all = [
    ExternalNoticeSource('LTC_NOTICE', '공지사항'),
    ExternalNoticeSource('LTC_LAW', '법령자료실'),
    ExternalNoticeSource('LTC_EVAL', '평가 매뉴얼'),
    ExternalNoticeSource('LTC_EDU', '기관종사자 교육'),
  ];
}
