CLASS zcl_ark_ui5_shell DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! UI5 启动壳（方案 B 阶段②框架资产）：固定 HTML/JS 文档，引导 UI5
    "! 运行时、承载 sapevent 事件桥，并把 zif_ark_gui_state 的页面 state
    "! 渲染为 Fiori 界面 —— UI5 分区（ShellBar/工具栏/sap.m.Table）+
    "! 原生分区（KPI/图表=ECharts、表单）。ABAP 侧不写 HTML。
    "! 本类由 tools/gen_ui5_shell.mjs 从 demo/ui5-shell-preview.html 生成，
    "! 壳 CSS/JS/骨架改动请改预览页后重新生成，勿手改本文件标记区内容。
    CONSTANTS c_ui5_cdn TYPE string VALUE 'https://sdk.openui5.org/resources/sap-ui-core.js' .
    "! OpenUI5 官方 CDN（注意 .org 域名，.com 不可达）；离线分发
    "! （self-contained 包）见 plan §4.4，届时替换此常量注入本资产 URL
    CONSTANTS c_bridge_frame TYPE string VALUE 'ark_bridge' .
    "! 桥事件标记参数：前端 ark.state()/表单经桥 POST 时附加 __ark=1，
    "! zcl_ark_ui5_page 据此识别桥事件并回推 state（keep_view 不重渲染）
    CONSTANTS c_bridge_param TYPE string VALUE '__ark' .

    CLASS-METHODS render
      IMPORTING
        !is_state TYPE zif_ark_gui_state=>ty_page_state
      RETURNING
        VALUE(ri_html) TYPE REF TO zcl_ark_html .
ENDCLASS.

