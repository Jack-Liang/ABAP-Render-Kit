# ARK × UI5 集成方案（方案 B）— 开发交接文档

> 本文档是方案决策与验证阶段的完整交接，供新会话零上下文接手开发。
> 日期：2026-08-22。前序讨论与验证记录见 git 历史与本文"验证结论"一节。

## 1. 项目与决策背景

**ARK（ABAP Render Kit）**：在 SAP GUI 的 `CL_GUI_HTML_VIEWER` 内构建富 HTML UI 的 ABAP 框架，从 abapGit 提取精炼而来。三层架构：core 引擎（`zcl_ark_gui`/`zcl_ark_html`/viewer/sapevent 分发）→ framework 页面框架 → components 组件。

**最终决策：方案 B —— 前端加载 UI5 运行时，直接使用 sap.m 等 Fiori 控件；ABAP 侧只产出数据（state JSON），不写 HTML。**

决策路径（勿再重复评估）：
- 最初因"客户端不假设 SAP GUI 7.70+"放弃 B 走了方案 A（自建渲染器）；
- 后兼容性放宽为 **Edge-only**（SAP GUI 7.70+ 且切换 Edge 内核，IE 内核不支持），B 的硬约束解除；
- A 路线完成 v1（`zcl_ark_state_page` 声明式状态页 + ALV 三件套 + `zcl_ark_theme` Fiori 主题层），但"每个视觉效果都要改框架代码"的词汇表建设成本促使用户最终拍板 B；
- 浏览器 spike 验证 B 的交互模型（UI5 常驻 + setData 局部更新）性能良好，原"每次交互重 boot"的顾虑仅存在于 naive 整页重载集成，正确架构天然规避。

## 2. 环境基线（README 已写入）

| 项 | 值 |
|---|---|
| 服务端 | 本地 Docker a4h：`sapse/abap-cloud-developer-trial:2023`（ABAP Platform 2023 / SAP_BASIS 7.57） |
| 客户端 | **Edge 内核 only**（SAP GUI 7.70+ 手动切换；Browser Info 页 `ZCL_ARK_EXAMPLE_BROWSER_PAGE` 探测） |
| 开发接入 | ADT MCP Server（localhost:2236，Bearer token 见会话），工具：ATC 检查/激活/单测/传输 |
| abapGit | 仓库 github.com/Jack-Liang/ABAP-Render-Kit，分支按功能开 |

## 3. 目标架构

```
ABAP 业务页（继承新的 UI5 页面基类）
  └─ 只填充 ty_page_state（zif_ark_gui_state，已有，持续演进）
       │ zcl_ark_json 序列化
       ▼
UI5 启动壳（固定 HTML/JS，随框架分发）
  ├─ sap.m/sap.f 控件渲染（JSONModel 绑定 state）
  ├─ ECharts 图表层（原生 div，与 UI5 分区混排）
  └─ 事件桥：UI5 事件 → 隐藏 iframe 提交 sapevent →
     ABAP on_event 处理 → 响应内嵌新 state JSON →
     主页面读取 → JSONModel.setData() 局部更新（UI5 常驻不重启）
```

关键设计结论（已验证）：
- **UI5 常驻 + setData** 是交互延迟的胜负手，spike 实测毫秒级；
- **`sap.ui.core.Html` 已从新版 UI5 移除**，UI5 控件内不能嵌原生 div → ECharts 必须与 UI5 分区混排（UI5 管行为控件：ShellBar/工具栏/表格/输入；ECharts 管可视化）；
- 图表继续 ECharts（`sap.viz` 判定为冗余不引入）；
- 旧模式 `build_html` 页面与 A 路线产物（`zcl_ark_state_page`/`zcl_ark_theme`）保留共存，逐步被 UI5 壳替代。

## 4. 分阶段路线

1. **宿主验证（当前未做，第一优先）**：把 showcase 搬进 a4h + Edge 内核 SAP GUI（先 CDN），实测：①WebView2 能否拉 CDN；②sap.m 渲染；③隐藏 iframe sapevent 桥端到端延迟；④会话内资源缓存。任一不过需调整方案（本地 self-contained 资源先行）。
2. **UI5 启动壳**：固定 HTML（bootstrap + require + JSONModel + 事件桥），作为框架资产分发。
3. **state→UI5 映射层**：`ty_page_state` → JSONModel 数据结构 + 声明式 UI5 视图描述；UI5 页面基类（对照 `zcl_ark_state_page` 的 API 形态：set_state/add_section/表格三件套）。
4. **离线分发**：Node + ui5-tooling 做 self-contained 构建（仅维护者机器，产物 W3MI 入 `src/assets/`，走现有 `cache_asset` 链路，与 ECharts 的 MIME 模式同构）。
5. **示例迁移** + ECharts 分区混排正式化。

