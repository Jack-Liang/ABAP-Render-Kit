# UI5 诊断 Probe 链（6 个，递进验证）

6 个 probe 脚本，从最简到最复杂，构成"UI5 能否在 SAP GUI HTML Viewer (Edge 内核) 下加载并工作"的完整可行性验证链。**每个 probe 解答的疑问不同，不是冗余迭代**——按 01 → 06 顺序阅读运行即可看到决策链的递进逻辑。

## 推荐运行顺序与说明

| # | 文件 | 验证问题 | 期望结果 |
|---|---|---|---|
| 01 | [`01-core-load.html`](01-core-load.html) | 能否加载 core.js + 创建 JSONModel/Button？ | log 区显示 `core.js onload OK` → `attachInit fired` → `JSONModel created: hello` → `button placed, dom=1` |
| 02 | [`02-module-require.html`](02-module-require.html) | 各模块 URL 可达性 + `sap.ui.require` 异步机制？ | 各 `sap/m/*.js` 报 `LOAD OK`，`sap.ui.require OK: Button=function JSONModel=function` |
| 03 | [`03-bootstrap-config.html`](03-bootstrap-config.html) | 用官方 bootstrap 配置（`id=sap-ui-bootstrap` + theme/libs/compatVersion/async）+ `sap.ui.define` 能否工作？ | `core ready` → `require OK` → `define OK: function` → `placed, .sapMBtn count=1` |
| 04 | [`04-sapm-modules.html`](04-sapm-modules.html) | 16 个 sap.m 控件能否逐模块 require 加载？ | 全部 `OK: sap/m/...`，无 `ERR` 或 `STILL PENDING` |
| 05 | [`05-echarts-sapf.html`](05-echarts-sapf.html) | 在 04 基础上引入 ECharts CDN + `sap.f`/`sap.ui.layout` 联合探测？ | `core ready, echarts=object`，全部模块 `OK` |
| 06 | [`06-export-spreadsheet.html`](06-export-spreadsheet.html) | `sap/ui/export/Spreadsheet` 等导出相关模块可达？ | 4 个模块状态。**注意**：`sap.ui.export` 不在 OpenUI5（许可限制），OpenUI5 CDN 下会 `ERR`，须换 SAPUI5 (`ui5.sap.com`) 才会 `OK` |

## 使用方法

1. 直接双击 `01-core-load.html` 在 Edge 浏览器打开
2. 页面内 `#log` div 实时输出诊断信息（**不是浏览器控制台**——SAP GUI 自动化下控制台看不到）
3. 若任一 probe 报 `ERR` 或 `core not ready`，对照期望结果定位失败点
4. 通过本链后即可信 UI5 在目标 SAP GUI 版本能加载，可进入主 demo 验证交互架构

## 与主 demo 的衔接

- 01-03 通过 → 可运行 [`ui5-spike.html`](../ui5-spike.html)（最小交互验证）
- 04 通过 → 可运行 [`ui5-showcase.html`](../ui5-showcase.html)（完整 UI5 + ECharts 混排）
- 05 通过 → UI5+ECharts 联合可行，showcase 不需 fallback
- 06 验证 → 决定 [`ui5-export.html`](../ui5-export.html) 的 SAPUI5/OpenUI5 选型

## 调试提示

- 探测页模式源自 plan 文档 §6.3："DOM 日志（`window.onerror` → `#errlog` div）+ probe 逐模块探测页"
- 所有 probe 用同一 CDN：`https://sdk.openui5.org/resources/sap-ui-core.js`（**`.org` 域名**）
- async bootstrap 下用 `sap.ui.require`，不要 `sap.ui.define`（在本环境报跨域 "Script error." 静默失败，详见 plan 文档 §6.2）
