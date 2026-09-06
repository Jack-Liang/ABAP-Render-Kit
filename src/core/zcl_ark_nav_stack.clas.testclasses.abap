" 测试用页面替身：带自增 id 便于验证弹出顺序
CLASS lcl_nav_page DEFINITION FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable.
    DATA mv_id TYPE i .
ENDCLASS.

CLASS lcl_nav_page IMPLEMENTATION.
  METHOD zif_ark_gui_renderable~render.
    ri_html = zcl_ark_html=>create( ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_nav_stack DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA gv_seq TYPE i .

    "! 造一个 id 递增的页面替身
    METHODS new_page
      RETURNING
        VALUE(ro_page) TYPE REF TO lcl_nav_page .
    METHODS push_pop_lifo FOR TESTING.
    METHODS pop_empty_returns_initial FOR TESTING.
    METHODS clear FOR TESTING.
    METHODS depth_cap_keeps_newest FOR TESTING.
ENDCLASS.

CLASS ltcl_nav_stack IMPLEMENTATION.

  METHOD new_page.
    ro_page = NEW lcl_nav_page( ).
    gv_seq = gv_seq + 1.
    ro_page->mv_id = gv_seq.
  ENDMETHOD.

  METHOD push_pop_lifo.
    DATA lo_stack TYPE REF TO zcl_ark_nav_stack.
    lo_stack = NEW zcl_ark_nav_stack( ).

    DATA(lo_first) = new_page( ).
    DATA(lo_second) = new_page( ).
    lo_stack->push( lo_first ).
    lo_stack->push( lo_second ).
    cl_abap_unit_assert=>assert_equals( exp  = 2 act  = lo_stack->count( ) ).

    " 后进先出：弹回的是离开顺序的上一层
    DATA(lo_popped) = CAST lcl_nav_page( lo_stack->pop( ) ).
    cl_abap_unit_assert=>assert_equals( exp  = lo_second->mv_id act  = lo_popped->mv_id ).
    DATA(lo_popped2) = CAST lcl_nav_page( lo_stack->pop( ) ).
    cl_abap_unit_assert=>assert_equals( exp  = lo_first->mv_id act  = lo_popped2->mv_id ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = lo_stack->count( ) ).
  ENDMETHOD.

  METHOD pop_empty_returns_initial.
    DATA(lo_stack) = NEW zcl_ark_nav_stack( ).
    cl_abap_unit_assert=>assert_initial( lo_stack->pop( ) ).
  ENDMETHOD.

  METHOD clear.
    DATA(lo_stack) = NEW zcl_ark_nav_stack( ).
    lo_stack->push( new_page( ) ).
    lo_stack->push( new_page( ) ).
    lo_stack->clear( ).
    cl_abap_unit_assert=>assert_equals( exp  = 0 act  = lo_stack->count( ) ).
    cl_abap_unit_assert=>assert_initial( lo_stack->pop( ) ).
  ENDMETHOD.

  METHOD depth_cap_keeps_newest.
    DATA lo_stack TYPE REF TO zcl_ark_nav_stack.
    lo_stack = NEW zcl_ark_nav_stack( ).

    " 压入 上限+2 个：最旧的被丢弃，保留最新 50 个
    DATA(lv_times) = zcl_ark_nav_stack=>c_max_depth + 2.
    DATA lt_all TYPE STANDARD TABLE OF REF TO lcl_nav_page WITH EMPTY KEY.
    DO lv_times TIMES.
      DATA(lo_page) = new_page( ).
      APPEND lo_page TO lt_all.
      lo_stack->push( lo_page ).
    ENDDO.
    cl_abap_unit_assert=>assert_equals( exp  = zcl_ark_nav_stack=>c_max_depth act  = lo_stack->count( ) ).

    " 逐个弹出：第一枪是最新的（id 最大），弹尽后为空
    DATA(lo_top) = CAST lcl_nav_page( lo_stack->pop( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp  = zcl_ark_nav_stack=>c_max_depth + 2
      act  = lo_top->mv_id ).
    DATA(lv_rest) = zcl_ark_nav_stack=>c_max_depth - 1.
    DO lv_rest TIMES.
      lo_stack->pop( ).
    ENDDO.
    cl_abap_unit_assert=>assert_initial( lo_stack->pop( ) ).
  ENDMETHOD.

ENDCLASS.
