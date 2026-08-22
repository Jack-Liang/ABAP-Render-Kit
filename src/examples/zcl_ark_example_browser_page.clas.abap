CLASS zcl_ark_example_browser_page DEFINITION
  PUBLIC
  INHERITING FROM zcl_ark_gui_page
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor .

    METHODS on_event REDEFINITION .

  PROTECTED SECTION.
    METHODS build_html REDEFINITION .

  PRIVATE SECTION.
    METHODS build_toolbar RETURNING VALUE(ri_toolbar) TYPE REF TO zif_ark_html .
    METHODS build_content RETURNING VALUE(ri_content) TYPE REF TO zif_ark_html .
    METHODS build_probe_js RETURNING VALUE(rv_js) TYPE string .
ENDCLASS.

CLASS zcl_ark_example_browser_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK Framework - Browser Info' ).
  ENDMETHOD.

  METHOD build_html.
    mo_html->add( |<h1>Browser Info</h1>| ).
    mo_html->add( |<p>Detects which rendering engine the SAP GUI HTML viewer | &&
                  |is actually using on this machine.</p>| ).

    mo_html->add( build_toolbar( ) ).
    mo_html->add( |<hr>| ).
    mo_html->add( build_content( ) ).
    mo_html->add_js( build_probe_js( ) ).

    ri_html = mo_html.
  ENDMETHOD.

  METHOD build_toolbar.
    DATA(lo_toolbar) = zcl_ark_html_toolbar=>create( ).

    lo_toolbar->add_button(
      iv_label  = 'Back to Home'
      iv_action = 'nav_home' ).

    ri_toolbar = lo_toolbar->zif_ark_gui_renderable~render( ).
  ENDMETHOD.

  METHOD build_content.
    DATA(lo_content) = zcl_ark_html=>create( ).

    " 占位文本在 JS 执行后被结果表替换；JS 不可用时保留，
    " 恰好说明查看器连脚本都不执行（或处于极端的旧仿真模式）
    lo_content->div(
      iv_id      = 'ark_browser_info'
      iv_content = 'Collecting browser information via JavaScript...'
      iv_style   = 'color: #666;' ).

    lo_content->add(
      |<p style="margin-top:16px;color:#666;">SAP GUI for Windows embeds the | &&
      |IE (MSHTML) engine by default; since 7.70 an administrator can switch | &&
      |the HTML control to Edge (Chromium), see SAP Notes 2913405 / 3191784.</p>| ).

    ri_content = lo_content.
  ENDMETHOD.

  METHOD build_probe_js.
    " ES5-free（var/字符串拼接/无 JSON），兼容最老的 IE 仿真模式。
    " 反引号字面量中的花括号无需转义；整段为静态代码，不含业务数据
    DATA lv_nl TYPE string.
    lv_nl = cl_abap_char_utilities=>newline.

    rv_js =
      `(function() {` && lv_nl &&
      `  function esc(s) {` && lv_nl &&
      `    s = '' + s;` && lv_nl &&
      `    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');` && lv_nl &&
      `  }` && lv_nl &&
      `  function detectEngine(ua) {` && lv_nl &&
      `    if (ua.indexOf('Trident') > -1 || ua.indexOf('MSIE') > -1) {` && lv_nl &&
      `      var mode = '';` && lv_nl &&
      `      if (typeof document.documentMode !== 'undefined') {` && lv_nl &&
      `        mode = ' - document mode ' + document.documentMode;` && lv_nl &&
      `      }` && lv_nl &&
      `      return 'Internet Explorer (MSHTML / Trident)' + mode;` && lv_nl &&
      `    }` && lv_nl &&
      `    if (ua.indexOf('Edg/') > -1) {` && lv_nl &&
      `      return 'Edge (Chromium / WebView2)';` && lv_nl &&
      `    }` && lv_nl &&
      `    return 'Other or unknown - check the user agent string below';` && lv_nl &&
      `  }` && lv_nl &&
      `  var ua = navigator.userAgent;` && lv_nl &&
      `  var rows = '';` && lv_nl &&
      `  function row(name, value) {` && lv_nl &&
      `    rows += '<tr>' +` && lv_nl &&
      `      '<td style="padding:4px 10px;border:1px solid #ccc;font-weight:bold;white-space:nowrap;">' + esc(name) + '</td>' +` && lv_nl &&
      `      '<td style="padding:4px 10px;border:1px solid #ccc;">' + esc(value) + '</td>' +` && lv_nl &&
      `      '</tr>';` && lv_nl &&
      `  }` && lv_nl &&
      `  row('Detected engine', detectEngine(ua));` && lv_nl &&
      `  row('navigator.userAgent', ua);` && lv_nl &&
      `  row('navigator.appName', navigator.appName);` && lv_nl &&
      `  row('navigator.appVersion', navigator.appVersion);` && lv_nl &&
      `  row('navigator.platform',` && lv_nl &&
      `    (typeof navigator.platform === 'undefined') ? 'n/a' : navigator.platform);` && lv_nl &&
      `  row('navigator.language',` && lv_nl &&
      `    (typeof navigator.language === 'undefined') ? 'n/a' : navigator.language);` && lv_nl &&
      `  if (typeof document.documentMode !== 'undefined') {` && lv_nl &&
      `    row('document.documentMode', '' + document.documentMode);` && lv_nl &&
      `  }` && lv_nl &&
      `  var box = document.getElementById('ark_browser_info');` && lv_nl &&
      `  if (box) {` && lv_nl &&
      `    box.innerHTML = '<table cellspacing="0" style="border-collapse:collapse;font-family:monospace;">' +` && lv_nl &&
      `      rows + '</table>';` && lv_nl &&
      `  }` && lv_nl &&
      `})();`.
  ENDMETHOD.

  METHOD on_event.
    CASE ii_event->mv_action.
      WHEN 'nav_home'.
        rs_result-page = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.
      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
