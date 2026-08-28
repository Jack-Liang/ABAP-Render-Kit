CLASS zcl_ark_ui5_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! 桥协议分发：__ark=1 事件 → on_state_event 后回推 state（keep_view，
    "! UI5 常驻不重载）；其余走经典处理器链。子类需要自定义经典动作
    "! （如主页返回）时重定义 on_event，对未处理事件委托 super->on_event
    METHODS on_event REDEFINITION .

    "! Replace the whole page state in one call (full schema control)
    METHODS set_state
      IMPORTING !is_state TYPE zif_ark_gui_state=>ty_page_state .

    "! Append a fully configured section (table / form / kpi_grid / chart)
    METHODS add_section
      IMPORTING !is_section TYPE zif_ark_gui_state=>ty_section .

    METHODS set_subtitle
      IMPORTING !iv_subtitle TYPE string .

    "! Page-level toolbar items
    METHODS add_button
      IMPORTING
        !iv_label      TYPE string
        !iv_action     TYPE string
        !iv_parameters TYPE string OPTIONAL
        !iv_emphasized TYPE abap_bool DEFAULT abap_false .
    METHODS add_link
      IMPORTING
        !iv_label  TYPE string
        !iv_action TYPE string .
    METHODS add_tooltext
      IMPORTING !iv_text TYPE string .
    METHODS add_toolseparator .

  PROTECTED SECTION.
    "! 当前页面 state：构造时填充，on_state_event 中重建后由框架回推
    DATA ms_state TYPE zif_ark_gui_state=>ty_page_state .

    METHODS build_html REDEFINITION .

    "! 桥事件钩子：前端经 ark.state()/桥表单触发（带 __ark=1 标记）的
    "! 交互。实现里重建 ms_state（或返回新页面），返回后框架自动把
    "! ms_state 回推给常驻主页面（keep_view，UI5 不重启）。
    "! 约定：不处理也无需返回 state —— 框架无条件回推当前 state 作为 ack；
    "! 返回 page 则跳过回推，主框架整页切换到新页面
    METHODS on_state_event
      IMPORTING !ii_event TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result .

    "! 当前 ms_state 序列化后经 ark_bridge 帧回投（桥响应通道）
    METHODS push_state RAISING zcx_ark_exception .

  PRIVATE SECTION.
    "! 桥事件判定：URL 查询参数 __ark=1，或（表单 POST 时 viewer 可能
    "! 不解析 action URL 查询）postdata 中的隐藏字段 __ark=1
    METHODS is_bridge_event
      IMPORTING !ii_event      TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rv_flag) TYPE abap_bool .

    METHODS post_body
      IMPORTING !ii_event      TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rv_body) TYPE string .
ENDCLASS.

CLASS zcl_ark_ui5_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.


  METHOD on_event.
    IF is_bridge_event( ii_event ) = abap_true.
      rs_result = on_state_event( ii_event ).
      IF rs_result-page IS INITIAL.
        " 就地更新：当前 ms_state 回推桥帧，主页面不重渲染（UI5 常驻）
        push_state( ).
        rs_result-state = 1.
        rs_result-keep_view = abap_true.
      ELSE.
        " 页面跳转：主框架整页切换（桥帧随文档替换消亡，无需回推）
        rs_result-state = 1.
      ENDIF.
    ELSE.
      rs_result = super->on_event( ii_event ).
    ENDIF.
  ENDMETHOD.


  METHOD set_state.
    ms_state = is_state.
    IF ms_state-title IS NOT INITIAL.
      set_title( ms_state-title ).
    ENDIF.
  ENDMETHOD.


  METHOD set_subtitle.
    ms_state-subtitle = iv_subtitle.
  ENDMETHOD.


  METHOD add_section.
    APPEND is_section TO ms_state-sections.
  ENDMETHOD.


  METHOD add_button.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind       = zif_ark_gui_state=>c_toolbar_kind-button
      label      = iv_label
      action     = iv_action
      parameters = iv_parameters
      emphasized = iv_emphasized
      enabled    = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.


  METHOD add_link.
    " link 类工具栏项在前端走主框架导航（ark.nav，整页切换路径），
    " 与 A 路线 render_toolbar 的恒可点语义一致
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-link
      label   = iv_label
      action  = iv_action
      enabled = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.


  METHOD add_tooltext.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-text
      label   = iv_text ) TO ms_state-toolbar.
  ENDMETHOD.


  METHOD add_toolseparator.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind = zif_ark_gui_state=>c_toolbar_kind-separator ) TO ms_state-toolbar.
  ENDMETHOD.


  METHOD build_html.
    " 整份文档 = UI5 启动壳 + 内嵌初始 state；业务侧不写任何 HTML
    mo_html = zcl_ark_ui5_shell=>render( ms_state ).
    ri_html = mo_html.
  ENDMETHOD.


  METHOD on_state_event.
    " 默认不处理：框架仍会回推当前 state 作为交互 ack
    rs_result-state = 0.
  ENDMETHOD.


  METHOD push_state.
    " 桥协议响应：state JSON 经 ark_bridge 帧回投，帧内脚本 postMessage
    " 给常驻主页面（壳 JS 的 ark.receive → 就地更新）。
    " __ark_state 标记用于主页面过滤无关 message 事件。
    " 值含 </ 会截断脚本块，按 JSON 转义规则替换（\/ 是合法 JSON 转义）
    DATA(lv_json) = zcl_ark_json=>to_json( ms_state ).
    lv_json = replace( val = lv_json sub = `</` with = `<\/` occ = 0 ).

    " 金丝雀：响应文档若落入主框架（FRAME 未命中 ark_bridge），只改标题
    " 留痕，不破坏页面 —— 正常落帧则 postMessage 回主页面。
    " 推帧异常必须吞掉（宿主实证 6a7404c）：异常冒泡会触发框架兜底
    " render() 整页重载 → 页面重 boot → 再触发 → 白屏循环；吞掉后
    " 保持 keep_view 语义，前端表现为该项超时，页面存活可继续交互
    TRY.
        get_services( )->push_to_frame(
          iv_frame = zcl_ark_ui5_shell=>c_bridge_frame
          iv_text  = `<script>try{if(window.parent===window){` &&
                     `document.title='ARK: bridge frame miss';}else{` &&
                     `parent.postMessage({__ark_state:1,payload: ` && lv_json &&
                     `},'*');}}catch(e){}</script>` ).
      CATCH zcx_ark_exception.
        " 推帧失败（FRAME 参数在该内核不可用等）：保持 keep_view，不重渲染
    ENDTRY.
  ENDMETHOD.


  METHOD is_bridge_event.
    IF ii_event->query( zcl_ark_ui5_shell=>c_bridge_param ) = '1'.
      rv_flag = abap_true.
      RETURN.
    ENDIF.

    FIND REGEX `(^|&)__ark=1(&|$)` IN post_body( ii_event ).
    rv_flag = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD post_body.
    " postdata 各行为 255 字符片段，拼接后按名值对解析
    LOOP AT ii_event->mt_postdata INTO DATA(lv_line).
      rv_body = rv_body && lv_line.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
