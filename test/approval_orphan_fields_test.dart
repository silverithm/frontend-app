// 양식에서 지운 항목 — 웹 src/lib/retiredFields.test.ts와 같은 규칙.
// 2026-11-16 업무일지: 'content'(행정 업무)를 복제한 뒤 원본을 지우자 지난 문서 본문이 내부 키 이름으로 나왔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/approval_orphan_fields.dart';

Map<String, dynamic> f(String id, String type, String label) =>
    {'id': id, 'type': type, 'label': label, 'required': false};

void main() {
  final after = [
    f('report-date', 'date', '업무 일자'),
    f('msod0n45pxcbv0rb40k', 'section', '금일 실시 사항'),
    f('mwimrby44qj5y9343e3', 'textarea', '행정 업무 사본'),
    f('issues', 'textarea', '어르신 특이사항'),
  ];
  final oldDoc = <String, dynamic>{
    'report-date': '2026-11-14',
    'content': '09:00 출근 체크',
    'issues': '없음',
    'msocv159to0qjd38i7d': '',
  };

  test('지운 항목에 쓴 내용만 잡히고, 이름은 기본 양식 사전에서', () {
    final orphans = orphanFields(fields: after, formData: oldDoc);
    expect(orphans.map((o) => o.key), ['content']);
    expect(orphans.single.label, '보고 내용');
    expect(orphans.single.valueIn(oldDoc), '09:00 출근 체크');
  });

  test('웹이 남긴 지운 항목 이름이 있으면 그 이름', () {
    final orphans = orphanFields(
      fields: after,
      retired: [f('content', 'textarea', '행정 업무')],
      formData: oldDoc,
    );
    expect(orphans.single.label, '행정 업무');
  });

  test('빌더가 만든 id는 이전 항목, 빈 값은 건너뛴다', () {
    final orphans = orphanFields(fields: after, formData: {
      'msocv159to0qjd38i7d': '기타 메모',
      'mwimzmg4j4vmvx3rbbj': '   ',
      'rows': [
        {'a': '', 'b': null}
      ],
    });
    expect(orphans.map((o) => o.label), ['이전 항목']);
  });

  test('기간은 시작·끝을 한 줄로', () {
    final doc = {'gone_start': '2026-11-01', 'gone_end': '2026-11-03', 'solo_start': '오전'};
    final orphans = orphanFields(fields: after, formData: doc);
    expect(orphans.map((o) => o.key), ['gone', 'solo_start']);
    expect(orphans.first.valueIn(doc), {'start': '2026-11-01', 'end': '2026-11-03'});
  });

  test('지금 양식의 기간 항목은 잡히지 않는다', () {
    final orphans = orphanFields(
      fields: [f('period', 'dateRange', '기간')],
      formData: {'period_start': '2026-11-01', 'period_end': '2026-11-02'},
    );
    expect(orphans, isEmpty);
  });

  test('이전 기안 불러오기는 지금 양식 항목 값만', () {
    final picked = pickLiveFormData(after, oldDoc);
    expect(picked.keys.toSet(), {'report-date', 'issues'});
    expect(pickLiveFormData(const [], oldDoc), oldDoc);
  });

  test('retiredFields 읽기', () {
    expect(retiredFieldsOf(null), isEmpty);
    expect(retiredFieldsOf({'fields': [], 'retiredFields': [f('content', 'textarea', '행정 업무')]}).single['label'], '행정 업무');
  });
}
