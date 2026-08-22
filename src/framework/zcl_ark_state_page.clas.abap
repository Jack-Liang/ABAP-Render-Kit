CLASS zcl_ark_state_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    "! Replace the whole page state in one call (full schema control)
    METHODS set_state
      IMPORTING !is_state TYPE zif_ark_gui_state=>ty_page_state .

    "! Append a fully configured section (table / form / kpi_grid / chart)
    METHODS add_section
      IMPORTING !is_section TYPE zif_ark_gui_state=>ty_section .

    METHODS set_subtitle
      IMPORTING !iv_subtitle TYPE string .

    "! Page-level toolbar items
    METHODS add_button
      IMPORTING
        !iv_label      TYPE string
        !iv_action     TYPE string
        !iv_parameters TYPE string OPTIONAL
        !iv_emphasized TYPE abap_bool DEFAULT abap_false .
    METHODS add_link
      IMPORTING
        !iv_label  TYPE string
        !iv_action TYPE string .
    METHODS add_tooltext
      IMPORTING !iv_text TYPE string .
    METHODS add_toolseparator .

  PROTECTED SECTION.
    DATA ms_state TYPE zif_ark_gui_state=>ty_page_state .

    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    METHODS render_toolbar
      IMPORTING
        !it_items TYPE zif_ark_gui_state=>tt_toolbar_item
      CHANGING
        !co_html  TYPE REF TO zcl_ark_html .

    METHODS render_section
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_kpi_grid
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_table
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_form
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_chart
      IMPORTING
        !is_section TYPE zif_ark_gui_state=>ty_section
        !iv_index   TYPE i
      CHANGING
        !co_html    TYPE REF TO zcl_ark_html .

    METHODS render_cell
      IMPORTING
        !is_cell      TYPE zif_ark_gui_state=>ty_table_cell
      RETURNING
        VALUE(rv_html) TYPE string .
ENDCLASS.

