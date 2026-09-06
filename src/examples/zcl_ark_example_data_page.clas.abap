CLASS zcl_ark_example_data_page DEFINITION
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
    TYPES:
      BEGIN OF ty_flight,
        carrid     TYPE sflight-carrid,
        connid     TYPE sflight-connid,
        fldate     TYPE sflight-fldate,
        price      TYPE sflight-price,
        currency   TYPE sflight-currency,
        seatsocc   TYPE sflight-seatsocc,
        passengers TYPE string_table,
      END OF ty_flight,
      tt_flight TYPE STANDARD TABLE OF ty_flight WITH DEFAULT KEY .

    "! JSON 树与表格区块共用的默认展开状态（全部展开/全部折叠按钮驱动）
    DATA mv_open TYPE abap_bool VALUE abap_false .

    METHODS build_json_section
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING   zcx_ark_exception .

    METHODS build_table_section
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING   zcx_ark_exception .

    METHODS demo_json
      RETURNING VALUE(rv_json) TYPE string .
ENDCLASS.



CLASS zcl_ark_example_data_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Data Viewer' ).
  ENDMETHOD.


  METHOD build_html.
    mo_html->add( |<h1 class="ark-page-title">Data Viewer</h1>| ).
    mo_html->add( |<p class="ark-page-subtitle">| &&
                  |Typed ABAP data in, HTML out &mdash; no per-cell code.| &&
                  |&nbsp;&nbsp;点击列头排序，输入筛选就地生效| &&
                  |&nbsp;&middot;&nbsp;| &&
                  |{ mo_html->a( iv_txt = 'Expand all' iv_act = 'jt_expand' ) }| &&
                  |&nbsp;&middot;&nbsp;| &&
                  |{ mo_html->a( iv_txt = 'Collapse all' iv_act = 'jt_collapse' ) }</p>| ).

    mo_html->add( build_json_section( ) ).
    mo_html->add( build_table_section( ) ).

    ri_html = mo_html.
  ENDMETHOD.


  METHOD build_json_section.
    " 一个字符串换一棵折叠树：sXML 解析、转义、折叠脚本全部内建，
    " 非法 JSON 自动回退原文展示
    ri_html = zcl_ark_json_tree=>create( demo_json( )
                              )->set_open( mv_open
                              )->zif_ark_gui_renderable~render( ).
  ENDMETHOD.


  METHOD build_table_section.
    DATA lt_flights TYPE tt_flight.
    DATA lt_tags TYPE string_table.
    DATA lt_pax TYPE string_table.
    " add_table 是 zcl_ark_html 具体类方法（不在 zif_ark_html 接口里），
    " 局部构建用具体类引用，收尾再赋给接口返回值
    DATA lo_html TYPE REF TO zcl_ark_html.

    lo_html = zcl_ark_html=>create( ).

    " 任意内表 -> 表格：RTTI 出列（DDIC 中文/英文列头、数值右对齐、
    " 日期按用户格式、深层内表列显示行数），返回的构建器仍可继续定制。
    " 深层字段先构变量再赋值：表套表内联构造在 7.57 解析器上不可书写
    APPEND `Alice` TO lt_pax.
    APPEND `Bob` TO lt_pax.
    APPEND VALUE ty_flight( carrid = 'AA' connid = '0017' fldate = '20260904'
                            price = '422.94' currency = 'USD' seatsocc = 150
                            passengers = lt_pax )
           TO lt_flights.

    CLEAR lt_pax.
    APPEND `Carol` TO lt_pax.
    APPEND `Dave` TO lt_pax.
    APPEND `Erin` TO lt_pax.
    APPEND VALUE ty_flight( carrid = 'LH' connid = '0400' fldate = '20261021'
                            price = '1200.00' currency = 'EUR' seatsocc = 300
                            passengers = lt_pax )
           TO lt_flights.

    " 初始日期/零值展示空串与 0；未赋深层字段 -> 行数 0
    APPEND VALUE ty_flight( carrid = 'SQ' connid = '0002'
                            price = '0' currency = 'SGD' )
           TO lt_flights.

    lo_html->add( |<h2 class="ark-h2">Internal table &rarr; RTTI table</h2>| ).
    lo_html->add_table( zcl_ark_html_table=>from_any_table( lt_flights
                                )->zif_ark_gui_renderable~render( ) ).

    " 基本类型行类型：单列 TABLE_LINE 回退
    APPEND `abap` TO lt_tags.
    APPEND `html` TO lt_tags.
    APPEND `echarts` TO lt_tags.

    lo_html->add( |<h2 class="ark-h2">Elementary line &rarr; TABLE_LINE</h2>| ).
    lo_html->add_table( zcl_ark_html_table=>from_any_table( lt_tags
                                )->zif_ark_gui_renderable~render( ) ).

    ri_html = lo_html.
  ENDMETHOD.


  METHOD demo_json.
    " 反引号字面量不解析模板语法，JSON 花括号无需转义；值含中文/引号
    " 特意覆盖转义与 UTF-8 路径
    rv_json =
      `{"company":"ARK 示例","active":true,"revenue":123456.78,` &&
      `"tags":["abap","html","echarts"],` &&
      `"address":{"city":"上海","zip":"200000"},` &&
      `"contacts":[{"name":"Alice <dev>","role":"dev","skills":["ABAP","JSON"]},` &&
      `{"name":"Bob","role":"ops"}],` &&
      `"empty":{},"nothing":null}`.
  ENDMETHOD.


  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'jt_expand' OR 'jt_collapse'.
        " state 置位且不带新 page：框架同页重渲染，默认展开状态生效
        mv_open = xsdbool( ii_event->mv_action = 'jt_expand' ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
