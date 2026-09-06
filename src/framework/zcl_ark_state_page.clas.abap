CLASS zcl_ark_state_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! 任意内表 -> 声明式表格节（RTTI 自动出列，数值列自动右对齐）。
    "! 北极星目标的直通车：业务侧给数据，不拼单元格。
    "!   rs_section = zcl_ark_state_page=>table_section(
    "!                  iv_title = '明细' it_data = lt_flight ).
    "! 列标签优先取 DDIC 文本；行类型为基本类型时输出单列 TABLE_LINE
    CLASS-METHODS table_section
      IMPORTING
        !iv_title         TYPE string OPTIONAL
        !it_data          TYPE ANY TABLE
      RETURNING
        VALUE(rs_section) TYPE zif_ark_gui_state=>ty_section
      RAISING
        zcx_ark_exception .

    "! 单系列图表节：一个调用直出 chart 节，数据经 zcl_ark_echarts 声明式
    "! API 构建 option，业务侧零 JSON。
    "!   rs_section = zcl_ark_state_page=>chart_section(
    "!                  iv_title       = '月度销售额'
    "!                  iv_series_name = '销售额'
    "!                  it_categories  = lt_months
    "!                  it_data        = lt_values ).
    "! iv_title 渲染为卡片标题（不写入 option，避免画布内双标题）；
    "! 多系列/堆叠/地图/饼图等高级形态仍走 lo_chart 声明式 API +
    "! get_option_json( ) 供 chart 节
    CLASS-METHODS chart_section
      IMPORTING
        !iv_title         TYPE string OPTIONAL
        !iv_series_name   TYPE string OPTIONAL
        !it_categories    TYPE string_table OPTIONAL
        !it_data          TYPE ANY TABLE
        !iv_chart_type    TYPE string DEFAULT 'bar'
        !iv_click_action  TYPE string OPTIONAL
      RETURNING
        VALUE(rs_section) TYPE zif_ark_gui_state=>ty_section .

    "! 框架内置表格交互（排序/筛选/下载）在此处理，其余动作交给子类。
    "! 保留动作名：ark_sort / ark_filter / ark_download
    METHODS on_event REDEFINITION .

    "! Replace the whole page state in one call (full schema control)
    METHODS set_state
      IMPORTING !is_state TYPE zif_ark_gui_state=>ty_page_state .

    "! Append a fully configured section (table / form / kpi_grid / chart)
    METHODS add_section
      IMPORTING !is_section TYPE zif_ark_gui_state=>ty_section .

    METHODS set_subtitle
      IMPORTING !iv_subtitle TYPE string .

    "! Page-level toolbar items
    METHODS add_button
      IMPORTING
        !iv_label      TYPE string
        !iv_action     TYPE string
        !iv_parameters TYPE string OPTIONAL
        !iv_emphasized TYPE abap_bool DEFAULT abap_false .
    METHODS add_link
      IMPORTING
        !iv_label  TYPE string
        !iv_action TYPE string .
    METHODS add_tooltext
      IMPORTING !iv_text TYPE string .
    METHODS add_toolseparator .

  PROTECTED SECTION.
    DATA ms_state TYPE zif_ark_gui_state=>ty_page_state .

    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    "! 表格节的交互状态（排序/筛选），按节序号记录。
    "! 不修改 ms_state 本身：业务重建 state 后设置自动重新生效
    TYPES:
      BEGIN OF ty_tbl_ui,
        sec      TYPE i,
        sort_col TYPE i,
        "! 1 = 升序, -1 = 降序, 0 = 未排序
        sort_dir TYPE i,
        filter   TYPE string,
      END OF ty_tbl_ui,
      tt_tbl_ui TYPE STANDARD TABLE OF ty_tbl_ui WITH EMPTY KEY .
    DATA mt_tbl_ui TYPE tt_tbl_ui .

    METHODS tbl_ui
      IMPORTING !iv_sec        TYPE i
      RETURNING VALUE(rs_ui)   TYPE ty_tbl_ui .

    "! 排序 + 筛选后的展示行（纯函数，不改 ms_state）
    METHODS transform_rows
      IMPORTING
        !is_section  TYPE zif_ark_gui_state=>ty_section
        !iv_sec      TYPE i
      RETURNING VALUE(rt_rows) TYPE zif_ark_gui_state=>tt_table_rows .

    METHODS is_numeric
      IMPORTING !iv_value       TYPE string
      RETURNING VALUE(rv_isnum) TYPE abap_bool .

    METHODS download_csv
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_sec     TYPE i
      RAISING   zcx_ark_exception .

    METHODS parse_post_value
      IMPORTING
        !iv_name        TYPE string
        !it_postdata    TYPE zif_ark_html_viewer=>ty_post_data
      RETURNING VALUE(rv_value) TYPE string .

    METHODS render_toolbar
      IMPORTING
        !it_items TYPE zif_ark_gui_state=>tt_toolbar_item
      CHANGING
        !co_html  TYPE REF TO zcl_ark_html .

    METHODS render_section
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_index   TYPE i
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_kpi_grid
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_index   TYPE i
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_table
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_index   TYPE i
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_form
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_chart
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_index   TYPE i
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    "! 导航卡片网格（标题+描述卡片，点击触发 sapevent；约定式路由接管）
    METHODS render_card_grid
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    "! 纯文本段落（转义）+ 可选外链
    METHODS render_text
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    "! 声明式表单回读：form_action 命中时把 POST 值写回 form_fields-value，
    "! 并执行 required 校验（失败置 error_text）。返回 false 表示校验失败
    METHODS read_back_form
      IMPORTING
        !ii_event       TYPE REF TO zif_ark_gui_event
        !iv_sec         TYPE i
      RETURNING
        VALUE(rv_valid) TYPE abap_bool .

    "! 查找 form_action 等于动作名的表单节序号（无则 0）
    METHODS find_form_section
      IMPORTING
        !iv_action     TYPE string
      RETURNING
        VALUE(rv_sec)  TYPE i .

    METHODS render_cell
      IMPORTING
        !is_cell      TYPE zif_ark_gui_state=>ty_table_cell
      RETURNING
        VALUE(rv_html) TYPE string .

    "! Sparkline 线色：语义色映射到 Quartz 默认色值（canvas 取不到 CSS 变量，
    "! 主题令牌改名/换值时此处需同步）
    METHODS sparkline_color
      IMPORTING
        !iv_semantic   TYPE zif_ark_gui_state=>ty_semantic
      RETURNING VALUE(rv_color) TYPE string .

    "! 事件参数/单元格值的安全整数转换：非数字输入返回 0 而非 dump
    CLASS-METHODS to_int
      IMPORTING !iv_value       TYPE string
      RETURNING VALUE(rv_int)   TYPE i .

    "! 排序键的安全数值转换：is_numeric 的 CO 校验拦不住 '1.2.3' 等，
    "! 非法值返回 0
    CLASS-METHODS to_num
      IMPORTING !iv_value       TYPE string
      RETURNING VALUE(rv_num)   TYPE decfloat16 .
