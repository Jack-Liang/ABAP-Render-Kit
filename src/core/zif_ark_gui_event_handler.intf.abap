INTERFACE zif_ark_gui_event_handler PUBLIC .
  TYPES:
    BEGIN OF ty_handling_result, state TYPE i, page TYPE REF TO zif_ark_gui_renderable,
    END OF ty_handling_result .
  METHODS on_event IMPORTING !ii_event TYPE REF TO zif_ark_gui_event
                   RETURNING VALUE(rs_result) TYPE ty_handling_result
                   RAISING zcx_ark_exception .
ENDINTERFACE.
