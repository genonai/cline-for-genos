#!/usr/bin/env bash
# GenCode 빌드 산출물 vsix 브랜딩·상표 게이트.
# 원칙(Apache-2.0, 상표 grant 없음):
#  - 사용자 노출 제품 정체성은 GenCode (displayName/명령 타이틀/뷰 타이틀/README).
#  - 내부 식별자(cline.* command id, claude-dev.SidebarProvider, .clinerules, ClineError 등)는 불변 — 검사 제외.
#  - LICENSE.txt(Apache-2.0) + NOTICE(Cline Bot Inc. 어트리뷰션)는 유지 필수.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VSIX="$(ls -t "$ROOT"/dist/*.vsix | head -1)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unzip -q "$VSIX" -d "$tmp"
EXT="$tmp/extension"
PKG="$EXT/package.json"
fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi }

# --- 메타데이터 브랜딩 ---
check "publisher=genon"            '[ "$(jq -r .publisher "$PKG")" = "genon" ]'
check "displayName=GenCode"        '[ "$(jq -r .displayName "$PKG")" = "GenCode" ]'
check "author=GenCode"             '[ "$(jq -r ".author.name // .author" "$PKG")" = "GenCode" ]'
check "account button removed"     '! grep -q accountButtonClicked "$PKG"'
check "i18n applied"               'grep -rq "프로젝트 파일 읽기" "$EXT/"'

# --- 상표 게이트: 사용자 노출 "Cline" 문구 0 ---
# 명령 타이틀/카테고리에 "Cline" 없어야 함
check "no Cline in command titles" '[ -z "$(jq -r ".contributes.commands[]? | .title, .category | select(.!=null)" "$PKG" | grep -i cline || true)" ]'
# 뷰 컨테이너/뷰 타이틀에 "Cline" 없어야 함
check "no Cline in view titles"    '[ -z "$(jq -r "(.contributes.viewsContainers.activitybar[]?.title), (.contributes.views[]?[]?.name) | select(.!=null)" "$PKG" | grep -i cline || true)" ]'
# README 에 사용자 노출 "Cline" 문구 없어야 함(단, 라이선스/어트리뷰션 문단의 Cline Bot Inc. 는 NOTICE 로 분리되어 있어 허용 범위 밖)
check "README has no CLINE brand"  '! grep -qE "CLINE-for-Genos|CLI a.?N.?d.?E" "$EXT/README.md"'
# 번들 화이트리스트 문구가 남지 않아야 함(대표 3종)
check "no \"Add to Cline\""        '! grep -rq "Add to Cline" "$EXT/webview-ui" "$EXT/dist" 2>/dev/null'
check "no \"with Cline\""          '! grep -rq "with Cline" "$EXT/webview-ui" "$EXT/dist" 2>/dev/null'

# --- 어트리뷰션 유지(필수) ---
check "LICENSE.txt retained"       '[ -f "$EXT/LICENSE.txt" ] && grep -q "Apache License" "$EXT/LICENSE.txt"'
check "NOTICE present"             '[ -f "$EXT/NOTICE" ] && grep -q "Cline Bot Inc" "$EXT/NOTICE"'

echo
if [ "$fail" -eq 0 ]; then echo "✅ 상표 게이트 통과 — 판매 배포 가능"; else echo "❌ 상표 게이트 실패 — 위 FAIL 수정 필요"; fi
exit $fail
