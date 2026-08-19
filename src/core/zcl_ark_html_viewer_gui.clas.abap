CLASS zcl_ark_html_viewer_gui DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_html_viewer .

    CLASS-METHODS create_viewer
      IMPORTING !iv_parent TYPE REF TO cl_gui_container OPTIONAL
                !io_container TYPE REF TO cl_gui_container OPTIONAL
      RETURNING VALUE(ri_viewer) TYPE REF TO zif_ark_html_viewer
      RAISING zcx_ark_exception .

    METHODS constructor
      IMPORTING !iv_parent TYPE REF TO cl_gui_container OPTIONAL
                !io_container TYPE REF TO cl_gui_container OPTIONAL
      RAISING zcx_ark_exception .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_html_viewer TYPE REF TO cl_gui_html_viewer .
    DATA mv_url TYPE string .

    METHODS on_sapevent
      FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action frame getdata postdata query_table .

    METHODS get_parent_container
      IMPORTING !iv_parent TYPE REF TO cl_gui_container OPTIONAL
                !io_container TYPE REF TO cl_gui_container OPTIONAL
      RETURNING VALUE(ro_container) TYPE REF TO cl_gui_container .
ENDCLASS.

CLASS zcl_ark_html_viewer_gui IMPLEMENTATION.

  METHOD constructor.
    DATA lo_container TYPE REF TO cl_gui_container.

    lo_container = get_parent_container(
      iv_parent    = iv_parent
      io_container = io_container ).

    IF lo_container IS INITIAL.
      zcx_ark_exception=>raise( 'Parent container is required for HTML viewer' ).
    ENDIF.

    CREATE OBJECT mo_html_viewer
      EXPORTING
        parent = lo_container.

    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'Failed to create HTML viewer' ).
    ENDIF.

    SET HANDLER on_sapevent FOR mo_html_viewer.
  ENDMETHOD.

  METHOD create_viewer.
    CREATE OBJECT ri_viewer TYPE zcl_ark_html_viewer_gui
      EXPORTING
        iv_parent    = iv_parent
        io_container = io_container.
  ENDMETHOD.

  METHOD get_parent_container.
    IF io_container IS NOT INITIAL.
      ro_container = io_container.
    ELSEIF iv_parent IS NOT INITIAL.
      ro_container = iv_parent.
    ELSE.
      ro_container = cl_gui_container=>screen0.
    ENDIF.
  ENDMETHOD.

  METHOD on_sapevent.
    DATA lt_postdata TYPE zif_ark_html_viewer=>ty_post_data.
    DATA ls_postdata LIKE LINE OF lt_postdata.
    DATA lv_postdata TYPE string.

    IF postdata IS NOT INITIAL.
      lv_postdata = cl_http_utility=>if_http_utility~string_to_fields( postdata ).
      CLEAR lt_postdata.
      ls_postdata = lv_postdata.
      APPEND ls_postdata TO lt_postdata.
    ENDIF.

    RAISE EVENT zif_ark_html_viewer~sapevent
      EXPORTING
        action      = action
        frame       = frame
        getdata     = getdata
        postdata    = lt_postdata
        query_table = query_table.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~back.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->go_back( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~close_document.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->close_document( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~free.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->free( ).
      FREE mo_html_viewer.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~get_url.
    rv_url = mv_url.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~load_data.
    DATA lt_data_table TYPE STANDARD TABLE OF c.
    DATA lv_url TYPE c LENGTH 250.

    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'HTML viewer not initialized' ).
    ENDIF.

    mo_html_viewer->load_data(
      EXPORTING
        url       = iv_url
        type      = iv_type
        subtype   = iv_subtype
        size      = iv_size
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table = ct_data_table
      EXCEPTIONS
        OTHERS    = 1 ).

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( 'Failed to load data into HTML viewer' ).
    ENDIF.

    ev_assigned_url = lv_url.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~set_focus.
    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'HTML viewer not initialized' ).
    ENDIF.

    mo_html_viewer->set_focus(
      EXCEPTIONS
        OTHERS = 1 ).

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( 'Failed to set focus on HTML viewer' ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~set_registered_events.
    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'HTML viewer not initialized' ).
    ENDIF.

    mo_html_viewer->set_registered_events(
      EXPORTING
        events = it_events
      EXCEPTIONS
        OTHERS = 1 ).

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( 'Failed to register events on HTML viewer' ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~set_visiblity.
    IF mo_html_viewer IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_visible = abap_true.
      mo_html_viewer->set_visible( abap_true ).
    ELSE.
      mo_html_viewer->set_visible( abap_false ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_html_viewer~show_url.
    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'HTML viewer not initialized' ).
    ENDIF.

    mv_url = iv_url.

    mo_html_viewer->show_url(
      EXPORTING
        url = iv_url
      EXCEPTIONS
        OTHERS = 1 ).

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( 'Failed to show URL in HTML viewer' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
