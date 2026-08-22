CLASS zcl_ark_echarts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 单条系列的数据点类型。p(16,6)：兼容金额等小数，整数字面量可直接使用
    " （f 行类型不接受整数字面量，VALUE 构造器会报类型不兼容）
    TYPES ty_value TYPE p LENGTH 16 DECIMALS 6 .
    TYPES ty_values TYPE STANDARD TABLE OF ty_value WITH DEFAULT KEY .

    CONSTANTS c_cdn_url TYPE string VALUE 'https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js' .
    CONSTANTS c_lib_cache_name TYPE string VALUE 'ark_echarts_min.js' .
    CONSTANTS c_bundled_mime_name TYPE wwwdatatab-objid VALUE 'ZARK_ECHARTS_MIN_JS' .

    " 启用随仓库分发的 ECharts 资产（MIME 对象 ZARK_ECHARTS_MIN_JS）：
    " 整个会话只从 SMW0 读取一次，之后所有图表共享，缺省回退 CDN
    CLASS-METHODS use_bundled_library
      IMPORTING !iv_mime_name TYPE wwwdatatab-objid DEFAULT c_bundled_mime_name
      RAISING   zcx_ark_exception .

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

    " 离线/内网环境：传入 SMW0 中 echarts.min.js 的二进制内容
    " （zcl_ark_convert=>mime_to_xstring( 'ZARK_ECHARTS_MIN_JS' )），
    " 渲染时经 cache_asset 换成本地缓存 URL，替代 CDN
    METHODS set_library_xdata
      IMPORTING !iv_xdata       TYPE xstring
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    " 通用模式：直接传入完整 option 的 ABAP 结构/内表（字段名用下划线命名，
    " 如 boundary_gap），经 /ui2/cl_json camelCase 序列化后整体替代声明式 option。
    " /ui2/cl_json 为软依赖（动态调用），不可用时回退 zcl_ark_json（字段名大写）。
    " 注意：compress 会把"纯数字样式的字符串"（如标题 '2026'）序列化为 JSON 数字，
    " 此类业务字符串需自行规避，或经 set_option_override 修正
    METHODS set_option
      IMPORTING !ig_option      TYPE any
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    " 逃生舱口：原生 JSON 片段，渲染时对 option 做浅层合并（顶层键覆盖），
    " 用于声明式 API 尚未覆盖的任意 ECharts 能力，如 dataZoom、markLine。
    " JSON 会原样嵌入页面脚本：只能传静态字面量，勿拼接数据库等不可信内容（脚本注入）
    METHODS set_option_override
      IMPORTING !iv_json        TYPE string
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

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
    CLASS-DATA gv_default_lib_xdata TYPE xstring .              " use_bundled_library 读入，会话级
    CLASS-DATA gv_default_lib_name TYPE wwwdatatab-objid .     " 已读入的 MIME 对象名

    DATA mv_div_id TYPE string .
    DATA mv_height TYPE i .
    DATA mv_theme TYPE string .
    DATA mv_include_lib TYPE abap_bool .
    DATA mv_title TYPE string .
    DATA mv_save_as_image TYPE abap_bool .
    DATA mv_library_xdata TYPE xstring .
    DATA mv_option_json TYPE string .
    DATA mv_option_override TYPE string .
    DATA mv_categories_json TYPE string .
    DATA mt_series TYPE STANDARD TABLE OF ty_series WITH DEFAULT KEY .

    METHODS build_init_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS build_option_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS serialize_option
      IMPORTING !ig_data       TYPE any
      RETURNING VALUE(rv_json) TYPE string .
    METHODS escape_js
      IMPORTING !iv_value         TYPE string
      RETURNING VALUE(rv_escaped) TYPE string .
ENDCLASS.


