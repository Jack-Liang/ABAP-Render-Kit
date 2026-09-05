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
    METHODS build_area_chart RETURNING VALUE(ro_chart) TYPE REF TO zcl_ark_echarts .
    METHODS build_bar_chart RETURNING VALUE(ro_chart) TYPE REF TO zcl_ark_echarts .
    METHODS build_table RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .
    DATA mv_drill_name TYPE string .
    DATA mv_drill_value TYPE string .
ENDCLASS.


CLASS zcl_ark_example_chart_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - ECharts Component' ).

    " 启用随仓库分发的 ECharts MIME 资产（会话级只读一次）；
    " 对象不存在时组件自动回退 CDN
    TRY.
        zcl_ark_echarts=>use_bundled_library( ).
      CATCH zcx_ark_exception.
        " MIME 资产未部署，保持 CDN
    ENDTRY.
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

    " 图表 1：堆叠面积图。页面级依赖声明：组件经 zif_ark_js_widget~get_assets
    " 报告所需 JS 库，include_for 统一注入（同页多组件声明同一库只注入一次）
    DATA(lo_area_chart) = build_area_chart( ).
    mo_html->add( zcl_ark_js_library=>include_for( lo_area_chart ) ).
    mo_html->add( lo_area_chart->render( ) ).

    mo_html->add( |<h2>Data Table</h2>| ).
    mo_html->add( build_table( ) ).

    " 图表 2：柱状图。不再依赖第一个组件"负责加载库"的隐式约定，
    " 依赖声明各自独立，注入由注册器去重
    mo_html->add( |<h2>Second Chart (Bar) — 点击柱子下钻</h2>| ).

    IF mv_drill_name IS NOT INITIAL.
      mo_html->add( |<p>已选择: <b>{ mv_drill_name }</b>（value = { mv_drill_value }）</p>| ).
    ENDIF.

    DATA(lo_bar_chart) = build_bar_chart( ).
    mo_html->add( zcl_ark_js_library=>include_for( lo_bar_chart ) ).
    mo_html->add( lo_bar_chart->render( ) ).

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
    ro_chart = NEW zcl_ark_echarts(
      iv_div_id = 'chart_area'
      iv_height = 420 ).

    ro_chart->set_title( 'Stacked Area Chart' ).
    ro_chart->set_toolbox( ).
    ro_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).

    ro_chart->add_series(
      iv_name  = 'Email'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 120 ) ( 132 ) ( 101 ) ( 134 ) ( 90 ) ( 230 ) ( 210 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    ro_chart->add_series(
      iv_name  = 'Union Ads'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 220 ) ( 182 ) ( 191 ) ( 234 ) ( 290 ) ( 330 ) ( 310 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    ro_chart->add_series(
      iv_name  = 'Video Ads'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 150 ) ( 232 ) ( 201 ) ( 154 ) ( 190 ) ( 330 ) ( 410 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    ro_chart->add_series(
      iv_name  = 'Direct'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 320 ) ( 332 ) ( 301 ) ( 334 ) ( 390 ) ( 330 ) ( 320 ) )
      iv_stack = 'Total'
      iv_area  = abap_true ).

    ro_chart->add_series(
      iv_name  = 'Search Engine'
      it_data  = VALUE zcl_ark_echarts=>ty_values( ( 820 ) ( 932 ) ( 901 ) ( 934 ) ( 1290 ) ( 1330 ) ( 1320 ) )
      iv_stack = 'Total'
      iv_area  = abap_true
      iv_label = abap_true ).

  ENDMETHOD.

  METHOD build_bar_chart.
    ro_chart = NEW zcl_ark_echarts(
      iv_div_id = 'chart_bar'
      iv_height = 320 ).

    ro_chart->set_title( 'Weekly Total' ).
    ro_chart->set_xaxis_categories(
      VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ( `Thu` ) ( `Fri` ) ( `Sat` ) ( `Sun` ) ) ).

    ro_chart->add_series(
      iv_name            = 'Total'
      iv_type            = 'bar'
      it_data            = VALUE zcl_ark_echarts=>ty_values(
                                         ( 1630000 ) ( 1810000 ) ( 1795000 ) ( 1890000 )
                                         ( 2250000 ) ( 2550000 ) ( 2580000 ) )
      iv_label           = abap_true
      iv_label_thousands = abap_true ).

    " 点击柱子 -> sapevent chart_drill -> on_event 读取参数
    ro_chart->set_on_click( 'chart_drill' ).
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
      WHEN 'chart_drill'.
        " 图表点击回传：query 值已自动 URL 解码
        mv_drill_name  = ii_event->query( 'name' ).
        mv_drill_value = ii_event->query( 'value' ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
