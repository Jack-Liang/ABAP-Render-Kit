CLASS zcl_ark_html_toolbar DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'toolbar'
      RETURNING VALUE(ri_toolbar) TYPE REF TO zcl_ark_html_toolbar .

    METHODS constructor
      IMPORTING !iv_id TYPE string OPTIONAL
                !iv_class TYPE string DEFAULT 'toolbar' .

    METHODS add_button
      IMPORTING !iv_label TYPE string
                !iv_action TYPE string
                !iv_icon TYPE string OPTIONAL
                !iv_query TYPE string OPTIONAL
                !iv_enabled TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_toolbar .

    METHODS add_link
      IMPORTING !iv_label TYPE string
                !iv_url TYPE string
                !iv_icon TYPE string OPTIONAL
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_toolbar .

    METHODS add_separator
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_toolbar .

    METHODS add_text
      IMPORTING !iv_text TYPE string
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_toolbar .

    METHODS add_html
      IMPORTING !ii_html TYPE REF TO zif_ark_html
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_html_toolbar .

    METHODS clear .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_toolbar_item,
        type TYPE c LENGTH 1,
        label TYPE string,
        action TYPE string,
        url TYPE string,
        icon TYPE string,
        query TYPE string,
        enabled TYPE abap_bool,
        html TYPE REF TO zif_ark_html,
      END OF ty_toolbar_item .

    DATA mt_items TYPE STANDARD TABLE OF ty_toolbar_item .
    DATA mv_id TYPE string .
    DATA mv_class TYPE string .
ENDCLASS.

CLASS zcl_ark_html_toolbar IMPLEMENTATION.

  METHOD constructor.
    mv_id = iv_id.
    mv_class = iv_class.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_toolbar
      EXPORTING
        iv_id    = iv_id
        iv_class = iv_class.
  ENDMETHOD.

  METHOD add_button.
    DATA ls_item TYPE ty_toolbar_item.
    ls_item-type    = 'B'.
    ls_item-label   = iv_label.
    ls_item-action  = iv_action.
    ls_item-icon    = iv_icon.
    ls_item-query   = iv_query.
    ls_item-enabled = iv_enabled.
    APPEND ls_item TO mt_items.
    ri_self = me.
  ENDMETHOD.

  METHOD add_html.
    DATA ls_item TYPE ty_toolbar_item.
    ls_item-type = 'H'.
    ls_item-html = ii_html.
    APPEND ls_item TO mt_items.
    ri_self = me.
  ENDMETHOD.

  METHOD add_link.
    DATA ls_item TYPE ty_toolbar_item.
    ls_item-type   = 'L'.
    ls_item-label  = iv_label.
    ls_item-url    = iv_url.
    ls_item-icon   = iv_icon.
    APPEND ls_item TO mt_items.
    ri_self = me.
  ENDMETHOD.

  METHOD add_separator.
    DATA ls_item TYPE ty_toolbar_item.
    ls_item-type = 'S'.
    APPEND ls_item TO mt_items.
    ri_self = me.
  ENDMETHOD.

  METHOD add_text.
    DATA ls_item TYPE ty_toolbar_item.
    ls_item-type  = 'T'.
    ls_item-label = iv_text.
    APPEND ls_item TO mt_items.
    ri_self = me.
  ENDMETHOD.

  METHOD clear.
    CLEAR mt_items.
  ENDMETHOD.

  METHOD zif_ark_gui_renderable~render.
    DATA lo_toolbar TYPE REF TO zcl_ark_html.
    lo_toolbar = zcl_ark_html=>create( ).

    DATA lv_id TYPE string.
    IF mv_id IS NOT INITIAL.
      lv_id = | id="{ mv_id }"|.
    ENDIF.

    lo_toolbar->add( |<div class="{ mv_class }"{ lv_id }>| ).

    LOOP AT mt_items INTO DATA(ls_item).
      CASE ls_item-type.
        WHEN 'B'.
          IF ls_item-enabled = abap_false.
            lo_toolbar->add( |<span class="disabled">{ ls_item-label }</span> | ).
          ELSE.
            lo_toolbar->add_a(
              iv_txt   = ls_item-label
              iv_act   = ls_item-action
              iv_query = ls_item-query
              iv_class = 'toolbar-button' ).
            lo_toolbar->add( | | ).
          ENDIF.

        WHEN 'L'.
          lo_toolbar->add_a(
            iv_txt   = ls_item-label
            iv_act   = ls_item-url
            iv_typ   = zif_ark_html=>c_action_type-url
            iv_class = 'toolbar-link' ).
          lo_toolbar->add( | | ).

        WHEN 'S'.
          lo_toolbar->add( |<span class="separator"></span> | ).

        WHEN 'T'.
          lo_toolbar->add( |<span class="toolbar-text">{ ls_item-label }</span> | ).

        WHEN 'H'.
          IF ls_item-html IS NOT INITIAL.
            lo_toolbar->add( ls_item-html ).
          ENDIF.

      ENDCASE.
    ENDLOOP.

    lo_toolbar->add( |</div>| ).

    ri_html = lo_toolbar.
  ENDMETHOD.

ENDCLASS.
