CLASS zcl_ark_example_hello_page DEFINITION
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
    METHODS build_content RETURNING VALUE(ri_content) TYPE REF TO zif_ark_html .
ENDCLASS.

CLASS zcl_ark_example_hello_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - Hello World' ).
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( |<h1>Welcome to ARK Framework</h1>| ).
    mo_html->add( |<p>This is a simple example demonstrating the ARK ABAP GUI framework.</p>| ).

    mo_html->add( build_toolbar( ) ).
    mo_html->add( |<hr>| ).
    mo_html->add( build_content( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Form Example'
      iv_action = 'nav_form' ).

    lo_toolbar->add_button(
      iv_label  = 'Table Example'
      iv_action = 'nav_table' ).

    lo_toolbar->add_separator( ).

    lo_toolbar->add_link(
      iv_label = 'GitHub'
      iv_url   = 'https://github.com/Jack-Liang/ABAP-Render-Kit' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_content.
    DATA(lo_content) = zcl_ark_html=>create( ).

    lo_content->add( |<h2>Features</h2>| ).
    lo_content->add( |<ul>| ).
    lo_content->add( |<li>HTML rendering engine</li>| ).
    lo_content->add( |<li>Event handling system</li>| ).
    lo_content->add( |<li>Reusable components</li>| ).
    lo_content->add( |<li>Form builder</li>| ).
    lo_content->add( |<li>Table builder</li>| ).
    lo_content->add( |</ul>| ).

    lo_content->add( |<h2>Getting Started</h2>| ).
    lo_content->add( |<p>Use the toolbar buttons above to navigate to different examples.</p>| ).

    ri_content = lo_content.
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_form'.
        rs_result-page = NEW zcl_ark_example_form_page( ).
        rs_result-state = 1.
      WHEN 'nav_table'.
        rs_result-page = NEW zcl_ark_example_table_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
