# ARK Project Manifest

## File Inventory

### Root
- `.abapgit.xml` — abapGit configuration
- `README.md` — Project documentation
- `MANIFEST.md` — This file (object inventory)
- `.gitignore` — Git ignore rules

### src/ (Main Package)
- `package.devc.xml` — Package definition

### src/core/ (Core Engine — 16 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCX_ARK_EXCEPTION | CLAS | Exception class |
| ZCL_ARK_HTML | CLAS | HTML builder engine |
| ZCL_ARK_GUI | CLAS | GUI controller |
| ZCL_ARK_GUI_EVENT | CLAS | Event object |
| ZCL_ARK_GUI_UTILS | CLAS | GUI utilities |
| ZCL_ARK_HTML_PARTS | CLAS | HTML parts collection |
| ZCL_ARK_HTML_VIEWER_GUI | CLAS | HTML viewer implementation |
| ZCL_ARK_CONVERT | CLAS | Conversion utilities |
| ZCL_ARK_JSON | CLAS | JSON serializer (standard sXML, zero deps) |
| ZIF_ARK_HTML | INTF | HTML interface |
| ZIF_ARK_GUI_RENDERABLE | INTF | Renderable interface |
| ZIF_ARK_GUI_EVENT | INTF | Event interface |
| ZIF_ARK_GUI_EVENT_HANDLER | INTF | Event handler interface |
| ZIF_ARK_GUI_SERVICES | INTF | GUI services interface |
| ZIF_ARK_HTML_VIEWER | INTF | HTML viewer interface |
| ZIF_ARK_GUI_ASSET_MANAGER | INTF | Asset manager interface |

### src/framework/ (Page Framework — 4 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCL_ARK_GUI_COMPONENT | CLAS | Component base class |
| ZCL_ARK_GUI_PAGE | CLAS | Page base class |
| ZIF_ARK_GUI_MODAL | INTF | Modal interface |
| ZIF_ARK_GUI_ERROR_HANDLER | INTF | Error handler interface |

### src/components/ (UI Components — 5 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZCL_ARK_HTML_FORM | CLAS | Form component |
| ZCL_ARK_HTML_TABLE | CLAS | Table component |
| ZCL_ARK_HTML_TOOLBAR | CLAS | Toolbar component |
| ZCL_ARK_ECHARTS | CLAS | ECharts chart component |
| ZCL_ARK_TEMPLATE | CLAS | String/MIME template engine ({{PLACEHOLDER}} syntax) |

### src/examples/ (Examples — 9 objects)
| Object | Type | Description |
|--------|------|-------------|
| ZARK_EXAMPLE | PROG | Demo report launcher (host screen 1001) |
| ZARK_ECHARTS_DEMO | PROG | ECharts component capability demo |
| ZARK_SFLIGHT_DEMO | PROG | Database-driven dashboard demo (SFLIGHT/SCARR) |
| ZCL_ARK_EXAMPLE_APP | CLAS | Demo application |
| ZCL_ARK_EXAMPLE_HELLO_PAGE | CLAS | Hello world page |
| ZCL_ARK_EXAMPLE_FORM_PAGE | CLAS | Form demo page |
| ZCL_ARK_EXAMPLE_TABLE_PAGE | CLAS | Table demo page |
| ZCL_ARK_EXAMPLE_CHART_PAGE | CLAS | Chart demo page (mixed chart + table content) |
| ZCL_ARK_EXAMPLE_BROWSER_PAGE | CLAS | HTML viewer engine probe page (IE / Edge) |

## Total: 34 ABAP objects
