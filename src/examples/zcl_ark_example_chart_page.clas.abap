CLASS zcl_ark_example_chart_page DEFINITION
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
    METHODS build_area_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_bar_chart RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    METHODS build_table RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
ENDCLASS.


CLASS zcl_ark_example_chart_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - ECharts Component' ).
  ENDMETHOD.

  METHOD build_html.
    " 图表组件与其他 HTML 内容自由混排：工具栏、标题、图表、表格、第二个图表
    mo_html->add( build_toolbar( ) ).

    " 页面头部用模板 + 占位符渲染（生产环境可改用 zcl_ark_template=>from_mime
    " 从 SMW0 加载模板文件，ABAP 代码里只留数据）
    mo_html->add(
      zcl_ark_template=>create(
        `<h1>{{TITLE}}</h1><p>{{DESC}}</p>`
      )->set( iv_name = 'TITLE' iv_value = 'ECharts Component Example'
       )->set( iv_name = 'DESC'  iv_value = 'zcl_ark_echarts 只是页面内容流中的一段，与文字、表格等任意混排。'
       )->render( ) ).

    " 图表 1：堆叠面积图（第一个组件负责加载 ECharts 库）
    mo_html->add( build_area_chart( ) ).

    mo_html->add( |<h2>Data Table</h2>| ).
    mo_html->add( build_table( ) ).

    " 图表 2：柱状图（iv_include_lib = abap_false，不重复加载库）
    mo_html->add( |<h2>Second Chart (Bar)</h2>| ).
    mo_html->add( build_bar_chart( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Back Home'
      iv_action = 'nav_home' ).

    lo_toolbar->add_separator( ).

    lo_toolbar->add_link(
      iv_label = 'ECharts Example'
      iv_url   = 'https://echarts.apache.org/examples/en/editor.html?c=area-stack' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_area_chart.
    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id = 'chart_area'
      iv_height = 420 ).

    lo_chart->set_title( 'Stacked Area Chart' ).
    lo_chart->set_toolbox( ).
    lo_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).

    lo_chart->add_series(
      iv_name  = 'Email'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 120 ) ( 132 ) ( 101 ) ( 134 ) ( 90 ) ( 230 ) ( 210 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    lo_chart->add_series(
      iv_name  = 'Union Ads'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 220 ) ( 182 ) ( 191 ) ( 234 ) ( 290 ) ( 330 ) ( 310 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    lo_chart->add_series(
      iv_name  = 'Video Ads'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 150 ) ( 232 ) ( 201 ) ( 154 ) ( 190 ) ( 330 ) ( 410 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    lo_chart->add_series(
      iv_name  = 'Direct'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 320 ) ( 332 ) ( 301 ) ( 334 ) ( 390 ) ( 330 ) ( 320 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    lo_chart->add_series(
      iv_name  = 'Search Engine'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 820 ) ( 932 ) ( 901 ) ( 934 ) ( 1290 ) ( 1330 ) ( 1320 ) )
      iv_stack = 'Total'
      iv_area  = abap_true
      iv_label = abap_true ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD build_bar_chart.
    DATA(lo_chart) = NEW zcl_ark_echarts(
      iv_div_id      = 'chart_bar'
      iv_height      = 320
      iv_include_lib = abap_false ).

    lo_chart->set_title( 'Weekly Total' ).
    lo_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).

    lo_chart->add_series(
      iv_name = 'Total'
      iv_type = 'bar'
      it_data = VALUE zcl_ark_echarts=>ty_values( ( 1630 ) ( 1810 ) ( 1795 ) ( 1890 ) ( 2250 ) ( 2550 ) ( 2580 ) ) ).

    ri_html = lo_chart->render( ).
  ENDMETHOD.

  METHOD build_table.
    DATA(lo_table) = zcl_ark_html_table=>create( ).

    lo_table->add_column( iv_header = 'Day' ).
    lo_table->add_column( iv_header = 'Email' ).
    lo_table->add_column( iv_header = 'Union Ads' ).
    lo_table->add_column( iv_header = 'Video Ads' ).
    lo_table->add_column( iv_header = 'Direct' ).
    lo_table->add_column( iv_header = 'Search Engine' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = 'Mon' ).
    lo_table->add_cell( iv_value = '120' ).
    lo_table->add_cell( iv_value = '220' ).
    lo_table->add_cell( iv_value = '150' ).
    lo_table->add_cell( iv_value = '320' ).
    lo_table->add_cell( iv_value = '820' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = 'Tue' ).
    lo_table->add_cell( iv_value = '132' ).
    lo_table->add_cell( iv_value = '182' ).
    lo_table->add_cell( iv_value = '232' ).
    lo_table->add_cell( iv_value = '332' ).
    lo_table->add_cell( iv_value = '932' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = 'Wed' ).
    lo_table->add_cell( iv_value = '101' ).
    lo_table->add_cell( iv_value = '191' ).
    lo_table->add_cell( iv_value = '201' ).
    lo_table->add_cell( iv_value = '301' ).
    lo_table->add_cell( iv_value = '901' ).

    ri_html = lo_table->zif_ark_gui_renderable~render( ).
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
