CLASS zcl_ark_echarts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 单条系列的数据点类型
    TYPES ty_values TYPE STANDARD TABLE OF i WITH DEFAULT KEY .

    METHODS constructor
      IMPORTING
        !iv_div_id      TYPE string OPTIONAL           " 容器 div id，缺省自动生成
        !iv_height      TYPE i DEFAULT 400             " 图表高度（px）
        !iv_theme       TYPE string OPTIONAL           " ECharts 主题，如 'dark'
        !iv_include_lib TYPE abap_bool DEFAULT abap_true .  " 同页第 2 个起传 abap_false

    METHODS set_title
      IMPORTING !iv_title       TYPE string
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    METHODS set_xaxis_categories
      IMPORTING !it_categories  TYPE string_table
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    METHODS add_series
      IMPORTING
        !iv_name                TYPE string
        !it_data                TYPE ty_values
        !iv_type                TYPE string DEFAULT 'line'
        !iv_stack               TYPE string OPTIONAL
        !iv_area                TYPE abap_bool DEFAULT abap_false
        !iv_smooth              TYPE abap_bool DEFAULT abap_false
        !iv_label               TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    METHODS set_toolbox
      IMPORTING !iv_save_as_image TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ro_self)    TYPE REF TO zcl_ark_echarts .

    " 渲染为 HTML 片段（div + 初始化脚本），可与其他内容混排：
    "   mo_html->add( lo_chart->render( ) ).
    METHODS render
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_series,
        name      TYPE string,
        type      TYPE string,
        stack     TYPE string,
        area      TYPE abap_bool,
        smooth    TYPE abap_bool,
        label     TYPE abap_bool,
        data_json TYPE string,
      END OF ty_series .

    CLASS-DATA gv_instance_counter TYPE i .

    DATA mv_div_id TYPE string .
    DATA mv_height TYPE i .
    DATA mv_theme TYPE string .
    DATA mv_include_lib TYPE abap_bool .
    DATA mv_title TYPE string .
    DATA mv_save_as_image TYPE abap_bool .
    DATA mv_categories_json TYPE string .
    DATA mt_series TYPE STANDARD TABLE OF ty_series WITH DEFAULT KEY .

    METHODS build_init_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS build_option_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS num_array_json
      IMPORTING !it_data       TYPE ty_values
      RETURNING VALUE(rv_json) TYPE string .
    METHODS str_array_json
      IMPORTING !it_values     TYPE string_table
      RETURNING VALUE(rv_json) TYPE string .
ENDCLASS.


