CLASS zcl_ark_example_ui5_state_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_ui5_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! 经典主框架事件（工具栏 link 走 ark.nav 整页导航路径）
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    "! 桥事件（工具栏按钮 / 单元格链接 / 图表点击 / 表单提交）
    METHODS on_state_event REDEFINITION .

  PRIVATE SECTION.
    DATA mv_factor TYPE i VALUE 1 ##NO_TEXT.
    DATA mv_message TYPE string .
    DATA ms_table TYPE zif_ark_gui_state=>ty_section .

    METHODS build_state .

    "! 追加一行到表格节：参数为该行的单元格表
    METHODS add_row
      IMPORTING !cells TYPE zif_ark_gui_state=>tt_table_cell .
ENDCLASS.

CLASS zcl_ark_example_ui5_state_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    build_state( ).
  ENDMETHOD.


  METHOD build_state.
    " UI5 声明式页面演示：与 zcl_ark_example_state_page 同一 state 内容，
    " 渲染走 UI5 启动壳 —— 工具栏/表格为 sap.m，KPI/图表为 ECharts 分区，
    " 交互经 sapevent 桥回推新 state（UI5 常驻不重启）
    DATA(ls_state) = VALUE zif_ark_gui_state=>ty_page_state(
      title    = '销售概览 · UI5'
      subtitle = '声明式 state + UI5 启动壳 — 点击工具栏按钮 / 表格链接 / 图表 / 提交表单试试' ).

    ls_state-toolbar = VALUE #(
      ( kind = zif_ark_gui_state=>c_toolbar_kind-button
        label = '刷新数据' action = 'ui5s_refresh' emphasized = abap_true )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-separator )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-text
        label = |放大系数: x{ mv_factor }| )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '返回' action = 'nav_home' ) ).

    " ---- KPI 卡片 ----
    DATA(lv_sales) = |{ 4286 * mv_factor }|.
    DATA(lv_orders) = |{ 18532 * mv_factor }|.
    ls_state-sections = VALUE #(
      ( kind = zif_ark_gui_state=>c_section_kind-kpi_grid
        kpi_cards = VALUE #(
          ( title = '总销售额' value = |{ lv_sales } 万|
            delta_text = '▲ 12.4% 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `32` ) ( `38` ) ( `35` ) ( `42` ) ( `48` ) ( `45` ) ( `52` ) ) )
          ( title = '订单数' value = lv_orders
            delta_text = '▲ 6.8% 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `12` ) ( `14` ) ( `13` ) ( `15` ) ( `16` ) ( `17` ) ( `19` ) ) )
          ( title = '退货率' value = '2.1%'
            delta_text = '▼ 0.4pp 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-negative
            sparkline = VALUE #( ( `3.4` ) ( `3.2` ) ( `2.9` ) ( `2.7` ) ( `2.4` ) ( `2.3` ) ( `2.1` ) ) )
          ( title = '客户满意度' value = '94.6'
            delta_text = '▲ 1.2 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-informative
            sparkline = VALUE #( ( `90` ) ( `91` ) ( `92` ) ( `92.8` ) ( `93.5` ) ( `94` ) ( `94.6` ) ) ) ) ).

    " ---- 表格（嵌套内表无法内联构造，ADD_ROW 逐行追加 — 7.57 兼容）----
    ms_table = VALUE zif_ark_gui_state=>ty_section(
      kind  = zif_ark_gui_state=>c_section_kind-table
      title = '销售凭证'
      columns = VALUE #(
        ( label = '凭证' ) ( label = '客户' ) ( label = '净价值' align_right = abap_true )
        ( label = '数量' align_right = abap_true )
        ( label = '状态' ) ) ).

    DATA(lt_cells) = VALUE zif_ark_gui_state=>tt_table_cell(
      ( value = '0080012345' action = 'ui5s_cell' )
      ( value = '华信科技' )
      ( value = '1,286,000' )
      ( value = '120' )
      ( value = '已完成' semantic = zif_ark_gui_state=>c_semantic-positive )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012346' action = 'ui5s_cell' )
      ( value = '南方物流集团' )
      ( value = '862,400' )
      ( value = '58' )
      ( value = '待审批' semantic = zif_ark_gui_state=>c_semantic-critical )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012347' action = 'ui5s_cell' )
      ( value = '北方重工' )
      ( value = '2,045,900' )
      ( value = '12' )
      ( value = '已发货' semantic = zif_ark_gui_state=>c_semantic-positive )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012348' action = 'ui5s_cell' )
      ( value = '东海商贸' )
      ( value = '95,700' )
      ( value = '640' )
      ( value = '被拒绝' semantic = zif_ark_gui_state=>c_semantic-negative )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012349' action = 'ui5s_cell' )
      ( value = '西部能源' )
      ( value = '530,200' )
      ( value = '35' )
      ( value = '处理中' semantic = zif_ark_gui_state=>c_semantic-neutral )
      ).
    add_row( lt_cells ).

    APPEND ms_table TO ls_state-sections.

    " ---- 图表（ECharts option JSON 直入；点击柱子经桥回传）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-chart
        title = '月度销售额'
        chart_click_action = 'ui5s_chart_click'
        chart_option =
          `{ "tooltip": { "trigger": "axis" },` &&
          `  "grid": { "left": 56, "right": 24, "top": 30, "bottom": 30 },` &&
          `  "xAxis": { "type": "category", "data": ["1月","2月","3月","4月","5月","6月"] },` &&
          `  "yAxis": { "type": "value", "name": "万元" },` &&
          `  "series": [{ "type": "bar", "name": "销售额",` &&
          `    "data": [420,455,490,530,580,620],` &&
          `    "itemStyle": { "color": "#0070f2", "borderRadius": [4,4,0,0] } }] }` ) ).

    " ---- 表单（经桥 POST：隐藏 __ark 字段 + target=ark_bridge）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-form
        title = '筛选条件'
        form_action = 'ui5s_form_save'
        form_fields = VALUE #(
          ( input_type = 'text' label = '客户名' name = 'city' value = '华信科技' )
          ( input_type = 'select' label = '渠道' name = 'channel'
            value = '直销' options = VALUE #( ( `直销` ) ( `分销` ) ( `电商` ) ) )
          ( input_type = 'submit' label = '' name = '' value = '应用筛选' ) ) ) ).

    IF mv_message IS NOT INITIAL.
      ls_state-subtitle = mv_message.
    ENDIF.

    set_state( ls_state ).
  ENDMETHOD.


  METHOD add_row.
    APPEND VALUE #( cells = cells ) TO ms_table-rows.
  ENDMETHOD.


  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        " 工具栏 link 前端走 ark.nav（主框架导航）→ 经典整页切换路径
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_state_event.
    CASE ii_event->mv_action.
      WHEN 'ui5s_refresh'.
        mv_factor = mv_factor + 1.
        IF mv_factor > 5.
          mv_factor = 1.
        ENDIF.
        mv_message = |桥往返刷新: 系数 x{ mv_factor }（UI5 未重启）|.
        build_state( ).

      WHEN 'ui5s_cell'.
        " 单元格链接：前端附加 __row（1 基行号）定位点击行
        mv_message = |行 { ii_event->query( '__row' ) } 详情（经桥回传，就地更新）|.
        build_state( ).

      WHEN 'ui5s_chart_click'.
        " 图表点击回传：name=类目，value=值，chart=节序号（与 A 路线同参）
        mv_message = |图表点击: { ii_event->query( 'name' ) } = { ii_event->query( 'value' ) }|.
        build_state( ).

      WHEN 'ui5s_form_save'.
        " 表单经桥 POST：postdata 为 name=value&... 片段，取回一个字段演示
        LOOP AT ii_event->mt_postdata INTO DATA(lv_post).
          IF lv_post CS 'city='.
            DATA(lv_city) = substring_after( val = lv_post sub = 'city=' ).
            mv_message = |筛选已应用: 客户 = { lv_city }（表单经桥 POST）|.
          ENDIF.
        ENDLOOP.
        build_state( ).

      WHEN OTHERS.
        rs_result = super->on_state_event( ii_event ).
    ENDCASE.
    " 返回后框架把重建的 ms_state 回推桥帧（keep_view），无需自己响应
  ENDMETHOD.

ENDCLASS.
