CLASS zcl_ark_gui DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_services .

    "! 框架保留动作：统一返回（兼容别名；唯一登记处在 zcl_ark_actions）。
    "! render_page 在所有非主页页面顶部自动注入返回条，on_event 在业务
    "! 分发之前拦截并 go_back。业务动作不得使用 ark_ 前缀名字
    CONSTANTS c_action_back TYPE string VALUE zcl_ark_actions=>c_back .

    CLASS-METHODS get_instance
      RETURNING VALUE(ri_gui) TYPE REF TO zcl_ark_gui .

    "! 只读访问已存在的 GUI 实例（可能为空），绝不创建：
    "! 资产缓存等"有 GUI 才有意义"的调用方用它避免在无 GUI 环境
    "! （headless 测试/导出）强行拉起控件
    CLASS-METHODS peek
      RETURNING VALUE(ri_gui) TYPE REF TO zcl_ark_gui .

    CLASS-METHODS create
      IMPORTING !io_container TYPE REF TO cl_gui_container OPTIONAL
      RETURNING VALUE(ri_gui) TYPE REF TO zcl_ark_gui
      RAISING zcx_ark_exception .

    METHODS constructor
      IMPORTING !io_container TYPE REF TO cl_gui_container OPTIONAL
      RAISING zcx_ark_exception .

    METHODS go_home RAISING zcx_ark_exception .
    "! 弹回上一层页面（页面栈）。栈空时返回 abap_false 且不动作；
    "! 弹回的是离开时的页面实例，其状态原样恢复
    METHODS go_back
      RETURNING
        VALUE(rv_popped) TYPE abap_bool .
    METHODS set_page
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable
      RAISING zcx_ark_exception .
    METHODS set_home_page
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable .

    "! 当前页是否为注册的主页（按页面类的绝对类名比较，跨实例成立）。
    "! 宿主报表的 Back/Escape 处理用它替代对具体页面类名的字符串耦合
    METHODS is_at_home
      RETURNING VALUE(rv_yes) TYPE abap_bool .
    METHODS render .
    METHODS set_focus RAISING zcx_ark_exception .
    METHODS free .

    "! 构建当前页面的完整 HTML 文档字符串（不触碰 GUI 控件）。
    "! 供无头导出/自动化测试使用：拿到 HTML 后走 mock arkEmit 在
    "! 普通浏览器里做黑盒验证
    METHODS render_page
      RETURNING VALUE(rv_html) TYPE string
      RAISING zcx_ark_exception .

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
    "! 页面导航栈（不含当前页）：set_page 压入离开的页面实例，
    "! go_back 弹回——实例引用使子页面状态在返回后原样保留。
    "! 逻辑独立成 zcl_ark_nav_stack 以获得单测覆盖
    DATA mo_history TYPE REF TO zcl_ark_nav_stack .
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
    " 匿名资产文件名序号：sy-index 在非循环上下文恒为 0，同秒多资产会重名互覆
    DATA mv_asset_seq TYPE i .
    " 事件处理异常横幅（正式化：不再静默吞掉 handler 异常），
    " 下一次 render_page 输出一次即清空
    DATA mv_event_error TYPE string .

    METHODS build_html_document
      IMPORTING !iv_content TYPE string
      RETURNING VALUE(rv_html) TYPE string .

    "! 仅替换当前页引用与类名缓存，不渲染不入栈（set_page/go_home/go_back 共用）
    METHODS set_current
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable .

    METHODS call_page_render
      RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html
      RAISING zcx_ark_exception .
ENDCLASS.

