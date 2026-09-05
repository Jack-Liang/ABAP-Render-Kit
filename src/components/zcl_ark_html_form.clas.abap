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
    " label 为用户可见文本，action 进属性值：一律转义，值含引号/< 时不破坏 HTML
    DATA(lv_label) = zcl_ark_convert=>escape_html( iv_label ).
    IF iv_action IS NOT INITIAL.
      mo_html->add( |<button type="{ zcl_ark_convert=>escape_html( iv_type ) }" formaction="sapevent:{ zcl_ark_convert=>escape_html( iv_action ) }">{ lv_label }</button> | ).
    ELSE.
      mo_html->add( |<button type="{ zcl_ark_convert=>escape_html( iv_type ) }">{ lv_label }</button> | ).
    ENDIF.
    ri_self = me.
  ENDMETHOD.

  METHOD add_dropdown.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ zcl_ark_convert=>escape_html( iv_label ) }</span>| ).
    mo_html->add( |<select name="{ zcl_ark_convert=>escape_html( iv_name ) }">| ).

    DATA lv_option TYPE string.
    LOOP AT it_options INTO lv_option.
      DATA(lv_escaped) = zcl_ark_convert=>escape_html( lv_option ).
      IF lv_option = iv_selected.
        mo_html->add( |<option value="{ lv_escaped }" selected>{ lv_escaped }</option>| ).
      ELSE.
        mo_html->add( |<option value="{ lv_escaped }">{ lv_escaped }</option>| ).
      ENDIF.
    ENDLOOP.

    mo_html->add( |</select>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_field.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ zcl_ark_convert=>escape_html( iv_label ) }</span>| ).

    DATA lv_readonly TYPE string.
    IF iv_readonly = abap_true.
      lv_readonly = ' readonly'.
    ENDIF.

    mo_html->add(
      |<input type="{ zcl_ark_convert=>escape_html( iv_type ) }"| &&
      | name="{ zcl_ark_convert=>escape_html( iv_name ) }"| &&
      | value="{ zcl_ark_convert=>escape_html( iv_value ) }"{ lv_readonly }>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_hidden.
    mo_html->add(
      |<input type="hidden" name="{ zcl_ark_convert=>escape_html( iv_name ) }"| &&
      | value="{ zcl_ark_convert=>escape_html( iv_value ) }">| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_textarea.
    mo_html->add( |<div class="form-row">| ).
    mo_html->add( |<span class="form-label">{ zcl_ark_convert=>escape_html( iv_label ) }</span>| ).
    mo_html->add(
      |<textarea name="{ zcl_ark_convert=>escape_html( iv_name ) }" rows="{ iv_rows }">| &&
      |{ zcl_ark_convert=>escape_html( iv_value ) }</textarea>| ).
    mo_html->add( |</div>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD set_form_action.
    mv_action = iv_action.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    DATA lo_form TYPE REF TO zcl_ark_html.
    lo_form = zcl_ark_html=>create( ).

    DATA lv_action TYPE string.
    IF mv_action IS NOT INITIAL.
      lv_action = | action="sapevent:{ zcl_ark_convert=>escape_html( mv_action ) }"|.
    ENDIF.

    lo_form->add( |<form method="{ zcl_ark_convert=>escape_html( mv_method ) }"{ lv_action }>| ).
    lo_form->add( mo_html ).
    lo_form->add( |</form>| ).

    ri_html = lo_form.
  ENDMETHOD.

ENDCLASS.
