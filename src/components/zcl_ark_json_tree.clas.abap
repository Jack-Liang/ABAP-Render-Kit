CLASS zcl_ark_json_tree DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_gui_renderable .

    CLASS-METHODS create
      IMPORTING
        !iv_json TYPE string
      RETURNING VALUE(ri_tree) TYPE REF TO zcl_ark_json_tree .

    METHODS constructor
      IMPORTING
        !iv_json TYPE string .

    "! Initial expand state of all collapsible nodes (default collapsed).
    "! Re-render the page with a flipped value for the expand-all /
    "! collapse-all sapevent pattern
    METHODS set_open
      IMPORTING
        !iv_open TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ri_self) TYPE REF TO zcl_ark_json_tree .

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_json TYPE string .
    DATA mv_open TYPE abap_bool VALUE abap_false ##NO_TEXT.

    METHODS render_tree
      RETURNING VALUE(ri_html) TYPE REF TO zcl_ark_html .

    "! 进入时 reader 停在 element_open 上；递归消费到本元素的 close
    METHODS parse_node
      IMPORTING
        !ii_reader TYPE REF TO if_sxml_reader
        !iv_index  TYPE string
      RETURNING VALUE(rv_html) TYPE string .

    METHODS key_html
      IMPORTING
        !iv_key      TYPE string
        !iv_is_index TYPE abap_bool
      RETURNING VALUE(rv_html) TYPE string .
ENDCLASS.



