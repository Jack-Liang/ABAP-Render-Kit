CLASS zcl_ark_example_table_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_ui5_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! 经典主框架事件（工具栏 link 走 ark.nav 整页导航路径）
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    "! 桥事件（行编辑/删除/恢复 —— state 驱动就地更新）
    METHODS on_state_event REDEFINITION .

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_emp,
        id     TYPE string,
        name   TYPE string,
        dept   TYPE string,
        role   TYPE string,
        status TYPE string,
        sema   TYPE zif_ark_gui_state=>ty_semantic,
      END OF ty_emp,
      tt_emp TYPE STANDARD TABLE OF ty_emp WITH EMPTY KEY .

    DATA mt_emp TYPE tt_emp .
    DATA mv_message TYPE string .

    METHODS build_state .
ENDCLASS.

CLASS zcl_ark_example_table_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    build_state( ).
  ENDMETHOD.


  METHOD build_state.
    " 表格构建器示例（UI5 声明式版）：列/行/语义色/行内动作全部类型化
    " 描述，渲染交给启动壳（sap.m.Table）。行编辑/删除经桥回传后重建
    " state，就地更新不重启。7.57 规避：构造器浅层，先构变量逐行 APPEND
    DATA ls_state TYPE zif_ark_gui_state=>ty_page_state.
    DATA ls_section TYPE zif_ark_gui_state=>ty_section.
    DATA lt_cells TYPE zif_ark_gui_state=>tt_table_cell.
    DATA lv_subtitle TYPE string.

    IF mt_emp IS INITIAL.
      APPEND VALUE ty_emp( id = '001' name = 'Alice Smith'   dept = 'Engineering'
                          role = 'Developer' status = '在职'
                          sema = zif_ark_gui_state=>c_semantic-positive ) TO mt_emp.
      APPEND VALUE ty_emp( id = '002' name = 'Bob Johnson'   dept = 'Marketing'
                          role = 'Manager' status = '在职'
                          sema = zif_ark_gui_state=>c_semantic-positive ) TO mt_emp.
      APPEND VALUE ty_emp( id = '003' name = 'Charlie Brown' dept = 'Sales'
                          role = 'Sales Rep' status = '试用'
                          sema = zif_ark_gui_state=>c_semantic-critical ) TO mt_emp.
      APPEND VALUE ty_emp( id = '004' name = 'Diana Prince'  dept = 'HR'
                          role = 'Director' status = '休假'
                          sema = zif_ark_gui_state=>c_semantic-informative ) TO mt_emp.
      APPEND VALUE ty_emp( id = '005' name = 'Eve Davis'     dept = 'Engineering'
                          role = 'Tester' status = '离职中'
                          sema = zif_ark_gui_state=>c_semantic-negative ) TO mt_emp.
    ENDIF.

    lv_subtitle = '点击行内 编辑/删除 链接或工具栏按钮 —— 经桥回传后表格与行数就地更新'.
    IF mv_message IS NOT INITIAL.
      lv_subtitle = mv_message.
    ENDIF.

    ls_state = VALUE #( title = '表格构建器 · UI5'
                        subtitle = lv_subtitle ).

    ls_state-toolbar = VALUE #(
      ( kind = zif_ark_gui_state=>c_toolbar_kind-button
        label = '恢复全部行' action = 'tbl_restore' emphasized = abap_true )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-separator )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-text
        label = |共 { lines( mt_emp ) } 行| )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '表单示例' action = 'nav_form' )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '返回首页' action = 'nav_home' ) ).

    ls_section = VALUE zif_ark_gui_state=>ty_section(
      kind  = zif_ark_gui_state=>c_section_kind-table
      title = '员工名录'
      columns = VALUE #(
        ( label = 'ID' align_right = abap_true )
        ( label = '姓名' ) ( label = '部门' ) ( label = '角色' )
        ( label = '状态' ) ( label = '编辑' ) ( label = '删除' ) ) ).

    LOOP AT mt_emp INTO DATA(ls_emp).
      CLEAR lt_cells.
      APPEND VALUE #( value = ls_emp-id ) TO lt_cells.
      APPEND VALUE #( value = ls_emp-name ) TO lt_cells.
      APPEND VALUE #( value = ls_emp-dept ) TO lt_cells.
      APPEND VALUE #( value = ls_emp-role ) TO lt_cells.
      APPEND VALUE #( value = ls_emp-status semantic = ls_emp-sema ) TO lt_cells.
      APPEND VALUE #( value = '编辑' action = 'row_edit' ) TO lt_cells.
      APPEND VALUE #( value = '删除' action = 'row_del' ) TO lt_cells.
      APPEND VALUE #( cells = lt_cells ) TO ls_section-rows.
    ENDLOOP.

    APPEND ls_section TO ls_state-sections.

    set_state( ls_state ).
  ENDMETHOD.


  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN 'nav_form'.
        rs_result-page = NEW zcl_ark_example_form_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_state_event.
    DATA lv_row TYPE i.

    CASE ii_event->mv_action.
      WHEN 'row_edit'.
        " 单元格链接：前端附加 __row（1 基行号）
        mv_message = |行 { ii_event->query( '__row' ) } 编辑（桥往返，就地更新）|.
        build_state( ).

      WHEN 'row_del'.
        lv_row = CONV i( ii_event->query( '__row' ) ).
        IF lv_row >= 1 AND lv_row <= lines( mt_emp ).
          DELETE mt_emp INDEX lv_row.
          mv_message = |已删除第 { lv_row } 行（桥往返，表格就地重建）|.
        ENDIF.
        build_state( ).

      WHEN 'tbl_restore'.
        CLEAR mt_emp.
        mv_message = '已恢复全部 5 行（桥往返）'.
        build_state( ).

      WHEN OTHERS.
        rs_result = super->on_state_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
