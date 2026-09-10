INTERFACE zif_ark_gui_state
  PUBLIC .

  "! <html><b>ARK declarative page state (DRAFT, Phase 2 contract)</b></html>
  "! A page describes WHAT to show via these typed structures; the framework
  "! serializes them to JSON and hands them to the fixed frontend renderer.
  "! ABAP code never writes HTML for state-driven pages; zcl_ark_gui_page's
  "! classic build_html( ) remains available as an escape hatch.
  "! This interface is a schema draft under discussion — expect changes.

  "! Semantic color for values and status; the renderer maps these to the
  "! Fiori design tokens from zcl_ark_theme (positive = green, negative = red)
  TYPES ty_semantic TYPE string .
  CONSTANTS:
    BEGIN OF c_semantic,
      none        TYPE ty_semantic VALUE '',
      positive    TYPE ty_semantic VALUE 'positive',
      negative    TYPE ty_semantic VALUE 'negative',
      critical    TYPE ty_semantic VALUE 'critical',
      informative TYPE ty_semantic VALUE 'informative',
      neutral     TYPE ty_semantic VALUE 'neutral',
    END OF c_semantic .

  "! Toolbar item kind
  TYPES ty_toolbar_kind TYPE string .
  CONSTANTS:
    BEGIN OF c_toolbar_kind,
      button    TYPE ty_toolbar_kind VALUE 'button',
      link      TYPE ty_toolbar_kind VALUE 'link',
      text      TYPE ty_toolbar_kind VALUE 'text',
      separator TYPE ty_toolbar_kind VALUE 'separator',
    END OF c_toolbar_kind .

  "! Section (= content block) kind
  TYPES ty_section_kind TYPE string .
  CONSTANTS:
    BEGIN OF c_section_kind,
      kpi_grid  TYPE ty_section_kind VALUE 'kpi_grid',
      table     TYPE ty_section_kind VALUE 'table',
      form      TYPE ty_section_kind VALUE 'form',
      chart     TYPE ty_section_kind VALUE 'chart',
      "! Navigation card grid (title + description cards firing sapevents)
      card_grid TYPE ty_section_kind VALUE 'card_grid',
      "! Plain text paragraph (escaped) with optional external link
      text      TYPE ty_section_kind VALUE 'text',
      "! Horizontal progress bars (validity, quota, completion, ...)
      progress  TYPE ty_section_kind VALUE 'progress',
    END OF c_section_kind .

  TYPES:
    BEGIN OF ty_toolbar_item,
      kind        TYPE ty_toolbar_kind,
      label       TYPE string,
      "! sapevent action id; the rendered item fires it on click
      action      TYPE string,
      "! Optional query parameters appended to the sapevent URL
      parameters  TYPE string,
      emphasized  TYPE abap_bool,
      enabled     TYPE abap_bool,
    END OF ty_toolbar_item,
    tt_toolbar_item TYPE STANDARD TABLE OF ty_toolbar_item WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_kpi_card,
      title          TYPE string,
      value          TYPE string,
      "! e.g. '+12.4% MoM'
      delta_text     TYPE string,
      "! Drives the color of delta_text
      delta_semantic TYPE ty_semantic,
      "! Optional sparkline values, rendered as a mini line chart
      sparkline      TYPE string_table,
    END OF ty_kpi_card,
    tt_kpi_card TYPE STANDARD TABLE OF ty_kpi_card WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_table_column,
      label       TYPE string,
      "! Right-align numbers like Fiori list reports
      align_right TYPE abap_bool,
      "! Column header offers sort asc/desc toggle (default true)
      sortable    TYPE abap_bool,
    END OF ty_table_column,
    tt_table_column TYPE STANDARD TABLE OF ty_table_column WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_table_cell,
      value       TYPE string,
      semantic    TYPE ty_semantic,
      "! Render as a clickable link firing 'action'
      action      TYPE string,
    END OF ty_table_cell,
    tt_table_cell TYPE STANDARD TABLE OF ty_table_cell WITH EMPTY KEY .

  "! 表格行：结构含单元格内表，而非"行类型为内表"的表套表 ——
  "! 后者的内联构造在低版本解析器上无法书写（行必须用表体语法）
  TYPES:
    BEGIN OF ty_table_row,
      cells TYPE tt_table_cell,
    END OF ty_table_row,
    tt_table_rows TYPE STANDARD TABLE OF ty_table_row WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_card,
      "! Card grid tile: rendered as a sapevent link card
      title  TYPE string,
      "! Optional second line
      desc   TYPE string,
      "! sapevent action fired on click; convention-routed to
      "! on_action_<action> on zcl_ark_gui_page subclasses
      action TYPE string,
    END OF ty_card,
    tt_card TYPE STANDARD TABLE OF ty_card WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_form_field,
      "! Input type: text, number, date, checkbox, select, textarea, hidden
      input_type  TYPE string,
      label       TYPE string,
      "! HTML name; posted back to the sapevent handler
      name        TYPE string,
      value       TYPE string,
      "! For select: dropdown option labels
      options     TYPE string_table,
      "! Framework validation: reject empty submissions, show error_text
      required    TYPE abap_bool,
      "! Set by the framework after read-back when validation fails
      error_text  TYPE string,
    END OF ty_form_field,
    tt_form_field TYPE STANDARD TABLE OF ty_form_field WITH EMPTY KEY .

  "! 进度条行：标签 + 右侧数值文本 + 0-100 百分比 + 语义填充色
  TYPES:
    BEGIN OF ty_progress_item,
      "! 左侧标签（如 '2025-01-01 ~ 2026-12-31'）
      label      TYPE string,
      "! 右侧数值文本（如 '已使用 215 / 730 天'）
      value_text TYPE string,
      "! 填充百分比，渲染时截断到 [0,100]
      percent    TYPE i,
      "! 填充条语义色（c_semantic）；空 = 主题色
      semantic   TYPE ty_semantic,
    END OF ty_progress_item,
    tt_progress_item TYPE STANDARD TABLE OF ty_progress_item WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_section,
      kind     TYPE ty_section_kind,
      title    TYPE string,
      toolbar  TYPE tt_toolbar_item,
      "! sapevent action the form section posts to
      form_action TYPE string,
      kpi_cards TYPE tt_kpi_card,
      columns   TYPE tt_table_column,
      rows      TYPE tt_table_rows,
      form_fields TYPE tt_form_field,
      "! For chart sections: complete ECharts option serialized as JSON.
      "! Reuse zcl_ark_echarts option building and pass its JSON here.
      chart_option TYPE string,
      "! For chart sections: fire this sapevent action when a chart element
      "! (bar / pie slice / map region / ...) is clicked. Payload params
      "! name / series / value / idx (see zcl_ark_echarts=>set_on_click)
      "! plus chart (= section index) to tell multiple chart sections apart
      chart_click_action TYPE string,
      "! For chart sections: GeoJSON map name to register before rendering
      "! (e.g. 'china'); the corresponding map asset script is injected
      "! automatically (see zcl_ark_echarts=>use_bundled_map / set_map)
      chart_map TYPE string,
      "! For card_grid sections: navigation/launch cards
      cards     TYPE tt_card,
      "! For text sections: escaped paragraph content
      text      TYPE string,
      "! For text sections: optional trailing external link (e.g. GitHub)
      link_url  TYPE string,
      link_text TYPE string,
      "! For progress sections: progress bar rows
      progress_items TYPE tt_progress_item,
    END OF ty_section,
    tt_section TYPE STANDARD TABLE OF ty_section WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_page_state,
      title     TYPE string,
      subtitle  TYPE string,
      toolbar   TYPE tt_toolbar_item,
      sections  TYPE tt_section,
    END OF ty_page_state .

ENDINTERFACE.
