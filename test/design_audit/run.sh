#!/bin/bash
# 사용: test/design_audit/run.sh <출력폴더> [테스트파일...]
# 예)  test/design_audit/run.sh /tmp/app-after
# macOS sandbox-exec 로 외부 네트워크 송신을 막은 채 돈다(127.0.0.1 만 허용) —
# 앱이 실수로 실제 서버에 붙지 못하게 하는 안전장치다.
OUT_DIR="${1:?usage: run.sh <out-dir> [test files]}"; shift
cd "$(dirname "$0")/../.."
FILES="${@:-test/design_audit/}"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR" sandbox-exec -f test/design_audit/no_network.sb \
  flutter test $FILES --dart-define=OUT="$OUT_DIR" --concurrency=1 --no-pub
