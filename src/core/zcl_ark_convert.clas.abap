CLASS zcl_ark_convert DEFINITION PUBLIC FINAL CREATE PRIVATE .
  PUBLIC SECTION.
    CLASS-METHODS string_to_tab IMPORTING !iv_str TYPE string EXPORTING !ev_size TYPE i !et_tab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_bintab IMPORTING !iv_xstr TYPE xstring EXPORTING !ev_size TYPE i !et_bintab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_string_utf8 IMPORTING !iv_xstr TYPE xstring RETURNING VALUE(rv_str) TYPE string .
    CLASS-METHODS string_to_xstring IMPORTING !iv_str TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
    CLASS-METHODS base64_to_xstring IMPORTING !iv_base64 TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ark_convert IMPLEMENTATION.
  METHOD base64_to_xstring.
    rv_xstr = cl_http_utility=>decode_x_base64( iv_base64 ).
  ENDMETHOD.
  METHOD string_to_tab.
    DATA lv_char200 TYPE c LENGTH 200.
    DATA lv_offset TYPE i.
    ev_size = strlen( iv_str ).
    lv_offset = 0.
    WHILE lv_offset < ev_size.
      lv_char200 = iv_str+lv_offset(200).
      APPEND lv_char200 TO et_tab.
      lv_offset = lv_offset + 200.
    ENDWHILE.
  ENDMETHOD.
  METHOD string_to_xstring.
    rv_xstr = cl_abap_codepage=>convert_to( source = iv_str codepage = 'UTF-8' ).
  ENDMETHOD.
  METHOD xstring_to_bintab.
    DATA lv_hex200 TYPE x LENGTH 200.
    DATA lv_offset TYPE i.
    ev_size = xstrlen( iv_xstr ).
    lv_offset = 0.
    WHILE lv_offset < ev_size.
      lv_hex200 = iv_xstr+lv_offset(200).
      APPEND lv_hex200 TO et_bintab.
      lv_offset = lv_offset + 200.
    ENDWHILE.
  ENDMETHOD.
  METHOD xstring_to_string_utf8.
    rv_str = cl_abap_codepage=>convert_from( source = iv_xstr codepage = 'UTF-8' ).
  ENDMETHOD.
ENDCLASS.
