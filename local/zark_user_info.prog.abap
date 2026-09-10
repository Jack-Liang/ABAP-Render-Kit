*&---------------------------------------------------------------------*
*& Report ZARK_USER_INFO
*&---------------------------------------------------------------------*
*& 用户账号信息（声明式 state 页面）：
*&   1) 账号有效期进度条：开始~结束日期 + 已使用天数/总天数
*&   2) 账号明细表：账号 / 姓名 / 有效期起止 / 最近登录 / 锁定状态
*& 数据源：USR02（有效期/最近登录/锁定）+ USER_ADDR（姓名）。
*&
*& 依赖框架能力：zif_ark_gui_state 的 progress 节类型（2026-09-10 之后
*& 的 zif_ark_gui_state + zcl_ark_state_page + zcl_ark_theme）。
*& 纯声明式：业务侧只填类型化 state，零 HTML。
*&---------------------------------------------------------------------*
REPORT zark_user_info.

PARAMETERS p_user TYPE xubname DEFAULT sy-uname.

*----------------------------------------------------------------------*
* CLASS lcl_user_page DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_user_page DEFINITION
  INHERITING FROM zcl_ark_state_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING !iv_user TYPE xubname .

  PRIVATE SECTION.
    METHODS build_state .

    "! 约定式动作：工具栏 '刷新'（action = refresh）
    METHODS on_action_refresh
      IMPORTING !ii_event        TYPE REF TO zif_ark_gui_event
      RETURNING VALUE(rs_result) TYPE zif_ark_gui_event_handler=>ty_handling_result
      RAISING   zcx_ark_exception .

    "! DATS -> 'yyyy-MM-dd'；初始日期显示占位文本
    CLASS-METHODS fmt_date
      IMPORTING !iv_date       TYPE d
                !iv_blank      TYPE string DEFAULT '—'
      RETURNING VALUE(rv_text) TYPE string .

    "! 有效期 -> 进度条项：永久/过期/未生效/正常四种形态，
    "! 进度 = 已使用天数占比，>=90% 转橙色预警
    CLASS-METHODS validity_item
      IMPORTING !iv_from       TYPE d
                !iv_to         TYPE d
      RETURNING VALUE(rs_item) TYPE zif_ark_gui_state=>ty_progress_item .

    DATA mv_user TYPE xubname .
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS lcl_user_page IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_user_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_user = iv_user.
    build_state( ).
  ENDMETHOD.

  METHOD build_state.
    DATA ls_prog_item TYPE zif_ark_gui_state=>ty_progress_item.
    DATA lt_cells     TYPE zif_ark_gui_state=>tt_table_cell.
    DATA lt_rows      TYPE zif_ark_gui_state=>tt_table_rows.
    DATA ls_section   TYPE zif_ark_gui_state=>ty_section.

    SELECT SINGLE bname, gltgv, gltgb, trdat, ltime, uflag
      FROM usr02
      WHERE bname = @mv_user
      INTO @DATA(ls_usr02).
    IF sy-subrc <> 0.
      set_state( VALUE zif_ark_gui_state=>ty_page_state(
        title    = '用户账号信息'
        subtitle = |账号 { mv_user } 不存在| ) ).
      RETURN.
    ENDIF.

    SELECT SINGLE name_text
      FROM user_addr
      WHERE bname = @mv_user
      INTO @DATA(lv_name).

    DATA(ls_state) = VALUE zif_ark_gui_state=>ty_page_state(
      title    = '用户账号信息'
      subtitle = COND string( WHEN lv_name IS NOT INITIAL
                              THEN |账号 { ls_usr02-bname } · { lv_name }|
                              ELSE |账号 { ls_usr02-bname }| ) ).

    ls_state-toolbar = VALUE #(
      ( kind = zif_ark_gui_state=>c_toolbar_kind-button
        label = '刷新' action = 'refresh' emphasized = abap_true ) ).

    " ---- 账号有效期进度条 ----
    ls_prog_item = validity_item( iv_from = ls_usr02-gltgv
                                  iv_to   = ls_usr02-gltgb ).
    ls_section = VALUE zif_ark_gui_state=>ty_section(
      kind  = zif_ark_gui_state=>c_section_kind-progress
      title = '账号有效期'
      progress_items = VALUE #( ( ls_prog_item ) ) ).
    APPEND ls_section TO ls_state-sections.

    " ---- 账号明细表（键值行，状态列带语义色）----
    DATA(lv_lastlog) = COND string(
      WHEN ls_usr02-trdat IS INITIAL THEN '从未登录'
      WHEN ls_usr02-ltime IS INITIAL THEN |{ ls_usr02-trdat DATE = ISO }|
      ELSE |{ ls_usr02-trdat DATE = ISO } { ls_usr02-ltime TIME = ISO }| ).

    lt_cells = VALUE #( ( value = '用户账号' )
                        ( value = CONV string( ls_usr02-bname ) ) ).
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.
    lt_cells = VALUE #( ( value = '姓名' )
                        ( value = COND string( WHEN lv_name IS NOT INITIAL
                                               THEN lv_name ELSE '—' ) ) ).
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.
    lt_cells = VALUE #( ( value = '有效期开始' )
                        ( value = fmt_date( iv_date  = ls_usr02-gltgv
                                            iv_blank = '不限' ) ) ).
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.
    lt_cells = VALUE #( ( value = '有效期结束' )
                        ( value = fmt_date( iv_date  = ls_usr02-gltgb
                                            iv_blank = '不限' ) ) ).
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.
    lt_cells = VALUE #( ( value = '最近登录' )
                        ( value = lv_lastlog ) ).
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.
    IF ls_usr02-uflag = 0.
      lt_cells = VALUE #( ( value = '状态' )
        ( value = '正常' semantic = zif_ark_gui_state=>c_semantic-positive ) ).
    ELSE.
      lt_cells = VALUE #( ( value = '状态' )
        ( value = '已锁定' semantic = zif_ark_gui_state=>c_semantic-negative ) ).
    ENDIF.
    APPEND VALUE #( cells = lt_cells ) TO lt_rows.

    CLEAR ls_section.
    ls_section = VALUE zif_ark_gui_state=>ty_section(
      kind    = zif_ark_gui_state=>c_section_kind-table
      title   = '账号明细'
      columns = VALUE #( ( label = '项目' ) ( label = '内容' ) )
      rows    = lt_rows ).
    APPEND ls_section TO ls_state-sections.

    set_state( ls_state ).
  ENDMETHOD.

  METHOD on_action_refresh.
    build_state( ).
    rs_result-state = 1.
  ENDMETHOD.

  METHOD fmt_date.
    IF iv_date IS INITIAL.
      rv_text = iv_blank.
    ELSE.
      rv_text = |{ iv_date DATE = ISO }|.
    ENDIF.
  ENDMETHOD.

  METHOD validity_item.
    DATA lv_today TYPE d.
    DATA lv_total TYPE i.
    DATA lv_used  TYPE i.
    DATA lv_pct   TYPE i.
    lv_today = sy-datum.

    " 无到期日：不限期账号
    IF iv_to IS INITIAL.
      rs_item = VALUE #(
        label      = |{ fmt_date( iv_from ) } 起 · 无到期日|
        value_text = '永久有效'
        percent    = 0
        semantic   = zif_ark_gui_state=>c_semantic-positive ).
      RETURN.
    ENDIF.

    " 已过期：条拉满标红
    IF lv_today > iv_to.
      rs_item = VALUE #(
        label      = |{ fmt_date( iv_from ) } ~ { fmt_date( iv_to ) }|
        value_text = |已过期 { lv_today - iv_to } 天|
        percent    = 100
        semantic   = zif_ark_gui_state=>c_semantic-negative ).
      RETURN.
    ENDIF.

    " 未生效 / 起始日不限：条空，只报剩余天数
    IF iv_from IS INITIAL OR lv_today < iv_from.
      rs_item = VALUE #(
        label      = |{ fmt_date( iv_from ) } 起 · 至 { fmt_date( iv_to ) } 到期|
        value_text = |剩余 { iv_to - lv_today } 天|
        percent    = 0
        semantic   = zif_ark_gui_state=>c_semantic-informative ).
      RETURN.
    ENDIF.

    lv_total = iv_to - iv_from + 1.
    lv_used  = lv_today - iv_from + 1.
    lv_pct   = CONV i( round( val = CONV decfloat16( lv_used ) * 100
                                / CONV decfloat16( lv_total ) dec = 0 ) ).
    rs_item = VALUE #(
      label      = |{ fmt_date( iv_from ) } ~ { fmt_date( iv_to ) }|
      value_text = |已使用 { lv_used } / { lv_total } 天|
      percent    = lv_pct
      semantic   = COND #( WHEN lv_pct >= 90
                           THEN zif_ark_gui_state=>c_semantic-critical
                           ELSE zif_ark_gui_state=>c_semantic-positive ) ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* 空选择屏幕 1001 作为 HTML 控件的宿主屏幕（1000 为账号选择屏）
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 1001.
SELECTION-SCREEN END OF SCREEN 1001.

