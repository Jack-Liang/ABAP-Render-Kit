REPORT zark_example.

* 空选择屏幕 1001 作为 HTML 控件的宿主屏幕
* (HTML Viewer 需要一个真实存在的屏幕；Java SAP GUI 下同样必须)
SELECTION-SCREEN BEGIN OF SCREEN 1001.
SELECTION-SCREEN END OF SCREEN 1001.

START-OF-SELECTION.
  PERFORM run.

* 隐藏选择屏幕上的 Execute / Save 按钮，把焦点交给 HTML 控件
AT SELECTION-SCREEN OUTPUT.
  PERFORM output.

* 接管 返回 / 取消 按键：子页面返回主页，主页再按则退出
AT SELECTION-SCREEN ON EXIT-COMMAND.
  PERFORM exit.

FORM run.
  TRY.
      " zcl_ark_gui=>create( ) 默认挂在 cl_gui_container=>screen0 上，
      " screen0 绑定的是当前显示的屏幕，所以先建 GUI，再把宿主屏幕调出来
      zcl_ark_example_app=>main( ).
      CALL SELECTION-SCREEN 1001.
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
  " 只处理宿主屏幕 1001 的退出命令
  IF sy-dynnr <> 1001.
    RETURN.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'CBAC' OR 'CCAN'.  " Back 与 Escape
      DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
      IF lo_gui IS INITIAL.
        LEAVE PROGRAM.
      ENDIF.

      DATA(lv_page) = lo_gui->zif_ark_gui_services~get_current_page_name( ).
      IF lv_page IS INITIAL OR lv_page CS 'HELLO_PAGE'.
        " 已在主页：释放资源并退出程序
        lo_gui->free( ).
        LEAVE PROGRAM.
      ELSE.
        " 子页面：返回主页
        lo_gui->go_home( ).
      ENDIF.
  ENDCASE.
ENDFORM.
