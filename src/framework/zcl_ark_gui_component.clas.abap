CLASS zcl_ark_gui_component DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    METHODS constructor .

    METHODS set_visible IMPORTING !iv_visible TYPE abap_bool .
    METHODS is_visible RETURNING VALUE(rv_visible) TYPE abap_bool .
    METHODS set_enabled IMPORTING !iv_enabled TYPE abap_bool .
    METHODS is_enabled RETURNING VALUE(rv_enabled) TYPE abap_bool .

    METHODS get_html RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .

  PROTECTED SECTION.
    DATA mo_html TYPE REF TO zcl_ark_html .
    DATA mv_visible TYPE abap_bool VALUE abap_true .
    DATA mv_enabled TYPE abap_bool VALUE abap_true .

    METHODS build_html ABSTRACT
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING zcx_ark_exception .

  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ark_gui_component IMPLEMENTATION.

  METHOD constructor.
    mo_html = zcl_ark_html=>create( ).
  ENDMETHOD.

  METHOD get_html.
    ri_html = mo_html.
  ENDMETHOD.

  METHOD is_enabled.
    rv_enabled = mv_enabled.
  ENDMETHOD.

  METHOD is_visible.
    rv_visible = mv_visible.
  ENDMETHOD.

  METHOD set_enabled.
    mv_enabled = iv_enabled.
  ENDMETHOD.

  METHOD set_visible.
    mv_visible = iv_visible.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    IF mv_visible = abap_false.
      ri_html = zcl_ark_html=>create( ).
      RETURN.
    ENDIF.

    CLEAR mo_html.
    mo_html = zcl_ark_html=>create( ).

    ri_html = build_html( ).

    " 安全网：build_html 忘写 ri_html = mo_html 时回落到已构建的内容，
    " 否则渲染接口返回空引用，页面表现为无内容白屏
    IF ri_html IS INITIAL.
      ri_html = mo_html.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
