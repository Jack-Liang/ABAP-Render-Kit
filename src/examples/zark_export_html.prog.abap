"! ARK 整页 HTML 导出（自动化测试出口）。
"!
"! 把 ARK 页面渲染成完整 HTML 连同 JS 资产导出到前端目录，供普通浏览器 /
"! Playwright 做黑盒验证（图表渲染、点击触发 arkEmit 回调等），不需要打开
"! SAP GUI 里的 HTML Viewer。
"!
"! 用法：SE38 运行，PAGE 选页面，PATH 填导出的 html 全路径。
"! 同目录会额外生成 ark_echarts.min.js / ark_map_china.js（相对引用），
"! 三件套拷走后即可在任何机器打开。
"!
"! 桥的 mock：导出的 HTML 里 arkEmit 不做 sapevent 导航，而是把事件记录到
"! window.__arkLog 并打印 console（前缀 ARKEVENT），测试脚本据此断言回调。
REPORT zark_export_html.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
PARAMETERS p_page TYPE char20 DEFAULT 'CHART' OBLIGATORY.
PARAMETERS p_path TYPE string DEFAULT 'C:/temp/ark_export.html' LOWER CASE.
SELECTION-SCREEN END OF BLOCK b1.

START-OF-SELECTION.
  PERFORM main.

FORM main.
  TRY.
      PERFORM do_export.
    CATCH cx_root INTO DATA(lo_err).
      MESSAGE lo_err->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.

