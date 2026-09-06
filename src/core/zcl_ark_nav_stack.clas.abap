CLASS zcl_ark_nav_stack DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! 深度上限：防导航环（A→B→A→B…）无限累积，超出丢弃最旧条目
    CONSTANTS c_max_depth TYPE i VALUE 50 .

    "! 压入一个页面实例（调用方负责跳过空引用与同实例重复压栈）
    METHODS push
      IMPORTING !io_page TYPE REF TO zif_ark_gui_renderable .

    "! 弹出栈顶页面实例；栈空返回初始引用
    METHODS pop
      RETURNING
        VALUE(ro_page) TYPE REF TO zif_ark_gui_renderable .

    METHODS clear .
    METHODS count
      RETURNING
        VALUE(rv_count) TYPE i .

  PRIVATE SECTION.
    DATA mt_pages TYPE STANDARD TABLE OF REF TO zif_ark_gui_renderable WITH EMPTY KEY .
ENDCLASS.

CLASS zcl_ark_nav_stack IMPLEMENTATION.

  METHOD push.
    APPEND io_page TO mt_pages.
    IF lines( mt_pages ) > c_max_depth.
      DELETE mt_pages INDEX 1.
    ENDIF.
  ENDMETHOD.

  METHOD pop.
    DATA(lv_last) = lines( mt_pages ).
    IF lv_last = 0.
      RETURN.
    ENDIF.
    READ TABLE mt_pages INDEX lv_last INTO ro_page.
    DELETE mt_pages INDEX lv_last.
  ENDMETHOD.

  METHOD clear.
    CLEAR mt_pages.
  ENDMETHOD.

  METHOD count.
    rv_count = lines( mt_pages ).
  ENDMETHOD.

ENDCLASS.
