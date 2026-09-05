CLASS zcl_ark_html_table DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'ark-table'
      RETURNING VALUE(ri_table) TYPE REF TO zcl_ark_html_table .

    "! Fill the builder from any internal table via RTTI: one column per
    "! component (DDIC medium/short/reptext as header, field name as
    "! fallback), numeric columns right-aligned, date/time in user format,
    "! deep table columns show their row count, values HTML-escaped.
    "! Elementary line types render as a single TABLE_LINE column.
    "! Returns the configured builder, so add_column/set_striped/... still
    "! apply before render( )
    CLASS-METHODS from_any_table
      IMPORTING !it_table TYPE ANY TABLE
      RETURNING VALUE(ri_table) TYPE REF TO zcl_ark_html_table .

    "! Column header for a structure component: DDIC scrtext_m >
    "! scrtext_s > reptext, field name as fallback. Shared by
    "! from_any_table( ) and external exporters (Excel etc.)
    CLASS-METHODS ddic_header
      IMPORTING
        !is_comp TYPE cl_abap_structdescr=>component
      RETURNING VALUE(rv_text) TYPE string .

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
    TYPES tt_component TYPE cl_abap_structdescr=>component_table .
    " type_kind 属性的值域（cl_abap_typedescr=>typekind_* 常量为 C(1)）；
    " 不直接用 cl_abap_typedescr=>typekind 命名类型：其来源是 ABAPTYPE
    " 类型组，经类名寻址在各发行版上不可靠
    TYPES ty_typekind TYPE c LENGTH 1 .
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

    "! Flatten a structure's components; .INCLUDE components contribute
    "! their nested components instead of appearing as one deep column.
    "! Static: called from the static from_any_table( ) and touching no
    "! instance state
    CLASS-METHODS collect_components
      IMPORTING
        !io_struct TYPE REF TO cl_abap_structdescr
      CHANGING
        !ct_comp TYPE tt_component .

    "! Elementary value as display string; initial date/time -> empty.
    "! Static: called from the static from_any_table( )
    CLASS-METHODS format_elem_value
      IMPORTING
        !iv_type_kind TYPE ty_typekind
        !ig_value TYPE any
      RETURNING VALUE(rv_text) TYPE string .
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

  METHOD from_any_table.
    DATA lo_tabledesc TYPE REF TO cl_abap_tabledescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_comp TYPE tt_component.
    DATA ls_comp TYPE cl_abap_structdescr=>component.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_field> TYPE any.
    FIELD-SYMBOLS <lt_nest> TYPE ANY TABLE.

    CREATE OBJECT ri_table.

    TRY.
        lo_tabledesc ?= cl_abap_tabledescr=>describe_by_data( it_table ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.

    DATA(lo_line) = lo_tabledesc->get_table_line_type( ).
    CLEAR lo_struct.
    IF lo_line->kind = cl_abap_typedescr=>kind_struct.
      TRY.
          lo_struct ?= lo_line.
        CATCH cx_sy_move_cast_error.
          CLEAR lo_struct.
      ENDTRY.
    ENDIF.

    IF lo_struct IS NOT BOUND.
      " 行类型非结构：单列 TABLE_LINE。仅基本类型可安全转字符串，
      " 引用/内表等深层行类型降级为占位符
      ri_table->add_column( iv_header = 'TABLE_LINE' ).
      LOOP AT it_table ASSIGNING <ls_row>.
        ri_table->add_row( ).
        IF lo_line->kind = cl_abap_typedescr=>kind_elem.
          ri_table->add_cell(
            iv_value = zcl_ark_convert=>escape_html( |{ <ls_row> }| ) ).
        ELSE.
          ri_table->add_cell( iv_value = '…' ).
        ENDIF.
      ENDLOOP.
      RETURN.
    ENDIF.

    collect_components( EXPORTING io_struct = lo_struct
                        CHANGING  ct_comp  = lt_comp ).

    LOOP AT lt_comp INTO ls_comp.
      ri_table->add_column( iv_header = ddic_header( is_comp = ls_comp ) ).
    ENDLOOP.

    LOOP AT it_table ASSIGNING <ls_row>.
      ri_table->add_row( ).
      LOOP AT lt_comp INTO ls_comp.
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lv_field>.
        IF sy-subrc <> 0.
          ri_table->add_cell( iv_value = '' ).
          CONTINUE.
        ENDIF.

        DATA lv_val TYPE string.
        DATA lv_style TYPE string.
        CASE ls_comp-type->kind.
          WHEN cl_abap_datadescr=>kind_elem.
            lv_val = format_elem_value( iv_type_kind = ls_comp-type->type_kind
                                        ig_value     = <lv_field> ).
            " 数值列右对齐（Fiori 列表报告惯例）
            IF ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int1      OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int2      OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int       OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_int8      OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_packed    OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_float     OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_decfloat16 OR
               ls_comp-type->type_kind = cl_abap_typedescr=>typekind_decfloat34.
              lv_style = 'text-align:right;'.
            ENDIF.
          WHEN cl_abap_datadescr=>kind_table.
            " 深层内表列只显示行数
            ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO <lt_nest>.
            IF sy-subrc = 0.
              lv_val = |{ lines( <lt_nest> ) }|.
              lv_style = 'text-align:right;'.
            ENDIF.
          WHEN OTHERS.
            lv_val = '…'.
        ENDCASE.

        " td() 不转义，单元格值统一过 escape_html 防 HTML 注入/错乱
        ri_table->add_cell( iv_value = zcl_ark_convert=>escape_html( lv_val )
                            iv_style = lv_style ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD collect_components.
    DATA ls_comp TYPE cl_abap_structdescr=>component.
    DATA lo_nested TYPE REF TO cl_abap_structdescr.

    LOOP AT io_struct->get_components( ) INTO ls_comp.
      " .INCLUDE 组件无独立单元格：递归平铺其子组件（DDIC 表常见 .INCLUDE）
      IF ls_comp-as_include = abap_true AND ls_comp-type IS BOUND
         AND ls_comp-type->kind = cl_abap_typedescr=>kind_struct.
        TRY.
            lo_nested ?= ls_comp-type.
            collect_components( EXPORTING io_struct = lo_nested
                                CHANGING  ct_comp  = ct_comp ).
          CATCH cx_sy_move_cast_error.
            APPEND ls_comp TO ct_comp.
        ENDTRY.
      ELSE.
        APPEND ls_comp TO ct_comp.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ddic_header.
    " 默认用字段名；组件基于 DDIC 数据元素时升级为中/短标签
    DATA lo_elem TYPE REF TO cl_abap_elemdescr.
    DATA ls_dfies TYPE dfies.

    rv_text = is_comp-name.
    IF is_comp-type IS NOT BOUND OR is_comp-type->kind <> cl_abap_datadescr=>kind_elem.
      RETURN.
    ENDIF.

    TRY.
        lo_elem ?= is_comp-type.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.

    CALL METHOD lo_elem->get_ddic_field
      RECEIVING
        p_flddescr = ls_dfies
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 标签逐级回退：中标签 > 短标签 > 标题 > 字段名
    DATA(lv_label) = COND string( WHEN ls_dfies-scrtext_m IS NOT INITIAL THEN ls_dfies-scrtext_m
                                  WHEN ls_dfies-scrtext_s IS NOT INITIAL THEN ls_dfies-scrtext_s
                                  WHEN ls_dfies-reptext    IS NOT INITIAL THEN ls_dfies-reptext
                                  ELSE '' ).
    IF lv_label IS NOT INITIAL.
      rv_text = lv_label.
    ENDIF.
  ENDMETHOD.

  METHOD format_elem_value.
    " 格式化选项要求静态类型：先移入定长目标再套模板，泛型形参不可直接用
    CASE iv_type_kind.
      WHEN cl_abap_typedescr=>typekind_date.
        DATA lv_date TYPE d.
        lv_date = ig_value.
        IF lv_date IS INITIAL.
          rv_text = ''.
        ELSE.
          rv_text = |{ lv_date DATE = USER }|.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_time.
        DATA lv_time TYPE t.
        lv_time = ig_value.
        IF lv_time IS INITIAL.
          rv_text = ''.
        ELSE.
          rv_text = |{ lv_time TIME = USER }|.
        ENDIF.
      WHEN OTHERS.
        rv_text = |{ ig_value }|.
    ENDCASE.
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