CLASS zcl_ark_gui IMPLEMENTATION.

  METHOD constructor.
    mo_parts = NEW zcl_ark_html_parts( ).
    mo_history = NEW zcl_ark_nav_stack( ).

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

  METHOD peek.
    ri_gui = go_instance.
  ENDMETHOD.

  METHOD go_home.
    " 回到注册主页：清空导航栈（主页即顶层，无"再往后"）。
    " 无注册主页时保持旧语义（清空页面）
    mo_history->clear( ).
    set_current( mo_home_page ).
    render( ).
  ENDMETHOD.

  METHOD go_back.
    " 弹回上一层：恢复离开时的页面实例（含其状态），当前页不入栈。
    " 旧实现是 HTML 控件的浏览器历史回退——重放陈旧快照而非重渲染父页，
    " 与页面对象层完全脱节。栈空（已到顶层）时返回 abap_false 不动作
    DATA(lo_page) = mo_history->pop( ).
    IF lo_page IS INITIAL.
      rv_popped = abap_false.
      RETURN.
    ENDIF.

    set_current( lo_page ).
    rv_popped = abap_true.
    render( ).
  ENDMETHOD.

  METHOD set_page.
    " 导航入栈：把离开的页面实例压入历史（同实例重设不压，防双击累积）。
    " 首次 set_page（启动）时当前页为空，不入栈
    IF mo_current_page IS NOT INITIAL AND mo_current_page <> io_page.
      mo_history->push( mo_current_page ).
    ENDIF.

    set_current( io_page ).
    render( ).
  ENDMETHOD.

  METHOD set_current.
    mo_current_page = io_page.

    IF io_page IS NOT INITIAL.
      DATA lo_object TYPE REF TO object.
      lo_object ?= io_page.
      mv_current_page_name = cl_abap_classdescr=>get_class_name( lo_object ).
    ELSE.
      CLEAR mv_current_page_name.
    ENDIF.
  ENDMETHOD.

  METHOD set_home_page.
    " 注册主页：go_home / 退出键"返回主页"时重新渲染该对象。
    " 不触发渲染，通常与 set_page 一起在启动时调用
    mo_home_page = io_page.
  ENDMETHOD.

  METHOD is_at_home.
    " 按绝对类名比较：导航常创建主页的新实例，引用比较不成立
    IF mo_current_page IS INITIAL OR mo_home_page IS INITIAL.
      RETURN.
    ENDIF.
    rv_yes = xsdbool(
      cl_abap_classdescr=>describe_by_object_ref( mo_current_page )->absolute_name =
      cl_abap_classdescr=>describe_by_object_ref( mo_home_page )->absolute_name ).
  ENDMETHOD.

  METHOD render.
    DATA lv_html TYPE string.

    " 页面作用域去重集（js_library / js_bridge 的同页幂等注入）每次整页
    " 渲染前重置：页面 HTML 全量重建，注入标记必须随之失效
    zcl_ark_js_library=>reset_page_scope( ).

    TRY.
        lv_html = render_page( ).
      CATCH zcx_ark_exception INTO DATA(lx_error).
        lv_html = |<html><body><h1>Error</h1><p>{ zcl_ark_convert=>escape_html( lx_error->get_text( ) ) }</p></body></html>|.
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

    " 事件处理异常横幅：输出一次即清空（转义后插入，防二次注入）
    IF mv_event_error IS NOT INITIAL.
      lv_content = |<div class="ark-error-banner">{ zcl_ark_convert=>escape_html( mv_event_error ) }</div>|.
      CLEAR mv_event_error.
    ENDIF.

    " 防线：页面缺失时优先回退到注册的主页，仍无页面则渲染可见提示，
    " 避免无声的空白页（历史上 go_home 清空页面即渲染空骨架）
    IF mo_current_page IS INITIAL AND mo_home_page IS NOT INITIAL.
      mo_current_page = mo_home_page.
    ENDIF.

    " 统一返回条：所有非主页页面自动获得，位置固定（错误横幅之下、
    " 页面内容之上）。动作 ark_back 由 on_event 拦截弹回上一层
    IF mo_current_page IS NOT INITIAL AND is_at_home( ) = abap_false.
      lv_content = lv_content &&
        |<div class="ark-backbar"><a class="ark-back" | &&
        |href="sapevent:{ c_action_back }">&#8592; { zcl_ark_texts=>text( zcl_ark_texts=>c_key-back ) }</a></div>|.
    ENDIF.

    IF mo_current_page IS NOT INITIAL.
      DATA(li_html) = call_page_render( ).
      IF li_html IS NOT INITIAL.
        lv_content = lv_content && li_html->render( ).
      ENDIF.
    ELSE.
      lv_content = |<p style="color: #b91c1c;">{ zcl_ark_convert=>escape_html( zcl_ark_texts=>text( zcl_ark_texts=>c_key-no_page ) ) }</p>|.
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
    " 全局 JS 错误捕获：任何脚本报错直接画进 DOM —— 内核差异导致的"白屏"
    " 从此可见（JavaFX WebView 老版 WebKit 缺 ES6/API 时尤其关键）
    rv_html = |<!DOCTYPE html>\n| &&
              |<html>\n| &&
              |<head>\n| &&
              |<meta charset="utf-8">\n| &&
              |<meta http-equiv="X-UA-Compatible" content="IE=edge">\n| &&
              |<script type="text/javascript">\n| &&
              |window.onerror = function(msg, src, line, col) \{\n| &&
              |  var d = document.createElement('pre');\n| &&
              |  d.style.cssText = 'position:fixed;left:0;right:0;bottom:0;margin:0;padding:8px;' +\n| &&
              |    'background:#fee;color:#b00020;font:12px monospace;z-index:99999;' +\n| &&
              |    'border-top:2px solid #b00020;max-height:40%;overflow:auto;white-space:pre-wrap;';\n| &&
              |  d.textContent = 'JS ERROR: ' + msg + ' @' + (src \|\| '?') + ':' + (line \|\| '?');\n| &&
              |  document.body.appendChild(d);\n| &&
              |\};\n| &&
              |</script>\n| &&
              |<style type="text/css">\n| &&
              zcl_ark_theme=>get_instance( )->get_css( ) &&
              |\n</style>\n| &&
              |</head>\n| &&
              |<body>\n| &&
              |<div id="ark_busy" class="ark-busy">{ zcl_ark_convert=>escape_html( zcl_ark_texts=>text( zcl_ark_texts=>c_key-busy ) ) }</div>\n| &&
              |<script type="text/javascript">\n| &&
              |document.addEventListener('click', function(ev) \{\n| &&
              |  var t = ev.target;\n| &&
              |  var a = (t && t.closest) ? t.closest('a[href*="sapevent:"]') : null;\n| &&
              |  if (!a) return;\n| &&
              |  var b = document.getElementById('ark_busy');\n| &&
              |  if (b) b.style.display = 'flex';\n| &&
              |\}, true);\n| &&
              |document.addEventListener('submit', function() \{\n| &&
              |  var b = document.getElementById('ark_busy');\n| &&
              |  if (b) b.style.display = 'flex';\n| &&
              |  setTimeout(function() \{\n| &&
              |    var x = document.getElementById('ark_busy');\n| &&
              |    if (x) x.style.display = 'none';\n| &&
              |  \}, 30000);\n| &&
              |\}, true);\n| &&
              |</script>\n| &&
              |{ iv_content }\n| &&
              |</body>\n| &&
              |</html>|.
  ENDMETHOD.

  METHOD on_event.
    " 框架保留动作：统一返回。在注册 handler / 页面分发之前拦截，
    " 业务侧不可覆盖也不必实现（c_action_back 注释见类定义）
    IF action = zcl_ark_actions=>c_back.
      go_back( ).
      RETURN.
    ENDIF.

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
        CATCH zcx_ark_exception INTO DATA(lx_handler).
          " handler 异常同样转为可见横幅，不再无声跳过
          mv_event_error = lx_handler->get_text( ).
      ENDTRY.
    ENDLOOP.

    IF lv_handled = abap_false AND mo_current_page IS NOT INITIAL.
      TRY.
          DATA(lo_page) = CAST zcl_ark_gui_page( mo_current_page ).
          ls_result = lo_page->on_event( li_event ).
          IF ls_result-state IS NOT INITIAL.
            lv_handled = abap_true.
          ENDIF.
        CATCH cx_sy_move_cast_error.
          " 当前页面不是 zcl_ark_gui_page：按未处理对待
        CATCH zcx_ark_exception INTO DATA(lx_page).
          " 正式化：handler 异常不再静默吞掉 —— 渲染当页 + 错误横幅，
          " 用户能看到出错了以及原因（文本已转义）
          mv_event_error = lx_page->get_text( ).
          lv_handled = abap_true.
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
      mv_asset_seq = mv_asset_seq + 1.
      lv_url = |ark_asset_{ cl_abap_context_info=>get_system_time( ) }_{ mv_asset_seq }.txt|.
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

  METHOD zif_ark_gui_services~is_at_home.
    rv_yes = is_at_home( ).
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
