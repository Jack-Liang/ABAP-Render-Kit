CLASS zcl_ark_json DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    " 任意 ABAP 数据对象 -> JSON 字符串
    " 基于标准 sXML JSON writer + CALL TRANSFORMATION id，
    " 零外部依赖（不依赖 /ui2/cl_json），自动处理转义与 Unicode
    CLASS-METHODS to_json
      IMPORTING !ig_data       TYPE any
      RETURNING VALUE(rv_json) TYPE string .
ENDCLASS.


CLASS zcl_ark_json IMPLEMENTATION.

  METHOD to_json.
    DATA(lo_writer) = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).

    CALL TRANSFORMATION id
      SOURCE root = ig_data
      RESULT XML lo_writer.

    rv_json = zcl_ark_convert=>xstring_to_string_utf8( lo_writer->get_output( ) ).

    " id 转换会把根节点包成 {"ROOT":...} 外层对象，剥掉后得到纯值（数组/标量/结构）
    FIND FIRST OCCURRENCE OF REGEX `^\{"[A-Za-z_]+":(.*)\}$`
      IN rv_json SUBMATCHES DATA(lv_inner).
    IF sy-subrc = 0.
      rv_json = lv_inner.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
