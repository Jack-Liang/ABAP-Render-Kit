"! ARK 示例中枢 —— "App 端零 HTML"的完整示范：
"!  * 继承 zcl_ark_state_page：页面 = 一份 ty_page_state（卡片网格 + 文本节），
"!    没有一个字符手写 HTML，样式全来自主题 .ark-nav-* 类
"!  * 约定式路由：不再写 on_event 的 CASE —— 动作 'nav_form' 自动分发到
"!    on_action_nav_form（zcl_ark_gui_page 基类约定）
CLASS zcl_ark_example_hello_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_state_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    " —— 约定式动作处理器（签名由基类约定，基类自动分发）——
    METHODS on_action_nav_form
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_table
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_chart
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_three
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_data
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_state
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_ui5_state
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_browser
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_nav_ui5
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_run_echarts_demo
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_run_sflight_demo
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS run_demo_report
      IMPORTING !iv_prog TYPE sy-repid
      RAISING   zcx_ark_exception .
ENDCLASS.


CLASS zcl_ark_example_hello_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).

    " 页面 = 一份声明式 state：标题 + 副标题 + 卡片网格 + 页脚文本
    DATA(ls_state) = VALUE zif_ark_gui_state=>ty_page_state(
      title    = 'ARK Framework'
      subtitle = 'Interactive HTML user interfaces inside SAP GUI — pick a demo below.'
      sections = VALUE #(
        ( kind  = zif_ark_gui_state=>c_section_kind-card_grid
          cards = VALUE #(
            ( title = 'Form Builder'
              desc  = 'Typed form fields -> UI5 shell; bridge POST round-trip (Edge only)'
              action = 'nav_form' )
            ( title = 'Table Builder'
              desc  = 'Declarative sap.m table: semantic states, row actions via bridge (Edge only)'
              action = 'nav_table' )
            ( title = 'Charts'
              desc  = 'ECharts mixed with plain HTML on one page'
              action = 'nav_chart' )
            ( title = 'three.js View'
              desc  = 'WebGL 3D via uploaded JS asset: registry + widget interface (Edge only)'
              action = 'nav_three' )
            ( title = 'Data Viewer'
              desc  = 'Any internal table -> RTTI table; JSON string -> collapsible tree'
              action = 'nav_data' )
            ( title = 'State Page (Declarative)'
              desc  = 'Typed page state -> Fiori-style UI, no HTML in your ABAP code'
              action = 'nav_state' )
            ( title = 'UI5 State Page (Declarative)'
              desc  = 'Same state via UI5 shell: sap.m controls + sapevent bridge (Edge only)'
              action = 'nav_ui5_state' )
            ( title = 'Browser Info'
              desc  = 'Detect the HTML viewer engine: IE (MSHTML) or Edge (Chromium)'
              action = 'nav_browser' )
            ( title = 'UI5 Host Verification'
              desc  = 'Plan B probe: CDN / sap.m / sapevent bridge / caching (Edge only)'
              action = 'nav_ui5' )
            ( title = 'ECharts Demo (Report)'
              desc  = 'Every charting mode: declarative API, override hatch, full option, themes'
              action = 'run_echarts_demo' )
            ( title = 'SFlight Demo (Report)'
              desc  = 'Database-driven dashboard on SFLIGHT / SCARR'
              action = 'run_sflight_demo' ) ) )
        ( kind     = zif_ark_gui_state=>c_section_kind-text
          text     = 'Extracted from abapGit, rendered by CL_GUI_HTML_VIEWER. Source on'
          link_url = 'https://github.com/Jack-Liang/ABAP-Render-Kit'
          link_text = 'GitHub' ) ) ).

    set_state( ls_state ).
  ENDMETHOD.

  " —— 约定式路由：动作名 = 方法名后缀，无 CASE ——

  METHOD on_action_nav_form.
    rs_result-page  = NEW zcl_ark_example_form_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_table.
    rs_result-page  = NEW zcl_ark_example_table_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_chart.
    rs_result-page  = NEW zcl_ark_example_chart_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_three.
    rs_result-page  = NEW zcl_ark_example_three_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_data.
    rs_result-page  = NEW zcl_ark_example_data_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_state.
    rs_result-page  = NEW zcl_ark_example_state_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_ui5_state.
    rs_result-page  = NEW zcl_ark_example_ui5_state_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_browser.
    rs_result-page  = NEW zcl_ark_example_browser_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_nav_ui5.
    rs_result-page  = NEW zcl_ark_example_ui5_page( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD on_action_run_echarts_demo.
    run_demo_report( 'ZARK_ECHARTS_DEMO' ).
    " run_demo_report 内已完成重渲染：keep_view 让框架跳过第二次整页刷新
    rs_result-state    = 1.
    rs_result-keep_view = abap_true.
  ENDMETHOD.

  METHOD on_action_run_sflight_demo.
    run_demo_report( 'ZARK_SFLIGHT_DEMO' ).
    rs_result-state    = 1.
    rs_result-keep_view = abap_true.
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
