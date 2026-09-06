CLASS zcl_ark_gui_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_component
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS get_title RETURNING VALUE(rv_title) TYPE string .
    METHODS set_title IMPORTING !iv_title TYPE string .

    METHODS on_event
      IMPORTING !ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING zcx_ark_exception .

    METHODS register_handler
      IMPORTING !ii_handler TYPE REF TO zif_ark_gui_event_handler .

  PROTECTED SECTION.
    DATA mv_title TYPE string .
    DATA mt_handlers TYPE STANDARD TABLE OF REF TO zif_ark_gui_event_handler .
    DATA mo_gui_services TYPE REF TO zif_ark_gui_services .

    METHODS get_services RETURNING VALUE(ri_services) TYPE REF TO zif_ark_gui_services .

    METHODS raise_event
      IMPORTING !iv_action TYPE string
                !iv_getdata TYPE string OPTIONAL
      RAISING zcx_ark_exception .

    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    "! 约定式路由：action 'foo' -> 方法 on_action_foo。
    "! 方法签名约定：IMPORTING ii_event TYPE REF TO zif_ark_gui_event
    "!               RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
    "! 注意：动作名经合法化（非法字符转 _）后拼接，方法名全长 ≤30 字符，
    "! 即动作名建议 ≤20 字符；超长动作请在子类重写 on_event 处理
    METHODS dispatch_convention
      IMPORTING
        !ii_event     TYPE REF TO zif_ark_gui_event
      CHANGING
        !cs_result    TYPE zif_ark_gui_event_handler=>ty_handling_result
      RETURNING
        VALUE(rv_hit) TYPE abap_bool
      RAISING
        zcx_ark_exception .
ENDCLASS.

CLASS zcl_ark_gui_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_gui_services = zcl_ark_gui=>get_instance( ).
  ENDMETHOD.

  METHOD build_html.
    ri_html = mo_html.
  ENDMETHOD.

  METHOD get_services.
    IF mo_gui_services IS INITIAL.
      mo_gui_services = zcl_ark_gui=>get_instance( ).
    ENDIF.
    ri_services = mo_gui_services.
  ENDMETHOD.

  METHOD get_title.
    rv_title = mv_title.
  ENDMETHOD.

  METHOD on_event.
    DATA lv_handled TYPE abap_bool VALUE abap_false.

    LOOP AT mt_handlers INTO DATA(li_handler).
      TRY.
          rs_result = li_handler->on_event( ii_event ).
          IF rs_result-state IS NOT INITIAL.
            lv_handled = abap_true.
            EXIT.
          ENDIF.
        CATCH zcx_ark_exception.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    IF lv_handled = abap_false.
      " 约定式路由：未注册 handler 处理的动作，尝试 on_action_<action>
      " （子类不必写 CASE —— 动作名即方法名后缀，返回结果语义与 on_event 相同）
      lv_handled = dispatch_convention(
        EXPORTING ii_event = ii_event
        CHANGING  cs_result = rs_result ).
    ENDIF.

    IF lv_handled = abap_false.
      rs_result-state = 0.
    ENDIF.
  ENDMETHOD.

  METHOD dispatch_convention.
    IF ii_event->mv_action IS INITIAL.
      RETURN.
    ENDIF.

    " 动作名合法化：ABAP 方法名只允许 A-Z0-9_，其余字符转下划线
    DATA(lv_method) = ii_event->mv_action.
    lv_method = replace( val = lv_method sub = `-` with = `_` occ = 0 ).
    TRANSLATE lv_method TO UPPER CASE.
    " 方法名全长 ≤30 字符（ON_ACTION_ 占 10），超长动作不参与约定路由
    IF strlen( lv_method ) > 20.
      RETURN.
    ENDIF.
    lv_method = |ON_ACTION_{ lv_method }|.

    " 反射确认方法存在：不存在即交给上层（返回未处理），不抛异常
    DATA(lo_descr) = CAST cl_abap_objectdescr(
                       cl_abap_objectdescr=>describe_by_object_ref( me ) ).
    READ TABLE lo_descr->methods TRANSPORTING NO FIELDS WITH KEY name = lv_method.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL METHOD me->(lv_method)
      EXPORTING
        ii_event  = ii_event
      RECEIVING
        rs_result = cs_result.
    rv_hit = abap_true.
  ENDMETHOD.

  METHOD raise_event.
    IF mo_gui_services IS INITIAL.
      RETURN.
    ENDIF.

    DATA(li_event) = zcl_ark_gui_event=>new(
      iv_action  = iv_action
      iv_getdata = iv_getdata ).

    DATA(ls_result) = on_event( li_event ).

    IF ls_result-page IS NOT INITIAL AND mo_gui_services IS NOT INITIAL.
      DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
      IF lo_gui IS NOT INITIAL.
        lo_gui->set_page( ls_result-page ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD register_handler.
    IF ii_handler IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE mt_handlers TRANSPORTING NO FIELDS
      WITH KEY table_line = ii_handler.
    IF sy-subrc <> 0.
      APPEND ii_handler TO mt_handlers.
    ENDIF.
  ENDMETHOD.

  METHOD set_title.
    mv_title = iv_title.
  ENDMETHOD.

ENDCLASS.
