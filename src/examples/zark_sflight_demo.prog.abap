*&---------------------------------------------------------------------*
*& Report ZARK_SFLIGHT_DEMO
*&---------------------------------------------------------------------*
*& zcl_ark_echarts + 经典航班数据模型（SFLIGHT/SCARR）的数据库驱动看板：
*&   1) 承运商收入柱状图（GROUP BY 聚合 + dataZoom 逃生舱口）
*&   2) 月度收入趋势平滑折线（ABAP 侧按月聚合）
*&   3) 承运商收入占比饼图（set_option 完整结构）
*&   4) 承运商明细表（zcl_ark_html_table 混排）
*&
*& 前置条件：系统已生成航班演示数据（报表 SAPBC_DATA_GENERATOR）。
*&---------------------------------------------------------------------*
REPORT zark_sflight_demo.

*----------------------------------------------------------------------*
* CLASS lcl_sflight_page DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_sflight_page DEFINITION
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    " 收入带小数（paymentsum 为 CURR 13,2），add_series 的 it_data
    " 接受任意数值行类型内表，p 内表经 MOVE 赋值不受构造器字面量限制
    TYPES:
      ty_amount  TYPE p LENGTH 16 DECIMALS 2,
      ty_amounts TYPE STANDARD TABLE OF ty_amount WITH DEFAULT KEY,
      BEGIN OF ty_carrier,
        carrid   TYPE sflight-carrid,
        carrname TYPE scarr-carrname,
        seatsocc TYPE int8,
        seatsmax TYPE int8,
        revenue  TYPE sflight-paymentsum,
      END OF ty_carrier,
      BEGIN OF ty_month,
        month   TYPE c LENGTH 6,
        revenue TYPE ty_amount,
      END OF ty_month.

    DATA mt_carrier TYPE STANDARD TABLE OF ty_carrier WITH DEFAULT KEY .
    DATA mt_month TYPE SORTED TABLE OF ty_month WITH UNIQUE KEY month .

    METHODS load_data .
    METHODS build_toolbar RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_revenue_bar RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_monthly_line RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_revenue_pie RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_carrier_table RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
ENDCLASS.


