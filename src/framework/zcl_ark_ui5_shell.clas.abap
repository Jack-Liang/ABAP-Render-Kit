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
    " 文档骨架：CSS → 挂载点 → UI5/ECharts 标签 → 壳 JS → 初始 state 启动。
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

    " ===== UI5 bootstrap（async：core 同步就绪，库文件异步加载）=====
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

    " ===== 壳 JS（桥 + 渲染器，与 demo 预览逐字一致）=====
    ro_html->add(
      `<script>` &&
      `(function () {` &&
      `  "use strict";` &&
      `  window.onerror = function (m, src, l) {` &&
      `    var el = document.getElementById("errlog");` &&
      `    if (el) { el.textContent += "JS ERROR: " + m + " @" + (src || "") + ":" + l + "\n"; }` &&
      `    return false;` &&
      `  };` &&
      `  function errlog(msg) {` &&
      `    var el = document.getElementById("errlog");` &&
      `    if (el) { el.textContent += msg + "\n"; }` &&
      `  }` &&
      `  var ARK5 = { state: null, charts: [], ui5Ready: false, mods: null, ctl: {} };` &&
      `  // zcl_ark_json 键名大写、abap_bool 序列化为 "X"/""（flag 兼容 true/1）` &&
      `  function flag(v) { return v === true || v === "X" || v === 1 || v === "true"; }` &&
      `  function esc(s) {` &&
      `    return String(s === null || s === undefined ? "" : s)` &&
      `      .replace(/&/g, "&amp;").replace(/</g, "&lt;")` &&
      `      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");` &&
      `  }` &&
      `  var SEMA = {` &&
      `    positive:    { color: "#107e3e", state: "Success" },` &&
      `    negative:    { color: "#bb0000", state: "Error" },` &&
      `    critical:    { color: "#e9730c", state: "Warning" },` &&
      `    informative: { color: "#0a6ed1", state: "Information" },` &&
      `    neutral:     { color: "#6a6d70", state: "None" }` &&
      `  };` &&
      `  function sema(name) { return SEMA[name] || { color: "#0070f2", state: "None" }; }` &&
      `  function toast(msg) {` &&
      `    if (ARK5.mods && ARK5.mods.MessageToast) { ARK5.mods.MessageToast.show(msg); }` &&
      `    else { errlog("TOAST: " + msg); }` &&
      `  }` &&
      `  // ---- sapevent 桥（与宿主验证页同一套已验证机制）----` &&
      `  function arkPrefix() {` &&
      `    var a = document.getElementById("ark_probe");` &&
      `    var base = String(location.href);` &&
      `    var tries = [];` &&
      `    if (a) {` &&
      `      tries.push(String(a.href || ""));` &&
      `      tries.push(String(a.getAttribute("href") || ""));` &&
      `    }` &&
      `    tries.push(base);` &&
      `    var n, h, i, head;` &&
      `    for (n = 0; n < tries.length; n++) {` &&
      `      i = tries[n].toLowerCase().indexOf("sapevent:");` &&
      `      if (i > 0) {` &&
      `        head = tries[n].substring(0, i);` &&
      `        if (head.charAt(head.length - 1) === "/") { return head; }` &&
      `      }` &&
      `    }` &&
      `    if (/^saphtmlp:/i.test(base) || /^sap-cust:/i.test(base)) {` &&
      `      return "sap-cust://sap-place-holder/";` &&
      `    }` &&
      `    if (/^file:/i.test(base)) { return "file:///"; }` &&
      `    return "";` &&
      `  }` &&
      `  function arkUrl(action, params) {` &&
      `    var u = arkPrefix() + "SAPEVENT:" + action, k, qs = [];` &&
      `    params = params || {};` &&
      `    for (k in params) {` &&
      `      if (params.hasOwnProperty(k)) { qs.push(k + "=" + encodeURIComponent(params[k])); }` &&
      `    }` &&
      `    return qs.length ? u + "?" + qs.join("&") : u;` &&
      `  }` &&
      `  function parseParams(s) {` &&
      `    var out = {}, pairs, i, kv;` &&
      `    if (!s) { return out; }` &&
      `    pairs = String(s).split("&");` &&
      `    for (i = 0; i < pairs.length; i++) {` &&
      `      kv = pairs[i].split("=");` &&
      `      if (kv.length >= 1 && kv[0]) {` &&
      `        out[kv[0]] = decodeURIComponent(kv.slice(1).join("=") || "");` &&
      `      }` &&
      `    }` &&
      `    return out;` &&
      `  }` &&
      `  window.ark = {` &&
      `    // 桥事件（隐藏 iframe GET）：ABAP 侧回推新 state，主页面常驻不重载` &&
      `    state: function (action, params) {` &&
      `      var p = {}, k;` &&
      `      for (k in (params || {})) { p[k] = params[k]; }` &&
      `      p.__ark = "1";` &&
      `      window.frames["ark_bridge"].location.href = arkUrl(action, p);` &&
      `    },` &&
      `    // 主框架导航：页面跳转（整页重渲染），桥事件的反面路径` &&
      `    nav: function (action, params) {` &&
      `      location.href = arkUrl(action, params);` &&
      `    },` &&
      `    // 表单经桥 POST：target=ark_bridge，响应同样 postMessage 回来` &&
      `    formGo: function (f, action) {` &&
      `      f.action = arkUrl(action, { __ark: "1" });` &&
      `      return true;` &&
      `    },` &&
      `    // 桥响应入口：隐藏帧脚本 parent.postMessage({__ark_state:1,payload:...})` &&
      `    receive: function (payload) {` &&
      `      ARK5.state = payload || {};` &&
      `      renderAll();` &&
      `    },` &&
      `    // 调试/测试辅助：当前渲染 state 的深拷贝` &&
      `    snapshot: function () { return JSON.parse(JSON.stringify(ARK5.state || {})); }` &&
      `  };` &&
      `  window.addEventListener("message", function (ev) {` &&
      `    var d = ev.data;` &&
      `    if (!d || d.__ark_state !== 1) { return; }` &&
      `    window.ark.receive(d.payload || {});` &&
      `  });` &&
      `  // ---- 文本分区（标题/副标题）----` &&
      `  function renderText() {` &&
      `    var st = ARK5.state || {};` &&
      `    document.getElementById("ark5_title").textContent = st.TITLE || "";` &&
      `    document.getElementById("ark5_sub").textContent = st.SUBTITLE || "";` &&
      `  }` &&
      `  // ---- 原生分区重建：KPI / 图表容器 / 表单 / 各节挂载点 ----` &&
      `  function renderSections() {` &&
      `    var host = document.getElementById("ark5_sections");` &&
      `    var i;` &&
      `    for (i = 0; i < ARK5.charts.length; i++) {` &&
      `      try { ARK5.charts[i].dispose(); } catch (e) { }` &&
      `    }` &&
      `    ARK5.charts = [];` &&
      `    destroySectionUi5();` &&
      `    host.innerHTML = "";` &&
      `    var st = ARK5.state || {};` &&
      `    (st.SECTIONS || []).forEach(function (sec, si) {` &&
      `      var card = document.createElement("div");` &&
      `      card.className = "ark5-card";` &&
      `      if (sec.TITLE) {` &&
      `        var h = document.createElement("div");` &&
      `        h.className = "ark5-card-title";` &&
      `        h.textContent = sec.TITLE;` &&
      `        card.appendChild(h);` &&
      `      }` &&
      `      if ((sec.TOOLBAR || []).length) {` &&
      `        var tb = document.createElement("div");` &&
      `        tb.id = "ark5_tb_" + si;` &&
      `        card.appendChild(tb);` &&
      `      }` &&
      `      if (sec.KIND === "kpi_grid") { buildKpi(card, sec, si); }` &&
      `      else if (sec.KIND === "table") {` &&
      `        var tbl = document.createElement("div");` &&
      `        tbl.id = "ark5_tbl_" + si;` &&
      `        card.appendChild(tbl);` &&
      `      }` &&
      `      else if (sec.KIND === "chart") {` &&
      `        var ch = document.createElement("div");` &&
      `        ch.id = "ark5_ch_" + si;` &&
      `        ch.className = "ark5-chart";` &&
      `        card.appendChild(ch);` &&
      `      }` &&
      `      else if (sec.KIND === "form") { buildForm(card, sec); }` &&
      `      host.appendChild(card);` &&
      `    });` &&
      `  }` &&
      `  function buildKpi(card, sec, si) {` &&
      `    var grid = document.createElement("div");` &&
      `    grid.className = "ark5-kpi-grid";` &&
      `    (sec.KPI_CARDS || []).forEach(function (k, ki) {` &&
      `      var d = document.createElement("div");` &&
      `      var t = document.createElement("div");` &&
      `      t.className = "ark5-kpi-title";` &&
      `      t.textContent = k.TITLE || "";` &&
      `      d.appendChild(t);` &&
      `      var v = document.createElement("div");` &&
      `      v.className = "ark5-kpi-value";` &&
      `      v.textContent = k.VALUE || "";` &&
      `      d.appendChild(v);` &&
      `      if (k.DELTA_TEXT) {` &&
      `        var dl = document.createElement("span");` &&
      `        dl.className = "ark5-kpi-delta";` &&
      `        dl.style.color = sema(k.DELTA_SEMANTIC).color;` &&
      `        dl.textContent = k.DELTA_TEXT;` &&
      `        d.appendChild(dl);` &&
      `      }` &&
      `      if ((k.SPARKLINE || []).length) {` &&
      `        var sp = document.createElement("div");` &&
      `        sp.id = "ark5_sp_" + si + "_" + ki;` &&
      `        sp.className = "ark5-spark";` &&
      `        d.appendChild(sp);` &&
      `      }` &&
      `      grid.appendChild(d);` &&
      `    });` &&
      `    card.appendChild(grid);` &&
      `  }` &&
      `  function buildForm(card, sec) {` &&
      `    var f = document.createElement("form");` &&
      `    f.method = "post";` &&
      `    f.target = "ark_bridge";` &&
      `    if (sec.FORM_ACTION) {` &&
      `      f.onsubmit = function () { return window.ark.formGo(this, sec.FORM_ACTION); };` &&
      `    }` &&
      `    var hid = document.createElement("input");` &&
      `    hid.type = "hidden";` &&
      `    hid.name = "__ark";` &&
      `    hid.value = "1";` &&
      `    f.appendChild(hid);` &&
      `    (sec.FORM_FIELDS || []).forEach(function (fd) {` &&
      `      if (fd.INPUT_TYPE === "hidden") {` &&
      `        var hi = document.createElement("input");` &&
      `        hi.type = "hidden";` &&
      `        hi.name = fd.NAME || "";` &&
      `        hi.value = fd.VALUE || "";` &&
      `        f.appendChild(hi);` &&
      `        return;` &&
      `      }` &&
      `      var row = document.createElement("div");` &&
      `      row.className = "ark5-form-row";` &&
      `      if (fd.INPUT_TYPE !== "submit") {` &&
      `        var lb = document.createElement("span");` &&
      `        lb.className = "ark5-form-label";` &&
      `        lb.textContent = fd.LABEL || "";` &&
      `        row.appendChild(lb);` &&
      `      }` &&
      `      var el;` &&
      `      if (fd.INPUT_TYPE === "select") {` &&
      `        el = document.createElement("select");` &&
      `        (fd.OPTIONS || []).forEach(function (op) {` &&
      `          var o = document.createElement("option");` &&
      `          o.textContent = op;` &&
      `          if (op === fd.VALUE) { o.selected = true; }` &&
      `          el.appendChild(o);` &&
      `        });` &&
      `      } else if (fd.INPUT_TYPE === "textarea") {` &&
      `        el = document.createElement("textarea");` &&
      `        el.rows = 4;` &&
      `        el.value = fd.VALUE || "";` &&
      `      } else if (fd.INPUT_TYPE === "checkbox") {` &&
      `        el = document.createElement("input");` &&
      `        el.type = "checkbox";` &&
      `        el.checked = flag(fd.VALUE);` &&
      `      } else if (fd.INPUT_TYPE === "submit") {` &&
      `        el = document.createElement("button");` &&
      `        el.type = "submit";` &&
      `        el.className = "ark5-form-btn";` &&
      `        el.textContent = fd.VALUE || fd.LABEL || "提交";` &&
      `      } else {` &&
      `        el = document.createElement("input");` &&
      `        el.type = fd.INPUT_TYPE || "text";` &&
      `        el.value = fd.VALUE || "";` &&
      `      }` &&
      `      if (fd.NAME) { el.name = fd.NAME; }` &&
      `      row.appendChild(el);` &&
      `      f.appendChild(row);` &&
      `    });` &&
      `    card.appendChild(f);` &&
      `  }` &&
      `  // ---- ECharts 分区（sparkline + chart 节）----` &&
      `  function chartOf(id) {` &&
      `    var el = document.getElementById(id);` &&
      `    if (!el || !window.echarts) { return null; }` &&
      `    return echarts.getInstanceByDom(el) || echarts.init(el);` &&
      `  }` &&
      `  function renderCharts() {` &&
      `    if (!window.echarts) { return; }` &&
      `    var st = ARK5.state || {};` &&
      `    (st.SECTIONS || []).forEach(function (sec, si) {` &&
      `      if (sec.KIND === "kpi_grid") {` &&
      `        (sec.KPI_CARDS || []).forEach(function (k, ki) {` &&
      `          var ch = chartOf("ark5_sp_" + si + "_" + ki);` &&
      `          if (!ch) { return; }` &&
      `          ARK5.charts.push(ch);` &&
      `          ch.setOption({` &&
      `            grid: { left: 0, right: 0, top: 2, bottom: 2 },` &&
      `            xAxis: { type: "category", show: false },` &&
      `            yAxis: { type: "value", show: false },` &&
      `            series: [{ type: "line", data: (k.SPARKLINE || []).map(Number),` &&
      `              symbol: "none", smooth: true,` &&
      `              lineStyle: { width: 2, color: sema(k.DELTA_SEMANTIC).color },` &&
      `              areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1,` &&
      `                colorStops: [` &&
      `                  { offset: 0, color: sema(k.DELTA_SEMANTIC).color + "40" },` &&
      `                  { offset: 1, color: sema(k.DELTA_SEMANTIC).color + "00" } ] } } }]` &&
      `          });` &&
      `        });` &&
      `      } else if (sec.KIND === "chart") {` &&
      `        var ch2 = chartOf("ark5_ch_" + si);` &&
      `        if (!ch2) { return; }` &&
      `        ARK5.charts.push(ch2);` &&
      `        if (sec.CHART_MAP && window.ARK_MAPS && window.ARK_MAPS[sec.CHART_MAP]) {` &&
      `          echarts.registerMap(sec.CHART_MAP, window.ARK_MAPS[sec.CHART_MAP]);` &&
      `        }` &&
      `        var opt = {};` &&
      `        try { opt = JSON.parse(sec.CHART_OPTION || "{}"); } catch (e) {` &&
      `          errlog("chart_option JSON 解析失败: " + e.message);` &&
      `        }` &&
      `        ch2.setOption(opt, true);` &&
      `        if (sec.CHART_CLICK_ACTION) {` &&
      `          ch2.off("click");` &&
      `          ch2.on("click", (function (act, sIdx) {` &&
      `            return function (p) {` &&
      `              var v = p.value;` &&
      `              if (v && typeof v === "object") { v = JSON.stringify(v); }` &&
      `              ark.state(act, {` &&
      `                name: p.name || "", series: p.seriesName || "",` &&
      `                value: v === undefined ? "" : String(v),` &&
      `                idx: p.dataIndex === undefined ? -1 : p.dataIndex,` &&
      `                chart: sIdx` &&
      `              });` &&
      `            };` &&
      `          })(sec.CHART_CLICK_ACTION, si + 1));` &&
      `        }` &&
      `      }` &&
      `    });` &&
      `  }` &&
      `  // ---- UI5 分区（ShellBar / 工具栏 / sap.m.Table）----` &&
      `  function destroySectionUi5() {` &&
      `    var k;` &&
      `    for (k in ARK5.ctl) {` &&
      `      if (k.indexOf("s_") === 0 || k === "tb") {` &&
      `        try { ARK5.ctl[k].destroy(); } catch (e) { }` &&
      `        delete ARK5.ctl[k];` &&
      `      }` &&
      `    }` &&
      `  }` &&
      `  function buildToolbarItems(tb, items) {` &&
      `    (items || []).forEach(function (it) {` &&
      `      var params = parseParams(it.PARAMETERS);` &&
      `      if (it.KIND === "button" || it.KIND === "link") {` &&
      `        // link 与 A 路线 render_toolbar 一致：恒可点（enabled 仅约束 button）` &&
      `        tb.addContent(new ARK5.mods.Button({` &&
      `          text: it.LABEL || "",` &&
      `          type: (it.KIND === "button" && flag(it.EMPHASIZED)) ? "Emphasized" : "Transparent",` &&
      `          enabled: it.KIND === "link" ? true : flag(it.ENABLED),` &&
      `          press: (function (a, p, kind) {` &&
      `            return function () {` &&
      `              if (kind === "link") { ark.nav(a, p); } else { ark.state(a, p); }` &&
      `            };` &&
      `          })(it.ACTION, params, it.KIND)` &&
      `        }));` &&
      `      } else if (it.KIND === "text") {` &&
      `        tb.addContent(new ARK5.mods.Text({ text: it.LABEL || "" }));` &&
      `      } else if (it.KIND === "separator") {` &&
      `        // sap.m.Toolbar 无竖线分隔控件，以弹性空档近似（v1 取舍）` &&
      `        tb.addContent(new ARK5.mods.ToolbarSpacer());` &&
      `      }` &&
      `    });` &&
      `  }` &&
      `  function buildTableInto(el, sec, si) {` &&
      `    var key = "s_" + si;` &&
      `    if (ARK5.ctl[key]) {` &&
      `      try { ARK5.ctl[key].destroy(); } catch (e) { }` &&
      `      delete ARK5.ctl[key];` &&
      `      if (el.firstChild) { el.innerHTML = ""; }` &&
      `    }` &&
      `    var cols = [];` &&
      `    (sec.COLUMNS || []).forEach(function (c) {` &&
      `      cols.push(new ARK5.mods.Column({` &&
      `        hAlign: flag(c.ALIGN_RIGHT) ? "End" : "Begin",` &&
      `        demandPopin: true, minScreenWidth: "Tablet",` &&
      `        header: new ARK5.mods.Label({ text: c.LABEL || "" })` &&
      `      }));` &&
      `    });` &&
      `    var items = [];` &&
      `    (sec.ROWS || []).forEach(function (r, ri) {` &&
      `      var cells = [];` &&
      `      (r.CELLS || []).forEach(function (cell) {` &&
      `        if (cell.SEMANTIC) {` &&
      `          cells.push(new ARK5.mods.ObjectStatus({` &&
      `            text: cell.VALUE || "", state: sema(cell.SEMANTIC).state }));` &&
      `        } else if (cell.ACTION) {` &&
      `          cells.push(new ARK5.mods.Link({` &&
      `            text: cell.VALUE || "",` &&
      `            press: (function (a, rn) {` &&
      `              return function () { ark.state(a, { __row: rn }); };` &&
      `            })(cell.ACTION, ri + 1)` &&
      `          }));` &&
      `        } else {` &&
      `          cells.push(new ARK5.mods.Text({ text: cell.VALUE || "" }));` &&
      `        }` &&
      `      });` &&
      `      items.push(new ARK5.mods.ColumnListItem({ cells: cells }));` &&
      `    });` &&
      `    var t = new ARK5.mods.Table({` &&
      `      columns: cols, items: items,` &&
      `      growing: true, growingThreshold: 100` &&
      `    });` &&
      `    t.addStyleClass("ark5-tbl");` &&
      `    ARK5.ctl[key] = t;` &&
      `    t.placeAt(el);` &&
      `  }` &&
      `  function buildUi5() {` &&
      `    if (!ARK5.ui5Ready || !ARK5.state) { return; }` &&
      `    var st = ARK5.state;` &&
      `    if (!ARK5.ctl.shell) {` &&
      `      ARK5.ctl.shell = new ARK5.mods.ShellBar({ showNavButton: false });` &&
      `      ARK5.ctl.shell.placeAt("ark5_shellbar");` &&
      `    }` &&
      `    ARK5.ctl.shell.setTitle(st.TITLE || "");` &&
      `    // 页面工具栏独占挂载点：无条件清掉旧控件遗留（UI5 destroy 在渲染` &&
      `    // 队列延迟下会留下改名死节点 sap-ui-destroyed-*；真实宿主页面前台` &&
      `    // 常驻，此防御主要覆盖后台标签页 rAF 节流与异常时序）` &&
      `    var tbMount = document.getElementById("ark5_toolbar");` &&
      `    if (tbMount && tbMount.firstChild) { tbMount.innerHTML = ""; }` &&
      `    if (ARK5.ctl.tb) {` &&
      `      try { ARK5.ctl.tb.destroy(); } catch (e) { }` &&
      `      ARK5.ctl.tb = null;` &&
      `    }` &&
      `    var tb = new ARK5.mods.Toolbar({ design: "Solid" });` &&
      `    buildToolbarItems(tb, st.TOOLBAR);` &&
      `    ARK5.ctl.tb = tb;` &&
      `    tb.placeAt("ark5_toolbar");` &&
      `    (st.SECTIONS || []).forEach(function (sec, si) {` &&
      `      var tbEl = document.getElementById("ark5_tb_" + si);` &&
      `      if (tbEl && (sec.TOOLBAR || []).length) {` &&
      `        var stb = new ARK5.mods.Toolbar({ design: "Solid" });` &&
      `        buildToolbarItems(stb, sec.TOOLBAR);` &&
      `        ARK5.ctl["s_tb" + si] = stb;` &&
      `        stb.placeAt(tbEl);` &&
      `      }` &&
      `      var tblEl = document.getElementById("ark5_tbl_" + si);` &&
      `      if (tblEl && sec.KIND === "table") { buildTableInto(tblEl, sec, si); }` &&
      `    });` &&
      `  }` &&
      `  function renderAll() {` &&
      `    renderText();` &&
      `    renderSections();` &&
      `    renderCharts();` &&
      `    buildUi5();` &&
      `  }` &&
      `  // ---- 启动 ----` &&
      `  window.__arkShellBoot = function (initialState) {` &&
      `    ARK5.state = initialState || {};` &&
      `    renderAll();` &&
      `    if (window.sap && sap.ui && sap.ui.require) {` &&
      `      sap.ui.require([` &&
      `        "sap/f/ShellBar", "sap/m/Toolbar", "sap/m/ToolbarSpacer", "sap/m/Button",` &&
      `        "sap/m/Text", "sap/m/Table", "sap/m/Column", "sap/m/Label",` &&
      `        "sap/m/ColumnListItem", "sap/m/ObjectStatus", "sap/m/Link",` &&
      `        "sap/m/MessageToast"` &&
      `      ], function (ShellBar, Toolbar, ToolbarSpacer, Button, Text, Table,` &&
      `                   Column, Label, ColumnListItem, ObjectStatus, Link, MessageToast) {` &&
      `        ARK5.mods = { ShellBar: ShellBar, Toolbar: Toolbar, ToolbarSpacer: ToolbarSpacer,` &&
      `          Button: Button, Text: Text, Table: Table, Column: Column, Label: Label,` &&
      `          ColumnListItem: ColumnListItem, ObjectStatus: ObjectStatus, Link: Link,` &&
      `          MessageToast: MessageToast };` &&
      `        ARK5.ui5Ready = true;` &&
      `        buildUi5();` &&
      `      }, function (e) {` &&
      `        errlog("sap.ui.require 失败: " + (e && e.message || e));` &&
      `      });` &&
      `    } else {` &&
      `      errlog("UI5 bootstrap 不可用：仅原生分区渲染（表格/工具栏缺席）");` &&
      `    }` &&
      `  };` &&
      `})();` &&
      `</script>`
      ).

    " ===== 初始 state 启动（值含 </ 会截断脚本块，按 JSON 转义规则替换）=====
    DATA(lv_json) = zcl_ark_json=>to_json( is_state ).
    lv_json = replace( val = lv_json sub = `</` with = `<\/` occ = 0 ).
    ro_html->add(
      `<script>window.__arkShellBoot( ` && lv_json && ` );</script>` ).

    ri_html = ro_html.
  ENDMETHOD.

ENDCLASS.
