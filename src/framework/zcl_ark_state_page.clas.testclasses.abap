" 测试桥：公开受保护的 ms_state 读取（仅测试用）
CLASS lcl_test_state_page DEFINITION FINAL CREATE PUBLIC
  INHERITING FROM zcl_ark_state_page.
  PUBLIC SECTION.
    METHODS get_state
      RETURNING VALUE(rs_state) TYPE zif_ark_gui_state=>ty_page_state .
    METHODS render_html
      RETURNING VALUE(rv_html) TYPE string .
ENDCLASS.

CLASS lcl_test_state_page IMPLEMENTATION.
  METHOD get_state.
    rs_state = ms_state.
  ENDMETHOD.
  METHOD render_html.
    rv_html = build_html( )->render( ).
  ENDMETHOD.
ENDCLASS.

" table_section 的测试行类型（含数值列验证右对齐判定）
TYPES:
  BEGIN OF ty_test_row,
    code   TYPE string,
    amount TYPE i,
  END OF ty_test_row,
  tt_test_row TYPE STANDARD TABLE OF ty_test_row WITH EMPTY KEY .

CLASS ltcl_state_form DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS read_back_writes_values FOR TESTING.
    METHODS required_rejects_empty FOR TESTING.
    METHODS required_pass_allows_handler FOR TESTING.
    METHODS table_section_from_data FOR TESTING.
    METHODS chart_section_builds_option FOR TESTING.
    METHODS chart_section_multi_series FOR TESTING.
    METHODS progress_clamps_and_escapes FOR TESTING.
ENDCLASS.

