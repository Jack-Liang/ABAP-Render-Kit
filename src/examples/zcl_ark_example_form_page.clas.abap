CLASS zcl_ark_example_form_page DEFINITION
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
    METHODS build_form RETURNING VALUE(ri_form) TYPE REF TO zif_ark_html .
ENDCLASS.

CLASS zcl_ark_example_form_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - Form Example' ).
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( |<h1>Form Example</h1>| ).
    mo_html->add( |<p>This page demonstrates the form builder component.</p>| ).

    mo_html->add( build_toolbar( ) ).
    mo_html->add( |<hr>| ).
    mo_html->add( build_form( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Back to Home'
      iv_action = 'nav_home' ).

    lo_toolbar->add_button(
      iv_label  = 'Table Example'
      iv_action = 'nav_table' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_form.
    DATA(lo_form) = zcl_ark_html_form=>create(
      iv_action = 'form_submit'
      iv_method = 'post' ).

    lo_form->add_field(
      iv_name  = 'firstname'
      iv_label = 'First Name'
      iv_value = 'John' ).

    lo_form->add_field(
      iv_name  = 'lastname'
      iv_label = 'Last Name'
      iv_value = 'Doe' ).

    lo_form->add_field(
      iv_name  = 'email'
      iv_label = 'Email'
      iv_type  = 'email'
      iv_value = 'john.doe@example.com' ).

    lo_form->add_dropdown(
      iv_name     = 'country'
      iv_label    = 'Country'
      it_options  = VALUE string_table( ( `Germany` ) ( `USA` ) ( `China` ) ( `Japan` ) )
      iv_selected = 'Germany' ).

    lo_form->add_textarea(
      iv_name  = 'comments'
      iv_label = 'Comments'
      iv_value = 'This is a sample comment.' ).

    lo_form->add_hidden(
      iv_name  = 'form_id'
      iv_value = '12345' ).

    lo_form->add_button(
      iv_label  = 'Submit'
      iv_action = 'form_submit'
      iv_type   = 'submit' ).

    lo_form->add_button(
      iv_label  = 'Reset'
      iv_type   = 'reset' ).

    ri_form = lo_form->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN 'nav_table'.
        rs_result-page = NEW zcl_ark_example_table_page( ).
        rs_result-state = 1.
      WHEN 'form_submit'.
        " Handle form submission
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
