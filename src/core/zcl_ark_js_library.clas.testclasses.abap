CLASS lcl_test_widget IMPLEMENTATION.
  METHOD set_assets.
    mv_assets = it_assets.
  ENDMETHOD.
  METHOD zif_ark_js_widget~get_assets.
    rt_assets = mv_assets.
  ENDMETHOD.
  METHOD zif_ark_gui_renderable~render.
    ri_html = zcl_ark_html=>create( ).
    ri_html->add( `widget` ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_js_library DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS setup.
    METHODS register_requires_name FOR TESTING.
    METHODS register_requires_source FOR TESTING.
    METHODS include_inline_dedup_reset FOR TESTING.
    METHODS include_unknown_returns_empty FOR TESTING.
    METHODS include_for_widget FOR TESTING.
    METHODS get_url_unregistered_raises FOR TESTING.
    METHODS is_registered FOR TESTING.
ENDCLASS.

CLASS ltcl_js_library IMPLEMENTATION.

  METHOD setup.
    " 页面作用域去重是类级状态，测试间必须隔离
    zcl_ark_js_library=>reset_page_scope( ).
  ENDMETHOD.

  METHOD register_requires_name.
    TRY.
        zcl_ark_js_library=>register( iv_name   = ``
                                      iv_inline = `x` ).
        cl_abap_unit_assert=>fail( 'empty name should raise' ).
      CATCH zcx_ark_exception.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD register_requires_source.
    TRY.
        zcl_ark_js_library=>register( iv_name = `t_no_src` ).
        cl_abap_unit_assert=>fail( 'no source should raise' ).
      CATCH zcx_ark_exception.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD include_inline_dedup_reset.
    zcl_ark_js_library=>register( iv_name   = `t_inline_a`
                                  iv_inline = `window.t_a = 1;` ).
    cl_abap_unit_assert=>assert_equals(
      exp  = `<script type="text/javascript">window.t_a = 1;</script>`
      act  = zcl_ark_js_library=>include( iv_name = `t_inline_a` ) ).
    " 同页幂等
    cl_abap_unit_assert=>assert_initial( zcl_ark_js_library=>include( iv_name = `t_inline_a` ) ).
    " 重置后重新注入
    zcl_ark_js_library=>reset_page_scope( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_ark_js_library=>include( iv_name = `t_inline_a` ) ).
  ENDMETHOD.

  METHOD include_unknown_returns_empty.
    cl_abap_unit_assert=>assert_initial( zcl_ark_js_library=>include( iv_name = `t_never_registered` ) ).
  ENDMETHOD.

  METHOD include_for_widget.
    zcl_ark_js_library=>register( iv_name   = `t_inline_b`
                                  iv_inline = `window.t_b = 2;` ).
    DATA(lo_widget) = NEW lcl_test_widget( ).
    lo_widget->set_assets( VALUE #( ( `t_inline_b` ) ( `t_never_registered` ) ) ).
    DATA(lv_html) = zcl_ark_js_library=>include_for( lo_widget ).
    " 已注册的注入，未注册的跳过且不报错
    cl_abap_unit_assert=>assert_true( xsdbool( lv_html CS `window.t_b = 2;` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp  = 1
      act  = count( val = lv_html sub = `<script` ) ).
  ENDMETHOD.

  METHOD get_url_unregistered_raises.
    TRY.
        zcl_ark_js_library=>get_url( `t_never_registered` ).
        cl_abap_unit_assert=>fail( 'unregistered name should raise' ).
      CATCH zcx_ark_exception.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD is_registered.
    zcl_ark_js_library=>register( iv_name   = `t_inline_c`
                                  iv_inline = `x` ).
    cl_abap_unit_assert=>assert_true( zcl_ark_js_library=>is_registered( `t_inline_c` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ark_js_library=>is_registered( `t_never_registered` ) ).
  ENDMETHOD.

ENDCLASS.
