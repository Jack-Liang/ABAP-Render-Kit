CLASS zcl_ark_example_state_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_state_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS on_event REDEFINITION .

  PRIVATE SECTION.
    DATA mv_factor TYPE i VALUE 1 .
    DATA mv_message TYPE string .

    METHODS build_state .
ENDCLASS.

CLASS zcl_ark_example_state_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    build_state( ).
  ENDMETHOD.

  METHOD build_state.
    " 演示声明式页面：业务代码只填类型化 state，一行 HTML 都不写。
    " 渲染由 zcl_ark_state_page 完成，样式来自 zcl_ark_theme
    DATA(ls_state) = VALUE zif_ark_gui_state=>ty_page_state(
      title    = '销售概览'
      subtitle = '声明式 state 页面演示 — 点击工具栏按钮 / 表格链接 / 提交表单试试' ).

    ls_state-toolbar = VALUE #(
      ( kind = zif_ark_gui_state=>c_toolbar_kind-button
        label = '刷新数据' action = 'state_refresh' emphasized = abap_true )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-separator )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-text
        label = |放大系数: x{ mv_factor }| )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '返回' action = 'nav_home' ) ).

    " ---- KPI 卡片 ----
    ls_state-sections = VALUE #(
      ( kind = zif_ark_gui_state=>c_section_kind-kpi_grid
        kpi_cards = VALUE #(
          ( title = '总销售额' value = |{ 4286 * mv_factor } 万|
            delta_text = '▲ 12.4% 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `32` ) ( `38` ) ( `35` ) ( `42` ) ( `48` ) ( `45` ) ( `52` ) ) )
          ( title = '订单数' value = |{ 18532 * mv_factor }|
            delta_text = '▲ 6.8% 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `12` ) ( `14` ) ( `13` ) ( `15` ) ( `16` ) ( `17` ) ( `19` ) ) )
          ( title = '退货率' value = '2.1%'
            delta_text = '▼ 0.4pp 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-negative
            sparkline = VALUE #( ( `3.4` ) ( `3.2` ) ( `2.9` ) ( `2.7` ) ( `2.4` ) ( `2.3` ) ( `2.1` ) ) )
          ( title = '客户满意度' value = '94.6'
            delta_text = '▲ 1.2 环比'
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `90` ) ( `91` ) ( `92` ) ( `92.8` ) ( `93.5` ) ( `94` ) ( `94.6` ) ) ) ) ).

    " ---- 表格（语义色状态 + 行内链接动作）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-table
        title = '销售凭证'
        columns = VALUE #(
          ( label = '凭证' ) ( label = '客户' ) ( label = '净价值' align_right = abap_true )
          ( label = '状态' ) )
        rows = VALUE #(
          ( VALUE #(
            ( value = '0080012345' action = 'cell_detail' )
            ( value = '华信科技' )
            ( value = '1,286,000' )
            ( value = '已完成' semantic = zif_ark_gui_state=>c_semantic-positive ) )
          ( VALUE #(
            ( value = '0080012346' action = 'cell_detail' )
            ( value = '南方物流集团' )
            ( value = '862,400' )
            ( value = '待审批' semantic = zif_ark_gui_state=>c_semantic-critical ) )
          ( VALUE #(
            ( value = '0080012347' action = 'cell_detail' )
            ( value = '北方重工' )
            ( value = '2,045,900' )
            ( value = '被拒绝' semantic = zif_ark_gui_state=>c_semantic-negative ) ) ) ) ).

    " ---- 图表（ECharts option JSON 直入）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-chart
        title = '月度销售额'
        chart_option =
          `{ "xAxis": { "type": "category", "data": ["1月","2月","3月","4月","5月","6月"] },` &&
          `  "yAxis": { "type": "value" },` &&
          `  "series": [{ "type": "bar", "name": "销售额",` &&
          `    "data": [420,455,490,530,580,620],` &&
          `    "itemStyle": { "color": "#0070f2", "borderRadius": [4,4,0,0] } }] }` ) ).

    " ---- 表单（sapevent POST 回传）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-form
        title = '筛选条件'
        form_action = 'form_save'
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

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'state_refresh'.
        " 演示"只改数据、重渲染"：state 驱动页面的常规刷新路径
        mv_factor = mv_factor + 1.
        IF mv_factor > 5.
          mv_factor = 1.
        ENDIF.
        build_state( ).
        rs_result-state = 1.
      WHEN 'form_save'.
        " 表单 POST：postdata 为 name=value&... 形式，这里演示取回一个字段
        LOOP AT ii_event->mt_postdata INTO DATA(lv_post).
          IF lv_post CS 'city='.
            DATA(lv_city) = substring_after( val = lv_post sub = 'city=' ).
            mv_message = |筛选已应用: 客户 = { lv_city }|.
          ENDIF.
        ENDLOOP.
        build_state( ).
        rs_result-state = 1.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
