INTERFACE zif_ark_gui_modal PUBLIC .

  METHODS show
    IMPORTING !iv_title TYPE string OPTIONAL
              !iv_width TYPE i DEFAULT 400
              !iv_height TYPE i DEFAULT 300
    RAISING zcx_ark_exception .

  METHODS close .

  METHODS set_content
    IMPORTING !ii_content TYPE REF TO zif_ark_gui_renderable .

  METHODS is_visible RETURNING VALUE(rv_visible) TYPE abap_bool .

ENDINTERFACE.
