CLASS ltcl_html DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS a_sapevent FOR TESTING.
    METHODS a_sapevent_query FOR TESTING.
    METHODS a_url_target_blank FOR TESTING.
    METHODS a_onclick FOR TESTING.
    METHODS div_with_data_attr FOR TESTING.
    METHODS nested_render FOR TESTING.
    METHODS add_css_js FOR TESTING.
    METHODS is_empty FOR TESTING.
ENDCLASS.

CLASS ltcl_html IMPLEMENTATION.

  METHOD a_sapevent.
    cl_abap_unit_assert=>assert_equals(
      exp  = `<a href="sapevent:CLICK">x</a>`
      act  = zcl_ark_html=>create( )->a( iv_txt = `x`
                                         iv_act = `CLICK`
                                         iv_typ = zif_ark_html=>c_action_type-sapevent ) ).
  ENDMETHOD.

  METHOD a_sapevent_query.
    cl_abap_unit_assert=>assert_equals(
      exp  = `<a href="sapevent:CLICK?a=1">x</a>`
      act  = zcl_ark_html=>create( )->a( iv_txt   = `x`
                                         iv_act   = `CLICK`
                                         iv_query = `a=1`
                                         iv_typ   = zif_ark_html=>c_action_type-sapevent ) ).
  ENDMETHOD.

  METHOD a_url_target_blank.
    cl_abap_unit_assert=>assert_equals(
      exp  = `<a href="https://a.b" target="_blank">x</a>`
      act  = zcl_ark_html=>create( )->a( iv_txt = `x`
                                         iv_act = `https://a.b`
                                         iv_typ = zif_ark_html=>c_action_type-url ) ).
  ENDMETHOD.

  METHOD a_onclick.
    cl_abap_unit_assert=>assert_equals(
      exp  = `<a onclick="doIt()" href="#">x</a>`
      act  = zcl_ark_html=>create( )->a( iv_txt = `x`
                                         iv_act = `doIt()`
                                         iv_typ = zif_ark_html=>c_action_type-onclick ) ).
  ENDMETHOD.

  METHOD div_with_data_attr.
    DATA(lo_html) = zcl_ark_html=>create( ).
    lo_html->div( iv_id         = `d`
                  iv_content    = `hi`
                  is_data_attr  = VALUE #( name = `foo` value = `1` ) ).
    DATA(lv_html) = lo_html->render( ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `<div id="d" data-foo="1">` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `</div>` ) ).
  ENDMETHOD.

  METHOD nested_render.
    DATA(lo_inner) = zcl_ark_html=>create( ).
    lo_inner->add( `inner` ).
    DATA(lo_outer) = zcl_ark_html=>create( ).
    lo_outer->div( ii_content = lo_inner ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_outer->render( ) CS `inner` ) ).
  ENDMETHOD.

  METHOD add_css_js.
    DATA(lo_html) = zcl_ark_html=>create( ).
    lo_html->add_css( `body{}` )->add_js( `var x;` ).
    DATA(lv_html) = lo_html->render( ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `<style type="text/css">body{}</style>` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `<script type="text/javascript">var x;</script>` ) ).
  ENDMETHOD.

  METHOD is_empty.
    DATA(lo_html) = zcl_ark_html=>create( ).
    cl_abap_unit_assert=>assert_true( lo_html->is_empty( ) ).
    lo_html->add( `x` ).
    cl_abap_unit_assert=>assert_false( lo_html->is_empty( ) ).
  ENDMETHOD.

ENDCLASS.
