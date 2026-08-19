# ARK - ABAP Render Kit

> *"Every old system needs an Ark."*

ARK is a modern UI framework for ABAP, extracted and refined from the battle-tested [abapGit](https://github.com/abapGit/abapGit) project. It enables developers to build rich, interactive HTML-based user interfaces within SAP GUI using familiar ABAP patterns.

## Features

- **HTML Rendering Engine** — Fluent API for building HTML with automatic indentation
- **Page Navigation** — Stack-based history with back/forward support
- **Event System** — Sapevent-based communication between frontend and ABAP backend
- **UI Components** — Form, Table, Toolbar, and more ready-to-use components
- **Theme Support** — CSS theming system
- **Zero External Dependencies** — Runs entirely within SAP GUI using standard `CL_GUI_HTML_VIEWER`

## Quick Start

```abap
" 1. Create a page
CLASS zcl_my_page DEFINITION INHERITING FROM zcl_ark_gui_page.
  PROTECTED SECTION.
    METHODS render_content REDEFINITION.
ENDCLASS.

CLASS zcl_my_page IMPLEMENTATION.
  METHOD render_content.
    CREATE OBJECT ri_html TYPE zcl_ark_html.
    ri_html->add( '<h1>Hello ARK!</h1>' ).
    ri_html->add_a( iv_txt = 'Click me' iv_act = 'my_action' ).
  ENDMETHOD.
ENDCLASS.

" 2. Create app router
CLASS zcl_my_app DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_ark_gui_event_handler.
    CLASS-METHODS run.
  PRIVATE SECTION.
    DATA mo_gui TYPE REF TO zcl_ark_gui.
ENDCLASS.

CLASS zcl_my_app IMPLEMENTATION.
  METHOD run.
    DATA(lo_app) = NEW zcl_my_app( ).
    CREATE OBJECT lo_app->mo_gui EXPORTING io_component = lo_app.
    lo_app->mo_gui->go_home( 'home' ).
  ENDMETHOD.
  METHOD zif_ark_gui_event_handler~on_event.
    CASE ii_event->mv_action.
      WHEN 'home'.
        rs_result-page  = NEW zcl_my_page( ).
        rs_result-state = zcl_ark_gui=>c_event_state-new_page.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

" 3. Run
zcl_my_app=>run( ).
```

## Installation

1. Install via [abapGit](https://github.com/abapGit/abapGit) — paste this repository URL
2. Or manually copy all `src/**/*.abap` files into your SAP system
3. Activate all classes and interfaces
4. Run `zcl_ark_example_app=>run( )` to see the demo

## Project Structure

```
src/
├── core/              # Tier 1: Core Engine
│   ├── zcl_ark_html              # HTML builder
│   ├── zcl_ark_gui               # GUI controller
│   ├── zcl_ark_html_viewer_gui   # HTML viewer wrapper
│   ├── zcl_ark_gui_event         # Event object
│   ├── zcl_ark_convert           # Conversion utilities
│   └── interfaces...
├── framework/         # Tier 2: Page Framework
│   ├── zcl_ark_gui_page          # Page base class
│   └── zcl_ark_gui_component     # Component base class
├── components/        # Tier 3: UI Components
│   ├── zcl_ark_html_form         # Form builder
│   ├── zcl_ark_html_table        # Table builder
│   └── zcl_ark_html_toolbar      # Toolbar builder
└── examples/          # Demo applications
```

## License

MIT License — same as abapGit.

> *Built with by extracting the best from abapGit.*
