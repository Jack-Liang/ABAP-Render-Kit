CLASS zcl_ark_example_form_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_ui5_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! 经典主框架事件（工具栏 link 走 ark.nav 整页导航路径）
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    "! 桥事件（随机填充 / 表单提交经桥 POST 回传）
    METHODS on_state_event REDEFINITION .

  PRIVATE SECTION.
    DATA mv_firstname TYPE string VALUE 'John' ##NO_TEXT.
    DATA mv_lastname TYPE string VALUE 'Doe' ##NO_TEXT.
    DATA mv_email TYPE string VALUE 'john.doe@example.com' ##NO_TEXT.
    DATA mv_country TYPE string VALUE 'Germany' ##NO_TEXT.
    DATA mv_comments TYPE string VALUE 'This is a sample comment.' ##NO_TEXT.
    DATA mv_message TYPE string .

    METHODS build_state .

    METHODS post_value
      IMPORTING
        !ii_event       TYPE REF TO zif_ark_gui_event
        !iv_name        TYPE string
      RETURNING VALUE(rv_value) TYPE string .
ENDCLASS.

CLASS zcl_ark_example_form_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    build_state( ).
  ENDMETHOD.


  METHOD build_state.
    " 表单构建器示例（UI5 声明式版）：字段类型化描述，渲染交给启动壳，
    " 提交经 sapevent 桥 POST 回传（隐藏 iframe + __ark 标记），
    " 处理后新 state 回推就地更新，UI5 常驻不重启。
    " 7.57 规避：构造器浅层 —— 单行 APPEND、先构变量，括号内无跨行链
    DATA ls_state TYPE zif_ark_gui_state=>ty_page_state.
    DATA lt_fields TYPE zif_ark_gui_state=>tt_form_field.
    DATA lt_options TYPE string_table.
    DATA lv_subtitle TYPE string.

    lv_subtitle = '声明式表单字段 → 提交经桥 POST 回传，字段值与副标题就地更新'.
    ls_state = VALUE #( title = '表单构建器 · UI5'
                        subtitle = lv_subtitle ).

    ls_state-toolbar = VALUE #(
      ( kind = zif_ark_gui_state=>c_toolbar_kind-button
        label = '随机填充' action = 'form_random' emphasized = abap_true )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-separator )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-text
        label = |国家: { mv_country }| )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '表格示例' action = 'nav_table' )
      ( kind = zif_ark_gui_state=>c_toolbar_kind-link
        label = '返回首页' action = 'nav_home' ) ).

    APPEND VALUE #( input_type = 'text' label = '名' name = 'firstname'
                    value = mv_firstname ) TO lt_fields.
    APPEND VALUE #( input_type = 'text' label = '姓' name = 'lastname'
                    value = mv_lastname ) TO lt_fields.
    APPEND VALUE #( input_type = 'email' label = '邮箱' name = 'email'
                    value = mv_email ) TO lt_fields.

    lt_options = VALUE #( ( `Germany` ) ( `USA` ) ( `China` ) ( `Japan` ) ).
    APPEND VALUE #( input_type = 'select' label = '国家' name = 'country'
                    value = mv_country options = lt_options ) TO lt_fields.

    APPEND VALUE #( input_type = 'textarea' label = '备注' name = 'comments'
                    value = mv_comments ) TO lt_fields.
    APPEND VALUE #( input_type = 'hidden' name = 'form_id' value = '12345' ) TO lt_fields.
    APPEND VALUE #( input_type = 'submit' value = '提交（经桥 POST）' ) TO lt_fields.

    APPEND VALUE zif_ark_gui_state=>ty_section(
      kind = zif_ark_gui_state=>c_section_kind-form
      title = '员工信息'
      form_action = 'form_submit'
      form_fields = lt_fields ) TO ls_state-sections.

    IF mv_message IS NOT INITIAL.
      ls_state-subtitle = mv_message.
    ENDIF.

    set_state( ls_state ).
  ENDMETHOD.


  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN 'nav_table'.
        rs_result-page = NEW zcl_ark_example_table_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_state_event.
    DATA lv_rand TYPE i.

    CASE ii_event->mv_action.
      WHEN 'form_random'.
        " 桥事件演示：服务端生成样例值，回推后表单就地更新
        lv_rand = ( sy-uzeit MOD 900 ) + 100.
        mv_firstname = |John{ lv_rand }|.
        mv_lastname  = |Doe{ lv_rand }|.
        mv_email     = |john{ lv_rand }@example.com|.
        mv_comments  = |Sample comment #{ lv_rand }（桥往返生成）|.
        mv_message   = |已随机填充 #{ lv_rand }（桥往返，UI5 未重启）|.
        build_state( ).

      WHEN 'form_submit'.
        " 表单经桥 POST：postdata 各行为 255 字符片段，拼接后按名值对解析，
        " 值经 URL 解码后回显到字段（演示提交 → state 回推闭环）
        mv_firstname = post_value( ii_event = ii_event iv_name = 'firstname' ).
        mv_lastname  = post_value( ii_event = ii_event iv_name = 'lastname' ).
        mv_email     = post_value( ii_event = ii_event iv_name = 'email' ).
        mv_country   = post_value( ii_event = ii_event iv_name = 'country' ).
        mv_comments  = post_value( ii_event = ii_event iv_name = 'comments' ).
        mv_message   = |提交已处理: { mv_firstname } { mv_lastname }|
                    && | <{ mv_email }> · 国家 { mv_country }（经桥 POST）|.
        build_state( ).

      WHEN OTHERS.
        rs_result = super->on_state_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD post_value.
    " postdata 形如 name=value&name2=value2（urlencoded），取字段并解码
    DATA lv_body TYPE string.
    DATA lv_pair TYPE string.
    DATA lv_name TYPE string.
    DATA lv_value TYPE string.

    LOOP AT ii_event->mt_postdata INTO DATA(lv_line).
      lv_body = lv_body && lv_line.
    ENDLOOP.

    SPLIT lv_body AT '&' INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO lv_pair.
      SPLIT lv_pair AT '=' INTO lv_name lv_value.
      IF lv_name = iv_name.
        rv_value = zcl_ark_convert=>url_decode( lv_value ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
