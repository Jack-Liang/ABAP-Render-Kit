CLASS zcl_ark_echarts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 插件接口：echarts 是第一个 JS 库组件样板（库依赖声明 + 统一 render）。
    " ALIASES 保持 lo_chart->render( ) 的调用写法不变
    INTERFACES zif_ark_js_widget .
    ALIASES render FOR zif_ark_gui_renderable~render .

    " 单条系列的数据点便捷类型（整型，支持 ( 120 ) 字面量写法）。
    " 带小数的数据（金额等）请将 add_series 的 it_data 传自定义数值内表
    " （p/f/decfloat 行类型均可）；ABAP 构造器表达式的字面量转换规则
    " 只允许整数字面量赋给 i 行类型，故本类型保持 i
    TYPES ty_values TYPE STANDARD TABLE OF i WITH DEFAULT KEY .

    CONSTANTS c_cdn_url TYPE string VALUE 'https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js' .
    CONSTANTS c_bundled_mime_name TYPE wwwdatatab-objid VALUE 'ZARK_ECHARTS_MIN_JS' .
    " zcl_ark_js_library 注册名
    CONSTANTS c_lib_name TYPE string VALUE 'echarts' .
    CONSTANTS c_china_map_name TYPE string VALUE 'china' .
    CONSTANTS c_bundled_china_map TYPE wwwdatatab-objid VALUE 'ZARK_MAP_CHINA_JSON' .

    " 地图数据点（name/value 对），add_map_series 的入参类型。
    " name 须与 GeoJSON 特性名一致（如中国地图的省份名）
    TYPES:
      BEGIN OF ty_map_data,
        name  TYPE string,
        value TYPE f,
      END OF ty_map_data,
      tt_map_data TYPE STANDARD TABLE OF ty_map_data WITH EMPTY KEY .

    " 启用随仓库分发的 ECharts 资产（MIME 对象 ZARK_ECHARTS_MIN_JS）：
    " 整个会话只从 SMW0 读取一次，之后所有图表共享，缺省回退 CDN
    CLASS-METHODS use_bundled_library
      IMPORTING !iv_mime_name TYPE wwwdatatab-objid DEFAULT c_bundled_mime_name
      RAISING   zcx_ark_exception .

    " 输出 ECharts 库的 <script> 标签（无实例上下文也可用，如状态页的
    " chart 节）：资产优先级与会话级缓存与 render( ) 一致，
    " use_bundled_library( ) 已启用时走本地缓存 URL，否则 CDN
    CLASS-METHODS include_library_script
      RETURNING VALUE(rv_html) TYPE string .

    "! 启用随仓库分发的中国地图 GeoJSON（MIME 对象 ZARK_MAP_CHINA_JSON）：
    "! 会话级只从 SMW0 读取一次，包装为 window.ARK_MAPS["china"] 的 JS 资产。
    "! 其他地图：自备 GeoJSON 上传 SMW0 后指定 iv_mime_name，
    "! 或经 set_map( iv_xdata = ... ) 传入原始 GeoJSON
    CLASS-METHODS use_bundled_map
      IMPORTING
        !iv_map_name  TYPE string DEFAULT c_china_map_name
        !iv_mime_name TYPE wwwdatatab-objid DEFAULT c_bundled_china_map
      RAISING   zcx_ark_exception .

    "! 输出已启用地图资产的 <script> 标签（echarts.registerMap 的数据来源，
    "! 状态页等外部调用方使用）。内置 china 未显式加载时自动尝试，
    "! 资产缺失或上传失败返回空串
    CLASS-METHODS include_map_script
      IMPORTING !iv_map_name   TYPE string
      RETURNING VALUE(rv_html) TYPE string .

    METHODS constructor
      IMPORTING
        !iv_div_id      TYPE string OPTIONAL           " 容器 div id，缺省自动生成
        !iv_height      TYPE i DEFAULT 400             " 图表高度（px）
        !iv_width       TYPE string OPTIONAL           " 图表宽度（如 '640px'/'50%'，缺省 100%）
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
        !it_data                TYPE ANY TABLE   " 任意数值行类型内表（i/p/f/decfloat），小数直接支持
        !iv_type                TYPE string DEFAULT 'line'
        !iv_stack               TYPE string OPTIONAL
        !iv_area                TYPE abap_bool DEFAULT abap_false
        !iv_smooth              TYPE abap_bool DEFAULT abap_false
        !iv_label               TYPE abap_bool DEFAULT abap_false
        "! 配合 iv_label：数据标签千分位（1,630,000），金额类大数可读性
        !iv_label_thousands     TYPE abap_bool DEFAULT abap_false
        !iv_color_by_data       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    METHODS set_toolbox
      IMPORTING !iv_save_as_image TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ro_self)    TYPE REF TO zcl_ark_echarts .

    "! 图表元素点击回传：点击柱/折线点/饼块/地图区域时以 sapevent 触发
    "! iv_action，页面 on_event 里经 ii_event->query( ) 读取参数：
    "!   name   类目名或数据点名（如饼块/地图区域名）
    "!   series 系列名
    "!   value  数值（scatter 等对象值回传为 JSON 字符串）
    "!   idx    dataIndex
    "! 值在框架侧自动 URL 解码；单个参数上限 250 字符（编码后中文约 9 字符/字）
    METHODS set_on_click
      IMPORTING !iv_action      TYPE string
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_echarts .

    "! 注册 GeoJSON 地图（map 系列填色图 / geo 坐标系的前置条件）。
    "! 缺省取会话级 use_bundled_map( ) 已加载的资产；传 iv_xdata
    "!（原始 GeoJSON 的 UTF-8 字节，如 zcl_ark_convert=>mime_to_xstring( )
    "! 的返回值）则即时包装注册。须在 add_map_series 之前调用
    METHODS set_map
      IMPORTING
        !iv_name       TYPE string
        !iv_xdata      TYPE xstring OPTIONAL
      RETURNING VALUE(ro_self) TYPE REF TO zcl_ark_echarts
      RAISING   zcx_ark_exception .

    "! 追加 map 系列（choropleth 填色图）：数据为区域名 + 数值对，
    "! 配合 set_visual_map( ) 控制色带映射
    METHODS add_map_series
      IMPORTING
        !iv_name       TYPE string
        !it_data       TYPE tt_map_data
      RETURNING VALUE(ro_self) TYPE REF TO zcl_ark_echarts .

    "! visualMap 数值映射条：min/max 为数值字符串（如 '0'/'1200'），
    "! 原样嵌入脚本，勿拼接不可信内容
    METHODS set_visual_map
      IMPORTING
        !iv_min        TYPE string
        !iv_max        TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_ark_echarts .

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

    "! 输出本图表的 option JSON（声明式 API 构建结果 / set_option 序列化）。
    "! 供 zif_ark_gui_state 的 chart 节直接取用：
    "!   chart_option = lo_chart->get_option_json( ).
    "! —— 业务侧给 ABAP 数据，框架两侧（经典/state）都不写裸 JSON
    METHODS get_option_json
      RETURNING
        VALUE(rv_json) TYPE string .

    " 渲染为 HTML 片段（div + 初始化脚本），可与其他内容混排：
    "   mo_html->add( lo_chart->render( ) ).
    " 经 zif_ark_gui_renderable~render 实现，ALIASES render 暴露。
    " get_assets 由 zif_ark_js_widget 接口带入，实现区直接 METHOD 实现，
    " 不得在类定义区用复合名声明（命名规则只允许 A-Z0-9_）

    " JS 字符串字面量转义（反斜杠/引号/换行/</script> 等）。
    " 公开给 state_page 等需要把值嵌入 <script> 的调用方复用
    CLASS-METHODS escape_js
      IMPORTING !iv_value         TYPE string
      RETURNING VALUE(rv_escaped) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_series,
        name          TYPE string,
        type          TYPE string,
        stack         TYPE string,
        map           TYPE string,
        area          TYPE abap_bool,
        smooth        TYPE abap_bool,
        label         TYPE abap_bool,
        label_thousands TYPE abap_bool,
        color_by_data TYPE abap_bool,
        data_json     TYPE string,
      END OF ty_series .

    TYPES:
      BEGIN OF ty_map_asset,
        map_name TYPE string,
        "! 包装后的 window.ARK_MAPS[...] JS（UTF-8 字节）
        xdata    TYPE xstring,
      END OF ty_map_asset,
      tt_map_asset TYPE HASHED TABLE OF ty_map_asset WITH UNIQUE KEY map_name .

    CLASS-DATA gv_instance_counter TYPE i .
    CLASS-DATA gt_map_asset TYPE tt_map_asset .                " use_bundled_map 读入，会话级

    DATA mv_div_id TYPE string .
    DATA mv_height TYPE i .
    DATA mv_width TYPE string .
    DATA mv_theme TYPE string .
    DATA mv_include_lib TYPE abap_bool .
    DATA mv_title TYPE string .
    DATA mv_save_as_image TYPE abap_bool .
    DATA mv_option_json TYPE string .
    DATA mv_option_override TYPE string .
    DATA mv_categories_json TYPE string .
    DATA mv_on_click TYPE string .
    DATA mv_map_name TYPE string .
    DATA mv_map_xdata TYPE xstring .                     " 实例级地图资产（set_map iv_xdata），已包装
    DATA mv_visual_min TYPE string .
    DATA mv_visual_max TYPE string .
    DATA mt_series TYPE STANDARD TABLE OF ty_series WITH DEFAULT KEY .

    METHODS build_init_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS build_option_js
      RETURNING VALUE(rv_js) TYPE string .
    METHODS serialize_option
      IMPORTING !ig_data       TYPE any
      RETURNING VALUE(rv_json) TYPE string .
    CLASS-METHODS wrap_map_js
      IMPORTING !iv_map_name     TYPE string
                !iv_geojson      TYPE string
      RETURNING VALUE(rv_js)     TYPE string .
    METHODS build_map_data_json
      IMPORTING !it_data         TYPE tt_map_data
      RETURNING VALUE(rv_json)   TYPE string .
