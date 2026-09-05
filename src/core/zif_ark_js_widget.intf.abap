INTERFACE zif_ark_js_widget
  PUBLIC .

  " JS 驱动组件的插件接口：实现本接口 = 一个可插入任意页面的"网页能力"。
  " 纯 HTML 组件（form/toolbar 等）无需实现，直接用 zif_ark_gui_renderable 即可。
  "
  " 标准接入形态（如 three.js）：
  "   1) SMW0 上传 JS（UMD 构建）为 MIME 对象
  "   2) 组件类实现本接口；get_assets 返回注册名，render 前置
  "      zcl_ark_js_library=>register( ... ) 并输出容器 + 初始化脚本
  "   3) JS→ABAP 回调经 zcl_ark_js_bridge=>emit_js（arkEmit）
  INTERFACES zif_ark_gui_renderable .

  "! 声明依赖的 JS 库（zcl_ark_js_library 注册名）。
  "! 页面渲染前统一注入：zcl_ark_js_library=>include_for( io_widget )，
  "! 同页多个组件声明同一依赖只注入一次
  METHODS get_assets
    RETURNING
      VALUE(rt_assets) TYPE string_table .

ENDINTERFACE.