CLASS zcl_ark_json_tree IMPLEMENTATION.

  METHOD create.
    CREATE OBJECT ri_tree
      EXPORTING
        iv_json = iv_json.
  ENDMETHOD.


  METHOD constructor.
    mv_json = iv_json.
  ENDMETHOD.


  METHOD set_open.
    mv_open = iv_open.
    ri_self = me.
  ENDMETHOD.


  METHOD zif_ark_gui_renderable~render.
    DATA lo_html TYPE REF TO zcl_ark_html.
    lo_html = zcl_ark_html=>create( ).

    IF mv_json IS INITIAL.
      ri_html = lo_html.
      RETURN.
    ENDIF.

    " 折叠切换脚本随片段输出（ES5，IE/MSHTML 与 Edge 双内核兼容）；
    " 函数名固定，同页多棵树/同页重渲染下的重复定义互相覆盖、无害
    lo_html->add_js(
      `function arkJtTg(e){var n=e.parentNode;` &&
      `if(n.getAttribute('data-open')==='1'){n.setAttribute('data-open','0');}` &&
      `else{n.setAttribute('data-open','1');}}` ).

    lo_html->add( render_tree( ) ).

    ri_html = lo_html.
  ENDMETHOD.


  METHOD render_tree.
    DATA lv_html TYPE string.

    ri_html = zcl_ark_html=>create( ).

    TRY.
        " 本机 create 收 xstring：JSON 字符串先转 UTF-8 字节再喂给 sXML
        DATA(li_reader) = cl_sxml_string_reader=>create(
                              cl_abap_codepage=>convert_to( mv_json ) ).
        li_reader->next_node( ).

        IF li_reader->node_type = if_sxml_node=>co_nt_element_open.
          lv_html = |<div class="ark-jt-tree">{ parse_node( ii_reader = li_reader
                                                            iv_index  = '' ) }</div>|.
        ENDIF.
      CATCH cx_root.
        " 非法 JSON / 解析器状态异常：lv_html 留空，走下方原文回退
    ENDTRY.

    IF lv_html IS INITIAL.
      lv_html = |<pre class="ark-jt-raw">{ zcl_ark_convert=>escape_html( mv_json ) }</pre>|.
    ENDIF.

    ri_html->add( lv_html ).
  ENDMETHOD.


  METHOD parse_node.
    " JSON-XML 的成员键挂在值元素的 name 属性上（<str name="key">v</str>），
    " 数组元素无键、由父层传序号
    DATA(lv_elem) = ii_reader->name.

    " 先取本元素的 name 属性（对象成员键）；迭代属性期间 name/value 指向属性
    DATA lv_key TYPE string.
    DO.
      ii_reader->next_attribute( ).
      IF ii_reader->node_type <> if_sxml_node=>co_nt_attribute.
        EXIT.
      ENDIF.
      IF ii_reader->name = 'name'.
        lv_key = ii_reader->value.
      ENDIF.
    ENDDO.

    DATA lv_key_html TYPE string.
    IF lv_key IS NOT INITIAL.
      lv_key_html = key_html( iv_key      = lv_key
                              iv_is_index = abap_false ).
    ELSEIF iv_index IS NOT INITIAL.
      lv_key_html = key_html( iv_key      = iv_index
                              iv_is_index = abap_true ).
    ENDIF.

    CASE lv_elem.
      WHEN 'object' OR 'array'.

        DATA(lv_is_array) = xsdbool( lv_elem = 'array' ).
        DATA lv_children TYPE string.
        DATA lv_count    TYPE i.

        DO.
          ii_reader->next_node( ).
          IF ii_reader->node_type = if_sxml_node=>co_nt_final OR
             ii_reader->node_type = if_sxml_node=>co_nt_element_close.
            EXIT.
          ENDIF.
          IF ii_reader->node_type <> if_sxml_node=>co_nt_element_open.
            CONTINUE.
          ENDIF.

          lv_count = lv_count + 1.
          DATA(lv_idx) = COND string( WHEN lv_is_array = abap_true
                                      THEN |{ lv_count - 1 }|
                                      ELSE '' ).

          lv_children = lv_children && parse_node( ii_reader = ii_reader
                                                   iv_index  = lv_idx ).
        ENDDO.

        IF lv_count = 0.
          " 空对象/数组内联字面量即可，折叠节点徒增噪音。
          " 反引号字面量不解析模板语法，花括号直接写
          DATA(lv_empty) = COND string( WHEN lv_is_array = abap_true
                                        THEN `[ ]`
                                        ELSE `{ }` ).
          rv_html = |<div class="ark-jt-leaf">{ lv_key_html }{ lv_empty }</div>|.
          RETURN.
        ENDIF.

        DATA(lv_openflag) = COND string( WHEN mv_open = abap_true THEN `1` ELSE `0` ).
        " 徽标沿用 JSON 语法形态：数组 [N]、对象 {N}，语言中立
        DATA(lv_badge) = COND string( WHEN lv_is_array = abap_true
                                      THEN |[ { lv_count } ]|
                                      ELSE |\{ { lv_count } \}| ).

        rv_html = |<div class="ark-jt-node" data-open="{ lv_openflag }">| &&
                  |<div class="ark-jt-sum" onclick="arkJtTg(this)">{ lv_key_html }| &&
                  |<span class="ark-jt-badge">{ lv_badge }</span></div>| &&
                  |<div class="ark-jt-kids">{ lv_children }</div></div>|.

      WHEN OTHERS.
        " 叶子：str/num/bool 带 value 节点（空串/null 只有 close），消费到 close 之后
        DATA lv_val TYPE string.
        ii_reader->next_node( ).
        IF ii_reader->node_type = if_sxml_node=>co_nt_value.
          lv_val = ii_reader->value.
          ii_reader->next_node( ).
        ENDIF.

        DATA lv_val_html TYPE string.
        CASE lv_elem.
          WHEN 'str'.
            lv_val_html = |<span class="ark-jt-str">"{ zcl_ark_convert=>escape_html( lv_val ) }"</span>|.
          WHEN 'num'.
            lv_val_html = |<span class="ark-jt-num">{ zcl_ark_convert=>escape_html( lv_val ) }</span>|.
          WHEN 'bool'.
            lv_val_html = |<span class="ark-jt-bool">{ zcl_ark_convert=>escape_html( lv_val ) }</span>|.
          WHEN OTHERS.
            lv_val_html = |<span class="ark-jt-null">null</span>|.
        ENDCASE.

        rv_html = |<div class="ark-jt-leaf">{ lv_key_html }{ lv_val_html }</div>|.
    ENDCASE.
  ENDMETHOD.


  METHOD key_html.
    IF iv_is_index = abap_true.
      rv_html = |<span class="ark-jt-idx">{ iv_key }:</span> |.
    ELSE.
      rv_html = |<span class="ark-jt-key">"{ zcl_ark_convert=>escape_html( iv_key ) }":</span> |.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
