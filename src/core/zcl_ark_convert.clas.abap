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
    CLASS-METHODS escape_html IMPORTING !iv_text TYPE string
                             RETURNING VALUE(rv_text) TYPE string .
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
      " 无 filesize 参数时回退：一次性批量转换（逐行 && 对 1MB 资产是 O(n²)）
      DATA lv_total TYPE i.
      lv_total = lines( lt_mime ) * 255.
      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          input_length = lv_total
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
      " 末行填充字节（NUL）截掉；本回退路径面向文本资产，二进制资产
      " 必须带 filesize 参数才能保证精确
      WHILE rv_xdata IS NOT INITIAL.
        DATA lv_last TYPE i.
        lv_last = xstrlen( rv_xdata ) - 1.
        IF rv_xdata+lv_last(1) <> '00'.
          EXIT.
        ENDIF.
        IF lv_last = 0.
          CLEAR rv_xdata.
        ELSE.
          rv_xdata = rv_xdata(lv_last).
        ENDIF.
      ENDWHILE.
    ENDIF.
  ENDMETHOD.
  METHOD string_to_tab.
    DATA lv_char200 TYPE c LENGTH 200.
    DATA lv_offset TYPE i.
    DATA lv_len TYPE i.
    " ev_size 必须是字节数（load_data 的 iv_size 语义）：中文字符 UTF-8 下
    " 一字多字节，strlen（字符数）会导致 HTML 尾部被截断。
    " 切分循环仍按字符偏移走（char200 片段），与字节数互不相干
    DATA lv_strlen TYPE i.
    ev_size = xstrlen( string_to_xstring( iv_str ) ).
    lv_strlen = strlen( iv_str ).
    lv_offset = 0.
    WHILE lv_offset < lv_strlen.
      lv_len = lv_strlen - lv_offset.
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
    " 快速路径：不含 %XX 序列时无需逐字节重组（逐字符 convert_to 开销大）
    IF rv_decoded NA `%`.
      RETURN.
    ENDIF.

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
  METHOD escape_html.
    " HTML 文本/属性值通用转义：& 必须最先替换，否则前面引入的实体会被二次转义
    rv_text = iv_text.
    rv_text = replace( val = rv_text sub = `&` with = `&amp;` occ = 0 ).
    rv_text = replace( val = rv_text sub = `<` with = `&lt;` occ = 0 ).
    rv_text = replace( val = rv_text sub = `>` with = `&gt;` occ = 0 ).
    rv_text = replace( val = rv_text sub = `"` with = `&quot;` occ = 0 ).
    rv_text = replace( val = rv_text sub = `'` with = `&#39;` occ = 0 ).
  ENDMETHOD.
ENDCLASS.
