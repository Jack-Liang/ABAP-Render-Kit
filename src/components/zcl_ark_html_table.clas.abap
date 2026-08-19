CLASS zcl_ark_html_table DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'ark-table'
      RETURNING VALUE(ri_table) TYPE REF TO zcl_ark_html_table .

    METHODS constructor
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'ark-table' .

    METHODS add_column
      IMPORTING !iv_header TYPE string
                !iv_width TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_row
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_cell
      IMPORTING !iv_value TYPE string OPTIONAL
                !ii_html TYPE REF TO zif_ark_html OPTIONAL
                !iv_style TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_header_row
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS add_header_cell
      IMPORTING !iv_value TYPE string OPTIONAL
                !ii_html TYPE REF TO zif_ark_html OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_table .

    METHODS set_striped IMPORTING !iv_striped TYPE abap_bool DEFAULT abap_true .
    METHODS set_hover IMPORTING !iv_hover TYPE abap_bool DEFAULT abap_true .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_column, header TYPE string, width TYPE string,
      END OF ty_column .
    TYPES:
      BEGIN OF ty_cell, value TYPE string, html TYPE REF TO zif_ark_html, style TYPE string,
      END OF ty_cell .
    TYPES:
      BEGIN OF ty_row, cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY,
      END OF ty_row .

    DATA mo_html TYPE REF TO zcl_ark_html .
    DATA mt_columns TYPE STANDARD TABLE OF ty_column .
    DATA mt_rows TYPE STANDARD TABLE OF ty_row .
    DATA mt_header_row TYPE STANDARD TABLE OF ty_cell .
    DATA mv_id TYPE string .
    DATA mv_class TYPE string .
    DATA mv_striped TYPE abap_bool VALUE abap_true .
    DATA mv_hover TYPE abap_bool VALUE abap_true .
    DATA mv_current_row TYPE i VALUE 0 .

    METHODS build_table
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING zcx_ark_exception .
ENDCLASS.

CLASS zcl_ark_html_table IMPLEMENTATION.

  METHOD constructor.
    mo_html = zcl_ark_html=>create( ).
    mv_id = iv_id.
    mv_class = iv_class.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_table
      EXPORTING
        iv_id    = iv_id
        iv_class = iv_class.
  ENDMETHOD.

  METHOD add_column.
    DATA ls_column TYPE ty_column.
    ls_column-header = iv_header.
    ls_column-width = iv_width.
    APPEND ls_column TO mt_columns.
    ri_self = me.
  ENDMETHOD.

  METHOD add_row.
    DATA ls_row TYPE ty_row.
    APPEND ls_row TO mt_rows.
    mv_current_row = lines( mt_rows ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_cell.
    IF mv_current_row = 0 OR mv_current_row > lines( mt_rows ).
      add_row( ).
    ENDIF.

    FIELD-SYMBOLS <ls_row> TYPE ty_row.
    READ TABLE mt_rows INDEX mv_current_row ASSIGNING <ls_row>.
    IF sy-subrc = 0.
      DATA ls_cell TYPE ty_cell.
      ls_cell-value = iv_value.
      ls_cell-html = ii_html.
      ls_cell-style = iv_style.
      APPEND ls_cell TO <ls_row>-cells.
    ENDIF.
    ri_self = me.
  ENDMETHOD.

  METHOD add_header_row.
    CLEAR mt_header_row.
    ri_self = me.
  ENDMETHOD.

  METHOD add_header_cell.
    DATA ls_cell TYPE ty_cell.
    ls_cell-value = iv_value.
    ls_cell-html = ii_html.
    APPEND ls_cell TO mt_header_row.
    ri_self = me.
  ENDMETHOD.

  METHOD set_hover.
    mv_hover = iv_hover.
  ENDMETHOD.

  METHOD set_striped.
    mv_striped = iv_striped.
  ENDMETHOD.

  METHOD build_table.
    DATA lo_table TYPE REF TO zcl_ark_html.
    lo_table = zcl_ark_html=>create( ).

    DATA lv_id TYPE string.
    IF mv_id IS NOT INITIAL.
      lv_id = | id="{ mv_id }"|.
    ENDIF.

    lo_table->add( |<table class="{ mv_class }"{ lv_id }>| ).

    " Header
    IF lines( mt_header_row ) > 0 OR lines( mt_columns ) > 0.
      lo_table->add( |<thead><tr>| ).

      IF lines( mt_header_row ) > 0.
        LOOP AT mt_header_row INTO DATA(ls_hcell).
          IF ls_hcell-html IS NOT INITIAL.
            lo_table->th( ii_content = ls_hcell-html ).
          ELSE.
            lo_table->th( iv_content = ls_hcell-value ).
          ENDIF.
        ENDLOOP.
      ELSE.
        LOOP AT mt_columns INTO DATA(ls_col).
          lo_table->th( iv_content = ls_col-header ).
        ENDLOOP.
      ENDIF.

      lo_table->add( |</tr></thead>| ).
    ENDIF.

    " Body
    lo_table->add( |<tbody>| ).

    LOOP AT mt_rows INTO DATA(ls_row).
      lo_table->add( |<tr>| ).

      LOOP AT ls_row-cells INTO DATA(ls_cell).
        IF ls_cell-html IS NOT INITIAL.
          lo_table->td( ii_content = ls_cell-html iv_style = ls_cell-style ).
        ELSE.
          lo_table->td( iv_content = ls_cell-value iv_style = ls_cell-style ).
        ENDIF.
      ENDLOOP.

      lo_table->add( |</tr>| ).
    ENDLOOP.

    lo_table->add( |</tbody>| ).
    lo_table->add( |</table>| ).

    ri_html = lo_table.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    IF lines( mt_rows ) = 0 AND lines( mt_header_row ) = 0 AND lines( mt_columns ) = 0.
      ri_html = zcl_ark_html=>create( ).
      ri_html->add( |<!-- Empty table -->| ).
      RETURN.
    ENDIF.

    ri_html = build_table( ).
  ENDMETHOD.

ENDCLASS.
