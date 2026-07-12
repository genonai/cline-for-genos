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

# 3.5 webview 로고 소스 오버레이 — Cline 로봇 마크 → GenOS 심볼.
#     빌드 전 소스(webview-ui/src/assets/ClineLogo*.tsx)를 교체하므로 번들에 자연 반영된다.
#     각 오버레이는 upstream 컴포넌트의 prop 시그니처를 그대로 유지(HomeHeader/Onboarding 컴파일 보존).
LOGO_SRC="$EXT_DIR/webview-ui/src/assets"
if [ -d "$ROOT/overlay/logos" ] && [ -d "$LOGO_SRC" ]; then
  shopt -s nullglob
  for f in "$ROOT"/overlay/logos/*.tsx; do
    cp "$f" "$LOGO_SRC/$(basename "$f")"
    echo "[build] logo overlay → webview-ui/src/assets/$(basename "$f")"
  done
  shopt -u nullglob
else
  echo "[build] ⚠️ overlay/logos 없음 — Cline 로봇 로고가 webview 에 유지됨."
fi

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
# 제품명 = GenCode (판매용 리브랜드). 상표(Apache-2.0 grant 없음): 사용자노출 "Cline" 은 GenCode 로,
# 내부 command/view ID(`cline.*`, `claude-dev.SidebarProvider`)는 불변(런타임 정합·상표 민감도 낮음),
# LICENSE/NOTICE 의 "Cline Bot Inc." 어트리뷰션은 유지(필수).
jq '
  .name = "cline-for-genos"
  | .displayName = "GenCode"
  | .publisher = "genon"
  | .author = {name: "GenCode"}
  | .repository.url = "https://github.com/genonai/cline-for-genos"
  | .homepage = "https://genon.ai/"
  | .contributes.commands |= map(select(.command != "cline.accountButtonClicked"))
  | (if .contributes.menus["view/title"] then
       .contributes.menus["view/title"] |= map(select(.command != "cline.accountButtonClicked"))
     else . end)
  # 사용자노출 브랜딩: 명령 타이틀/카테고리 "Cline" → "GenCode"
  | .contributes.commands |= map(
        (if (.title? | type) == "string" then .title |= gsub("Cline"; "GenCode") else . end)
      | (if (.category? | type) == "string" then .category |= gsub("Cline"; "GenCode") else . end))
  # 메뉴 아이템 타이틀
  | (if .contributes.menus then
       .contributes.menus |= map_values(map(if (.title? | type)=="string" then .title |= gsub("Cline"; "GenCode") else . end))
     else . end)
  # 액티비티바 뷰 컨테이너 타이틀 (사이드바 "Cline")
  | (if .contributes.viewsContainers.activitybar then
       .contributes.viewsContainers.activitybar |= map(if (.title? | type)=="string" then .title |= gsub("Cline"; "GenCode") else . end)
     else . end)
  # 뷰 이름
  | (if .contributes.views then
       .contributes.views |= map_values(map(if (.name? | type)=="string" then .name |= gsub("Cline"; "GenCode") else . end))
     else . end)
  # walkthrough 카드 타이틀/설명
  | (if .contributes.walkthroughs then
       .contributes.walkthroughs |= map(
           (if (.title? | type)=="string" then .title |= gsub("Cline"; "GenCode") else . end)
         | (if (.description? | type)=="string" then .description |= gsub("Cline"; "GenCode") else . end))
     else . end)
' "$PKG" > "$tmp"
mv "$tmp" "$PKG"

# walkthrough 마크다운 문구 브랜딩 (perl: BSD/GNU 양쪽에서 \b word-boundary 동작)
if [ -d "$EXT_DIR/walkthrough" ]; then
  find "$EXT_DIR/walkthrough" -name '*.md' -exec perl -pi -e 's/\bCline\b/GenCode/g' {} \;
fi

# 번들(webview/extension) 내 사용자노출 "Cline" 문자열 치환 — 큐레이션 화이트리스트(내부 식별자 보존).
# ⚠️ 목록은 upstream 분기 갱신마다 재검증(신규 UI 문자열 유입 가능). 근거: docs 감사(2026-07-07).
node "$ROOT/scripts/rebrand-webview-strings.mjs" \
  --target "$EXT_DIR/webview-ui/$WEBVIEW_OUT" \
  --dist "$EXT_DIR/dist"

# NOTICE — 합법 리셀 어트리뷰션 (LICENSE.txt=Apache-2.0 는 upstream 그대로 유지됨)
cp "$ROOT/overlay/NOTICE" "$EXT_DIR/NOTICE" 2>/dev/null || true

# README overlay
cp "$ROOT/overlay/README.md" "$EXT_DIR/README.md"

# 아이콘/로고 overlay — GenCode 로고로 교체(상표: Cline 로고 제거). overlay/icon.png 있으면 교체.
ICON_REL="$(jq -r '.icon // "assets/icons/icon.png"' "$PKG")"
if [ -f "$ROOT/overlay/icon.png" ]; then
  mkdir -p "$EXT_DIR/$(dirname "$ICON_REL")"
  cp "$ROOT/overlay/icon.png" "$EXT_DIR/$ICON_REL"
  echo "[build] icon overlay applied → $ICON_REL"
else
  echo "[build] ⚠️ overlay/icon.png 없음 — Cline 로고가 유지됨(상표). 판매 전 GenCode 아이콘 추가 필요."
fi

# 활동바 뷰 컨테이너 아이콘(좌측 사이드바 글리프) overlay — Cline 로봇 → GenOS 심볼.
# (마켓플레이스 .icon 과 별개 파일: contributes.viewsContainers.activitybar[].icon)
AB_ICON="$(jq -r '.contributes.viewsContainers.activitybar[0].icon // empty' "$PKG")"
if [ -n "$AB_ICON" ] && [ -f "$ROOT/overlay/activitybar-icon.svg" ]; then
  mkdir -p "$EXT_DIR/$(dirname "$AB_ICON")"
  cp "$ROOT/overlay/activitybar-icon.svg" "$EXT_DIR/$AB_ICON"
  echo "[build] activitybar icon overlay applied → $AB_ICON"
else
  echo "[build] ⚠️ 활동바 아이콘 overlay 없음/미매칭 — Cline 로봇 글리프 유지."
fi

# 7. 패키징 — 이미 빌드된 산출물을 그대로 묶는다 (prepublish 재빌드 차단: 재빌드되면 브랜딩된
#    name이 번들에 인라인되어 위 ⚠️ 문제가 재발한다)
mkdir -p "$ROOT/dist"
(cd "$EXT_DIR" && \
  npm pkg set "scripts.vscode:prepublish=echo skip-rebuild: artifacts prebuilt by build.sh" && \
  ./node_modules/.bin/vsce package --allow-package-secrets sendgrid \
    --out "$ROOT/dist/cline-for-genos-$GENOS_VERSION.vsix")

echo "[build] done: dist/cline-for-genos-$GENOS_VERSION.vsix"
