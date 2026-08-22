CLASS zcl_ark_template DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 以字符串创建模板，占位符语法：{{NAME}}
    CLASS-METHODS create
      IMPORTING !iv_template     TYPE string
      RETURNING VALUE(ro_tpl)    TYPE REF TO zcl_ark_template .

    " 从 SMW0 MIME 仓库加载文本模板（如 HTML/JS 骨架文件）
    CLASS-METHODS from_mime
      IMPORTING !iv_name         TYPE wwwdatatab-objid
      RETURNING VALUE(ro_tpl)    TYPE REF TO zcl_ark_template
      RAISING   zcx_ark_exception .

    " 登记占位符取值：{{NAME}} <- iv_value（同名多次 set 时后值覆盖前值）
    METHODS set
      IMPORTING !iv_name        TYPE string
                !iv_value       TYPE string
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_template .

    " 渲染：单遍替换所有已登记占位符后返回文本。
    " 值中即使恰好含有 {{XXX}} 也不会被再次替换。
    " 未填充的占位符原样保留，便于发现遗漏
    METHODS render
      RETURNING VALUE(rv_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_value,
        name  TYPE string,
        value TYPE string,
      END OF ty_value .

    DATA mv_template TYPE string .
    DATA mt_values TYPE STANDARD TABLE OF ty_value WITH DEFAULT KEY .
ENDCLASS.


CLASS zcl_ark_template IMPLEMENTATION.

  METHOD create.
    CREATE OBJECT ro_tpl.
    ro_tpl->mv_template = iv_template.
  ENDMETHOD.

  METHOD from_mime.
    DATA(lv_xdata) = zcl_ark_convert=>mime_to_xstring( iv_name ).
    ro_tpl = create( zcl_ark_convert=>xstring_to_string_utf8( lv_xdata ) ).
  ENDMETHOD.

  METHOD set.
    READ TABLE mt_values ASSIGNING FIELD-SYMBOL(<ls_value>) WITH KEY name = iv_name.
    IF sy-subrc = 0.
      <ls_value>-value = iv_value.
    ELSE.
      APPEND VALUE ty_value( name = iv_name value = iv_value ) TO mt_values.
    ENDIF.

    ro_self = me.
  ENDMETHOD.

  METHOD render.
    " 两阶段哨兵替换：先把占位符换成"行号+控制字符"哨兵，再把哨兵换成真值。
    " 若直接顺序替换，先填的值中含 {{XXX}} 时会被后续替换波及
    FIELD-SYMBOLS <ls_value> TYPE ty_value.

    rv_text = mv_template.

    LOOP AT mt_values ASSIGNING <ls_value>.
      DATA(lv_token) = `{{` && <ls_value>-name && `}}`.
      DATA(lv_sentinel) = |{ cl_abap_char_utilities=>minchar }{ sy-tabix }{ cl_abap_char_utilities=>minchar }|.
      REPLACE ALL OCCURRENCES OF lv_token IN rv_text WITH lv_sentinel.
    ENDLOOP.

    LOOP AT mt_values ASSIGNING <ls_value>.
      DATA(lv_sentinel_out) = |{ cl_abap_char_utilities=>minchar }{ sy-tabix }{ cl_abap_char_utilities=>minchar }|.
      REPLACE ALL OCCURRENCES OF lv_sentinel_out IN rv_text WITH <ls_value>-value.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