## 5. 现有资产清单

| 资产 | 状态 | 在 B 中的角色 |
|---|---|---|
| core 引擎（gui/viewer/sapevent/cache_asset/json） | 已验证 | 原样复用 |
| `zif_ark_gui_state` state schema | 已验证（v1） | **核心资产**，演进为 JSONModel 数据源 |
| `zcl_ark_state_page`（A 路线渲染） | 已验证 | 保留共存；其 API 形态是 UI5 基类的参照 |
| `zcl_ark_theme` + ALV 三件套 | 已验证 | 保留给非 UI5 页面 |
| ECharts 集成（MIME 离线 + CDN 回退） | 生产可用 | 原样复用 |
| demo（本地，gitignored）：ui5-spike / ui5-showcase / ui5-codediff / probe1-5 | 已验证 | 宿主验证的搬运素材 |

## 6. 硬代价与已知坑（血泪，必读）

### 6.1 7.57 ABAP 语法地雷（示例类已全部踩过并修复）
- 嵌套内表（行类型为内表）**无法内联构造**：`( ( ... ) )` 报 `Unable to interpret "("`，`( VALUE type(...) )` 报 `table row expected`。正解：行 = 含内表组件的结构（`ty_table_row-cells`）；
- `DATA(x) = VALUE #(...)` 内联声明无类型上下文，**必须显式类型**；
- 方法参数上下文中的构造器写显式类型更稳；
- `DATA ... VALUE strlen(...)` 非法（VALUE 加法只收常量）；
- 组件访问符是 `-` 不是 `.`（`ls_item.kind` 会被解析成断句）；
- 字符串模板：`\` 只允许掩码 `{ } | \`；`\n` 无换行语义（ABAP 用 `cl_abap_char_utilities=>newline`）；正则竖线在模板内要写 `\|`；
- **语法检查必须过真实系统**：abapGit 激活不报语法错，运行时才 dump。用 MCP 的 ATC（`abap_atc_run`→`abap_atc_get_result`）闭环。

### 6.2 前端（浏览器/CDN）
- UI5 CDN 域名是 **`sdk.openui5.org`**（`.com` 不可达；`openui5.hana.ondemand.com` 301 到 .org）；
- async bootstrap 下用 **`sap.ui.require`**，不要 `sap.ui.define`（后者在本环境报跨域 "Script error." 静默失败）；
- `sap.m.Page` 的 content 是 0..n 聚合，用 `addContent` 不是 `setContent`；
- ECharts CDN：`cdn.jsdelivr.net/npm/echarts@6.1.0` 可用。

### 6.3 工具链注意
- **本 agent 的 python heredoc 传输会吃掉一层 `\\`**：`\\n` 进文件变真实换行（JS 断裂）、正则 `\\|` 变 `\|` 有歧义——写转义一律用 `chr(92)` 显式构造或用 Write 工具直写后 node --check 验证；
- JS 修改后必做 `node --check`（提取 `<script>` 块检查）；
- 调试手法：页面内 DOM 日志（`window.onerror` → `#errlog` div）+ probe 逐模块探测页（demo/ui5-probe*.html 模式），浏览器控制台在自动化里看不到。

## 7. 约定

- 分支：本阶段开发在 **`feat/ui5-integration`**；
- `demo/` 已 gitignore（本地验证素材不入库）；`docs/` 入库；
- 提交信息中文，格式 `类型(范围): 摘要`；
- SAP 侧同步靠用户 abapGit pull，之后用 MCP ATC 复检 + 激活验证；
- UI5 页面基类 API 对齐 `zcl_ark_state_page`（业务侧迁移成本最小化）。

## 8. 新会话开工清单

1. 读本文档 + README + `src/framework/zif_ark_gui_state.intf.abap` + `demo/ui5-showcase.html`（本地）；
2. 第一步做 §4.1 宿主验证（写 ABAP 验证页输出 showcase 的 HTML，走 `zcl_ark_gui` 渲染管线）；
3. 验证通过后按 §4 顺序推进，每阶段提交推送并请用户 pull 验证。
