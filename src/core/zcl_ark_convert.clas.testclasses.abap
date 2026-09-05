CLASS ltcl_convert DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS escape_html_basic FOR TESTING.
    METHODS escape_js_specials FOR TESTING.
    METHODS string_xstring_roundtrip FOR TESTING.
    METHODS url_decode_basic FOR TESTING.
    METHODS url_decode_utf8 FOR TESTING.
    METHODS url_decode_invalid_seq FOR TESTING.
ENDCLASS.

CLASS ltcl_convert IMPLEMENTATION.

  METHOD escape_html_basic.
    cl_abap_unit_assert=>assert_equals(
      exp  = `&lt;b&gt; &amp; &quot;ok&quot; &#39;`
      act  = zcl_ark_convert=>escape_html( `<b> & "ok" '`) ).
  ENDMETHOD.

  METHOD escape_js_specials.
    " 反斜杠先行、单双引号、CRLF 折叠为 \n、</script> 防截断
    DATA(lv_cr_lf) = cl_abap_char_utilities=>cr_lf.
    cl_abap_unit_assert=>assert_equals(
      exp  = `a\'b\"c\\d\n</e>`
      act  = zcl_ark_convert=>escape_js( |a'b"c\\d{ lv_cr_lf }</e>| ) ).
  ENDMETHOD.

  METHOD string_xstring_roundtrip.
    DATA(lv_xstr) = zcl_ark_convert=>string_to_xstring( `中文abc` ).
    cl_abap_unit_assert=>assert_equals(
      exp  = 9
      act  = xstrlen( lv_xstr ) ).
    cl_abap_unit_assert=>assert_equals(
      exp  = `中文abc`
      act  = zcl_ark_convert=>xstring_to_string_utf8( lv_xstr ) ).
  ENDMETHOD.

  METHOD url_decode_basic.
    cl_abap_unit_assert=>assert_equals(
      exp  = `a b c`
      act  = zcl_ark_convert=>url_decode( `a+b%20c` ) ).
  ENDMETHOD.

  METHOD url_decode_utf8.
    cl_abap_unit_assert=>assert_equals(
      exp  = `中国`
      act  = zcl_ark_convert=>url_decode( `%E4%B8%AD%E5%9B%BD` ) ).
  ENDMETHOD.

  METHOD url_decode_invalid_seq.
    " 非法 % 序列按普通字符保留
    cl_abap_unit_assert=>assert_equals(
      exp  = `100%`
      act  = zcl_ark_convert=>url_decode( `100%` ) ).
  ENDMETHOD.

ENDCLASS.