*----------------------------------------------------------------------*
* CLASS lcl_sflight_page IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_sflight_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK SFlight Dashboard' ).

    TRY.
        zcl_ark_echarts=>use_bundled_library( ).
      CATCH zcx_ark_exception.
        " MIME 资产未部署，回退 CDN
    ENDTRY.

    load_data( ).
  ENDMETHOD.

  METHOD load_data.
    " 承运商维度聚合
    SELECT s~carrid, c~carrname,
           SUM( s~seatsocc )    AS seatsocc,
           SUM( s~seatsmax )    AS seatsmax,
           SUM( s~paymentsum )  AS revenue
      FROM sflight AS s
      INNER JOIN scarr AS c ON c~carrid = s~carrid
      GROUP BY s~carrid, c~carrname
      ORDER BY revenue DESCENDING
      INTO TABLE @mt_carrier.

    " 月度维度：SFLIGHT 量级小，ABAP 侧聚合（兼容性优于 SUBSTRING SQL）
    SELECT fldate, paymentsum
      FROM sflight
      INTO TABLE @DATA(lt_flights).

    FIELD-SYMBOLS <ls_month> TYPE ty_month.
    LOOP AT lt_flights INTO DATA(ls_flight).
      READ TABLE mt_month ASSIGNING <ls_month>
        WITH KEY month = ls_flight-fldate(6).
      IF sy-subrc <> 0.
        INSERT VALUE ty_month( month = ls_flight-fldate(6) )
          INTO TABLE mt_month ASSIGNING <ls_month>.
      ENDIF.
      <ls_month>-revenue = <ls_month>-revenue + ls_flight-paymentsum.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( build_toolbar( ) ).

    mo_html->add(
      zcl_ark_template=>create(
        `<h1>{{TITLE}}</h1><p>{{DESC}}</p>`
      )->set( iv_name = 'TITLE' iv_value = 'SFlight 航班数据看板'
       )->set( iv_name = 'DESC'  iv_value = '数据来源：SFLIGHT / SCARR · 数据库驱动渲染'
       )->render( ) ).

    IF mt_carrier IS INITIAL.
      mo_html->add( |<p style="color:#b91c1c;">未找到 SFLIGHT 数据。请先运行报表 SAPBC_DATA_GENERATOR 生成航班演示数据。</p>| ).
      ri_html = mo_html.
      RETURN.
    ENDIF.

    mo_html->add( |<h2>承运商收入</h2>| ).
    mo_html->add( build_revenue_bar( ) ).

    mo_html->add( |<h2>月度收入趋势</h2>| ).
    mo_html->add( build_monthly_line( ) ).

    mo_html->add( |<h2>收入占比</h2>| ).
    mo_html->add( build_revenue_pie( ) ).

    mo_html->add( |<h2>承运商明细</h2>| ).
    mo_html->add( build_carrier_table( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Reload'
      iv_action = 'reload' ).

    ri_html = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_revenue_bar.
    DATA lt_categories TYPE string_table.
    DATA lt_revenue TYPE ty_amounts.

    LOOP AT mt_carrier INTO DATA(ls_carrier).
      APPEND ls_carrier-carrname TO lt_categories.
      APPEND ls_carrier-revenue TO lt_revenue.
    ENDLOOP.

    DATA(lo_chart) = NEW zcl_ark_echarts( iv_div_id = 'sf_revenue' iv_height = 400 ).

    lo_chart->set_title( 'Revenue by Carrier' ).
    lo_chart->set_toolbox( ).
    lo_chart->set_xaxis_categories( lt_categories ).
    lo_chart->add_series(
      iv_name = 'Revenue'
      iv_type = 'bar'
      it_data = lt_revenue ).

    " 承运商较多时方便拖动查看
    lo_chart->set_option_override(
      `{ "color": ["#5470c6"],` &&
      `  "dataZoom": [{ "type": "slider" }, { "type": "inside" }] }` ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD build_monthly_line.
    DATA lt_categories TYPE string_table.
    DATA lt_revenue TYPE ty_amounts.

    LOOP AT mt_month INTO DATA(ls_month).
      APPEND ls_month-month TO lt_categories.
      APPEND ls_month-revenue TO lt_revenue.
    ENDLOOP.

    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'sf_month'
      iv_height      = 380
      iv_include_lib = abap_false ).

    lo_chart->set_title( 'Monthly Revenue Trend' ).
    lo_chart->set_xaxis_categories( lt_categories ).
    lo_chart->add_series(
      iv_name   = 'Revenue'
      it_data   = lt_revenue
      iv_smooth = abap_true
      iv_area   = abap_true ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD build_revenue_pie.
    TYPES:
      BEGIN OF ty_name_value,
        name  TYPE string,
        value TYPE ty_amount,
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

    ls_option-title-text      = 'Revenue Share by Carrier'.
    ls_option-title-left      = 'center'.
    ls_option-tooltip-trigger = 'item'.
    ls_option-legend-left     = 'center'.
    ls_option-legend-bottom   = '0'.

    ls_series-name   = 'Revenue'.
    ls_series-type   = 'pie'.
    ls_series-radius = '50%'.
    LOOP AT mt_carrier INTO DATA(ls_carrier).
      APPEND VALUE ty_name_value(
        name  = ls_carrier-carrname
        value = ls_carrier-revenue ) TO ls_series-data.
    ENDLOOP.
    APPEND ls_series TO ls_option-series.

    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'sf_pie'
      iv_height      = 420
      iv_include_lib = abap_false ).

    lo_chart->set_option( ls_option ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD build_carrier_table.
    DATA(lo_table) = zcl_ark_html_table=>create( ).

    lo_table->add_column( iv_header = 'Carrier' ).
    lo_table->add_column( iv_header = 'Name' ).
    lo_table->add_column( iv_header = 'Passengers' ).
    lo_table->add_column( iv_header = 'Seats Max' ).
    lo_table->add_column( iv_header = 'Occupancy %' ).
    lo_table->add_column( iv_header = 'Revenue' ).

    LOOP AT mt_carrier INTO DATA(ls_carrier).
      lo_table->add_row( ).
      lo_table->add_cell( iv_value = CONV string( ls_carrier-carrid ) ).
      lo_table->add_cell( iv_value = CONV string( ls_carrier-carrname ) ).
      lo_table->add_cell( iv_value = |{ ls_carrier-seatsocc }| ).
      lo_table->add_cell( iv_value = |{ ls_carrier-seatsmax }| ).
      IF ls_carrier-seatsmax > 0.
        lo_table->add_cell(
          iv_value = |{ ls_carrier-seatsocc * 100 / ls_carrier-seatsmax }| ).
      ELSE.
        lo_table->add_cell( iv_value = '-' ).
      ENDIF.
      lo_table->add_cell( iv_value = |{ ls_carrier-revenue }| ).
    ENDLOOP.

    ri_html = lo_table->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'reload'.
        rs_result-page  = NEW lcl_sflight_page( ).
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
      lo_gui->set_page( NEW lcl_sflight_page( ) ).
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
