CLASS zcl_ark_example_ui5_page DEFINITION
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
    TYPES ty_num TYPE STANDARD TABLE OF i WITH EMPTY KEY .

    TYPES:
      BEGIN OF ty_kpi,
        title TYPE string,
        value TYPE string,
        delta TYPE string,
        dir   TYPE string,
        sema  TYPE string,
        "! 数值以字符串传输（string_table 规避 VALUE 构造器对基本类型行的
        "! 跨类型字面量限制），前端 SPARK.map(Number) 还原
        spark TYPE string_table,
      END OF ty_kpi,
      tt_kpi TYPE STANDARD TABLE OF ty_kpi WITH EMPTY KEY .

    TYPES:
      BEGIN OF ty_row,
        doc      TYPE string,
        customer TYPE string,
        amount   TYPE i,
        qty      TYPE i,
        status   TYPE string,
        sema     TYPE string,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY .

    "! ty_state 与页面初始 state 对象同构；zcl_ark_json 序列化键名大写，
    "! JS 侧按大写访问（p.KPI[i].TITLE 等）
    TYPES:
      BEGIN OF ty_state,
        kind         TYPE string,
        seq          TYPE i,
        path         TYPE string,
        doc          TYPE string,
        factor       TYPE i,
        title        TYPE string,
        subtitle     TYPE string,
        refreshlabel TYPE string,
        kpi          TYPE tt_kpi,
        bar          TYPE ty_num,
        line         TYPE ty_num,
        rows         TYPE tt_row,
      END OF ty_state .

    DATA mv_factor TYPE i VALUE 1 ##NO_TEXT.

    METHODS build_state
      IMPORTING !iv_kind       TYPE string
      RETURNING VALUE(rs_state) TYPE ty_state .

    METHODS respond
      IMPORTING !is_state TYPE ty_state
      RAISING   zcx_ark_exception .

    METHODS post_value
      IMPORTING
        !ii_event       TYPE REF TO zif_ark_gui_event
        !iv_name        TYPE string
      RETURNING VALUE(rv_value) TYPE string .
ENDCLASS.