ENDCLASS.

CLASS zcl_ark_state_page IMPLEMENTATION.

  METHOD table_section.
    DATA lo_tabledesc TYPE REF TO cl_abap_tabledescr.
    DATA lo_line TYPE REF TO cl_abap_datadescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lo_elem TYPE REF TO cl_abap_elemdescr.
    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_rows TYPE zif_ark_gui_state=>tt_table_rows.
    DATA lv_val TYPE string.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_field> TYPE any.
    FIELD-SYMBOLS <ls_comp> TYPE cl_abap_structdescr=>component.
    FIELD-SYMBOLS <ls_col> TYPE zif_ark_gui_state=>ty_table_column.
    FIELD-SYMBOLS <ls_out_row> TYPE zif_ark_gui_state=>ty_table_row.

    rs_section-kind  = zif_ark_gui_state=>c_section_kind-table.
    rs_section-title = iv_title.

    lo_tabledesc ?= cl_abap_tabledescr=>describe_by_data( it_data ).
    lo_line = lo_tabledesc->get_table_line_type( ).
    CLEAR lo_struct.
    IF lo_line->kind = cl_abap_typedescr=>kind_struct.
      lo_struct ?= lo_line.
    ENDIF.

    IF lo_struct IS NOT BOUND.
      " 基本类型行：单列 TABLE_LINE
      APPEND INITIAL LINE TO rs_section-columns ASSIGNING <ls_col>.
      <ls_col>-label = 'TABLE_LINE'.
      LOOP AT it_data ASSIGNING <ls_row>.
        APPEND INITIAL LINE TO lt_rows ASSIGNING <ls_out_row>.
        APPEND VALUE #( value = |{ <ls_row> }| ) TO <ls_out_row>-cells.
      ENDLOOP.
      rs_section-rows = lt_rows.
      RETURN.
    ENDIF.

    lt_comp = lo_struct->get_components( ).
    LOOP AT lt_comp ASSIGNING <ls_comp>.
      APPEND INITIAL LINE TO rs_section-columns ASSIGNING <ls_col>.
      <ls_col>-label = <ls_comp>-name.
      " DDIC 元素优先取数据元素文本做列标签
      IF <ls_comp>-type->kind = cl_abap_typedescr=>kind_elem.
        lo_elem ?= <ls_comp>-type.
        DATA(lv_ddic) = lo_elem->get_ddic_field( ).
        IF sy-subrc = 0.
          IF lv_ddic-scrtext_m IS NOT INITIAL.
            <ls_col>-label = lv_ddic-scrtext_m.
          ELSEIF lv_ddic-scrtext_l IS NOT INITIAL.
            <ls_col>-label = lv_ddic-scrtext_l.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT it_data ASSIGNING <ls_row>.
      APPEND INITIAL LINE TO lt_rows ASSIGNING <ls_out_row>.
      LOOP AT lt_comp ASSIGNING <ls_comp>.
        ASSIGN COMPONENT <ls_comp>-name OF STRUCTURE <ls_row> TO <lv_field>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        lv_val = |{ <lv_field> }|.
        READ TABLE rs_section-columns ASSIGNING <ls_col> INDEX sy-tabix.
        IF <ls_comp>-type->kind = cl_abap_typedescr=>kind_elem.
          lo_elem ?= <ls_comp>-type.
          " 数值列右对齐
          CASE lo_elem->type_kind.
            WHEN cl_abap_typedescr=>typekind_int
              OR cl_abap_typedescr=>typekind_int8
              OR cl_abap_typedescr=>typekind_packed
              OR cl_abap_typedescr=>typekind_decfloat16
              OR cl_abap_typedescr=>typekind_decfloat34
              OR cl_abap_typedescr=>typekind_float.
              <ls_col>-align_right = abap_true.
          ENDCASE.
        ENDIF.
        APPEND VALUE #( value = lv_val ) TO <ls_out_row>-cells.
      ENDLOOP.
    ENDLOOP.

    rs_section-rows = lt_rows.
  ENDMETHOD.

  METHOD chart_section.
    rs_section-kind  = zif_ark_gui_state=>c_section_kind-chart.
    rs_section-title = iv_title.
    rs_section-chart_click_action = iv_click_action.

    DATA(lo_chart) = NEW zcl_ark_echarts( ).
    IF it_categories IS NOT INITIAL.
      lo_chart->set_xaxis_categories( it_categories ).
    ENDIF.
    lo_chart->add_series(
      iv_name = COND string( WHEN iv_series_name IS NOT INITIAL
                             THEN iv_series_name ELSE 'series1' )
      iv_type = iv_chart_type
      it_data = it_data ).
    rs_section-chart_option = lo_chart->get_option_json( ).
  ENDMETHOD.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.

  METHOD set_state.
    ms_state = is_state.
    IF ms_state-title IS NOT INITIAL.
      set_title( ms_state-title ).
    ENDIF.
  ENDMETHOD.

  METHOD set_subtitle.
    ms_state-subtitle = iv_subtitle.
  ENDMETHOD.

  METHOD add_section.
    APPEND is_section TO ms_state-sections.
  ENDMETHOD.

  METHOD add_button.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind       = zif_ark_gui_state=>c_toolbar_kind-button
      label      = iv_label
      action     = iv_action
      parameters = iv_parameters
      emphasized = iv_emphasized
      enabled    = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_link.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-link
      label   = iv_label
      action  = iv_action
      enabled = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_tooltext.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-text
      label   = iv_text ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_toolseparator.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind = zif_ark_gui_state=>c_toolbar_kind-separator ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD build_html.
    " 声明式页面：业务代码只填充 ms_state（或经 set_state/add_* 辅助方法），
    " 此处把类型化 state 渲染为 Fiori 风格 HTML。样式全部来自 zcl_ark_theme
    " 的 .ark-* / 组件类，本类不写任何内联颜色
    IF ms_state-title IS NOT INITIAL.
      set_title( ms_state-title ).
      mo_html->add( |<h1 class="ark-page-title">{ zcl_ark_convert=>escape_html( ms_state-title ) }</h1>| ).
    ENDIF.
    IF ms_state-subtitle IS NOT INITIAL.
      mo_html->add( |<p class="ark-page-subtitle">{ zcl_ark_convert=>escape_html( ms_state-subtitle ) }</p>| ).
    ENDIF.

    render_toolbar( EXPORTING it_items = ms_state-toolbar CHANGING co_html = mo_html ).

    " ECharts 库：chart 节或带 sparkline 的 KPI 卡存在时整页注入一次
    LOOP AT ms_state-sections INTO DATA(ls_lib_check).
      DATA(lv_need_lib) = boolc(
        ls_lib_check-kind = zif_ark_gui_state=>c_section_kind-chart ).
      IF lv_need_lib = abap_false
         AND ls_lib_check-kind = zif_ark_gui_state=>c_section_kind-kpi_grid.
        LOOP AT ls_lib_check-kpi_cards INTO DATA(ls_card_check).
          IF ls_card_check-sparkline IS NOT INITIAL.
            lv_need_lib = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
      IF lv_need_lib = abap_true.
        mo_html->add( zcl_ark_echarts=>include_library_script( ) ).
        EXIT.
      ENDIF.
    ENDLOOP.

    " 地图资产：chart 节声明 chart_map 时注入（同名地图整页只注入一次）；
    " 资产缺失时 include_map_script 返回空串，渲染端 registerMap 守卫兜底
    DATA lt_maps TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT ms_state-sections INTO DATA(ls_map_check)
         WHERE kind = zif_ark_gui_state=>c_section_kind-chart.
      IF ls_map_check-chart_map IS NOT INITIAL.
        INSERT ls_map_check-chart_map INTO TABLE lt_maps.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_maps INTO DATA(lv_map_name).
      DATA(lv_map_html) = zcl_ark_echarts=>include_map_script( lv_map_name ).
      IF lv_map_html IS NOT INITIAL.
        mo_html->add( lv_map_html ).
      ENDIF.
    ENDLOOP.

    DATA lv_index TYPE i.
    LOOP AT ms_state-sections INTO DATA(ls_section).
      lv_index = sy-tabix.
      render_section( EXPORTING is_section = ls_section iv_index = lv_index
                      CHANGING co_html = mo_html ).
    ENDLOOP.

    ri_html = mo_html.
  ENDMETHOD.

  METHOD render_toolbar.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    co_html->add( |<div class="toolbar">| ).

    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_label) = zcl_ark_convert=>escape_html( ls_item-label ).
      CASE ls_item-kind.
        WHEN zif_ark_gui_state=>c_toolbar_kind-button.
          DATA(lv_class) = 'toolbar-button'.
          IF ls_item-emphasized = abap_true.
            lv_class = lv_class && | toolbar-button--emphasized|.
          ENDIF.
          IF ls_item-enabled = abap_false.
            co_html->add( |<span class="toolbar-button disabled">{ lv_label }</span> | ).
          ELSE.
            DATA(lv_params) = COND #(
              WHEN ls_item-parameters IS NOT INITIAL
              THEN |?{ zcl_ark_convert=>escape_html( ls_item-parameters ) }| ).
            co_html->add(
              |<a class="{ lv_class }" href="sapevent:{ zcl_ark_convert=>escape_html( ls_item-action ) }{ lv_params }">| &&
              |{ lv_label }</a> | ).
          ENDIF.
        WHEN zif_ark_gui_state=>c_toolbar_kind-link.
          co_html->add(
            |<a class="toolbar-link" href="sapevent:{ zcl_ark_convert=>escape_html( ls_item-action ) }">{ lv_label }</a> | ).
        WHEN zif_ark_gui_state=>c_toolbar_kind-text.
          co_html->add( |<span class="toolbar-text">{ lv_label }</span> | ).
        WHEN zif_ark_gui_state=>c_toolbar_kind-separator.
          co_html->add( |<span class="separator"></span> | ).
      ENDCASE.
    ENDLOOP.

    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_section.
    co_html->add( |<div class="ark-card">| ).

    IF is_section-title IS NOT INITIAL.
      co_html->add( |<h2 class="ark-card-title">{ zcl_ark_convert=>escape_html( is_section-title ) }</h2>| ).
    ENDIF.

    render_toolbar( EXPORTING it_items = is_section-toolbar CHANGING co_html = co_html ).

    CASE is_section-kind.
      WHEN zif_ark_gui_state=>c_section_kind-kpi_grid.
        render_kpi_grid( EXPORTING is_section = is_section iv_index = iv_index
                        CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-table.
        render_table( EXPORTING is_section = is_section iv_index = iv_index
                      CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-form.
        render_form( EXPORTING is_section = is_section CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-chart.
        render_chart( EXPORTING is_section = is_section iv_index = iv_index
                      CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-card_grid.
        render_card_grid( EXPORTING is_section = is_section CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-text.
        render_text( EXPORTING is_section = is_section CHANGING co_html = co_html ).
    ENDCASE.

    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_kpi_grid.
    DATA lv_js TYPE string.

    co_html->add( |<div class="ark-kpi-grid">| ).

    LOOP AT is_section-kpi_cards INTO DATA(ls_card).
      co_html->add( |<div class="ark-kpi">| ).
      co_html->add( |<div class="ark-kpi-title">{ zcl_ark_convert=>escape_html( ls_card-title ) }</div>| ).
      co_html->add( |<div class="ark-kpi-value">{ zcl_ark_convert=>escape_html( ls_card-value ) }</div>| ).
      IF ls_card-delta_text IS NOT INITIAL.
        DATA(lv_semantic) = zcl_ark_convert=>escape_html( ls_card-delta_semantic ).
        IF lv_semantic IS NOT INITIAL.
          co_html->add(
            |<span class="ark-delta ark-delta--{ lv_semantic }">{ zcl_ark_convert=>escape_html( ls_card-delta_text ) }</span>| ).
        ELSE.
          co_html->add( |<span class="ark-delta">{ zcl_ark_convert=>escape_html( ls_card-delta_text ) }</span>| ).
        ENDIF.
      ENDIF.

      " 迷你趋势线：容器占位，脚本在网格闭合后集中初始化
      IF ls_card-sparkline IS NOT INITIAL.
        DATA(lv_id) = |ark_spark_{ iv_index }_{ sy-tabix }|.
        co_html->div(
          iv_id    = lv_id
          iv_style = |width: 100%; height: 36px; margin-top: 8px;| ).

        DATA(lv_data) = REDUCE #(
          INIT s TYPE string
          FOR lv_val IN ls_card-sparkline
          NEXT s = COND #( WHEN s IS INITIAL
                           THEN zcl_ark_convert=>escape_js( lv_val )
                           ELSE |{ s },{ zcl_ark_convert=>escape_js( lv_val ) }| ) ).

        lv_js = lv_js &&
          |var e=document.getElementById('{ lv_id }');| &&
          |if(window.echarts&&e)\{echarts.init(e).setOption(\{| &&
          |grid:\{left:0,right:0,top:2,bottom:2\},| &&
          |xAxis:\{type:'category',show:false\},| &&
          |yAxis:\{type:'value',show:false\},| &&
          |series:[\{type:'line',data:[{ lv_data }],symbol:'none',smooth:true,| &&
          |lineStyle:\{width:2,color:'{ sparkline_color( ls_card-delta_semantic ) }'\}\}]\});\};| .
      ENDIF.

      co_html->add( |</div>| ).
    ENDLOOP.

    co_html->add( |</div>| ).

    IF lv_js IS NOT INITIAL.
      co_html->add_js( |(function()\{{ lv_js }\})();| ).
    ENDIF.
  ENDMETHOD.

  METHOD render_table.
    DATA(ls_ui) = tbl_ui( iv_index ).

    " 过滤栏 + 下载按钮（ALV 三件套的筛选/导出入口）
    co_html->add( |<form class="ark-filterbar" method="post" | &&
                  |action="sapevent:ark_filter">| ).
    co_html->add( |<input type="hidden" name="sec" value="{ iv_index }">| ).
    co_html->add( |<input type="text" name="flt" value="{ zcl_ark_convert=>escape_html( ls_ui-filter ) }" | &&
                  |placeholder="任意列包含…">| ).
    co_html->add( |<button type="submit" class="toolbar-button">筛选</button>| ).
    co_html->add( |<a class="toolbar-link" | &&
                  |href="sapevent:ark_download?sec={ iv_index }">下载 CSV</a>| ).
    co_html->add( |</form>| ).

    DATA(lt_rows) = transform_rows( is_section = is_section iv_sec = iv_index ).

    co_html->add( |<table>| ).
    co_html->add( |<thead><tr>| ).

    LOOP AT is_section-columns INTO DATA(ls_column).
      DATA(lv_label) = zcl_ark_convert=>escape_html( ls_column-label ).
      DATA(lv_style) = COND #(
        WHEN ls_column-align_right = abap_true THEN | style="text-align: right;"| ).

      " 可排序列（sortable 缺省即允许，显式 abap_false 关闭）：
      " 表头为 sapevent 链接，点击循环 升序->降序->取消
      IF ls_column-sortable <> abap_false AND is_section-rows IS NOT INITIAL.
        DATA(lv_arrow) = ``.
        IF ls_ui-sort_col = sy-tabix.
          CASE ls_ui-sort_dir.
            WHEN 1.  lv_arrow = ` &#9650;`.
            WHEN -1. lv_arrow = ` &#9660;`.
          ENDCASE.
        ENDIF.
        co_html->add(
          |<th{ lv_style }><a class="ark-sort" | &&
          |href="sapevent:ark_sort?sec={ iv_index }&col={ sy-tabix }">| &&
          |{ lv_label }{ lv_arrow }</a></th>| ).
      ELSE.
        co_html->add( |<th{ lv_style }>{ lv_label }</th>| ).
      ENDIF.
    ENDLOOP.

    co_html->add( |</tr></thead>| ).
    co_html->add( |<tbody>| ).

    LOOP AT lt_rows INTO DATA(ls_row).
      co_html->add( |<tr>| ).
      DATA lv_col TYPE i.
      LOOP AT ls_row-cells INTO DATA(ls_cell).
        lv_col = sy-tabix.
        READ TABLE is_section-columns INTO DATA(ls_col) INDEX lv_col.
        IF sy-subrc = 0 AND ls_col-align_right = abap_true.
          co_html->add( |<td class="ark-num">{ render_cell( ls_cell ) }</td>| ).
        ELSE.
          co_html->add( |<td>{ render_cell( ls_cell ) }</td>| ).
        ENDIF.
      ENDLOOP.
      co_html->add( |</tr>| ).
    ENDLOOP.

    IF lt_rows IS INITIAL.
      co_html->add( |<tr><td class="ark-empty">无匹配数据</td></tr>| ).
    ENDIF.

    co_html->add( |</tbody></table>| ).
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'ark_sort'.
        DATA(lv_sec) = to_int( ii_event->query( 'sec' ) ).
        DATA(lv_col) = to_int( ii_event->query( 'col' ) ).
        READ TABLE mt_tbl_ui ASSIGNING FIELD-SYMBOL(<ls_ui>) WITH KEY sec = lv_sec.
        IF sy-subrc <> 0.
          APPEND VALUE ty_tbl_ui( sec = lv_sec ) TO mt_tbl_ui
            ASSIGNING <ls_ui>.
        ENDIF.
        IF <ls_ui>-sort_col = lv_col AND <ls_ui>-sort_dir = 1.
          <ls_ui>-sort_dir = -1.
        ELSEIF <ls_ui>-sort_col = lv_col AND <ls_ui>-sort_dir = -1.
          CLEAR: <ls_ui>-sort_col, <ls_ui>-sort_dir.
        ELSE.
          <ls_ui>-sort_col = lv_col.
          <ls_ui>-sort_dir = 1.
        ENDIF.
        rs_result-state = 1.

      WHEN 'ark_filter'.
        lv_sec = to_int( parse_post_value( iv_name = 'sec' it_postdata = ii_event->mt_postdata ) ).
        DATA(lv_flt) = parse_post_value( iv_name = 'flt' it_postdata = ii_event->mt_postdata ).
        READ TABLE mt_tbl_ui ASSIGNING <ls_ui> WITH KEY sec = lv_sec.
        IF sy-subrc <> 0.
          APPEND VALUE ty_tbl_ui( sec = lv_sec ) TO mt_tbl_ui ASSIGNING <ls_ui>.
        ENDIF.
        <ls_ui>-filter = lv_flt.
        rs_result-state = 1.

      WHEN 'ark_download'.
        TRY.
            download_csv(
              is_section = ms_state-sections[ to_int( ii_event->query( 'sec' ) ) ]
              iv_sec     = to_int( ii_event->query( 'sec' ) ) ).
          CATCH cx_sy_itab_line_not_found.
            " 节序号失效（业务重建 state）：忽略下载
        ENDTRY.
        rs_result-state = 1.

      WHEN OTHERS.
        " 声明式表单：form_action 命中时先自动回读 POST 值并校验 required，
        " 全部通过才放行业务 handler（约定式 on_action_<form_action>）；
        " 校验失败只重渲染以显示错误提示
        DATA(lv_form_sec) = find_form_section( ii_event->mv_action ).
        IF lv_form_sec > 0.
          IF read_back_form( ii_event = ii_event iv_sec = lv_form_sec ) = abap_true.
            rs_result = super->on_event( ii_event ).
            IF rs_result-state IS INITIAL.
              rs_result-state = 1.
            ENDIF.
          ELSE.
            rs_result-state = 1.
          ENDIF.
        ELSE.
          rs_result = super->on_event( ii_event ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD find_form_section.
    LOOP AT ms_state-sections TRANSPORTING NO FIELDS
         WHERE kind = zif_ark_gui_state=>c_section_kind-form
           AND form_action = iv_action.
      rv_sec = sy-tabix.
      RETURN.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_back_form.
    FIELD-SYMBOLS <ls_section> LIKE LINE OF ms_state-sections.
    READ TABLE ms_state-sections ASSIGNING <ls_section> INDEX iv_sec.
    IF sy-subrc <> 0.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    rv_valid = abap_true.
    LOOP AT <ls_section>-form_fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      " 无名字段（如纯 submit 按钮）不参与回读/校验
      IF <ls_field>-name IS INITIAL.
        CONTINUE.
      ENDIF.
      " checkbox 未勾选时浏览器不上送该字段：解析不到即视为空
      <ls_field>-value = parse_post_value(
        iv_name = <ls_field>-name it_postdata = ii_event->mt_postdata ).
      IF <ls_field>-required = abap_true AND <ls_field>-value IS INITIAL.
        <ls_field>-error_text = '此字段为必填项'.
        rv_valid = abap_false.
      ELSE.
        CLEAR <ls_field>-error_text.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD tbl_ui.
    READ TABLE mt_tbl_ui INTO rs_ui WITH KEY sec = iv_sec.
    IF sy-subrc <> 0.
      rs_ui-sec = iv_sec.
    ENDIF.
  ENDMETHOD.

  METHOD transform_rows.
    DATA(ls_ui) = tbl_ui( iv_sec ).
    rt_rows = is_section-rows.

    " 筛选：任意列子串匹配（大小写不敏感），保留匹配行重建表
    IF ls_ui-filter IS NOT INITIAL.
      DATA(lv_flt) = to_lower( ls_ui-filter ).
      DATA(lt_keep) = rt_rows.
      CLEAR rt_rows.
      LOOP AT lt_keep INTO DATA(ls_row).
        DATA(lv_match) = abap_false.
        LOOP AT ls_row-cells INTO DATA(ls_cell).
          IF to_lower( ls_cell-value ) CS lv_flt.
            lv_match = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_match = abap_true.
          APPEND ls_row TO rt_rows.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " 排序：全列数字则按数值比较，否则按文本；方向翻转用倒序循环
    IF ls_ui-sort_col > 0.
      " 数值列判定扫描整列首个非空值：仅看第一行会在首行为空时误判为文本列
      DATA lv_numeric TYPE abap_bool.
      LOOP AT rt_rows INTO DATA(ls_probe).
        READ TABLE ls_probe-cells INTO DATA(ls_probe_cell) INDEX ls_ui-sort_col.
        IF sy-subrc = 0 AND ls_probe_cell-value IS NOT INITIAL.
          lv_numeric = is_numeric( ls_probe_cell-value ).
          EXIT.
        ENDIF.
      ENDLOOP.

      TYPES:
        BEGIN OF ty_sort_row,
          key_num TYPE decfloat16,
          key_txt TYPE string,
          cells   TYPE zif_ark_gui_state=>tt_table_cell,
        END OF ty_sort_row.
      DATA lt_sort TYPE STANDARD TABLE OF ty_sort_row WITH EMPTY KEY.

      LOOP AT rt_rows INTO DATA(ls_r).
        READ TABLE ls_r-cells INTO DATA(ls_c) INDEX ls_ui-sort_col.
        " 千分位逗号剥离后按数值赋键（1,286,000 -> 1286000）
        DATA(lv_keynum) = replace( val = ls_c-value sub = `,` with = `` occ = 0 ).
        APPEND VALUE ty_sort_row(
          key_num = COND decfloat16( WHEN lv_numeric = abap_true
                                     THEN to_num( lv_keynum ) ELSE 0 )
          key_txt = to_lower( ls_c-value )
          cells   = ls_r-cells ) TO lt_sort.
      ENDLOOP.

      IF lv_numeric = abap_true.
        SORT lt_sort BY key_num ASCENDING.
      ELSE.
        SORT lt_sort BY key_txt ASCENDING.
      ENDIF.
      IF ls_ui-sort_dir = -1.
        " 倒序重建：BY -1 负步长在不同版本兼容性存疑，用下标逆序 APPEND
        DATA lt_desc LIKE lt_sort.
        DATA(lv_idx) = lines( lt_sort ).
        WHILE lv_idx > 0.
          APPEND lt_sort[ lv_idx ] TO lt_desc.
          lv_idx = lv_idx - 1.
        ENDWHILE.
        lt_sort = lt_desc.
      ENDIF.

      CLEAR rt_rows.
      LOOP AT lt_sort INTO DATA(ls_s).
        APPEND VALUE #( cells = ls_s-cells ) TO rt_rows.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD is_numeric.
    " 仅含数字/千分位逗号/小数点/负号/加号/空白视为数值（用于排序比较）
    rv_isnum = boolc( iv_value IS NOT INITIAL
                      AND iv_value CO '0123456789.,-+ ' ).
  ENDMETHOD.

  METHOD to_int.
    TRY.
        rv_int = CONV i( iv_value ).
      CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
        rv_int = 0.
    ENDTRY.
  ENDMETHOD.

  METHOD to_num.
    TRY.
        rv_num = CONV decfloat16( iv_value ).
      CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
        rv_num = 0.
    ENDTRY.
  ENDMETHOD.

  METHOD download_csv.
    " 前端保存对话框 + CSV(UTF-8 BOM) 导出，ALV 本地文件下载同款路径。
    " 导出内容 = 当前筛选/排序后的可见行
    DATA lt_csv TYPE string_table.
    DATA(ls_ui) = tbl_ui( iv_sec ).

    DATA(lv_header) = REDUCE #(
      INIT h TYPE string
      FOR ls_col IN is_section-columns
      NEXT h = COND #( WHEN h IS INITIAL THEN ls_col-label ELSE |{ h };{ ls_col-label }| ) ).
    APPEND lv_header TO lt_csv.

    LOOP AT transform_rows( is_section = is_section iv_sec = iv_sec )
         INTO DATA(ls_row).
      DATA(lv_line) = ``.
      LOOP AT ls_row-cells INTO DATA(ls_cell).
        DATA(lv_val) = ls_cell-value.
        " 含分隔符/引号/换行的值按 CSV 规则加引号转义
        IF lv_val CA '; "' OR lv_val CA cl_abap_char_utilities=>cr_lf.
          lv_val = |"{ replace( val = lv_val sub = `"` with = `""` occ = 0 ) }"|.
        ENDIF.
        IF lv_line IS INITIAL.
          lv_line = lv_val.
        ELSE.
          lv_line = |{ lv_line };{ lv_val }|.
        ENDIF.
      ENDLOOP.
      APPEND lv_line TO lt_csv.
    ENDLOOP.

    DATA lv_path TYPE string.
    DATA lv_filename TYPE string.
    DATA lv_fullpath TYPE string.
    TRY.
        cl_gui_frontend_services=>file_save_dialog(
          EXPORTING
            default_extension   = 'csv'
            default_file_name   = 'ark_export'
            file_filter         = 'CSV 文件 (*.csv)|*.csv|所有文件|*.*'
          CHANGING
            filename            = lv_filename
            path                = lv_path
            fullpath            = lv_fullpath ).
        IF lv_fullpath IS INITIAL.
          RETURN.  " 用户取消
        ENDIF.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename                = lv_fullpath
            filetype                = 'DAT'
            codepage                = '4110'
            write_bom               = abap_true
          CHANGING
            data_tab                = lt_csv ).
      CATCH cx_root INTO DATA(lx_fs).
        zcx_ark_exception=>raise( |CSV 下载失败: { lx_fs->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD parse_post_value.
    " postdata 形如 name=value&name2=value2，取指定字段并做 URL 解码。
    " 先拼成完整 body 再匹配：postdata 按固定长度分片，名值对可能被切到两片
    DATA(lv_body) = REDUCE #(
      INIT s TYPE string
      FOR lv_part IN it_postdata
      NEXT s = s && lv_part ).
    FIND REGEX |(^\|&)({ iv_name })=(.*)$| IN lv_body
      SUBMATCHES DATA(lv_val).
    IF sy-subrc = 0.
      rv_value = zcl_ark_convert=>url_decode( lv_val ).
    ENDIF.
  ENDMETHOD.

  METHOD render_cell.
    DATA(lv_value) = zcl_ark_convert=>escape_html( is_cell-value ).
    IF is_cell-action IS NOT INITIAL.
      rv_html = |<a href="sapevent:{ zcl_ark_convert=>escape_html( is_cell-action ) }">{ lv_value }</a>|.
      IF is_cell-semantic IS NOT INITIAL.
        rv_html = |<span class="ark-status ark-status--{ zcl_ark_convert=>escape_html( is_cell-semantic ) }"></span>{ rv_html }|.
      ENDIF.
    ELSEIF is_cell-semantic IS NOT INITIAL.
      rv_html = |<span class="ark-status ark-status--{ zcl_ark_convert=>escape_html( is_cell-semantic ) }">| &&
                |{ lv_value }</span>|.
    ELSE.
      rv_html = lv_value.
    ENDIF.
  ENDMETHOD.

  METHOD render_form.
    IF is_section-form_action IS INITIAL.
      co_html->add( |<form method="post">| ).
    ELSE.
      co_html->add(
        |<form method="post" action="sapevent:{ zcl_ark_convert=>escape_html( is_section-form_action ) }">| ).
    ENDIF.

    LOOP AT is_section-form_fields INTO DATA(ls_field).
      DATA(lv_label) = zcl_ark_convert=>escape_html( ls_field-label ).
      IF ls_field-required = abap_true.
        lv_label = |{ lv_label } <span class="ark-required">*</span>|.
      ENDIF.
      DATA(lv_name)  = zcl_ark_convert=>escape_html( ls_field-name ).
      DATA(lv_value) = zcl_ark_convert=>escape_html( ls_field-value ).
      DATA(lv_type)  = zcl_ark_convert=>escape_html( ls_field-input_type ).
      " 校验失败的控件标红，错误提示跟在控件后
      DATA(lv_err_class) = COND string( WHEN ls_field-error_text IS NOT INITIAL
                                        THEN ' class="ark-input-error"' ).
      DATA(lv_err_text)  = COND string( WHEN ls_field-error_text IS NOT INITIAL
                                        THEN |<span class="ark-field-error">{ zcl_ark_convert=>escape_html( ls_field-error_text ) }</span>| ).
      co_html->add( |<div class="form-row">| ).
      co_html->add( |<span class="form-label">{ lv_label }</span>| ).

      CASE ls_field-input_type.
        WHEN 'select'.
          co_html->add( |<select{ lv_err_class } name="{ lv_name }">| ).
          LOOP AT ls_field-options INTO DATA(lv_option).
            DATA(lv_opt) = zcl_ark_convert=>escape_html( lv_option ).
            IF lv_option = ls_field-value.
              co_html->add( |<option selected>{ lv_opt }</option>| ).
            ELSE.
              co_html->add( |<option>{ lv_opt }</option>| ).
            ENDIF.
          ENDLOOP.
          co_html->add( |</select>| ).
        WHEN 'textarea'.
          co_html->add(
            |<textarea{ lv_err_class } name="{ lv_name }" rows="4">| &&
            |{ lv_value }</textarea>| ).
        WHEN 'checkbox'.
          IF ls_field-value = 'X'.
            co_html->add( |<input type="checkbox" name="{ lv_name }" checked>| ).
          ELSE.
            co_html->add( |<input type="checkbox" name="{ lv_name }">| ).
          ENDIF.
        WHEN 'hidden'.
          co_html->add( |<input type="hidden" name="{ lv_name }" | &&
                        |value="{ lv_value }">| ).
        WHEN 'submit'.
          co_html->add( |<button type="submit" class="toolbar-button">{ lv_value }</button>| ).
        WHEN OTHERS.
          co_html->add( |<input type="{ lv_type }"{ lv_err_class } name="{ lv_name }" | &&
                        |value="{ lv_value }">| ).
      ENDCASE.

      co_html->add( lv_err_text ).
      co_html->add( |</div>| ).
    ENDLOOP.

    co_html->add( |</form>| ).
  ENDMETHOD.

  METHOD sparkline_color.
    CASE iv_semantic.
      WHEN zif_ark_gui_state=>c_semantic-positive.
        rv_color = '#107e3e'.
      WHEN zif_ark_gui_state=>c_semantic-negative.
        rv_color = '#bb0000'.
      WHEN zif_ark_gui_state=>c_semantic-critical.
        rv_color = '#e9730c'.
      WHEN zif_ark_gui_state=>c_semantic-informative.
        rv_color = '#0a6ed1'.
      WHEN OTHERS.
        rv_color = '#0070f2'.
    ENDCASE.
  ENDMETHOD.

  METHOD render_card_grid.
    " 导航卡片网格：卡片即 sapevent 链接（约定式路由接管动作），
    " 样式全在主题 .ark-nav-* 类，本方法不写任何内联颜色/布局尺寸
    co_html->add( |<div class="ark-nav-grid">| ).
    LOOP AT is_section-cards INTO DATA(ls_card).
      co_html->add(
        |<a class="ark-nav-card" href="sapevent:{ zcl_ark_convert=>escape_html( ls_card-action ) }">| &&
        |<span class="ark-nav-card-title">{ zcl_ark_convert=>escape_html( ls_card-title ) }</span>| &&
        |<span class="ark-nav-card-desc">{ zcl_ark_convert=>escape_html( ls_card-desc ) }</span>| &&
        |</a> | ).
    ENDLOOP.
    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_text.
    " 纯文本段落（转义）+ 可选外链（外部 URL 开新窗口）
    DATA(lv_html) = |<p class="ark-text">{ zcl_ark_convert=>escape_html( is_section-text ) }|.
    IF is_section-link_url IS NOT INITIAL.
      lv_html = lv_html &&
        | <a href="{ zcl_ark_convert=>escape_html( is_section-link_url ) }" target="_blank">| &&
        |{ zcl_ark_convert=>escape_html( is_section-link_text ) }</a>|.
    ENDIF.
    co_html->add( |{ lv_html }</p>| ).
  ENDMETHOD.

  METHOD render_chart.
    DATA(lv_id) = |ark_state_chart_{ iv_index }|.

    co_html->div(
      iv_id    = lv_id
      iv_style = |width: 100%; height: 320px;| ).

    " chart_option 是 JSON，本身即合法 JS 对象字面量；
    " 仅需转义 </ 防止值中 </script> 截断宿主脚本块
    DATA(lv_option) = is_section-chart_option.
    lv_option = replace( val = lv_option sub = `</` with = `<\/` occ = 0 ).

    " 地图注册：chart_map 对应资产已由 build_html 注入（守卫缺失时退化为空地图）
    DATA lv_map_js TYPE string.
    IF is_section-chart_map IS NOT INITIAL.
      DATA(lv_map_esc) = zcl_ark_convert=>escape_js( is_section-chart_map ).
      lv_map_js =
        |var m = window.ARK_MAPS && window.ARK_MAPS['{ lv_map_esc }'];| &&
        |if (m) \{ echarts.registerMap('{ lv_map_esc }', m); \}| .
    ENDIF.

    " 图表元素点击 → sapevent，参数同 zcl_ark_echarts=>set_on_click，
    " 额外带 chart=节序号区分多个图表节。action 来自应用 state，
    " 信任级别与 toolbar action 一致。
    " 前缀探测/参数编码收敛在公共桥 zcl_ark_js_bridge（arkEmit）
    DATA lv_click_js TYPE string.
    IF is_section-chart_click_action IS NOT INITIAL.
      lv_click_js =
        |c.on('click', function(p) \{| &&
        |var v = p.value;| &&
        |if (v && typeof v === 'object') \{ v = JSON.stringify(v); \}| &&
        zcl_ark_js_bridge=>emit_js(
          iv_action    = is_section-chart_click_action
          iv_params_js = |name: p.name \|\| '',| &&
                         |series: p.seriesName \|\| '',| &&
                         |value: v === undefined ? '' : String(v),| &&
                         |idx: p.dataIndex === undefined ? -1 : p.dataIndex,| &&
                         |chart: { iv_index }| ) && |;| &&
        |\});| .
    ENDIF.

    " 公共事件桥先行注入（同页幂等，点击回传的 arkEmit 依赖它）
    co_html->add( zcl_ark_js_bridge=>script( ) ).

    co_html->add_js(
      |(function() \{| &&
      |var el = document.getElementById('{ lv_id }');| &&
      |if (window.echarts && el) \{| &&
      |var c = echarts.init(el);| &&
      lv_map_js &&
      |c.setOption({ lv_option });| &&
      lv_click_js &&
      |\} else if (el) \{| &&
      |  el.innerHTML = '<span style="color:#b00;font-size:13px">| &&
      |ECharts 库未加载（CDN/MIME 均不可达）— 图表缺席</span>';| &&
      |\}| &&
      |\})();| ).
  ENDMETHOD.

ENDCLASS.
