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
      kpi_grid TYPE ty_section_kind VALUE 'kpi_grid',
      table    TYPE ty_section_kind VALUE 'table',
      form     TYPE ty_section_kind VALUE 'form',
      chart    TYPE ty_section_kind VALUE 'chart',
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
    END OF ty_table_column,
    tt_table_column TYPE STANDARD TABLE OF ty_table_column WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_table_cell,
      value       TYPE string,
      semantic    TYPE ty_semantic,
      "! Render as a clickable link firing 'action'
      action      TYPE string,
    END OF ty_table_cell,
    tt_table_cell  TYPE STANDARD TABLE OF ty_table_cell WITH EMPTY KEY,
    tt_table_row   TYPE STANDARD TABLE OF tt_table_cell WITH EMPTY KEY,
    ttt_table_body TYPE STANDARD TABLE OF tt_table_row WITH EMPTY KEY .

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
    END OF ty_form_field,
    tt_form_field TYPE STANDARD TABLE OF ty_form_field WITH EMPTY KEY .

  TYPES:
    BEGIN OF ty_section,
      kind     TYPE ty_section_kind,
      title    TYPE string,
      toolbar  TYPE tt_toolbar_item,
      kpi_cards TYPE tt_kpi_card,
      columns   TYPE tt_table_column,
      rows      TYPE ttt_table_body,
      form_fields TYPE tt_form_field,
      "! For chart sections: complete ECharts option serialized as JSON.
      "! Reuse zcl_ark_echarts option building and pass its JSON here.
      chart_option TYPE string,
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
