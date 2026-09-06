" 测试用页面：约定式路由验证（动作 -> on_action_<动作名> 动态分发）
CLASS lcl_route_page DEFINITION FINAL CREATE PUBLIC
  INHERITING FROM zcl_ark_gui_page.
  PUBLIC SECTION.
    METHODS on_action_ping
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    METHODS on_action_dash_me
      IMPORTING ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .
    DATA mv_hit TYPE string .
ENDCLASS.

CLASS lcl_route_page IMPLEMENTATION.
  METHOD on_action_ping.
    mv_hit = 'ping'.
    rs_result-state = 1.
  ENDMETHOD.
  METHOD on_action_dash_me.
    " 动作 'dash-me' 合法化为 dash_me（接口约定：非法字符转下划线）
    mv_hit = 'dash_me'.
    rs_result-state = 1.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_convention_routing DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS hit_for_no_arg FOR TESTING.
    METHODS dash_normalized FOR TESTING.
    METHODS unknown_action_unhandled FOR TESTING.
    METHODS overlong_action_unhandled FOR TESTING.
    METHODS empty_action_unhandled FOR TESTING.
ENDCLASS.

CLASS ltcl_convention_routing IMPLEMENTATION.

  METHOD hit_for_no_arg.
    DATA(lo_page) = NEW lcl_route_page( ).
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new( iv_action = 'ping' ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 'ping' act  = lo_page->mv_hit ).
    cl_abap_unit_assert=>assert_equals( exp  = 1 act  = ls_result-state ).
  ENDMETHOD.

  METHOD dash_normalized.
    DATA(lo_page) = NEW lcl_route_page( ).
    lo_page->on_event( zcl_ark_gui_event=>new( iv_action = 'dash-me' ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 'dash_me' act  = lo_page->mv_hit ).
  ENDMETHOD.

  METHOD unknown_action_unhandled.
    DATA(lo_page) = NEW lcl_route_page( ).
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new( iv_action = 'no_such' ) ).
    cl_abap_unit_assert=>assert_initial( lo_page->mv_hit ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = ls_result-state ).
  ENDMETHOD.

  METHOD overlong_action_unhandled.
    " 动作名合法化后超 20 字符不参与约定路由（方法名 ≤30 硬限制）
    DATA(lo_page) = NEW lcl_route_page( ).
    DATA(ls_result) = lo_page->on_event(
      zcl_ark_gui_event=>new( iv_action = 'a2345678901234567890123456789012345' ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = ls_result-state ).
  ENDMETHOD.

  METHOD empty_action_unhandled.
    DATA(lo_page) = NEW lcl_route_page( ).
    DATA(ls_result) = lo_page->on_event( zcl_ark_gui_event=>new( iv_action = '' ) ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = ls_result-state ).
  ENDMETHOD.

ENDCLASS.
