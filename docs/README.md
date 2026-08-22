# Docs — ARK 决策档案

本目录存放项目级决策档案与开发交接文档。文档**入库**纳入版本管理（与 `demo/` 一样），便于跨会话/跨贡献者复现决策路径。

## 文档索引

| 文档 | 日期 | 角色 |
|---|---|---|
| [`ui5-integration-plan.md`](ui5-integration-plan.md) | 2026-08-22 | ARK × UI5 集成方案 B 的开发交接文档：决策背景、目标架构、分阶段路线、现有资产、硬代价与已知坑、新会话开工清单 |

## `ui5-integration-plan.md` 摘要

- **决策**：方案 B —— 前端加载 UI5 运行时，直接用 `sap.m` 等 Fiori 控件；ABAP 侧只产出 state JSON，不写 HTML
- **环境基线**：本地 Docker a4h（ABAP Platform 2023 / SAP_BASIS 7.57）+ SAP GUI 7.70+ Edge 内核 only
- **目标架构**：UI5 启动壳常驻 + `JSONModel.setData()` 局部更新；ECharts 与 UI5 分区混排（因 `sap.ui.core.Html` 已从新版 UI5 移除）；事件桥走隐藏 iframe 提交 sapevent
- **分阶段路线**：① 宿主验证（待 a4h+Edge 实测）→ ② UI5 启动壳 → ③ state→UI5 映射层 → ④ 离线分发（SAPUI5 self-contained 包）→ ⑤ 示例迁移
- **硬代价**：7.57 ABAP 语法地雷、UI5 CDN 域名、async bootstrap 用 `sap.ui.require` 而非 `define`、ECharts 与 UI5 分区等

## 与 `demo/` 的对应关系

`docs/ui5-integration-plan.md` 引用的浏览器验证素材均落地于 [`../demo/`](../demo/)：

| plan 章节 | 对应 demo 文件 |
|---|---|
| §3 目标架构 + §6.2 UI5 常驻胜负手 | [`demo/ui5-spike.html`](../demo/ui5-spike.html) |
| §3 `sap.ui.core.Html` 移除结论 | [`demo/ui5-showcase.html`](../demo/ui5-showcase.html) |
| §4.5 示例迁移 + 扩展能力 | [`demo/ui5-export.html`](../demo/ui5-export.html) |
| §6.2 前端硬代价 + §6.3 探测页模式 | [`demo/probes/01-06`](../demo/probes/README.md) |

## ⚠️ 文档勘误：`demo/` gitignore 状态

`ui5-integration-plan.md` 中有两处与现状不符的过时陈述：

- **第 67 行**："demo（本地，gitignored）：ui5-spike / ui5-showcase / ui5-codediff / probe1-5"
- **第 94 行**："`demo/` 已 gitignore（本地验证素材不入库）；`docs/` 入库"

**现实**：`.gitignore` 未列入 `demo/`，本仓库的 `demo/` 与 `docs/` 均纳入版本管理。原 plan 文档写于"计划 gitignore 但未执行"的状态，与最终落地不一致。

**为何保留 `demo/` 入库**：ARK 已在 README 声明为**实验项目**，实验项目的核心价值之一是决策可追溯。`demo/` 下的浏览器验证素材是方案 B 落地论证链的物证，删除或本地化会让未来贡献者无法复现"为什么走 UI5 路线"的论证依据。

建议后续会话编辑 `ui5-integration-plan.md` 第 67 行与第 94 行，将"gitignored"改为"入库"以与现实一致。

## 敏感信息

通读 `ui5-integration-plan.md` 全文确认无敏感信息泄露：

- 第 24 行提到"ADT MCP Server（localhost:2236，Bearer token 见会话）"——"见会话"指开发期对话会话，**token 值未写入文档**
- 第 22 行 Docker 镜像名 `sapse/abap-cloud-developer-trial:2023` 是 SAP 官方公开镜像
- 第 25 行 `github.com/Jack-Liang/ABAP-Render-Kit` 是项目公开仓库地址本身

均不构成泄露。

## 维护约定

- **入库**：本目录所有文档纳入 git 版本管理
- **跨会话交接**：新会话开工时优先读本目录索引，再按 `ui5-integration-plan.md` §8 的开工清单操作
- **勘误处理**：发现文档与现实不符时，新增 `docs/README.md` 索引或直接编辑原文档订正，避免决策漂移
- **提交格式**：`docs(范围): 摘要` 中文提交信息
