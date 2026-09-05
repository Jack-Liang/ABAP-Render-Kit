CLASS ltcl_js_bridge DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS setup.
    METHODS script_contains_arkemit FOR TESTING.
    METHODS script_page_scope_dedup FOR TESTING.
    METHODS emit_js_simple FOR TESTING.
    METHODS emit_js_with_params FOR TESTING.
ENDCLASS.

CLASS ltcl_js_bridge IMPLEMENTATION.

  METHOD setup.
    " 桥的去重是类级状态，测试间必须隔离
    zcl_ark_js_bridge=>reset_page_scope( ).
  ENDMETHOD.

  METHOD script_contains_arkemit.
    DATA(lv_html) = zcl_ark_js_bridge=>script( ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `window.arkEmit` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `SAPEVENT:` ) ).
  ENDMETHOD.

  METHOD script_page_scope_dedup.
    cl_abap_unit_assert=>assert_not_initial( zcl_ark_js_bridge=>script( ) ).
    " 同页第二次调用不重复注入
    cl_abap_unit_assert=>assert_initial( zcl_ark_js_bridge=>script( ) ).
    " 重置后重新注入
    zcl_ark_js_bridge=>reset_page_scope( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_ark_js_bridge=>script( ) ).
  ENDMETHOD.

  METHOD emit_js_simple.
    cl_abap_unit_assert=>assert_equals(
      exp  = `arkEmit('REFRESH')`
      act  = zcl_ark_js_bridge=>emit_js( iv_action = `REFRESH` ) ).
  ENDMETHOD.

  METHOD emit_js_with_params.
    " 动态值经 escape_js 转义后进入参数体
    cl_abap_unit_assert=>assert_equals(
      exp  = |arkEmit('CLICK', \{ name: 'a\\'b', idx: 3 \})|
      act  = zcl_ark_js_bridge=>emit_js( iv_action    = `CLICK`
                                         iv_params_js = |name: '{ zcl_ark_convert=>escape_js( `a'b` ) }', idx: 3| ) ).
  ENDMETHOD.

ENDCLASS.
