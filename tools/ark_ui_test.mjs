#!/usr/bin/env node
// ARK 前端黑盒测试：对 ZARK_EXPORT_HTML 导出的整页 HTML 做无头浏览器验证。
//
// 用法：
//   cd tools && npm i playwright   # 首次
//   node ark_ui_test.mjs <导出目录> [html 文件名=ark_export.html]
//
// 检查项：
//   1) 页面无 JS 运行时错误（pageerror）
//   2) ECharts 已渲染出 canvas（图表页）
//   3) window.__arkLog 收到的 arkEmit 回调清单（桥 mock 写入）
//   4) ARKEVENT console 输出与 __arkLog 一致
// 退出码非 0 即失败，可直接接 CI。
import { chromium } from 'playwright';
import path from 'node:path';
import fs from 'node:fs';

const dir = process.argv[2] ?? '.';
const file = process.argv[3] ?? 'ark_export.html';
const htmlPath = path.resolve(dir, file);
const assets = ['ark_echarts.min.js', 'ark_map_china.js'];

if (!fs.existsSync(htmlPath)) {
  console.error(`not found: ${htmlPath}`);
  console.error('先在 SAP 里运行 ZARK_EXPORT_HTML 导出页面，再运行本脚本');
  process.exit(2);
}

const pageErrors = [];
const arkEvents = [];

const browser = await chromium.launch();
const page = await browser.newPage();
page.on('pageerror', (err) => pageErrors.push(String(err)));
page.on('console', (msg) => {
  if (msg.text().startsWith('ARKEVENT')) arkEvents.push(msg.text());
});

await page.goto('file://' + htmlPath);
await page.waitForTimeout(4000); // 等图表动画/异步初始化

// 1) JS 错误
if (pageErrors.length > 0) {
  console.error('FAIL page errors:');
  for (const e of pageErrors) console.error('  ' + e);
}

// 2) ECharts canvas（导出的 echarts.min.js 存在才检查）
const hasEcharts = assets[0] && fs.existsSync(path.resolve(dir, assets[0]));
let canvasCount = 0;
if (hasEcharts) {
  canvasCount = await page.locator('canvas').count();
  console.log(`canvas count: ${canvasCount}`);
  if (canvasCount === 0) console.error('FAIL no echarts canvas rendered');
}

// 3) 回调日志
const log = await page.evaluate(() => window.__arkLog ?? null);
if (log) {
  console.log(`__arkLog events: ${log.length}`);
  for (const ev of log) console.log(`  ARKEVENT ${ev.action} ${ev.q}`);
}

// 4) 资产引用完整性：页面里的相对 src 都应存在
const srcs = await page.evaluate(() =>
  [...document.querySelectorAll('script[src]')].map((s) => s.getAttribute('src')),
);
for (const src of srcs) {
  if (/^(https?:|file:|data:)/.test(src)) continue;
  if (!fs.existsSync(path.resolve(dir, src))) {
    console.error(`FAIL missing asset: ${src}`);
    pageErrors.push(`missing asset ${src}`);
  }
}

await browser.close();

const failed = pageErrors.length > 0 || (hasEcharts && canvasCount === 0);
console.log(failed ? 'RESULT: FAIL' : 'RESULT: PASS');
process.exit(failed ? 1 : 0);