CLASS zcl_ark_echarts IMPLEMENTATION.

  METHOD constructor.
    gv_instance_counter = gv_instance_counter + 1.

    IF iv_div_id IS INITIAL.
      mv_div_id = |ark_chart_{ gv_instance_counter }|.
    ELSE.
      mv_div_id = iv_div_id.
    ENDIF.

    mv_height      = iv_height.
    mv_theme       = iv_theme.
    mv_include_lib = iv_include_lib.
  ENDMETHOD.

  METHOD set_title.
    mv_title = iv_title.
    ro_self = me.
  ENDMETHOD.

  METHOD set_xaxis_categories.
    mv_categories_json = str_array_json( it_categories ).
    ro_self = me.
  ENDMETHOD.

  METHOD add_series.
    DATA ls_series TYPE ty_series.

    ls_series-name      = iv_name.
    ls_series-type      = iv_type.
    ls_series-stack     = iv_stack.
    ls_series-area      = iv_area.
    ls_series-smooth    = iv_smooth.
    ls_series-label     = iv_label.
    ls_series-data_json = num_array_json( it_data ).

    APPEND ls_series TO mt_series.
    ro_self = me.
  ENDMETHOD.

  METHOD set_toolbox.
    mv_save_as_image = iv_save_as_image.
    ro_self = me.
  ENDMETHOD.

  METHOD render.
    DATA(lo_html) = zcl_ark_html=>create( ).

    " ECharts 库（CDN）。同页多个图表时，仅第一个组件需要带上
    IF mv_include_lib = abap_true.
      lo_html->add( `<script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>` ).
    ENDIF.

    " 图表容器
    lo_html->div(
      iv_id    = mv_div_id
      iv_style = |width: 100%; height: { mv_height }px;| ).

    " 初始化脚本（IIFE 包裹，不污染全局作用域）
    lo_html->add_js( build_init_js( ) ).

    ri_html = lo_html.
  ENDMETHOD.

  METHOD build_init_js.
    DATA lv_theme_arg TYPE string.
    DATA lv_nl TYPE string.

    lv_nl = cl_abap_char_utilities=>newline.

    IF mv_theme IS NOT INITIAL.
      lv_theme_arg = |, '{ mv_theme }'|.
    ENDIF.

    rv_js =
      |(function() \{|                                                        && lv_nl &&
      |  var chartDom = document.getElementById('{ mv_div_id }');|            && lv_nl &&
      |  if (!chartDom \|\| typeof echarts === 'undefined') \{ return; \}|      && lv_nl &&
      |  var myChart = echarts.init(chartDom{ lv_theme_arg });|               && lv_nl &&
      |  var option = | && build_option_js( ) && |;|                          && lv_nl &&
      |  myChart.setOption(option);|                                          && lv_nl &&
      |  window.addEventListener('resize', function() \{ myChart.resize(); \});| && lv_nl &&
      |\})();|.
  ENDMETHOD.

  METHOD build_option_js.
    DATA:
      lv_title_line  TYPE string,
      lv_toolbox     TYPE string,
      lv_legend      TYPE string,
      lv_series_json TYPE string,
      lt_legend      TYPE string_table,
      lv_nl          TYPE string.

    FIELD-SYMBOLS <ls_series> TYPE ty_series.

    lv_nl = cl_abap_char_utilities=>newline.

    " 标题（可选）
    IF mv_title IS NOT INITIAL.
      lv_title_line = |  title: \{ text: '{ mv_title }' \},| && lv_nl.
    ENDIF.

    " 工具栏（可选）
    IF mv_save_as_image = abap_true.
      lv_toolbox = |  toolbox: \{ feature: \{ saveAsImage: \{ \} \} \},| && lv_nl.
    ENDIF.

    " 图例自动取各系列名称
    LOOP AT mt_series ASSIGNING <ls_series>.
      APPEND <ls_series>-name TO lt_legend.
    ENDLOOP.
    lv_legend = str_array_json( lt_legend ).

    " 各系列
    LOOP AT mt_series ASSIGNING <ls_series>.
      DATA(lv_options) = ``.

      IF <ls_series>-stack IS NOT INITIAL.
        lv_options = lv_options && |, stack: '{ <ls_series>-stack }'|.
      ENDIF.
      IF <ls_series>-area = abap_true.
        lv_options = lv_options && |, areaStyle: \{ \}|.
      ENDIF.
      IF <ls_series>-smooth = abap_true.
        lv_options = lv_options && `, smooth: true`.
      ENDIF.
      IF <ls_series>-label = abap_true.
        lv_options = lv_options && |, label: \{ show: true, position: 'top' \}|.
      ENDIF.

      IF lv_series_json IS NOT INITIAL.
        lv_series_json = lv_series_json && `,` && lv_nl.
      ENDIF.

      lv_series_json = lv_series_json &&
        |    \{ name: '{ <ls_series>-name }', type: '{ <ls_series>-type }'{ lv_options },| && lv_nl &&
        |      emphasis: \{ focus: 'series' \}, data: { <ls_series>-data_json } \}|.
    ENDLOOP.

    " xAxis 类目缺省为空数组，避免生成非法 JS
    DATA(lv_categories) = mv_categories_json.
    IF lv_categories IS INITIAL.
      lv_categories = `[ ]`.
    ENDIF.

    rv_js =
      |\{|                                                                          && lv_nl &&
      lv_title_line                                                                 &&
      |  tooltip: \{|                                                               && lv_nl &&
      |    trigger: 'axis',|                                                        && lv_nl &&
      |    axisPointer: \{ type: 'cross', label: \{ backgroundColor: '#6a7985' \} \}| && lv_nl &&
      |  \},|                                                                       && lv_nl &&
      |  legend: \{ data: { lv_legend } \},|                                        && lv_nl &&
      lv_toolbox                                                                    &&
      |  grid: \{ left: '3%', right: '4%', bottom: '3%', containLabel: true \},|    && lv_nl &&
      |  xAxis: [ \{ type: 'category', boundaryGap: false, data: { lv_categories } \} ],| && lv_nl &&
      |  yAxis: [ \{ type: 'value' \} ],|                                           && lv_nl &&
      |  series: [|                                                                 && lv_nl &&
      lv_series_json                                                                && lv_nl &&
      |  ]|                                                                         && lv_nl &&
      |\}|.
  ENDMETHOD.

  METHOD num_array_json.
    DATA lv_sep TYPE string.

    LOOP AT it_data INTO DATA(lv_val).
      rv_json = rv_json && lv_sep && |{ lv_val }|.
      lv_sep = `, `.
    ENDLOOP.

    rv_json = `[ ` && rv_json && ` ]`.
  ENDMETHOD.

  METHOD str_array_json.
    DATA lv_sep TYPE string.

    LOOP AT it_values INTO DATA(lv_val).
      rv_json = rv_json && lv_sep && `'` && lv_val && `'`.
      lv_sep = `, `.
    ENDLOOP.

    rv_json = `[ ` && rv_json && ` ]`.
  ENDMETHOD.

ENDCLASS.