FORM do_export.
  " gui_download 要求前端绝对路径：相对路径直接 dataprovider 错误
  IF find( val = p_path sub = `/` ) < 0 AND find( val = p_path sub = `\` ) < 0.
    zcx_ark_exception=>raise( |p_path 需为绝对路径（如 C:/temp/ark_export.html），当前: { p_path }| ).
  ENDIF.

  " 1) 页面对象（参数无关，直接实例化）
  DATA lv_cls TYPE string.
  CASE p_page.
    WHEN 'HELLO'.   lv_cls = 'ZCL_ARK_EXAMPLE_HELLO_PAGE'.
    WHEN 'FORM'.    lv_cls = 'ZCL_ARK_EXAMPLE_FORM_PAGE'.
    WHEN 'TABLE'.   lv_cls = 'ZCL_ARK_EXAMPLE_TABLE_PAGE'.
    WHEN 'CHART'.   lv_cls = 'ZCL_ARK_EXAMPLE_CHART_PAGE'.
    WHEN 'DATA'.    lv_cls = 'ZCL_ARK_EXAMPLE_DATA_PAGE'.
    WHEN 'BROWSER'. lv_cls = 'ZCL_ARK_EXAMPLE_BROWSER_PAGE'.
    WHEN OTHERS.
      zcx_ark_exception=>raise( |unknown page: { p_page }| ).
  ENDCASE.
  DATA lo_page TYPE REF TO zif_ark_gui_renderable.
  CREATE OBJECT lo_page TYPE (lv_cls).

  " 2) GUI 实例：set_page/render_page 需要；资产全部走相对 URL，
  "    不会触发 load_data
  DATA(lo_gui) = zcl_ark_gui=>create( ).
  lo_gui->set_page( lo_page ).

  " 3) 资产导出 + 相对 URL 覆盖注册（register 同名以最新一次为准）。
  "    MIME 缺失时跳过对应覆盖，页面退化为 CDN 兜底或空地图
  DATA lv_dir TYPE string.
  PERFORM export_assets CHANGING lv_dir.

  " 4) 整页 HTML + 桥 mock
  DATA(lv_html) = lo_gui->render_page( ).
  lv_html = replace( val = lv_html
                     sub  = |location.href = arkPrefix + 'SAPEVENT:' + action + (q ? '?' + q : '');|
                     with = |if (!window.__arkLog) \{ window.__arkLog = []; \} window.__arkLog.push(\{ action: action, q: q \}); console.log('ARKEVENT', action, q);|
                     occ  = 0 ).
  PERFORM download_string USING lv_html p_path.

  MESSAGE |exported: { p_path } (dir: { lv_dir })| TYPE 'S'.
ENDFORM.

FORM export_assets CHANGING cv_dir TYPE string.
  " 目标目录取 p_path 的父目录（find 的 occ = -1 取最后一次出现；
  " FIND LAST OCCURRENCE OF 语句 abaplint 解析不了，故用内置函数）
  DATA(lv_norm) = replace( val = p_path sub = `\` with = `/` occ = 0 ).
  DATA(lv_off) = find( val = lv_norm sub = `/` occ = -1 ).
  DATA lv_sep TYPE c LENGTH 1.
  IF lv_off > 0.
    cv_dir = lv_norm(lv_off).
    lv_sep = '/'.
  ELSE.
    CLEAR cv_dir.
    lv_sep = '/'.
  ENDIF.

  " echarts 本体
  TRY.
      DATA(lv_lib_xstr) = zcl_ark_convert=>mime_to_xstring( 'ZARK_ECHARTS_MIN_JS' ).
      zcl_ark_js_library=>register(
        iv_name = zcl_ark_echarts=>c_lib_name
        iv_url  = 'ark_echarts.min.js' ).
      DATA(lv_lib_path) = |{ cv_dir }{ lv_sep }ark_echarts.min.js|.
      PERFORM download_xstring USING lv_lib_xstr lv_lib_path.
    CATCH zcx_ark_exception.
      MESSAGE 'MIME ZARK_ECHARTS_MIN_JS not found, echarts falls back to CDN' TYPE 'S'.
  ENDTRY.

  " 中国地图（use_bundled_map 的 xdata 走 gt_map_asset，但注册名解析在
  " 注册器——预注册同名 URL 后 include_map_script 不再覆盖）
  TRY.
      DATA(lv_map_geojson) = zcl_ark_convert=>xstring_to_string_utf8(
                               zcl_ark_convert=>mime_to_xstring( 'ZARK_MAP_CHINA_JSON' ) ).
      zcl_ark_js_library=>register(
        iv_name = 'ark_map_china'
        iv_url  = 'ark_map_china.js' ).
      " 与 zcl_ark_echarts=>wrap_map_js 的输出保持一致：
      " 同步 script 注入 window.ARK_MAPS['<map>']，由图表初始化脚本 registerMap
      DATA(lv_map_wrapped) = replace( val = lv_map_geojson sub = `</` with = `<\/` occ = 0 ).
      DATA(lv_map_js) = |window.ARK_MAPS = window.ARK_MAPS \|\| \{\};| &&
                        |window.ARK_MAPS['china'] = { lv_map_wrapped };|.
      DATA(lv_map_path) = |{ cv_dir }{ lv_sep }ark_map_china.js|.
      PERFORM download_string USING lv_map_js lv_map_path.
    CATCH zcx_ark_exception.
      MESSAGE 'MIME ZARK_MAP_CHINA_JSON not found, map page will show empty map' TYPE 'S'.
  ENDTRY.
ENDFORM.

FORM download_string USING iv_str TYPE string iv_path TYPE string.
  " BIN 字节流写入（UTF-8 精确落盘，绕开 ASC 代码页转换的 DP 兼容问题）
  TYPES ty_x200 TYPE x LENGTH 200.
  DATA lt_tab TYPE STANDARD TABLE OF ty_x200.
  DATA lv_size TYPE i.
  zcl_ark_convert=>xstring_to_bintab(
    EXPORTING iv_xstr = zcl_ark_convert=>string_to_xstring( iv_str )
    IMPORTING ev_size = lv_size
              et_bintab = lt_tab ).
  TRY.
      cl_gui_frontend_services=>gui_download(
        EXPORTING
          filename = iv_path
          filetype = 'BIN'
          bin_filesize = lv_size
        CHANGING
          data_tab = lt_tab ).
    CATCH cx_root INTO DATA(lo_err).
      zcx_ark_exception=>raise( |gui_download 失败({ iv_path }): { lo_err->get_text( ) }| ).
  ENDTRY.
ENDFORM.

FORM download_xstring USING iv_xstr TYPE xstring iv_path TYPE string.
  TYPES ty_x200 TYPE x LENGTH 200.
  DATA lt_tab TYPE STANDARD TABLE OF ty_x200.
  DATA lv_size TYPE i.
  zcl_ark_convert=>xstring_to_bintab(
    EXPORTING iv_xstr = iv_xstr
    IMPORTING ev_size = lv_size
              et_bintab = lt_tab ).
  TRY.
      cl_gui_frontend_services=>gui_download(
        EXPORTING
          filename = iv_path
          filetype = 'BIN'
          bin_filesize = lv_size
        CHANGING
          data_tab = lt_tab ).
    CATCH cx_root INTO DATA(lo_err).
      zcx_ark_exception=>raise( |gui_download 失败({ iv_path }): { lo_err->get_text( ) }| ).
  ENDTRY.
ENDFORM.
