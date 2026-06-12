#!/usr/bin/env node
// webview 빌드 출력물(JS 번들)에서 i18n 사전의 "완전 일치 문자열 리터럴"만 치환한다.
// upstream 소스는 건드리지 않음 — 미매칭 항목은 리포트만 하고 빌드는 실패시키지 않는다.
import fs from "node:fs"
import path from "node:path"

const args = process.argv.slice(2)
const get = (flag) => {
	const i = args.indexOf(flag)
	return i >= 0 ? args[i + 1] : null
}
const dictPath = get("--dict")
const targetDir = get("--target")
if (!dictPath || !targetDir) {
	console.error("usage: translate-webview.mjs --dict <ko.json> --target <webview build dir>")
	process.exit(1)
}

const dict = JSON.parse(fs.readFileSync(dictPath, "utf8"))
const files = []
;(function walk(d) {
	for (const e of fs.readdirSync(d, { withFileTypes: true })) {
		const p = path.join(d, e.name)
		if (e.isDirectory()) walk(p)
		else if (/\.(js|mjs|cjs)$/.test(e.name)) files.push(p)
	}
})(targetDir)

const counts = Object.fromEntries(Object.keys(dict).map((k) => [k, 0]))
for (const f of files) {
	let src = fs.readFileSync(f, "utf8")
	for (const [en, ko] of Object.entries(dict)) {
		const variants = [
			[JSON.stringify(en), JSON.stringify(ko)],
			[`'${en.replaceAll("'", "\\'")}'`, `'${ko.replaceAll("'", "\\'")}'`],
		]
		for (const [from, to] of variants) {
			if (src.includes(from)) {
				counts[en] += src.split(from).length - 1
				src = src.replaceAll(from, to)
			}
		}
	}
	fs.writeFileSync(f, src)
}

const total = Object.keys(dict).length
const hit = Object.values(counts).filter((n) => n > 0).length
console.log(`[i18n] ${hit}/${total} entries replaced across ${files.length} files`)
const missed = Object.entries(counts)
	.filter(([, n]) => n === 0)
	.map(([k]) => k)
if (missed.length) {
	console.warn("[i18n] unmatched (upstream 라벨 변경 추정 — 영문 유지, 분기 갱신 시 사전 보수):")
	for (const m of missed) console.warn(`  - ${m}`)
}
