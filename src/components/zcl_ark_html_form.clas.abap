CLASS zcl_ark_html_form DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING !iv_action TYPE string OPTIONAL
                !iv_method TYPE string DEFAULT 'post'
      RETURNING VALUE(ri_form) TYPE REF TO zcl_ark_html_form .

    METHODS constructor
      IMPORTING !iv_action TYPE string OPTIONAL
                !iv_method TYPE string DEFAULT 'post' .

    METHODS add_field
      IMPORTING !iv_name TYPE string
                !iv_label TYPE string
                !iv_value TYPE string OPTIONAL
                !iv_type TYPE string DEFAULT 'text'
                !iv_readonly TYPE abap_bool OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_form .

    METHODS add_textarea
      IMPORTING !iv_name TYPE string
                !iv_label TYPE string
                !iv_value TYPE string OPTIONAL
                !iv_rows TYPE i DEFAULT 4
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_form .

    METHODS add_dropdown
      IMPORTING !iv_name TYPE string
                !iv_label TYPE string
                !it_options TYPE string_table
                !iv_selected TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_form .

    METHODS add_button
      IMPORTING !iv_label TYPE string
                !iv_action TYPE string OPTIONAL
                !iv_type TYPE string DEFAULT 'submit'
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_form .

    METHODS add_hidden
      IMPORTING !iv_name TYPE string
                !iv_value TYPE string
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_form .

    METHODS set_form_action
      IMPORTING !iv_action TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_html TYPE REF TO zcl_ark_html .
    DATA mv_action TYPE string .
    DATA mv_method TYPE string .
    DATA mt_fields TYPE STANDARD TABLE OF string .

    METHODS render_field
      IMPORTING !iv_name TYPE string
                !iv_label TYPE string
                !iv_value TYPE string
                !iv_type TYPE string
                !iv_readonly TYPE abap_bool
      RETURNING VALUE(rv_html) TYPE string .
ENDCLASS.

CLASS zcl_ark_html_form IMPLEMENTATION.

  METHOD constructor.
    mo_html = zcl_ark_html=>create( ).
    mv_action = iv_action.
    mv_method = iv_method.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_form
      EXPORTING
        iv_action = iv_action
        iv_method = iv_method.
  ENDMETHOD.

  METHOD add_button.
    IF iv_action IS NOT INITIAL.
      mo_html->add( |<button type="{ iv_type }" formaction="sapevent:{ iv_action }">{ iv_label }</button> | ).
    ELSE.
      mo_html->add( |<button type="{ iv_type }">{ iv_label }</button> | ).
    ENDIF.
    ri_self = me.
  ENDMETHOD.

  METHOD add_dropdown.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ iv_label }</span>| ).
    mo_html->add( |<select name="{ iv_name }">| ).

    DATA lv_option TYPE string.
    LOOP AT it_options INTO lv_option.
      IF lv_option = iv_selected.
        mo_html->add( |<option value="{ lv_option }" selected>{ lv_option }</option>| ).
      ELSE.
        mo_html->add( |<option value="{ lv_option }">{ lv_option }</option>| ).
      ENDIF.
    ENDLOOP.

    mo_html->add( |</select>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_field.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ iv_label }</span>| ).

    DATA lv_readonly TYPE string.
    IF iv_readonly = abap_true.
      lv_readonly = ' readonly'.
    ENDIF.

    mo_html->add( |<input type="{ iv_type }" name="{ iv_name }" value="{ iv_value }"{ lv_readonly }>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_hidden.
    mo_html->add( |<input type="hidden" name="{ iv_name }" value="{ iv_value }">| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_textarea.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ iv_label }</span>| ).
    mo_html->add( |<textarea name="{ iv_name }" rows="{ iv_rows }">{ iv_value }</textarea>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD render_field.
    rv_html = |<input type="{ iv_type }" name="{ iv_name }" value="{ iv_value }">|.
  ENDMETHOD.

  METHOD set_form_action.
    mv_action = iv_action.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    DATA lo_form TYPE REF TO zcl_ark_html.
    lo_form = zcl_ark_html=>create( ).

    DATA lv_action TYPE string.
    IF mv_action IS NOT INITIAL.
      lv_action = | action="sapevent:{ mv_action }"|.
    ENDIF.

    lo_form->add( |<form method="{ mv_method }"{ lv_action }>| ).
    lo_form->add( mo_html ).
    lo_form->add( |</form>| ).

    ri_html = lo_form.
  ENDMETHOD.

ENDCLASS.