ENDCLASS.


CLASS zcl_ark_echarts IMPLEMENTATION.

  METHOD use_bundled_library.
    " 显式指定库资产的 MIME 对象（会话级一次即可）。实现收敛到注册器：
    " MIME 只读一次/失败标记/本地 URL 均由 zcl_ark_js_library 负责。
    " 缺省资产由 include_library_script 隐式注册，无需调用本方法
    zcl_ark_js_library=>register(
      iv_name = c_lib_name
      iv_mime = iv_mime_name ).
  ENDMETHOD.

  METHOD constructor.
    gv_instance_counter = gv_instance_counter + 1.

    IF iv_div_id IS INITIAL.
      mv_div_id = |ark_chart_{ gv_instance_counter }|.
    ELSE.
      mv_div_id = iv_div_id.
    ENDIF.

    mv_height      = iv_height.
    mv_width       = iv_width.
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

    ls_series-name            = iv_name.
    ls_series-type            = iv_type.
    ls_series-stack           = iv_stack.
    ls_series-area            = iv_area.
    ls_series-smooth          = iv_smooth.
    ls_series-label           = iv_label.
    ls_series-label_thousands = iv_label_thousands.
    ls_series-color_by_data   = iv_color_by_data.
    ls_series-data_json       = zcl_ark_json=>to_json( it_data ).

    APPEND ls_series TO mt_series.
    ro_self = me.
  ENDMETHOD.

  METHOD set_toolbox.
    mv_save_as_image = iv_save_as_image.
    ro_self = me.
  ENDMETHOD.

  METHOD set_on_click.
    mv_on_click = iv_action.
    ro_self = me.
  ENDMETHOD.

  METHOD use_bundled_map.
    " 会话级每个地图只读一次（大 GeoJSON 的 WWWDATA_IMPORT 很贵）
    READ TABLE gt_map_asset WITH KEY map_name = iv_map_name TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      DATA(lv_geojson) = zcl_ark_convert=>xstring_to_string_utf8(
                           zcl_ark_convert=>mime_to_xstring( iv_mime_name ) ).
      INSERT VALUE #(
        map_name = iv_map_name
        xdata    = zcl_ark_convert=>string_to_xstring(
                     wrap_map_js( iv_map_name = iv_map_name iv_geojson = lv_geojson ) ) )
        INTO TABLE gt_map_asset.
    ENDIF.
  ENDMETHOD.

  METHOD include_map_script.
    DATA lv_map_xdata TYPE xstring.

    READ TABLE gt_map_asset INTO DATA(ls_map) WITH KEY map_name = iv_map_name.
    IF sy-subrc <> 0 AND iv_map_name = c_china_map_name.
      " 内置地图允许隐式加载（显式 use_bundled_map 的补充路径）
      TRY.
          use_bundled_map( ).
          READ TABLE gt_map_asset INTO ls_map WITH KEY map_name = iv_map_name.
        CATCH zcx_ark_exception.
          " MIME 资产未部署：返回空串
      ENDTRY.
    ENDIF.
    IF sy-subrc <> 0 OR ls_map-xdata IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        " 会话级地图资产走注册器（与库注入同一管道）；cache_asset 的
        " 实例级去重由注册器复用
        DATA(lv_map_reg_name) = |ark_map_{ iv_map_name }|.
        IF zcl_ark_js_library=>is_registered( lv_map_reg_name ) = abap_false.
          zcl_ark_js_library=>register(
            iv_name  = lv_map_reg_name
            iv_xdata = ls_map-xdata ).
        ENDIF.
        rv_html = zcl_ark_js_library=>include( lv_map_reg_name ).
      CATCH zcx_ark_exception.
        " 缓存失败返回空串；初始化脚本里的 registerMap 守卫使图表退化为空地图
    ENDTRY.
  ENDMETHOD.

  METHOD set_map.
    mv_map_name = iv_name.

    IF iv_xdata IS NOT INITIAL.
      " 实例级资产：原始 GeoJSON 字节即时包装
      mv_map_xdata = zcl_ark_convert=>string_to_xstring(
                       wrap_map_js(
                         iv_map_name = iv_name
                         iv_geojson  = zcl_ark_convert=>xstring_to_string_utf8( iv_xdata ) ) ).
    ELSE.
      READ TABLE gt_map_asset WITH KEY map_name = iv_name TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        IF iv_name = c_china_map_name.
          use_bundled_map( ).
        ELSE.
          zcx_ark_exception=>raise( |Map { iv_name } not loaded: call use_bundled_map( ) first| ).
        ENDIF.
      ENDIF.
    ENDIF.

    ro_self = me.
  ENDMETHOD.

  METHOD add_map_series.
    DATA ls_series TYPE ty_series.

    ls_series-name      = iv_name.
    ls_series-type      = 'map'.
    ls_series-map       = mv_map_name.
    ls_series-data_json = build_map_data_json( it_data ).

    APPEND ls_series TO mt_series.
    ro_self = me.
  ENDMETHOD.

  METHOD set_visual_map.
    mv_visual_min = iv_min.
    mv_visual_max = iv_max.
    ro_self = me.
  ENDMETHOD.

  METHOD wrap_map_js.
    " GeoJSON 是纯 JSON，<script src> 无法向页面暴露数据；包装成 JS
    " 全局变量赋值即可经同步 script 标签注入 window.ARK_MAPS["<map>"]。
    " </ 转义防 </script> 截断（JSON 中只出现在字符串值内，\/ 等价 /）
    DATA(lv_geojson) = replace( val = iv_geojson sub = `</` with = `<\/` occ = 0 ).

    rv_js = |window.ARK_MAPS = window.ARK_MAPS \|\| \{\};| &&
            |window.ARK_MAPS['{ escape_js( iv_map_name ) }'] = { lv_geojson };|.
  ENDMETHOD.

  METHOD build_map_data_json.
    " zcl_ark_json 序列化结构内表会得到大写键名（NAME/VALUE），地图数据
    " 必须是小写 name/value，这里手工拼 JSON（与 build_option_js 的
    " legend 系列名同一信任级别：值经 escape_js 转义）
    " 先收集后拼接：大地图（几千区域）逐条 && 是 O(n²) 拷贝
    DATA lt_items TYPE string_table.
    LOOP AT it_data INTO DATA(ls_data).
      APPEND
        |\{ name: '{ escape_js( ls_data-name ) }', value: { ls_data-value DECIMALS = 2 } \}|
        TO lt_items.
    ENDLOOP.

    rv_json = `[ ` && concat_lines_of( table = lt_items sep = `,` ) && ` ]`.
  ENDMETHOD.

  METHOD set_library_xdata.
    " 实例级库内容覆盖：直接注册进 zcl_ark_js_library（同名覆盖语义）。
    " 渲染统一走 include_library_script，不再有独立的实例级上传分支
    zcl_ark_js_library=>register(
      iv_name  = c_lib_name
      iv_xdata = iv_xdata ).
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
    " 兼容别名：实现收敛在 zcl_ark_convert=>escape_js（core 层），桥等
    " 基础设施也需要该转义，避免组件层被 core 反向依赖
    rv_escaped = zcl_ark_convert=>escape_js( iv_value ).
  ENDMETHOD.

  METHOD include_library_script.
    " 库注入统一走 zcl_ark_js_library 注册器（同页幂等、会话级 MIME 缓存、
    " cache_asset 换本地 URL 均由注册器负责）。
    " 宿主实证（2026-08-22）：WebView2 内 jsdelivr CDN 不可达，未启用
    " MIME 资产的页面图表静默缺席 —— 首次调用时自动尝试随仓库分发的
    " 资产 ZARK_ECHARTS_MIN_JS，缺资产/读失败回退注册 CDN 地址
    IF zcl_ark_js_library=>is_registered( c_lib_name ) = abap_false.
      TRY.
          zcl_ark_js_library=>register(
            iv_name = c_lib_name
            iv_mime = c_bundled_mime_name ).
        CATCH zcx_ark_exception.
          " 资产未上传：保持 CDN 路径
          zcl_ark_js_library=>register(
            iv_name = c_lib_name
            iv_url  = c_cdn_url ).
      ENDTRY.
    ENDIF.

    rv_html = zcl_ark_js_library=>include( c_lib_name ).
    IF rv_html IS INITIAL.
      " 注册器解析失败（如无 GUI 实例）退回 CDN 标签，行为与旧实现一致
      rv_html = |<script src="{ c_cdn_url }"></script>|.
    ENDIF.
  ENDMETHOD.

  METHOD get_option_json.
    rv_json = mv_option_json.
    IF rv_json IS INITIAL.
      rv_json = build_option_js( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_js_widget~get_assets.
    " 库依赖：echarts 本体（地图资产由 render 内的 include_map_script 自注）
    APPEND c_lib_name TO rt_assets.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    DATA(lo_html) = zcl_ark_html=>create( ).

    " ECharts 库。同页多个图表时，仅第一个组件需要带上（iv_include_lib）。
    " 库注入单一路径：set_library_xdata / use_bundled_library 都只是向
    " zcl_ark_js_library 注册，解析/缓存/CDN 回退全在 include_library_script
    IF mv_include_lib = abap_true.
      lo_html->add( include_library_script( ) ).
    ENDIF.

    " 地图资产脚本（echarts.registerMap 的数据来源），须位于初始化脚本
    " 之前；实例级 set_map( iv_xdata ) 优先，其次会话级资产。
    " 上传失败不阻断渲染：registerMap 守卫使图表退化为空地图
    IF mv_map_name IS NOT INITIAL.
      DATA(lv_map_html) = include_map_script( mv_map_name ).

      IF mv_map_xdata IS NOT INITIAL.
        TRY.
            DATA(lv_map_url) = zcl_ark_gui=>get_instance( )->zif_ark_gui_services~cache_asset(
              iv_url     = |ark_map_{ mv_map_name }.js|
              iv_xdata   = mv_map_xdata
              iv_type    = 'text'
              iv_subtype = 'javascript' ).
            IF lv_map_url IS NOT INITIAL.
              lv_map_html = |<script src="{ lv_map_url }"></script>|.
            ENDIF.
          CATCH zcx_ark_exception.
            " 实例级资产上传失败：保持会话资产/空串
        ENDTRY.
      ENDIF.

      IF lv_map_html IS NOT INITIAL.
        lo_html->add( lv_map_html ).
      ENDIF.
    ENDIF.

    " 图表容器。指定宽度时水平居中，缺省铺满可用宽度
    DATA(lv_width) = mv_width.
    IF lv_width IS INITIAL.
      lv_width = '100%'.
    ENDIF.

    lo_html->div(
      iv_id    = mv_div_id
      iv_style = |width: { lv_width }; height: { mv_height }px; margin: 0 auto;| ).

    " 公共事件桥先行注入（同页幂等，初始化脚本里的 arkEmit 依赖它）
    lo_html->add( zcl_ark_js_bridge=>script( ) ).

    " 初始化脚本（IIFE 包裹，不污染全局作用域）
    lo_html->add_js( build_init_js( ) ).

    ri_html = lo_html.
  ENDMETHOD.

  METHOD build_init_js.
    DATA lv_theme_arg TYPE string.
    DATA lv_nl TYPE string.
    DATA lv_base_option TYPE string.
    DATA lv_override_js TYPE string.
    DATA lv_click_js TYPE string.

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

    " 图表元素点击 → sapevent，经公共桥 window.arkEmit（前缀探测/参数
    " 编码收敛在 zcl_ark_js_bridge，桥脚本由 render( ) 先行注入）
    IF mv_on_click IS NOT INITIAL.
      lv_click_js =
        |  myChart.on('click', function(p) \{|                                    && lv_nl &&
        |    var v = p.value;|                                                    && lv_nl &&
        |    if (v && typeof v === 'object') \{ v = JSON.stringify(v); \}|        && lv_nl &&
        |    | && zcl_ark_js_bridge=>emit_js(
              iv_action    = mv_on_click
              iv_params_js = |name: p.name \|\| '',| &&
                             |series: p.seriesName \|\| '',| &&
                             |value: v === undefined ? '' : String(v),| &&
                             |idx: p.dataIndex === undefined ? -1 : p.dataIndex| ) && |;| && lv_nl &&
        |  \});|                                                                 && lv_nl.
    ENDIF.

    " 地图注册：资产脚本已先行加载 window.ARK_MAPS["<map>"]；
    " 守卫缺失时图表退化为空地图而非脚本报错
    DATA lv_map_js TYPE string.
    IF mv_map_name IS NOT INITIAL.
      lv_map_js =
        |  var arkMap = window.ARK_MAPS && window.ARK_MAPS['{ escape_js( mv_map_name ) }'];| && lv_nl &&
        |  if (arkMap) \{ echarts.registerMap('{ escape_js( mv_map_name ) }', arkMap); \}|    && lv_nl.
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
      lv_map_js                                                               &&
      |  var option = | && lv_base_option && |;|                              && lv_nl &&
      lv_override_js                                                          &&
      |  myChart.setOption(option);|                                          && lv_nl &&
      lv_click_js                                                             &&
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

    " visualMap 数值映射条（choropleth 填色图常用；min/max 为受控数值字符串）
    DATA lv_visual_map TYPE string.
    IF mv_visual_min IS NOT INITIAL AND mv_visual_max IS NOT INITIAL.
      lv_visual_map = |  visualMap: \{ min: { mv_visual_min }, max: { mv_visual_max }, left: 'right', calculable: true \},| && lv_nl.
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
      IF <ls_series>-map IS NOT INITIAL.
        lv_options = lv_options && |, map: '{ escape_js( <ls_series>-map ) }'|.
      ENDIF.
      IF <ls_series>-area = abap_true.
        lv_options = lv_options && |, areaStyle: \{ \}|.
      ENDIF.
      IF <ls_series>-smooth = abap_true.
        lv_options = lv_options && `, smooth: true`.
      ENDIF.
      IF <ls_series>-label = abap_true.
        IF <ls_series>-label_thousands = abap_true.
          " 千分位标签（1,630,000）：toLocaleString 依赖 Edge/WebView2 基线
          lv_options = lv_options &&
            |, label: \{ show: true, position: 'top', formatter: function(p) \{ return p.value.toLocaleString(); \} \}|.
        ELSE.
          lv_options = lv_options && |, label: \{ show: true, position: 'top' \}|.
        ENDIF.
      ENDIF.
      IF <ls_series>-color_by_data = abap_true.
        " 逐数据点从调色盘取色（bar/pie 每根柱/每块不同颜色）
        lv_options = lv_options && `, colorBy: 'data'`.
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
      lv_visual_map                                                                 &&
      |  grid: \{ left: '3%', right: '4%', bottom: '3%', containLabel: true \},|    && lv_nl &&
      |  xAxis: [ \{ type: 'category', boundaryGap: false, data: { lv_categories } \} ],| && lv_nl &&
      |  yAxis: [ \{ type: 'value' \} ],|                                           && lv_nl &&
      |  series: [|                                                                 && lv_nl &&
      lv_series_json                                                                && lv_nl &&
      |  ]|                                                                         && lv_nl &&
      |\}|.
  ENDMETHOD.

ENDCLASS.

