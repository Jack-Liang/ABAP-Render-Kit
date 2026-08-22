CLASS zcl_ark_theme DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    "! Design token: a named CSS custom property (design option) of the theme
    TYPES:
      BEGIN OF ty_token,
        name  TYPE string,
        value TYPE string,
      END OF ty_token,
      tt_token TYPE SORTED TABLE OF ty_token WITH UNIQUE KEY name .

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_theme) TYPE REF TO zcl_ark_theme .

    "! Full CSS for the HTML document: ':root' design tokens plus default
    "! styles for the built-in component class names (toolbar, form, table).
    "! zcl_ark_gui embeds this in every rendered page; pages can override
    "! single tokens via set_token( ) before the page is rendered.
    METHODS get_css
      RETURNING VALUE(rv_css) TYPE string .

    "! Override a single design token, e.g. set_token( 'brandColor' = '#0a6ed1' ).
    "! Takes effect from the next render( ) on.
    METHODS set_token
      IMPORTING
        !iv_name  TYPE string
        !iv_value TYPE string .

    "! Drop all overrides and return to the default Fiori Quartz Light tokens
    METHODS reset .

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO zcl_ark_theme .

    DATA mt_override TYPE tt_token .

    METHODS constructor .

    METHODS token
      IMPORTING
        !iv_name         TYPE string
        !iv_default      TYPE string
      RETURNING VALUE(rv_value) TYPE string .

    METHODS token_block
      RETURNING VALUE(rv_css) TYPE string .

    METHODS component_block
      RETURNING VALUE(rv_css) TYPE string .
ENDCLASS.

