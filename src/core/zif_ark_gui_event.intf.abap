INTERFACE zif_ark_gui_event PUBLIC .
  DATA mv_action TYPE string READ-ONLY .
  DATA mv_getdata TYPE string READ-ONLY .
  DATA mt_postdata TYPE zif_ark_html_viewer=>ty_post_data READ-ONLY .
  METHODS query IMPORTING !iv_key TYPE string RETURNING VALUE(rv_value) TYPE string .
ENDINTERFACE.
