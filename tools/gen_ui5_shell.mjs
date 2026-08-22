// gen_ui5_shell.mjs — 从 demo/ui5-shell-preview.html 的标记区生成
// src/framework/zcl_ark_ui5_shell.clas.abap（启动壳 = 阶段②框架资产）。
//
// 用法：node tools/gen_ui5_shell.mjs
// 预览页是壳 CSS/JS/骨架的唯一真源（浏览器可测），本脚本做逐行移植：
// ARK5:SHELL_CSS / ARK5:SHELL_JS / ARK5:SHELL_BODY 三对标记区。
// 约束：标记区内容不得含反引号（ABAP 字面量定界符），含则报错终止。
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = readFileSync(join(root, "demo", "ui5-shell-preview.html"), "utf8");

function extract(startMark, endMark) {
  const i = src.indexOf(startMark);
  const j = src.indexOf(endMark);
  if (i < 0 || j < 0 || j < i) {
    throw new Error(`marker not found: ${startMark} / ${endMark}`);
  }
  return src.slice(i + startMark.length, j);
}

let css = extract("/* ===== ARK5:SHELL_CSS START ===== */", "/* ===== ARK5:SHELL_CSS END ===== */");
let js = extract("/* ===== ARK5:SHELL_JS START ===== */", "/* ===== ARK5:SHELL_JS END ===== */");
let body = extract("<!-- ===== ARK5:SHELL_BODY START ===== -->", "<!-- ===== ARK5:SHELL_BODY END ===== -->");

// 预览专用节点不进 ABAP（自检日志行）
body = body
  .split("\n")
  .filter((l) => l.indexOf("ark5_testlog") < 0)
  .join("\n");

function toAbapLiteral(block, indent) {
  const lines = block
    .split("\n")
    .map((l) => l.replace(/\r$/, ""))
    .filter((l) => l.trim().length > 0);
  for (const l of lines) {
    if (l.indexOf("`") >= 0) {
      throw new Error(`backtick in shell block (ABAP literal delimiter): ${l}`);
    }
  }
  return lines.map((l, idx) => {
    const tail = idx < lines.length - 1 ? " &&" : "";
    return `${indent}\`${l}\`${tail}`;
  }).join("\n");
}

// JS 块必须逐行 APPEND + 真实换行拼接：ABAP 的 && 连接不产生换行，
// 单行化会让 JS 行注释 // 吞掉其后全部代码（白屏事故已踩）
function toAbapLines(block) {
  const lines = block
    .split("\n")
    .map((l) => l.replace(/\r$/, ""))
    .filter((l) => l.trim().length > 0);
  for (const l of lines) {
    if (l.indexOf("`") >= 0) {
      throw new Error(`backtick in shell block (ABAP literal delimiter): ${l}`);
    }
  }
  return ["<script>", ...lines, "</script>"]
    .map((l) => `      APPEND \`${l}\` TO lt_js.`)
    .join("\n");
}

const cssLit = toAbapLiteral(css, "      ");
const jsLit = toAbapLines(js);
const bodyLit = toAbapLiteral(body, "      ");

const clas = `CLASS zcl_ark_ui5_shell DEFINITION
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
${cssLit}
      ).

    ro_html->add(
${bodyLit}
      ).

    " ===== 壳 JS（桥 + 渲染器，与 demo 预览逐字一致）=====
    " 逐行 APPEND 后以真实换行拼接：&& 连接不产生换行，单行化会让
    " JS 行注释 // 吞掉其后全部代码（宿主白屏事故已踩）
    DATA lt_js TYPE string_table.
    DATA lv_js TYPE string.
${jsLit}
    CONCATENATE LINES OF lt_js INTO lv_js
      SEPARATED BY cl_abap_char_utilities=>newline.
    ro_html->add( lv_js ).

    " ===== 初始 state 启动（值含 </ 会截断脚本块，按 JSON 转义规则替换）=====
    DATA(lv_json) = zcl_ark_json=>to_json( is_state ).
    lv_json = replace( val = lv_json sub = \`</\` with = \`<\\/\` occ = 0 ).
    ro_html->add(
      \`<script>window.__arkShellBoot( \` && lv_json && \` );</script>\` ).

    " ===== UI5 bootstrap（文档末尾；async=true，库文件异步加载）=====
    ro_html->add(
      \`<script id="sap-ui-bootstrap"\` &&
      \`        src="\` && c_ui5_cdn && \`"\` &&
      \`        data-sap-ui-theme="sap_horizon"\` &&
      \`        data-sap-ui-libs="sap.m,sap.f"\` &&
      \`        data-sap-ui-compatVersion="edge"\` &&
      \`        data-sap-ui-async="true"></script>\` ).

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
`;

writeFileSync(join(root, "src", "framework", "zcl_ark_ui5_shell.clas.abap"), clas);
console.log("written: src/framework/zcl_ark_ui5_shell.clas.abap");
console.log("css lines:", css.split("\n").filter((l) => l.trim()).length,
  "| js lines:", js.split("\n").filter((l) => l.trim()).length,
  "| body lines:", body.split("\n").filter((l) => l.trim()).length);
