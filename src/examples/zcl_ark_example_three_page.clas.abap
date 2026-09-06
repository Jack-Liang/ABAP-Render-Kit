CLASS zcl_ark_example_three_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

ENDCLASS.


CLASS zcl_ark_example_three_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - three.js View' ).

    " 注册 three.js 库（会话级一次）：SMW0 UMD 资产，缺资产自动回退 CDN
    zcl_ark_three_view=>register_default( ).
  ENDMETHOD.

  METHOD build_html.
    " 两个视图同页：库脚本经注册器页面级去重只注入一次 ——
    " 这正是 zif_ark_js_widget + zcl_ark_js_library 的接入形态
    " （接入指引见 docs/js-extensions.md）

    mo_html->add(
      |<p style="color: #57606a;">| &&
      |three.js r149（UMD 构建）经 SMW0 资产注入。WebGL 能力取决于实际 WebView 内核：| &&
      |Windows SAP GUI 的 Edge/WebView2 完整支持；SAP GUI for Java 的 JavaFX WebView| &&
      |因 JavaFX 版本而异（2026-09-06 真机实测可渲染）。初始化失败时每个视图原位| &&
      |显示自诊断红框（含 userAgent 与异常文本），备选路径为 ZARK_EXPORT_HTML| &&
      |（PAGE=THREE）导出后在外部浏览器查看。</p>| ).

    mo_html->add( |<h2>Torus Knot</h2>| ).
    DATA(lo_knot) = NEW zcl_ark_three_view(
      iv_div_id = 'three_knot'
      iv_height = 380 ).
    lo_knot->set_geometry( 'torus_knot' ).
    lo_knot->set_color( '#0070f2' ).
    mo_html->add( lo_knot->render( ) ).

    mo_html->add( |<h2>Sphere</h2>| ).
    DATA(lo_sphere) = NEW zcl_ark_three_view(
      iv_div_id = 'three_sphere'
      iv_height = 300 ).
    lo_sphere->set_geometry( 'sphere' ).
    lo_sphere->set_color( '#107e3e' ).
    mo_html->add( lo_sphere->render( ) ).

    ri_html = mo_html.
  ENDMETHOD.

ENDCLASS.
