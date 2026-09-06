# ARK 开发准则（所有开发者与 AI 会话必须遵循）

## 北极星目标（2026-09-06 由项目所有者确立，长期有效）

> **ABAP 端尽量少写 HTML。**
> 应用代码只提供"数据和参数"（类型化 state / 声明式 API），框架负责把它们
> 渲染成 HTML 页面。未来所有开发决策以这条目标为最高准则。

## 由此推导的开发规则

1. **新能力 = 扩展声明层，不是教用户写 HTML。**
   - 新的展示形态：先考虑给 `zif_ark_gui_state` 加 section 类型 / 字段，
     在 `zcl_ark_state_page` 实现渲染；
   - 新的 JS 库/前端能力：走 `zif_ark_js_widget`（`get_assets` + `render`）
     + `zcl_ark_js_library` 注册器，组件内部自含 HTML，业务侧零 HTML；
   - 只有逃生舱口（`zcl_ark_html` 原样 API、`set_option_override`）可以
     暴露原始 HTML/JSON，且必须在文档标注"脚本注入"警告。

2. **渲染层纪律。** 框架内拼接 HTML 的代码：动态值一律过
   `zcl_ark_convert=>escape_html`（属性/文本）或 `escape_js`（脚本字面量）；
   样式进 `zcl_ark_theme` 的 `.ark-*` 类与 design token，渲染器不写内联颜色。

3. **动作路由走约定。** 页面动作 = `on_action_<动作名>` 方法（基类自动分发），
   新示例/文档不得再示范 on_event 里写 CASE 分发（框架内部保留 CASE 除外）。

4. **新示例必须是声明式示范。** `src/examples` 的页面要么继承
   `zcl_ark_state_page` 填 state，要么是组件 API 演示；手写 HTML 字符串的
   示例页面不允许新增（发现即迭代掉）。

5. **内核基线。** Windows WebView2/Edge 为全功能基线；JavaFX WebView（Java GUI，
   WebGL 能力因 JavaFX 版本而异——2026-09-06 用户真机实测可渲染 three.js，
   勿再断言"无 WebGL"）与 IE 只要求优雅降级并给出可读提示（参考 `zcl_ark_three_view`，
   先尝试创建 WebGL 上下文、失败才降级）。任何新功能不得静默依赖 Edge 独有 API。

6. **质量门禁（每次推送前必做）。**
   - `npx --yes @abaplint/cli` 必须 0 issues；
   - 见 `docs/js-extensions.md` 与根目录 `abaplint.json`；
   - 历史陷阱清单见项目记忆与 [[ark-abap-template-pitfalls]]：字符串模板
     `{ expr }` 空格、接口方法不得用复合名声明、`TYPES ... VALUE` 不上 string
     组件、测试助手整体放 testclasses、带 testclasses 的类 XML 必须有
     `WITH_UNIT_TESTS`、gui_download 只收绝对路径。

7. **破坏性变更允许**（项目处于 alpha），但必须：同步更新 MANIFEST.md、
   README、`docs/`，并在提交信息里写明破坏点与迁移方式。

## 其他长期约定

- 用户通过 `git pull`（abapGit）安装：修复要当轮 commit+push，不留本地。
- 用户真机环境：SAP GUI for Java（macOS，JavaFX WebView——WebGL 实测可用）+
  ABAP Platform 2023 (7.57)。语法保持 7.57 保守。
- 纯前端模板迭代用 `demo/*.html`（不开 SAP 即可在浏览器验证）。
