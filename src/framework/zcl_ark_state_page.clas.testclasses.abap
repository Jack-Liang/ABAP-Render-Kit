" 测试桥：公开受保护的 ms_state 读取（仅测试用）
CLASS lcl_test_state_page DEFINITION FINAL CREATE PUBLIC
  INHERITING FROM zcl_ark_state_page.
  PUBLIC SECTION.
    METHODS get_state
      RETURNING VALUE(rs_state) TYPE zif_ark_gui_state=>ty_page_state .
ENDCLASS.

CLASS lcl_test_state_page IMPLEMENTATION.
  METHOD get_state.
    rs_state = ms_state.
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
    LOOP AT ls_state-sections ASSIGNING FIELD-SYMBOL(<ls_sec>)
         WHERE form_action = 'save_form'.
      READ TABLE <ls_sec>-form_fields WITH KEY name = 'field_a'
        INTO DATA(ls_field).
      lv_a = ls_field-value.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp  = `hello` act  = lv_a ).
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

    " 校验通过：约定路由接手（测试页无 on_action_save_form → 未处理 → 0）
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new(
      iv_action = 'save_form'
      it_postdata = VALUE #( ( |field_a=x| ) ) ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = ls_result-state ).
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

ENDCLASS.
