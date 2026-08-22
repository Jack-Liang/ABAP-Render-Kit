CLASS zcl_ark_example_hello_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    METHODS build_toolbar RETURNING VALUE(ri_toolbar) TYPE REF TO zif_ark_html .
    METHODS build_content RETURNING VALUE(ri_content) TYPE REF TO zif_ark_html .
    METHODS run_demo_report
      IMPORTING !iv_prog TYPE sy-repid
      RAISING   zcx_ark_exception .
ENDCLASS.

CLASS zcl_ark_example_hello_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - Hello World' ).
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( |<h1>Welcome to ARK Framework</h1>| ).
    mo_html->add( |<p>This is a simple example demonstrating the ARK ABAP GUI framework.</p>| ).

    mo_html->add( build_toolbar( ) ).
    mo_html->add( |<hr>| ).
    mo_html->add( build_content( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Form Example'
      iv_action = 'nav_form' ).

    lo_toolbar->add_button(
      iv_label  = 'Table Example'
      iv_action = 'nav_table' ).

    lo_toolbar->add_button(
      iv_label  = 'Chart Example'
      iv_action = 'nav_chart' ).

    lo_toolbar->add_separator( ).

    " 独立 demo 报表：SUBMIT 跳转执行，退出后返回本页
    lo_toolbar->add_button(
      iv_label  = 'ECharts Demo'
      iv_action = 'run_echarts_demo' ).

    lo_toolbar->add_button(
      iv_label  = 'SFlight Demo'
      iv_action = 'run_sflight_demo' ).

    lo_toolbar->add_separator( ).

    lo_toolbar->add_link(
      iv_label = 'GitHub'
      iv_url   = 'https://github.com/Jack-Liang/ABAP-Render-Kit' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_content.
    DATA(lo_content) = zcl_ark_html=>create( ).

    lo_content->add( |<h2>Features</h2>| ).
    lo_content->add( |<ul>| ).
    lo_content->add( |<li>HTML rendering engine</li>| ).
    lo_content->add( |<li>Event handling system</li>| ).
    lo_content->add( |<li>Reusable components</li>| ).
    lo_content->add( |<li>Form builder</li>| ).
    lo_content->add( |<li>Table builder</li>| ).
    lo_content->add( |</ul>| ).

    lo_content->add( |<h2>Getting Started</h2>| ).
    lo_content->add( |<p>Use the toolbar buttons above to navigate to different examples.</p>| ).

    ri_content = lo_content.
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_form'.
        rs_result-page = NEW zcl_ark_example_form_page( ).
        rs_result-state = 1.
      WHEN 'nav_table'.
        rs_result-page = NEW zcl_ark_example_table_page( ).
        rs_result-state = 1.
      WHEN 'nav_chart'.
        rs_result-page = NEW zcl_ark_example_chart_page( ).
        rs_result-state = 1.
      WHEN 'run_echarts_demo'.
        run_demo_report( 'ZARK_ECHARTS_DEMO' ).
      WHEN 'run_sflight_demo'.
        run_demo_report( 'ZARK_SFLIGHT_DEMO' ).
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

  METHOD run_demo_report.
    " demo 报表有自己的宿主屏幕与独立的 GUI 实例（SUBMIT 会加载新的程序组，
    " 类静态变量互不影响）。执行期间全屏接管，退出（LEAVE PROGRAM）后返回此处
    SUBMIT (iv_prog) AND RETURN.

    TRY.
        " 控件通常随屏幕恢复而存活：直接刷新当前页面即可
        zcl_ark_gui=>get_instance( )->render( ).
      CATCH zcx_ark_exception.
        " demo 的全屏切换可能已销毁原 HTML 控件：释放旧实例并整体重建，回到主页
        TRY.
            zcl_ark_gui=>get_instance( )->free( ).
          CATCH cx_root ##NO_TEXT.
            " 已销毁的控件释放失败可容忍
        ENDTRY.
        zcl_ark_example_app=>main( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
