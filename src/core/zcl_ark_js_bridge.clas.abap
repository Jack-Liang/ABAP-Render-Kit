CLASS zcl_ark_js_bridge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! 输出桥的引导脚本（定义 window.arkEmit(action, params)）。
    "! 同页只注入一次（页面作用域去重，zcl_ark_gui=>render 经
    "! zcl_ark_js_library=>reset_page_scope 重置）。
    "!
    "! 为什么需要前缀探测：Chromium 内核（SAP GUI 7.70 PL13+/8.00，
    "! SAP Note 3355910）不拦截 JS 发起的裸 sapevent: 导航 —— 页面内
    "! <a href="sapevent:.."> 会被内核解析为 file:///SAPEVENT:.. 再由控件
    "! 拦截，故运行期先探测前缀再拼 URL（同 abapGit getSapeventPrefix 方案）。
    "! 此逻辑原先在 echarts / state_page 各复制一份，现收敛于此
    CLASS-METHODS script
      RETURNING
        VALUE(rv_html) TYPE string .

    "! 生成一次 arkEmit 调用语句（须先注入 script( )）。
    "! iv_params_js 为 JS 对象字面量体，如 |name: p.name, idx: p.dataIndex|；
    "! 值须由调用方保证为合法 JS 表达式（动态值经 zcl_ark_convert=>escape_js
    "! 或 encodeURIComponent 处理）
    CLASS-METHODS emit_js
      IMPORTING
        !iv_action     TYPE string
        !iv_params_js  TYPE string OPTIONAL
      RETURNING
        VALUE(rv_js)   TYPE string .

    "! 页面作用域去重集重置（由 zcl_ark_js_library=>reset_page_scope 调用）
    CLASS-METHODS reset_page_scope .

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gv_included TYPE abap_bool .
ENDCLASS.



CLASS zcl_ark_js_bridge IMPLEMENTATION.


  METHOD script.
    IF gv_included = abap_true.
      RETURN.
    ENDIF.
    gv_included = abap_true.

    " params 值统一 encodeURIComponent：params 对象的值按 String() 转
    " 后编码，undefined/null 输出空串
    rv_html =
      |<script type="text/javascript">| &&
      |if (!window.arkEmit) \{| &&
      |window.arkEmit = function(action, params) \{| &&
      |var arkPrefix = '';| &&
      |if (document.querySelector('a[href*="file:///SAPEVENT:"]')) \{| &&
      |arkPrefix = 'file:///';| &&
      |\} else if (document.querySelector('a[href^="sap-cust"]')) \{| &&
      |arkPrefix = 'sap-cust://sap-place-holder/';| &&
      |\}| &&
      |var q = '';| &&
      |if (params) \{| &&
      |for (var k in params) \{| &&
      |if (!params.hasOwnProperty(k)) \{ continue; \}| &&
      |var v = params[k];| &&
      |v = (v === undefined \|\| v === null) ? '' : String(v);| &&
      |q += (q ? '&' : '') + encodeURIComponent(k) + '=' + encodeURIComponent(v);| &&
      |\}| &&
      |\}| &&
      |location.href = arkPrefix + 'SAPEVENT:' + action + (q ? '?' + q : '');| &&
      |\};| &&
      |\}| &&
      |</script>|.
  ENDMETHOD.


  METHOD emit_js.
    " 返回不带分号的语句：调用方按上下文自行拼接结尾
    DATA(lv_action) = zcl_ark_convert=>escape_js( iv_action ).
    IF iv_params_js IS INITIAL.
      rv_js = |arkEmit('{ lv_action }')|.
    ELSE.
      rv_js = |arkEmit('{ lv_action }', \{ { iv_params_js } \})|.
    ENDIF.
  ENDMETHOD.


  METHOD reset_page_scope.
    CLEAR gv_included.
  ENDMETHOD.


ENDCLASS.
