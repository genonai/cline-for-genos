#!/usr/bin/env bash
# cline-for-genos 빌드: upstream 태그 checkout → (브랜딩/패치/i18n) → vsix 패키징
# 요구사항: Node 22, jq, git. bun/protoc 불필요.
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

# 2.5 브랜딩 (jq 필드 단위 편집 — 통파일 overlay 금지: upstream 의존성/contributes 추적 유지)
PKG="$EXT_DIR/package.json"
tmp="$(mktemp "$EXT_DIR/package.json.XXXXXX")"
jq '
  .name = "cline-for-genos"
  | .displayName = "CLINE-for-Genos"
  | .publisher = "genon"
  | .author = {name: "CLINE-for-Genos"}
  | .repository.url = "https://github.com/mindsandcompany/cline-for-genos"
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

# 3. 의존성 설치
npm --prefix "$EXT_DIR" ci --include=optional
npm --prefix "$EXT_DIR/webview-ui" ci --include=optional

# 4. webview vite 출력 경로 확인 (upstream 변경 감지)
OUTDIR_LINE="$(grep -n 'outDir' "$EXT_DIR/webview-ui/vite.config.ts" || true)"
echo "[build] vite outDir hint: ${OUTDIR_LINE:-not-found (default dist)}"
WEBVIEW_OUT="build"   # v3.89.2 기준. 위 hint와 다르면 이 값을 수정할 것.

# 5. 패키징: prepublish 체인 끝에 i18n 치환을 끼워 단일 vsce 호출로 완결
mkdir -p "$ROOT/dist"
(cd "$EXT_DIR" && \
  npm pkg set "scripts.vscode:prepublish=npm run package && node $ROOT/scripts/translate-webview.mjs --dict $ROOT/i18n/ko.json --target ./webview-ui/$WEBVIEW_OUT" && \
  ./node_modules/.bin/vsce package --allow-package-secrets sendgrid \
    --out "$ROOT/dist/cline-for-genos-$GENOS_VERSION.vsix")

echo "[build] done: dist/cline-for-genos-$GENOS_VERSION.vsix"
