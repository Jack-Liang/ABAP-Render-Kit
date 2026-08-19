CLASS zcl_ark_gui_utils DEFINITION PUBLIC FINAL CREATE PRIVATE .
  PUBLIC SECTION.
    CLASS-METHODS is_renderable IMPORTING !io_object TYPE REF TO object RETURNING VALUE(rv_yes) TYPE abap_bool .
    CLASS-METHODS is_event_handler IMPORTING !io_object TYPE REF TO object RETURNING VALUE(rv_yes) TYPE abap_bool .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ark_gui_utils IMPLEMENTATION.
  METHOD is_event_handler.
    DATA li_handler TYPE REF TO zif_ark_gui_event_handler.
    TRY. li_handler ?= io_object. rv_yes = abap_true. CATCH cx_sy_move_cast_error. rv_yes = abap_false. ENDTRY.
  ENDMETHOD.
  METHOD is_renderable.
    DATA li_renderable TYPE REF TO zif_ark_gui_renderable.
    TRY. li_renderable ?= io_object. rv_yes = abap_true. CATCH cx_sy_move_cast_error. rv_yes = abap_false. ENDTRY.
  ENDMETHOD.
ENDCLASS.
