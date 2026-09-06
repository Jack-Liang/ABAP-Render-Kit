# ARK JS 扩展指南

> 把任意前端库（three.js、dayjs、d3、……）接入 ARK 页面的完整路径。
> 核心机制：**SMW0 (W3MI) 资产承载 JS 文件 → `zcl_ark_js_library` 注册注入 → `zcl_ark_js_bridge` 回传事件**。

## 架构一览

```
ABAP 组件（实现 zif_ark_js_widget）
  ├─ get_assets( )      → 声明依赖的 JS 库（注册名）
  └─ render( )          → 容器 div + 初始化脚本
        ↑                    │
        │ include_for( )     │ arkEmit(action, params)
zcl_ark_js_library       zcl_ark_js_bridge
  注册/缓存/同页幂等注入    window.arkEmit → sapevent → ABAP on_event
        ↑
SMW0 (W3MI)：JS 文件的宿主，随 abapGit 仓库分发
```

三块职责正交：**库注册器管"JS 怎么进页面"**，**桥管"页面事件怎么回 ABAP"**，
**widget 接口管"一个新能力怎么长成组件"**。

## 接入一个新 JS 库（以 three.js 为例）

### 1. 上传 JS 资产

推荐仓库分发（版本可控、内网可用）：

```bash
node tools/make_w3mi.mjs three.min.js ZARK_THREE_MIN_JS --text "three.js r160 (UMD build)"
git add src/assets/zark_three_min_js.w3mi.* && git push
# 目标系统 abapGit pull 即部署到 SMW0
```

> **内核能力边界**：WebGL 能力取决于实际 WebView 内核——Windows SAP GUI 的
> Edge/WebView2 完整支持；SAP GUI for Java 的 JavaFX WebView 因 JavaFX 版本而异
> （2026-09-06 用户真机实测可渲染 three.js，勿断言"无 WebGL"）。
> `zcl_ark_three_view` 先尝试创建 WebGL 上下文，失败时原位显示自诊断红框
> （含 userAgent 与异常文本）；备选验证路径：`ZARK_EXPORT_HTML`（PAGE=THREE）
> 导出三件套后在外部浏览器打开（ECharts 等纯 Canvas 2D 库不受影响）。
>
⚠️ 必须用 **UMD/全局构建**（`three.min.js`），ES module 的 `import` 在
SAP GUI HTML Viewer 的 `file:///` 环境下不可靠。ECharts 用的是同一机制
（`ZARK_ECHARTS_MIN_JS`），可对照。

### 2. ABAP 侧注册 + 注入

```abap
" 注册（会话级，重复注册覆盖；缺 MIME 资产时自行回退 CDN 可另行注册 iv_url）
zcl_ark_js_library=>register( iv_name = 'three' iv_mime = 'ZARK_THREE_MIN_JS' ).

" 页面构建时（同页幂等，只注入一次 <script>）：
mo_html->add( zcl_ark_js_library=>include( 'three' ) ).
```

### 3. JS→ABAP 回调

页面里先注入桥（同页幂等），之后任何脚本可调 `arkEmit`：

```abap
mo_html->add( zcl_ark_js_bridge=>script( ) ).   " 定义 window.arkEmit
```

```js
// 任意初始化脚本中：sapevent 回传，参数自动 encodeURIComponent
arkEmit('pick_object', { name: obj.name, id: obj.id });
```

ABAP 侧 `on_event` 里 `ii_event->query( 'name' )` 读取（值已自动 URL 解码）。
桥内部处理了 Chromium 内核的 sapevent 前缀探测（file:/// vs sap-cust://）。

## 写一个 JS 组件（widget 接口）

实现 `zif_ark_js_widget`（= `zif_ark_gui_renderable~render` + `get_assets`），
你的类就和内置的表格/JSON 树/图表组件同构：

```abap
CLASS zcl_my_three_view DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ark_js_widget.
    METHODS constructor IMPORTING iv_div_id TYPE string OPTIONAL.
  PRIVATE SECTION.
    DATA mv_div_id TYPE string.
ENDCLASS.

CLASS zcl_my_three_view IMPLEMENTATION.
  METHOD constructor.
    mv_div_id = COND #( WHEN iv_div_id IS INITIAL THEN |ark_three_{ ... }| ELSE iv_div_id ).
  ENDMETHOD.

  METHOD zif_ark_js_widget~get_assets.
    APPEND 'three' TO rt_assets.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    DATA(lo_html) = zcl_ark_html=>create( ).
    lo_html->div( iv_id = mv_div_id iv_style = 'width:100%; height:480px;' ).
    mo_... " 页面已在 render 前经 include_for 注入 three.js 与桥脚本
    lo_html->add( zcl_ark_js_bridge=>script( ) ).        " 幂等
    lo_html->add_js( |(function() \{ ... new THREE.Scene() ... \})();| ).
    ri_html = lo_html.
  ENDMETHOD.
ENDCLASS.
```

页面用两行接线（这是 chart 示例页的现行写法）：

```abap
DATA(lo_view) = NEW zcl_my_three_view( ).
mo_html->add( zcl_ark_js_library=>include_for( lo_view ) ).  " 依赖注入，同页去重
mo_html->add( lo_view->render( ) ).
```

纯 HTML 组件（无 JS 依赖）不需要实现 widget 接口，直接 `zif_ark_gui_renderable`。

## 语义备忘

- **同页幂等**：`include` / 桥脚本的去重集在 `zcl_ark_gui=>render` 每次整页
  渲染前重置（页面 HTML 全量重建）。
- **URL 生命周期**：`cache_asset` 分配的本地 URL 绑定 GUI 控件实例，控件
  销毁重建后自动失效重传；注册器层不做 URL 缓存。
- **MIME 读取**：会话级每个 MIME 对象只 `WWWDATA_IMPORT` 一次；读失败置
  标记，不再反复尝试大文件导入。
- **脚本注入面**：`get_assets` 的注册名、`arkEmit` 的 action 经转义；
  init 脚本里的动态值一律过 `zcl_ark_convert=>escape_js` 或
  `encodeURIComponent`——`<script>` 内的内容默认不可信，与 HTML 属性转义同级。