START-OF-SELECTION.
  PERFORM run.

AT SELECTION-SCREEN OUTPUT.
  PERFORM output.

AT SELECTION-SCREEN ON EXIT-COMMAND.
  PERFORM exit.


FORM run.
  TRY.
      DATA(lo_gui) = zcl_ark_gui=>create( ).
      lo_gui->set_page( NEW lcl_user_page( iv_user = p_user ) ).
      CALL SELECTION-SCREEN 1001.
    CATCH zcx_ark_exception INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM output.
  " 1000 屏是账号选择屏，保持标准状态；1001 才是 HTML 宿主
  IF sy-dynnr <> 1001.
    RETURN.
  ENDIF.

  DATA lt_ucomm TYPE TABLE OF sy-ucomm.

  APPEND 'CRET' TO lt_ucomm.
  APPEND 'SPOS' TO lt_ucomm.

  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = lt_ucomm.

  TRY.
      zcl_ark_gui=>get_instance( )->set_focus( ).
    CATCH zcx_ark_exception.
  ENDTRY.
ENDFORM.

FORM exit.
  IF sy-dynnr <> 1001.
    RETURN.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'CBAC' OR 'CCAN'.
      DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
      IF lo_gui IS NOT INITIAL.
        lo_gui->free( ).
      ENDIF.
      LEAVE PROGRAM.
  ENDCASE.
ENDFORM.
