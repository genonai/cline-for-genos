import { test } from "node:test"
import assert from "node:assert"
import { spawnSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

test("사전 항목을 번들에서 완전 일치 치환하고, 부분 일치는 건드리지 않는다", () => {
	const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "i18n-"))
	fs.mkdirSync(path.join(tmp, "assets"))
	fs.writeFileSync(
		path.join(tmp, "assets", "index.js"),
		`const a={label:"Read project files",d:'Read project files'};const keep="ReadProjectFilesKey";`,
	)
	const dict = path.join(tmp, "ko.json")
	fs.writeFileSync(
		dict,
		JSON.stringify({ "Read project files": "프로젝트 파일 읽기", "Never appears": "없음" }),
	)

	const res = spawnSync("node", ["scripts/translate-webview.mjs", "--dict", dict, "--target", tmp], {
		encoding: "utf8",
	})

	const result = fs.readFileSync(path.join(tmp, "assets", "index.js"), "utf8")
	assert.match(result, /"프로젝트 파일 읽기"/)
	assert.match(result, /'프로젝트 파일 읽기'/)
	assert.doesNotMatch(result, /Read project files/)
	assert.match(result, /ReadProjectFilesKey/)
	assert.match(res.stdout, /1\/2 entries replaced/)
	assert.match(res.stderr, /unmatched/)
	assert.match(res.stderr, /Never appears/)
})
