CLASS zcl_ark_convert DEFINITION PUBLIC FINAL CREATE PRIVATE .
  PUBLIC SECTION.
    CLASS-METHODS string_to_tab IMPORTING !iv_str TYPE string EXPORTING !ev_size TYPE i !et_tab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_bintab IMPORTING !iv_xstr TYPE xstring EXPORTING !ev_size TYPE i !et_bintab TYPE STANDARD TABLE .
    CLASS-METHODS xstring_to_string_utf8 IMPORTING !iv_xstr TYPE xstring RETURNING VALUE(rv_str) TYPE string .
    CLASS-METHODS string_to_xstring IMPORTING !iv_str TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
    CLASS-METHODS base64_to_xstring IMPORTING !iv_base64 TYPE string RETURNING VALUE(rv_xstr) TYPE xstring .
    CLASS-METHODS mime_to_xstring IMPORTING !iv_name TYPE wwwdatatab-objid RETURNING VALUE(rv_xdata) TYPE xstring
                                  RAISING zcx_ark_exception .
    CLASS-METHODS url_decode IMPORTING !iv_encoded TYPE string
                             RETURNING VALUE(rv_decoded) TYPE string .
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
      " 仅接受数字值，非数字内容跳过并走整行拼接回退（避免 char->i 隐式转换 dump）
      IF sy-subrc = 0 AND <ls_param>-value CO '0123456789 '.
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
  METHOD url_decode.
    " sapevent GET/POST 参数值的简易 URL 解码（+ -> 空格、%XX -> UTF-8 字符）。
    " 非法 % 序列按普通字符处理，整体解码失败保留原样。
    " %XX 路径：两位十六进制经 CO 校验后用 c->x 标准转换取字节 ——
    " 原 CONV xstring( |X..| ) 写法的 X 前缀并非十六进制字符，
    " 运行期必然抛异常走 CATCH，%XX 会被当作普通文本（中文解码出乱码）
    rv_decoded = iv_encoded.
    rv_decoded = replace( val = rv_decoded sub = `+` with = ` ` occ = 0 ).

    DATA lv_x TYPE xstring.
    DATA lv_two TYPE string.
    DATA lv_hexbyte TYPE x LENGTH 1.
    DATA lv_pos TYPE i VALUE 0.
    DATA lv_len TYPE i.
    lv_len = strlen( rv_decoded ).

    WHILE lv_pos < lv_len.
      IF substring( val = rv_decoded off = lv_pos len = 1 ) = '%'
         AND lv_pos + 2 < lv_len.
        lv_two = to_upper( substring( val = rv_decoded off = lv_pos + 1 len = 2 ) ).
        IF lv_two CO `0123456789ABCDEF`.
          lv_hexbyte = lv_two.
          CONCATENATE lv_x lv_hexbyte INTO lv_x IN BYTE MODE.
          lv_pos = lv_pos + 3.
          CONTINUE.
        ENDIF.
      ENDIF.
      DATA(lv_byte) = cl_abap_codepage=>convert_to( substring( val = rv_decoded off = lv_pos len = 1 ) ).
      CONCATENATE lv_x lv_byte INTO lv_x IN BYTE MODE.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_x IS NOT INITIAL.
      TRY.
          rv_decoded = cl_abap_codepage=>convert_from( lv_x ).
        CATCH cx_root.
          " 解码失败保留原样
      ENDTRY.
    ENDIF.
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
