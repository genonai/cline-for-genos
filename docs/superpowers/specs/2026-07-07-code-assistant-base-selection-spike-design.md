# GenOS 코드 어시스턴트 — 베이스 선정 스파이크 설계

- 작성일: 2026-07-07
- 상태: Draft (브레인스토밍 산출물 → writing-plans 로 이관 예정)
- 관련: cline-for-genos v2 (soft fork), GenOS #13293/#13294 (codespace 서빙 자동연결·WS·provisioning)

---

## 0. 배경 / 문제

cline-for-genos v2 는 업스트림 추적을 위해 **소프트 포크**(overlay/patch, 소스 직접수정 0, i18n 번들치환, env provisioning, 폐쇄망 kill-switch)로 만들었다. 이제 코드 어시스턴트를 **GenOS 프리미엄 모듈(제품)**로 판매할 가능성이 생겼고, 이는 기능·프롬프트·UI 고도화 = 사실상 하드 포크를 의미한다. 그러면 "Cline 이 최선의 베이스인가, 지금이라도 다른 오픈소스로 바꾸는 게 나은가"가 다시 열린다.

이 문서는 **그 결정을 내릴 근거를 만드는 비교 스파이크**를 정의한다. 결정 자체가 아니라, 결정을 위한 방법·기준·1차 실측 결과를 담는다.

### 확정된 제품 제약 (브레인스토밍 합의)
| 항목 | 값 |
|---|---|
| 제품 형태 | **GenOS 프리미엄 모듈** (온프렘/폐쇄망, 기존 GenOS 고객, 서빙·인증·데이터 통합이 차별점) |
| v1 must-have 기능 | ① 에이전트형 코딩 ② 코드베이스 이해(**Cline native 읽기** — grep+read+tree-sitter심볼; VDB RAG 폐기) ③ GenOS 워크플로우/MCP  ·  ~~인라인 자동완성~~ **v1 제외**(§1.3)  ·  ~~VDB RAG~~ **폐기**(§1.4) |
| 모델 환경 | **강한 오픈모델 동반/권장** (Qwen3-Coder/DeepSeek 급 → 에이전트 무난히 동작) |
| 리소스 | **전담 1~2명 상시** → 지속가능성이 최우선 제약 |
| 표면 방향 | 헤드리스 코어 중심(코어 1 + 얇은 프론트엔드: VS Code + CLI) + 자동완성 별도 |
| 전달 | code-server(codespace) 안 VS Code 익스텐션 + CLI |

### 횡단 원칙: 레이어드 포크
"업스트림 포기 = 하드포크"는 함정. 커스텀을 **레이어(overlay·config·주입)에 격리**하면 깊은 제품화에도 업스트림 **선택적 cherry-pick**을 유지할 수 있다. 1~2명 지속가능성엔 베이스 선택보다 이 규율이 더 중요하다. → 진짜 질문은 "소프트 vs 하드"가 아니라 **"어느 베이스 위에 레이어를 쌓을 때 1~2명이 4개 기능을 지속가능하게 유지하느냐"**.

---

## 1. 1차 리서치 결과 (웹 실검증, 2025~2026)

> 워크플로우 `wf_bb9a4340-9b5` 로 후보별 병렬 조사. `yes-with-conditions` = 표준 Apache/MIT 어트리뷰션·상표 조건 하 상용/재배포 가능.