CLASS zcl_ark_example_ui5_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    set_title( 'ARK - UI5 Host Verification' ).
  ENDMETHOD.


  METHOD on_event.
    DATA ls_state TYPE ty_state.

    CASE ii_event->mv_action.
      WHEN 'ui5_ping'.
        ls_state = build_state( 'pong' ).
        ls_state-path = ii_event->query( 'path' ).
        ls_state-doc  = ii_event->query( 'doc' ).
        ls_state-seq  = ii_event->query( 'seq' ).
        respond( ls_state ).
        rs_result-state     = 1.
        rs_result-keep_view = abap_true.

      WHEN 'ui5_post'.
        ls_state = build_state( 'post_ok' ).
        ls_state-seq = post_value( ii_event = ii_event iv_name = 'seq' ).
        respond( ls_state ).
        rs_result-state     = 1.
        rs_result-keep_view = abap_true.

      WHEN 'ui5_refresh'.
        mv_factor = mv_factor MOD 5 + 1.
        ls_state  = build_state( 'refresh' ).
        ls_state-seq = ii_event->query( 'seq' ).
        respond( ls_state ).
        rs_result-state     = 1.
        rs_result-keep_view = abap_true.

      WHEN 'nav_home'.
        rs_result-page  = NEW zcl_ark_example_hello_page( ).
        rs_result-state = 1.

      WHEN OTHERS.
        rs_result = super->on_event( ii_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD build_state.
    DATA lv_sales  TYPE i.
    DATA lv_orders TYPE i.

    rs_state-kind         = iv_kind.
    rs_state-factor       = mv_factor.
    rs_state-title        = '销售概览 · 2026 Q3 — UI5 宿主验证'.
    rs_state-subtitle     = '刷新/行点击走真实 sapevent 往返；表格图表就地更新，UI5 不重启'.
    rs_state-refreshlabel = |刷新数据 (x{ mv_factor })|.

    lv_sales  = 4286 * mv_factor.
    lv_orders = 18532 * mv_factor.

    rs_state-kpi = VALUE tt_kpi(
      ( title = '总销售额'
        value = |¥ { lv_sales } 万|
        delta = '+12.4% 环比' dir = 'up' sema = '#0070f2'
        spark = VALUE string_table( ( `32` ) ( `38` ) ( `35` ) ( `42` ) ( `48` ) ( `45` ) ( `52` ) ( `58` ) ) )
      ( title = '订单数'
        value = |{ lv_orders }|
        delta = '+6.8% 环比' dir = 'up' sema = '#04aca7'
        spark = VALUE string_table( ( `12` ) ( `14` ) ( `13` ) ( `15` ) ( `16` ) ( `15` ) ( `17` ) ( `19` ) ) )
      ( title = '退货率'
        value = '2.1%'
        delta = '-0.4pp 环比' dir = 'down' sema = '#e9730c'
        spark = VALUE string_table( ( `3.4` ) ( `3.2` ) ( `2.9` ) ( `2.7` ) ( `2.4` ) ( `2.3` ) ( `2.1` ) ) )
      ( title = '客户满意度'
        value = '94.6'
        delta = '+1.2 环比' dir = 'up' sema = '#107e3e'
        spark = VALUE string_table( ( `90` ) ( `91` ) ( `92` ) ( `92.8` ) ( `93.5` ) ( `94` ) ( `94.6` ) ) ) ).

    rs_state-bar = VALUE ty_num(
      ( 420 * mv_factor ) ( 455 * mv_factor ) ( 490 * mv_factor ) ( 530 * mv_factor )
      ( 510 * mv_factor ) ( 580 * mv_factor ) ( 620 * mv_factor ) ( 681 * mv_factor ) ).

    rs_state-line = VALUE ty_num( ( 88 ) ( 92 ) ( 95 ) ( 101 ) ( 97 ) ( 106 ) ( 110 ) ( 115 ) ).

    rs_state-rows = VALUE tt_row(
      ( doc = '0080012345' customer = '华信科技'    amount = 1286000 * mv_factor qty = 120 status = '已完成' sema = 'positive' )
      ( doc = '0080012346' customer = '南方物流集团' amount = 862400  * mv_factor qty = 58  status = '待审批' sema = 'critical' )
      ( doc = '0080012347' customer = '北方重工'    amount = 2045900 * mv_factor qty = 12  status = '已发货' sema = 'positive' )
      ( doc = '0080012348' customer = '东海商贸'    amount = 95700   * mv_factor qty = 640 status = '被拒绝' sema = 'negative' )
      ( doc = '0080012349' customer = '西部能源'    amount = 530200  * mv_factor qty = 35  status = '处理中' sema = 'neutral' ) ).
  ENDMETHOD.


  METHOD respond.
    " 桥协议：响应文档载入 ark_bridge 帧，其脚本 postMessage 回常驻主页面。
    " __ark_state 标记用于过滤无关 message 事件
    DATA lv_json TYPE string.
    lv_json = zcl_ark_json=>to_json( is_state ).

    get_services( )->push_to_frame(
      iv_frame = 'ark_bridge'
      iv_text  = `<script>try { parent.postMessage({__ark_state: 1, payload: ` && lv_json &&
                 `}, '*'); } catch (e) { }</script>` ).
  ENDMETHOD.


  METHOD post_value.
    " postdata 各行为 255 字符片段，先拼接再按 &/= 解析
    DATA lv_body TYPE string.
    DATA lv_pair TYPE string.
    DATA lv_name TYPE string.
    DATA lv_value TYPE string.

    LOOP AT ii_event->mt_postdata INTO DATA(lv_line).
      lv_body = lv_body && lv_line.
    ENDLOOP.

    SPLIT lv_body AT '&' INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO lv_pair.
      SPLIT lv_pair AT '=' INTO lv_name lv_value.
      IF lv_name = iv_name.
        rv_value = lv_value.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_html.
    mo_html->add_css(
      `html, body { height: 100%; margin: 0; background: #f0f0f0;` &&
      `  font-family: "72", -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif; }` &&
      `.note { padding: 4px 16px; font-size: 12px; color: #666; background: #f5f5f5; }` &&
      `.page-title { font-size: 22px; font-weight: 400; margin: 20px 32px 2px; color: #1d2d3e; }` &&
      `.page-sub { font-size: 13px; color: #6a6d70; margin: 0 32px 16px; }` &&
      `.card { background: #fff; border: 1px solid #e5e5e5; border-radius: 12px;` &&
      `  padding: 14px 18px; transition: box-shadow .2s, transform .2s; }` &&
      `.card:hover { box-shadow: 0 4px 12px rgba(0,0,0,.14); transform: translateY(-2px); }` &&
      `.kpi-grid { display: grid;` &&
      `  grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));` &&
      `  gap: 16px; padding: 0 32px 16px; }` &&
      `.kpi-title { font-size: 13px; color: #6a6d70; }` &&
      `.kpi-value { font-size: 28px; color: #1d2d3e; margin: 4px 0 2px; }` &&
      `.kpi-delta { font-size: 13px; }` &&
      `.kpi-delta.up { color: #107e3e; } .kpi-delta.down { color: #bb0000; }` &&
      `.spark { width: 100%; height: 34px; margin-top: 6px; }` &&
      `.chart-row { display: grid; grid-template-columns: 2fr 1fr; gap: 16px; padding: 0 32px 16px; }` &&
      `@media (max-width: 900px) { .chart-row { grid-template-columns: 1fr; } }` &&
      `.chart-box { width: 100%; height: 300px; }` &&
      `.table-card { margin: 0 32px 24px; }` &&
      `.table-card table { width: 100%; border-collapse: collapse; }` &&
      `.table-card th { text-align: left; font-size: 12px; font-weight: 500; color: #6a6d70;` &&
      `  padding: 10px 16px; border-bottom: 1px solid #d9d9d9; background: #fafafa; }` &&
      `.table-card td { padding: 10px 16px; font-size: 13px; border-bottom: 1px solid #e5e5e5; }` &&
      `.table-card tr:last-child td { border-bottom: none; }` &&
      `.table-card tbody tr:hover { background: #f5f5f5; }` &&
      `.num { text-align: right; font-variant-numeric: tabular-nums; }` &&
      `.status { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; }` &&
      `.status::before { content: ""; width: 8px; height: 8px; border-radius: 50%; }` &&
      `.status.positive::before { background: #107e3e; }` &&
      `.status.critical::before { background: #e9730c; }` &&
      `.status.negative::before { background: #bb0000; }` &&
      `.status.neutral::before { background: #6a6d70; }` &&
      `a.plain { color: #0070f2; text-decoration: none; cursor: pointer; }` &&
      `.rpt-card { margin: 12px 32px 4px; background: #fff; border: 1px solid #d9d9d9;` &&
      `  border-radius: 12px; padding: 12px 16px; }` &&
      `.rpt-title { font-size: 14px; font-weight: 700; color: #1d2d3e; margin-bottom: 8px; }` &&
      `.rpt-table { width: 100%; border-collapse: collapse; font-size: 12px; }` &&
      `.rpt-table td { padding: 4px 8px; border-bottom: 1px solid #f0f0f0;` &&
      `  vertical-align: top; font-variant-numeric: tabular-nums; }` &&
      `.rpt-table td:first-child { white-space: nowrap; color: #485059; width: 1%; }` &&
      `.rpt-table td:nth-child(2) { width: 60px; font-weight: 700; }` &&
      `.st { display: inline-block; padding: 0 6px; border-radius: 4px; }` &&
      `.st-pass { color: #107e3e; background: #effaf3; }` &&
      `.st-fail { color: #bb0000; background: #fbeaea; }` &&
      `.st-warn { color: #e9730c; background: #fdf3e7; }` &&
      `.st-info, .st-skip { color: #6a6d70; background: #f2f2f2; }` &&
      `.rpt-btn { font-size: 12px; margin: 8px 6px 0 0; padding: 4px 12px;` &&
      `  border: 1px solid #0070f2; color: #0070f2; background: #fff;` &&
      `  border-radius: 4px; cursor: pointer; }` &&
      `.rpt-btn:hover { background: #f0f7ff; }` &&
      `#rpt_out { width: 100%; box-sizing: border-box; margin-top: 10px; font: 11px monospace;` &&
      `  color: #333; background: #fafafa; border: 1px solid #e5e5e5; }` ).

    " ===== 脚本 1：基础设施（错误日志 / 桥 / 报告 / 本地渲染）=====
    " 必须位于 UI5/ECharts 标签之前：它们的 onload/onerror 属性要调到这里定义的函数
    mo_html->add(
      `<script>` &&
      `window.__arkT0 = (window.performance && performance.now) ? performance.now() : Date.now();` &&
      `function now() { return (window.performance && performance.now) ? performance.now() : Date.now(); }` &&
      `window.onerror = function (m, src, l) {` &&
      `  var d = document.createElement("div");` &&
      `  d.textContent = "JS ERROR: " + m + " @" + (src || "") + ":" + l;` &&
      `  var el = document.getElementById("errlog");` &&
      `  if (el) { el.appendChild(d); }` &&
      `  return false;` &&
      `};` &&
      `function errlog(msg) {` &&
      `  var el = document.getElementById("errlog");` &&
      `  if (el) { var d = document.createElement("div"); d.textContent = msg; el.appendChild(d); }` &&
      `}` &&
      `var ARK = { seq: 0, t0: {}, stat: { iframe: [], main: [], post: [], refresh: -1 },` &&
      `  burstN: 0, burstGot: 0, burstMs: [], sparks: [], lines: [], bootCore: -1, echReady: false };` &&
      `function rpt(id, status, detail) {` &&
      `  var st = document.getElementById("r_st_" + id);` &&
      `  var dt = document.getElementById("r_dt_" + id);` &&
      `  if (st) { st.textContent = status; st.className = "st st-" + status.toLowerCase(); }` &&
      `  if (dt) { dt.textContent = detail; }` &&
      `  ARK.lines.push(new Date().toLocaleTimeString() + " [" + id + "] " + status + " | " + detail);` &&
      `  var ta = document.getElementById("rpt_out");` &&
      `  if (ta) { ta.value = ARK.lines.join("\n"); }` &&
      `}` &&
      `function toast(msg) {` &&
      `  if (window.sap && sap.m && sap.m.MessageToast) { sap.m.MessageToast.show(msg); }` &&
      `  else { errlog("TOAST: " + msg); }` &&
      `}` &&
      `function copyReport() {` &&
      `  var ta = document.getElementById("rpt_out");` &&
      `  ta.focus(); ta.select();` &&
      `  try { document.execCommand("copy"); toast("报告已复制"); } catch (e) { errlog("复制失败: " + e.message); }` &&
      `}` &&
      `function arkPrefix() {` &&
      `  var a = document.getElementById("ark_probe");` &&
      `  var h = (a && a.href) ? String(a.href) : "";` &&
      `  if (h.indexOf("file:///SAPEVENT:") === 0) { return "file:///"; }` &&
      `  if (h.indexOf("sap-cust") === 0) { return "sap-cust://sap-place-holder/"; }` &&
      `  return "";` &&
      `}` &&
      `function arkUrl(action, params) {` &&
      `  var u = arkPrefix() + "SAPEVENT:" + action, k, qs = [];` &&
      `  for (k in params) { if (params.hasOwnProperty(k)) { qs.push(k + "=" + encodeURIComponent(params[k])); } }` &&
      `  return qs.length ? u + "?" + qs.join("&") : u;` &&
      `}` &&
      `function nextSeq() { ARK.seq += 1; ARK.t0[ARK.seq] = now(); return ARK.seq; }` &&
      `function fireIframe(action, params) {` &&
      `  params = params || {}; params.seq = nextSeq();` &&
      `  window.frames["ark_bridge"].location.href = arkUrl(action, params);` &&
      `  return params.seq;` &&
      `}` &&
      `function fireMain(action, params) {` &&
      `  params = params || {}; params.seq = nextSeq();` &&
      `  location.href = arkUrl(action, params);` &&
      `}` &&
      `function firePost(action, fields) {` &&
      `  fields = fields || {};` &&
      `  var f = document.getElementById("ark_form");` &&
      `  f.action = arkPrefix() + "SAPEVENT:" + action;` &&
      `  document.getElementById("ark_f_seq").value = String(nextSeq());` &&
      `  document.getElementById("ark_f_kind").value = fields.kind || "";` &&
      `  f.submit();` &&
      `}` &&
      `function armTimeout(id, condFn, label) {` &&
      `  setTimeout(function () { if (!condFn()) { rpt(id, "FAIL", label + "：9 秒超时未响应"); } }, 9000);` &&
      `}` &&
      `window.addEventListener("message", function (ev) {` &&
      `  var d = ev.data;` &&
      `  if (!d || d.__ark_state !== 1) { return; }` &&
      `  var p = d.payload || {};` &&
      `  var s = Number(p.SEQ || 0), dt = -1;` &&
      `  if (s > 0 && ARK.t0[s] !== undefined) { dt = Math.round(now() - ARK.t0[s]); delete ARK.t0[s]; }` &&
      `  if (p.KIND === "refresh") {` &&
      `    ARK.stat.refresh = dt;` &&
      `    applyState(p);` &&
      `    rpt("bridge_refresh", dt >= 0 ? "PASS" : "WARN", "全量 state 往返 " + dt + " ms · 已就地更新为 x" + p.FACTOR);` &&
      `    return;` &&
      `  }` &&
      `  if (p.KIND === "post_ok") {` &&
      `    ARK.stat.post.push(dt);` &&
      `    rpt("bridge_c", "PASS", "POST 往返 " + dt + " ms（postdata 回读 seq=" + p.SEQ + "）");` &&
      `    return;` &&
      `  }` &&
      `  if (p.KIND === "pong") {` &&
      `    if (p.PATH === "iframe") {` &&
      `      ARK.stat.iframe.push(dt);` &&
      `      rpt("bridge_a", "PASS", "iframe GET 往返 " + dt + " ms");` &&
      `    } else if (p.PATH === "main") {` &&
      `      ARK.stat.main.push(dt);` &&
      `      rpt("bridge_b", "PASS", "主框架 GET 往返 " + dt + " ms");` &&
      `    } else if (p.PATH === "burst") {` &&
      `      ARK.burstGot += 1; ARK.burstMs.push(dt);` &&
      `      rpt("bridge_burst", "INFO", "连发进度 " + ARK.burstGot + "/" + ARK.burstN + " · 最近 " + dt + " ms");` &&
      `      if (ARK.burstGot >= ARK.burstN) {` &&
      `        var mn = Math.min.apply(null, ARK.burstMs), mx = Math.max.apply(null, ARK.burstMs);` &&
      `        var av = Math.round(ARK.burstMs.reduce(function (a, b) { return a + b; }, 0) / ARK.burstMs.length);` &&
      `        rpt("bridge_burst", "PASS", mn + " / " + av + " / " + mx + " ms（min/avg/max，共 " + ARK.burstN + " 次）");` &&
      `      }` &&
      `    }` &&
      `    if (p.DOC) { toast("行 " + p.DOC + " 往返 " + dt + " ms（UI5 未重启）"); }` &&
      `  }` &&
      `});` &&
      `function arkCoreLoaded() {` &&
      `  ARK.bootCore = Math.round(now() - window.__arkT0);` &&
      `  rpt("cdn_ui5", "PASS", "sap-ui-core.js 加载并执行 " + ARK.bootCore + " ms");` &&
      `}` &&
      `function arkCoreFailed() { rpt("cdn_ui5", "FAIL", "bootstrap onerror：WebView2 拉不到 UI5 CDN"); }` &&
      `function arkEchOk() {` &&
      `  ARK.echReady = true;` &&
      `  rpt("cdn_echarts", "PASS", "echarts.min.js 加载 " + Math.round(now() - window.__arkT0) + " ms（自页面起点）");` &&
      `  if (typeof renderCharts === "function") { renderCharts(); }` &&
      `}` &&
      `function arkEchFailed() { rpt("cdn_echarts", "FAIL", "script onerror：echarts CDN 不可达"); }` &&
      `</script>` ).

    " ===== UI5 bootstrap 与 ECharts（同步脚本标签，onload/onerror 上报报告行）=====
    mo_html->add(
      `<script id="sap-ui-bootstrap"` &&
      `        src="https://sdk.openui5.org/resources/sap-ui-core.js"` &&
      `        data-sap-ui-theme="sap_horizon"` &&
      `        data-sap-ui-libs="sap.m,sap.f"` &&
      `        data-sap-ui-compatVersion="edge"` &&
      `        data-sap-ui-async="true"` &&
      `        onload="arkCoreLoaded()" onerror="arkCoreFailed()"></script>` &&
      `<script src="https://cdn.jsdelivr.net/npm/echarts@6.1.0/dist/echarts.min.js"` &&
      `        onload="arkEchOk()" onerror="arkEchFailed()"></script>` ).

    " ===== 页面结构：报告面板 + UI5 挂载点 + 原生分区 + 桥基础设施 =====
    mo_html->add(
      `<a id="ark_probe" href="sapevent:x" style="display:none"></a>` &&
      `<div class="rpt-card">` &&
      `  <div class="rpt-title">宿主验证报告（Edge 内核 SAP GUI · a4h）</div>` &&
      `  <table class="rpt-table">` &&
      `    <tr><td>① UI5 CDN</td><td id="r_st_cdn_ui5">…</td><td id="r_dt_cdn_ui5">探测中</td></tr>` &&
      `    <tr><td>① ECharts CDN</td><td id="r_st_cdn_echarts">…</td><td id="r_dt_cdn_echarts">探测中</td></tr>` &&
      `    <tr><td>② sap.m/f 渲染</td><td id="r_st_ui5_render">…</td><td id="r_dt_ui5_render">探测中</td></tr>` &&
      `    <tr><td>③ 桥 · iframe GET</td><td id="r_st_bridge_a">…</td><td id="r_dt_bridge_a">未测</td></tr>` &&
      `    <tr><td>③ 桥 · 主框架 GET</td><td id="r_st_bridge_b">…</td><td id="r_dt_bridge_b">未测</td></tr>` &&
      `    <tr><td>③ 桥 · 表单 POST</td><td id="r_st_bridge_c">…</td><td id="r_dt_bridge_c">未测</td></tr>` &&
      `    <tr><td>③ 连发 ×10</td><td id="r_st_bridge_burst">…</td><td id="r_dt_bridge_burst">未测</td></tr>` &&
      `    <tr><td>③ 全量 state 更新</td><td id="r_st_bridge_refresh">…</td><td id="r_dt_bridge_refresh">未测</td></tr>` &&
      `    <tr><td>④ 资源双取</td><td id="r_st_cache">…</td><td id="r_dt_cache">未测</td></tr>` &&
      `    <tr><td>④ 启动资源统计</td><td id="r_st_cache_res">…</td><td id="r_dt_cache_res">未测</td></tr>` &&
      `    <tr><td>④ 启动耗时</td><td id="r_st_boot_ms">…</td><td id="r_dt_boot_ms">探测中</td></tr>` &&
      `  </table>` &&
      `  <button class="rpt-btn" onclick="autoRun()">重跑自动测试</button>` &&
      `  <button class="rpt-btn" onclick="burst()">连发 ×10</button>` &&
      `  <button class="rpt-btn" onclick="fireIframe('ui5_refresh')">刷新数据（桥）</button>` &&
      `  <button class="rpt-btn" onclick="copyReport()">复制报告</button>` &&
      `  <textarea id="rpt_out" rows="8" readonly spellcheck="false"></textarea>` &&
      `</div>` ).

    mo_html->add(
      `<div id="ui5-shellbar"></div>` &&
      `<div class="note">方案 B 宿主验证：ShellBar/工具栏为 sap.m+f；KPI 卡与图表为原生 div+ECharts；` &&
      `事件走真实 sapevent 桥（隐藏 iframe ark_bridge + postMessage 回传）</div>` &&
      `<div id="ui5-toolbar" style="padding: 8px 32px;"></div>` &&
      `<h1 class="page-title" id="pg-title"></h1>` &&
      `<p class="page-sub" id="pg-sub"></p>` &&
      `<div class="kpi-grid" id="kpi-grid"></div>` &&
      `<div class="chart-row">` &&
      `  <div class="card"><div class="kpi-title">月度销售额与目标达成</div>` &&
      `    <div id="chart-bar" class="chart-box"></div></div>` &&
      `  <div class="card"><div class="kpi-title">渠道占比（静态）</div>` &&
      `    <div id="chart-pie" class="chart-box"></div></div>` &&
      `</div>` &&
      `<div class="card table-card">` &&
      `  <table>` &&
      `    <thead><tr>` &&
      `      <th>销售凭证</th><th>客户</th>` &&
      `      <th style="text-align:right">净价值</th>` &&
      `      <th style="text-align:right">数量</th><th>状态</th><th></th>` &&
      `    </tr></thead>` &&
      `    <tbody id="doc-rows"></tbody>` &&
      `  </table>` &&
      `</div>` &&
      `<iframe id="ark_bridge" name="ark_bridge" style="display:none;width:0;height:0;border:0;"></iframe>` &&
      `<form id="ark_form" method="post" action="" target="ark_bridge">` &&
      `  <input type="hidden" name="seq" id="ark_f_seq">` &&
      `  <input type="hidden" name="kind" id="ark_f_kind">` &&
      `</form>` &&
      `<div id="errlog" style="font:12px monospace;color:#b00;padding:8px;white-space:pre-wrap"></div>` ).

    " ===== 脚本 2：初始 state + 本地渲染 + 桥响应应用 =====
    mo_html->add(
      `<script>` &&
      `var QUARTZ = { brand: "#0070f2", teal: "#04aca7", purple: "#9255d7",` &&
      `  orange: "#e9730c", good: "#107e3e", bad: "#bb0000", neutral: "#6a6d70" };` &&
      `var state = {` &&
      `  FACTOR: 1, filterQ: "",` &&
      `  TITLE: "销售概览 · 2026 Q3 — UI5 宿主验证",` &&
      `  SUBTITLE: "刷新/行点击走真实 sapevent 往返；表格图表就地更新，UI5 不重启",` &&
      `  REFRESHLABEL: "刷新数据 (x1)",` &&
      `  KPI: [` &&
      `    { TITLE: "总销售额", VALUE: "¥ 4286 万", DELTA: "+12.4% 环比", DIR: "up", SEMA: QUARTZ.brand, SPARK: [32,38,35,42,48,45,52,58] },` &&
      `    { TITLE: "订单数", VALUE: "18532", DELTA: "+6.8% 环比", DIR: "up", SEMA: QUARTZ.teal, SPARK: [12,14,13,15,16,15,17,19] },` &&
      `    { TITLE: "退货率", VALUE: "2.1%", DELTA: "-0.4pp 环比", DIR: "down", SEMA: QUARTZ.orange, SPARK: [3.4,3.2,2.9,2.7,2.4,2.3,2.1] },` &&
      `    { TITLE: "客户满意度", VALUE: "94.6", DELTA: "+1.2 环比", DIR: "up", SEMA: QUARTZ.good, SPARK: [90,91,92,92.8,93.5,94,94.6] } ],` &&
      `  BAR: [420,455,490,530,510,580,620,681],` &&
      `  LINE: [88,92,95,101,97,106,110,115],` &&
      `  ALL_ROWS: [` &&
      `    { DOC: "0080012345", CUSTOMER: "华信科技", AMOUNT: 1286000, QTY: 120, STATUS: "已完成", SEMA: "positive" },` &&
      `    { DOC: "0080012346", CUSTOMER: "南方物流集团", AMOUNT: 862400, QTY: 58, STATUS: "待审批", SEMA: "critical" },` &&
      `    { DOC: "0080012347", CUSTOMER: "北方重工", AMOUNT: 2045900, QTY: 12, STATUS: "已发货", SEMA: "positive" },` &&
      `    { DOC: "0080012348", CUSTOMER: "东海商贸", AMOUNT: 95700, QTY: 640, STATUS: "被拒绝", SEMA: "negative" },` &&
      `    { DOC: "0080012349", CUSTOMER: "西部能源", AMOUNT: 530200, QTY: 35, STATUS: "处理中", SEMA: "neutral" } ],` &&
      `  ROWS: []` &&
      `};` &&
      `state.ROWS = state.ALL_ROWS.slice(0);` &&
      `function applyFilter(q) {` &&
      `  state.filterQ = q;` &&
      `  var all = state.ALL_ROWS;` &&
      `  if (!q) { state.ROWS = all.slice(0); }` &&
      `  else {` &&
      `    var ql = q.toLowerCase();` &&
      `    state.ROWS = [];` &&
      `    all.forEach(function (r) {` &&
      `      if (JSON.stringify(r).toLowerCase().indexOf(ql) >= 0) { state.ROWS.push(r); }` &&
      `    });` &&
      `  }` &&
      `  renderText();` &&
      `}` &&
      `function renderText() {` &&
      `  document.getElementById("pg-title").textContent = state.TITLE;` &&
      `  document.getElementById("pg-sub").textContent = state.SUBTITLE;` &&
      `  var grid = document.getElementById("kpi-grid");` &&
      `  grid.innerHTML = "";` &&
      `  state.KPI.forEach(function (k, i) {` &&
      `    var card = document.createElement("div");` &&
      `    card.className = "card";` &&
      `    card.innerHTML = '<div class="kpi-title">' + k.TITLE + '</div>' +` &&
      `      '<div class="kpi-value">' + k.VALUE + '</div>' +` &&
      `      '<span class="kpi-delta ' + k.DIR + '">' + k.DELTA + '</span>' +` &&
      `      '<div id="sp_' + i + '" class="spark"></div>';` &&
      `    grid.appendChild(card);` &&
      `  });` &&
      `  var tb = document.getElementById("doc-rows");` &&
      `  tb.innerHTML = "";` &&
      `  state.ROWS.forEach(function (r) {` &&
      `    var tr = document.createElement("tr");` &&
      `    tr.innerHTML =` &&
      `      '<td><a class="plain" href="#" onclick="rowClick(\'' + r.DOC + '\');return false;">' + r.DOC + '</a></td>' +` &&
      `      '<td>' + r.CUSTOMER + '</td>' +` &&
      `      '<td class="num">¥ ' + (r.AMOUNT || 0).toLocaleString() + '</td>' +` &&
      `      '<td class="num">' + r.QTY + '</td>' +` &&
      `      '<td><span class="status ' + r.SEMA + '">' + r.STATUS + '</span></td>' +` &&
      `      '<td><a class="plain" href="#" onclick="rowClick(\'' + r.DOC + '\');return false;">详情</a></td>';` &&
      `    tb.appendChild(tr);` &&
      `  });` &&
      `  if (ARK.echReady) { renderCharts(); }` &&
      `}` &&
      `function rowClick(doc) { fireIframe("ui5_ping", { path: "iframe", doc: doc }); }` &&
      `function chartOf(id) {` &&
      `  var el = document.getElementById(id);` &&
      `  if (!el || !window.echarts) { return null; }` &&
      `  return echarts.getInstanceByDom(el) || echarts.init(el);` &&
      `}` &&
      `function renderCharts() {` &&
      `  if (!window.echarts) { return; }` &&
      `  var i;` &&
      `  for (i = 0; i < ARK.sparks.length; i++) { try { ARK.sparks[i].dispose(); } catch (e) { } }` &&
      `  ARK.sparks = [];` &&
      `  state.KPI.forEach(function (k, i) {` &&
      `    var el = document.getElementById("sp_" + i);` &&
      `    if (!el) { return; }` &&
      `    var ch = echarts.init(el);` &&
      `    ARK.sparks.push(ch);` &&
      `    ch.setOption({` &&
      `      grid: { left: 0, right: 0, top: 2, bottom: 2 },` &&
      `      xAxis: { type: "category", show: false },` &&
      `      yAxis: { type: "value", show: false },` &&
      `      series: [{ type: "line", data: (k.SPARK || []).map(Number), symbol: "none", smooth: true,` &&
      `        lineStyle: { width: 2, color: k.SEMA },` &&
      `        areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1,` &&
      `          colorStops: [` &&
      `            { offset: 0, color: k.SEMA + "40" },` &&
      `            { offset: 1, color: k.SEMA + "00" } ] } } }]` &&
      `    });` &&
      `  });` &&
      `  var bar = chartOf("chart-bar");` &&
      `  if (bar) {` &&
      `    bar.setOption({` &&
      `      tooltip: { trigger: "axis" }, legend: { top: 0 },` &&
      `      grid: { left: 56, right: 48, top: 32, bottom: 32 },` &&
      `      xAxis: { type: "category", data: ["1月","2月","3月","4月","5月","6月","7月","8月"] },` &&
      `      yAxis: [` &&
      `        { type: "value", name: "万元" },` &&
      `        { type: "value", name: "达成率", min: 60, max: 130,` &&
      `          axisLabel: { formatter: "{value}%" } } ],` &&
      `      series: [` &&
      `        { name: "销售额", type: "bar", barWidth: 22, data: state.BAR,` &&
      `          itemStyle: { color: QUARTZ.brand, borderRadius: [4,4,0,0] } },` &&
      `        { name: "达成率", type: "line", yAxisIndex: 1, smooth: true, data: state.LINE,` &&
      `          lineStyle: { color: QUARTZ.teal, width: 2.5 },` &&
      `          itemStyle: { color: QUARTZ.teal } } ]` &&
      `    });` &&
      `  }` &&
      `  var pie = chartOf("chart-pie");` &&
      `  if (pie && !pie.__arkDone) {` &&
      `    pie.__arkDone = true;` &&
      `    pie.setOption({` &&
      `      tooltip: { trigger: "item", formatter: "{b}: {c}（{d}%）" },` &&
      `      legend: { bottom: 0 },` &&
      `      series: [{ type: "pie", radius: ["48%", "70%"], center: ["50%", "42%"],` &&
      `        label: { show: false },` &&
      `        itemStyle: { borderColor: "#fff", borderWidth: 2 },` &&
      `        data: [` &&
      `          { value: 46, name: "直销", itemStyle: { color: QUARTZ.brand } },` &&
      `          { value: 28, name: "分销", itemStyle: { color: QUARTZ.teal } },` &&
      `          { value: 18, name: "电商", itemStyle: { color: QUARTZ.purple } },` &&
      `          { value: 8, name: "其他", itemStyle: { color: QUARTZ.orange } } ] }]` &&
      `    });` &&
      `  }` &&
      `}` &&
      `function applyState(p) {` &&
      `  state.TITLE = p.TITLE; state.SUBTITLE = p.SUBTITLE;` &&
      `  state.REFRESHLABEL = p.REFRESHLABEL; state.FACTOR = p.FACTOR;` &&
      `  state.KPI = p.KPI; state.BAR = p.BAR; state.LINE = p.LINE;` &&
      `  state.ALL_ROWS = p.ROWS;` &&
      `  applyFilter(state.filterQ);` &&
      `  renderCharts();` &&
      `  if (ARK.oRefreshBtn) { ARK.oRefreshBtn.setText(state.REFRESHLABEL); }` &&
      `}` &&
      `</script>` ).

    " ===== 脚本 3：UI5 控件 + 自动测试调度 =====
    mo_html->add(
      `<script>` &&
      `function autoRun() {` &&
      `  try {` &&
      `    rpt("bridge_a", "INFO", "发送中…"); rpt("bridge_b", "INFO", "发送中…"); rpt("bridge_c", "INFO", "发送中…");` &&
      `    fireIframe("ui5_ping", { path: "iframe" });` &&
      `    armTimeout("bridge_a", function () { return ARK.stat.iframe.length > 0; }, "iframe GET");` &&
      `    fireMain("ui5_ping", { path: "main" });` &&
      `    armTimeout("bridge_b", function () { return ARK.stat.main.length > 0; }, "主框架 GET");` &&
      `    firePost("ui5_post", { kind: "post" });` &&
      `    armTimeout("bridge_c", function () { return ARK.stat.post.length > 0; }, "表单 POST");` &&
      `    cacheProbe();` &&
      `  } catch (ex) { errlog("autoRun: " + ex.message); }` &&
      `}` &&
      `function burst() {` &&
      `  ARK.burstN = 10; ARK.burstGot = 0; ARK.burstMs = [];` &&
      `  rpt("bridge_burst", "INFO", "发送 10 次…");` &&
      `  var i = 0;` &&
      `  var t = setInterval(function () {` &&
      `    i += 1;` &&
      `    fireIframe("ui5_ping", { path: "burst" });` &&
      `    if (i >= ARK.burstN) { clearInterval(t); }` &&
      `  }, 120);` &&
      `  setTimeout(function () {` &&
      `    if (ARK.burstGot < ARK.burstN) {` &&
      `      rpt("bridge_burst", "FAIL", "仅收到 " + ARK.burstGot + "/" + ARK.burstN + " 次响应");` &&
      `    }` &&
      `  }, 10000);` &&
      `}` &&
      `function cacheProbe() {` &&
      `  var url = "https://sdk.openui5.org/resources/sap-ui-version.json";` &&
      `  if (!window.fetch) { rpt("cache", "SKIP", "环境无 fetch API，跳过双取探测"); return; }` &&
      `  rpt("cache", "INFO", "双取探测中…");` &&
      `  var s1 = now();` &&
      `  fetch(url, { mode: "no-cors", cache: "force-cache" }).then(function () {` &&
      `    var d1 = Math.round(now() - s1);` &&
      `    var s2 = now();` &&
      `    fetch(url, { mode: "no-cors", cache: "force-cache" }).then(function () {` &&
      `      var d2 = Math.round(now() - s2);` &&
      `      var verdict = (d2 < 50 || d2 < d1 * 0.2) ? "PASS" : "WARN";` &&
      `      rpt("cache", verdict, "同资源二次获取 " + d1 + " ms → " + d2 + " ms" +` &&
      `        (verdict === "PASS" ? "（缓存命中）" : "（疑似未缓存，关注跨次启动耗时）"));` &&
      `    }, function () { rpt("cache", "FAIL", "第二次 fetch 网络失败"); });` &&
      `  }, function () { rpt("cache", "FAIL", "fetch 不可达：CDN 出网或协议受限"); });` &&
      `}` &&
      `function cacheResReport() {` &&
      `  if (!performance.getEntriesByType) { rpt("cache_res", "SKIP", "无 Resource Timing"); return; }` &&
      `  var es = performance.getEntriesByType("resource"), i;` &&
      `  var hit = 0, opaque = 0;` &&
      `  for (i = 0; i < es.length; i++) {` &&
      `    if (es[i].transferSize === 0 && es[i].decodedBodySize > 0) { hit += 1; }` &&
      `    else if (es[i].transferSize === 0 && es[i].decodedBodySize === 0) { opaque += 1; }` &&
      `  }` &&
      `  rpt("cache_res", "INFO", "启动资源 " + es.length + " 项：缓存命中 " + hit +` &&
      `    "、不透明(无法判定) " + opaque + "、网络可见 " + (es.length - hit - opaque));` &&
      `}` &&
      `renderText();` &&
      `renderCharts();` &&
      `if (!(window.sap && sap.ui && sap.ui.require)) {` &&
      `  rpt("ui5_render", "FAIL", "sap.ui 不可用（bootstrap 失败），仅原生分区渲染");` &&
      `} else {` &&
      `  sap.ui.require([` &&
      `    "sap/f/ShellBar", "sap/m/Toolbar", "sap/m/ToolbarSpacer", "sap/m/Button",` &&
      `    "sap/m/SearchField", "sap/m/MessageToast", "sap/m/Text"` &&
      `  ], function (ShellBar, Toolbar, ToolbarSpacer, Button, SearchField, MessageToast, Text) {` &&
      `    "use strict";` &&
      `    try {` &&
      `      new ShellBar({ title: "ARK Render Kit — 方案 B 宿主验证" }).placeAt("ui5-shellbar");` &&
      `      ARK.oRefreshBtn = new Button({` &&
      `        text: state.REFRESHLABEL, type: "Emphasized",` &&
      `        press: function () { fireIframe("ui5_refresh"); } });` &&
      `      new Toolbar({` &&
      `        design: "Solid",` &&
      `        content: [` &&
      `          ARK.oRefreshBtn,` &&
      `          new Button({ text: "Ping×10", press: function () { burst(); } }),` &&
      `          new Button({ text: "POST 桥", press: function () { firePost("ui5_post", { kind: "post" }); } }),` &&
      `          new Button({ text: "Back Home",` &&
      `            press: function () { location.href = arkPrefix() + "SAPEVENT:nav_home"; } }),` &&
      `          new ToolbarSpacer(),` &&
      `          new Text({ text: "sapevent 事件桥：刷新 / 连发 / 表单 POST / 行链接" }).addStyleClass("kpi-title"),` &&
      `          new ToolbarSpacer(),` &&
      `          new SearchField({ placeholder: "任意列包含…（本地过滤）", width: "220px",` &&
      `            search: function (oEvt) { applyFilter(oEvt.getParameter("query")); } })` &&
      `        ]` &&
      `      }).placeAt("ui5-toolbar");` &&
      `      setTimeout(function () {` &&
      `        var ok = document.getElementById("ui5-shellbar").children.length > 0 &&` &&
      `                 document.getElementById("ui5-toolbar").children.length > 0;` &&
      `        rpt("ui5_render", ok ? "PASS" : "FAIL",` &&
      `          ok ? ("ShellBar/Toolbar 已渲染 · UI5 " + sap.ui.version)` &&
      `             : "挂载点无子元素，控件未渲染");` &&
      `      }, 600);` &&
      `      rpt("boot_ms", "INFO", "控件库就绪 " + Math.round(now() - window.__arkT0) +` &&
      `        " ms（core " + ARK.bootCore + " ms）— 退出重进对比此值即可观察会话缓存");` &&
      `    } catch (ex) {` &&
      `      rpt("ui5_render", "FAIL", "UI5 构建异常: " + ex.message);` &&
      `    }` &&
      `  });` &&
      `}` &&
      `setTimeout(function () {` &&
      `  if (!window.sap || !sap.ui) { rpt("cdn_ui5", "FAIL", "15 秒后 sap.ui 仍不可用"); }` &&
      `}, 15000);` &&
      `setTimeout(cacheResReport, 2500);` &&
      `setTimeout(autoRun, 800);` &&
      `</script>` ).

    ri_html = mo_html.
  ENDMETHOD.

ENDCLASS.
