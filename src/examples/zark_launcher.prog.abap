"! ARK 通用应用启动器 —— App 端零样板入口。
"!
"! 你的应用不再需要复制宿主屏幕样板：建一个继承 zcl_ark_gui_page（或
"! zcl_ark_state_page）的页面类，然后二选一：
"!   a) 建一个 transaction code 指向本报表，启动后输入页面类名（或绑定
"!      事务码变体预设 P_PAGE）；
"!   b) 建事务码时直接带启动参数：SE38 里为 ZARK_LAUNCHER 建事务码，
"!      "跳过起始屏幕" 填 P_PAGE = 你的页面类名（如 ZCL_MY_MAIN_PAGE）。
"!
"! 页面类可选实现约定式动作处理器：on_action_<动作名>（基类自动分发）。
REPORT zark_launcher.

* 空选择屏幕 1001 作为 HTML 控件的宿主屏幕（HTML Viewer 需要真实屏幕）
SELECTION-SCREEN BEGIN OF SCREEN 1001.
SELECTION-SCREEN END OF SCREEN 1001.

PARAMETERS p_page TYPE char40 OBLIGATORY LOWER CASE.

START-OF-SELECTION.
  PERFORM run.

AT SELECTION-SCREEN OUTPUT.
  PERFORM output.

AT SELECTION-SCREEN ON EXIT-COMMAND.
  PERFORM exit.

FORM run.
  " 类名校验：仅允许本框架命名空间字符，防动态对象注入
  IF p_page CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'.
    MESSAGE |页面类名只能包含字母/数字/下划线: { p_page }| TYPE 'E'.
    RETURN.
  ENDIF.

  DATA lo_page TYPE REF TO zcl_ark_gui_page.
  TRY.
      " zcl_ark_gui=>create( ) 默认挂在 screen0 上：先建 GUI 再调宿主屏幕
      CREATE OBJECT lo_page TYPE (p_page).
      zcl_ark_gui=>create( )->set_page( lo_page ).
      CALL SELECTION-SCREEN 1001.
    CATCH cx_sy_create_object_error.
      MESSAGE |页面类不存在或不是 zcl_ark_gui_page 子类: { p_page }| TYPE 'E'.
    CATCH zcx_ark_exception INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM output.
  DATA lt_ucomm TYPE TABLE OF sy-ucomm.
  APPEND 'CRET' TO lt_ucomm.  " Execute 按钮
  APPEND 'SPOS' TO lt_ucomm.  " Save 按钮
  CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
    EXPORTING
      p_status  = sy-pfkey
    TABLES
      p_exclude = lt_ucomm.
  TRY.
      zcl_ark_gui=>get_instance( )->set_focus( ).
    CATCH zcx_ark_exception.
      " 忽略焦点设置失败
  ENDTRY.
ENDFORM.

FORM exit.
  IF sy-dynnr <> 1001.
    RETURN.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'CBAC' OR 'CCAN'.  " Back 与 Escape
      " 启动器没有主页语义：直接退出程序（页面内部的 Back 由应用自管）
      DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
      IF lo_gui IS NOT INITIAL.
        lo_gui->free( ).
      ENDIF.
      LEAVE PROGRAM.
  ENDCASE.
ENDFORM.
