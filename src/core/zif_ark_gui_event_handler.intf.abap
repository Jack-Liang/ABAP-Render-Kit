INTERFACE zif_ark_gui_event_handler PUBLIC .
  TYPES:
    "! keep_view = X: event fully handled, the page was updated in place
    "! (e.g. state pushed into a bridge frame); the framework must NOT
    "! re-render the main document. Without it the classic behavior applies
    "! (re-render after every handled event without a new page).
    BEGIN OF ty_handling_result, state TYPE i, keep_view TYPE abap_bool,
             page TYPE REF TO zif_ark_gui_renderable,
    END OF ty_handling_result .
  METHODS on_event IMPORTING !ii_event TYPE REF TO zif_ark_gui_event
                   RETURNING VALUE(rs_result) TYPE ty_handling_result
                   RAISING zcx_ark_exception .
ENDINTERFACE.
