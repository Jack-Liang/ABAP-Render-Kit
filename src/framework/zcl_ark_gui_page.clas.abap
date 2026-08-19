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
      rs_result-state = 0.
    ENDIF.
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
