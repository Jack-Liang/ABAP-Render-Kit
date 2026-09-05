# ARK 测试指南

三层测试体系：静态检查（零 SAP 依赖）→ ABAP 单测（测渲染逻辑）→ 无头浏览器黑盒测试（测前端行为）。

## 1. abaplint 静态检查（本地 / CI）

```bash
npx -y @abaplint/cli@latest   # 读 abaplint.json，0 issue 为过
```

目标版本 ABAP Platform 2023（v757）。主要防激活错误回归（语法、丢实现、未定义类型等）。GitHub Actions 见 `.github/workflows/abaplint.yml`，push/PR 自动跑。

注意：`check_syntax` 依赖 `dependencies` 里的 open-abap 补齐 SAP 标准类（如 `CX_STATIC_CHECK`），勿删。

## 2. ABAP Unit 测试（在 SAP 系统里跑）

覆盖 core 层确定性逻辑，文件为各类的 `.clas.testclasses.abap`：

| 被测类 | 覆盖点 |
|---|---|
| `zcl_ark_convert` | escape_html / escape_js / URL 编解码 / UTF-8 往返 |
| `zcl_ark_html` | sapevent/url/onclick 链接、data 属性、嵌套渲染、is_empty |
| `zcl_ark_js_bridge` | arkEmit 语句生成、参数转义、页面作用域去重 |
| `zcl_ark_js_library` | 注册校验、inline 注入、同页幂等、include_for、未注册异常 |

运行：ADT 里对上述类 Ctrl+F9（或右键 Run As → ABAP Unit Test）；也可整包跑。已知 abaplint 限制：本地类不要写双层 `~` 接口方法实现（SAP 里合法），见 `zcl_ark_js_library.clas.locals_def.abap` 的注释。

## 3. 无头浏览器黑盒测试（Playwright）

前提：渲染产物是纯 HTML，完全可以在普通浏览器里验证"图表画出来、点击触发回调"，绕开 SAP GUI 的 HTML Viewer。

**第一步（SAP 里，一次性导出）**：运行 `ZARK_EXPORT_HTML`：

- `P_PAGE`：HELLO / FORM / TABLE / CHART / DATA / BROWSER
- `P_PATH`：导出 html 全路径，如 `C:\ark_test\ark_export.html`

同目录自动生成 `ark_echarts.min.js`、`ark_map_china.js`（相对引用，三件套可整体拷走）。导出页里的 `arkEmit` 已被 mock：不做 sapevent 导航，而是写入 `window.__arkLog` 并打印 console（前缀 `ARKEVENT`）。

**第二步（本机）**：

```bash
cd tools
npm i playwright && npx playwright install chromium   # 首次
node ark_ui_test.mjs <导出目录>
```

检查：无 JS 运行时错误、ECharts canvas 已渲染、`__arkLog` 回调清单、页面相对引用的资产文件齐全。非 0 退出码即失败。

**仍需手工验证的一环**：SAP GUI 真实拦截 sapevent（mock 之外的最后一公里）。跑一次 `ZARK_EXAMPLE`，用 Browser Info 页确认 Edge 内核 + 图表页点一下带回调的元素即可。

## 已知边界

- 地图 choropleth 的省份点击回调在导出页同样经 `__arkLog` 可见，可直接断言。
- `ZARK_ECHARTS_DEMO` 的页面类是程序局部类，导出程序目前只覆盖 `zcl_ark_example_*` 页面族。
