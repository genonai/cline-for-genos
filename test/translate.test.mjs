import { test } from "node:test"
import assert from "node:assert"
import { spawnSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)))

test("사전 항목을 번들에서 완전 일치 치환하고, 부분 일치는 건드리지 않는다", () => {
	const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "i18n-"))
	fs.mkdirSync(path.join(tmp, "assets"))
	fs.writeFileSync(
		path.join(tmp, "assets", "index.js"),
		`const a={label:"Read project files",d:'Read project files',price:"Price"};const keep="ReadProjectFilesKey";`,
	)
	const dict = path.join(tmp, "ko.json")
	fs.writeFileSync(
		dict,
		JSON.stringify({
			"Read project files": "프로젝트 파일 읽기",
			"Never appears": "없음",
			"Price": "가격 $100 $&",
		}),
	)

	const res = spawnSync("node", ["scripts/translate-webview.mjs", "--dict", dict, "--target", tmp], {
		encoding: "utf8",
		cwd: ROOT,
	})

	assert.strictEqual(res.status, 0, `translate-webview exited ${res.status}: ${res.stderr}`)
	const result = fs.readFileSync(path.join(tmp, "assets", "index.js"), "utf8")
	assert.match(result, /"프로젝트 파일 읽기"/)
	assert.match(result, /'프로젝트 파일 읽기'/)
	assert.doesNotMatch(result, /Read project files/)
	assert.match(result, /ReadProjectFilesKey/)
	// $ 포함 치환값이 패턴($& 등)으로 해석되지 않고 그대로 들어가는지 (replaceAll 함수 인자 회귀 방지)
	// 주의: $100은 문자열 패턴에선 캡처 그룹이 없어 구버전에서도 리터럴 유지 — 실제 회귀를 잡는 건 $&
	assert.match(result, /"가격 \$100 \$&"/)
	assert.match(res.stdout, /2\/3 entries replaced/)
	assert.match(res.stderr, /unmatched/)
	assert.match(res.stderr, /Never appears/)
})
