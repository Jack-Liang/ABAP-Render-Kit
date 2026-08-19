CLASS zcl_ark_html DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_ark_html .
    ALIASES add FOR zif_ark_html~add .
    ALIASES add_a FOR zif_ark_html~add_a .
    ALIASES add_checkbox FOR zif_ark_html~add_checkbox .
    ALIASES add_icon FOR zif_ark_html~add_icon .
    ALIASES div FOR zif_ark_html~div .
    ALIASES icon FOR zif_ark_html~icon .
    ALIASES is_empty FOR zif_ark_html~is_empty .
    ALIASES render FOR zif_ark_html~render .
    ALIASES set_title FOR zif_ark_html~set_title .
    ALIASES td FOR zif_ark_html~td .
    ALIASES th FOR zif_ark_html~th .
    ALIASES wrap FOR zif_ark_html~wrap .
    ALIASES a FOR zif_ark_html~a .

    CLASS-METHODS create RETURNING VALUE(ri_html) TYPE REF TO zif_ark_html .

    METHODS add_css IMPORTING !iv_css TYPE string RETURNING VALUE(ri_self) TYPE REF TO zif_ark_html .
    METHODS add_js IMPORTING !iv_js TYPE string RETURNING VALUE(ri_self) TYPE REF TO zif_ark_html .
    METHODS add_table IMPORTING !ii_table TYPE REF TO zif_ark_html RETURNING VALUE(ri_self) TYPE REF TO zif_ark_html .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_chunk, is_text TYPE abap_bool, text TYPE string, html TYPE REF TO zcl_ark_html,
      END OF ty_chunk .
    DATA mt_chunks TYPE STANDARD TABLE OF ty_chunk WITH DEFAULT KEY .
    DATA mv_indent TYPE i VALUE 0 ##NO_TEXT.
    DATA mv_within_style TYPE abap_bool .
    DATA mv_within_js TYPE abap_bool .

    METHODS increase_indent .
    METHODS decrease_indent .
    METHODS indent_line CHANGING !cv_line TYPE string .
    METHODS add_chunk IMPORTING !is_chunk TYPE ty_chunk .
    METHODS check_rerender RETURNING VALUE(rv_result) TYPE abap_bool .
ENDCLASS.