CLASS zcl_ark_ui5_shell IMPLEMENTATION.

  METHOD render.
    " 文档骨架：CSS → 挂载点 → 壳 JS + 初始 state → CDN 标签（末尾，
    " 解析不被阻塞：CDN 不可达时原生分区已在屏，UI5/ECharts 轮询降级）。
    " 键名大写/abap_bool 为 "X"/""（zcl_ark_json 的 CALL TRANSFORMATION id
    " 序列化形态），壳 JS 的 flag() 兼容处理
    DATA ro_html TYPE REF TO zcl_ark_html.
    ro_html = zcl_ark_html=>create( ).

    ro_html->add_css(
      `html, body { margin: 0; background: #f0f0f0;` &&
      `  font-family: "72", -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif; }` &&
      `.ark5-title { font-size: 22px; font-weight: 400; margin: 18px 32px 2px; color: #1d2d3e; }` &&
      `.ark5-sub { font-size: 13px; color: #6a6d70; margin: 0 32px 14px; }` &&
      `.ark5-toolbar-wrap { padding: 0 32px; }` &&
      `.ark5-card { background: #fff; border: 1px solid #e5e5e5; border-radius: 12px;` &&
      `  padding: 14px 18px; margin: 0 32px 16px; }` &&
      `.ark5-card-title { font-size: 15px; font-weight: 700; color: #1d2d3e; margin: 0 0 8px; }` &&
      `.ark5-kpi-grid { display: grid;` &&
      `  grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 16px; }` &&
      `.ark5-kpi-title { font-size: 13px; color: #6a6d70; }` &&
      `.ark5-kpi-value { font-size: 28px; color: #1d2d3e; margin: 4px 0 2px; }` &&
      `.ark5-kpi-delta { font-size: 13px; }` &&
      `.ark5-spark { width: 100%; height: 34px; margin-top: 6px; }` &&
      `.ark5-chart { width: 100%; height: 300px; }` &&
      `.ark5-tbl { width: 100%; }` &&
      `.ark5-form-row { display: flex; align-items: center; margin: 8px 0; }` &&
      `.ark5-form-label { width: 140px; font-size: 13px; color: #6a6d70; flex: none; }` &&
      `.ark5-form-row input[type=text], .ark5-form-row input[type=number],` &&
      `.ark5-form-row input[type=date], .ark5-form-row select, .ark5-form-row textarea {` &&
      `  flex: 1; max-width: 420px; padding: 6px 10px; font-size: 13px;` &&
      `  border: 1px solid #8f8f8f; border-radius: 4px; background: #fff; }` &&
      `.ark5-form-btn { font-size: 13px; padding: 6px 16px; margin-top: 8px;` &&
      `  border: 1px solid #0070f2; color: #0070f2; background: #fff;` &&
      `  border-radius: 4px; cursor: pointer; }` &&
      `.ark5-form-btn:hover { background: #f0f7ff; }` &&
      `#errlog { font: 12px monospace; color: #b00; padding: 8px 32px; white-space: pre-wrap; }`
      ).

    ro_html->add(
      `<a id="ark_probe" href="sapevent:x" style="display:none"></a>` &&
      `<div id="ark5_shellbar"></div>` &&
      `<div id="ark5_toolbar" class="ark5-toolbar-wrap"></div>` &&
      `<h1 class="ark5-title" id="ark5_title"></h1>` &&
      `<p class="ark5-sub" id="ark5_sub"></p>` &&
      `<div id="ark5_sections"></div>` &&
      `<iframe id="ark_bridge" name="ark_bridge" style="display:none;width:0;height:0;border:0;"></iframe>` &&
      `<div id="errlog"></div>`
      ).

    " ===== 壳 JS（桥 + 渲染器，与 demo 预览逐字一致）=====
    " 逐行 APPEND 后以真实换行拼接：&& 连接不产生换行，单行化会让
    " JS 行注释 // 吞掉其后全部代码（宿主白屏事故已踩）
    DATA lt_js TYPE string_table.
    DATA lv_js TYPE string.
      APPEND `<script>` TO lt_js.
      APPEND `(function () {` TO lt_js.
      APPEND `  "use strict";` TO lt_js.
      APPEND `  window.onerror = function (m, src, l) {` TO lt_js.
      APPEND `    var el = document.getElementById("errlog");` TO lt_js.
      APPEND `    if (el) { el.textContent += "JS ERROR: " + m + " @" + (src || "") + ":" + l + "\n"; }` TO lt_js.
      APPEND `    return false;` TO lt_js.
      APPEND `  };` TO lt_js.
      APPEND `  function errlog(msg) {` TO lt_js.
      APPEND `    var el = document.getElementById("errlog");` TO lt_js.
      APPEND `    if (el) { el.textContent += msg + "\n"; }` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  var ARK5 = { state: null, charts: [], ui5Ready: false, ui5Tried: false, mods: null, ctl: {} };` TO lt_js.
      APPEND `  // zcl_ark_json 键名大写、abap_bool 序列化为 "X"/""（flag 兼容 true/1）` TO lt_js.
      APPEND `  function flag(v) { return v === true || v === "X" || v === 1 || v === "true"; }` TO lt_js.
      APPEND `  function esc(s) {` TO lt_js.
      APPEND `    return String(s === null || s === undefined ? "" : s)` TO lt_js.
      APPEND `      .replace(/&/g, "&amp;").replace(/</g, "&lt;")` TO lt_js.
      APPEND `      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  var SEMA = {` TO lt_js.
      APPEND `    positive:    { color: "#107e3e", state: "Success" },` TO lt_js.
      APPEND `    negative:    { color: "#bb0000", state: "Error" },` TO lt_js.
      APPEND `    critical:    { color: "#e9730c", state: "Warning" },` TO lt_js.
      APPEND `    informative: { color: "#0a6ed1", state: "Information" },` TO lt_js.
      APPEND `    neutral:     { color: "#6a6d70", state: "None" }` TO lt_js.
      APPEND `  };` TO lt_js.
      APPEND `  function sema(name) { return SEMA[name] || { color: "#0070f2", state: "None" }; }` TO lt_js.
      APPEND `  function toast(msg) {` TO lt_js.
      APPEND `    if (ARK5.mods && ARK5.mods.MessageToast) { ARK5.mods.MessageToast.show(msg); }` TO lt_js.
      APPEND `    else { errlog("TOAST: " + msg); }` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // ---- sapevent 桥（与宿主验证页同一套已验证机制）----` TO lt_js.
      APPEND `  function arkPrefix() {` TO lt_js.
      APPEND `    var a = document.getElementById("ark_probe");` TO lt_js.
      APPEND `    var base = String(location.href);` TO lt_js.
      APPEND `    var tries = [];` TO lt_js.
      APPEND `    if (a) {` TO lt_js.
      APPEND `      tries.push(String(a.href || ""));` TO lt_js.
      APPEND `      tries.push(String(a.getAttribute("href") || ""));` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    tries.push(base);` TO lt_js.
      APPEND `    var n, h, i, head;` TO lt_js.
      APPEND `    for (n = 0; n < tries.length; n++) {` TO lt_js.
      APPEND `      i = tries[n].toLowerCase().indexOf("sapevent:");` TO lt_js.
      APPEND `      if (i > 0) {` TO lt_js.
      APPEND `        head = tries[n].substring(0, i);` TO lt_js.
      APPEND `        if (head.charAt(head.length - 1) === "/") { return head; }` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    if (/^saphtmlp:/i.test(base) || /^sap-cust:/i.test(base)) {` TO lt_js.
      APPEND `      return "sap-cust://sap-place-holder/";` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    if (/^file:/i.test(base)) { return "file:///"; }` TO lt_js.
      APPEND `    return "";` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function arkUrl(action, params) {` TO lt_js.
      APPEND `    var u = arkPrefix() + "SAPEVENT:" + action, k, qs = [];` TO lt_js.
      APPEND `    params = params || {};` TO lt_js.
      APPEND `    for (k in params) {` TO lt_js.
      APPEND `      if (params.hasOwnProperty(k)) { qs.push(k + "=" + encodeURIComponent(params[k])); }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    return qs.length ? u + "?" + qs.join("&") : u;` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function parseParams(s) {` TO lt_js.
      APPEND `    var out = {}, pairs, i, kv;` TO lt_js.
      APPEND `    if (!s) { return out; }` TO lt_js.
      APPEND `    pairs = String(s).split("&");` TO lt_js.
      APPEND `    for (i = 0; i < pairs.length; i++) {` TO lt_js.
      APPEND `      kv = pairs[i].split("=");` TO lt_js.
      APPEND `      if (kv.length >= 1 && kv[0]) {` TO lt_js.
      APPEND `        out[kv[0]] = decodeURIComponent(kv.slice(1).join("=") || "");` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    return out;` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // 宿主实证（6a7404c）：iframe location.href 触发帧导航会被拦截（白屏` TO lt_js.
      APPEND `  // 元凶），sapevent 触发一律走锚点 click —— 桥帧内建隐藏锚点点击 /` TO lt_js.
      APPEND `  // 主框架文档内建隐藏锚点点击（已验证拦截路径）` TO lt_js.
      APPEND `  function arkFire(url) {` TO lt_js.
      APPEND `    var fdoc = window.frames["ark_bridge"].document;` TO lt_js.
      APPEND `    var a = fdoc.getElementById("ark_fire_a");` TO lt_js.
      APPEND `    if (!a) { a = fdoc.createElement("a"); a.id = "ark_fire_a"; fdoc.body.appendChild(a); }` TO lt_js.
      APPEND `    a.setAttribute("href", url);` TO lt_js.
      APPEND `    a.click();` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function arkFireMain(url) {` TO lt_js.
      APPEND `    var a = document.getElementById("ark_main_anchor");` TO lt_js.
      APPEND `    if (!a) {` TO lt_js.
      APPEND `      a = document.createElement("a");` TO lt_js.
      APPEND `      a.id = "ark_main_anchor";` TO lt_js.
      APPEND `      a.style.display = "none";` TO lt_js.
      APPEND `      document.body.appendChild(a);` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    a.setAttribute("href", url);` TO lt_js.
      APPEND `    a.click();` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  window.ark = {` TO lt_js.
      APPEND `    // 桥事件（隐藏 iframe 经锚点点击）：ABAP 侧回推新 state，主页面常驻不重载` TO lt_js.
      APPEND `    state: function (action, params) {` TO lt_js.
      APPEND `      var p = {}, k;` TO lt_js.
      APPEND `      for (k in (params || {})) { p[k] = params[k]; }` TO lt_js.
      APPEND `      p.__ark = "1";` TO lt_js.
      APPEND `      arkFire(arkUrl(action, p));` TO lt_js.
      APPEND `    },` TO lt_js.
      APPEND `    // 主框架导航：页面跳转（整页重渲染），同样走锚点点击` TO lt_js.
      APPEND `    nav: function (action, params) {` TO lt_js.
      APPEND `      arkFireMain(arkUrl(action, params));` TO lt_js.
      APPEND `    },` TO lt_js.
      APPEND `    // 表单经桥 POST：target=ark_bridge，响应同样 postMessage 回来` TO lt_js.
      APPEND `    formGo: function (f, action) {` TO lt_js.
      APPEND `      f.action = arkUrl(action, { __ark: "1" });` TO lt_js.
      APPEND `      return true;` TO lt_js.
      APPEND `    },` TO lt_js.
      APPEND `    // 桥响应入口：隐藏帧脚本 parent.postMessage({__ark_state:1,payload:...})` TO lt_js.
      APPEND `    receive: function (payload) {` TO lt_js.
      APPEND `      ARK5.state = payload || {};` TO lt_js.
      APPEND `      renderAll();` TO lt_js.
      APPEND `    },` TO lt_js.
      APPEND `    // 调试/测试辅助：当前渲染 state 的深拷贝` TO lt_js.
      APPEND `    snapshot: function () { return JSON.parse(JSON.stringify(ARK5.state || {})); }` TO lt_js.
      APPEND `  };` TO lt_js.
      APPEND `  window.addEventListener("message", function (ev) {` TO lt_js.
      APPEND `    var d = ev.data;` TO lt_js.
      APPEND `    if (!d || d.__ark_state !== 1) { return; }` TO lt_js.
      APPEND `    window.ark.receive(d.payload || {});` TO lt_js.
      APPEND `  });` TO lt_js.
      APPEND `  // ---- 文本分区（标题/副标题）----` TO lt_js.
      APPEND `  function renderText() {` TO lt_js.
      APPEND `    var st = ARK5.state || {};` TO lt_js.
      APPEND `    document.getElementById("ark5_title").textContent = st.TITLE || "";` TO lt_js.
      APPEND `    document.getElementById("ark5_sub").textContent = st.SUBTITLE || "";` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // ---- 原生分区重建：KPI / 图表容器 / 表单 / 各节挂载点 ----` TO lt_js.
      APPEND `  function renderSections() {` TO lt_js.
      APPEND `    var host = document.getElementById("ark5_sections");` TO lt_js.
      APPEND `    var i;` TO lt_js.
      APPEND `    for (i = 0; i < ARK5.charts.length; i++) {` TO lt_js.
      APPEND `      try { ARK5.charts[i].dispose(); } catch (e) { }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    ARK5.charts = [];` TO lt_js.
      APPEND `    destroySectionUi5();` TO lt_js.
      APPEND `    host.innerHTML = "";` TO lt_js.
      APPEND `    var st = ARK5.state || {};` TO lt_js.
      APPEND `    (st.SECTIONS || []).forEach(function (sec, si) {` TO lt_js.
      APPEND `      var card = document.createElement("div");` TO lt_js.
      APPEND `      card.className = "ark5-card";` TO lt_js.
      APPEND `      if (sec.TITLE) {` TO lt_js.
      APPEND `        var h = document.createElement("div");` TO lt_js.
      APPEND `        h.className = "ark5-card-title";` TO lt_js.
      APPEND `        h.textContent = sec.TITLE;` TO lt_js.
      APPEND `        card.appendChild(h);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      if ((sec.TOOLBAR || []).length) {` TO lt_js.
      APPEND `        var tb = document.createElement("div");` TO lt_js.
      APPEND `        tb.id = "ark5_tb_" + si;` TO lt_js.
      APPEND `        card.appendChild(tb);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      if (sec.KIND === "kpi_grid") { buildKpi(card, sec, si); }` TO lt_js.
      APPEND `      else if (sec.KIND === "table") {` TO lt_js.
      APPEND `        var tbl = document.createElement("div");` TO lt_js.
      APPEND `        tbl.id = "ark5_tbl_" + si;` TO lt_js.
      APPEND `        card.appendChild(tbl);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      else if (sec.KIND === "chart") {` TO lt_js.
      APPEND `        var ch = document.createElement("div");` TO lt_js.
      APPEND `        ch.id = "ark5_ch_" + si;` TO lt_js.
      APPEND `        ch.className = "ark5-chart";` TO lt_js.
      APPEND `        card.appendChild(ch);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      else if (sec.KIND === "form") { buildForm(card, sec); }` TO lt_js.
      APPEND `      host.appendChild(card);` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function buildKpi(card, sec, si) {` TO lt_js.
      APPEND `    var grid = document.createElement("div");` TO lt_js.
      APPEND `    grid.className = "ark5-kpi-grid";` TO lt_js.
      APPEND `    (sec.KPI_CARDS || []).forEach(function (k, ki) {` TO lt_js.
      APPEND `      var d = document.createElement("div");` TO lt_js.
      APPEND `      var t = document.createElement("div");` TO lt_js.
      APPEND `      t.className = "ark5-kpi-title";` TO lt_js.
      APPEND `      t.textContent = k.TITLE || "";` TO lt_js.
      APPEND `      d.appendChild(t);` TO lt_js.
      APPEND `      var v = document.createElement("div");` TO lt_js.
      APPEND `      v.className = "ark5-kpi-value";` TO lt_js.
      APPEND `      v.textContent = k.VALUE || "";` TO lt_js.
      APPEND `      d.appendChild(v);` TO lt_js.
      APPEND `      if (k.DELTA_TEXT) {` TO lt_js.
      APPEND `        var dl = document.createElement("span");` TO lt_js.
      APPEND `        dl.className = "ark5-kpi-delta";` TO lt_js.
      APPEND `        dl.style.color = sema(k.DELTA_SEMANTIC).color;` TO lt_js.
      APPEND `        dl.textContent = k.DELTA_TEXT;` TO lt_js.
      APPEND `        d.appendChild(dl);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      if ((k.SPARKLINE || []).length) {` TO lt_js.
      APPEND `        var sp = document.createElement("div");` TO lt_js.
      APPEND `        sp.id = "ark5_sp_" + si + "_" + ki;` TO lt_js.
      APPEND `        sp.className = "ark5-spark";` TO lt_js.
      APPEND `        d.appendChild(sp);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      grid.appendChild(d);` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `    card.appendChild(grid);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function buildForm(card, sec) {` TO lt_js.
      APPEND `    var f = document.createElement("form");` TO lt_js.
      APPEND `    f.method = "post";` TO lt_js.
      APPEND `    f.target = "ark_bridge";` TO lt_js.
      APPEND `    if (sec.FORM_ACTION) {` TO lt_js.
      APPEND `      f.onsubmit = function () { return window.ark.formGo(this, sec.FORM_ACTION); };` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    var hid = document.createElement("input");` TO lt_js.
      APPEND `    hid.type = "hidden";` TO lt_js.
      APPEND `    hid.name = "__ark";` TO lt_js.
      APPEND `    hid.value = "1";` TO lt_js.
      APPEND `    f.appendChild(hid);` TO lt_js.
      APPEND `    (sec.FORM_FIELDS || []).forEach(function (fd) {` TO lt_js.
      APPEND `      if (fd.INPUT_TYPE === "hidden") {` TO lt_js.
      APPEND `        var hi = document.createElement("input");` TO lt_js.
      APPEND `        hi.type = "hidden";` TO lt_js.
      APPEND `        hi.name = fd.NAME || "";` TO lt_js.
      APPEND `        hi.value = fd.VALUE || "";` TO lt_js.
      APPEND `        f.appendChild(hi);` TO lt_js.
      APPEND `        return;` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      var row = document.createElement("div");` TO lt_js.
      APPEND `      row.className = "ark5-form-row";` TO lt_js.
      APPEND `      if (fd.INPUT_TYPE !== "submit") {` TO lt_js.
      APPEND `        var lb = document.createElement("span");` TO lt_js.
      APPEND `        lb.className = "ark5-form-label";` TO lt_js.
      APPEND `        lb.textContent = fd.LABEL || "";` TO lt_js.
      APPEND `        row.appendChild(lb);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      var el;` TO lt_js.
      APPEND `      if (fd.INPUT_TYPE === "select") {` TO lt_js.
      APPEND `        el = document.createElement("select");` TO lt_js.
      APPEND `        (fd.OPTIONS || []).forEach(function (op) {` TO lt_js.
      APPEND `          var o = document.createElement("option");` TO lt_js.
      APPEND `          o.textContent = op;` TO lt_js.
      APPEND `          if (op === fd.VALUE) { o.selected = true; }` TO lt_js.
      APPEND `          el.appendChild(o);` TO lt_js.
      APPEND `        });` TO lt_js.
      APPEND `      } else if (fd.INPUT_TYPE === "textarea") {` TO lt_js.
      APPEND `        el = document.createElement("textarea");` TO lt_js.
      APPEND `        el.rows = 4;` TO lt_js.
      APPEND `        el.value = fd.VALUE || "";` TO lt_js.
      APPEND `      } else if (fd.INPUT_TYPE === "checkbox") {` TO lt_js.
      APPEND `        el = document.createElement("input");` TO lt_js.
      APPEND `        el.type = "checkbox";` TO lt_js.
      APPEND `        el.checked = flag(fd.VALUE);` TO lt_js.
      APPEND `      } else if (fd.INPUT_TYPE === "submit") {` TO lt_js.
      APPEND `        el = document.createElement("button");` TO lt_js.
      APPEND `        el.type = "submit";` TO lt_js.
      APPEND `        el.className = "ark5-form-btn";` TO lt_js.
      APPEND `        el.textContent = fd.VALUE || fd.LABEL || "提交";` TO lt_js.
      APPEND `      } else {` TO lt_js.
      APPEND `        el = document.createElement("input");` TO lt_js.
      APPEND `        el.type = fd.INPUT_TYPE || "text";` TO lt_js.
      APPEND `        el.value = fd.VALUE || "";` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      if (fd.NAME) { el.name = fd.NAME; }` TO lt_js.
      APPEND `      row.appendChild(el);` TO lt_js.
      APPEND `      f.appendChild(row);` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `    card.appendChild(f);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // ---- ECharts 分区（sparkline + chart 节）----` TO lt_js.
      APPEND `  function chartOf(id) {` TO lt_js.
      APPEND `    var el = document.getElementById(id);` TO lt_js.
      APPEND `    if (!el || !window.echarts) { return null; }` TO lt_js.
      APPEND `    return echarts.getInstanceByDom(el) || echarts.init(el);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function renderCharts() {` TO lt_js.
      APPEND `    if (!window.echarts) { return; }` TO lt_js.
      APPEND `    var st = ARK5.state || {};` TO lt_js.
      APPEND `    (st.SECTIONS || []).forEach(function (sec, si) {` TO lt_js.
      APPEND `      if (sec.KIND === "kpi_grid") {` TO lt_js.
      APPEND `        (sec.KPI_CARDS || []).forEach(function (k, ki) {` TO lt_js.
      APPEND `          var ch = chartOf("ark5_sp_" + si + "_" + ki);` TO lt_js.
      APPEND `          if (!ch) { return; }` TO lt_js.
      APPEND `          ARK5.charts.push(ch);` TO lt_js.
      APPEND `          ch.setOption({` TO lt_js.
      APPEND `            grid: { left: 0, right: 0, top: 2, bottom: 2 },` TO lt_js.
      APPEND `            xAxis: { type: "category", show: false },` TO lt_js.
      APPEND `            yAxis: { type: "value", show: false },` TO lt_js.
      APPEND `            series: [{ type: "line", data: (k.SPARKLINE || []).map(Number),` TO lt_js.
      APPEND `              symbol: "none", smooth: true,` TO lt_js.
      APPEND `              lineStyle: { width: 2, color: sema(k.DELTA_SEMANTIC).color },` TO lt_js.
      APPEND `              areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1,` TO lt_js.
      APPEND `                colorStops: [` TO lt_js.
      APPEND `                  { offset: 0, color: sema(k.DELTA_SEMANTIC).color + "40" },` TO lt_js.
      APPEND `                  { offset: 1, color: sema(k.DELTA_SEMANTIC).color + "00" } ] } } }]` TO lt_js.
      APPEND `          });` TO lt_js.
      APPEND `        });` TO lt_js.
      APPEND `      } else if (sec.KIND === "chart") {` TO lt_js.
      APPEND `        var ch2 = chartOf("ark5_ch_" + si);` TO lt_js.
      APPEND `        if (!ch2) { return; }` TO lt_js.
      APPEND `        ARK5.charts.push(ch2);` TO lt_js.
      APPEND `        if (sec.CHART_MAP && window.ARK_MAPS && window.ARK_MAPS[sec.CHART_MAP]) {` TO lt_js.
      APPEND `          echarts.registerMap(sec.CHART_MAP, window.ARK_MAPS[sec.CHART_MAP]);` TO lt_js.
      APPEND `        }` TO lt_js.
      APPEND `        var opt = {};` TO lt_js.
      APPEND `        try { opt = JSON.parse(sec.CHART_OPTION || "{}"); } catch (e) {` TO lt_js.
      APPEND `          errlog("chart_option JSON 解析失败: " + e.message);` TO lt_js.
      APPEND `        }` TO lt_js.
      APPEND `        ch2.setOption(opt, true);` TO lt_js.
      APPEND `        if (sec.CHART_CLICK_ACTION) {` TO lt_js.
      APPEND `          ch2.off("click");` TO lt_js.
      APPEND `          ch2.on("click", (function (act, sIdx) {` TO lt_js.
      APPEND `            return function (p) {` TO lt_js.
      APPEND `              var v = p.value;` TO lt_js.
      APPEND `              if (v && typeof v === "object") { v = JSON.stringify(v); }` TO lt_js.
      APPEND `              ark.state(act, {` TO lt_js.
      APPEND `                name: p.name || "", series: p.seriesName || "",` TO lt_js.
      APPEND `                value: v === undefined ? "" : String(v),` TO lt_js.
      APPEND `                idx: p.dataIndex === undefined ? -1 : p.dataIndex,` TO lt_js.
      APPEND `                chart: sIdx` TO lt_js.
      APPEND `              });` TO lt_js.
      APPEND `            };` TO lt_js.
      APPEND `          })(sec.CHART_CLICK_ACTION, si + 1));` TO lt_js.
      APPEND `        }` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // ---- UI5 分区（ShellBar / 工具栏 / sap.m.Table）----` TO lt_js.
      APPEND `  function destroySectionUi5() {` TO lt_js.
      APPEND `    var k;` TO lt_js.
      APPEND `    for (k in ARK5.ctl) {` TO lt_js.
      APPEND `      if (k.indexOf("s_") === 0 || k === "tb") {` TO lt_js.
      APPEND `        try { ARK5.ctl[k].destroy(); } catch (e) { }` TO lt_js.
      APPEND `        delete ARK5.ctl[k];` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function buildToolbarItems(tb, items) {` TO lt_js.
      APPEND `    (items || []).forEach(function (it) {` TO lt_js.
      APPEND `      var params = parseParams(it.PARAMETERS);` TO lt_js.
      APPEND `      if (it.KIND === "button" || it.KIND === "link") {` TO lt_js.
      APPEND `        // link 与 A 路线 render_toolbar 一致：恒可点（enabled 仅约束 button）` TO lt_js.
      APPEND `        tb.addContent(new ARK5.mods.Button({` TO lt_js.
      APPEND `          text: it.LABEL || "",` TO lt_js.
      APPEND `          type: (it.KIND === "button" && flag(it.EMPHASIZED)) ? "Emphasized" : "Transparent",` TO lt_js.
      APPEND `          enabled: it.KIND === "link" ? true : flag(it.ENABLED),` TO lt_js.
      APPEND `          press: (function (a, p, kind) {` TO lt_js.
      APPEND `            return function () {` TO lt_js.
      APPEND `              if (kind === "link") { ark.nav(a, p); } else { ark.state(a, p); }` TO lt_js.
      APPEND `            };` TO lt_js.
      APPEND `          })(it.ACTION, params, it.KIND)` TO lt_js.
      APPEND `        }));` TO lt_js.
      APPEND `      } else if (it.KIND === "text") {` TO lt_js.
      APPEND `        tb.addContent(new ARK5.mods.Text({ text: it.LABEL || "" }));` TO lt_js.
      APPEND `      } else if (it.KIND === "separator") {` TO lt_js.
      APPEND `        // sap.m.Toolbar 无竖线分隔控件，以弹性空档近似（v1 取舍）` TO lt_js.
      APPEND `        tb.addContent(new ARK5.mods.ToolbarSpacer());` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function buildTableInto(el, sec, si) {` TO lt_js.
      APPEND `    var key = "s_" + si;` TO lt_js.
      APPEND `    if (ARK5.ctl[key]) {` TO lt_js.
      APPEND `      try { ARK5.ctl[key].destroy(); } catch (e) { }` TO lt_js.
      APPEND `      delete ARK5.ctl[key];` TO lt_js.
      APPEND `      if (el.firstChild) { el.innerHTML = ""; }` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    var cols = [];` TO lt_js.
      APPEND `    (sec.COLUMNS || []).forEach(function (c) {` TO lt_js.
      APPEND `      cols.push(new ARK5.mods.Column({` TO lt_js.
      APPEND `        hAlign: flag(c.ALIGN_RIGHT) ? "End" : "Begin",` TO lt_js.
      APPEND `        demandPopin: true, minScreenWidth: "Tablet",` TO lt_js.
      APPEND `        header: new ARK5.mods.Label({ text: c.LABEL || "" })` TO lt_js.
      APPEND `      }));` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `    var items = [];` TO lt_js.
      APPEND `    (sec.ROWS || []).forEach(function (r, ri) {` TO lt_js.
      APPEND `      var cells = [];` TO lt_js.
      APPEND `      (r.CELLS || []).forEach(function (cell) {` TO lt_js.
      APPEND `        if (cell.SEMANTIC) {` TO lt_js.
      APPEND `          cells.push(new ARK5.mods.ObjectStatus({` TO lt_js.
      APPEND `            text: cell.VALUE || "", state: sema(cell.SEMANTIC).state }));` TO lt_js.
      APPEND `        } else if (cell.ACTION) {` TO lt_js.
      APPEND `          cells.push(new ARK5.mods.Link({` TO lt_js.
      APPEND `            text: cell.VALUE || "",` TO lt_js.
      APPEND `            press: (function (a, rn) {` TO lt_js.
      APPEND `              return function () { ark.state(a, { __row: rn }); };` TO lt_js.
      APPEND `            })(cell.ACTION, ri + 1)` TO lt_js.
      APPEND `          }));` TO lt_js.
      APPEND `        } else {` TO lt_js.
      APPEND `          cells.push(new ARK5.mods.Text({ text: cell.VALUE || "" }));` TO lt_js.
      APPEND `        }` TO lt_js.
      APPEND `      });` TO lt_js.
      APPEND `      items.push(new ARK5.mods.ColumnListItem({ cells: cells }));` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `    var t = new ARK5.mods.Table({` TO lt_js.
      APPEND `      columns: cols, items: items,` TO lt_js.
      APPEND `      growing: true, growingThreshold: 100` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `    t.addStyleClass("ark5-tbl");` TO lt_js.
      APPEND `    ARK5.ctl[key] = t;` TO lt_js.
      APPEND `    t.placeAt(el);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function buildUi5() {` TO lt_js.
      APPEND `    if (!ARK5.ui5Ready || !ARK5.state) { return; }` TO lt_js.
      APPEND `    var st = ARK5.state;` TO lt_js.
      APPEND `    if (!ARK5.ctl.shell) {` TO lt_js.
      APPEND `      ARK5.ctl.shell = new ARK5.mods.ShellBar({ showNavButton: false });` TO lt_js.
      APPEND `      ARK5.ctl.shell.placeAt("ark5_shellbar");` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    ARK5.ctl.shell.setTitle(st.TITLE || "");` TO lt_js.
      APPEND `    // 页面工具栏独占挂载点：无条件清掉旧控件遗留（UI5 destroy 在渲染` TO lt_js.
      APPEND `    // 队列延迟下会留下改名死节点 sap-ui-destroyed-*；真实宿主页面前台` TO lt_js.
      APPEND `    // 常驻，此防御主要覆盖后台标签页 rAF 节流与异常时序）` TO lt_js.
      APPEND `    var tbMount = document.getElementById("ark5_toolbar");` TO lt_js.
      APPEND `    if (tbMount && tbMount.firstChild) { tbMount.innerHTML = ""; }` TO lt_js.
      APPEND `    if (ARK5.ctl.tb) {` TO lt_js.
      APPEND `      try { ARK5.ctl.tb.destroy(); } catch (e) { }` TO lt_js.
      APPEND `      ARK5.ctl.tb = null;` TO lt_js.
      APPEND `    }` TO lt_js.
      APPEND `    var tb = new ARK5.mods.Toolbar({ design: "Solid" });` TO lt_js.
      APPEND `    buildToolbarItems(tb, st.TOOLBAR);` TO lt_js.
      APPEND `    ARK5.ctl.tb = tb;` TO lt_js.
      APPEND `    tb.placeAt("ark5_toolbar");` TO lt_js.
      APPEND `    (st.SECTIONS || []).forEach(function (sec, si) {` TO lt_js.
      APPEND `      var tbEl = document.getElementById("ark5_tb_" + si);` TO lt_js.
      APPEND `      if (tbEl && (sec.TOOLBAR || []).length) {` TO lt_js.
      APPEND `        var stb = new ARK5.mods.Toolbar({ design: "Solid" });` TO lt_js.
      APPEND `        buildToolbarItems(stb, sec.TOOLBAR);` TO lt_js.
      APPEND `        ARK5.ctl["s_tb" + si] = stb;` TO lt_js.
      APPEND `        stb.placeAt(tbEl);` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `      var tblEl = document.getElementById("ark5_tbl_" + si);` TO lt_js.
      APPEND `      if (tblEl && sec.KIND === "table") { buildTableInto(tblEl, sec, si); }` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function renderAll() {` TO lt_js.
      APPEND `    renderText();` TO lt_js.
      APPEND `    renderSections();` TO lt_js.
      APPEND `    renderCharts();` TO lt_js.
      APPEND `    buildUi5();` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  // ---- 启动：原生分区立即渲染；UI5/ECharts 标签在文档末尾，` TO lt_js.
      APPEND `  // 就绪靠轮询 —— CDN 不可达只降级（表格/工具栏/图表缺席 + errlog），` TO lt_js.
      APPEND `  // 不阻塞解析、不白屏 ----` TO lt_js.
      APPEND `  function startUi5() {` TO lt_js.
      APPEND `    if (ARK5.ui5Tried) { return; }` TO lt_js.
      APPEND `    ARK5.ui5Tried = true;` TO lt_js.
      APPEND `    sap.ui.require([` TO lt_js.
      APPEND `      "sap/f/ShellBar", "sap/m/Toolbar", "sap/m/ToolbarSpacer", "sap/m/Button",` TO lt_js.
      APPEND `      "sap/m/Text", "sap/m/Table", "sap/m/Column", "sap/m/Label",` TO lt_js.
      APPEND `      "sap/m/ColumnListItem", "sap/m/ObjectStatus", "sap/m/Link",` TO lt_js.
      APPEND `      "sap/m/MessageToast"` TO lt_js.
      APPEND `    ], function (ShellBar, Toolbar, ToolbarSpacer, Button, Text, Table,` TO lt_js.
      APPEND `                 Column, Label, ColumnListItem, ObjectStatus, Link, MessageToast) {` TO lt_js.
      APPEND `      ARK5.mods = { ShellBar: ShellBar, Toolbar: Toolbar, ToolbarSpacer: ToolbarSpacer,` TO lt_js.
      APPEND `        Button: Button, Text: Text, Table: Table, Column: Column, Label: Label,` TO lt_js.
      APPEND `        ColumnListItem: ColumnListItem, ObjectStatus: ObjectStatus, Link: Link,` TO lt_js.
      APPEND `        MessageToast: MessageToast };` TO lt_js.
      APPEND `      ARK5.ui5Ready = true;` TO lt_js.
      APPEND `      buildUi5();` TO lt_js.
      APPEND `    }, function (e) {` TO lt_js.
      APPEND `      errlog("sap.ui.require 失败: " + (e && e.message || e));` TO lt_js.
      APPEND `    });` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function pollUi5() {` TO lt_js.
      APPEND `    if (window.sap && sap.ui && sap.ui.require) { startUi5(); return; }` TO lt_js.
      APPEND `    var tries = 0;` TO lt_js.
      APPEND `    var t = setInterval(function () {` TO lt_js.
      APPEND `      tries += 1;` TO lt_js.
      APPEND `      if (window.sap && sap.ui && sap.ui.require) {` TO lt_js.
      APPEND `        clearInterval(t);` TO lt_js.
      APPEND `        startUi5();` TO lt_js.
      APPEND `      } else if (tries >= 300) {` TO lt_js.
      APPEND `        clearInterval(t);` TO lt_js.
      APPEND `        errlog("UI5 运行时 60 秒未就绪（CDN 不可达？）— 仅原生分区渲染，表格/工具栏缺席");` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    }, 200);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  function watchEcharts() {` TO lt_js.
      APPEND `    if (window.echarts) { renderCharts(); return; }` TO lt_js.
      APPEND `    var tries = 0;` TO lt_js.
      APPEND `    var t = setInterval(function () {` TO lt_js.
      APPEND `      tries += 1;` TO lt_js.
      APPEND `      if (window.echarts) { clearInterval(t); renderCharts(); }` TO lt_js.
      APPEND `      else if (tries >= 300) {` TO lt_js.
      APPEND `        clearInterval(t);` TO lt_js.
      APPEND `        errlog("ECharts 60 秒未加载（CDN/MIME 不可达？）— 图表分区缺席");` TO lt_js.
      APPEND `      }` TO lt_js.
      APPEND `    }, 200);` TO lt_js.
      APPEND `  }` TO lt_js.
      APPEND `  window.__arkShellBoot = function (initialState) {` TO lt_js.
      APPEND `    ARK5.state = initialState || {};` TO lt_js.
      APPEND `    renderAll();` TO lt_js.
      APPEND `    watchEcharts();` TO lt_js.
      APPEND `    pollUi5();` TO lt_js.
      APPEND `  };` TO lt_js.
      APPEND `  window.ark.isUi5Ready = function () { return !!ARK5.ui5Ready; };` TO lt_js.
      APPEND `})();` TO lt_js.
      APPEND `</script>` TO lt_js.
    CONCATENATE LINES OF lt_js INTO lv_js
      SEPARATED BY cl_abap_char_utilities=>newline.
    ro_html->add( lv_js ).

    " ===== 初始 state 启动（值含 </ 会截断脚本块，按 JSON 转义规则替换）=====
    DATA(lv_json) = zcl_ark_json=>to_json( is_state ).
    lv_json = replace( val = lv_json sub = `</` with = `<\/` occ = 0 ).
    ro_html->add(
      `<script>window.__arkShellBoot( ` && lv_json && ` );</script>` ).

    " ===== UI5 bootstrap（文档末尾；async=true，库文件异步加载）=====
    ro_html->add(
      `<script id="sap-ui-bootstrap"` &&
      `        src="` && c_ui5_cdn && `"` &&
      `        data-sap-ui-theme="sap_horizon"` &&
      `        data-sap-ui-libs="sap.m,sap.f"` &&
      `        data-sap-ui-compatVersion="edge"` &&
      `        data-sap-ui-async="true"></script>` ).

    " ECharts：chart 节或 KPI sparkline 存在时注入一次（MIME/缓存/CDN 资产链）
    DATA lv_need_echarts TYPE abap_bool.
    LOOP AT is_state-sections INTO DATA(ls_lib_check).
      IF ls_lib_check-kind = zif_ark_gui_state=>c_section_kind-chart.
        lv_need_echarts = abap_true.
        EXIT.
      ENDIF.
      IF ls_lib_check-kind = zif_ark_gui_state=>c_section_kind-kpi_grid.
        LOOP AT ls_lib_check-kpi_cards INTO DATA(ls_card_check).
          IF ls_card_check-sparkline IS NOT INITIAL.
            lv_need_echarts = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_need_echarts = abap_true.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF lv_need_echarts = abap_true.
      ro_html->add( zcl_ark_echarts=>include_library_script( ) ).
    ENDIF.

    " 地图资产：chart 节声明 chart_map 时注入（同名整页一次）；
    " 资产缺失返回空串，渲染端 registerMap 守卫兜底（与 A 路线同构）
    DATA lt_maps TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT is_state-sections INTO DATA(ls_map_check)
         WHERE kind = zif_ark_gui_state=>c_section_kind-chart.
      IF ls_map_check-chart_map IS NOT INITIAL.
        INSERT ls_map_check-chart_map INTO TABLE lt_maps.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_maps INTO DATA(lv_map_name).
      DATA(lv_map_html) = zcl_ark_echarts=>include_map_script( lv_map_name ).
      IF lv_map_html IS NOT INITIAL.
        ro_html->add( lv_map_html ).
      ENDIF.
    ENDLOOP.

    ri_html = ro_html.
  ENDMETHOD.

ENDCLASS.
