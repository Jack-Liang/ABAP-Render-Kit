# 迁移说明 — 2026-09-06 正式化重构

本次允许破坏性变更，目标是把 API 收敛到"ABAP 端零 HTML"的北极星目标
（见根目录 AGENTS.md）。以下条目影响既有调用方：

## zcl_ark_html / zif_ark_html（瘦身为逃生舱口）

移除（全库零调用的遗留 API）：
- `set_title( )` / `mv_chunk_title`（写入后无任何读取，语义误导）
- `add_checkbox( )`、`icon( )`、`add_icon( )`
- 私有缩进状态机（`mv_indent` / `increase_indent` / `decrease_indent` /
  `indent_line` / `check_rerender` / `mv_within_style` / `mv_within_js`）

保留：`add / add_a / a / add_css / add_js / add_table / wrap / td / th / div /
is_empty / render`。声明式路径（state_page / from_any_table / json_tree /
echarts / template）不经过这些原样 API，不受影响。

## zcl_ark_echarts（库注入单一路径）

- `use_bundled_library( iv_mime )` 保留，语义变为"向 zcl_ark_js_library
  注册该 MIME"（原会话级静态缓存 gv_default_lib_* 删除）；
- `set_library_xdata( iv_xdata )` 语义变为"注册进 zcl_ark_js_library"，
  不再有独立的实例级上传分支；
- `render( )` 只走 `include_library_script( )` 单一路径；
- 常量 `c_lib_cache_name` 删除。

## zcl_ark_gui（异常正式化 + 主页判定）

- 事件处理器抛出的 `zcx_ark_exception` 不再被静默吞掉：渲染当页并在顶部
  显示转义后的错误横幅（`.ark-error-banner`，下一次渲染清除）；
- 新增 `is_at_home( )`（类级与 `zif_ark_gui_services` 均有）：按页面类的
  绝对类名判断是否在主页 —— 宿主报表的 Back 处理不再与
  `'HELLO_PAGE'` 之类类名字符串耦合。

## 示例迭代

- `zcl_ark_example_hello_page` 重写：继承 `zcl_ark_state_page`，纯声明式
  （card_grid + text 节），动作全部约定式路由（原 6 处内联 HTML 归零）；
- `zcl_ark_example_app`：`main( )` 空壳删除，入口为 `run( )`；
- data_page / sflight_demo / browser_page 的内联样式改用主题类
  （`.ark-h2` / `.ark-note` / `.ark-text-error`）；
- `ZARK_EXPORT_HTML` 新增 `PAGE=STATE`。
