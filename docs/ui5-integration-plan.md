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

1. **宿主验证（代码就绪，实测并入最后统一验证）**：入口 `ZARK_EXAMPLE` → 主页卡片 *UI5 Host Verification*（`zcl_ark_example_ui5_page`）。页面内自带验证报告面板（可一键复制回传），覆盖：① UI5/ECharts CDN 可达性与耗时；② sap.m/f 渲染（ShellBar/Toolbar）；③ sapevent 桥三条路径（隐藏 iframe GET / 主框架 GET / 表单 POST）+ 连发 10 次 + 全量 state 就地更新，均带往返毫秒数；④ 资源双取缓存探测 + 启动资源统计 + 启动耗时（跨次运行对比）。
   - 桥机制（本阶段落地）：主页面 JS 发 `SAPEVENT:` URL（前缀自动探测：`file:///` / `sap-cust://sap-place-holder/` / 裸）→ ABAP `on_event` 处理 → `push_to_frame` 把内嵌新 state JSON 的小文档 `show_url( in_frame = 'ark_bridge' )` 进隐藏桥帧 → 桥帧脚本 `postMessage` 回主页面 → UI5 常驻不重载。
   - 框架新增（向后兼容）：`ty_handling_result-keep_view`（处理了但禁止整页重渲染）、`zif_ark_gui_services~push_to_frame`、`zif_ark_html_viewer~show_url` 的 `iv_frame` 参数。任一验证项不过需调整方案（本地 self-contained 资源先行）。
2. **UI5 启动壳（已开发，浏览器验证通过）**：`zcl_ark_ui5_shell`（框架资产）——固定 HTML/JS：UI5 async bootstrap + ECharts 资产链（复用 `zcl_ark_echarts`）+ sapevent 事件桥（`ark.state` 桥事件 / `ark.nav` 主框架导航 / `ark.formGo` 桥表单 POST）。真源为 `demo/ui5-shell-preview.html`（浏览器可测），经 `tools/gen_ui5_shell.mjs` 逐字生成 ABAP 类，勿手改标记区。
3. **state→UI5 映射层（已开发 v1）**：`zcl_ark_ui5_page` 基类（API 对齐 `zcl_ark_state_page`：set_state / add_section / add_button…）+ 壳 JS 映射器：kpi_grid（原生卡+sparkline）/ table（sap.m.Table + ObjectStatus/Link 语义色）/ chart（ECharts option + 点击回传）/ form（经桥 POST）。**桥协议**：前端事件带 `__ark=1` → `on_state_event` 钩子重建 state → `push_state` 回推 ark_bridge 帧（keep_view，UI5 常驻）。**v1 取舍**：表格排序/筛选/CSV 内置与 sap.m 表单映射留待后续；工具栏 link 走主框架导航（对齐 A 路线恒可点语义）。
4. **离线分发**：Node + ui5-tooling 做 self-contained 构建（仅维护者机器，产物 W3MI 入 `src/assets/`，走现有 `cache_asset` 链路，与 ECharts 的 MIME 模式同构）。
5. **示例迁移** + ECharts 分区混排正式化：已完成 `zcl_ark_example_ui5_state_page`（销售概览）与 `zcl_ark_example_form_page` / `zcl_ark_example_table_page`（表单/表格构建器，改声明式 + 桥交互：随机填充、提交回显、行编辑/删除/恢复）；Charts 与 SFlight 等其余示例待迁。

## 5. 现有资产清单

| 资产 | 状态 | 在 B 中的角色 |
|---|---|---|
| core 引擎（gui/viewer/sapevent/cache_asset/json） | 已验证 | 原样复用 |
| `zif_ark_gui_state` state schema | 已验证（v1） | **核心资产**，演进为 JSONModel 数据源 |
| `zcl_ark_state_page`（A 路线渲染） | 已验证 | 保留共存；其 API 形态是 UI5 基类的参照 |
| `zcl_ark_theme` + ALV 三件套 | 已验证 | 保留给非 UI5 页面 |
| ECharts 集成（MIME 离线 + CDN 回退） | 生产可用 | 原样复用 |
| demo（入库，见 `demo/README.md`）：ui5-spike / ui5-showcase / ui5-export / ui5-codediff / probe1-6 | 已验证（浏览器侧） | 宿主验证的搬运素材 |