CLASS zcl_ark_state_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.

  METHOD set_state.
    ms_state = is_state.
    IF ms_state-title IS NOT INITIAL.
      set_title( ms_state-title ).
    ENDIF.
  ENDMETHOD.

  METHOD set_subtitle.
    ms_state-subtitle = iv_subtitle.
  ENDMETHOD.

  METHOD add_section.
    APPEND is_section TO ms_state-sections.
  ENDMETHOD.

  METHOD add_button.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind       = zif_ark_gui_state=>c_toolbar_kind-button
      label      = iv_label
      action     = iv_action
      parameters = iv_parameters
      emphasized = iv_emphasized
      enabled    = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_link.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-link
      label   = iv_label
      action  = iv_action
      enabled = abap_true ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_tooltext.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind    = zif_ark_gui_state=>c_toolbar_kind-text
      label   = iv_text ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD add_toolseparator.
    APPEND VALUE zif_ark_gui_state=>ty_toolbar_item(
      kind = zif_ark_gui_state=>c_toolbar_kind-separator ) TO ms_state-toolbar.
  ENDMETHOD.

  METHOD build_html.
    " 声明式页面：业务代码只填充 ms_state（或经 set_state/add_* 辅助方法），
    " 此处把类型化 state 渲染为 Fiori 风格 HTML。样式全部来自 zcl_ark_theme
    " 的 .ark-* / 组件类，本类不写任何内联颜色
    IF ms_state-title IS NOT INITIAL.
      set_title( ms_state-title ).
      mo_html->add( |<h1 class="ark-page-title">{ ms_state-title }</h1>| ).
    ENDIF.
    IF ms_state-subtitle IS NOT INITIAL.
      mo_html->add( |<p class="ark-page-subtitle">{ ms_state-subtitle }</p>| ).
    ENDIF.

    render_toolbar( EXPORTING it_items = ms_state-toolbar CHANGING co_html = mo_html ).

    " 图表节需要 ECharts 库：任一 chart 节存在时整页注入一次
    LOOP AT ms_state-sections TRANSPORTING NO FIELDS
         WHERE kind = zif_ark_gui_state=>c_section_kind-chart.
      mo_html->add( zcl_ark_echarts=>include_library_script( ) ).
      EXIT.
    ENDLOOP.

    DATA lv_index TYPE i.
    LOOP AT ms_state-sections INTO DATA(ls_section).
      lv_index = sy-tabix.
      render_section( EXPORTING is_section = ls_section iv_index = lv_index
                      CHANGING co_html = mo_html ).
    ENDLOOP.

    ri_html = mo_html.
  ENDMETHOD.

  METHOD render_toolbar.
    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    co_html->add( |<div class="toolbar">| ).

    LOOP AT it_items INTO DATA(ls_item).
      CASE ls_item.kind.
        WHEN zif_ark_gui_state=>c_toolbar_kind-button.
          DATA(lv_class) = 'toolbar-button'.
          IF ls_item-emphasized = abap_true.
            lv_class = lv_class && | toolbar-button--emphasized|.
          ENDIF.
          IF ls_item-enabled = abap_false.
            co_html->add( |<span class="toolbar-button disabled">{ ls_item-label }</span> | ).
          ELSE.
            DATA(lv_params) = COND #(
              WHEN ls_item-parameters IS NOT INITIAL THEN |?{ ls_item-parameters }| ).
            co_html->add(
              |<a class="{ lv_class }" href="sapevent:{ ls_item-action }{ lv_params }">| &&
              |{ ls_item-label }</a> | ).
          ENDIF.
        WHEN zif_ark_gui_state=>c_toolbar_kind-link.
          co_html->add(
            |<a class="toolbar-link" href="sapevent:{ ls_item-action }">{ ls_item-label }</a> | ).
        WHEN zif_ark_gui_state=>c_toolbar_kind-text.
          co_html->add( |<span class="toolbar-text">{ ls_item-label }</span> | ).
        WHEN zif_ark_gui_state=>c_toolbar_kind-separator.
          co_html->add( |<span class="separator"></span> | ).
      ENDCASE.
    ENDLOOP.

    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_section.
    co_html->add( |<div class="ark-card">| ).

    IF is_section-title IS NOT INITIAL.
      co_html->add( |<h2 class="ark-card-title">{ is_section-title }</h2>| ).
    ENDIF.

    render_toolbar( EXPORTING it_items = is_section-toolbar CHANGING co_html = co_html ).

    CASE is_section-kind.
      WHEN zif_ark_gui_state=>c_section_kind-kpi_grid.
        render_kpi_grid( EXPORTING is_section = is_section CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-table.
        render_table( EXPORTING is_section = is_section CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-form.
        render_form( EXPORTING is_section = is_section CHANGING co_html = co_html ).
      WHEN zif_ark_gui_state=>c_section_kind-chart.
        render_chart( EXPORTING is_section = is_section iv_index = iv_index
                      CHANGING co_html = co_html ).
    ENDCASE.

    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_kpi_grid.
    co_html->add( |<div class="ark-kpi-grid">| ).

    LOOP AT is_section-kpi_cards INTO DATA(ls_card).
      co_html->add( |<div class="ark-kpi">| ).
      co_html->add( |<div class="ark-kpi-title">{ ls_card-title }</div>| ).
      co_html->add( |<div class="ark-kpi-value">{ ls_card-value }</div>| ).
      IF ls_card-delta_text IS NOT INITIAL.
        DATA(lv_semantic) = ls_card-delta_semantic.
        IF lv_semantic IS NOT INITIAL.
          co_html->add(
            |<span class="ark-delta ark-delta--{ lv_semantic }">{ ls_card-delta_text }</span>| ).
        ELSE.
          co_html->add( |<span class="ark-delta">{ ls_card-delta_text }</span>| ).
        ENDIF.
      ENDIF.
      co_html->add( |</div>| ).
    ENDLOOP.

    co_html->add( |</div>| ).
  ENDMETHOD.

  METHOD render_table.
    co_html->add( |<table>| ).
    co_html->add( |<thead><tr>| ).

    LOOP AT is_section-columns INTO DATA(ls_column).
      IF ls_column-align_right = abap_true.
        co_html->add( |<th style="text-align: right;">{ ls_column-label }</th>| ).
      ELSE.
        co_html->add( |<th>{ ls_column-label }</th>| ).
      ENDIF.
    ENDLOOP.

    co_html->add( |</tr></thead>| ).
    co_html->add( |<tbody>| ).

    LOOP AT is_section-rows INTO DATA(lt_row).
      co_html->add( |<tr>| ).
      LOOP AT lt_row INTO DATA(ls_cell).
        co_html->add( |<td>{ render_cell( ls_cell ) }</td>| ).
      ENDLOOP.
      co_html->add( |</tr>| ).
    ENDLOOP.

    co_html->add( |</tbody></table>| ).
  ENDMETHOD.

  METHOD render_cell.
    IF is_cell-action IS NOT INITIAL.
      rv_html = |<a href="sapevent:{ is_cell-action }">{ is_cell-value }</a>|.
      IF is_cell-semantic IS NOT INITIAL.
        rv_html = |<span class="ark-status ark-status--{ is_cell-semantic }"></span>{ rv_html }|.
      ENDIF.
    ELSEIF is_cell-semantic IS NOT INITIAL.
      rv_html = |<span class="ark-status ark-status--{ is_cell-semantic }">| &&
                |{ is_cell-value }</span>|.
    ELSE.
      rv_html = is_cell-value.
    ENDIF.
  ENDMETHOD.

  METHOD render_form.
    IF is_section-form_action IS INITIAL.
      co_html->add( |<form method="post">| ).
    ELSE.
      co_html->add( |<form method="post" action="sapevent:{ is_section-form_action }">| ).
    ENDIF.

    LOOP AT is_section-form_fields INTO DATA(ls_field).
      co_html->add( |<div class="form-row">| ).
      co_html->add( |<span class="form-label">{ ls_field-label }</span>| ).

      CASE ls_field-input_type.
        WHEN 'select'.
          co_html->add( |<select name="{ ls_field-name }">| ).
          LOOP AT ls_field-options INTO DATA(lv_option).
            IF lv_option = ls_field-value.
              co_html->add( |<option selected>{ lv_option }</option>| ).
            ELSE.
              co_html->add( |<option>{ lv_option }</option>| ).
            ENDIF.
          ENDLOOP.
          co_html->add( |</select>| ).
        WHEN 'textarea'.
          co_html->add(
            |<textarea name="{ ls_field-name }" rows="4">{ ls_field-value }</textarea>| ).
        WHEN 'checkbox'.
          IF ls_field-value = 'X'.
            co_html->add( |<input type="checkbox" name="{ ls_field-name }" checked>| ).
          ELSE.
            co_html->add( |<input type="checkbox" name="{ ls_field-name }">| ).
          ENDIF.
        WHEN 'hidden'.
          co_html->add( |<input type="hidden" name="{ ls_field-name }" | &&
                        |value="{ ls_field-value }">| ).
        WHEN OTHERS.
          co_html->add( |<input type="{ ls_field-input_type }" name="{ ls_field-name }" | &&
                        |value="{ ls_field-value }">| ).
      ENDCASE.

      co_html->add( |</div>| ).
    ENDLOOP.

    co_html->add( |</form>| ).
  ENDMETHOD.

  METHOD render_chart.
    DATA(lv_id) = |ark_state_chart_{ iv_index }|.

    co_html->div(
      iv_id    = lv_id
      iv_style = |width: 100%; height: 320px;| ).

    " chart_option 是 JSON，本身即合法 JS 对象字面量；
    " 仅需转义 </ 防止值中 </script> 截断宿主脚本块
    DATA(lv_option) = is_section-chart_option.
    lv_option = replace( val = lv_option sub = `</` with = `<\/` occ = 0 ).

    co_html->add_js(
      |(function() \{| &&
      |var el = document.getElementById('{ lv_id }');| &&
      |if (window.echarts && el) \{ echarts.init(el).setOption({ lv_option }); \}| &&
      |\})();| ).
  ENDMETHOD.

ENDCLASS.
