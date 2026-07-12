#!/usr/bin/env node
// 번들(webview build + extension dist) 내 "사용자 노출 Cline 문자열"을 GenCode 로 치환.
// 전략: bare "Cline" 은 절대 건드리지 않는다(refreshClineModelsRpc, .clinerules, ClineError 등 내부
// 식별자와 충돌). 오직 아래 화이트리스트의 **완전 문구**만 교체한다.
// ⚠️ upstream 분기 갱신마다 재검증: 신규 UI 문자열이 유입될 수 있으므로 빌드 후 남은 사용자노출
//    "Cline" 을 scripts/check-forbidden-strings.sh 게이트로 확인하고 이 목록을 보강한다.
// 근거: 브랜딩 감사 2026-07-07 (명령/메뉴 라벨은 package.json jq 에서 처리, 여기선 webview UI 문구).

import { readdirSync, statSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

// [from, to] — 완전 문구만. 순서 주의(긴 문구 먼저).
const REPLACEMENTS = [
  ['Generate Commit Message with Cline', 'Generate Commit Message with GenCode'],
  ['Generate Jupyter Cell with Cline', 'Generate Jupyter Cell with GenCode'],
  ['Explain Jupyter Cell with Cline', 'Explain Jupyter Cell with GenCode'],
  ['Improve Jupyter Cell with Cline', 'Improve Jupyter Cell with GenCode'],
  ['Create a Github issue with Cline', 'Create a Github issue with GenCode'],
  ['Add to Cline Chat', 'Add to GenCode Chat'],
  ['Add to Cline', 'Add to GenCode'],
  ['Improve with Cline', 'Improve with GenCode'],
  ['Explain with Cline', 'Explain with GenCode'],
  ['Fix with Cline', 'Fix with GenCode'],
  ['fixWithCline', 'fixWithCline'], // 내부 커맨드 id — 불변(자기치환으로 문서화)
  ['with Cline', 'with GenCode'],
  ['Cline instance aborted', 'GenCode instance aborted'],
  ['No Cline account auth token found', 'No GenCode account auth token found'],
]

function parseArgs(argv) {
  const out = {}
  for (let i = 2; i < argv.length; i += 2) out[argv[i].replace(/^--/, '')] = argv[i + 1]
  return out
}

function walk(dir, exts) {
  const files = []
  const visit = (d) => {
    for (const name of readdirSync(d)) {
      const p = join(d, name)
      const s = statSync(p)
      if (s.isDirectory()) visit(p)
      else if (exts.some((e) => name.endsWith(e))) files.push(p)
    }
  }
  try {
    visit(dir)
  } catch {
    /* dir 없음 무시 */
  }
  return files
}

// 사용자노출 "Cline" 단어를 GenCode 로 치환하는 정규식.
// - 단어경계(대소문자 구분): "ClineError"/"clineAsk"/".clinerules" 등 결합/소문자 식별자는 미매칭.
// - 앞: 워드문자/./ 아님(식별자·경로 접두 배제) / 뒤: 워드문자·. ·( ·/ 아님(코드 프로퍼티/호출/경로 배제).
//   → "Cline." "Cline(" 같은 코드 참조(번들 내 7건)와 URL(cline.bot 등)을 보존, 문장 속 "Cline"만 교체.
const WORD_CLINE = /(?<![\w.\/])Cline(?![\w.(\/])/g

function applyTo(dir) {
  let total = 0
  for (const file of walk(dir, ['.js', '.html', '.css'])) {
    let text = readFileSync(file, 'utf8')
    const before = text
    // 1) 큐레이션된 확정 문구(안전) 먼저
    for (const [from, to] of REPLACEMENTS) {
      if (from !== to && text.includes(from)) text = text.split(from).join(to)
    }
    // 2) 단어경계 포괄 치환(식별자·코드참조 보존)
    text = text.replace(WORD_CLINE, 'GenCode')
    if (text !== before) {
      writeFileSync(file, text)
      total++
    }
  }
  return total
}

const args = parseArgs(process.argv)
let count = 0
if (args.target) count += applyTo(args.target)
if (args.dist) count += applyTo(args.dist)
console.log(`[rebrand] webview/dist 사용자노출 문구 치환 적용: ${count}건`)
