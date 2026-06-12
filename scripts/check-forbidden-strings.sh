#!/usr/bin/env bash
# 빌드 산출물 vsix의 브랜딩·차단 항목 검증 (Kilo Code forbidden-strings 패턴 축소판)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VSIX="$(ls "$ROOT"/dist/*.vsix | head -1)"
tmp="$(mktemp -d)"
unzip -q "$VSIX" -d "$tmp"
PKG="$tmp/extension/package.json"
fail=0
check() { if eval "$2"; then echo "ok - $1"; else echo "FAIL - $1"; fail=1; fi }

check "name=cline-for-genos"   '[ "$(jq -r .name "$PKG")" = "cline-for-genos" ]'
check "publisher=genon"        '[ "$(jq -r .publisher "$PKG")" = "genon" ]'
check "displayName"            '[ "$(jq -r .displayName "$PKG")" = "CLINE-for-Genos" ]'
check "account button removed" '! grep -q accountButtonClicked "$PKG"'
check "i18n applied"           'grep -rq "프로젝트 파일 읽기" "$tmp/extension/"'
exit $fail