CLASS zcl_ark_theme IMPLEMENTATION.

  METHOD get_instance.
    IF go_instance IS INITIAL.
      go_instance = NEW zcl_ark_theme( ).
    ENDIF.
    ro_theme = go_instance.
  ENDMETHOD.

  METHOD constructor.
    CLEAR mt_override.
  ENDMETHOD.

  METHOD set_token.
    " MODIFY TABLE = insert-or-update by unique key
    MODIFY TABLE mt_override FROM VALUE ty_token( name = iv_name value = iv_value ).
  ENDMETHOD.

  METHOD reset.
    CLEAR mt_override.
  ENDMETHOD.

  METHOD token.
    " Overrides win over theme defaults
    READ TABLE mt_override INTO DATA(ls_override) WITH KEY name = iv_name.
    IF sy-subrc = 0.
      rv_value = ls_override-value.
    ELSE.
      rv_value = iv_default.
    ENDIF.
  ENDMETHOD.

  METHOD get_css.
    rv_css = token_block( ) && component_block( ).
  ENDMETHOD.

  METHOD token_block.
    " ':root' custom properties. Defaults follow SAP Fiori Quartz Light.
    " Escape \{ \} inside string templates
    rv_css =
      |:root \{ | &&
      |  --arkBrandColor: { token( iv_name = 'brandColor' iv_default = '#0070f2' ) }; | &&
      |  --arkPositiveColor: { token( iv_name = 'positiveColor' iv_default = '#107e3e' ) }; | &&
      |  --arkNegativeColor: { token( iv_name = 'negativeColor' iv_default = '#bb0000' ) }; | &&
      |  --arkCriticalColor: { token( iv_name = 'criticalColor' iv_default = '#e9730c' ) }; | &&
      |  --arkInformativeColor: { token( iv_name = 'informativeColor' iv_default = '#0a6ed1' ) }; | &&
      |  --arkTextColor: { token( iv_name = 'textColor' iv_default = '#1d2d3e' ) }; | &&
      |  --arkNeutralColor: { token( iv_name = 'neutralColor' iv_default = '#6a6d70' ) }; | &&
      |  --arkPageBackground: { token( iv_name = 'pageBackground' iv_default = '#f5f5f5' ) }; | &&
      |  --arkBaseColor: { token( iv_name = 'baseColor' iv_default = '#ffffff' ) }; | &&
      |  --arkHoverBackground: { token( iv_name = 'hoverBackground' iv_default = '#f0f0f0' ) }; | &&
      |  --arkSelectionBackground: { token( iv_name = 'selectionBackground' iv_default = '#e5f0fa' ) }; | &&
      |  --arkBorderColor: { token( iv_name = 'borderColor' iv_default = '#e5e5e5' ) }; | &&
      |  --arkBorderStrongColor: { token( iv_name = 'borderStrongColor' iv_default = '#c9c9c9' ) }; | &&
      |  --arkRadius: { token( iv_name = 'radius' iv_default = '8px' ) }; | &&
      |  --arkRadiusCard: { token( iv_name = 'radiusCard' iv_default = '12px' ) }; | &&
      |  --arkFontFamily: { token( iv_name = 'fontFamily' iv_default = '"72", "72full", -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif' ) }; | &&
      |  --arkFontSize: { token( iv_name = 'fontSize' iv_default = '14px' ) }; | &&
      |\} |.
  ENDMETHOD.

  METHOD component_block.
    " Default styles for the built-in component class names emitted by
    " zcl_ark_html_toolbar / zcl_ark_html_form / zcl_ark_html_table.
    " Everything resolves through the ':root' tokens above, so overriding a
    " token re-themes the whole page.
    rv_css =
      |body \{ font-family: var(--arkFontFamily); font-size: var(--arkFontSize);| &&
      | color: var(--arkTextColor); background: var(--arkPageBackground);| &&
      | margin: 0; padding: 24px 32px; \} | &&
      |a \{ color: var(--arkBrandColor); text-decoration: none; \} | &&
      |a:hover \{ text-decoration: underline; \} | &&
      |table \{ border-collapse: collapse; width: 100%;| &&
      | background: var(--arkBaseColor); border-radius: var(--arkRadiusCard); \} | &&
      |th \{ text-align: left; font-size: 12px; font-weight: 500;| &&
      | color: var(--arkNeutralColor); padding: 10px 16px;| &&
      | border-bottom: 1px solid var(--arkBorderStrongColor); \} | &&
      |td \{ padding: 10px 16px; font-size: 13px;| &&
      | border-bottom: 1px solid var(--arkBorderColor); \} | &&
      |tr:last-child td \{ border-bottom: none; \} | &&
      |tr:hover td \{ background: var(--arkHoverBackground); \} | &&
      |.toolbar \{ display: flex; align-items: center; gap: 8px;| &&
      | margin-bottom: 16px; padding: 8px; background: var(--arkBaseColor);| &&
      | border: 1px solid var(--arkBorderColor); border-radius: var(--arkRadiusCard); \} | &&
      |.toolbar-button \{ display: inline-block; padding: 5px 12px;| &&
      | margin: 0 2px 0 0; border: 1px solid var(--arkBorderStrongColor);| &&
      | border-radius: var(--arkRadius); background-color: var(--arkBaseColor);| &&
      | color: var(--arkTextColor); text-decoration: none; font-size: 13px; \} | &&
      |.toolbar-button:hover \{ background-color: var(--arkHoverBackground);| &&
      | color: var(--arkTextColor); text-decoration: none; \} | &&
      |.toolbar-link \{ margin-left: 8px; \} | &&
      |.toolbar-text \{ color: var(--arkNeutralColor); margin: 0 6px; \} | &&
      |.separator \{ display: inline-block; width: 1px; height: 20px;| &&
      | background-color: var(--arkBorderStrongColor); margin: 0 8px;| &&
      | vertical-align: middle; \} | &&
      |.disabled \{ color: var(--arkNeutralColor); opacity: 0.6; \} | &&
      |.form-row \{ margin-bottom: 12px; \} | &&
      |.form-label \{ display: inline-block; width: 120px; font-weight: 500;| &&
      | color: var(--arkNeutralColor); \} | &&
      |input, select, textarea \{ font-family: var(--arkFontFamily);| &&
      | font-size: 13px; padding: 4px 8px; border: 1px solid var(--arkBorderStrongColor);| &&
      | border-radius: var(--arkRadius); \} | &&
      |input:focus, select:focus, textarea:focus \{ outline: none;| &&
      | border-color: var(--arkBrandColor);| &&
      | box-shadow: 0 0 0 1px var(--arkBrandColor); \} | &&
      |.toolbar-button--emphasized \{ background-color: var(--arkBrandColor);| &&
      | border-color: var(--arkBrandColor); color: #fff; \} | &&
      |.toolbar-button--emphasized:hover \{ background-color: #005dc2;| &&
      | color: #fff; \} | &&
      |.ark-page-title \{ font-size: 22px; font-weight: 400; margin: 0 0 4px; \} | &&
      |.ark-page-subtitle \{ color: var(--arkNeutralColor); font-size: 13px;| &&
      | margin: 0 0 20px; \} | &&
      |.ark-card \{ background: var(--arkBaseColor);| &&
      | border: 1px solid var(--arkBorderColor);| &&
      | border-radius: var(--arkRadiusCard); padding: 16px 20px;| &&
      | margin-bottom: 16px; \} | &&
      |.ark-card-title \{ font-size: 16px; font-weight: 500; margin: 0 0 12px; \} | &&
      |.ark-kpi-grid \{ display: grid;| &&
      | grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));| &&
      | gap: 16px; \} | &&
      |.ark-kpi-title \{ font-size: 13px; color: var(--arkNeutralColor); \} | &&
      |.ark-kpi-value \{ font-size: 30px; font-weight: 400; margin: 6px 0 2px; \} | &&
      |.ark-delta \{ font-size: 13px; \} | &&
      |.ark-delta--positive \{ color: var(--arkPositiveColor); \} | &&
      |.ark-delta--negative \{ color: var(--arkNegativeColor); \} | &&
      |.ark-delta--critical \{ color: var(--arkCriticalColor); \} | &&
      |.ark-delta--informative \{ color: var(--arkInformativeColor); \} | &&
      |.ark-delta--neutral \{ color: var(--arkNeutralColor); \} | &&
      |.ark-status \{ display: inline-flex; align-items: center; gap: 6px;| &&
      | font-size: 13px; \} | &&
      |.ark-status::before \{ content: ""; width: 8px; height: 8px;| &&
      | border-radius: 50%; background: var(--arkNeutralColor); \} | &&
      |.ark-status--positive::before \{ background: var(--arkPositiveColor); \} | &&
      |.ark-status--negative::before \{ background: var(--arkNegativeColor); \} | &&
      |.ark-status--critical::before \{ background: var(--arkCriticalColor); \} | &&
      |.ark-status--informative::before \{ background: var(--arkInformativeColor); \} | &&
      |.ark-num \{ text-align: right; font-variant-numeric: tabular-nums; \} | &&
      |.ark-filterbar \{ display: flex; align-items: center; gap: 8px;| &&
      | margin-bottom: 12px; \} | &&
      |.ark-filterbar input[type=text] \{ width: 200px; \} | &&
      |.ark-sort \{ color: var(--arkTextColor); text-decoration: none; \} | &&
      |.ark-sort:hover \{ color: var(--arkBrandColor); text-decoration: none; \} | &&
      |.ark-empty \{ color: var(--arkNeutralColor); text-align: center;| &&
      | padding: 20px; \} |.
  ENDMETHOD.

ENDCLASS.
