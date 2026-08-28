INTERFACE zif_ark_gui_services PUBLIC .
  TYPES: ty_web_asset_url TYPE c LENGTH 250 .
  METHODS cache_asset IMPORTING !iv_text TYPE string OPTIONAL !iv_xdata TYPE xstring OPTIONAL
                                !iv_url TYPE string OPTIONAL !iv_type TYPE c DEFAULT 'text'
                                !iv_subtype TYPE c DEFAULT 'html'
                      RETURNING VALUE(rv_url) TYPE ty_web_asset_url RAISING zcx_ark_exception .
  METHODS get_current_page_name RETURNING VALUE(rv_page_name) TYPE string .
  METHODS register_event_handler IMPORTING !ii_event_handler TYPE REF TO zif_ark_gui_event_handler
                                 RAISING zcx_ark_exception .
  "! Load iv_text as a fresh text/html document and navigate the named frame
  "! to it. Response channel for resident pages (UI5 bridge): the frame's
  "! script hands the payload to the resident main page. No caching — every
  "! push is new content.
  METHODS push_to_frame IMPORTING !iv_frame TYPE string
                                  !iv_text  TYPE string
                         RAISING zcx_ark_exception .
  METHODS get_html_parts RETURNING VALUE(ro_parts) TYPE REF TO zcl_ark_html_parts .
ENDINTERFACE.
