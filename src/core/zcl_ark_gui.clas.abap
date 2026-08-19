CLASS zcl_ark_gui DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_services .

    CLASS-METHODS get_instance
      RETURNING VALUE(ri_gui) TYPE REF TO zcl_ark_gui .

    CLASS-METHODS create
      IMPORTING !io_container TYPE REF TO cl_gui_container OPTIONAL
      RETURNING VALUE(ri_gui) TYPE REF TO zcl_ark_gui
      RAISING zcx_ark_exception .

    METHODS constructor
      IMPORTING !io_container TYPE REF TO cl_gui_container OPTIONAL
      RAISING zcx_ark_exception .

    METHODS go_home RAISING zcx_ark_exception .
    METHODS go_back RAISING zcx_ark_exception .
    METHODS set_page
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable
      RAISING zcx_ark_exception .
    METHODS render .
    METHODS set_focus RAISING zcx_ark_exception .
    METHODS free .

    METHODS on_event
      FOR EVENT sapevent OF zif_ark_html_viewer
      IMPORTING action frame getdata postdata query_table .

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO zcl_ark_gui .

    DATA mo_html_viewer TYPE REF TO zif_ark_html_viewer .
    DATA mo_current_page TYPE REF TO zif_ark_gui_renderable .
    DATA mv_current_page_name TYPE string .
    DATA mo_parts TYPE REF TO zcl_ark_html_parts .
    DATA mt_event_handlers TYPE STANDARD TABLE OF REF TO zif_ark_gui_event_handler .
    DATA mo_container TYPE REF TO cl_gui_container .

    METHODS render_page
      RETURNING VALUE(rv_html) TYPE string
      RAISING zcx_ark_exception .

    METHODS build_html_document
      IMPORTING !iv_content TYPE string
      RETURNING VALUE(rv_html) TYPE string .

    METHODS call_page_render
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING zcx_ark_exception .

    METHODS get_asset_mime
      IMPORTING !iv_mime_name TYPE wwwdatatab-objid
      RETURNING VALUE(rv_xdata) TYPE xstring
      RAISING zcx_ark_exception .
ENDCLASS.

