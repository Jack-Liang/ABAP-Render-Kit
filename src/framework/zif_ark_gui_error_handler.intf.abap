INTERFACE zif_ark_gui_error_handler PUBLIC .

  METHODS handle_error
    IMPORTING !ix_error TYPE REF TO zcx_ark_exception
    RETURNING VALUE(rv_handled) TYPE abap_bool .

  METHODS get_last_error
    RETURNING VALUE(rx_error) TYPE REF TO zcx_ark_exception .

ENDINTERFACE.
