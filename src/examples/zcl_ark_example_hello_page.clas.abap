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
    METHODS add_card
      IMPORTING
        !iv_title  TYPE string
        !iv_desc   TYPE string
        !iv_action TYPE string .
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
    " 颜色类样式必须走 CSS 而非内联：内联样式优先级高于类规则，
    " 悬停换色（border-color/background-color）才能覆盖静息态。
    " 布局属性保留内联，样式块缺失时卡片退化为纯文本链接仍可用
    mo_html->add_css(
      `.demo-card { border: 1px solid #d0d7de; border-radius: 8px; background-color: #fff; }` &&
      `.demo-card:hover { border-color: #0969da; background-color: #f0f6ff; text-decoration: none; }` &&
      `.demo-card:hover .demo-card-title { text-decoration: underline; }` ).

    mo_html->add( |<h1 style="margin-bottom: 4px;">ARK Framework</h1>| ).
    mo_html->add( |<p style="margin-top: 0; color: #57606a;">| &&
                  |Interactive HTML user interfaces inside SAP GUI &mdash; pick a demo below.</p>| ).

    mo_html->add( |<h2 style="margin-bottom: 8px;">In-App Pages</h2>| ).
    add_card( iv_title  = 'Form Builder'
              iv_desc   = 'Input fields, dropdowns and a submit round-trip via sapevent'
              iv_action = 'nav_form' ).
    add_card( iv_title  = 'Table Builder'
              iv_desc   = 'Column/row/cell API with styles and actions'
              iv_action = 'nav_table' ).
    add_card( iv_title  = 'Charts'
              iv_desc   = 'ECharts mixed with plain HTML on one page'
              iv_action = 'nav_chart' ).
    add_card( iv_title  = 'State Page (Declarative)'
              iv_desc   = 'Typed page state -> Fiori-style UI, no HTML in your ABAP code'
              iv_action = 'nav_state' ).
    add_card( iv_title  = 'Browser Info'
              iv_desc   = 'Detect the HTML viewer engine: IE (MSHTML) or Edge (Chromium)'
              iv_action = 'nav_browser' ).
    add_card( iv_title  = 'UI5 Host Verification'
              iv_desc   = 'Plan B probe: CDN / sap.m / sapevent bridge / caching (Edge only)'
              iv_action = 'nav_ui5' ).

    mo_html->add( |<h2 style="margin-bottom: 8px;">Standalone Reports</h2>| ).
    add_card( iv_title  = 'ECharts Demo'
              iv_desc   = 'Every charting mode: declarative API, override hatch, full option, themes'
              iv_action = 'run_echarts_demo' ).
    add_card( iv_title  = 'SFlight Demo'
              iv_desc   = 'Database-driven dashboard on SFLIGHT / SCARR'
              iv_action = 'run_sflight_demo' ).

    mo_html->add( |<hr>| ).

    DATA(lv_github_link) = mo_html->a(
      iv_txt = 'GitHub'
      iv_act = 'https://github.com/Jack-Liang/ABAP-Render-Kit'
      iv_typ = zif_ark_html=>c_action_type-url ).

    mo_html->add(
      |<p style="color: #57606a;">Extracted from abapGit, rendered by CL_GUI_HTML_VIEWER.| &&
      |&nbsp;&nbsp;Source on { lv_github_link }</p>| ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD add_card.
    " 卡片即 sapevent 链接：标题/描述双行。颜色样式在页面 CSS 类中定义
    " （内联无法被 hover 覆盖），此处内联仅保留布局属性
    mo_html->add(
      mo_html->a(
        iv_txt   = |<span class="demo-card-title" style="display: block; font-size: 15px; font-weight: bold; color: #0969da;">{ iv_title }</span>| &&
                   |<span style="display: block; margin-top: 6px; font-size: 13px; color: #57606a;">{ iv_desc }</span>|
        iv_act   = iv_action
        iv_class = 'demo-card'
        iv_style = |display: inline-block; width: 240px; margin: 0 12px 12px 0; padding: 14px 16px;| &&
                   |vertical-align: top; text-decoration: none;| ) ).
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
      WHEN 'nav_state'.
        rs_result-page = NEW zcl_ark_example_state_page( ).
        rs_result-state = 1.
      WHEN 'nav_browser'.
        rs_result-page = NEW zcl_ark_example_browser_page( ).
        rs_result-state = 1.
      WHEN 'nav_ui5'.
        rs_result-page = NEW zcl_ark_example_ui5_page( ).
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
