CLASS zcl_ark_gui_event DEFINITION PUBLIC FINAL CREATE PUBLIC .
  PUBLIC SECTION.
    INTERFACES zif_ark_gui_event .
    CLASS-METHODS new IMPORTING !iv_action TYPE clike !iv_getdata TYPE clike OPTIONAL
                                !it_postdata TYPE zif_ark_html_viewer=>ty_post_data OPTIONAL
                      RETURNING VALUE(ri_event) TYPE REF TO zif_ark_gui_event .
    METHODS constructor IMPORTING !iv_action TYPE clike !iv_getdata TYPE clike OPTIONAL
                                  !it_postdata TYPE zif_ark_html_viewer=>ty_post_data OPTIONAL .
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mt_query TYPE zif_ark_html_viewer=>ty_query_table .
ENDCLASS.

CLASS zcl_ark_gui_event IMPLEMENTATION.
  METHOD constructor.
    zif_ark_gui_event~mv_action = iv_action.
    zif_ark_gui_event~mv_getdata = iv_getdata.
    zif_ark_gui_event~mt_postdata = it_postdata.
    IF iv_getdata IS NOT INITIAL.
      DATA lt_parts TYPE STANDARD TABLE OF string.
      DATA lv_part TYPE string.
      SPLIT iv_getdata AT '&' INTO TABLE lt_parts.
      LOOP AT lt_parts INTO lv_part.
        DATA lv_name TYPE c LENGTH 30.
        DATA lv_value TYPE c LENGTH 250.
        SPLIT lv_part AT '=' INTO lv_name lv_value.
        APPEND VALUE #( name = lv_name value = lv_value ) TO mt_query.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD new.
    CREATE OBJECT ri_event TYPE zcl_ark_gui_event
      EXPORTING iv_action = iv_action iv_getdata = iv_getdata it_postdata = it_postdata.
  ENDMETHOD.
  METHOD zif_ark_gui_event~query.
    FIELD-SYMBOLS <ls_query> LIKE LINE OF mt_query.
    READ TABLE mt_query ASSIGNING <ls_query> WITH KEY name = iv_key.
    IF sy-subrc = 0. rv_value = <ls_query>-value. ENDIF.
  ENDMETHOD.
ENDCLASS.
