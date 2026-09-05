// make_w3mi.mjs — 把本地 JS/JSON/CSS 等文件转成 ARK 的 SMW0 (W3MI) 资产对：
//   <name>.w3mi.xml     — abapGit 对象元数据
//   <name>.w3mi.data.X  — 原始内容（随仓库分发，abapGit pull 即部署到 SMW0）
//
// 用法：
//   node tools/make_w3mi.mjs three.min.js ZARK_THREE_MIN_JS \
//        --text "three.js r160 (UMD build)" [--out src/assets]
//
// 生成后 git add + push，目标系统 abapGit pull 即完成部署；ABAP 侧：
//   zcl_ark_js_library=>register( iv_name = 'three' iv_mime = 'ZARK_THREE_MIN_JS' ).
//
// 注意：JS 库请用 UMD/全局构建（如 three.min.js），ES module 的 import
// 在 SAP GUI HTML Viewer 的 file:/// 环境下不可靠。

import { readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const MIME_TYPES = {
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
  ".css": "text/css",
  ".html": "text/html",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".gif": "image/gif",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
};

function arg(flag) {
  const i = process.argv.indexOf(flag);
  return i > 0 ? process.argv[i + 1] : undefined;
}

const [, , input, name] = process.argv;
if (!input || !name || !/^[A-Z][A-Z0-9_]*$/.test(name)) {
  console.error(
    "用法: node tools/make_w3mi.mjs <input-file> <MIME_NAME> [--text \"desc\"] [--out dir]",
  );
  process.exit(1);
}

const text = arg("--text") ?? `ARK - ${name}`;
const outDir = arg("--out") ?? join(dirname(fileURLToPath(import.meta.url)), "..", "src", "assets");

const ext = (basename(input).match(/(\.[a-z0-9]+)$/i)?.[1] ?? "").toLowerCase();
const mimetype = MIME_TYPES[ext];
if (!mimetype) {
  console.error(`不支持的扩展名: ${ext || "(无)"} — 支持: ${Object.keys(MIME_TYPES).join(" ")}`);
  process.exit(1);
}

const content = readFileSync(input);

// abapGit W3MI 约定：<lower_snake_name>.w3mi.xml + .w3mi.data.<原扩展名>
const base = name.toLowerCase().replaceAll("_", "_");
const xmlName = `${base}.w3mi.xml`;
const dataName = `${base}.w3mi.data${ext}`;

const param = (n, v) =>
  `    <WWWPARAMS>\n     <NAME>${n}</NAME>\n     <VALUE>${v}</VALUE>\n    </WWWPARAMS>`;

// 行首 BOM 与既有资产 XML 一致（abapGit 序列化输出带 BOM）
const xml =
  "\ufeff<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
  '<abapGit version="v1.0.0" serializer="LCL_OBJECT_W3MI" serializer_version="v2.0.0">\n' +
  ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n' +
  "  <asx:values>\n" +
  `   <NAME>${name}</NAME>\n` +
  `   <TEXT>${text.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</TEXT>\n` +
  "   <PARAMS>\n" +
  param("fileextension", ext) +
  "\n" +
  param("filename", basename(input)) +
  "\n" +
  param("mimetype", mimetype) +
  "\n" +
  "   </PARAMS>\n" +
  "  </asx:values>\n" +
  " </asx:abap>\n" +
  "</abapGit>\n";

writeFileSync(join(outDir, xmlName), xml);
writeFileSync(join(outDir, dataName), content);

console.log(`OK  ${join(outDir, xmlName)}`);
console.log(`    ${join(outDir, dataName)} (${content.length} bytes)`);
console.log(`ABAP: zcl_ark_js_library=>register( iv_name = '...' iv_mime = '${name}' ).`);
