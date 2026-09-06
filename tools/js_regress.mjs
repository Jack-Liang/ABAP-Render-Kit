#!/usr/bin/env node
/**
 * ARK 嵌入式 JS 语法回归门禁。
 *
 * 背景：abaplint 查不出 ABAP 字符串里拼出来的 JS 语法错。three.js 的三次
 * 事故（相邻字符串字面量 ×2、三元双冒号）全部属于此类型，且都是真机白图
 * 才发现。本脚本把"部署后抽 HTML → node --check 每个内联脚本"的手工流程
 * 固化成门禁：
 *
 *   1) demo/*.html 的内联 <script>     —— 纯本地，可进 GitHub CI（--demo-only）
 *   2) ABAP 示例页真实渲染的内联 <script> —— 经 vsp 无 GUI 渲染（需本地系统）
 *
 * 用法：
 *   node tools/js_regress.mjs --demo-only              # 只查 demo（CI 模式）
 *   node tools/js_regress.mjs [-s a4h] [--vsp <路径>]  # demo + 系统渲染
 *
 * 环境变量：VSP_BIN（vsp 可执行文件路径，默认 'vsp'）
 * 退出码：任一内联脚本语法错或页面渲染失败 → 1
 */

import { readdirSync, readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, basename } from 'node:path';
import { spawnSync } from 'node:child_process';

const args = process.argv.slice(2);
const demoOnly = args.includes('--demo-only');
const systemIdx = args.indexOf('-s') >= 0 ? args.indexOf('-s') : args.indexOf('--system');
const system = systemIdx >= 0 ? args[systemIdx + 1] : undefined;
const vspBin = process.env.VSP_BIN || 'vsp';

// 系统渲染覆盖的示例页（新示例页加入此清单）
const PAGES = [
  'ZCL_ARK_EXAMPLE_HELLO_PAGE',
  'ZCL_ARK_EXAMPLE_FORM_PAGE',
  'ZCL_ARK_EXAMPLE_TABLE_PAGE',
  'ZCL_ARK_EXAMPLE_CHART_PAGE',
  'ZCL_ARK_EXAMPLE_DATA_PAGE',
  'ZCL_ARK_EXAMPLE_BROWSER_PAGE',
  'ZCL_ARK_EXAMPLE_THREE_PAGE',
  'ZCL_ARK_EXAMPLE_STATE_PAGE',
  'ZCL_ARK_EXAMPLE_UI5_STATE_PAGE',
  'ZCL_ARK_EXAMPLE_UI5_PAGE',
];

const tmp = mkdtempSync(join(tmpdir(), 'ark-js-regress-'));
let failures = 0;
let checked = 0;

/** 抽取 HTML 里的内联 <script>（跳过 src= 外链），逐块 node --check */
function checkInlineScripts(name, html) {
  const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let m;
  let count = 0;
  while ((m = re.exec(html)) !== null) {
    if (/\bsrc\s*=/i.test(m[1])) continue; // 外链脚本由浏览器/引擎自己加载
    const body = m[2];
    if (!body.trim()) continue;
    count += 1;
    const file = join(tmp, `${name.replace(/[^\w-]/g, '_')}_${count}.js`);
    writeFileSync(file, body, 'utf8');
    const r = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
    if (r.status !== 0) {
      failures += 1;
      console.error(`  ✗ 内联脚本 #${count} 语法错误:`);
      console.error(r.stderr.trim().split('\n').slice(0, 6).join('\n'));
    }
  }
  checked += count;
  return count;
}

// ---------- 1) demo/*.html（本地，CI 可跑） ----------
const repoRoot = new URL('..', import.meta.url).pathname;
const demoDir = join(repoRoot, 'demo');
for (const f of readdirSync(demoDir).filter((f) => f.endsWith('.html'))) {
  const n = checkInlineScripts(`demo_${basename(f, '.html')}`, readFileSync(join(demoDir, f), 'utf8'));
  console.log(`demo/${f}: ${n} 个内联脚本`);
}

// ---------- 2) ABAP 示例页真实渲染（需 vsp + 系统） ----------
if (!demoOnly) {
  for (const cls of PAGES) {
    const abap = `
DATA lo_page TYPE REF TO zif_ark_gui_renderable.
DATA lo_html TYPE REF TO zif_ark_html.
zcl_ark_js_library=>register( iv_name = zcl_ark_echarts=>c_lib_name iv_url = zcl_ark_echarts=>c_cdn_url ).
zcl_ark_js_library=>register( iv_name = zcl_ark_three_view=>c_lib_name iv_url = zcl_ark_three_view=>c_cdn_url ).
CREATE OBJECT lo_page TYPE ('${cls}').
lo_html = lo_page->render( ).
lv_result = cl_http_utility=>encode_x_base64( zcl_ark_convert=>string_to_xstring( lo_html->render( ) ) ).
`;
    const abapFile = join(tmp, 'page.abap');
    writeFileSync(abapFile, abap, 'utf8');
    const vspArgs = system ? ['-s', system, 'execute', '--file', abapFile] : ['execute', '--file', abapFile];
    const r2 = spawnSync(vspBin, vspArgs, { encoding: 'utf8', timeout: 120000 });
    const out = (r2.stdout || '') + (r2.stderr || '');
    const m = out.match(/([A-Za-z0-9+/=]{200,})\s*Executed successfully/s);
    if (!m) {
      failures += 1;
      console.error(`${cls}: ✗ 渲染失败（无有效输出）`);
      console.error(out.trim().split('\n').slice(0, 4).join('\n'));
      continue;
    }
    const html = Buffer.from(m[1], 'base64').toString('utf8');
    const n = checkInlineScripts(cls, html);
    console.log(`${cls}: ${n} 个内联脚本`);
  }
}

rmSync(tmp, { recursive: true, force: true });
console.log(`\n共检查 ${checked} 个内联脚本，${failures} 个失败`);
process.exit(failures > 0 ? 1 : 0);
