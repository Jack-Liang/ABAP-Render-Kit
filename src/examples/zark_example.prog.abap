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

* 接管 返回 / 取消 按键：F3/Back/Escape = 沿页面栈回上一层（与页面
* 统一返回条同语义），已在顶层则退出；F12/F15 = 退出程序
AT SELECTION-SCREEN ON EXIT-COMMAND.
  PERFORM exit.

FORM run.
  TRY.
      " zcl_ark_gui=>create( ) 默认挂在 cl_gui_container=>screen0 上，
      " screen0 绑定的是当前显示的屏幕，所以先建 GUI，再把宿主屏幕调出来
      zcl_ark_example_app=>run( ).
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

  DATA(lo_gui) = zcl_ark_gui=>get_instance( ).
  IF lo_gui IS INITIAL.
    LEAVE PROGRAM.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'F12' OR 'F15'.  " 取消 / 退出：直接结束程序
      lo_gui->free( ).
      LEAVE PROGRAM.
    WHEN 'CBAC' OR 'CCAN' OR 'F03'.
      " F3 / Back / Escape：沿页面栈回上一层（与页面统一返回条同语义），
      " 已在顶层（主页）才退出程序
      IF lo_gui->zif_ark_gui_services~is_at_home( ).
        lo_gui->free( ).
        LEAVE PROGRAM.
      ELSEIF lo_gui->go_back( ) = abap_false.
        " 无栈可弹（未注册主页的宿主形态）：停留当页
        lo_gui->render( ).
      ENDIF.
  ENDCASE.
ENDFORM.
