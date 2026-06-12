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
tmp="$(mktemp)"
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
' "$PKG" > "$tmp" && mv "$tmp" "$PKG"

# walkthrough 문구 브랜딩
if [ -d "$EXT_DIR/walkthrough" ]; then
  find "$EXT_DIR/walkthrough" -name '*.md' -exec sed -i.bak 's/\bCline\b/CLINE-for-Genos/g' {} \;
  find "$EXT_DIR/walkthrough" -name '*.bak' -delete
fi

# README overlay
cp "$ROOT/overlay/README.md" "$EXT_DIR/README.md"

# 3. 의존성 설치
npm --prefix "$EXT_DIR" ci --include=optional
npm --prefix "$EXT_DIR/webview-ui" ci --include=optional

# 4. 패키징 (vscode:prepublish 체인이 protos→webview 빌드→esbuild 전부 수행)
mkdir -p "$ROOT/dist"
(cd "$EXT_DIR" && ./node_modules/.bin/vsce package --allow-package-secrets sendgrid \
  --out "$ROOT/dist/cline-for-genos-$GENOS_VERSION.vsix")

echo "[build] done: dist/cline-for-genos-$GENOS_VERSION.vsix"