| | 라이선스(판매) | 인라인 자동완성 | **폐쇄망 자동완성** | 아키텍처 | 표면 | 에이전트 평판 |
|---|---|---|---|---|---|---|
| **Cline** | Apache-2.0 ✓ | ✗ (creator가 issue #5007에서 미지원 확인) | — | **헤드리스 "Cline Core"(gRPC) + 클라이언트** | VS Code/JetBrains/CLI/web-Kanban, **Open VSX**(code-server·에어갭✓) | SWE-bench Verified ~59.8%(Sonnet 4.5), 5M+ 설치 |
| **Continue** | Apache-2.0 ✓ | **✓ FIM(전용 autocomplete role, config.yaml)** | **✓ self-host 가능**(apiBase→GenOS 서빙) | 확장 + 공유코어(@continuedev/core), 얇은 IDE 클라이언트 | VS Code/JetBrains/CLI, Open VSX | 모델종속. **⛔ EOL 확정**: Cursor 인수, 2026-06-19 v2.0.0 마지막·아카이브(§1.1) → 활성의존 불가, 코드 seed 만 유효 |
| **Kilo Code** | MIT ✓ | ✓ FIM(ghost-text+tab, Codestral 기본) | **✗ Kilo Gateway 클라우드 강제, self-host 옵션 없음** | 확장(Roo 포크)+JetBrains+CLI(**OpenCode 포크**)+클라우드 | 다표면(VS Code/JB/CLI/웹/PR리뷰) | OpenRouter 주간 #3, 3M+ 다운로드 |
| **OpenCode** | MIT ✓ | ✗ (에이전트/대화 전용, LSP는 진단피드백용) | — | **헤드리스 서버(`opencode serve`, OpenAPI 3.1→타입드 SDK)** | CLI/TUI 주력, VS Code 확장(beta) | 공식 벤치 없음, 모델종속 |

출처(대표): Cline `github.com/cline/cline/issues/5007`, `cline.bot/blog/cline-cli...`; Continue `docs.continue.dev/customize/model-roles/autocomplete`, `webdeveloper.com/news/cursor-acquires-continue...`; Kilo `kilo.ai/docs/.../autocomplete`; OpenCode `opencode.ai/docs/server/`.

### "OpenCode 가 성능이 더 좋다"에 대한 판정
**근거 없음(model-dominated).** 넷 다 스캐폴드/하네스라 코딩 성능은 붙인 **모델**이 지배한다. OpenCode 는 공식 SWE-bench 점수가 **없고**, 오히려 Cline 이 published ~59.8%(Sonnet 4.5)를 낸다. OpenCode 평판의 실체는 *헤드리스 아키텍처 + 속도 + LSP* 이지 검증된 코딩 성공률 우위가 아니다. → **같은 GenOS 모델을 붙이면 격차는 작을 가능성. 성능이 아니라 아키텍처·유지비로 골라야 한다.**

### 리서치가 만든 3가지 반전
1. **헤드리스 코어를 직접 지을 필요 없음.** Cline(Cline Core/gRPC)·OpenCode(`opencode serve`/OpenAPI) **둘 다 이미 헤드리스 client/server**. 코어는 채택하고 얇은 프론트엔드만 붙이면 됨 → 1~2명 부담 감소.
2. **자동완성 must-have + 폐쇄망 = Continue 가 사실상 유일.** Kilo 는 자동완성이 있으나 **클라우드 강제로 폐쇄망 탈락**. Cline·OpenCode 는 자동완성 자체가 없음. → **어느 에이전트 베이스든 자동완성은 Continue self-host FIM(또는 얇은 자체 FIM 엔진)으로 별도 조립** = "단일 베이스로 4개 불가" 재확인.
3. **성능이 모델 지배 + 강한 오픈모델 전제** → 에이전트 베이스 선택이 성능을 크게 안 가름. 선택 기준은 **포크 유지비·라이선스·헤드리스 성숙도·GenOS 통합공수**로 이동.

### 1.1 최종 리서치 갱신 (성능·종합 agent 완료)
- **[확정] Continue 는 EOL.** Cursor 가 Continue 를 인수, `continuedev/continue` 는 **2026-06-19 v2.0.0 을 마지막으로 아카이브·read-only**(텔레메트리+auth 제거된 깨끗한 빌드). 업스트림 = 0. Apache-2.0 라 포크는 자유지만 **모든 유지보수를 GenOS 가 떠안는다.** → *Continue 를 "활성 프로젝트로 의존"하는 안은 탈락.* 단 **자동완성 코드(frozen v2.0.0, 텔레메트리-free)를 seed 로 포크**하는 것은 유효(유계 FIM 엔진).
- **[확정] Cline SDK 존재(2026-05).** `@cline/core`(stateful orchestration)·`@cline/agents`·`@cline/llms` 로 코어가 추출돼 CLI·Kanban 을 구동, IDE 확장도 SDK 위로 이관 중. → **"확장을 깊이 포크"가 아니라 "SDK 위에 얇은 프론트엔드 + 리브랜딩"** 이 가능 = 1~2명 포크 유지비 대폭 절감. Approach A 를 크게 강화.
- **[확정] 성능: OpenCode 우위 근거 없음.** 신뢰 소스(Artificial Analysis Coding Agent Index — Opus 4.7 고정 harness 비교; Terminal-Bench 2.1 리더보드)에 네 툴의 동일-모델 head-to-head 는 부재. 하네스는 5~40%p 2차 변수, 모델이 지배. Cline 자기보고 59.8%(비감사), OpenCode 는 harness 귀속 벤치 자체 없음. 출처: `artificialanalysis.ai/agents/coding-agents`, `tbench.ai/leaderboard/terminal-bench/2.1`, `thoughts.jock.pl/p/ai-coding-harness-agents-2026`.
- **[확정] 라이선스: 4개 모두 상표 grant 없음** → 리브랜딩 필수(어차피 GenOS 브랜드라 무영향).

### 1.2 갱신된 무게중심
위 확정으로 구도가 좁혀진다:
- **에이전트 코어 = Cline** (확장 포크가 아니라 **Cline SDK `@cline/core` 위 구축** + 리브랜딩): 세션 투자 보존 + 헤드리스 SDK 갓 출시(1~2명 지속가능) + Open VSX(code-server) + 활성·자금지원 업스트림 + published 벤치.
- **자동완성 = self-host FIM 자체 엔진** (GenOS 서빙 Qwen-Coder FIM): Continue EOL·Kilo 클라우드락 때문에 "활성 자동완성 프로젝트 의존"이 불가 → **얇은 자체 FIM 확장**이 지속가능. 필요시 **Continue frozen v2.0.0 자동완성 코드(Apache-2.0)를 seed** 로 활용.
  - **모델·서빙 기본값 = A(전용 소형 FIM 서빙)**: 자동완성은 에이전트 모델과 별개의 **전용 소형 FIM 코드모델**(Qwen2.5-Coder-1.5B/7B 급)을 별도 서빙으로 GenOS 가 동반/권장. chat/instruct 에이전트 모델은 FIM 미지원이라 재사용 불가. env 도 `GENOS_SERVING_*`(에이전트) ↔ `GENOS_AUTOCOMPLETE_*`(FIM) 분리. (겸용 단일 대형모델 B 는 지연 손해로 비권장.)
- **OpenCode** = 강력하나(대형 커뮤니티·MIT·CLI 천연) 자동완성 없음 + 세션 투자 폐기 + 성능 우위 미검증 → 채택 안 함. 단 *CLI-first 로 축이 바뀌면 최강 대안*으로 기록.

### 1.3 결정 갱신 (2026-07-07): 자동완성 v1 제외
자동완성이 "Cline 유일 미지원 → 별도 조립"의 원인이었는데, **트렌드가 에이전트/채팅형으로 이동**했고 이 제품의 차별점도 **에이전트 + GenOS 통합**이라, **자동완성을 v1 must-have 에서 제외**한다.
- **효과**: 크로스툴 조립 불필요 · 전용 FIM 서빙·과금정책 부담 소멸 · **베이스가 "순수 Cline 계열"로 확정**(자동완성 조립 축이 사라져 §2 의 무게중심 단순화). v1 must-have = 3개(에이전트·RAG·MCP).
- **자동완성 코드는 폐기하지 않음**: 이미 만든 `genos-autocomplete` 확장(Task 1~6, off-by-default, 미설정 시 자동 비활성)을 **선택 기능으로 레포 보관**(마케팅 체크박스 + 미래 옵션). FIM 서빙 배포·번들(M1 Task 7·8)은 **v1 에서 미추진**.
- **재검토 트리거**: 타깃 엔터프라이즈 RFP 에 자동완성이 요구되면 그때 M1 Task 7·8 재개(전용 소형 FIM 서빙 A + 이미 만든 확장 번들).

### 1.4 결정 갱신 (2026-07-07): 코드베이스 이해 = Cline native, VDB RAG 폐기
코드 이해 트렌드가 **임베딩 VDB RAG → 에이전트 직접 파일읽기**로 이동(Cline·Claude Code 모두 임베딩 인덱싱 의도적 미사용; 코드는 grep/AST 가 정밀, 임베딩은 구조손실·stale). **Cline 이 이미 `search_files`(ripgrep)·`read_file`·`list_files`·`list_code_definition_names`(tree-sitter 심볼) 로 코드베이스를 native 탐색** → "코드베이스 이해/채팅" must-have 는 **이미 충족**.
- **VDB 임베딩 RAG(구 M2) 폐기**: 중복·레거시. GenOS Weaviate 는 문서/지식 RAG 용도지 코드용 아님.
- **코드 그래프(LSP/tree-sitter/SCIP 심볼·참조·호출 그래프를 MCP 툴로)** = 대형레포 정밀 네비게이션 차별점이나 **빌드 무거워 후순위 고급 마일스톤**(v1 아님).
- **파급**: 자동완성·VDB RAG 둘 다 빠지면 **v1 must-have 3개가 모두 현 v2 Cline 확장 + 이번 세션 GenOS 통합으로 이미 충족** → v1 신규 서브시스템 빌드 ≈ 0. 남은 v1 작업 = **GenOS 통합 폴리시·브랜딩/테마·제품화(패키징/문서/버전)**.

---

## 2. 재구성된 결정 구도

제품 아키텍처는 **[에이전트 코어] + [자동완성 레이어] + [얇은 프론트엔드(VS Code 패널 + CLI)]** 로 분리된다.

- **에이전트 코어 후보**: Cline · OpenCode · Kilo Code
- **자동완성 레이어**: Continue self-host FIM (폐쇄망 검증된 유일) 또는 얇은 자체 FIM 엔진(GenOS 서빙 Qwen-Coder)
- **공통**: RAG(@codebase→GenOS VDB), MCP, GenOS 서빙 자동연결·인증헤더 주입·provisioning(세션 자산 재활용)

### 좁혀진 3개 방향
- **A. Cline 코어 유지 + 자동완성 조립** — 세션 투자(서빙 자동연결·WS·provisioning·UI) 보존, 헤드리스 Core 성숙, SWE벤치 근거. 자동완성은 Continue FIM 또는 자체 FIM.
- **B. OpenCode 코어 채택 + 자동완성 조립** — MIT·CLI 천연·깨끗한 OpenAPI 서버. 단 세션 투자 폐기 + VS Code 프론트엔드는 beta라 우리가 성숙시켜야 함.
- **C. Kilo Code 코어 채택** — 에이전트 강·다표면. 단 자동완성이 폐쇄망 탈락이라 이점 반감 + Roo/Cline 포크의 포크라 계보 복잡.

> 무게중심(§1.2 확정 반영): **A — Cline SDK(`@cline/core`) 위 구축 + 리브랜딩** + 자동완성 = **self-host 자체 FIM 엔진**(Continue frozen 코드 seed 가능). B(OpenCode)는 CLI-first 전환 시 대안, C(Kilo)는 폐쇄망 자동완성 탈락으로 후순위. 스파이크는 이 무게중심을 *반증* 시도로 검증.

---

## 3. 평가 기준 (가중치)

| # | 기준 | 가중 | 비고 |
|---|---|---|---|
| G | **라이선스/판매가능** | 게이트 | 상용 재배포·상표·어트리뷰션. 불합격 즉시 탈락. (1차: 4개 모두 통과) |
| 1 | 포크 유지비 @1~2명 | 25% | config/overlay 격리 가능 vs 소스 깊이 수정 강제, 업스트림 케이던스 |
| 2 | 헤드리스 코어 성숙도 | 15% | Cline Core/gRPC · OpenCode OpenAPI 실제 안정성·문서·프론트엔드 붙이기 난이도 |
| 3 | 에이전트 품질(동일 모델) | 15% | 같은 GenOS 모델로 하네스 실측 + 도구호출 견고성(약한모델 회복력) |
| 4 | 자동완성 실현성(폐쇄망) | 15% | Continue FIM self-host 실동작 또는 자체 FIM 공수 |
| 5 | GenOS 통합 공수 | 15% | 서빙 자동연결·인증헤더·provisioning·kill-switch 재활용도 |
| 6 | 표면 커버(VS Code 확장+CLI) | 10% | code-server(Open VSX) + CLI |
| 7 | RAG/@codebase+VDB | 5% | GenOS VDB 연결 난이도 |

---

## 4. 잔여 검증 항목 (스파이크 실행 범위)

1차 리서치가 라이선스·자동완성·아키텍처·성능(모델지배)·**Continue EOL·Cline SDK 존재**까지 해소했으므로, 스파이크는 무게중심(A + 자체 FIM)을 **반증 시도**하는 좁은 확인만 한다:
1. **Cline SDK 위 구축 실측** — `@cline/core` 로 얇은 프론트엔드(우리 VS Code 패널 + CLI)를 붙이고 리브랜딩하는 난이도·안정성 스모크. *확장 깊이 포크 대비 유지비 이점이 실제인지.*
2. **자체 FIM 자동완성 실동작** — GenOS 서빙(Qwen-Coder FIM) 엔드포인트로 얇은 자체 FIM 확장 지연/품질 스모크. + **Continue frozen v2.0.0 자동완성 코드 seed 재사용 타당성**(코드 규모·의존성·격리도) 평가.
3. **레이어드 포크 probe** — "소스 수정 없이 테마 + 서빙 자동연결 주입 + kill-switch" 가 Cline SDK 위에서 overlay/config 로 되는가(세션 v2 규율 이식).
4. **(반증용) OpenCode 코어 대안 비용** — CLI-first 로 갈 경우의 전환 비용·VS Code 프론트엔드(beta) 성숙 공수 스케치 — A 를 뒤집을 만한지 1일 확인.
5. **성능·종합 스코어카드**(워크플로우 wf_bb9a4340-9b5) URL 근거를 부록 B 로 첨부.

---

## 5. 산출물 / 결정 게이트

- **산출물**: 본 문서 + 가중 스코어카드(부록) → **에이전트 코어 1안 + 자동완성 레이어 1안 확정**.
- **결정 게이트**: A/B/C 중 코어 선택 + 자동완성(Continue FIM vs 자체 FIM) 선택. 확정 후 별도 구현 플랜(writing-plans)으로 이관.
- **비-목표(YAGNI)**: JetBrains 표면, 화이트라벨, 클라우드 SaaS 는 v1 범위 밖(기록만).

---

## 6. OneAgent 후보 평가 (2026-07-08 스파이크 보완)

> 1차 리서치(§1)가 "오픈소스 코드 어시스턴트"(Cline/Continue/Kilo/OpenCode)만 훑어 **genon 자체 범용 에이전트 OneAgent를 후보에서 누락**했다. 사용자 지적으로 보완. 근거 = 실 레포(`~/Projects/OneAgent`) 코드 직접 확인.

### 6.1 OneAgent 정체 (코드 확인)
- **ByteDance Agent-TARS / UI-TARS 포크**: `package.json` author "ByteDance", `@agent-tars/core`·`@agent-tars/cli` 의존, "GUI Agent based on UI-TARS(VLM)". genon(황승현)이 리브랜드·확장한 모노레포(CI·이슈트래킹·디자인시스템 성숙).
- **멀티모달 범용 에이전트**: 브라우저 자동화 + 컴퓨터/GUI 조작(비전, UI-TARS) + 터미널 + MCP. 표면 = Electron 데스크톱 + CLI + Web UI.
- MCP 서버 보유: filesystem(파일 read/write)·browser·search·**hwp**(한글문서). 모델 = GenOS 서빙/OpenRouter/Anthropic.
- **코드 특화 툴링 없음**(grep 확인): tree-sitter 정의탐색·diff 편집 UX·체크포인트·in-IDE(code-server) 표면 부재.

### 6.2 결정적 프레임 — 둘 다 "업스트림 포크", 차이는 *도메인 정합*
- GenCode = **Cline 포크**(상류 = 코드 에이전트) / OneAgent = **Agent-TARS 포크**(상류 = GUI 에이전트).
- 따라서 OneAgent의 기대 이점 "genon 소유 → 업스트림 추적 부담 없음"은 **성립하지 않는다**: OneAgent도 Agent-TARS 상류를 추적한다(§3 기준① 포크유지비와 동일 구조, 도메인만 어긋남).
- v1 must-have가 **순수 IDE 코딩**(사용자 확정 2026-07-08; 자동완성 §1.3·VDB RAG §1.4 제외)이므로 OneAgent의 강점(멀티모달·브라우저·컴퓨터유즈)은 이 제품 **범위 밖**.

### 6.3 §3 기준 대입 (순수 IDE 코딩)
| 기준 | GenCode (Cline) | OneAgent (Agent-TARS) |
|---|---|---|
| G 라이선스/판매 | Apache-2.0 ✓ | Agent-TARS(Apache 계열) ✓ |
| ① 포크 유지비 @1~2명 | Cline 상류(코드 도메인) | Agent-TARS 상류(GUI 도메인) — 동일 부담·도메인 불일치 |
| ② 헤드리스 코어 | Cline Core/gRPC(코드) | agent-tars core(범용 GUI) |
| ③ 에이전트 품질(코딩) | ✅ 코드 특화(diff·plan/act·코드 인지 nav) | ⚠️ 범용 loop + filesystem/터미널 MCP(blunt) |
| ⑤ GenOS 통합 | ✅ 세션 자산 재활용(#13294 서빙 자동연결·WS·provisioning) | ○ GenOS 서빙 지원(별개 통합 필요) |
| ⑥ 표면(VS Code+CLI) | ✅ code-server 익스텐션(IDE 내장) | ✗ Electron 데스크톱(IDE 밖) |
| — 멀티모달/브라우저 | 없음 | 강점 — **순수 IDE 코딩엔 무관** |

### 6.4 Verdict
- **A. GenCode(Cline) 유지 — 채택.** 순수 IDE 코딩 제품엔 *코드 에이전트 포크*가 도메인 정합. OneAgent를 베이스로 쓰면 Cline이 공짜로 주는 코드 UX(diff 편집·in-IDE 표면·코드 인지)를 재구축해야 함.
- **B. OneAgent 전환 — 기각.** GUI 에이전트에 코딩을 얹는 역방향. "genon 자체 소유" 이점도 Agent-TARS 상류 추적이라 무의미.
- **C. 공존/공유 인프라 — 채택(보조).** OneAgent는 **범용·멀티모달 자동화 제품**으로서 올바른 베이스(그 도메인엔 GenCode가 부적합). 둘은 경쟁이 아니라 상보. 공유 대상 = **GenOS 서빙·모델 레이어, MCP 툴 인프라, 디자인 토큰(GenA)**. 코드 = GenCode, 그 외 자동화 = OneAgent.

### 6.5 함의
- 스파이크 결론(§2 무게중심 A — Cline 유지)은 OneAgent 반영 후에도 **불변** — 오히려 강화(genon 내부의 유일한 대안조차 순수 코딩엔 도메인 부적합).
- 후속(YAGNI, v1 밖): GenCode↔OneAgent **공유 레이어**(MCP 서버 카탈로그, GenOS 서빙 자동연결 패턴, GenA 디자인 토큰) 중복 최소화 지점만 별도 정리.

---

## 부록 A — 제외/참고 후보
- **Tabby**: 자동완성 특화·self-host, 에이전트 약 → 자동완성 레퍼런스로만 참고.
- **Roo Code**: Cline 계열 에이전트, Kilo 가 이를 흡수 → Kilo 로 대표.
- **Void**: VS Code IDE 포크 → code-server 확장 전달과 충돌, 1~2명 유지 부담 과다 → 제외.
