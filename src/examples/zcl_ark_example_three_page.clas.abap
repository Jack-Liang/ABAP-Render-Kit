CLASS zcl_ark_example_three_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .
    METHODS on_event REDEFINITION .

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

    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).
    lo_toolbar->add_button(
      iv_label  = 'Back Home'
      iv_action = 'nav_home' ).
    mo_html->add( lo_toolbar->zif_ark_gui_renderable~render( ) ).

    mo_html->add(
      |<p style="color: #57606a;">| &&
      |three.js r149（UMD 构建）经 SMW0 资产注入。需 Edge 内核（WebView2/Chromium）| &&
      |+ WebGL 硬件加速；IE 内核下会显示降级提示。</p>| ).

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

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page  = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