CLASS zcl_ark_html IMPLEMENTATION.

  METHOD a.
    DATA lv_class TYPE string.
    DATA lv_href TYPE string.
    DATA lv_click TYPE string.
    DATA lv_style_str TYPE string.
    DATA lv_title_str TYPE string.
    DATA lv_id_str TYPE string.

    IF iv_class IS NOT INITIAL.
      lv_class = | class="{ iv_class }"|.
    ENDIF.

    IF iv_id IS NOT INITIAL.
      lv_id_str = | id="{ iv_id }"|.
    ENDIF.

    IF iv_style IS NOT INITIAL.
      lv_style_str = | style="{ iv_style }"|.
    ENDIF.

    IF iv_title IS NOT INITIAL.
      lv_title_str = | title="{ iv_title }"|.
    ENDIF.

    CASE iv_typ.
      WHEN zif_ark_html=>c_action_type-sapevent.
        lv_href = |sapevent:{ iv_act }|.
        IF iv_query IS NOT INITIAL.
          lv_href = lv_href && |?{ iv_query }|.
        ENDIF.
        rv_str = |<a{ lv_class }{ lv_id_str }{ lv_style_str }{ lv_title_str } href="{ lv_href }">{ iv_txt }</a>|.
      WHEN zif_ark_html=>c_action_type-url.
        rv_str = |<a{ lv_class }{ lv_id_str }{ lv_style_str }{ lv_title_str } href="{ iv_act }" target="_blank">{ iv_txt }</a>|.
      WHEN zif_ark_html=>c_action_type-onclick.
        lv_click = | onclick="{ iv_act }"|.
        rv_str = |<a{ lv_class }{ lv_id_str }{ lv_style_str }{ lv_title_str }{ lv_click } href="#">{ iv_txt }</a>|.
      WHEN OTHERS.
        rv_str = iv_txt.
    ENDCASE.

    IF iv_opt = zif_ark_html=>c_html_opt-strong.
      rv_str = |<strong>{ rv_str }</strong>|.
    ELSEIF iv_opt = zif_ark_html=>c_html_opt-cancel.
      rv_str = |<del>{ rv_str }</del>|.
    ELSEIF iv_opt = zif_ark_html=>c_html_opt-crossout.
      rv_str = |<s>{ rv_str }</s>|.
    ENDIF.
  ENDMETHOD.

  METHOD add.
    DATA ls_chunk TYPE ty_chunk.

    IF ig_chunk IS INITIAL.
      RETURN.
    ENDIF.

    IF cl_abap_typedescr=>describe_by_data( ig_chunk )->type_kind = cl_abap_typedescr=>typekind_oref.
      ls_chunk-html ?= ig_chunk.
      ls_chunk-is_text = abap_false.
    ELSE.
      ls_chunk-text = ig_chunk.
      ls_chunk-is_text = abap_true.
    ENDIF.

    add_chunk( ls_chunk ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_a.
    add( a( iv_txt   = iv_txt
            iv_act   = iv_act
            iv_query = iv_query
            iv_typ   = iv_typ
            iv_opt   = iv_opt
            iv_class = iv_class
            iv_id    = iv_id
            iv_style = iv_style
            iv_title = iv_title ) ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_checkbox.
    DATA lv_checked TYPE string.
    IF iv_checked = abap_true.
      lv_checked = ' checked'.
    ENDIF.
    add( |<input type="checkbox" id="{ iv_id }" name="{ iv_id }"{ lv_checked }>| ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_chunk.
    IF is_chunk-is_text = abap_true AND is_chunk-text IS INITIAL.
      RETURN.
    ENDIF.
    APPEND is_chunk TO mt_chunks.
  ENDMETHOD.

  METHOD add_css.
    DATA ls_chunk TYPE ty_chunk.
    ls_chunk-text = |<style type="text/css">{ iv_css }</style>|.
    ls_chunk-is_text = abap_true.
    add_chunk( ls_chunk ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_icon.
    add( icon( iv_name    = iv_name
               iv_hint    = iv_hint
               iv_class   = iv_class
               iv_onclick = iv_onclick ) ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_js.
    DATA ls_chunk TYPE ty_chunk.
    ls_chunk-text = |<script type="text/javascript">{ iv_js }</script>|.
    ls_chunk-is_text = abap_true.
    add_chunk( ls_chunk ).
    ri_self = me.
  ENDMETHOD.

  METHOD add_table.
    IF ii_table IS NOT INITIAL.
      add( ii_table ).
    ENDIF.
    ri_self = me.
  ENDMETHOD.

  METHOD check_rerender.
    rv_result = abap_false.
  ENDMETHOD.

  METHOD create.
    CREATE OBJECT ri_html TYPE zcl_ark_html.
  ENDMETHOD.

  METHOD decrease_indent.
    mv_indent = mv_indent - 2.
    IF mv_indent < 0.
      mv_indent = 0.
    ENDIF.
  ENDMETHOD.

  METHOD div.
    wrap( iv_tag     = 'div'
          iv_content = iv_content
          ii_content = ii_content
          iv_id      = iv_id
          iv_class   = iv_class
          iv_style   = iv_style
          is_data_attr = is_data_attr
          it_data_attrs = it_data_attrs ).
    ri_self = me.
  ENDMETHOD.

  METHOD icon.
    DATA lv_class TYPE string.
    DATA lv_onclick TYPE string.
    DATA lv_title TYPE string.

    IF iv_class IS NOT INITIAL.
      lv_class = | class="{ iv_class }"|.
    ENDIF.

    IF iv_onclick IS NOT INITIAL.
      lv_onclick = | onclick="{ iv_onclick }"|.
    ENDIF.

    IF iv_hint IS NOT INITIAL.
      lv_title = | title="{ iv_hint }"|.
    ENDIF.

    rv_str = |<span{ lv_class }{ lv_title }{ lv_onclick }>{ iv_name }</span>|.
  ENDMETHOD.

  METHOD increase_indent.
    mv_indent = mv_indent + 2.
  ENDMETHOD.

  METHOD indent_line.
    DATA lv_spaces TYPE string.
    DO mv_indent TIMES.
      lv_spaces = lv_spaces && ` `.
    ENDDO.
    cv_line = lv_spaces && cv_line.
  ENDMETHOD.

  METHOD is_empty.
    rv_yes = abap_false.
    IF lines( mt_chunks ) = 0.
      rv_yes = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD render.
    DATA ls_chunk TYPE ty_chunk.
    DATA lv_html TYPE string.
    DATA lt_html TYPE STANDARD TABLE OF string.

    LOOP AT mt_chunks INTO ls_chunk.
      IF ls_chunk-is_text = abap_true.
        lv_html = ls_chunk-text.
      ELSEIF ls_chunk-html IS NOT INITIAL.
        lv_html = ls_chunk-html->render( iv_no_indent_jscss = iv_no_indent_jscss
                                         iv_no_line_breaks  = iv_no_line_breaks ).
      ENDIF.
      APPEND lv_html TO lt_html.
    ENDLOOP.

    IF iv_no_line_breaks = abap_true.
      rv_html = concat_lines_of( table = lt_html sep = '' ).
    ELSE.
      rv_html = concat_lines_of( table = lt_html sep = cl_abap_char_utilities=>newline ).
    ENDIF.
  ENDMETHOD.

  METHOD set_title.
    zif_ark_html~mv_chunk_title = iv_title.
    ri_self = me.
  ENDMETHOD.

  METHOD td.
    wrap( iv_tag                = 'td'
          iv_content            = iv_content
          ii_content            = ii_content
          iv_id                 = iv_id
          iv_class              = iv_class
          iv_hint               = iv_hint
          iv_style              = iv_style
          iv_format_single_line = iv_format_single_line
          is_data_attr          = is_data_attr
          it_data_attrs         = it_data_attrs ).
    ri_self = me.
  ENDMETHOD.

  METHOD th.
    wrap( iv_tag                = 'th'
          iv_content            = iv_content
          ii_content            = ii_content
          iv_id                 = iv_id
          iv_class              = iv_class
          iv_hint               = iv_hint
          iv_style              = iv_style
          iv_format_single_line = iv_format_single_line
          is_data_attr          = is_data_attr
          it_data_attrs         = it_data_attrs ).
    ri_self = me.
  ENDMETHOD.

  METHOD wrap.
    DATA lv_content TYPE string.
    DATA lv_attrs TYPE string.
    DATA ls_data_attr TYPE zif_ark_html=>ty_data_attr.

    IF iv_id IS NOT INITIAL.
      lv_attrs = lv_attrs && | id="{ iv_id }"|.
    ENDIF.

    IF iv_class IS NOT INITIAL.
      lv_attrs = lv_attrs && | class="{ iv_class }"|.
    ENDIF.

    IF iv_hint IS NOT INITIAL.
      lv_attrs = lv_attrs && | title="{ iv_hint }"|.
    ENDIF.

    IF iv_style IS NOT INITIAL.
      lv_attrs = lv_attrs && | style="{ iv_style }"|.
    ENDIF.

    IF is_data_attr IS NOT INITIAL.
      lv_attrs = lv_attrs && | data-{ is_data_attr-name }="{ is_data_attr-value }"|.
    ENDIF.

    LOOP AT it_data_attrs INTO ls_data_attr.
      lv_attrs = lv_attrs && | data-{ ls_data_attr-name }="{ ls_data_attr-value }"|.
    ENDLOOP.

    IF ii_content IS NOT INITIAL.
      lv_content = ii_content->render( ).
    ELSE.
      lv_content = iv_content.
    ENDIF.

    IF iv_format_single_line = abap_true.
      add( |<{ iv_tag }{ lv_attrs }>{ lv_content }</{ iv_tag }>| ).
    ELSE.
      add( |<{ iv_tag }{ lv_attrs }>| ).
      add( lv_content ).
      add( |</{ iv_tag }>| ).
    ENDIF.

    ri_self = me.
  ENDMETHOD.

ENDCLASS.
