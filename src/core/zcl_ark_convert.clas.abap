CLASS zcl_ark_convert DEFINITION PUBLIC FINAL CREATE PRIVATE .
  PUBLIC SECTION.
    CLASS-METHODS string_to_tab IMPORTING !iv_str TYPE string EXPORTING !ev_size TYPE i !et_tab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_bintab IMPORTING !iv_xstr TYPE xstring EXPORTING !ev_size TYPE i !et_bintab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_string_utf8 IMPORTING !iv_xstr TYPE xstring RETURNING VALUE(rv_str) TYPE string .
    CLASS-METHODS string_to_xstring IMPORTING !iv_str TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
    CLASS-METHODS base64_to_xstring IMPORTING !iv_base64 TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
    CLASS-METHODS mime_to_xstring IMPORTING !iv_name TYPE wwwdatatab-objid RETURNING VALUE(rv_xdata) TYPE xstring
                                  RAISING zcx_ark_exception .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ark_convert IMPLEMENTATION.
  METHOD base64_to_xstring.
    rv_xstr = cl_http_utility=>decode_x_base64( iv_base64 ).
  ENDMETHOD.
  METHOD mime_to_xstring.
    DATA lt_mime TYPE STANDARD TABLE OF w3mime.
    DATA lt_params TYPE STANDARD TABLE OF wwwparams.
    DATA lv_size TYPE i.
    FIELD-SYMBOLS <ls_mime> TYPE w3mime.
    FIELD-SYMBOLS <ls_param> TYPE wwwparams.

    " w3mime 行定长 255 字节且末行带填充，必须按 filesize 参数精确截取，
    " 否则文本资产（如 JS）尾部会带 NUL 字节导致解析失败
    CALL FUNCTION 'WWWPARAMS_READ_ALL'
      EXPORTING
        type             = 'MI'
        objid            = iv_name
      TABLES
        params           = lt_params
      EXCEPTIONS
        entry_not_exists = 1
        OTHERS           = 2.

    IF sy-subrc = 0.
      READ TABLE lt_params ASSIGNING <ls_param> WITH KEY name = 'filesize'.
      IF sy-subrc = 0.
        lv_size = <ls_param>-value.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'WWWDATA_IMPORT'
      EXPORTING
        key               = VALUE wwwdatatab( relid = 'MI' objid = iv_name )
      TABLES
        mime              = lt_mime
      EXCEPTIONS
        wrong_objecttype  = 1
        import_error      = 2
        OTHERS            = 3.

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( |MIME object { iv_name } not found| ).
    ENDIF.

    IF lv_size > 0.
      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          input_length = lv_size
        IMPORTING
          buffer       = rv_xdata
        TABLES
          binary_tab   = lt_mime
        EXCEPTIONS
          failed       = 1
          OTHERS       = 2.
      IF sy-subrc <> 0.
        zcx_ark_exception=>raise( |MIME object { iv_name } conversion failed| ).
      ENDIF.
    ELSE.
      " 无 filesize 参数时回退为整行拼接（末行可能含填充字节）
      LOOP AT lt_mime ASSIGNING <ls_mime>.
        rv_xdata = rv_xdata && <ls_mime>-line.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD string_to_tab.
    DATA lv_char200 TYPE c LENGTH 200.
    DATA lv_offset TYPE i.
    DATA lv_len TYPE i.
    ev_size = strlen( iv_str ).
    lv_offset = 0.
    WHILE lv_offset < ev_size.
      lv_len = ev_size - lv_offset.
      IF lv_len > 200.
        lv_len = 200.
      ENDIF.
      lv_char200 = iv_str+lv_offset(lv_len).
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
    DATA lv_len TYPE i.
    ev_size = xstrlen( iv_xstr ).
    lv_offset = 0.
    WHILE lv_offset < ev_size.
      lv_len = ev_size - lv_offset.
      IF lv_len > 200.
        lv_len = 200.
      ENDIF.
      lv_hex200 = iv_xstr+lv_offset(lv_len).
      APPEND lv_hex200 TO et_bintab.
      lv_offset = lv_offset + 200.
    ENDWHILE.
  ENDMETHOD.
  METHOD xstring_to_string_utf8.
    rv_str = cl_abap_codepage=>convert_from( source = iv_xstr codepage = 'UTF-8' ).
  ENDMETHOD.
ENDCLASS.
