*&---------------------------------------------------------------------*
*& Report ZARK_ECHARTS_DEMO
*&---------------------------------------------------------------------*
*& zcl_ark_echarts 能力演示：
*&   1) 声明式 API：堆叠面积图
*&   2) 声明式 + 逃生舱口：柱状图 + set_option_override（dataZoom/markLine）
*&   3) 通用模式：set_option 传入完整 ABAP 结构（/ui2/cl_json camelCase）画饼图
*&   4) 主题与平滑曲线：dark 主题折线图
*&
*& 宿主屏幕 1001 样板与 ZARK_EXAMPLE 一致。
*&---------------------------------------------------------------------*
REPORT zark_echarts_demo.

*----------------------------------------------------------------------*
* CLASS lcl_demo_page DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_demo_page DEFINITION
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    METHODS build_toolbar RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_area_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_bar_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_pie_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_dark_line_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
ENDCLASS.


*----------------------------------------------------------------------*
* CLASS lcl_demo_page IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_demo_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK ECharts Demo' ).

    " 启用随仓库分发的 ECharts MIME 资产（会话级只读一次），缺失时回退 CDN
    TRY.
        zcl_ark_echarts=>use_bundled_library( ).
      CATCH zcx_ark_exception.
    ENDTRY.
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( build_toolbar( ) ).

    mo_html->add(
      zcl_ark_template=>create(
        `<h1>{{TITLE}}</h1><p>{{DESC}}</p>`
      )->set( iv_name = 'TITLE' iv_value = 'zcl_ark_echarts 能力演示'
       )->set( iv_name = 'DESC'  iv_value = '声明式 API · 逃生舱口 · 通用 option 结构 · 主题'
       )->render( ) ).

    mo_html->add( |<h2>1. 声明式 API · 堆叠面积图</h2>| ).
    mo_html->add( build_area_chart( ) ).

    mo_html->add( |<h2>2. 逃生舱口 · dataZoom + markLine（柱状图）</h2>| ).
    mo_html->add( build_bar_chart( ) ).

    mo_html->add( |<h2>3. 通用模式 · set_option 完整结构（饼图）</h2>| ).
    mo_html->add( build_pie_chart( ) ).

    mo_html->add( |<h2>4. 主题 · dark 平滑折线</h2>| ).
    mo_html->add( build_dark_line_chart( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Reload'
      iv_action = 'reload' ).

    ri_html = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  " 1) 纯声明式 API
  METHOD build_area_chart.
    DATA(lo_chart) = NEW zcl_ark_echarts( iv_div_id = 'demo_area' iv_height = 380 ).

    lo_chart->set_title( 'Stacked Area Chart' ).
    lo_chart->set_toolbox( ).
    lo_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).

    lo_chart->add_series( iv_name = 'Email'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 120 ) ( 132 ) ( 101 ) ( 134 ) ( 90 ) ( 230 ) ( 210 ) )
      iv_stack = 'Total' iv_area = abap_true ).
    lo_chart->add_series( iv_name = 'Union Ads'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 220 ) ( 182 ) ( 191 ) ( 234 ) ( 290 ) ( 330 ) ( 310 ) )
      iv_stack = 'Total' iv_area = abap_true ).
    lo_chart->add_series( iv_name = 'Video Ads'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 150 ) ( 232 ) ( 201 ) ( 154 ) ( 190 ) ( 330 ) ( 410 ) )
      iv_stack = 'Total' iv_area = abap_true ).
    lo_chart->add_series( iv_name = 'Direct'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 320 ) ( 332 ) ( 301 ) ( 334 ) ( 390 ) ( 330 ) ( 320 ) )
      iv_stack = 'Total' iv_area = abap_true ).
    lo_chart->add_series( iv_name = 'Search Engine'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 820 ) ( 932 ) ( 901 ) ( 934 ) ( 1290 ) ( 1330 ) ( 1320 ) )
      iv_stack = 'Total' iv_area = abap_true iv_label = abap_true ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  " 2) 声明式骨架 + set_option_override 浅层合并，解锁任意 option
  METHOD build_bar_chart.
    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'demo_bar'
      iv_height      = 380
      iv_include_lib = abap_false ).

    lo_chart->set_title( 'Weekly Sales' ).
    lo_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).
    lo_chart->add_series( iv_name = 'Sales' iv_type = 'bar'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 1630 ) ( 1810 ) ( 1795 ) ( 1890 ) ( 2250 ) ( 2550 ) ( 2580 ) ) ).

    " 声明式 API 未覆盖的能力，用原生 JSON 顶层覆盖
    lo_chart->set_option_override(
      `{ "color": ["#5470c6"],` &&
      `  "dataZoom": [{ "type": "slider" }, { "type": "inside" }] }` ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  " 3) 通用模式：ABAP 结构 -> /ui2/cl_json camelCase -> 完整 option
  METHOD build_pie_chart.
    TYPES:
      BEGIN OF ty_name_value,
        name  TYPE string,
        value TYPE i,
      END OF ty_name_value,
      tt_name_value TYPE STANDARD TABLE OF ty_name_value WITH DEFAULT KEY,
      BEGIN OF ty_title,
        text TYPE string,
        left TYPE string,
      END OF ty_title,
      BEGIN OF ty_tooltip,
        trigger TYPE string,
      END OF ty_tooltip,
      BEGIN OF ty_legend,
        left   TYPE string,
        bottom TYPE string,
      END OF ty_legend,
      BEGIN OF ty_pie_series,
        name   TYPE string,
        type   TYPE string,
        radius TYPE string,
        data   TYPE tt_name_value,
      END OF ty_pie_series,
      tt_pie_series TYPE STANDARD TABLE OF ty_pie_series WITH DEFAULT KEY,
      BEGIN OF ty_pie_option,
        title   TYPE ty_title,
        tooltip TYPE ty_tooltip,
        legend  TYPE ty_legend,
        series  TYPE tt_pie_series,
      END OF ty_pie_option.

    DATA ls_option TYPE ty_pie_option.
    DATA ls_series TYPE ty_pie_series.

    ls_option-title-text    = 'Traffic Source'.
    ls_option-title-left    = 'center'.
    ls_option-tooltip-trigger = 'item'.
    ls_option-legend-left   = 'center'.
    ls_option-legend-bottom = '0'.

    ls_series-name   = 'Access From'.
    ls_series-type   = 'pie'.
    ls_series-radius = '50%'.
    ls_series-data   = VALUE tt_name_value(
      ( name = 'Search Engine' value = 1048 )
      ( name = 'Direct'        value = 735 )
      ( name = 'Email'         value = 580 )
      ( name = 'Union Ads'     value = 484 )
      ( name = 'Video Ads'     value = 300 ) ).
    APPEND ls_series TO ls_option-series.

    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'demo_pie'
      iv_height      = 420
      iv_include_lib = abap_false ).

    lo_chart->set_option( ls_option ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  " 4) dark 主题 + 平滑曲线
  METHOD build_dark_line_chart.
    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'demo_dark'
      iv_height      = 380
      iv_theme       = 'dark'
      iv_include_lib = abap_false ).

    lo_chart->set_title( 'Temperature Trend' ).
    lo_chart->set_xaxis_categories(
      VALUE string_table( ( `00:00` ) ( `04:00` ) ( `08:00` ) ( `12:00` ) ( `16:00` ) ( `20:00` ) ) ).
    lo_chart->add_series( iv_name = 'Indoor' iv_smooth = abap_true
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 21 ) ( 20 ) ( 22 ) ( 27 ) ( 26 ) ( 23 ) ) ).
    lo_chart->add_series( iv_name = 'Outdoor' iv_smooth = abap_true
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 15 ) ( 13 ) ( 18 ) ( 29 ) ( 31 ) ( 22 ) ) ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'reload'.
        rs_result-page  = NEW lcl_demo_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* 空选择屏幕 1001 作为 HTML 控件的宿主屏幕
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 1001.
SELECTION-SCREEN END OF SCREEN 1001.

START-OF-SELECTION.
  PERFORM run.

AT SELECTION-SCREEN OUTPUT.
  PERFORM output.

AT SELECTION-SCREEN ON EXIT-COMMAND.
  PERFORM exit.


FORM run.
  TRY.
      DATA(lo_gui) = zcl_ark_gui=>create( ).
      lo_gui->set_page( NEW lcl_demo_page( ) ).
      CALL SELECTION-SCREEN 1001.
    CATCH zcx_ark_exception INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM output.
  DATA lt_ucomm TYPE TABLE OF sy-ucomm.

  APPEND 'CRET' TO lt_ucomm.
  APPEND 'SPOS' TO lt_ucomm.

  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = lt_ucomm.

  TRY.
      zcl_ark_gui=>get_instance( )->set_focus( ).
    CATCH zcx_ark_exception.
  ENDTRY.
ENDFORM.

FORM exit.
  IF sy-dynnr <> 1001.
    RETURN.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'CBAC' OR 'CCAN'.
      DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
      IF lo_gui IS NOT INITIAL.
        lo_gui->free( ).
      ENDIF.
      LEAVE PROGRAM.
  ENDCASE.
ENDFORM.
