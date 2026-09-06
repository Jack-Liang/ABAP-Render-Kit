CLASS zcl_ark_example_state_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_state_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_factor TYPE i VALUE 1 .
    DATA mv_message TYPE string .
    " 表单声明式回读的落地值：框架已把 POST 值写回 ms_state，
    " handler 取走后放这里，build_state 重建时作为字段初值复用
    DATA mv_city TYPE string VALUE '华信科技' .
    DATA mv_channel TYPE string VALUE '直销' .
    DATA ms_table TYPE zif_ark_gui_state=>ty_section .

    METHODS build_state .

    "! 追加一行到表格节：参数为该行的单元格表
    METHODS add_row
      IMPORTING !cells TYPE zif_ark_gui_state=>tt_table_cell .
ENDCLASS.



CLASS ZCL_ARK_EXAMPLE_STATE_PAGE IMPLEMENTATION.


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
        label = |放大系数: x{ mv_factor }| ) ).
    " 返回不需要自己写：框架在非主页自动注入统一返回条（ark_back）

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
            delta_semantic = zif_ark_gui_state=>c_semantic-positive
            sparkline = VALUE #( ( `90` ) ( `91` ) ( `92` ) ( `92.8` ) ( `93.5` ) ( `94` ) ( `94.6` ) ) ) ) ) ).

    " ---- 表格（语义色状态 + 行内链接动作；表头点击排序/过滤栏/CSV 下载为内置能力）----
    " 嵌套内表（表行的行类型本身是内表）在 7.57 上无法内联构造，
    " 用 ADD_ROW 逐行追加（见私有方法），兼容且可读
    ms_table = VALUE zif_ark_gui_state=>ty_section(
      kind  = zif_ark_gui_state=>c_section_kind-table
      title = '销售凭证'
      columns = VALUE #(
        ( label = '凭证' ) ( label = '客户' ) ( label = '净价值' align_right = abap_true )
        ( label = '数量' align_right = abap_true )
        ( label = '状态' ) ) ).

    DATA(lt_cells) = VALUE zif_ark_gui_state=>tt_table_cell(
      ( value = '0080012345' action = 'cell_detail' )
      ( value = '华信科技' )
      ( value = '1,286,000' )
      ( value = '120' )
      ( value = '已完成' semantic = zif_ark_gui_state=>c_semantic-positive )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012346' action = 'cell_detail' )
      ( value = '南方物流集团' )
      ( value = '862,400' )
      ( value = '58' )
      ( value = '待审批' semantic = zif_ark_gui_state=>c_semantic-critical )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012347' action = 'cell_detail' )
      ( value = '北方重工' )
      ( value = '2,045,900' )
      ( value = '12' )
      ( value = '已发货' semantic = zif_ark_gui_state=>c_semantic-positive )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012348' action = 'cell_detail' )
      ( value = '东海商贸' )
      ( value = '95,700' )
      ( value = '640' )
      ( value = '被拒绝' semantic = zif_ark_gui_state=>c_semantic-negative )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012349' action = 'cell_detail' )
      ( value = '西部能源' )
      ( value = '530,200' )
      ( value = '35' )
      ( value = '处理中' semantic = zif_ark_gui_state=>c_semantic-neutral )
      ).
    add_row( lt_cells ).
    lt_cells = VALUE #(
      ( value = '0080012350' action = 'cell_detail' )
      ( value = '华信科技' )
      ( value = '742,300' )
      ( value = '210' )
      ( value = '已完成' semantic = zif_ark_gui_state=>c_semantic-positive )
      ).
    add_row( lt_cells ).

    APPEND ms_table TO ls_state-sections.

    " ---- 任意内表直出（table_section：RTTI 自动出列，不拼单元格）----
    DATA lt_months TYPE zcl_ark_echarts=>ty_values.
    lt_months = VALUE #( ( 420 ) ( 455 ) ( 490 ) ( 530 ) ( 580 ) ( 620 ) ).
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( zcl_ark_state_page=>table_section(
          iv_title = '月度数据（任意内表直出）'
          it_data  = lt_months ) ) ).

    " ---- 图表（chart_section：单系列一调用直出，点击柱子回传）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( zcl_ark_state_page=>chart_section(
          iv_title        = '月度销售额'
          iv_series_name  = '销售额'
          it_categories   = VALUE string_table( ( `1月` ) ( `2月` ) ( `3月` )
                                                 ( `4月` ) ( `5月` ) ( `6月` ) )
          it_data         = VALUE zcl_ark_echarts=>ty_values(
                              ( 420 ) ( 455 ) ( 490 ) ( 530 ) ( 580 ) ( 620 ) )
          iv_click_action = 'state_chart_click' ) ) ).

    " ---- 表单（sapevent POST 回传）----
    ls_state-sections = VALUE #( BASE ls_state-sections
      ( kind = zif_ark_gui_state=>c_section_kind-form
        title = '筛选条件'
        form_action = 'form_save'
        form_fields = VALUE #(
          ( input_type = 'text' label = '客户名' name = 'city' value = mv_city
            required = abap_true )
          ( input_type = 'select' label = '渠道' name = 'channel'
            value = mv_channel options = VALUE #( ( `直销` ) ( `分销` ) ( `电商` ) ) )
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
      WHEN 'state_refresh'.
        " 演示"只改数据、重渲染"：state 驱动页面的常规刷新路径
        mv_factor = mv_factor + 1.
        IF mv_factor > 5.
          mv_factor = 1.
        ENDIF.
        build_state( ).
        rs_result-state = 1.
      WHEN 'form_save'.
        " 声明式表单回读：到达这里前框架已把 POST 值写进 ms_state 并通过
        " required 校验（失败时根本不会进本分支，页面显示红色错误提示）。
        " 业务代码只从 ms_state 取值 —— 无需手动解析 postdata
        LOOP AT ms_state-sections ASSIGNING FIELD-SYMBOL(<ls_sec>)
             WHERE form_action = 'form_save'.
          LOOP AT <ls_sec>-form_fields ASSIGNING FIELD-SYMBOL(<ls_f>).
            CASE <ls_f>-name.
              WHEN 'city'.    mv_city = <ls_f>-value.
              WHEN 'channel'. mv_channel = <ls_f>-value.
            ENDCASE.
          ENDLOOP.
        ENDLOOP.
        mv_message = |筛选已应用: 客户 = { mv_city }，渠道 = { mv_channel }|.
        build_state( ).
        rs_result-state = 1.
      WHEN 'state_chart_click'.
        " 图表点击回传：name=类目（月份），chart=节序号；值已自动 URL 解码
        mv_message = |图表点击: { ii_event->query( 'name' ) } = { ii_event->query( 'value' ) }|.
        build_state( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
