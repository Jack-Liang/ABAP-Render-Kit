# ARK Project Manifest

## File Inventory

### Root
- `.abapgit.xml` — abapGit configuration
- `README.md` — Project documentation
- `MANIFEST.md` — This file (object inventory)
- `.gitignore` — Git ignore rules

### tools/
- `make_w3mi.mjs` — convert a local JS/JSON/CSS file into an abapGit W3MI asset pair (see docs/js-extensions.md)
- `gen_ui5_shell.mjs` — generate zcl_ark_ui5_shell from the UI5 shell preview page

### src/ (Main Package)
- `package.devc.xml` — Package definition

### src/core/ (Core Engine — 18 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCX_ARK_EXCEPTION | CLAS | Exception class |
| ZCL_ARK_HTML | CLAS | HTML builder engine (slimmed: raw-string escape hatch only; all declarative paths bypass it) |
| ZCL_ARK_GUI | CLAS | GUI controller (page history stack, uniform ark_back control auto-injected on non-home pages, event-error banner, is_at_home service) |
| ZCL_ARK_GUI_EVENT | CLAS | Event object |
| ZCL_ARK_HTML_PARTS | CLAS | HTML parts collection |
| ZCL_ARK_HTML_VIEWER_GUI | CLAS | HTML viewer implementation |
| ZCL_ARK_THEME | CLAS | Theme: Fiori design tokens + default CSS |
| ZCL_ARK_CONVERT | CLAS | Conversion utilities (+ escape_js) |
| ZCL_ARK_JS_LIBRARY | CLAS | JS library registry: MIME/URL/xdata/inline sources, page-scope idempotent include |
| ZCL_ARK_JS_BRIDGE | CLAS | JS-ABAP event bridge: window.arkEmit(action, params) → sapevent |
| ZIF_ARK_JS_WIDGET | INTF | JS widget plugin interface: get_assets() + render() (composes zif_ark_gui_renderable) |
| ZCL_ARK_JSON | CLAS | JSON serializer (standard sXML, zero deps) |
| ZIF_ARK_HTML | INTF | HTML interface |
| ZIF_ARK_GUI_RENDERABLE | INTF | Renderable interface |
| ZIF_ARK_GUI_EVENT | INTF | Event interface |
| ZIF_ARK_GUI_EVENT_HANDLER | INTF | Event handler interface |
| ZIF_ARK_GUI_SERVICES | INTF | GUI services interface |
| ZIF_ARK_HTML_VIEWER | INTF | HTML viewer interface |

### src/framework/ (Page Framework — 6 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCL_ARK_GUI_COMPONENT | CLAS | Component base class |
| ZCL_ARK_GUI_PAGE | CLAS | Page base class (+ convention routing on_action_&lt;action&gt;) |
| ZCL_ARK_STATE_PAGE | CLAS | Declarative state page (kpi/table/form/chart/card_grid/text, form read-back + required validation, section builders: table_section from any internal table, chart_section single-series bar/line) |
| ZIF_ARK_GUI_MODAL | INTF | Modal interface |
| ZIF_ARK_GUI_ERROR_HANDLER | INTF | Error handler interface |
| ZIF_ARK_GUI_STATE | INTF | Declarative page state schema (draft) |

### src/components/ (UI Components — 7 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCL_ARK_HTML_FORM | CLAS | Form component |
| ZCL_ARK_HTML_TABLE | CLAS | Table component (+ from_any_table RTTI rendering) |
| ZCL_ARK_HTML_TOOLBAR | CLAS | Toolbar component |
| ZCL_ARK_ECHARTS | CLAS | ECharts chart component (lib injection unified into zcl_ark_js_library; get_option_json bridges to state pages) |
| ZCL_ARK_JSON_TREE | CLAS | JSON string -> collapsible tree component |
| ZCL_ARK_TEMPLATE | CLAS | String/MIME template engine ({{PLACEHOLDER}} syntax) |
| ZCL_ARK_THREE_VIEW | CLAS | three.js 3D view widget (WebGL, UMD asset, zif_ark_js_widget reference impl) |

### src/examples/ (Examples — 15 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZARK_EXAMPLE | PROG | Demo report launcher (host screen 1001) |
| ZARK_ECHARTS_DEMO | PROG | ECharts component capability demo |
| ZARK_SFLIGHT_DEMO | PROG | Database-driven dashboard demo (SFLIGHT/SCARR) |
| ZARK_LAUNCHER | PROG | Generic app launcher: transaction-code entry for any page class, zero boilerplate |
| ZCL_ARK_EXAMPLE_APP | CLAS | Demo application |
| ZCL_ARK_EXAMPLE_HELLO_PAGE | CLAS | Hello world page (demo hub) |
| ZCL_ARK_EXAMPLE_FORM_PAGE | CLAS | Form demo page |
| ZCL_ARK_EXAMPLE_TABLE_PAGE | CLAS | Table demo page |
| ZCL_ARK_EXAMPLE_CHART_PAGE | CLAS | Chart demo page (mixed chart + table content) |
| ZCL_ARK_EXAMPLE_DATA_PAGE | CLAS | Data viewer demo page (RTTI table + JSON tree) |
| ZCL_ARK_EXAMPLE_THREE_PAGE | CLAS | three.js 3D view example page |
| ZCL_ARK_EXAMPLE_STATE_PAGE | CLAS | Declarative state page demo |
| ZCL_ARK_EXAMPLE_UI5_PAGE | CLAS | UI5 host verification page |
| ZCL_ARK_EXAMPLE_UI5_STATE_PAGE | CLAS | UI5 declarative state demo page |
| ZCL_ARK_EXAMPLE_BROWSER_PAGE | CLAS | HTML viewer engine probe page (IE / Edge) |

## Total: 42 ABAP objects
