# ARK - ABAP Render Kit

> *"Every old system needs an Ark."*

ARK is a modern UI framework for ABAP, extracted and refined from the battle-tested [abapGit](https://github.com/abapGit/abapGit) project. It enables developers to build rich, interactive HTML-based user interfaces within SAP GUI using familiar ABAP patterns.

> ⚠️ **Experimental Project**
>
> This is an **experimental** project. APIs, class names, and behavior may change without notice between releases. While ARK is derived from abapGit's source code, it is an independent project — not officially endorsed by or maintained by the abapGit team or SAP. No warranty is provided.
>
> - Do **not** use in production systems without thorough testing.
> - Expect breaking changes as the framework evolves.
> - Feedback, bug reports, and contributions are welcome, but treat current builds as alpha-quality.

## Features

- **HTML Rendering Engine** — Fluent API for building HTML with automatic indentation
- **Page Navigation** — Stack-based history with back/forward support
- **Event System** — Sapevent-based communication between frontend and ABAP backend
- **UI Components** — Form, Table, Toolbar, and more ready-to-use components
- **ECharts Component** — Declarative charting with `zcl_ark_echarts`, mixable with any other HTML content
- **Text Templates** — `zcl_ark_template` with `{{PLACEHOLDER}}` syntax, loadable from the MIME repository
- **JSON Serialization** — `zcl_ark_json=>to_json( )` for any ABAP data object (sXML-based, zero dependencies)
- **Theme Support** — CSS theming system
- **Zero External Dependencies** — Runs entirely within SAP GUI using standard `CL_GUI_HTML_VIEWER`

## Quick Start

```abap
" 1. Create a page — inherit from zcl_ark_gui_page and redefine build_html
CLASS zcl_my_page DEFINITION
  INHERITING FROM zcl_ark_gui_page
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .
ENDCLASS.

CLASS zcl_my_page IMPLEMENTATION.
  METHOD build_html.
    " mo_html is inherited from zcl_ark_gui_component
    mo_html->add( '<h1>Hello ARK!</h1>' ).
    mo_html->add_a( iv_txt = 'Click me' iv_act = 'my_action' ).
    ri_html = mo_html.
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'my_action'.
        rs_result-state = 1.             " handled, stay on page
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
```

```abap
" 2. Launcher report — the HTML viewer needs a host screen (like abapGit)
REPORT zmy_app.

SELECTION-SCREEN BEGIN OF SCREEN 1001.   " dummy host screen
SELECTION-SCREEN END OF SCREEN 1001.

START-OF-SELECTION.
  TRY.
      DATA(lo_gui) = zcl_ark_gui=>create( ).
      lo_gui->set_page( NEW zcl_my_page( ) ).
      CALL SELECTION-SCREEN 1001.
    CATCH zcx_ark_exception INTO DATA(lx_error).
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.

AT SELECTION-SCREEN ON EXIT-COMMAND.
  " Back / Escape: release the GUI and leave the program
  IF sy-dynnr = 1001.
    zcl_ark_gui=>get_instance( )->free( ).
    LEAVE PROGRAM.
  ENDIF.
```

To navigate to another page from `on_event`, return it in the result:

```abap
WHEN 'nav_detail'.
  rs_result-page  = NEW zcl_my_detail_page( ).
  rs_result-state = 1.
```

## Charts (ECharts)

`zcl_ark_echarts` renders a chart as a plain HTML fragment, so it mixes freely with headings, tables, toolbars, or a second chart on the same page:

```abap
DATA(lo_chart) = NEW zcl_ark_echarts( iv_div_id = 'chart1' iv_height = 420 ).

lo_chart->set_title( 'Stacked Area Chart' ).
lo_chart->set_xaxis_categories( VALUE string_table( ( `Mon` ) ( `Tue` ) ( `Wed` ) ) ).
lo_chart->add_series(
  iv_name  = 'Email'
  it_data  = VALUE zcl_ark_echarts=>ty_values( ( 120 ) ( 132 ) ( 101 ) )
  iv_stack = 'Total'
  iv_area  = abap_true ).

mo_html->add( |<h1>Dashboard</h1>| ).
mo_html->add( lo_chart->render( ) ).   " just one chunk in the page flow
```

Notes:

- ECharts 6.1.0 is loaded from CDN by the first chart on the page; pass `iv_include_lib = abap_false` to any additional chart on the same page.
- For offline systems, upload `echarts.min.js` to the MIME repository (SMW0) and inject it via `lo_chart->set_library_xdata( zcl_ark_convert=>mime_to_xstring( 'ZARK_ECHARTS_MIN_JS' ) )` — the component serves it through `cache_asset` with automatic CDN fallback.
- Series data and categories are serialized with `zcl_ark_json=>to_json( )`; pass plain ABAP internal tables, no string building required.
- See `ZCL_ARK_EXAMPLE_CHART_PAGE` for a full mixed-content example (reachable from the demo's home page via *Chart Example*).

## Installation

1. Install via [abapGit](https://github.com/abapGit/abapGit) — paste this repository URL
2. Or manually copy all `src/**/*.abap` files into your SAP system
3. Activate all classes and interfaces
4. Run the demo program `ZARK_EXAMPLE` from SE38/SA38, or run class `ZCL_ARK_EXAMPLE_APP` as an ABAP application in ADT

## Project Structure

```
src/
├── core/              # Tier 1: Core Engine
│   ├── zcl_ark_html              # HTML builder
│   ├── zcl_ark_gui               # GUI controller
│   ├── zcl_ark_html_viewer_gui   # HTML viewer wrapper
│   ├── zcl_ark_gui_event         # Event object
│   ├── zcl_ark_convert           # Conversion utilities
│   ├── zcl_ark_json              # JSON serializer (sXML based)
│   └── interfaces...
├── framework/         # Tier 2: Page Framework
│   ├── zcl_ark_gui_page          # Page base class
│   └── zcl_ark_gui_component     # Component base class
├── components/        # Tier 3: UI Components
│   ├── zcl_ark_html_form         # Form builder
│   ├── zcl_ark_html_table        # Table builder
│   ├── zcl_ark_html_toolbar      # Toolbar builder
│   ├── zcl_ark_echarts           # ECharts chart component
│   └── zcl_ark_template          # Text template with placeholders
└── examples/          # Demo applications
```

## License

MIT License — same as abapGit.

> *Built with by extracting the best from abapGit.*
