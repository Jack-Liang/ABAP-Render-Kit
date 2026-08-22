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
    METHODS set_home_page
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable .
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
    DATA mo_home_page TYPE REF TO zif_ark_gui_renderable .
    DATA mo_parts TYPE REF TO zcl_ark_html_parts .
    DATA mt_event_handlers TYPE STANDARD TABLE OF REF TO zif_ark_gui_event_handler .
    DATA mo_container TYPE REF TO cl_gui_container .

    " 具名资产 -> load_data 分配的 URL。实例级缓存：
    " URL 绑定在当前 HTML 控件上，控件随实例销毁重建后缓存一并失效，
    " 不会残留指向旧控件的 URL
    TYPES:
      BEGIN OF ty_asset_cache,
        url          TYPE string,
        assigned_url TYPE string,
      END OF ty_asset_cache,
      tt_asset_cache TYPE HASHED TABLE OF ty_asset_cache WITH UNIQUE KEY url .
    DATA mt_asset_cache TYPE tt_asset_cache .

    METHODS render_page
      RETURNING VALUE(rv_html) TYPE string
      RAISING zcx_ark_exception .

    METHODS build_html_document
      IMPORTING !iv_content TYPE string
      RETURNING VALUE(rv_html) TYPE string .

    METHODS call_page_render
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
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
    " 有注册主页则回到主页对象；无注册时保持旧语义（清空页面）。
    " 旧实现无条件 CLEAR 后渲染，历史上从子页面"返回"会渲染出空骨架白屏
    IF mo_home_page IS NOT INITIAL.
      set_page( mo_home_page ).
      RETURN.
    ENDIF.

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

  METHOD set_home_page.
    " 注册主页：go_home / 退出键"返回主页"时重新渲染该对象。
    " 不触发渲染，通常与 set_page 一起在启动时调用
    mo_home_page = io_page.
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

    TYPES ty_c200 TYPE c LENGTH 200.
    DATA lt_data TYPE STANDARD TABLE OF ty_c200.
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

    " 防线：页面缺失时优先回退到注册的主页，仍无页面则渲染可见提示，
    " 避免无声的空白页（历史上 go_home 清空页面即渲染空骨架）
    IF mo_current_page IS INITIAL AND mo_home_page IS NOT INITIAL.
      mo_current_page = mo_home_page.
    ENDIF.

    IF mo_current_page IS NOT INITIAL.
      DATA(li_html) = call_page_render( ).
      IF li_html IS NOT INITIAL.
        lv_content = li_html->render( ).
      ENDIF.
    ELSE.
      lv_content = |<p style="color: #b91c1c;">ARK: no page set | &&
                   |(render before set_page / page was cleared)</p>|.
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
    " Default styles come from the theme (Fiori Quartz Light design tokens);
    " see zcl_ark_theme. Pages can override single tokens before render( ).
    rv_html = |<!DOCTYPE html>\n| &&
              |<html>\n| &&
              |<head>\n| &&
              |<meta charset="utf-8">\n| &&
              |<meta http-equiv="X-UA-Compatible" content="IE=edge">\n| &&
              |<style type="text/css">\n| &&
              zcl_ark_theme=>get_instance( )->get_css( ) &&
              |\n</style>\n| &&
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

    IF lv_handled = abap_false AND mo_current_page IS NOT INITIAL.
      TRY.
          DATA(lo_page) = CAST zcl_ark_gui_page( mo_current_page ).
          ls_result = lo_page->on_event( li_event ).
          IF ls_result-state IS NOT INITIAL.
            lv_handled = abap_true.
          ENDIF.
        CATCH cx_sy_move_cast_error zcx_ark_exception.
          " 当前页面不是 zcl_ark_gui_page 或处理出错，按未处理对待
      ENDTRY.
    ENDIF.

    IF lv_handled = abap_true.
      IF ls_result-page IS NOT INITIAL.
        set_page( ls_result-page ).
      ELSEIF ls_result-keep_view = abap_false.
        render( ).
      ENDIF.
      " keep_view = X：页面已就地更新（桥帧推送 state），主文档保持常驻
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

  METHOD zif_ark_gui_services~push_to_frame.
    IF mo_html_viewer IS INITIAL.
      zcx_ark_exception=>raise( 'HTML viewer not initialized' ).
    ENDIF.

    TYPES ty_c200 TYPE c LENGTH 200.
    DATA lt_data TYPE STANDARD TABLE OF ty_c200.
    DATA lv_size TYPE i.

    zcl_ark_convert=>string_to_tab(
      EXPORTING
        iv_str = iv_text
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

    mo_html_viewer->show_url(
      iv_url   = lv_assigned_url
      iv_frame = iv_frame ).
  ENDMETHOD.

  METHOD zif_ark_gui_services~cache_asset.
    DATA lv_url TYPE string.

    IF iv_url IS NOT INITIAL.
      lv_url = iv_url.

      READ TABLE mt_asset_cache INTO DATA(ls_cached) WITH KEY url = lv_url.
      IF sy-subrc = 0.
        rv_url = ls_cached-assigned_url.
        RETURN.
      ENDIF.
    ELSE.
      lv_url = |ark_asset_{ cl_abap_context_info=>get_system_time( ) }_{ sy-index }.txt|.
    ENDIF.

    TYPES ty_c200 TYPE c LENGTH 200.
    DATA lt_data TYPE STANDARD TABLE OF ty_c200.
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
      TYPES ty_x200 TYPE x LENGTH 200.
      DATA lt_bintab TYPE STANDARD TABLE OF ty_x200.
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

    " 具名资产登记进实例缓存，后续请求直接复用，不再重复上传
    IF iv_url IS NOT INITIAL AND rv_url IS NOT INITIAL.
      INSERT VALUE ty_asset_cache( url = lv_url assigned_url = rv_url )
        INTO TABLE mt_asset_cache.
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

ENDCLASS.
