# GenCode

GenOS 코딩 에이전트 — 폐쇄망(온프렘) 환경에서 GenOS 서빙에 연결해 동작하는 VS Code 확장.

<div align="center">
<table>
<tbody>
<td align="center">
<a href="https://github.com/genonai/cline-for-genos/releases" target="_blank"><strong>Download VSIX (Releases)</strong></a>
</td>
<td align="center">
<a href="https://github.com/genonai/cline-for-genos/issues" target="_blank"><strong>Issues</strong></a>
</td>
</tbody>
</table>
</div>

GenCode 는 계획(Plan)·실행(Act) 에이전트 루프로 소프트웨어 개발 작업을 단계별로 처리합니다. 파일 생성·편집, 대형 프로젝트 탐색(AST·정규식 검색·파일 읽기), 터미널 실행(승인 후), Model Context Protocol(MCP) 툴 확장을 지원하며, 모든 파일 변경·터미널 명령을 사용자가 승인하는 human-in-the-loop GUI 를 제공합니다.

## GenOS 통합 (차별점)
- **GenOS 서빙 자동 연결** — 코드스페이스 생성 시 선택한 서빙에 자동 연결(모델/URL/키 주입).
- **폐쇄망 안전** — 외부 텔레메트리·인증 kill-switch. 모델 호출은 GenOS 서빙 엔드포인트로만.
- **한국어 UI** — GenOS 환경에 맞춘 현지화.

## 주요 기능
- **모든 API/모델** — OpenAI 호환 엔드포인트(GenOS 서빙 포함), 로컬 모델(LM Studio/Ollama) 등.
- **터미널 실행** — 명령 실행·출력 모니터링(승인 기반), 장시간 프로세스 백그라운드 진행.
- **파일 생성·편집** — diff 뷰로 변경 확인·되돌리기, 린터/컴파일러 오류 자동 대응.
- **컨텍스트 추가** — `@file` · `@folder` · `@problems` · `@url`.
- **체크포인트** — 단계별 워크스페이스 스냅샷 비교·복원.
- **MCP 툴 확장** — "add a tool that…" 로 커스텀 도구 생성·설치.

## License / Attribution

Apache License 2.0. 자세한 내용은 [LICENSE.txt](./LICENSE.txt) 참고.

GenCode 는 [Cline](https://github.com/cline/cline)(© Cline Bot Inc., Apache-2.0)을 기반으로 리브랜딩한 배포판입니다. 원저작권 표기는 LICENSE.txt·[NOTICE](./NOTICE) 에 유지됩니다. "Cline" 은 Cline Bot Inc. 의 상표이며, 여기서는 원본 출처 표기 목적으로만 사용됩니다. 본 제품은 Cline Bot Inc. 와 제휴·보증 관계가 없습니다.