## 6. 硬代价与已知坑（血泪，必读）

### 6.1 7.57 ABAP 语法地雷（示例类已全部踩过并修复）
- 嵌套内表（行类型为内表）**无法内联构造**：`( ( ... ) )` 报 `Unable to interpret "("`，`( VALUE type(...) )` 报 `table row expected`。正解：行 = 含内表组件的结构（`ty_table_row-cells`）；
- `DATA(x) = VALUE #(...)` 内联声明无类型上下文，**必须显式类型**；
- 方法参数上下文中的构造器写显式类型更稳；
- `DATA ... VALUE strlen(...)` 非法（VALUE 加法只收常量）；
- **`TYPES ... TYPE STANDARD TABLE OF p LENGTH n DECIMALS d` 非法**（LENGTH/DECIMALS 加法只适用于基本类型声明）：先 `TYPES ty_p TYPE p LENGTH 5 DECIMALS 2 .` 再 `TYPES ty_t TYPE STANDARD TABLE OF ty_p WITH EMPTY KEY .`（实测踩雷：报错 `"LENGTH 5 DECIMALS 2" is not valid`）；
- **VALUE 构造器对基本类型行要求字面量与行类型兼容**：`VALUE ty_p( ( 32 ) ... )`（i 字面量进 p 行）报 `"32" and the row type ... are incompatible`；结构化行的组件赋值走 MOVE 语义无此限制。数值数组最省事的写法是 `string_table` + 前端 `map(Number)`；
- **深层内联构造即使语法正确也可能被 7.57 解析器拒绝**（实测：`zcl_ark_example_ui5_state_page` 首版 KPI 块 `sections → kpi_cards → sparkline` 三层内联 + 四重收尾括号，报 `"(", ")", or "component =" expected after ")"`，且该写法与已激活的 A 路线示例逐字相同仍失败——报错行是解析器放弃点而非病因点）。**规避**：构造器一律浅层 —— 先构变量/逐行 APPEND（显式行类型），构造器括号内不写跨行 `&&` 链；
- 组件访问符是 `-` 不是 `.`（`ls_item.kind` 会被解析成断句）；
- 字符串模板：`\` 只允许掩码 `{ } | \`；`\n` 无换行语义（ABAP 用 `cl_abap_char_utilities=>newline`）；正则竖线在模板内要写 `\|`；
- **语法检查必须过真实系统**：abapGit 激活不报语法错，运行时才 dump。用 MCP 的 ATC（`abap_atc_run`→`abap_atc_get_result`）闭环。

### 6.2 前端（浏览器/CDN）
- **宿主实证（6a7404c + 本轮）**：WebView2 内 `iframe.location.href` / `location.href` 触发 sapevent 会被帧导航拦截（白屏元凶），**sapevent 触发一律走隐藏锚点 `click()`**（桥帧内锚点 `ark_fire_a` / 主框架锚点 `ark_main_anchor`）；`push_to_frame`（show_url FRAME）可能抛异常，**必须吞掉**——异常冒泡触发框架兜底 render() → 页面重 boot → 白屏循环；
- **jsdelivr CDN 在宿主内不可达**（UI5 的 openui5.org 可达不代表 jsdelivr 可达）：未启用 MIME 资产的页面图表**静默缺席**。`include_library_script` 已改为自动尝试随仓库分发的 MIME 资产（会话级一次），缺资产回退 CDN；图表页不再需要显式 `use_bundled_library( )`；
- UI5 CDN 域名是 **`sdk.openui5.org`**（`.com` 不可达；`openui5.hana.ondemand.com` 301 到 .org）；
- async bootstrap 下用 **`sap.ui.require`**，不要 `sap.ui.define`（后者在本环境报跨域 "Script error." 静默失败）；
- `sap.m.Page` 的 content 是 0..n 聚合，用 `addContent` 不是 `setContent`；
- ECharts CDN：`cdn.jsdelivr.net/npm/echarts@6.1.0` 可用；
- **后台标签页 rAF 节流会挂起 UI5 RenderManager**：placeAt 的控件迟迟不渲染、Playwright 点击 actionability 检查超时（浏览器验证时假阳性）。验证脚本在读数前 `sap.ui.getCore().applyChanges()` 强制同步冲刷；SAP GUI 宿主内页面前台常驻，不受影响；
- **UI5 `destroy()` 在渲染延迟下遗留改名死节点**（`sap-ui-destroyed-*`）：挂载点独占的控件（页面工具栏）重建前先清空挂载点 innerHTML；
- 模块未 require 就直接访问会静默 undefined（如 `sap.m.BusyIndicator.show is not a function`）：用到哪个模块就 require 哪个，或访问前守卫。

### 6.3 工具链注意
- **ABAP `&&` 拼接不产生换行**（宿主白屏事故）：多行 JS 字面量 `&&` 连接后是单行，JS 行注释 `//` 会吞掉其后全部代码（`__arkShellBoot` 未定义 → 空挂载点白屏）。JS 块必须逐行 `APPEND` 到 `string_table` 再 `CONCATENATE LINES OF ... SEPARATED BY cl_abap_char_utilities=>newline`（`tools/gen_ui5_shell.mjs` 已内置）；模拟产物组装时也必须 `join('\n')`，逐行文本 diff 察觉不到换行丢失；
- **同步 `<script src=CDN>` 标签阻塞解析**：CDN 不可达时连静态 HTML 都不显示（整页白到网络超时）。壳的 CDN 标签放文档末尾 + 就绪轮询（UI5 60s / ECharts 60s，超时降级 + errlog），原生分区立即渲染；
- **本 agent 的 python heredoc 传输会吃掉一层 `\\`**：`\\n` 进文件变真实换行（JS 断裂）、正则 `\\|` 变 `\|` 有歧义——写转义一律用 `chr(92)` 显式构造或用 Write 工具直写后 node --check 验证；
- JS 修改后必做 `node --check`（提取 `<script>` 块检查）；
- 调试手法：页面内 DOM 日志（`window.onerror` → `#errlog` div）+ probe 逐模块探测页（demo/ui5-probe*.html 模式），浏览器控制台在自动化里看不到。

## 7. 约定

- 分支：本阶段开发在 **`feat/ui5-integration`**；
- `demo/` 与 `docs/` 均入库（实验项目决策可追溯，验证素材是方案 B 论证链物证）；
- 验证节奏（2026-08-22 起）：**最后统一验证** —— 开发连续推进阶段①-③，每步只做本地验证（`node --check` + 浏览器实测）；a4h + Edge 宿主实测（四项判定）由用户在收尾时一次性执行；
- 提交信息中文，格式 `类型(范围): 摘要`；
- SAP 侧同步靠用户 abapGit pull，之后用 MCP ATC 复检 + 激活验证；
- UI5 页面基类 API 对齐 `zcl_ark_state_page`（业务侧迁移成本最小化）。

## 8. 新会话开工清单

1. 读本文档 + README + `src/framework/zif_ark_gui_state.intf.abap` + `demo/ui5-showcase.html`（本地）；
2. 第一步做 §4.1 宿主验证（写 ABAP 验证页输出 showcase 的 HTML，走 `zcl_ark_gui` 渲染管线）；
3. 验证通过后按 §4 顺序推进，每阶段提交推送并请用户 pull 验证。
