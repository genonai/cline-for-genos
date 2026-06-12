# cline-for-genos (v2 빌드 레포)

[Cline](https://github.com/cline/cline) upstream을 추적하는 GenOS 브랜딩 빌드.
**소스 포크가 아니다** — upstream 태그를 그대로 빌드하면서 다음만 주입한다:

| 레이어 | 수단 | 위치 |
|---|---|---|
| 브랜딩 | jq 필드 편집 + README overlay + walkthrough perl 치환 | `scripts/build.sh` |
| 한국어 UI | webview 번들 사전 치환 (소스 무수정) | `i18n/ko.json` + `scripts/translate-webview.mjs` |
| 코드 패치 | (현재 0건 — 비상 슬롯) | `patches/*.patch` |
| 런타임 설정 | GenOS 컨테이너가 ~/.cline 시딩 | GenOS 레포 `container-services/codespace/cline-provision.sh` |
| 폐쇄망 차단 | `~/.cline/endpoints.json` 시딩 → Cline selfHosted 모드 (PostHog·banners·feature-flags 미생성) | 〃 |

## 빌드

```bash
# 요구: Node 22 (24 금지 — vsce 이슈), jq, git. bun/protoc 불필요.
bash scripts/build.sh                    # → dist/cline-for-genos-<ver>.vsix (10~15분)
bash scripts/check-forbidden-strings.sh  # 브랜딩·i18n 산출물 게이트
node --test test/translate.test.mjs      # i18n 치환 단위 테스트
```

CI(`.github/workflows/build.yml`)가 push마다 동일 절차를 수행한다 (ubuntu, ~3분).

## 분기 업데이트 런북 (목표 반나절)

1. upstream 릴리스 노트 확인, 안정 태그 선택: https://github.com/cline/cline/releases
2. `UPSTREAM_VERSION` 변경 → 푸시 → CI green 확인
3. 빌드 로그의 `[i18n] unmatched` 항목 → upstream 소스에서 현행 영문 찾아 `i18n/ko.json` 키 교체 (LLM 일괄 번역 가능)
4. `check-forbidden-strings.sh` 통과 확인
5. UI smoke: 사이드바 브랜딩·한국어 라벨·webview 콘솔 무에러·채팅 1회
6. `gh release create v<ver>-genos.1 dist/*.vsix --repo genonai/cline-for-genos` → GenOS `Dockerfile-codespace-*`의 `CLINE_GENOS_RELEASE`/`CLINE_GENOS_VSIX` ARG 갱신 + `cline-cli` 스테이지의 `@cline/cli-linux-*` 버전 갱신
7. 구조 변화 감지 포인트: webview vite outDir(`build.sh`의 WEBVIEW_OUT), 설정 파일 키(upstream `apps/vscode/src/shared/storage/state-keys.ts`), endpoints.json 스키마(`apps/vscode/src/config.ts`)

## 레거시

v3.35.1 기반 구 소스 포크: `legacy/v3.35.1` 브랜치.
