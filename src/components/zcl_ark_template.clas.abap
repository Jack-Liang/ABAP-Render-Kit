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

    " 填充占位符：{{NAME}} <- iv_value
    METHODS set
      IMPORTING !iv_name        TYPE string
                !iv_value       TYPE string
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_ark_template .

    " 渲染：替换所有占位符后返回文本
    " 注意：未填充的占位符会原样保留，便于发现遗漏
    METHODS render
      RETURNING VALUE(rv_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_template TYPE string .
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
    DATA lv_token TYPE string.

    lv_token = `{{` && iv_name && `}}`.
    REPLACE ALL OCCURRENCES OF lv_token IN mv_template WITH iv_value.

    ro_self = me.
  ENDMETHOD.

  METHOD render.
    rv_text = mv_template.
  ENDMETHOD.

ENDCLASS.