CLASS zcl_ark_gui IMPLEMENTATION.

  METHOD constructor.
    mo_parts = NEW zcl_ark_html_parts( ).

    IF io_container IS NOT INITIAL.
      mo_container = io_container.
    ELSE.
      mo_container = cl_gui_container=>screen0.
    ENDIF.

    mo_html_viewer = zcl_ark_html_viewer_gui=>create_viewer(
      io_container = mo_container ).

    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'Failed to create HTML viewer' ).
    ENDIF.

    SET HANDLER on_event FOR mo_html_viewer.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_gui
      EXPORTING
        io_container = io_container.
    go_instance = ri_gui.
  ENDMETHOD.

  METHOD get_instance.
    IF go_instance IS INITIAL.
      go_instance = zcl_ark_gui=>create( ).
    ENDIF.
    ri_gui = go_instance.
  ENDMETHOD.

  METHOD go_home.
    CLEAR mo_current_page.
    CLEAR mv_current_page_name.
    render( ).
  ENDMETHOD.

  METHOD go_back.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->back( ).
    ENDIF.
  ENDMETHOD.

  METHOD set_page.
    mo_current_page = io_page.

    IF io_page IS NOT INITIAL.
      DATA lo_object TYPE REF TO object.
      lo_object ?= io_page.
      mv_current_page_name = cl_abap_classdescr=>get_class_name( lo_object ).
    ELSE.
      CLEAR mv_current_page_name.
    ENDIF.

    render( ).
  ENDMETHOD.

  METHOD render.
    DATA lv_html TYPE string.

    TRY.
        lv_html = render_page( ).
      CATCH zcx_ark_exception INTO DATA(lx_error).
        lv_html = |<html><body><h1>Error</h1><p>{ lx_error->get_text( ) }</p></body></html>|.
    ENDTRY.

    IF mo_html_viewer IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_data TYPE STANDARD TABLE OF c.
    DATA lv_size TYPE i.

    zcl_ark_convert=>string_to_tab(
      EXPORTING
        iv_str = lv_html
      IMPORTING
        ev_size = lv_size
        et_tab  = lt_data ).

    DATA lv_assigned_url TYPE string.

    mo_html_viewer->load_data(
      EXPORTING
        iv_type    = 'text'
        iv_subtype = 'html'
        iv_size    = lv_size
      IMPORTING
        ev_assigned_url = lv_assigned_url
      CHANGING
        ct_data_table = lt_data ).

    mo_html_viewer->show_url( lv_assigned_url ).
  ENDMETHOD.

  METHOD render_page.
    DATA lv_content TYPE string.

    IF mo_current_page IS NOT INITIAL.
      DATA(li_html) = call_page_render( ).
      IF li_html IS NOT INITIAL.
        lv_content = li_html->render( ).
      ENDIF.
    ENDIF.

    rv_html = build_html_document( lv_content ).
  ENDMETHOD.

  METHOD call_page_render.
    IF mo_current_page IS INITIAL.
      ri_html = zcl_ark_html=>create( ).
      RETURN.
    ENDIF.

    ri_html = mo_current_page->render( ).
  ENDMETHOD.

  METHOD build_html_document.
    rv_html = |<!DOCTYPE html>\n| &&
              |<html>\n| &&
              |<head>\n| &&
              |<meta charset="utf-8">\n| &&
              |<style type="text/css">\n| &&
              |body \{ font-family: Arial, Helvetica, sans-serif; margin: 0; padding: 10px; \}\n| &&
              |table \{ border-collapse: collapse; width: 100%; \}\n| &&
              |th, td \{ border: 1px solid #ddd; padding: 8px; text-align: left; \}\n| &&
              |th \{ background-color: #f2f2f2; \}\n| &&
              |tr:nth-child(even) \{ background-color: #f9f9f9; \}\n| &&
              |a \{ color: #0066cc; text-decoration: none; \}\n| &&
              |a:hover \{ text-decoration: underline; \}\n| &&
              |.toolbar \{ margin-bottom: 10px; padding: 5px; background-color: #f0f0f0; \}\n| &&
              |.form-row \{ margin-bottom: 10px; \}\n| &&
              |.form-label \{ display: inline-block; width: 120px; font-weight: bold; \}\n| &&
              |</style>\n| &&
              |</head>\n| &&
              |<body>\n| &&
              |{ iv_content }\n| &&
              |</body>\n| &&
              |</html>|.
  ENDMETHOD.

  METHOD on_event.
    DATA(li_event) = zcl_ark_gui_event=>new(
      iv_action   = action
      iv_getdata  = getdata
      it_postdata = postdata ).

    DATA ls_result TYPE zif_ark_gui_event_handler=>ty_handling_result.
    DATA lv_handled TYPE abap_bool VALUE abap_false.

    LOOP AT mt_event_handlers INTO DATA(li_handler).
      TRY.
          ls_result = li_handler->on_event( li_event ).
          IF ls_result-state IS NOT INITIAL.
            lv_handled = abap_true.
            EXIT.
          ENDIF.
        CATCH zcx_ark_exception.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    IF lv_handled = abap_true AND ls_result-page IS NOT INITIAL.
      set_page( ls_result-page ).
    ELSEIF action IS NOT INITIAL.
      render( ).
    ENDIF.
  ENDMETHOD.

  METHOD set_focus.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->set_focus( ).
    ENDIF.
  ENDMETHOD.

  METHOD free.
    IF mo_html_viewer IS NOT INITIAL.
      mo_html_viewer->free( ).
      FREE mo_html_viewer.
    ENDIF.
    IF go_instance = me.
      CLEAR go_instance.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_gui_services~cache_asset.
    DATA lv_url TYPE string.

    IF iv_url IS NOT INITIAL.
      lv_url = iv_url.
    ELSE.
      lv_url = |ark_asset_{ cl_abap_context_info=>get_system_time( ) }_{ sy-index }.txt|.
    ENDIF.

    DATA lt_data TYPE STANDARD TABLE OF c.
    DATA lv_size TYPE i.

    IF iv_text IS NOT INITIAL.
      zcl_ark_convert=>string_to_tab(
        EXPORTING
          iv_str = iv_text
        IMPORTING
          ev_size = lv_size
          et_tab  = lt_data ).

      DATA lv_assigned_url TYPE string.
      mo_html_viewer->load_data(
        EXPORTING
          iv_url     = lv_url
          iv_type    = iv_type
          iv_subtype = iv_subtype
          iv_size    = lv_size
        IMPORTING
          ev_assigned_url = lv_assigned_url
        CHANGING
          ct_data_table = lt_data ).

      rv_url = lv_assigned_url.
    ELSEIF iv_xdata IS NOT INITIAL.
      DATA lt_bintab TYPE STANDARD TABLE OF x.
      zcl_ark_convert=>xstring_to_bintab(
        EXPORTING
          iv_xstr = iv_xdata
        IMPORTING
          ev_size = lv_size
          et_bintab = lt_bintab ).

      mo_html_viewer->load_data(
        EXPORTING
          iv_url     = lv_url
          iv_type    = iv_type
          iv_subtype = iv_subtype
          iv_size    = lv_size
        IMPORTING
          ev_assigned_url = lv_assigned_url
        CHANGING
          ct_data_table = lt_bintab ).

      rv_url = lv_assigned_url.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ark_gui_services~get_current_page_name.
    rv_page_name = mv_current_page_name.
  ENDMETHOD.

  METHOD zif_ark_gui_services~get_html_parts.
    ro_parts = mo_parts.
  ENDMETHOD.

  METHOD zif_ark_gui_services~register_event_handler.
    IF ii_event_handler IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE mt_event_handlers TRANSPORTING NO FIELDS
      WITH KEY table_line = ii_event_handler.
    IF sy-subrc <> 0.
      APPEND ii_event_handler TO mt_event_handlers.
    ENDIF.
  ENDMETHOD.

  METHOD get_asset_mime.
    DATA lt_mime TYPE STANDARD TABLE OF w3mime.
    DATA ls_mime TYPE w3mime.

    CALL FUNCTION 'WWWDATA_IMPORT'
      EXPORTING
        key               = VALUE wwwdatatab( relid = 'MI' objid = iv_mime_name )
      TABLES
        mime              = lt_mime
      EXCEPTIONS
        wrong_objecttype  = 1
        import_error      = 2
        OTHERS            = 3.

    IF sy-subrc <> 0.
      zcx_ark_exception=>raise( |MIME object { iv_mime_name } not found| ).
    ENDIF.

    LOOP AT lt_mime INTO ls_mime.
      rv_xdata = rv_xdata && ls_mime-line.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