CLASS ltcl_state_form IMPLEMENTATION.

  METHOD read_back_writes_values.
    DATA(lo_page) = NEW lcl_test_state_page( ).
    lo_page->set_state( VALUE zif_ark_gui_state=>ty_page_state(
      sections = VALUE #(
        ( kind = zif_ark_gui_state=>c_section_kind-form
          form_action = 'save_form'
          form_fields = VALUE #(
            ( input_type = 'text' label = 'A' name = 'field_a' )
            ( input_type = 'text' label = 'B' name = 'field_b' ) ) ) ) ) ).

    lo_page->on_event( zcl_ark_gui_event=>new(
      iv_action = 'save_form'
      it_postdata = VALUE #( ( |field_a=hello&field_b=world| ) ) ) ).

    DATA(ls_state) = lo_page->get_state( ).
    DATA(lv_a) = ``.
    DATA(lv_b) = ``.
    LOOP AT ls_state-sections ASSIGNING FIELD-SYMBOL(<ls_sec>)
         WHERE form_action = 'save_form'.
      READ TABLE <ls_sec>-form_fields WITH KEY name = 'field_a'
        INTO DATA(ls_field).
      lv_a = ls_field-value.
      READ TABLE <ls_sec>-form_fields WITH KEY name = 'field_b'
        INTO ls_field.
      lv_b = ls_field-value.
    ENDLOOP.
    " 多字段回读：第一个字段的值必须截断在 & 边界（贪婪正则回归）
    cl_abap_unit_assert=>assert_equals( exp  = `hello` act  = lv_a ).
    cl_abap_unit_assert=>assert_equals( exp  = `world` act  = lv_b ).
  ENDMETHOD.

  METHOD required_rejects_empty.
    DATA(lo_page) = NEW lcl_test_state_page( ).
    lo_page->set_state( VALUE zif_ark_gui_state=>ty_page_state(
      sections = VALUE #(
        ( kind = zif_ark_gui_state=>c_section_kind-form
          form_action = 'save_form'
          form_fields = VALUE #(
            ( input_type = 'text' label = 'A' name = 'field_a'
              required = abap_true ) ) ) ) ) ).

    " required 字段为空：校验失败（state=1 重渲染），handler 链不执行
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new(
      iv_action = 'save_form'
      it_postdata = VALUE #( ( |field_a=| ) ) ) ).

    cl_abap_unit_assert=>assert_equals( exp  = 1 act  = ls_result-state ).
    DATA(ls_state) = lo_page->get_state( ).
    LOOP AT ls_state-sections ASSIGNING FIELD-SYMBOL(<ls_sec>)
         WHERE form_action = 'save_form'.
      READ TABLE <ls_sec>-form_fields WITH KEY name = 'field_a'
        INTO DATA(ls_field).
      cl_abap_unit_assert=>assert_not_initial( ls_field-error_text ).
    ENDLOOP.
  ENDMETHOD.

  METHOD required_pass_allows_handler.
    DATA(lo_page) = NEW lcl_test_state_page( ).
    lo_page->set_state( VALUE zif_ark_gui_state=>ty_page_state(
      sections = VALUE #(
        ( kind = zif_ark_gui_state=>c_section_kind-form
          form_action = 'save_form'
          form_fields = VALUE #(
            ( input_type = 'text' label = 'A' name = 'field_a'
              required = abap_true ) ) ) ) ) ).

    " 校验通过：约定路由接手；handler 未设 state 时框架置 1 重渲染
    " （回显回读后的 state，如 select 保存值/成功消息）
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new(
      iv_action = 'save_form'
      it_postdata = VALUE #( ( |field_a=x| ) ) ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 1 act  = ls_result-state ).
  ENDMETHOD.

  METHOD table_section_from_data.
    DATA lt_data TYPE tt_test_row.
    lt_data = VALUE #( ( code = `AA` amount = 12 )
                       ( code = `BB` amount = 340 ) ).

    DATA(ls_section) = zcl_ark_state_page=>table_section(
      iv_title = 'demo' it_data = lt_data ).

    cl_abap_unit_assert=>assert_equals(
      exp  = zif_ark_gui_state=>c_section_kind-table
      act  = ls_section-kind ).
    cl_abap_unit_assert=>assert_equals( exp  = 2 act  = lines( ls_section-columns ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 2 act  = lines( ls_section-rows ) ).
    " 数值列自动右对齐
    READ TABLE ls_section-columns INDEX 2 INTO DATA(ls_col).
    cl_abap_unit_assert=>assert_true( ls_col-align_right ).
  ENDMETHOD.

  METHOD chart_section_builds_option.
    DATA(ls_section) = zcl_ark_state_page=>chart_section(
      iv_title        = '月度销售额'
      iv_series_name  = '销售额'
      it_categories   = VALUE string_table( ( `1月` ) ( `2月` ) )
      it_data         = VALUE zcl_ark_echarts=>ty_values( ( 420 ) ( 455 ) )
      iv_click_action = 'chart_click' ).

    cl_abap_unit_assert=>assert_equals(
      exp  = zif_ark_gui_state=>c_section_kind-chart
      act  = ls_section-kind ).
    cl_abap_unit_assert=>assert_equals( exp  = '月度销售额' act  = ls_section-title ).
    cl_abap_unit_assert=>assert_equals( exp  = 'chart_click' act  = ls_section-chart_click_action ).
    " option JSON 含系列名/类型/类目，且不含卡片标题（避免画布内双标题）
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `销售额` ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `'bar'` ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `1月` ) ).
    cl_abap_unit_assert=>assert_false( boolc( ls_section-chart_option CS `月度销售额` ) ).
  ENDMETHOD.

  METHOD chart_section_multi_series.
    " 多系列形态：it_series 提供时忽略单系列便捷参数
    DATA lt_series TYPE zcl_ark_state_page=>tt_chart_series.
    APPEND VALUE #( name = '营收' type = 'bar'
                    values = VALUE #( ( `420` ) ( `455` ) ) ) TO lt_series.
    APPEND VALUE #( name = '成本'
                    type = 'line'
                    values = VALUE #( ( `300` ) ( `280.5` ) ) ) TO lt_series.

    DATA(ls_section) = zcl_ark_state_page=>chart_section(
      iv_title      = '营收 vs 成本'
      it_categories = VALUE string_table( ( `1月` ) ( `2月` ) )
      it_series     = lt_series ).

    cl_abap_unit_assert=>assert_equals(
      exp  = zif_ark_gui_state=>c_section_kind-chart
      act  = ls_section-kind ).
    " 两个系列名与各自类型都在 option JSON 中
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `营收` ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `成本` ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `'bar'` ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `'line'` ) ).
    " 小数系列值保留（zcl_ark_json 序列化为带引号数字字符串）
    cl_abap_unit_assert=>assert_true( boolc( ls_section-chart_option CS `"280.5"` ) ).
  ENDMETHOD.

  METHOD progress_clamps_and_escapes.
    " 进度条渲染：百分比截断 [0,100]、语义色修饰类、动态值转义
    DATA(lo_page) = NEW lcl_test_state_page( ).
    lo_page->set_state( VALUE zif_ark_gui_state=>ty_page_state(
      sections = VALUE #(
        ( kind = zif_ark_gui_state=>c_section_kind-progress
          title = 'Progress'
          progress_items = VALUE #(
            ( label = `<b>bad</b>`
              value_text = `620 / 730`
              percent = 150
              semantic = zif_ark_gui_state=>c_semantic-negative ) ) ) ) ) ).

    DATA(lv_html) = lo_page->render_html( ).
    " 150 截断为 100
    cl_abap_unit_assert=>assert_true( boolc( lv_html CS `width: 100%;` ) ).
    cl_abap_unit_assert=>assert_true(
      boolc( lv_html CS `ark-progress-fill--negative` ) ).
    " 标签是动态值：HTML 不落原样（escape_html 纪律）
    cl_abap_unit_assert=>assert_false( boolc( lv_html CS `<b>bad</b>` ) ).
    cl_abap_unit_assert=>assert_true( boolc( lv_html CS `620 / 730` ) ).
  ENDMETHOD.

ENDCLASS.
