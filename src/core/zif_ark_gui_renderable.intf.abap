INTERFACE zif_ark_gui_renderable PUBLIC .
  METHODS render RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html RAISING zcx_ark_exception.
ENDINTERFACE.
