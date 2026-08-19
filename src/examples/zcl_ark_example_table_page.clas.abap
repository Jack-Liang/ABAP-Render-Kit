CLASS zcl_ark_example_table_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    METHODS build_toolbar RETURNING VALUE(ri_toolbar) TYPE REF TO zif_ark_html .
    METHODS build_table RETURNING VALUE(ri_table) TYPE REF TO zif_ark_html .
ENDCLASS.

CLASS zcl_ark_example_table_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - Table Example' ).
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( |<h1>Table Example</h1>| ).
    mo_html->add( |<p>This page demonstrates the table builder component.</p>| ).

    mo_html->add( build_toolbar( ) ).
    mo_html->add( |<hr>| ).
    mo_html->add( build_table( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Back to Home'
      iv_action = 'nav_home' ).

    lo_toolbar->add_button(
      iv_label  = 'Form Example'
      iv_action = 'nav_form' ).

    lo_toolbar->add_separator( ).

    lo_toolbar->add_text( iv_text = 'Total rows: 5' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_table.
    DATA(lo_table) = zcl_ark_html_table=>create( iv_id = 'sample_table' ).

    lo_table->add_column( iv_header = 'ID' iv_width = '10%' ).
    lo_table->add_column( iv_header = 'Name' iv_width = '30%' ).
    lo_table->add_column( iv_header = 'Department' iv_width = '25%' ).
    lo_table->add_column( iv_header = 'Role' iv_width = '20%' ).
    lo_table->add_column( iv_header = 'Actions' iv_width = '15%' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = '001' ).
    lo_table->add_cell( iv_value = 'Alice Smith' ).
    lo_table->add_cell( iv_value = 'Engineering' ).
    lo_table->add_cell( iv_value = 'Developer' ).
    lo_table->add_cell(
      iv_value = 'Edit | Delete'
      iv_style = 'color: #0066cc;' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = '002' ).
    lo_table->add_cell( iv_value = 'Bob Johnson' ).
    lo_table->add_cell( iv_value = 'Marketing' ).
    lo_table->add_cell( iv_value = 'Manager' ).
    lo_table->add_cell(
      iv_value = 'Edit | Delete'
      iv_style = 'color: #0066cc;' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = '003' ).
    lo_table->add_cell( iv_value = 'Charlie Brown' ).
    lo_table->add_cell( iv_value = 'Sales' ).
    lo_table->add_cell( iv_value = 'Sales Rep' ).
    lo_table->add_cell(
      iv_value = 'Edit | Delete'
      iv_style = 'color: #0066cc;' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = '004' ).
    lo_table->add_cell( iv_value = 'Diana Prince' ).
    lo_table->add_cell( iv_value = 'HR' ).
    lo_table->add_cell( iv_value = 'Director' ).
    lo_table->add_cell(
      iv_value = 'Edit | Delete'
      iv_style = 'color: #0066cc;' ).

    lo_table->add_row( ).
    lo_table->add_cell( iv_value = '005' ).
    lo_table->add_cell( iv_value = 'Eve Davis' ).
    lo_table->add_cell( iv_value = 'Engineering' ).
    lo_table->add_cell( iv_value = 'Tester' ).
    lo_table->add_cell(
      iv_value = 'Edit | Delete'
      iv_style = 'color: #0066cc;' ).

    ri_table = lo_table->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN 'nav_form'.
        rs_result-page = NEW zcl_ark_example_form_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
