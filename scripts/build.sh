#!/usr/bin/env bash
# cline-for-genos 빌드: upstream 태그 checkout → 빌드(순정) → i18n 치환 → 브랜딩(메타데이터) → vsix 패키징
# 요구사항: Node 22, jq, git. bun/protoc 불필요.
#
# ⚠️ 순서 불변 조건: 브랜딩(jq)은 반드시 `npm run package` 이후에 수행한다.
#    esbuild가 package.json의 name/publisher를 번들에 인라인하고, 런타임 명령·뷰 ID 프리픽스를
#    `name === "claude-dev" ? "cline" : name` 으로 파생하기 때문에, 빌드 전에 name을 바꾸면
#    확장이 `cline-for-genos.*` 로 provider/명령을 등록해 package.json contributes(`cline.*`,
#    `claude-dev.SidebarProvider`)와 어긋난다 → 사이드바 webview가 영원히 빈 화면(스피너).
#    (2026-06-12 CDP 이분 탐색으로 실증 — 브랜딩은 패키징 메타데이터 단계에서만.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

UPSTREAM_TAG="$(tr -d '[:space:]' < UPSTREAM_VERSION)"
GENOS_VERSION="${UPSTREAM_TAG#v}"
BUILD_DIR="$ROOT/build/upstream"
EXT_DIR="$BUILD_DIR/apps/vscode"

echo "[build] upstream $UPSTREAM_TAG → cline-for-genos-$GENOS_VERSION.vsix"

# 1. upstream fresh checkout (분기 1회 빌드라 캐시보다 재현성 우선)
rm -rf "$BUILD_DIR"
mkdir -p "$ROOT/build"
git clone --depth 1 --branch "$UPSTREAM_TAG" https://github.com/cline/cline.git "$BUILD_DIR"

# 2. 패치 적용 (초기 0건 — 슬롯)
shopt -s nullglob
for p in "$ROOT"/patches/*.patch; do
  echo "[build] applying $(basename "$p")"
  git -C "$BUILD_DIR" apply --verbose "$p"
done
shopt -u nullglob

# 3. 의존성 설치
npm --prefix "$EXT_DIR" ci --include=optional
npm --prefix "$EXT_DIR/webview-ui" ci --include=optional

# 4. 순정 빌드 (protos → 타입체크 → webview 빌드 → lint → esbuild)
#    package.json이 순정인 상태에서 번들을 만들어 런타임 ID가 upstream contributes와 일치하게 한다
(cd "$EXT_DIR" && npm run package)

# 5. 한국어 i18n — webview 번들 출력물 사전 치환 (빌드 후, 소스 무수정)
OUTDIR_LINE="$(grep -n 'outDir' "$EXT_DIR/webview-ui/vite.config.ts" || true)"
echo "[build] vite outDir hint: ${OUTDIR_LINE:-not-found (default dist)}"
WEBVIEW_OUT="build"   # v3.89.2 기준. 위 hint와 다르면 이 값을 수정할 것.
node "$ROOT/scripts/translate-webview.mjs" --dict "$ROOT/i18n/ko.json" --target "$EXT_DIR/webview-ui/$WEBVIEW_OUT"

# 6. 브랜딩 — 패키징 메타데이터 전용 단계 (상단 ⚠️ 참고: 빌드 전 수행 금지)
PKG="$EXT_DIR/package.json"
tmp="$(mktemp "$EXT_DIR/package.json.XXXXXX")"
jq '
  .name = "cline-for-genos"
  | .displayName = "CLINE-for-Genos"
  | .publisher = "genon"
  | .author = {name: "CLINE-for-Genos"}
  | .repository.url = "https://github.com/genonai/cline-for-genos"
  | .homepage = "https://genon.ai/"
  | .contributes.commands |= map(select(.command != "cline.accountButtonClicked"))
  | (if .contributes.menus["view/title"] then
       .contributes.menus["view/title"] |= map(select(.command != "cline.accountButtonClicked"))
     else . end)
' "$PKG" > "$tmp"
mv "$tmp" "$PKG"

# walkthrough 문구 브랜딩 (perl: BSD/GNU 양쪽에서 \b word-boundary 동작)
if [ -d "$EXT_DIR/walkthrough" ]; then
  find "$EXT_DIR/walkthrough" -name '*.md' -exec perl -pi -e 's/\bCline\b/CLINE-for-Genos/g' {} \;
fi

# README overlay
cp "$ROOT/overlay/README.md" "$EXT_DIR/README.md"

# 7. 패키징 — 이미 빌드된 산출물을 그대로 묶는다 (prepublish 재빌드 차단: 재빌드되면 브랜딩된
#    name이 번들에 인라인되어 위 ⚠️ 문제가 재발한다)
mkdir -p "$ROOT/dist"
(cd "$EXT_DIR" && \
  npm pkg set "scripts.vscode:prepublish=echo skip-rebuild: artifacts prebuilt by build.sh" && \
  ./node_modules/.bin/vsce package --allow-package-secrets sendgrid \
    --out "$ROOT/dist/cline-for-genos-$GENOS_VERSION.vsix")

echo "[build] done: dist/cline-for-genos-$GENOS_VERSION.vsix"
