# Demo — UI5 集成方案验证素材

本目录存放 ARK × UI5 集成方案 B 的浏览器端验证素材，对应 [`docs/ui5-integration-plan.md`](../docs/ui5-integration-plan.md) 的决策路径。每个文件都是一条独立可复现的验证链节点，**不依赖 ABAP 系统**，直接用浏览器打开即可运行。

## 主 demo（5 个，平铺在本目录）

| 文件 | 角色 | 关键定位 |
|---|---|---|
| [`fiori-style-demo.html`](fiori-style-demo.html) | **视觉基线**（无 UI5） | 纯 HTML+CSS+ECharts 手工实现 Fiori Quartz/Horizon 设计令牌，无 JS 运行时。是"走 UI5 之前能做到什么程度"的对照 |
| [`ui5-spike.html`](ui5-spike.html) | **方案 B 核心验证** | UI5 JSONModel 数据绑定 + 模拟 sapevent 往返 + `setData` 局部更新无重 boot。**最重要的架构验证文件** |
| [`ui5-showcase.html`](ui5-showcase.html) | **UI5 完整集成 demo** | `fiori-style-demo` 的 UI5 实现版：ShellBar/工具栏/表格用 `sap.m`+`sap.f`，KPI 卡与图表用原生 div + ECharts（因 `sap.ui.core.Html` 已从新版 UI5 移除） |
| [`ui5-codediff.html`](ui5-codediff.html) | **代码分栏对比工具** | 项目真实案例（如 `build_html_document` 旧→新）的 diff 可视化，文档工具性质，非 runtime demo |
| [`ui5-export.html`](ui5-export.html) | **Excel 导出扩展能力 demo** | `sap.m.Table` + `sap.ui.export.Spreadsheet` 客户端 xlsx 导出。**注意**：`sap.ui.export` 不在 OpenUI5（许可限制），必须 SAPUI5 (`ui5.sap.com`) |

## probes/ 子目录

6 个递进诊断脚本，从最简到最复杂，验证 UI5 能否在 SAP GUI HTML Viewer (Edge 内核) 下加载与工作。详见 [`probes/README.md`](probes/README.md)。

## 运行方式

### 浏览器直接打开
所有 HTML 文件可双击直接在 Edge / Chrome / Firefox 中打开运行。CDN 依赖：
- OpenUI5：`https://sdk.openui5.org/resources/sap-ui-core.js`（**注意用 `.org` 域名**，`.com` 不可达）
- ECharts：`https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js`
- SAPUI5（仅 `ui5-export.html`）：`https://ui5.sap.com/resources/sap-ui-core.js`

### SAP GUI HTML Viewer 内验证
浏览器 spike 验证通过后，下一步是把 showcase 的 HTML 写进 ABAP 验证页输出，走 `zcl_ark_gui` 渲染管线，在 SAP GUI 7.70+ Edge 内核下复测。详见 plan 文档 §4.1。

### 离线环境
把 `echarts.min.js` 上传到 SMW0 MIME 仓库，用 `cache_asset` 链路替换 CDN（与 `zcl_ark_echarts` 的离线模式同构）。UI5 离线分发需 SAPUI5 self-contained 包（Node + ui5-tooling 构建），见 plan 文档 §4.4。

## 与 docs/ 的对应关系

| `demo/` 文件 | 对应 `docs/ui5-integration-plan.md` 章节 |
|---|---|
| `ui5-spike.html` | §3 目标架构 + §6.2 前端硬代价（UI5 常驻 + setData 胜负手） |
| `ui5-showcase.html` | §3 关键设计结论（`sap.ui.core.Html` 移除 → ECharts 与 UI5 分区混排） |
| `ui5-export.html` | §4.5 示例迁移 + 扩展能力 |
| `probes/01-06` | §6.2 前端硬代价 + §6.3 工具链注意（probe 逐模块探测页模式） |

## Git 状态说明

> ⚠️ [`docs/ui5-integration-plan.md`](../docs/ui5-integration-plan.md) 第 67 行 + 第 94 行声称 "`demo/` 已 gitignore（本地验证素材不入库）"——**这是与现状不符的过时陈述**。实际 `.gitignore` 未列入 `demo/`，本目录文件均纳入版本管理。原 plan 文档已修正，详见 [`docs/README.md`](../docs/README.md)。

之所以保留入库：实验项目（README 已声明）的核心价值之一是**决策可追溯**，这些验证素材是方案 B 落地论证链的物证，删除会让未来贡献者无法复现决策依据。