CLASS zcl_ark_echarts IMPLEMENTATION.

  METHOD use_bundled_library.
    " 会话级每个 MIME 对象只读一次（1MB+ 的 WWWDATA_IMPORT 很贵）；
    " 换用不同的 iv_mime_name 时按对象名重新读取
    IF gv_default_lib_xdata IS INITIAL OR gv_default_lib_name <> iv_mime_name.
      gv_default_lib_xdata = zcl_ark_convert=>mime_to_xstring( iv_mime_name ).
      gv_default_lib_name   = iv_mime_name.
    ENDIF.
  ENDMETHOD.

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
    mv_categories_json = zcl_ark_json=>to_json( it_categories ).
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
    ls_series-data_json = zcl_ark_json=>to_json( it_data ).

    APPEND ls_series TO mt_series.
    ro_self = me.
  ENDMETHOD.

  METHOD set_toolbox.
    mv_save_as_image = iv_save_as_image.
    ro_self = me.
  ENDMETHOD.

  METHOD set_library_xdata.
    mv_library_xdata = iv_xdata.
    ro_self = me.
  ENDMETHOD.

  METHOD set_option.
    mv_option_json = serialize_option( ig_option ).
    ro_self = me.
  ENDMETHOD.

  METHOD set_option_override.
    mv_option_override = iv_json.
    ro_self = me.
  ENDMETHOD.

  METHOD serialize_option.
    " /ui2/cl_json 软依赖：动态调用，类不存在时回退 zcl_ark_json。
    " pretty_name 为 char1 枚举：none=` ` low_case='L' camel_case='X'
    " extended='Y' user='U' user_low_case='C'。
    " camel_case 将下划线字段名转 camelCase（boundary_gap -> boundaryGap）
    TRY.
        CALL METHOD ('/UI2/CL_JSON')=>serialize
          EXPORTING
            data        = ig_data
            compress    = abap_true
            pretty_name = 'X'
          RECEIVING
            r_json      = rv_json.
      CATCH cx_sy_dyn_call_error.
        rv_json = zcl_ark_json=>to_json( ig_data ).
    ENDTRY.
  ENDMETHOD.

  METHOD escape_js.
    " JS 单引号字符串字面量转义。标题/系列名等常直接来自数据库（客户名、物料描述），
    " 未转义的反斜杠/引号/换行会产生非法脚本，导致整页所有图表一起失效。
    " `</` 一并转义，避免值中的 </script> 提前截断宿主脚本块
    rv_escaped = iv_value.

    rv_escaped = replace( val = rv_escaped sub = `\` with = `\\` occ = 0 ).
    rv_escaped = replace( val = rv_escaped
                          sub = |{ cl_abap_char_utilities=>cr_lf }|
                          with = `\n` occ = 0 ).
    rv_escaped = replace( val = rv_escaped
                          sub = |{ cl_abap_char_utilities=>cr }|
                          with = `\r` occ = 0 ).
    rv_escaped = replace( val = rv_escaped
                          sub = |{ cl_abap_char_utilities=>lf }|
                          with = `\n` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = `"` with = `\"` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = `'` with = `\'` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = `</` with = `<\/` occ = 0 ).
  ENDMETHOD.

  METHOD render.
    DATA(lo_html) = zcl_ark_html=>create( ).

    " ECharts 库。同页多个图表时，仅第一个组件需要带上（iv_include_lib）
    " 资产优先级：实例级 set_library_xdata > 会话级 use_bundled_library > CDN
    " 资产经 cache_asset 换成本地 URL；缓存挂在 GUI 实例上（同一 HTML 控件只上传
    " 一次），控件销毁重建后随实例失效，不会残留失效 URL
    IF mv_include_lib = abap_true.
      DATA(lv_lib_url) = c_cdn_url.

      DATA(lv_xdata) = mv_library_xdata.
      IF lv_xdata IS INITIAL.
        lv_xdata = gv_default_lib_xdata.
      ENDIF.

      IF lv_xdata IS NOT INITIAL.
        TRY.
            DATA(lv_asset_url) = zcl_ark_gui=>get_instance( )->zif_ark_gui_services~cache_asset(
              iv_url     = c_lib_cache_name
              iv_xdata   = lv_xdata
              iv_type    = 'text'
              iv_subtype = 'javascript' ).
          CATCH zcx_ark_exception.
            " 缓存失败时保持 CDN 回退
        ENDTRY.

        IF lv_asset_url IS NOT INITIAL.
          lv_lib_url = lv_asset_url.
        ENDIF.
      ENDIF.

      lo_html->add( |<script src="{ lv_lib_url }"></script>| ).
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
    DATA lv_base_option TYPE string.
    DATA lv_override_js TYPE string.

    lv_nl = cl_abap_char_utilities=>newline.

    IF mv_theme IS NOT INITIAL.
      lv_theme_arg = |, '{ escape_js( mv_theme ) }'|.
    ENDIF.

    " set_option 通用模式整体替代声明式骨架
    lv_base_option = mv_option_json.
    IF lv_base_option IS INITIAL.
      lv_base_option = build_option_js( ).
    ENDIF.

    " 逃生舱口：浅层合并（顶层键覆盖）
    IF mv_option_override IS NOT INITIAL.
      lv_override_js =
        |  var optionOverride = | && mv_option_override && |;| && lv_nl &&
        |  for (var k in optionOverride) \{ if (optionOverride.hasOwnProperty(k)) \{ option[k] = optionOverride[k]; \} \}| && lv_nl.
    ENDIF.

    rv_js =
      |(function() \{|                                                        && lv_nl &&
      |  var chartDom = document.getElementById('{ escape_js( mv_div_id ) }');|    && lv_nl &&
      |  if (!chartDom) \{ return; \}|                                        && lv_nl &&
      |  if (typeof echarts === 'undefined') \{|                              && lv_nl &&
      |    chartDom.innerHTML = '<div style="padding:16px;color:#b91c1c;font-family:sans-serif;">ECharts 库加载失败：资产缺失或浏览器内核不受支持（SAP GUI HTML Viewer 为 IE 内核，可能需要 ECharts 5.x）。</div>';| && lv_nl &&
      |    return;|                                                           && lv_nl &&
      |  \}|                                                                  && lv_nl &&
      |  var myChart = echarts.init(chartDom{ lv_theme_arg });|               && lv_nl &&
      |  var option = | && lv_base_option && |;|                              && lv_nl &&
      lv_override_js                                                          &&
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
      lv_title_line = |  title: \{ text: '{ escape_js( mv_title ) }' \},| && lv_nl.
    ENDIF.

    " 工具栏（可选）
    IF mv_save_as_image = abap_true.
      lv_toolbox = |  toolbox: \{ feature: \{ saveAsImage: \{ \} \} \},| && lv_nl.
    ENDIF.

    " 图例自动取各系列名称
    LOOP AT mt_series ASSIGNING <ls_series>.
      APPEND <ls_series>-name TO lt_legend.
    ENDLOOP.
    lv_legend = zcl_ark_json=>to_json( lt_legend ).

    " 各系列
    LOOP AT mt_series ASSIGNING <ls_series>.
      DATA(lv_options) = ``.

      IF <ls_series>-stack IS NOT INITIAL.
        lv_options = lv_options && |, stack: '{ escape_js( <ls_series>-stack ) }'|.
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
        |    \{ name: '{ escape_js( <ls_series>-name ) }', type: '{ escape_js( <ls_series>-type ) }'{ lv_options },| && lv_nl &&
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

ENDCLASS.
